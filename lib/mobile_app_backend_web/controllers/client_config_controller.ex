defmodule MobileAppBackendWeb.ClientConfigController do
  use MobileAppBackendWeb, :controller

  alias MobileAppBackend.ClientConfig
  alias MobileAppBackend.MapboxTokenRotator

  @spec config(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def config(conn, _params) do
    client_config = %ClientConfig{
      mapbox_public_token: MapboxTokenRotator.get_public_token()
    }

    json(conn, client_config)
  end
end
