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

      :track_change ->
        gettext("Track Change", comment: "Possible alert effect")

      :other_effect ->
        gettext("Alert", comment: "Possible alert effect")

      :unknown_effect ->
        gettext("Alert", comment: "Possible alert effect")
    end
  end

  # Using alerts UI as the source of truth for articules
  # https://github.com/mbta/alerts_ui/blob/cc2fa6d28f28464abc15528ca789564c8eb50f45/lib/alerts_ui_web/live/form_components/helpers/auto_text/build_auto_text.ex#L62C4-L62C27
  @spec due_to_cause(Alert.cause()) :: String.t() | nil
  def due_to_cause(cause) do
    case cause do
      :accident ->
        gettext(" due to an accident", comment: "Alert cause, used in 'Delays [due to cause]'")

      :amtrak ->
        gettext(" due to Amtrak", comment: "Alert cause, used in 'Delays [due to cause]'")

      :amtrak_train_traffic ->
        gettext(" due to Amtrak train traffic",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :an_earlier_mechanical_problem ->
        gettext(" due to an earlier mechanical problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :an_earlier_signal_problem ->
        gettext(" due to an earlier signal problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :autos_impeding_service ->
        gettext(" due to autos impeding service",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :coast_guard_restriction ->
        gettext(" due to a Coast Guard restriction",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :congestion ->
        gettext(" due to congestion", comment: "Alert cause, used in 'Delays [due to cause]'")

      :construction ->
        gettext(" due to construction", comment: "Alert cause, used in 'Delays [due to cause]'")

      :crossing_issue ->
        gettext(" due to a crossing issue",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :crossing_malfunction ->
        #
        gettext(" due to crossing malfunction",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :demonstration ->
        gettext(" due to a demonstration",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :disabled_bus ->
        gettext(" due to a disabled bus", comment: "Alert cause, used in 'Delays [due to cause]'")

      :disabled_train ->
        gettext(" due to a disabled train",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :drawbridge_being_raised ->
        gettext(" due to a drawbridge being raised",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :drawbridge_issue ->
        gettext(" due to a drawbridge issue",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :electrical_work ->
        gettext(" due to electrical work",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :fire ->
        gettext(" due to a fire", comment: "Alert cause, used in 'Delays [due to cause]'")

      :fire_department_activity ->
        gettext(" due to fire department activity",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :flooding ->
        gettext(" due to flooding", comment: "Alert cause, used in 'Delays [due to cause]'")

      :fog ->
        gettext(" due to fog", comment: "Alert cause, used in 'Delays [due to cause]'")

      :freight_train_interference ->
        gettext(" due to freight train interference",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :hazmat_condition ->
        gettext(" due to a hazmat condition",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :heavy_ridership ->
        gettext(" due to heavy ridership",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :high_winds ->
        gettext(" due to high winds", comment: "Alert cause, used in 'Delays [due to cause]'")

      :holiday ->
        gettext(" due to the holiday", comment: "Alert cause, used in 'Delays [due to cause]'")

      :hurricane ->
        gettext(" due to a hurricane", comment: "Alert cause, used in 'Delays [due to cause]'")

      :ice_in_harbor ->
        gettext(" due to ice in harbor", comment: "Alert cause, used in 'Delays [due to cause]'")

      :maintenance ->
        gettext(" due to maintenance", comment: "Alert cause, used in 'Delays [due to cause]'")

      :mechanical_issue ->
        gettext(" due to a mechanical issue",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :mechanical_problem ->
        gettext(" due to a mechanical problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :medical_emergency ->
        gettext(" due to a medical emergency",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :parade ->
        gettext(" due to a parade", comment: "Alert cause, used in 'Delays [due to cause]'")

      :police_activity ->
        gettext(" due to police activity",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :power_problem ->
        gettext(" due to a power problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :presence_of_whales ->
        gettext(" due to presence of whales",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :rail_defect ->
        gettext(" due to a rail defect", comment: "Alert cause, used in 'Delays [due to cause]'")

      :rough_seas ->
        gettext(" due to rough seas", comment: "Alert cause, used in 'Delays [due to cause]'")

      :severe_weather ->
        gettext(" due to severe weather", comment: "Alert cause, used in 'Delays [due to cause]'")

      :signal_issue ->
        gettext(" due to a signal issue", comment: "Alert cause, used in 'Delays [due to cause]'")

      :signal_problem ->
        gettext(" due to a signal problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :single_tracking ->
        gettext(" due to single tracking",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :slippery_rail ->
        gettext(" due to a slippery rail",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :snow ->
        gettext(" due to snow", comment: "Alert cause, used in 'Delays [due to cause]'")

      :special_event ->
        gettext(" due to a special event",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :speed_restriction ->
        gettext(" due to a speed restriction",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :strike ->
        gettext(" due to strike", comment: "Alert cause, used in 'Delays [due to cause]'")

      :switch_issue ->
        gettext(" due to a switch issue", comment: "Alert cause, used in 'Delays [due to cause]'")

      :switch_problem ->
        gettext(" due to a switch problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :technical_problem ->
        gettext(" due to technical problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :tie_replacement ->
        gettext(" due to tie replacement",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :track_problem ->
        gettext(" due to a track problem",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :track_work ->
        gettext(" due to track work", comment: "Alert cause, used in 'Delays [due to cause]'")

      :traffic ->
        gettext(" due to traffic", comment: "Alert cause, used in 'Delays [due to cause]'")

      :train_traffic ->
        gettext(" due to train traffic", comment: "Alert cause, used in 'Delays [due to cause]'")

      :unruly_passenger ->
        gettext(" due to an unruly passenger",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :utility_work ->
        gettext(" due to utility work", comment: "Alert cause, used in 'Delays [due to cause]'")

      :vessel_substitution ->
        gettext(" due to vessel substitution",
          comment: "Alert cause, used in 'Delays [due to cause]'"
        )

      :vessel_traffic ->
        gettext(" due to vessel traffic", comment: "Alert cause, used in 'Delays [due to cause]'")

      :weather ->
        gettext(" due to weather", comment: "Alert cause, used in 'Delays [due to cause]'")

      _ ->
        nil
    end
  end
end
