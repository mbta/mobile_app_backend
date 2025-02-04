defmodule MBTAV3API.Stream.InstanceTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.Prediction
  alias MBTAV3API.Route
  alias MBTAV3API.Stream

  alias Test.Support.SSEStub

  test "starts pipeline and sends messages" do
    instance =
      start_link_supervised!(
        {MBTAV3API.Stream.Instance,
         url: "https://example.com", headers: [{"a", "b"}], destination: self(), type: Route}
      )

    sse_stage = SSEStub.get_from_instance(instance)

    assert SSEStub.get_args(sse_stage) == [
             url: "https://example.com",
             headers: [{"a", "b"}],
             idle_timeout: :timer.seconds(45)
           ]

    refute_receive _

    SSEStub.push_events(sse_stage, [
      %ServerSentEventStage.Event{
        event: "add",
        data: ~s({"attributes":{"type":3},"id":"1723","type":"route"})
      }
    ])

    assert_receive {:stream_data, %{routes: %{"1723" => %Route{id: "1723", type: :bus}}}}
  end

  test "logs health" do
    instance =
      start_link_supervised!(
        {MBTAV3API.Stream.Instance,
         url: "https://example.com", headers: [{"a", "b"}], destination: self(), type: Route}
      )

    {_, log} =
      ExUnit.CaptureLog.with_log(fn ->
        MBTAV3API.Stream.Instance.check_health(instance)
      end)

    # since the SSEStub is not a ServerSentEventStage, it reports as missing
    assert log =~ "[warning]"
    assert log =~ "stage_alive=false"
    assert log =~ "consumer_alive=true"
    assert log =~ "consumer_dest=#PID<"
    assert log =~ "consumer_subscribers=0"
  end

  test "restarts stream if consumer crashes" do
    instance =
      start_link_supervised!(
        {MBTAV3API.Stream.Instance,
         url: "https://example.com", headers: [{"a", "b"}], destination: self(), type: Route}
      )

    old_sse_stage = SSEStub.get_from_instance(instance)

    {_id, consumer, _type, [Stream.Consumer]} =
      instance
      |> Supervisor.which_children()
      |> Enum.find(fn {_id, _child, _type, [module]} -> module == Stream.Consumer end)

    Process.exit(consumer, :simulating_crash)

    # wait for the supervisor to restart things
    Process.sleep(5)

    new_sse_stage = SSEStub.get_from_instance(instance)

    refute old_sse_stage == new_sse_stage
  end

  describe "consumer_spec/1" do
    test "when not specified, returns default consumer" do
      assert {Stream.Consumer, _spec} =
               Stream.Instance.consumer_spec(
                 destination: "topic",
                 type: Prediction,
                 name: "name",
                 ref: "ref"
               )
    end

    test "when store consumer specified, returns store consumer" do
      assert {Stream.ConsumerToStore, _spec} =
               Stream.Instance.consumer_spec(
                 destination: "topic",
                 type: Prediction,
                 name: "name",
                 consumer: %{store: MBTAV3API.Store.Predictions, scope: [route_id: "66"]},
                 ref: "ref"
               )
    end
  end
end
