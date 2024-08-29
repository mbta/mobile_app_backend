defmodule MobileAppBackendWeb.Plugs.EtagTest do
  use MobileAppBackendWeb.ConnCase

  alias MobileAppBackendWeb.Plugs.Etag
  import Mox
  import Test.Support.Helpers
  import Phoenix.ConnTest

  describe "init/1" do
    test "passes options through unchanged" do
      assert Etag.init([]) == []
    end
  end

  describe "call/2" do
    setup do
      data = "[\"data\"]"

      %{
        data: data,
        hashed_data:
          :crypto.hash(:sha256, data)
          |> Base.encode16()
          |> String.downcase(),
        parsed_data: Jason.decode!(data)
      }
    end

    @tag :capture_log
    test "when no etag is provided, pass conn through", %{
      conn: conn,
      data: data,
      hashed_data: hashed_data,
      parsed_data: parsed_data
    } do
      conn =
        conn
        |> Etag.call([])
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, data)

      assert Phoenix.ConnTest.json_response(conn, 200) == parsed_data
      assert Plug.Conn.get_resp_header(conn, "etag") == [hashed_data]
    end

    @tag :capture_log
    test "when mismatched etag is provided, pass conn through", %{
      conn: conn,
      data: data,
      hashed_data: hashed_data,
      parsed_data: parsed_data
    } do
      conn =
        conn
        |> Etag.call([])
        |> Plug.Conn.put_req_header("etag", "mismatch")
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, data)

      assert Phoenix.ConnTest.json_response(conn, 200) == parsed_data
      assert Plug.Conn.get_resp_header(conn, "etag") == [hashed_data]
    end

    @tag :capture_log
    test "when matching etag is provided, return 304 with empty body", %{
      conn: conn,
      data: data,
      hashed_data: hashed_data
    } do
      conn =
        conn
        |> Etag.call([])
        |> Plug.Conn.put_req_header("etag", hashed_data)
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, data)

      assert conn.status == 304
      assert conn.resp_body == ""
      assert Plug.Conn.get_resp_header(conn, "etag") == [hashed_data]
    end
  end
end
