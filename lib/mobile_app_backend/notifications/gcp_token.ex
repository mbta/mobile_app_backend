defmodule MobileAppBackend.Notifications.GCPToken do
  @typedoc """
  A key to disambiguate other persistent_term entries from the one owned by this cache instance.
  Defaults to the module name.
  """
  @type key :: term()

  require Logger
  alias GoogleApi.STS.V1, as: STS

  defmodule StoredToken do
    @type t :: %__MODULE__{token: String.t(), expires: DateTime.t()}
    defstruct [:token, :expires]
  end

  def default_key, do: __MODULE__

  def get_token(key \\ default_key()) do
    stored_token_if_valid =
      case :persistent_term.get(key, nil) do
        %StoredToken{token: token, expires: expires} ->
          if DateTime.before?(DateTime.utc_now(), expires) do
            token
          end

        nil ->
          nil
      end

    stored_token_if_valid || update_token(key)
  end

  @spec update_token(key()) :: String.t()
  defp update_token(key) do
    stored_token =
      Application.get_env(:mobile_app_backend, __MODULE__, [])
      |> Keyword.get(:gcp_provider_name)
      |> case do
        name when name in [nil, ""] ->
          goth_opts =
            case Process.get(:goth_http_client) do
              nil -> []
              http_client -> [http_client: http_client]
            end

          {:ok, token} = Goth.Token.fetch(goth_opts)
          %StoredToken{token: token.token, expires: DateTime.from_unix!(token.expires)}

        gcp_provider_name ->
          # unfortunately, ExAws.request/2 will include content-type and content-encoding headers,
          # which will cause GCP to reject the request, so we have to do this manually
          # (borrowed from https://github.com/peburrows/goth/pull/186)
          aws_config = ExAws.Config.new(:sts)

          # for reasons beyond mortal comprehension, this matters
          aws_config =
            Map.update(aws_config, :security_token, nil, fn security_token ->
              case Base.decode64(security_token) do
                {:ok, raw_token} -> Base.url_encode64(raw_token)
                :error -> security_token
              end
            end)

          operation = ExAws.STS.get_caller_identity()
          url = ExAws.Request.Url.build(operation, aws_config)

          {:ok, sig_headers} =
            ExAws.Auth.headers(
              :post,
              url,
              :sts,
              aws_config,
              [{"x-goog-cloud-target-resource", "//iam.googleapis.com/#{gcp_provider_name}"}],
              ""
            )

          # https://cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds#rest
          gcp_subject_token = %{
            url: url,
            method: "POST",
            headers: Enum.map(sig_headers, fn {key, value} -> %{key: key, value: value} end)
          }

          gcp_sts_request = %STS.Model.GoogleIdentityStsV1ExchangeTokenRequest{
            audience: "//iam.googleapis.com/#{gcp_provider_name}",
            grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
            requestedTokenType: "urn:ietf:params:oauth:token-type:access_token",
            scope: "https://www.googleapis.com/auth/firebase.messaging",
            subjectToken: gcp_subject_token |> Jason.encode!() |> URI.encode(),
            subjectTokenType: "urn:ietf:params:aws:token-type:aws4_request"
          }

          issued_at = DateTime.utc_now(:second)

          gcp_sts_connection = STS.Connection.new()

          {:ok, gcp_sts_response} =
            STS.Api.V1.sts_token(gcp_sts_connection, body: gcp_sts_request)

          token = gcp_sts_response.access_token
          expires_at = DateTime.add(issued_at, gcp_sts_response.expires_in, :second)

          %StoredToken{token: token, expires: expires_at}
      end

    :persistent_term.put(key, stored_token)

    stored_token.token
  end
end
