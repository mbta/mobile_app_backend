defmodule MobileAppBackendWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MobileAppBackendWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint MobileAppBackendWeb.Endpoint

      use MobileAppBackendWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MobileAppBackendWeb.ConnCase
    end
  end

  setup tags do
    conn =
      cond do
        tags[:firebase_valid_token] ->
          Plug.Conn.put_req_header(
            Phoenix.ConnTest.build_conn(),
            "http_x_firebase_appcheck",
            "valid_token"
          )

        tags[:firebase_invalid_token] ->
          Plug.Conn.put_req_header(
            Phoenix.ConnTest.build_conn(),
            "http_x_firebase_appcheck",
            "invalid_token"
          )

        tags[:firebase_invalid_issuer] ->
          Plug.Conn.put_req_header(
            Phoenix.ConnTest.build_conn(),
            "http_x_firebase_appcheck",
            "invalid_issuer"
          )

        tags[:firebase_invalid_project] ->
          Plug.Conn.put_req_header(
            Phoenix.ConnTest.build_conn(),
            "http_x_firebase_appcheck",
            "invalid_project"
          )

        tags[:firebase_invalid_subject] ->
          Plug.Conn.put_req_header(
            Phoenix.ConnTest.build_conn(),
            "http_x_firebase_appcheck",
            "invalid_subject"
          )

        true ->
          Phoenix.ConnTest.build_conn()
      end

    {:ok, conn: conn}
  end
end
