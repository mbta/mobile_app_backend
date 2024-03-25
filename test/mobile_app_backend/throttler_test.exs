defmodule MobileAppBackend.ThrottlerTest do
  use ExUnit.Case, async: true

  alias MobileAppBackend.Throttler

  @timeout 10

  test "casts instantly on first run" do
    throttler = start_link_supervised!({Throttler, target: self(), cast: :message, ms: @timeout})

    Throttler.request(throttler)

    assert_receive {:"$gen_cast", :message}, 1
  end

  test "casts instantly if last cast was old" do
    throttler = start_link_supervised!({Throttler, target: self(), cast: :message, ms: @timeout})

    :sys.replace_state(throttler, fn state ->
      %Throttler.State{state | last_cast: System.monotonic_time(:millisecond) - (@timeout + 1)}
    end)

    Throttler.request(throttler)

    assert_receive {:"$gen_cast", :message}, 1
  end

  test "casts later if last cast was recent" do
    throttler = start_link_supervised!({Throttler, target: self(), cast: :message, ms: @timeout})

    :sys.replace_state(throttler, fn state ->
      %Throttler.State{state | last_cast: System.monotonic_time(:millisecond)}
    end)

    Throttler.request(throttler)

    refute_receive {:"$gen_cast", :message}, @timeout - 1
    assert_receive {:"$gen_cast", :message}, 2
  end

  test "only casts once" do
    throttler = start_link_supervised!({Throttler, target: self(), cast: :message, ms: @timeout})

    :sys.replace_state(throttler, fn state ->
      %Throttler.State{state | last_cast: System.monotonic_time(:millisecond)}
    end)

    for _ <- 0..50 do
      Throttler.request(throttler)
    end

    refute_receive {:"$gen_cast", :message}, @timeout - 1
    assert_receive {:"$gen_cast", :message}, 2
    refute_receive {:"$gen_cast", :message}, @timeout
  end
end
