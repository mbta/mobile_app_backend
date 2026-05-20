defmodule MobileAppBackendWeb.GlobalController do
  use MobileAppBackendWeb, :controller
  alias MobileAppBackend.GlobalDataCache

  def show(conn, _params) do
    global_data = GlobalDataCache.get_data()

    json(conn, add_stop_blocklist(global_data))
  end

  # Hardcoded list of stops that should still be shown on the map, but omitted in places
  # like nearby trasit. For example, due to a long term planned closure.
  defp add_stop_blocklist(data) do
    # TODO: remove this stop
    Map.put(data, :stop_blocklist, ["place-cool"])
  end
end
