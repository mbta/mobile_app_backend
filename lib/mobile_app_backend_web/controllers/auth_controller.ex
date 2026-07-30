defmodule MobileAppBackendWeb.AuthController do
  @moduledoc """
  Handle interactions related to authentication via Keycloak.
  """
  use MobileAppBackendWeb, :controller

  require Logger

  alias MobileAppBackend.KeycloakUser
  alias MobileAppBackendWeb.UserAuth
  alias Plug.Conn

  plug Ueberauth

  @spec callback(Conn.t(), any) :: Conn.t()
  def callback(
        %{
          assigns: %{
            ueberauth_auth: %{
              info: %{
                email: email,
                first_name: first_name,
                last_name: last_name
              },
              extra: %{
                raw_info: %{
                  claims: %{"sub" => id, "auth_time" => auth_time},
                  userinfo: userinfo
                }
              }
            }
          }
        } = conn,
        _params
      ) do
    roles = parse_role(userinfo)
    user = KeycloakUser.new(id, email, first_name, last_name, roles)

    UserAuth.log_in_user(conn, user, auth_time)
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    Logger.info("Ueberauth failure: #{inspect(failure)}")
    conn |> UserAuth.renew_session()
  end

  def callback(%{assigns: assigns} = conn, params) do
    Logger.warning(
      "Unexpected Ueberauth callback assigns=#{inspect(assigns)} params=#{inspect(params)}"
    )

    conn |> UserAuth.renew_session()
  end

  @spec request(Conn.t(), map()) :: Conn.t()
  def request(conn, _params) do
    conn
    |> redirect(to: "/dev/not-found")
    |> halt()
  end

  # Parse the user's roles from the access token provided by Keycloak
  @spec parse_role(map()) :: [KeycloakUser.role()]
  defp parse_role(%{"resource_access" => %{"mobile-app-backend" => %{"roles" => roles}}})
       when is_list(roles),
       do: roles |> Enum.map(&String.to_existing_atom/1)

  defp parse_role(_), do: []
end
