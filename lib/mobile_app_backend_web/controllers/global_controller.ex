defmodule MobileAppBackendWeb.GlobalController do
  use MobileAppBackendWeb, :controller
  alias MobileAppBackend.GlobalDataCache

  def show(conn, _params) do
    global_data = GlobalDataCache.get_data()

    json(conn, global_data)
  end
end
