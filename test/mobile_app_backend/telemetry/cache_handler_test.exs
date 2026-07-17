defmodule MobileAppBackend.Telemetry.CacheHandlerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Test.Support.Helpers

  alias MobileAppBackend.Telemetry.CacheHandler

  describe "handle_event/4" do
    test "logs hit" do
      set_log_level(:info)

      {_results, log} =
        with_log([level: :info], fn ->
          CacheHandler.handle_event(
            [:mbtav3api, :response_cache, :command, :stop],
            %{duration: 0},
            %{command: :fetch, args: ["key", "value", "opts"], result: {:ok, "why"}},
            %{}
          )
        end)

      assert log =~
               "duration=0 result=hit key=\"key\""
    end

    test "logs miss" do
      set_log_level(:info)

      {_results, log} =
        with_log([level: :info], fn ->
          CacheHandler.handle_event(
            [:mbtav3api, :response_cache, :command, :stop],
            %{duration: 0},
            %{command: :fetch, args: ["key", "value", "opts"], result: {:error, "why"}},
            %{}
          )
        end)

      assert log =~
               "duration=0 result=miss details=\"why\" key=\"key\""
    end
  end
end
