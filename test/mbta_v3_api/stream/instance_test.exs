defmodule MBTAV3API.Stream.InstanceTest do
  use ExUnit.Case, async: true

  alias Test.Support.SSEStub

  test "starts pipeline and sends messages" do
    instance =
      start_supervised!(
        {MBTAV3API.Stream.Instance,
         url: "https://example.com", headers: [{"a", "b"}], send_to: self()}
      )

    sse_stage = SSEStub.get_from_instance(instance)
    assert SSEStub.get_args(sse_stage) == [url: "https://example.com", headers: [{"a", "b"}]]

    refute_receive _

    SSEStub.push_events(sse_stage, [
      %ServerSentEventStage.Event{event: "remove", data: ~s({"id":"1723","type":"vehicle"})}
    ])

    assert_receive {:stream_events,
                    [
                      %MBTAV3API.Stream.Event.Remove{
                        data: %MBTAV3API.JsonApi.Reference{id: "1723", type: "vehicle"}
                      }
                    ]}
  end
end
