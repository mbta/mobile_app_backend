defmodule OpenTripPlannerClient.ParamsBuilderTest do
  use ExUnit.Case, async: true
  alias OpenTripPlannerClient.NamedPosition
  import OpenTripPlannerClient.ParamsBuilder

  @from_inside %NamedPosition{
    latitude: 42.356365,
    longitude: -71.060920
  }

  @to_inside %NamedPosition{
    latitude: 42.3636617,
    longitude: -71.0832908
  }

  @from_stop %NamedPosition{
    name: "FromStop",
    stop_id: "From_Id"
  }

  @to_stop %NamedPosition{
    name: "ToStop",
    stop_id: "To_Id"
  }

  describe "build_params/1" do
    test "depart_at sets date/time options" do
      expected =
        {:ok,
         %{
           "date" => "\"2017-05-22\"",
           "time" => "\"12:04pm\"",
           "arriveBy" => "false",
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual =
        build_params(
          @from_inside,
          @to_inside,
          depart_at: DateTime.from_naive!(~N[2017-05-22T16:04:20], "Etc/UTC")
        )

      assert expected == actual
    end

    test "arrive_by sets date/time options" do
      expected =
        {:ok,
         %{
           "date" => "\"2017-05-22\"",
           "time" => "\"12:04pm\"",
           "arriveBy" => "true",
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual =
        build_params(
          @from_inside,
          @to_inside,
          arrive_by: DateTime.from_naive!(~N[2017-05-22T16:04:20], "Etc/UTC")
        )

      assert expected == actual
    end

    test "wheelchair_accessible? sets wheelchair option" do
      expected =
        {:ok,
         %{
           "wheelchair" => "true",
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, wheelchair_accessible?: true)
      assert expected == actual

      expected =
        {:ok,
         %{
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, wheelchair_accessible?: false)
      assert expected == actual
    end

    test ":mode defaults TRANSIT,WALK" do
      expected =
        {:ok,
         %{
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, mode: [])
      assert expected == actual
    end

    test ":mode builds a comma-separated list of modes to use" do
      expected =
        {:ok,
         %{
           "walkReluctance" => 15,
           "transportModes" => "[{mode: BUS}, {mode: SUBWAY}, {mode: TRAM}, {mode: WALK}]",
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, mode: ["BUS", "SUBWAY", "TRAM"])
      assert expected == actual
    end

    test "optimize_for: :less_walking sets walkReluctance value" do
      expected =
        {:ok,
         %{
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "walkReluctance" => 27,
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, optimize_for: :less_walking)
      assert expected == actual
    end

    test "optimize_for: :fewest_transfers sets transferPenalty value" do
      expected =
        {:ok,
         %{
           "walkReluctance" => 15,
           "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
           "transferPenalty" => 100,
           "fromPlace" => "\"::42.356365,-71.06092\"",
           "locale" => "\"en\"",
           "toPlace" => "\"::42.3636617,-71.0832908\""
         }}

      actual = build_params(@from_inside, @to_inside, optimize_for: :fewest_transfers)
      assert expected == actual
    end

    test "bad options return an error" do
      expected = {:error, {:bad_param, {:bad, :arg}}}
      actual = build_params(@from_inside, @to_inside, bad: :arg)
      assert expected == actual
    end

    test "use stop id from to/from location" do
      expected = {
        :ok,
        %{
          "fromPlace" => "\"FromStop::mbta-ma-us:From_Id\"",
          "toPlace" => "\"ToStop::mbta-ma-us:To_Id\"",
          "locale" => "\"en\"",
          "transportModes" => "[{mode: WALK}, {mode: TRANSIT}]",
          "walkReluctance" => 15
        }
      }

      actual = build_params(@from_stop, @to_stop, [])
      assert expected == actual
    end
  end
end
