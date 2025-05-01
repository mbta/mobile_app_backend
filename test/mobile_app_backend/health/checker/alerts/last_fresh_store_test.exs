defmodule MobileAppBackend.Health.Checker.Alerts.LastFreshStoreTest do
  use ExUnit.Case
  alias MobileAppBackend.Health.Checker.Alerts

  setup do
    start_link_supervised!(Alerts.LastFreshStore)
    :ok
  end

  test "read and write last fresh timestamp" do
    Alerts.LastFreshStore.update_last_fresh_timestamp(~U[2024-01-01 00:00:00Z])
    assert ~U[2024-01-01 00:00:00Z] == Alerts.LastFreshStore.last_fresh_timestamp()

    Alerts.LastFreshStore.update_last_fresh_timestamp(~U[2024-01-02 00:00:00Z])
    assert ~U[2024-01-02 00:00:00Z] == Alerts.LastFreshStore.last_fresh_timestamp()
  end
end
