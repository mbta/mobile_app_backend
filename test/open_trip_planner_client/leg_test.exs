defmodule OpenTripPlannerClient.LegTest do
  use ExUnit.Case, async: true
  import OpenTripPlannerClient.Leg
  alias Test.Support.OpenTripPlannerClient, as: Support

  @from Support.random_stop()
  @to Support.random_stop()
  @start ~N[2017-01-01T00:00:00]
  @stop ~N[2017-01-01T23:59:59]

  describe "same_leg?/1" do
    test "same_legs are the same" do
      leg = Support.transit_leg(@from, @to, @start, @stop)
      assert same_leg?(leg, leg)
    end

    test "same_legs with different steps are the same" do
      leg = Support.personal_leg(@from, @to, @start, @stop)
      modified_leg = %{leg | mode: %{leg.mode | steps: ["different personal steps"]}}
      assert same_leg?(leg, modified_leg)
    end

    test "legs with different to and from are different" do
      leg = Support.personal_leg(@from, @to, @start, @stop)
      different_leg = %{leg | from: %{leg.from | name: "New name"}}
      refute same_leg?(leg, different_leg)
    end
  end
end
