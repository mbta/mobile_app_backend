defmodule MobileAppBackendWeb.ClientConfigController do
  use MobileAppBackendWeb, :controller

  alias MobileAppBackend.ClientConfig
  alias MobileAppBackend.MapboxTokenRotator

  @spec config(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def config(conn, _params) do
    token_rotator_module =
      Application.get_env(:mobile_app_backend, MapboxTokenRotator, MapboxTokenRotator)

    client_config = %ClientConfig{
      mapbox_public_token: token_rotator_module.get_public_token()
    }

    json(conn, client_config)
  end
end
