defmodule MobileAppBackend.Telemetry.HttpResponseHandlerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Test.Support.Helpers

  alias MobileAppBackend.Telemetry.HttpResponseHandler

  describe "handle_event/4" do
    test "logs size and compressed size" do
      set_log_level(:info)

      {_results, log} =
        with_log([level: :info], fn ->
          HttpResponseHandler.handle_event(
            [:bandit, :request, :stop],
            %{resp_body_bytes: 123, resp_uncompressed_body_bytes: 456, duration: 0},
            %{conn: %{request_path: "path", status: 200}},
            %{}
          )
        end)

      assert log =~
               "size=123 uncompressed_size=456"
    end

    test "logs null uncompressed size if missing" do
      set_log_level(:info)

      {_results, log} =
        with_log([level: :info], fn ->
          HttpResponseHandler.handle_event(
            [:bandit, :request, :stop],
            %{resp_body_bytes: 123, duration: 0},
            %{conn: %{request_path: "path", status: 200}},
            %{}
          )
        end)

      assert log =~ "size=123 uncompressed_size= duration_ms=0"
    end
  end
end
