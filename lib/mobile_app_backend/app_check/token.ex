defmodule MobileAppBackend.AppCheck.Token do
  @moduledoc """
  Verify app check tokens
  """

  @callback peek_headers(String.t()) :: JOSE.JWS.t()
  @callback verify_strict(JOSE.JWK.t(), [String.t()], binary()) ::
              {valid? :: boolean(), JOSE.JWT.t(), JOSE.JWS.t()}

  def peek_headers(token) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.AppCheck.Token,
      MobileAppBackend.AppCheck.TokenImpl
    ).peek_headers(token)
  end

  def verify_strict(jwk, algos, token) do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.AppCheck.Token,
      MobileAppBackend.AppCheck.TokenImpl
    ).verify_strict(
      jwk,
      algos,
      token
    )
  end
end

defmodule MobileAppBackend.AppCheck.TokenImpl do
  @moduledoc """
  Verify app check tokens using JOSE
  """
  @behaviour MobileAppBackend.AppCheck.Token
  @impl true
  def peek_headers(token) do
    JOSE.JWT.peek_protected(token)
  end

  @impl true
  def verify_strict(jwk, algos, token) do
    JOSE.JWT.verify_strict(jwk, algos, token)
  end
end
