defmodule MobileAppBackend.Telemetry.WebsocketEventHandlerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Test.Support.Helpers

  alias MobileAppBackend.Telemetry.WebsocketEventHandler

  describe "handle_event/4" do
    test "logs size, count, duration" do
      set_log_level(:info)

      {_results, log} =
        with_log([level: :info], fn ->
          WebsocketEventHandler.handle_event(
            [:bandit, :websocket, :stop],
            %{send_text_frame_bytes: 123, send_text_frame_count: 456, duration: 0},
            %{},
            %{}
          )
        end)

      assert log =~
               "socket_connection_closed send_text_frame_bytes=123 send_text_frame_count=456 duration_ms=0"
    end

    test "debug logs compression info" do
      set_log_level(:debug)

      {_results, log} =
        with_log([level: :debug], fn ->
          WebsocketEventHandler.handle_event(
            [:bandit, :websocket, :start],
            %{compress: %{}},
            %{},
            %{}
          )
        end)

      assert log =~ "socket_connection_opened compression_enabled=true"
    end
  end
end
