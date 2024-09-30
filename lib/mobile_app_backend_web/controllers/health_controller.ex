defmodule MobileAppBackendWeb.HealthController do
  @moduledoc """
  Simple controller to return 200 OK when the application is running.
  This is used by the AWS ALB to determine the health of the target.
  """
  use MobileAppBackendWeb, :controller

  def index(conn, _params) do
    backend = conn.private[:health_check_module] || MobileAppBackend.HealthCheck

    {code, body} =
      if backend.healthy?() do
        {:ok, "Ok"}
      else
        {:service_unavailable, "Service Unavailable"}
      end

    send_resp(conn, code, body)
  end
end
