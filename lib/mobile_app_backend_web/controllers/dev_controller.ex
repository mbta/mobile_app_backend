defmodule MobileAppBackendWeb.DevController do
  @moduledoc """
  Dev utilities controller. This is only available behind a login.
  """
  use MobileAppBackendWeb, :controller

  alias Plug.Conn

  plug(Ueberauth)

  def home(conn, params) do
    render(conn, :dev_home, params)
  end

  @spec not_found(Conn.t(), any) :: Conn.t()
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(MobileAppBackendWeb.ErrorHTML)
    |> render("404.html")
  end
end
