defmodule MBTAV3API.Stream.InstanceTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.Route
  alias Test.Support.SSEStub

  test "starts pipeline and sends messages" do
    instance =
      start_link_supervised!(
        {MBTAV3API.Stream.Instance,
         url: "https://example.com", headers: [{"a", "b"}], destination: self(), type: Route}
      )

    sse_stage = SSEStub.get_from_instance(instance)
    assert SSEStub.get_args(sse_stage) == [url: "https://example.com", headers: [{"a", "b"}]]

    refute_receive _

    SSEStub.push_events(sse_stage, [
      %ServerSentEventStage.Event{
        event: "add",
        data: ~s({"attributes":{},"id":"1723","type":"route"})
      }
    ])

    assert_receive {:stream_data, %{routes: %{"1723" => %Route{id: "1723"}}}}
  end
end
