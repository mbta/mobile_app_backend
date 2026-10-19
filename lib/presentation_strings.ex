# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule MobileAppBackend.PresentationStrings do
  @moduledoc """
  Localized string descriptions of pieces of data from MBTAV3API.
  """
  use Gettext, backend: MobileAppBackend.Gettext

  alias MBTAV3API.Alert
  alias MBTAV3API.Route

  @type plurality :: :singular | :plural
  @type string_case :: :lower_case | :sentence_case

  @spec route_type(Route.type(), plurality(), string_case()) :: String.t()
  def route_type(:bus, :singular, :lower_case) do
    gettext_comment("bus")
    gettext("bus")
  end

  def route_type(:bus, :plural, :lower_case) do
    gettext_comment("buses")
    gettext("buses")
  end

  def route_type(:bus, :singular, :sentence_case) do
    gettext_comment("Label for bus routes in the route picker view")
    gettext("Bus")
  end

  def route_type(:bus, :plural, :sentence_case) do
    gettext_comment(~s|Mode of travel prefixing alert summary e.g.: "Buses will not stop at..."|)
    gettext("Buses")
  end

  def route_type(:ferry, :singular, :lower_case) do
    gettext_comment("ferry")
    gettext("ferry")
  end

  def route_type(:ferry, :plural, :lower_case) do
    gettext_comment("ferries")
    gettext("ferries")
  end

  def route_type(:ferry, :singular, :sentence_case) do
    gettext_comment("Label for ferry routes in the route picker view")
    gettext("Ferry")
  end

  def route_type(:ferry, :plural, :sentence_case) do
    gettext_comment(
      ~s|Mode of travel prefixing alert summary e.g.: "Ferries will not stop at..."|
    )

    gettext("Ferries")
  end

  def route_type(_train, :singular, :lower_case) do
    gettext_comment("train")
    gettext("train")
  end

  def route_type(_train, :plural, :lower_case) do
    gettext_comment("trains")
    gettext("trains")
  end

  def route_type(_train, :singular, :sentence_case) do
    gettext_comment("Train")
    gettext("Train")
  end

  def route_type(_train, :plural, :sentence_case) do
    gettext_comment(~s|Mode of travel prefixing alert summary e.g.: "Trains will not stop at..."|)
    gettext("Trains")
  end

  @spec mode_label(String.t(), Route.type()) :: String.t()
  def mode_label(name, route_type) do
    if route_type == :bus do
      gettext_comment(
        ~s|Bus route name label, with the value being the route number, ex. "1 bus", "66 bus"|
      )

      gettext("%{name} bus", name: name)
    else
      name
    end
  end

  @spec delay_duration(integer()) :: String.t()
  def delay_duration(severity) do
    case severity do
      3 ->
        gettext_comment("Ex: delays [of about 10 minutes]")
        gettext("of about 10 minutes")

      4 ->
        gettext_comment("Ex: delays [of about 15 minutes]")
        gettext("of about 15 minutes")

      5 ->
        gettext_comment("Ex: delays [of about 20 minutes]")
        gettext("of about 20 minutes")

      6 ->
        gettext_comment("Ex: delays [of about 25 minutes]")
        gettext("of about 25 minutes")

      7 ->
        gettext_comment("Ex: delays [of about 30 minutes]")
        gettext("of about 30 minutes")

      8 ->
        gettext_comment("Ex: delays [of more than 30 minutes]")
        gettext("of more than 30 minutes")

      9 ->
        gettext_comment("Ex: delays [of more than an hour]")
        gettext("of more than an hour")

      _ ->
        ""
    end
  end

  @spec effect_sentence_case(Alert.effect()) :: String.t()
  def effect_sentence_case(effect) do
    case effect do
      :access_issue ->
        gettext_comment("Possible alert effect")
        gettext("Access issue")

      :additional_service ->
        gettext_comment("Possible alert effect")
        gettext("Additional service")

      :amber_alert ->
        gettext_comment("Possible alert effect")
        gettext("Amber alert")

      :bike_issue ->
        gettext_comment("Possible alert effect")
        gettext("Bike issue")

      :cancellation ->
        gettext_comment("Header for a cancelled trip card on stop details")
        gettext_comment("Possible alert effect")
        gettext("Trip cancelled")

      :delay ->
        gettext_comment("Possible alert effect")
        gettext("Delay")

      :detour ->
        gettext_comment("Possible alert effect")
        gettext("Detour")

      :dock_closure ->
        gettext_comment("Possible alert effect")
        gettext("Dock closed")

      :dock_issue ->
        gettext_comment("Possible alert effect")
        gettext("Dock issue")

      :elevator_closure ->
        gettext_comment("Possible alert effect")
        gettext("Elevator closed")

      :escalator_closure ->
        gettext_comment("Possible alert effect")
        gettext("Escalator closed")

      :extra_service ->
        gettext_comment("Possible alert effect")
        gettext("Extra service")

      :facility_issue ->
        gettext_comment("Possible alert effect")
        gettext("Facility issue")

      :modified_service ->
        gettext_comment("Possible alert effect")
        gettext("Modified service")

      :no_service ->
        gettext_comment("Possible alert effect")
        gettext("No service")

      :notice ->
        gettext_comment("Possible alert effect")
        gettext("Notice")

      :parking_closure ->
        gettext_comment("Possible alert effect")
        gettext("Parking closed")

      :parking_issue ->
        gettext_comment("Possible alert effect")
        gettext("Parking issue")

      :policy_change ->
        gettext_comment("Possible alert effect")
        gettext("Policy change")

      :schedule_change ->
        gettext_comment("Possible alert effect")
        gettext("Schedule change")

      :service_change ->
        gettext_comment("Possible alert effect")
        gettext("Service change")

      :shuttle ->
        gettext_comment("Possible alert effect")
        gettext("Shuttle buses")

      :snow_route ->
        gettext_comment("Possible alert effect")
        gettext("Snow route")

      :station_closure ->
        gettext_comment("Possible alert effect")
        gettext("Station closed")

      :station_issue ->
        gettext_comment("Possible alert effect")
        gettext("Station issue")

      :stop_closure ->
        gettext_comment("Possible alert effect")
        gettext("Stop closed")

      :stop_move ->
        gettext_comment("Possible alert effect")
        gettext("Stop moved")

      :stop_moved ->
        gettext_comment("Possible alert effect")
        gettext("Stop moved")

      :stop_shoveling ->
        gettext_comment("Possible alert effect")
        gettext("Stop shoveling")

      :summary ->
        gettext_comment("Possible alert effect")
        gettext("Summary")

      :suspension ->
        gettext_comment("Possible alert effect")
        gettext_comment("Suspension alert VoiceOver text")
        gettext("Service suspended")

      :track_change ->
        gettext_comment("Possible alert effect")
        gettext("Track change")

      :other_effect ->
        gettext_comment("Possible alert effect")
        gettext("Alert")

      :unknown_effect ->
        gettext_comment("Possible alert effect")
        gettext("Alert")
    end
  end

  @spec effect(Alert.effect()) :: String.t()
  def effect(effect) do
    case effect do
      :access_issue ->
        gettext_comment("Possible alert effect")
        gettext("Access Issue")

      :additional_service ->
        gettext_comment("Possible alert effect")
        gettext("Additional Service")

      :amber_alert ->
        gettext_comment("Possible alert effect")
        gettext("Amber Alert")

      :bike_issue ->
        gettext_comment("Possible alert effect")
        gettext("Bike Issue")

      :cancellation ->
        gettext_comment("Possible alert effect")
        gettext("Cancellation")

      :delay ->
        gettext_comment("Possible alert effect")
        gettext("Delay")

      :detour ->
        gettext_comment("Possible alert effect")
        gettext("Detour")

      :dock_closure ->
        gettext_comment("Possible alert effect")
        gettext("Dock Closure")

      :dock_issue ->
        gettext_comment("Possible alert effect")
        gettext("Dock Issue")

      :elevator_closure ->
        gettext_comment("Possible alert effect")
        gettext("Elevator Closure")

      :escalator_closure ->
        gettext_comment("Possible alert effect")
        gettext("Escalator Closure")

      :extra_service ->
        gettext_comment("Possible alert effect")
        gettext("Extra Service")

      :facility_issue ->
        gettext_comment("Possible alert effect")
        gettext("Facility Issue")

      :modified_service ->
        gettext_comment("Possible alert effect")
        gettext("Modified Service")

      :no_service ->
        gettext_comment("Possible alert effect")
        gettext("No Service")

      :notice ->
        gettext_comment("Possible alert effect")
        gettext("Notice")

      :parking_closure ->
        gettext_comment("Possible alert effect")
        gettext("Parking Closure")

      :parking_issue ->
        gettext_comment("Possible alert effect")
        gettext("Parking Issue")

      :policy_change ->
        gettext_comment("Possible alert effect")
        gettext("Policy Change")

      :schedule_change ->
        gettext_comment("Possible alert effect")
        gettext("Schedule Change")

      :service_change ->
        gettext_comment("Possible alert effect")
        gettext("Service Change")

      :shuttle ->
        gettext_comment("Possible alert effect")
        gettext_comment("The status label for a shuttled trip")
        gettext("Shuttle")

      :snow_route ->
        gettext_comment("Possible alert effect")
        gettext("Snow Route")

      :station_closure ->
        gettext_comment("Possible alert effect")
        gettext("Station Closure")

      :station_issue ->
        gettext_comment("Possible alert effect")
        gettext("Station Issue")

      :stop_closure ->
        gettext_comment("Possible alert effect")
        gettext("Stop Closure")

      :stop_move ->
        gettext_comment("Possible alert effect")
        gettext("Stop Moved")

      :stop_moved ->
        gettext_comment("Possible alert effect")
        gettext("Stop Moved")

      :stop_shoveling ->
        gettext_comment("Possible alert effect")
        gettext("Stop Shoveling")

      :summary ->
        gettext_comment("Possible alert effect")
        gettext("Summary")

      :suspension ->
        gettext_comment("Possible alert effect")
        gettext("Suspension")

      :trackChange ->
        gettext_comment("Possible alert effect")
        gettext("Track Change")

      :other_effect ->
        gettext_comment("Possible alert effect")
        gettext("Alert")

      :unknown_effect ->
        gettext_comment("Possible alert effect")

        gettext_comment("Possible alert effect")
        gettext("Alert")
    end
  end

  @spec cause_lower_case(Alert.cause()) :: String.t() | nil
  def cause_lower_case(cause) do
    case cause do
      :accident ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("accident")

      :amtrak ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("Amtrak")

      :amtrak_train_traffic ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("Amtrak train traffic")

      :an_earlier_mechanical_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("an earlier mechanical problem")

      :an_earlier_signal_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("an earlier signal problem")

      :autos_impeding_service ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("autos impeding service")

      :coast_guard_restriction ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("Coast Guard restriction")

      :congestion ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("congestion")

      :construction ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("construction")

      :crossing_issue ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("crossing issue")

      :crossing_malfunction ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("crossing malfunction")

      :demonstration ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("demonstration")

      :disabled_bus ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("disabled bus")

      :disabled_train ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("disabled train")

      :drawbridge_being_raised ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("drawbridge being raised")

      :drawbridge_issue ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("drawbridge issue")

      :electrical_work ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("electrical work")

      :fire ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("fire")

      :fire_department_activity ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("fire department activity")

      :flooding ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("flooding")

      :fog ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("fog")

      :freight_train_interference ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("freight train interference")

      :hazmat_condition ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("hazmat condition")

      :heavy_ridership ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("heavy ridership")

      :high_winds ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("high winds")

      :holiday ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("holiday")

      :hurricane ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("hurricane")

      :ice_in_harbor ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("ice in harbor")

      :maintenance ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("maintenance")

      :mechanical_issue ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("mechanical issue")

      :mechanical_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("mechanical problem")

      :medical_emergency ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("medical emergency")

      :parade ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("parade")

      :police_action ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("police action")

      :police_activity ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("police activity")

      :power_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("power problem")

      :rail_defect ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("rail defect")

      :severe_weather ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("severe weather")

      :signal_issue ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("signal issue")

      :signal_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("signal problem")

      :single_tracking ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("single tracking")

      :slippery_rail ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("slippery rail")

      :snow ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("snow")

      :special_event ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("special event")

      :speed_restriction ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("speed restriction")

      :strike ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("strike")

      :switch_issue ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("switch issue")

      :switch_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("switch problem")

      :technical_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("technical problem")

      :tie_replacement ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("tie replacement")

      :track_problem ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("track problem")

      :track_work ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("track work")

      :traffic ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("traffic")

      :train_traffic ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("train traffic")

      :unruly_passenger ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("unruly passenger")

      :weather ->
        gettext_comment("Alert cause, used in 'Delays due to [cause]'")
        gettext("weather")

      _ ->
        nil
    end
  end

  @spec cause(Alert.cause()) :: String.t() | nil
  def cause(cause) do
    case cause do
      :accident ->
        gettext_comment("Possible alert cause")
        gettext("Accident")

      :amtrak ->
        gettext_comment("Possible alert cause")
        gettext("Amtrak")

      :amtrak_train_traffic ->
        gettext_comment("Possible alert cause")
        gettext("Amtrak Train Traffic")

      :an_earlier_mechanical_problem ->
        gettext_comment("Possible alert cause")
        gettext("An Earlier Mechanical Problem")

      :an_earlier_signal_problem ->
        gettext_comment("Possible alert cause")
        gettext("An Earlier Signal Problem")

      :autos_impeding_service ->
        gettext_comment("Possible alert cause")
        gettext("Autos Impeding Service")

      :coast_guard_restriction ->
        gettext_comment("Possible alert cause")
        gettext("Coast Guard Restriction")

      :congestion ->
        gettext_comment("Possible alert cause")
        gettext("Congestion")

      :construction ->
        gettext_comment("Possible alert cause")
        gettext("Construction")

      :crossing_issue ->
        gettext_comment("Possible alert cause")
        gettext("Crossing Issue")

      :crossing_malfunction ->
        gettext_comment("Possible alert cause")
        gettext("Crossing Malfunction")

      :demonstration ->
        gettext_comment("Possible alert cause")
        gettext("Demonstration")

      :disabled_bus ->
        gettext_comment("Possible alert cause")
        gettext("Disabled Bus")

      :disabled_train ->
        gettext_comment("Possible alert cause")
        gettext("Disabled Train")

      :drawbridge_being_raised ->
        gettext_comment("Possible alert cause")
        gettext("Drawbridge Being Raised")

      :drawbridge_issue ->
        gettext_comment("Possible alert cause")
        gettext("Drawbridge Issue")

      :electrical_work ->
        gettext_comment("Possible alert cause")
        gettext("Electrical Work")

      :fire ->
        gettext_comment("Possible alert cause")
        gettext("Fire")

      :fire_department_activity ->
        gettext_comment("Possible alert cause")
        gettext("Fire Department Activity")

      :flooding ->
        gettext_comment("Possible alert cause")
        gettext("Flooding")

      :fog ->
        gettext_comment("Possible alert cause")
        gettext("Fog")

      :freight_train_interference ->
        gettext_comment("Possible alert cause")
        gettext("Freight Train Interference")

      :hazmat_condition ->
        gettext_comment("Possible alert cause")
        gettext("Hazmat Condition")

      :heavy_ridership ->
        gettext_comment("Possible alert cause")
        gettext("Heavy Ridership")

      :high_winds ->
        gettext_comment("Possible alert cause")
        gettext("High Winds")

      :holiday ->
        gettext_comment("Possible alert cause")
        gettext("Holiday")

      :hurricane ->
        gettext_comment("Possible alert cause")
        gettext("Hurricane")

      :ice_in_harbor ->
        gettext_comment("Possible alert cause")
        gettext("Ice In Harbor")

      :maintenance ->
        gettext_comment("Possible alert cause")
        gettext("Maintenance")

      :mechanical_issue ->
        gettext_comment("Possible alert cause")
        gettext("Mechanical Issue")

      :mechanical_problem ->
        gettext_comment("Possible alert cause")
        gettext("Mechanical Problem")

      :medical_emergency ->
        gettext_comment("Possible alert cause")
        gettext("Medical Emergency")

      :parade ->
        gettext_comment("Possible alert cause")
        gettext("Parade")

      :police_action ->
        gettext_comment("Possible alert cause")
        gettext("Police Action")

      :police_activity ->
        gettext_comment("Possible alert cause")
        gettext("Police Activity")

      :power_problem ->
        gettext_comment("Possible alert cause")
        gettext("Power Problem")

      :rail_defect ->
        gettext_comment("Possible alert cause")
        gettext("Rail Defect")

      :severe_weather ->
        gettext_comment("Possible alert cause")
        gettext("Severe Weather")

      :signal_issue ->
        gettext_comment("Possible alert cause")
        gettext("Signal Issue")

      :signal_problem ->
        gettext_comment("Possible alert cause")
        gettext("Signal Problem")

      :single_tracking ->
        gettext_comment("Possible alert cause")
        gettext("Single Tracking")

      :slippery_rail ->
        gettext_comment("Possible alert cause")
        gettext("Slippery Rail")

      :snow ->
        gettext_comment("Possible alert cause")
        gettext("Snow")

      :special_event ->
        gettext_comment("Possible alert cause")
        gettext("Special Event")

      :speed_restriction ->
        gettext_comment("Possible alert cause")
        gettext("Speed Restriction")

      :strike ->
        gettext_comment("Possible alert cause")
        gettext("Strike")

      :switch_issue ->
        gettext_comment("Possible alert cause")
        gettext("Switch Issue")

      :switch_problem ->
        gettext_comment("Possible alert cause")
        gettext("Switch Problem")

      :technical_problem ->
        gettext_comment("Possible alert cause")
        gettext("Technical Problem")

      :tie_replacement ->
        gettext_comment("Possible alert cause")
        gettext("Tie Replacement")

      :track_problem ->
        gettext_comment("Possible alert cause")
        gettext("Track Problem")

      :track_work ->
        gettext_comment("Possible alert cause")
        gettext("Track Work")

      :traffic ->
        gettext_comment("Possible alert cause")
        gettext("Traffic")

      :train_traffic ->
        gettext_comment("Possible alert cause")
        gettext("Train Traffic")

      :unruly_passenger ->
        gettext_comment("Possible alert cause")
        gettext("Unruly Passenger")

      :weather ->
        gettext_comment("Possible alert cause")
        gettext("Weather")

      _ ->
        nil
    end
  end
end
