defmodule Util.GCP.IAMCredentials do
  @moduledoc """
  Wrappers for the [Identity and Access Management Service Account Credentials API][api].

  [api]: https://docs.cloud.google.com/iam/docs/reference/credentials/rest?hl=en
  """

  defmodule AccessTokenRequest do
    @moduledoc """
    Request body for
    https://docs.cloud.google.com/iam/docs/reference/credentials/rest/v1/projects.serviceAccounts/generateAccessToken?hl=en
    """
    @type t :: %__MODULE__{scope: [String.t()]}
    @derive Jason.Encoder
    defstruct [:scope]
  end

  defmodule AccessTokenResponse do
    @moduledoc """
    Response body for
    https://docs.cloud.google.com/iam/docs/reference/credentials/rest/v1/projects.serviceAccounts/generateAccessToken?hl=en
    """
    @type t :: %__MODULE__{accessToken: String.t(), expireTime: DateTime.t()}
    defstruct [:accessToken, :expireTime]
  end

  @doc """
  https://docs.cloud.google.com/iam/docs/reference/credentials/rest/v1/projects.serviceAccounts/generateAccessToken?hl=en
  """
  @spec generate_access_token!(String.t(), String.t(), AccessTokenRequest.t()) ::
          AccessTokenResponse.t()
  def generate_access_token!(token, name, request) do
    %Req.Response{body: resp_body} =
      Util.GCP.base_req()
      |> Req.post!(
        base_url: "https://iamcredentials.googleapis.com",
        auth: {:bearer, token},
        url: "/v1/#{name}:generateAccessToken",
        json: request
      )

    {:ok, expire_time, _} = DateTime.from_iso8601(resp_body["expireTime"])

    %AccessTokenResponse{
      accessToken: resp_body["accessToken"],
      expireTime: expire_time
    }
  end
end
