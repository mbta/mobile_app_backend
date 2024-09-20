defmodule MobileAppBackendWeb.GlobalController do
  use MobileAppBackendWeb, :controller
  alias MobileAppBackend.GlobalDataCache

  def show(conn, _params) do
    cache_key =
      Map.get(conn.assigns, :global_cache_key_for_testing, GlobalDataCache.default_key())

    global_data = GlobalDataCache.get_data(cache_key)

    json(conn, global_data)
  end
end
