defmodule MobileAppBackend.AppCheck.JwksApi do
  @moduledoc """
  API for reading the public JSON Web Key Set  (jwks) for use in app check flows.
  """

  @callback read_jwks :: {:ok, [map()]} | {:error, any()}
  def read_jwks do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.AppCheck.JwksApi,
      MobileAppBackend.AppCheck.JwksImpl
    ).read_jwks()
  end
end

defmodule MobileAppBackend.AppCheck.JwksImpl do
  @behaviour MobileAppBackend.AppCheck.JwksApi

  @impl true
  def read_jwks do
    case MobileAppBackend.HTTP.get(
           Application.get_env(:mobile_app_backend, MobileAppBackend.AppCheck)[:jwks_url],
           cache: true
         ) do
      {:ok, %{body: %{"keys" => jwks}}} -> {:ok, jwks}
      {:error, error} -> {:error, error}
      other -> {:error, other}
    end
  end
end
