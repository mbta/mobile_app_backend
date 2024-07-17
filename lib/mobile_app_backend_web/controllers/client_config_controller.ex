defmodule MobileAppBackendWeb.ClientConfigController do
  alias MobielAppBackend.ClientConfig
  use MobileAppBackendWeb, :controller

  def config(conn, _params) do
    client_config = %ClientConfig{
      mapbox_public_token:
        Application.get_env(:mobile_app_backend, MobileAppBackend.ClientConfig)[
          :mapbox_public_token
        ]
    }

    json(conn, client_config)
  end
end
