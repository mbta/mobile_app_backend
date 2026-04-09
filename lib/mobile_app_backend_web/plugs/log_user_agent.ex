defmodule MobileAppBackendWeb.Plugs.LogUserAgent do
  @behaviour Plug

  def init(_) do
    :ok
  end

  def call(conn, _) do
    user_agent = conn |> Plug.Conn.get_req_header("user-agent") |> List.last()

    if not is_nil(user_agent) do
      Logger.metadata(user_agent: user_agent)
    end

    conn
  end
end
