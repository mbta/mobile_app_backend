# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule MobileAppBackend.PresentationStrings do
  @moduledoc """
  Localized string descriptions of pieces of data from MBTAV3API.
  """
  use MobileAppBackend.Gettext

  alias MBTAV3API.Alert
  alias MBTAV3API.Route

  @type plurality :: :singular | :plural
  @type string_case :: :lower_case | :sentence_case

  @spec route_type(Route.type(), plurality(), string_case()) :: String.t()
  def route_type(:bus, :singular, :lower_case) do
    gettext("bus", comment: "bus")
  end

  def route_type(:bus, :plural, :lower_case) do
    gettext("buses", comment: "buses")
  end

  def route_type(:bus, :singular, :sentence_case) do
    gettext("Bus", comment: "Label for bus routes in the route picker view")
  end

  def route_type(:bus, :plural, :sentence_case) do
    gettext("Buses",
      comment: ~s|Mode of travel prefixing alert summary e.g.: "Buses will not stop at..."|
    )
  end

  def route_type(:ferry, :singular, :lower_case) do
    gettext("ferry", comment: "ferry")
  end

  def route_type(:ferry, :plural, :lower_case) do
    gettext("ferries", comment: "ferries")
  end

  def route_type(:ferry, :singular, :sentence_case) do
    gettext("Ferry", comment: "Label for ferry routes in the route picker view")
  end

  def route_type(:ferry, :plural, :sentence_case) do
    gettext("Ferries",
      comment: ~s|Mode of travel prefixing alert summary e.g.: "Ferries will not stop at..."|
    )
  end

  def route_type(_train, :singular, :lower_case) do
    gettext("train", comment: "train")
  end

  def route_type(_train, :plural, :lower_case) do
    gettext("trains", comment: "trains")
  end

  def route_type(_train, :singular, :sentence_case) do
    gettext("Train", comment: "Train")
  end

  def route_type(_train, :plural, :sentence_case) do
    gettext("Trains",
      comment: ~s|Mode of travel prefixing alert summary e.g.: "Trains will not stop at..."|
    )
  end

  @spec mode_label(String.t(), Route.type()) :: String.t()
  def mode_label(name, route_type) do
    if route_type == :bus do
      gettext("%{name} bus",
        comment:
          ~s|Bus route name label, with the value being the route number, ex. "1 bus", "66 bus"|,
        name: name
      )
    else
      name
    end
  end

  @spec delay_duration(integer()) :: String.t()
  def delay_duration(severity) do
    case severity do
      3 ->
        gettext("of about 10 minutes", comment: "Ex: delays [of about 10 minutes]")

      4 ->
        gettext("of about 15 minutes", comment: "Ex: delays [of about 15 minutes]")

      5 ->
        gettext("of about 20 minutes", comment: "Ex: delays [of about 20 minutes]")

      6 ->
        gettext("of about 25 minutes", comment: "Ex: delays [of about 25 minutes]")

      7 ->
        gettext("of about 30 minutes", comment: "Ex: delays [of about 30 minutes]")

      8 ->
        gettext("of more than 30 minutes", comment: "Ex: delays [of more than 30 minutes]")

      9 ->
        gettext("of more than an hour", comment: "Ex: delays [of more than an hour]")

      _ ->
        ""
    end
  end

  @spec effect_sentence_case(Alert.effect()) :: String.t()
  def effect_sentence_case(effect) do
    case effect do
      :access_issue ->
        gettext("Access issue", comment: "Possible alert effect")

      :additional_service ->
        gettext("Additional service", comment: "Possible alert effect")

      :amber_alert ->
        gettext("Amber alert", comment: "Possible alert effect")

      :bike_issue ->
        gettext("Bike issue", comment: "Possible alert effect")

      :cancellation ->
        gettext("Trip cancelled",
          comment: [
            "Header for a cancelled trip card on stop details",
            "Possible alert effect"
          ]
        )

      :delay ->
        gettext("Delay", comment: "Possible alert effect")

      :detour ->
        gettext("Detour", comment: "Possible alert effect")

      :dock_closure ->
        gettext("Dock closed", comment: "Possible alert effect")

      :dock_issue ->
        gettext("Dock issue", comment: "Possible alert effect")

      :elevator_closure ->
        gettext("Elevator closed", comment: "Possible alert effect")

      :escalator_closure ->
        gettext("Escalator closed", comment: "Possible alert effect")

      :extra_service ->
        gettext("Extra service", comment: "Possible alert effect")

      :facility_issue ->
        gettext("Facility issue", comment: "Possible alert effect")

      :modified_service ->
        gettext("Modified service", comment: "Possible alert effect")

      :no_service ->
        gettext("No service", comment: "Possible alert effect")

      :notice ->
        gettext("Notice", comment: "Possible alert effect")

      :parking_closure ->
        gettext("Parking closed", comment: "Possible alert effect")

      :parking_issue ->
        gettext("Parking issue", comment: "Possible alert effect")

      :policy_change ->
        gettext("Policy change", comment: "Possible alert effect")

      :schedule_change ->
        gettext("Schedule change", comment: "Possible alert effect")

      :service_change ->
        gettext("Service change", comment: "Possible alert effect")

      :shuttle ->
        gettext("Shuttle buses", comment: "Possible alert effect")

      :snow_route ->
        gettext("Snow route", comment: "Possible alert effect")

      :station_closure ->
        gettext("Station closed", comment: "Possible alert effect")

      :station_issue ->
        gettext("Station issue", comment: "Possible alert effect")

      :stop_closure ->
        gettext("Stop closed", comment: "Possible alert effect")

      :stop_move ->
        gettext("Stop moved", comment: "Possible alert effect")

      :stop_moved ->
        gettext("Stop moved", comment: "Possible alert effect")

      :stop_shoveling ->
        gettext("Stop shoveling", comment: "Possible alert effect")

      :summary ->
        gettext("Summary", comment: "Possible alert effect")

      :suspension ->
        gettext("Service suspended",
          comment: ["Possible alert effect", "Suspension alert VoiceOver text"]
        )

      :track_change ->
        gettext("Track change", comment: "Possible alert effect")

      :other_effect ->
        gettext("Alert", comment: "Possible alert effect")

      :unknown_effect ->
        gettext("Alert", comment: "Possible alert effect")
    end
  end

  @spec effect(Alert.effect()) :: String.t()
  def effect(effect) do
    case effect do
      :access_issue ->
        gettext("Access Issue", comment: "Possible alert effect")

      :additional_service ->
        gettext("Additional Service", comment: "Possible alert effect")

      :amber_alert ->
        gettext("Amber Alert", comment: "Possible alert effect")

      :bike_issue ->
        gettext("Bike Issue", comment: "Possible alert effect")

      :cancellation ->
        gettext("Cancellation", comment: "Possible alert effect")

      :delay ->
        gettext("Delay", comment: "Possible alert effect")

      :detour ->
        gettext("Detour", comment: "Possible alert effect")

      :dock_closure ->
        gettext("Dock Closure", comment: "Possible alert effect")

      :dock_issue ->
        gettext("Dock Issue", comment: "Possible alert effect")

      :elevator_closure ->
        gettext("Elevator Closure", comment: "Possible alert effect")

      :escalator_closure ->
        gettext("Escalator Closure", comment: "Possible alert effect")

      :extra_service ->
        gettext("Extra Service", comment: "Possible alert effect")

      :facility_issue ->
        gettext("Facility Issue", comment: "Possible alert effect")

      :modified_service ->
        gettext("Modified Service", comment: "Possible alert effect")

      :no_service ->
        gettext("No Service", comment: "Possible alert effect")

      :notice ->
        gettext("Notice", comment: "Possible alert effect")

      :parking_closure ->
        gettext("Parking Closure", comment: "Possible alert effect")

      :parking_issue ->
        gettext("Parking Issue", comment: "Possible alert effect")

      :policy_change ->
        gettext("Policy Change", comment: "Possible alert effect")

      :schedule_change ->
        gettext("Schedule Change", comment: "Possible alert effect")

      :service_change ->
        gettext("Service Change", comment: "Possible alert effect")

      :shuttle ->
        gettext("Shuttle",
          comment: ["Possible alert effect", "The status label for a shuttled trip"]
        )

      :snow_route ->
        gettext("Snow Route", comment: "Possible alert effect")

      :station_closure ->
        gettext("Station Closure", comment: "Possible alert effect")

      :station_issue ->
        gettext("Station Issue", comment: "Possible alert effect")

      :stop_closure ->
        gettext("Stop Closure", comment: "Possible alert effect")

      :stop_move ->
        gettext("Stop Moved", comment: "Possible alert effect")

      :stop_moved ->
        gettext("Stop Moved", comment: "Possible alert effect")

      :stop_shoveling ->
        gettext("Stop Shoveling", comment: "Possible alert effect")

      :summary ->
        gettext("Summary", comment: "Possible alert effect")

      :suspension ->
        gettext("Suspension", comment: "Possible alert effect")

      :trackChange ->
        gettext("Track Change", comment: "Possible alert effect")

      :other_effect ->
        gettext("Alert", comment: "Possible alert effect")

      :unknown_effect ->
        gettext("Alert", comment: "Possible alert effect")
    end
  end

  @spec cause_lower_case(Alert.cause()) :: String.t() | nil
  def cause_lower_case(cause) do
    case cause do
      :accident ->
        gettext("accident", comment: "Alert cause, used in 'Delays due to [cause]'")

      :amtrak ->
        gettext("Amtrak", comment: "Alert cause, used in 'Delays due to [cause]'")

      :amtrak_train_traffic ->
        gettext("Amtrak train traffic", comment: "Alert cause, used in 'Delays due to [cause]'")

      :an_earlier_mechanical_problem ->
        gettext("an earlier mechanical problem",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :an_earlier_signal_problem ->
        gettext("an earlier signal problem",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :autos_impeding_service ->
        gettext("autos impeding service", comment: "Alert cause, used in 'Delays due to [cause]'")

      :coast_guard_restriction ->
        gettext("Coast Guard restriction",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :congestion ->
        gettext("congestion", comment: "Alert cause, used in 'Delays due to [cause]'")

      :construction ->
        gettext("construction", comment: "Alert cause, used in 'Delays due to [cause]'")

      :crossing_issue ->
        gettext("crossing issue", comment: "Alert cause, used in 'Delays due to [cause]'")

      :crossing_malfunction ->
        gettext("crossing malfunction", comment: "Alert cause, used in 'Delays due to [cause]'")

      :demonstration ->
        gettext("demonstration", comment: "Alert cause, used in 'Delays due to [cause]'")

      :disabled_bus ->
        gettext("disabled bus", comment: "Alert cause, used in 'Delays due to [cause]'")

      :disabled_train ->
        gettext("disabled train", comment: "Alert cause, used in 'Delays due to [cause]'")

      :drawbridge_being_raised ->
        gettext("drawbridge being raised",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :drawbridge_issue ->
        gettext("drawbridge issue", comment: "Alert cause, used in 'Delays due to [cause]'")

      :electrical_work ->
        gettext("electrical work", comment: "Alert cause, used in 'Delays due to [cause]'")

      :fire ->
        gettext("fire", comment: "Alert cause, used in 'Delays due to [cause]'")

      :fire_department_activity ->
        gettext("fire department activity",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :flooding ->
        gettext("flooding", comment: "Alert cause, used in 'Delays due to [cause]'")

      :fog ->
        gettext("fog", comment: "Alert cause, used in 'Delays due to [cause]'")

      :freight_train_interference ->
        gettext("freight train interference",
          comment: "Alert cause, used in 'Delays due to [cause]'"
        )

      :hazmat_condition ->
        gettext("hazmat condition", comment: "Alert cause, used in 'Delays due to [cause]'")

      :heavy_ridership ->
        gettext("heavy ridership", comment: "Alert cause, used in 'Delays due to [cause]'")

      :high_winds ->
        gettext("high winds", comment: "Alert cause, used in 'Delays due to [cause]'")

      :holiday ->
        gettext("holiday", comment: "Alert cause, used in 'Delays due to [cause]'")

      :ice_in_harbor ->
        gettext("ice in harbor", comment: "Alert cause, used in 'Delays due to [cause]'")

      :maintenance ->
        gettext("maintenance", comment: "Alert cause, used in 'Delays due to [cause]'")

      :mechanical_issue ->
        gettext("mechanical issue", comment: "Alert cause, used in 'Delays due to [cause]'")

      :mechanical_problem ->
        gettext("mechanical problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :medical_emergency ->
        gettext("medical emergency", comment: "Alert cause, used in 'Delays due to [cause]'")

      :parade ->
        gettext("parade", comment: "Alert cause, used in 'Delays due to [cause]'")

      :police_activity ->
        gettext("police activity", comment: "Alert cause, used in 'Delays due to [cause]'")

      :power_problem ->
        gettext("power problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :presence_of_whales ->
        gettext("presence of whales", comment: "Alert cause, used in 'Delays due to [cause]'")

      :rail_defect ->
        gettext("rail defect", comment: "Alert cause, used in 'Delays due to [cause]'")

      :rough_seas ->
        gettext("rough seas", comment: "Alert cause, used in 'Delays due to [cause]'")

      :severe_weather ->
        gettext("severe weather", comment: "Alert cause, used in 'Delays due to [cause]'")

      :signal_issue ->
        gettext("signal issue", comment: "Alert cause, used in 'Delays due to [cause]'")

      :signal_problem ->
        gettext("signal problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :single_tracking ->
        gettext("single tracking", comment: "Alert cause, used in 'Delays due to [cause]'")

      :slippery_rail ->
        gettext("slippery rail", comment: "Alert cause, used in 'Delays due to [cause]'")

      :snow ->
        gettext("snow", comment: "Alert cause, used in 'Delays due to [cause]'")

      :special_event ->
        gettext("special event", comment: "Alert cause, used in 'Delays due to [cause]'")

      :speed_restriction ->
        gettext("speed restriction", comment: "Alert cause, used in 'Delays due to [cause]'")

      :strike ->
        gettext("strike", comment: "Alert cause, used in 'Delays due to [cause]'")

      :switch_issue ->
        gettext("switch issue", comment: "Alert cause, used in 'Delays due to [cause]'")

      :switch_problem ->
        gettext("switch problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :technical_problem ->
        gettext("technical problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :tie_replacement ->
        gettext("tie replacement", comment: "Alert cause, used in 'Delays due to [cause]'")

      :track_problem ->
        gettext("track problem", comment: "Alert cause, used in 'Delays due to [cause]'")

      :track_work ->
        gettext("track work", comment: "Alert cause, used in 'Delays due to [cause]'")

      :traffic ->
        gettext("traffic", comment: "Alert cause, used in 'Delays due to [cause]'")

      :train_traffic ->
        gettext("train traffic", comment: "Alert cause, used in 'Delays due to [cause]'")

      :unruly_passenger ->
        gettext("unruly passenger", comment: "Alert cause, used in 'Delays due to [cause]'")

      :utility_work ->
        gettext("utility work", comment: "Alert cause, used in 'Delays due to [cause]'")

      :vessel_substitution ->
        gettext("vessel substitution", comment: "Alert cause, used in 'Delays due to [cause]'")

      :vessel_traffic ->
        gettext("vessel traffic", comment: "Alert cause, used in 'Delays due to [cause]'")

      :weather ->
        gettext("weather", comment: "Alert cause, used in 'Delays due to [cause]'")

      _ ->
        nil
    end
  end

  @spec cause(Alert.cause()) :: String.t() | nil
  def cause(cause) do
    case cause do
      :accident ->
        gettext("Accident", comment: "Possible alert cause")

      :amtrak ->
        gettext("Amtrak", comment: "Possible alert cause")

      :amtrak_train_traffic ->
        gettext("Amtrak Train Traffic", comment: "Possible alert cause")

      :an_earlier_mechanical_problem ->
        gettext("An Earlier Mechanical Problem", comment: "Possible alert cause")

      :an_earlier_signal_problem ->
        gettext("An Earlier Signal Problem", comment: "Possible alert cause")

      :autos_impeding_service ->
        gettext("Autos Impeding Service", comment: "Possible alert cause")

      :coast_guard_restriction ->
        gettext("Coast Guard Restriction", comment: "Possible alert cause")

      :congestion ->
        gettext("Congestion", comment: "Possible alert cause")

      :construction ->
        gettext("Construction", comment: "Possible alert cause")

      :crossing_issue ->
        gettext("Crossing Issue", comment: "Possible alert cause")

      :crossing_malfunction ->
        gettext("Crossing Malfunction", comment: "Possible alert cause")

      :demonstration ->
        gettext("Demonstration", comment: "Possible alert cause")

      :disabled_bus ->
        gettext("Disabled Bus", comment: "Possible alert cause")

      :disabled_train ->
        gettext("Disabled Train", comment: "Possible alert cause")

      :drawbridge_being_raised ->
        gettext("Drawbridge Being Raised", comment: "Possible alert cause")

      :drawbridge_issue ->
        gettext("Drawbridge Issue", comment: "Possible alert cause")

      :electrical_work ->
        gettext("Electrical Work", comment: "Possible alert cause")

      :fire ->
        gettext("Fire", comment: "Possible alert cause")

      :fire_department_activity ->
        gettext("Fire Department Activity", comment: "Possible alert cause")

      :flooding ->
        gettext("Flooding", comment: "Possible alert cause")

      :fog ->
        gettext("Fog", comment: "Possible alert cause")

      :freight_train_interference ->
        gettext("Freight Train Interference", comment: "Possible alert cause")

      :hazmat_condition ->
        gettext("Hazmat Condition", comment: "Possible alert cause")

      :heavy_ridership ->
        gettext("Heavy Ridership", comment: "Possible alert cause")

      :high_winds ->
        gettext("High Winds", comment: "Possible alert cause")

      :holiday ->
        gettext("Holiday", comment: "Possible alert cause")

      :ice_in_harbor ->
        gettext("Ice In Harbor", comment: "Possible alert cause")

      :maintenance ->
        gettext("Maintenance", comment: "Possible alert cause")

      :mechanical_issue ->
        gettext("Mechanical Issue", comment: "Possible alert cause")

      :mechanical_problem ->
        gettext("Mechanical Problem", comment: "Possible alert cause")

      :medical_emergency ->
        gettext("Medical Emergency", comment: "Possible alert cause")

      :parade ->
        gettext("Parade", comment: "Possible alert cause")

      :police_activity ->
        gettext("Police Activity", comment: "Possible alert cause")

      :power_problem ->
        gettext("Power Problem", comment: "Possible alert cause")

      :presence_of_whales ->
        gettext("Presence of Whales", comment: "Possible alert cause")

      :rail_defect ->
        gettext("Rail Defect", comment: "Possible alert cause")

      :rough_seas ->
        gettext("Rough Seas", comment: "Possible alert cause")

      :severe_weather ->
        gettext("Severe Weather", comment: "Possible alert cause")

      :signal_issue ->
        gettext("Signal Issue", comment: "Possible alert cause")

      :signal_problem ->
        gettext("Signal Problem", comment: "Possible alert cause")

      :single_tracking ->
        gettext("Single Tracking", comment: "Possible alert cause")

      :slippery_rail ->
        gettext("Slippery Rail", comment: "Possible alert cause")

      :snow ->
        gettext("Snow", comment: "Possible alert cause")

      :special_event ->
        gettext("Special Event", comment: "Possible alert cause")

      :speed_restriction ->
        gettext("Speed Restriction", comment: "Possible alert cause")

      :strike ->
        gettext("Strike", comment: "Possible alert cause")

      :switch_issue ->
        gettext("Switch Issue", comment: "Possible alert cause")

      :switch_problem ->
        gettext("Switch Problem", comment: "Possible alert cause")

      :technical_problem ->
        gettext("Technical Problem", comment: "Possible alert cause")

      :tie_replacement ->
        gettext("Tie Replacement", comment: "Possible alert cause")

      :track_problem ->
        gettext("Track Problem", comment: "Possible alert cause")

      :track_work ->
        gettext("Track Work", comment: "Possible alert cause")

      :traffic ->
        gettext("Traffic", comment: "Possible alert cause")

      :train_traffic ->
        gettext("Train Traffic", comment: "Possible alert cause")

      :unruly_passenger ->
        gettext("Unruly Passenger", comment: "Possible alert cause")

      :utility_work ->
        gettext("Utility Work", comment: "Possible alert cause")

      :vessel_substitution ->
        gettext("Vessel Substitution", comment: "Possible alert cause")

      :vessel_traffic ->
        gettext("Vessel Traffic", comment: "Possible alert cause")

      :weather ->
        gettext("Weather", comment: "Possible alert cause")

      _ ->
        nil
    end
  end
end
