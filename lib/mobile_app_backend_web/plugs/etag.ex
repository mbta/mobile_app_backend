defmodule MobileAppBackendWeb.Plugs.Etag do
  @moduledoc """
  Plug for reading and setting the etag header, which is used to determine
  whether or not the frontend has up to date cached data. The etag is
  generated by hashing the entire response body, and if the frontend makes
  a request with the etag set to the same value that the endpoint would
  respond with, instead it returns a 304 status with an empty body.
  """
  use MobileAppBackendWeb, :controller
  import Plug.Conn

  @impl Plug
  def init(opts) do
    opts
  end

  @impl Plug
  def call(conn, _opts) do
    register_before_send(conn, &handle_etag/1)
  end

  defp handle_etag(conn) do
    hashed_body = hash_body(conn)
    conn = conn |> put_resp_header("etag", hashed_body)

    if List.first(get_req_header(conn, "if-none-match")) == hashed_body do
      conn |> put_status(:not_modified) |> then(&%Plug.Conn{&1 | resp_body: ""})
    else
      conn
    end
  end

  defp hash_body(conn) do
    :crypto.hash(:sha256, conn.resp_body)
    |> Base.encode16()
    |> String.downcase()
  end
end
