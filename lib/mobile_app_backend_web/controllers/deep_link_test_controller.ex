defmodule MobileAppBackendWeb.DeepLinkTestController do
  use MobileAppBackendWeb, :controller

  def redir_dotcom(conn, _params) do
    redirect(conn, to: "https://dev-green.mbtace.com/go")
  end

  def redir_backend(conn, _params) do
    redirect(conn, external: "/go")
  end

  def link_dotcom(conn, _params) do
    html(conn, "<a href=\"https://dev-green.mbtace.com/go\">Open MBTA Go</a>")
  end

  def link_backend(conn, _params) do
    html(conn, "<a href=\"/go\">Open MBTA Go</a>")
  end
end
