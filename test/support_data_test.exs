defmodule Test.Support.DataTest do
  use ExUnit.Case

  alias Test.Support.Data, as: MockData

  test "uses state to provide responses" do
    {:ok, server} = start_supervised({MockData, name: nil})

    :sys.replace_state(server, fn _ ->
      %MockData.State{
        data: %{
          %MockData.Request{host: "V3_API", path: "/test-only/is-ok", query: "a=b&c=d"} =>
            %MockData.Response{id: "cfbff0d1-9375-5685-968c-48ce8b15ae17"}
        },
        updating_test_data?: false
      }
    end)

    assert [%MockData.Response{touched: false}] = Map.values(:sys.get_state(server).data)

    resp =
      Req.get!("/test-only/is-ok?a=b&c=d",
        base_url: Application.get_env(:mobile_app_backend, :base_url),
        decode_body: false,
        plug: &MockData.respond(&1, server)
      )

    assert %Req.Response{body: "true"} = resp

    assert [%MockData.Response{touched: true}] = Map.values(:sys.get_state(server).data)

    GenServer.stop(server)
  end
end
