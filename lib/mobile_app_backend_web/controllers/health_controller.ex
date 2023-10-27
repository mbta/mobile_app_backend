defmodule MobileAppBackendWeb.HealthController do
  @moduledoc """
  Simple controller to return 200 OK when the application is running.
  This is used by the AWS ALB to determine the health of the target.
  """
  use MobileAppBackendWeb, :controller

  def index(conn, _params) do
    send_resp(conn, :ok, "Ok")
  end
end
