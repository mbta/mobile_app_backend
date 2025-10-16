defmodule MobileAppBackend.Notifications.GCPToken do
  @typedoc """
  A key to disambiguate other persistent_term entries from the one owned by this cache instance.
  Defaults to the module name.
  """
  @type key :: term()

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

  defmodule GCPSTSTokenRequester do
    alias GoogleApi.STS.V1, as: STS

    @behaviour ExAws.Request.HttpClient

    @impl ExAws.Request.HttpClient
    def request(method, url, req_body, headers, http_opts) do
      # https://cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds#rest
      gcp_sts_connection = STS.Connection.new()

      provider_name = Keyword.fetch!(http_opts, :gcp_provider_name)

      gcp_subject_token = %{
        url: URI.append_query(URI.new!(url), req_body) |> to_string(),
        method:
          case method do
            :post -> "POST"
          end,
        headers:
          Enum.map(headers, fn {key, value} -> %{key: key, value: value} end) ++
            [
              %{
                key: "x-goog-cloud-target-resource",
                value: "//iam.googleapis.com/#{provider_name}"
              }
            ]
      }

      gcp_sts_request = %STS.Model.GoogleIdentityStsV1ExchangeTokenRequest{
        audience: "//iam.googleapis.com/#{provider_name}",
        grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
        requestedTokenType: "urn:ietf:params:oauth:token-type:access_token",
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        subjectToken: gcp_subject_token |> Jason.encode!() |> URI.encode(),
        subjectTokenType: "urn:ietf:params:aws:token-type:aws4_request"
      }

      issued_at = :erlang.system_time(:second)

      {:ok, gcp_sts_response} = STS.Api.V1.sts_token(gcp_sts_connection, body: gcp_sts_request)

      token = gcp_sts_response.access_token
      expires_at = issued_at + gcp_sts_response.expires_in

      {:ok,
       %{status_code: 200, headers: [], body: Jason.encode!(%{token: token, expires: expires_at})}}
    end
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
          request = ExAws.STS.get_caller_identity()

          response =
            ExAws.request!(request,
              http_client: GCPSTSTokenRequester,
              http_opts: [gcp_provider_name: gcp_provider_name]
            )

          %{"token" => token, "expires" => expires} = Jason.decode!(response.body)

          %StoredToken{token: token, expires: DateTime.from_unix!(expires)}
      end

    :persistent_term.put(key, stored_token)

    stored_token.token
  end
end
