defmodule Util.GCP.STS do
  @moduledoc """
  Wrappers for the
  [Security Token Service API](https://docs.cloud.google.com/iam/docs/reference/sts/rest?hl=en).
  """

  defmodule TokenRequest do
    @moduledoc """
    Request body type for
    https://docs.cloud.google.com/iam/docs/reference/sts/rest/v1/TopLevel/token?hl=en
    """
    @type t :: %__MODULE__{
            grantType: String.t(),
            audience: String.t() | nil,
            scope: String.t() | nil,
            requestedTokenType: String.t(),
            subjectToken: String.t(),
            subjectTokenType: String.t()
          }
    @derive Jason.Encoder
    defstruct [
      :grantType,
      :audience,
      :scope,
      :requestedTokenType,
      :subjectToken,
      :subjectTokenType
    ]
  end

  defmodule TokenResponse do
    @moduledoc """
    Response body type for
    https://docs.cloud.google.com/iam/docs/reference/sts/rest/v1/TopLevel/token?hl=en
    """
    @type t :: %__MODULE__{
            access_token: String.t(),
            issued_token_type: String.t(),
            token_type: String.t(),
            expires_in: integer() | nil,
            access_boundary_session_key: String.t()
          }
    defstruct [
      :access_token,
      :issued_token_type,
      :token_type,
      :expires_in,
      :access_boundary_session_key
    ]
  end

  @doc "https://docs.cloud.google.com/iam/docs/reference/sts/rest/v1/TopLevel/token?hl=en"
  @spec token!(TokenRequest.t()) :: TokenResponse.t()
  def token!(request) do
    %Req.Response{body: resp_body} =
      Util.GCP.base_req()
      |> Req.post!(
        base_url: "https://sts.googleapis.com",
        url: "/v1/token",
        json: request
      )

    %TokenResponse{
      access_token: resp_body["access_token"],
      issued_token_type: resp_body["issued_token_type"],
      token_type: resp_body["token_type"],
      expires_in: resp_body["expires_in"],
      access_boundary_session_key: resp_body["access_boundary_session_key"]
    }
  end
end
