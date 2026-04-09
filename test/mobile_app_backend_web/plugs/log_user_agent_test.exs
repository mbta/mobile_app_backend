defmodule MobileAppBackendWeb.Plugs.LogUserAgentTest do
  use MobileAppBackendWeb.ConnCase

  alias MobileAppBackendWeb.Plugs.LogUserAgent

  test "puts user agent in logger metadata", %{conn: conn} do
    user_agent = "Mozilla/5.0 (X11; Linux riscv64; rv:140.0) Servo/1.0.0 Firefox/140.0"
    conn |> put_req_header("user-agent", user_agent) |> LogUserAgent.call(nil)
    assert Keyword.fetch!(Logger.metadata(), :user_agent) == user_agent
  end
end
