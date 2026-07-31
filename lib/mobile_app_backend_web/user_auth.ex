defmodule MobileAppBackendWeb.UserAuth do
  @moduledoc """
  Context for user authentication operations.
  """

  use MobileAppBackendWeb, :verified_routes

  require Logger

  import Plug.Conn
  import Phoenix.Controller

  alias MobileAppBackend.KeycloakUser
  alias Plug.Conn

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  @spec log_in_user(Conn.t(), KeycloakUser.t(), number()) :: Conn.t()
  def log_in_user(conn, user, auth_time) do
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_current_user_in_session(user)
    |> put_session(:last_auth_time, auth_time)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    {user, conn} = ensure_session_user(conn)
    last_auth_time = get_session(conn, :last_auth_time, nil)
    last_active = get_session(conn, :last_active, nil)

    conn
    |> assign(:current_user, user)
    |> assign(:last_auth_time, last_auth_time)
    |> assign(:last_active, last_active)
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user to socket assigns based on
      session user, or nil if there's no session user.

    * `:ensure_authenticated` - Authenticates the user from the session, and
      assigns the current_user to socket assigns based on session user.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule MobileAppBackendWeb.PageLive do
        use MobileAppBackendWeb, :live_view

        on_mount {MobileAppBackendWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{MobileAppBackendWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket =
      socket
      |> mount_current_user(session)
      |> mount_auth_times(session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      Logger.info(
        "USER LOGGING: no current user inside on_mount(:ensure_authenticated). redirecting."
      )

      socket = Phoenix.LiveView.redirect(socket, to: ~p"/auth/keycloak")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  @doc """
  Plug used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] && !auth_expired?(conn) do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def max_session_time do
    Application.get_env(:mobile_app_backend, __MODULE__)[:max_session_time]
  end

  def idle_time do
    Application.get_env(:mobile_app_backend, __MODULE__)[:idle_time]
  end

  @doc """
  Plug used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if current_user do
      email = current_user.email
      now = System.system_time(:second)

      if auth_expired?(conn, now) do
        Logger.info("USER LOGGING: user auth has expired")

        conn
        |> maybe_store_return_to()
        |> redirect(to: ~p"/auth/keycloak?prompt=login&login_hint=#{email}")
        |> halt()
      else
        put_session(conn, :last_active, now)
      end
    else
      Logger.info("USER LOGGING: no current user in 'require authenticated user'. redirecting.")

      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/keycloak")
      |> halt()
    end
  end

  def auth_expired?(last_auth_map, now \\ System.system_time(:second))

  def auth_expired?(%{last_auth_time: last_auth_time, last_active: last_active}, now)
      when is_integer(last_auth_time) and is_integer(last_active) do
    # last_auth_time is when the user entered their password at the SSO provider
    auth_time_expires = last_auth_time + max_session_time()

    # last_active is time of last request
    idle_time_expires = last_active + idle_time()

    # did either timeout expire?
    min(auth_time_expires, idle_time_expires) < now
  end

  def auth_expired?(%Plug.Conn{} = conn, now) do
    last_auth_time = get_session(conn, :last_auth_time)
    last_active = get_session(conn, :last_active, now)

    auth_expired?(%{last_auth_time: last_auth_time, last_active: last_active})
  end

  # Default to auth is expired if last_auth_time or last_active not available
  def auth_expired?(_, _), do: true

  def require_roles(conn, opts) do
    required_roles = Keyword.get(opts, :required_roles, [])
    user = conn.assigns[:current_user]

    if user && Enum.all?(required_roles, fn x -> x in user.roles end) do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access that page")
      |> redirect(to: "/dev/not-found")
      |> halt()
    end
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  @spec renew_session(Conn.t()) :: Conn.t()
  def renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @spec ensure_session_user(Conn.t()) :: {KeycloakUser.t(), Conn.t()} | {nil, Conn.t()}
  defp ensure_session_user(conn) do
    if user = get_session(conn, :user) do
      {user, conn}
    else
      {nil, conn}
    end
  end

  defp mount_auth_times(socket, session) do
    socket
    |> Phoenix.Component.assign_new(:last_auth_time, fn ->
      session["last_auth_time"]
    end)
    |> Phoenix.Component.assign_new(:last_active, fn ->
      session["last_active"]
    end)
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn -> session["user"] end)
  end

  defp put_current_user_in_session(conn, user) do
    conn
    |> put_session(:user, user)
    |> put_session(:live_socket_id, "users_sessions:#{KeycloakUser.keycloak_id(user)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/dev"
end
