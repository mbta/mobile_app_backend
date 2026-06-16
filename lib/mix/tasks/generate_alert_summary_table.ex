# use of Mox makes injecting mock data via the Repository substantially easier,
# so don’t even try to compile this in the dev environment where Mox is unavailable
if Mix.env() == :test do
  defmodule Mix.Tasks.GenerateAlertSummaryTable do
    @moduledoc """
    Generates a .csv export of alert summaries in some specific cases.

    Usage:

        mix generate_alert_summary_table > alert_summary_table.csv
    """
    alias MBTAV3API.Alert
    alias MobileAppBackend.GlobalDataCache
    alias MobileAppBackend.Notifications
    alias MobileAppBackend.Repo
    use Mix.Task
    @shortdoc "Exports some alert summaries"
    @requirements ["app.start"]

    defmodule Scenario do
      alias MobileAppBackend.Notifications.Engine.OutgoingNotification

      @type t :: %__MODULE__{
              name: String.t(),
              alert: Alert.t(),
              subscriptions: [Notifications.Subscription.t()],
              at_time: DateTime.t(),
              schedules: [MBTAV3API.Schedule.t()],
              trips: [MBTAV3API.Trip.t()]
            }
      defstruct [:name, :alert, :subscriptions, :at_time, :schedules, :trips]

      @spec outgoing(t()) :: OutgoingNotification.Localized.t()
      def outgoing(%__MODULE__{} = scenario) do
        real_repo =
          Application.get_env(
            :mobile_app_backend,
            MBTAV3API.Repository,
            MBTAV3API.Repository.Impl
          )

        Application.put_env(:mobile_app_backend, MBTAV3API.Repository, RepositoryMock)

        Mox.stub(
          RepositoryMock,
          :schedules,
          fn [filter: [trip: trip_filter], include: :trip, sort: {:stop_sequence, :asc}], [] ->
            schedules = Enum.sort_by(scenario.schedules, & &1.stop_sequence)
            trips = Map.new(scenario.trips, &{&1.id, &1})

            if Enum.sort(trip_filter) != Enum.sort(Map.keys(trips)) do
              raise "Expected trip filter #{inspect(Map.keys(trips))} but got trip filter #{inspect(trip_filter)}"
            end

            {:ok, %{data: schedules, included: %{trips: trips}}}
          end
        )

        Mox.stub(
          RepositoryMock,
          :trips,
          fn [filter: [id: trip_id]], [] ->
            {:ok, %{data: Enum.filter(scenario.trips, &(&1.id == trip_id))}}
          end
        )

        [outgoing_notification] =
          Notifications.Engine.notifications(
            scenario.subscriptions,
            [scenario.alert],
            scenario.at_time
          )

        Application.put_env(:mobile_app_backend, MBTAV3API.Repository, real_repo)

        OutgoingNotification.localize(outgoing_notification, "en")
      end
    end

    @impl Mix.Task
    def run(_) do
      Mox.defmock(RepositoryMock, for: MBTAV3API.Repository)

      # warm up the cache
      _ = GlobalDataCache.get_data()

      IO.puts("scenario,notification title,notification body")

      for scenario <- scenarios() do
        notification = Scenario.outgoing(scenario)
        IO.puts(~s|"#{scenario.name}","#{notification.title}","#{notification.body}"|)
      end

      if Mix.env() == :test do
        Repo.delete_all(MobileAppBackend.User)
        Repo.delete_all(Notifications.DeliveredNotification)
      end
    end

    defp scenarios do
      [
        here_and_now(),
        here_and_now_os_notification(),
        here_and_now_os_notification_multiple_routes(),
        here_and_now_rl_shuttle(),
        here_and_now_gl(),
        here_and_now_gl_d(),
        here_and_now_bus_stop_skipped(),
        here_and_now_bus_detour(),
        here_and_now_bus_snow_route(),
        here_and_now_cr(),
        here_and_now_ferry(),
        downstream_ol(),
        downstream_gl(),
        upcoming_tomorrow(),
        upcoming_today(),
        subway_delay(),
        recurring_upcoming(),
        recurring_now(),
        recurring_last_day(),
        recurring_some_days(),
        update(),
        all_clear(),
        cr_cancel_one(),
        ferry_cancel_one(),
        ferry_cancel_two(),
        ferry_cancel_all(),
        suspension_ol(),
        suspension_gl(),
        shuttle_ol(),
        shuttle_gl(),
        stop_closed_ol(),
        stop_closed_gl(),
        service_change_ol(),
        service_change_gl(),
        cr_trip_suspended_here(),
        cr_trip_suspended_downstream(),
        cr_trip_shuttle_here(),
        cr_trip_shuttle_downstream(),
        cr_trip_station_bypass_here(),
        cr_trip_station_bypass_downstream()
      ]
    end

    defp here_and_now do
      wednesday_noon = ~N[2026-06-10 12:00:00]

      scenario("Here + Now", wednesday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(cause: :maintenance, effect: :suspension)
      |> active_period({-2, :days}, {2, :days})
      |> informed_entity(stops: ["place-rugg", "place-rcmnl", "place-jaksn"])
    end

    defp here_and_now_os_notification do
      friday_noon = ~N[2026-06-12 12:00:00]

      scenario("Here + Now (OS Notification)", friday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 1)
      |> alert(effect: :suspension)
      |> active_period({-2, :days}, {2, :days})
      |> informed_entity(
        stops: [
          "place-bbsta",
          "place-tumnl",
          "place-chncl",
          "place-dwnxg",
          "place-state",
          "place-haecl",
          "place-north",
          "place-ccmnl",
          "place-sull",
          "place-astao",
          "place-welln"
        ]
      )
    end

    defp here_and_now_os_notification_multiple_routes do
      wednesday_noon = ~N[2026-06-10 12:00:00]

      scenario("Here + Now (OS Notification, Multiple Routes)", wednesday_noon)
      |> subscription(route: "Orange", stop: "place-north", direction: 0)
      |> subscription(route: "line-Green", stop: "place-north", direction: 0)
      |> alert(effect: :station_closure)
      |> active_period({-2, :days}, {2, :days})
      |> informed_entity(routes: ["Orange", "Green-D", "Green-E"], stops: ["place-north"])
    end

    defp here_and_now_rl_shuttle do
      scenario("Here + Now (RL/Shuttle/StopToDirection/LaterToday)", ~T[12:00:00])
      |> subscription(route: "Red", stop: "place-jfk", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period(:service_start, ~T[23:00:00])
      |> informed_entity(stops: ["place-andrw", "place-jfk", "place-shmnl", "place-nqncy"])
    end

    defp here_and_now_gl do
      scenario("Here + Now (GL/DirectionToStop/EndOfService)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-kencl", direction: 1)
      |> alert(effect: :service_change)
      |> active_period(:service_start, :service_end)
      |> informed_entity(route: "Green-B", stops: ["place-hymnl", "place-kencl", "place-bland"])
      |> informed_entity(route: "Green-C", stops: ["place-hymnl", "place-kencl", "place-smary"])
      |> informed_entity(route: "Green-D", stops: ["place-hymnl", "place-kencl", "place-fenwy"])
    end

    defp here_and_now_gl_d do
      scenario("Here + Now (GL-D/StopSkipped)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-rsmnl", direction: 1)
      |> alert(effect: :station_closure)
      |> active_period(:service_start, {1, :day})
      |> informed_entity(route: "Green-D", stop: "place-rsmnl")
    end

    defp here_and_now_bus_stop_skipped do
      scenario("Here + Now (Bus/StopSkipped)", ~T[12:00:00])
      |> subscription(route: "86", stop: "1042", direction: 0)
      |> alert(effect: :stop_closure)
      |> active_period(:service_start, nil)
      |> informed_entity(stop: "1042")
    end

    defp here_and_now_bus_detour do
      scenario("Here + Now (Bus detour at specific stops)", ~T[12:00:00])
      |> subscription(route: "708", stop: "10015", direction: 0)
      |> alert(effect: :detour, duration_certainty: :estimated)
      |> active_period(:service_start, {2, :hours})
      |> informed_entity(stops: ["10014", "10015", "1790"])
    end

    defp here_and_now_bus_snow_route do
      scenario("Here + Now (Bus snow route at all stops)", ~T[12:00:00])
      |> subscription(route: "741", stop: "place-wtcst", direction: 0)
      |> alert(effect: :snow_route, duration_certainty: :estimated)
      |> active_period(:service_start, {2, :hours})
      |> informed_entity()
    end

    defp here_and_now_cr do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Here + Now (CR)", monday_noon)
      |> subscription(route: "CR-Worcester", stop: "place-WML-0147", direction: 0)
      |> alert(effect: :station_closure)
      |> active_period(:service_start, ~N[2026-07-01 03:00:00])
      |> informed_entity(stop: "place-WML-0147")
    end

    defp here_and_now_ferry do
      scenario("Here + Now (Ferry)", ~T[12:00:00])
      |> subscription(route: "Boat-F2H", stop: "Boat-Logan", direction: 0)
      |> alert(effect: :dock_closure, duration_certainty: :estimated)
      |> active_period(:service_start, {2, :hours})
      |> informed_entity(stop: "Boat-Logan")
    end

    defp downstream_ol do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Downstream (OL)", monday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period(:service_start, {4, :days})
      |> informed_entity(stops: ["place-rcmnl", "place-jaksn", "place-sbmnl", "place-grnst"])
    end

    defp downstream_gl do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Downstream (GL)", monday_noon)
      |> subscription(route: "line-Green", stop: "place-boyls", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period(:service_start, {4, :days})
      |> informed_entity(
        route: "Green-B",
        stops: ["place-bland", "place-buest", "place-bucen", "place-amory", "place-babck"]
      )
    end

    defp upcoming_tomorrow do
      scenario("Upcoming (Tomorrow)", ~T[12:00:00])
      |> subscription(route: "Orange", stop: "place-sbmnl", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period([{1, :day}, {-1, :hour}], {2, :days})
      |> informed_entity(
        stops: ["place-rcmnl", "place-jaksn", "place-sbmnl", "place-grnst", "place-forhl"]
      )
    end

    defp upcoming_today do
      scenario("Upcoming (Today)", ~T[12:00:00])
      |> subscription(route: "Orange", stop: "place-sbmnl", direction: 0)
      |> alert(effect: :suspension)
      |> active_period(~T[20:45:00], :service_end)
      |> informed_entity(stop: "place-sbmnl")
    end

    defp subway_delay do
      scenario("Subway Delay", ~T[12:00:00])
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(cause: :accident, effect: :delay, severity: 8, duration_certainty: :estimated)
      |> active_period({-1, :hour}, {2, :hours})
      |> informed_entity()
    end

    defp recurring_upcoming do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Recurring (Upcoming)", monday_noon)
      |> subscription(route: "Red", stop: "place-qamnl", direction: 0)
      |> alert(effect: :delay, cause: :single_tracking)
      |> active_period(~T[21:00:00], :service_end)
      |> active_period([{1, :day}, ~T[21:00:00]], [{1, :day}, :service_end])
      |> active_period([{2, :days}, ~T[21:00:00]], [{2, :days}, :service_end])
      |> active_period([{3, :days}, ~T[21:00:00]], [{3, :days}, :service_end])
      |> active_period([{4, :days}, ~T[21:00:00]], [{4, :days}, :service_end])
      |> informed_entity(stops: ["place-qamnl", "place-brntn"])
    end

    defp recurring_now do
      monday_ten_pm = ~N[2026-06-15 22:00:00]

      scenario("Recurring (Now)", monday_ten_pm)
      |> subscription(route: "Red", stop: "place-qamnl", direction: 0)
      |> alert(effect: :delay, cause: :single_tracking)
      |> active_period(~T[21:00:00], :service_end)
      |> active_period([{1, :day}, ~T[21:00:00]], [{1, :day}, :service_end])
      |> active_period([{2, :day}, ~T[21:00:00]], [{2, :days}, :service_end])
      |> active_period([{3, :day}, ~T[21:00:00]], [{3, :days}, :service_end])
      |> active_period([{4, :day}, ~T[21:00:00]], [{4, :days}, :service_end])
      |> informed_entity(stops: ["place-qamnl", "place-brntn"])
    end

    defp recurring_last_day do
      friday_noon = ~N[2026-06-19 12:00:00]

      scenario("Recurring (Last Day)", friday_noon)
      |> subscription(route: "Red", stop: "place-qamnl", direction: 0)
      |> alert(effect: :delay, cause: :single_tracking)
      |> active_period([{-4, :days}, ~T[21:00:00]], [{-4, :days}, :service_end])
      |> active_period([{-3, :days}, ~T[21:00:00]], [{-3, :days}, :service_end])
      |> active_period([{-2, :days}, ~T[21:00:00]], [{-2, :days}, :service_end])
      |> active_period([{-1, :days}, ~T[21:00:00]], [{-1, :days}, :service_end])
      |> active_period(~T[21:00:00], :service_end)
      |> informed_entity(stops: ["place-qamnl", "place-brntn"])
    end

    defp recurring_some_days do
      monday_ten_pm = ~N[2026-06-15 22:00:00]

      scenario("Recurring (Some Days)", monday_ten_pm)
      |> subscription(route: "Red", stop: "place-qamnl", direction: 0)
      |> alert(effect: :delay, cause: :single_tracking)
      |> active_period(~T[21:00:00], :service_end)
      |> active_period([{2, :days}, ~T[21:00:00]], [{2, :days}, :service_end])
      |> active_period([{4, :days}, ~T[21:00:00]], [{4, :days}, :service_end])
      |> informed_entity(stops: ["place-qamnl", "place-brntn"])
    end

    defp update do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Update", monday_noon)
      |> subscription(route: "line-Green", stop: "place-bland", direction: 0)
      |> alert(effect: :suspension, updated_at: {-1, :minute})
      |> active_period({-1, :hour}, {4, :days})
      |> informed_entity(route: "Green-B", stops: ["place-bland", "place-buest"])
      |> prior_delivered_notification()
    end

    defp all_clear do
      scenario("All Clear", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-chill", direction: 0)
      |> alert(
        effect: :suspension,
        closed_timestamp: {-1, :minute},
        last_push_notification_timestamp: {-1, :minute}
      )
      |> informed_entity(
        route: "Green-B",
        stops: [
          "place-wascm",
          "place-sthld",
          "place-chswk",
          "place-chill",
          "place-sougr",
          "place-lake"
        ]
      )
      |> prior_delivered_notification()
    end

    defp cr_cancel_one do
      scenario("Cancellation (CR)", ~T[12:00:00])
      |> subscription(route: "CR-Worcester", stop: "place-WML-0214", direction: 1)
      |> alert(cause: :mechanical_issue, effect: :cancellation)
      |> active_period(~T[18:30:00], ~T[19:30:00])
      |> trip(id: "some_trip", stops: [{"place-WML-0214", ~T[19:00:00]}])
      |> informed_entity(trip: "some_trip")
    end

    defp ferry_cancel_one do
      scenario("Cancellation (Ferry)", ~T[09:10:00])
      |> subscription(route: "Boat-Lynn", stop: "Boat-Blossom", direction: 1)
      |> alert(cause: :weather, effect: :cancellation)
      |> active_period(~T[08:50:00], ~T[09:50:00])
      |> trip(id: "some_trip", stops: [{"Boat-Blossom", ~T[09:20:00]}])
      |> informed_entity(trip: "some_trip")
    end

    defp ferry_cancel_two do
      scenario("Cancellation (Ferry, two trips)", ~T[13:12:00])
      |> subscription(route: "Boat-Lynn", stop: "Boat-Blossom", direction: 1)
      |> alert(cause: :weather, effect: :cancellation)
      |> active_period(~T[16:30:00], ~T[19:00:00])
      |> trip(id: "some_trip", stops: [{"Boat-Blossom", ~T[17:00:00]}])
      |> trip(id: "other_trip", stops: [{"Boat-Blossom", ~T[18:30:00]}])
      |> informed_entity(trips: ["some_trip", "other_trip"])
    end

    defp ferry_cancel_all do
      scenario("Cancellation (Ferry, all trips)", ~T[13:14:00])
      |> subscription(route: "Boat-Lynn", stop: "Boat-Blossom", direction: 1)
      |> alert(cause: :weather, effect: :cancellation)
      |> active_period(~T[13:14:00], :service_end)
      |> informed_entity()
    end

    defp suspension_ol do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Suspension (OL)", monday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(effect: :suspension)
      |> active_period({-1, :hour}, {4, :days})
      |> informed_entity(stops: ["place-rugg", "place-rcmnl", "place-jaksn"])
    end

    defp suspension_gl do
      scenario("Suspension (GL)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-clmnl", direction: 1)
      |> alert(effect: :suspension)
      |> active_period({-1, :hour}, :service_end)
      |> informed_entity(route: "Green-C")
    end

    defp shuttle_ol do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Shuttle (OL)", monday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period({-1, :hour}, {4, :days})
      |> informed_entity(stops: ["place-rugg", "place-rcmnl", "place-jaksn"])
    end

    defp shuttle_gl do
      scenario("Shuttle (GL)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-clmnl", direction: 1)
      |> alert(effect: :shuttle)
      |> active_period({-1, :hour}, :service_end)
      |> informed_entity(route: "Green-C")
    end

    defp stop_closed_ol do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Stop closed (OL)", monday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(effect: :station_closure)
      |> active_period({-1, :hour}, {4, :days})
      |> informed_entity(stops: ["place-rugg", "place-rcmnl", "place-jaksn"])
    end

    defp stop_closed_gl do
      scenario("Stop closed (GL)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-clmnl", direction: 1)
      |> alert(effect: :station_closure)
      |> active_period({-1, :hour}, :service_end)
      |> informed_entity(route: "Green-C")
    end

    defp service_change_ol do
      monday_noon = ~N[2026-06-15 12:00:00]

      scenario("Service change (OL)", monday_noon)
      |> subscription(route: "Orange", stop: "place-rugg", direction: 0)
      |> alert(effect: :service_change)
      |> active_period({-1, :hour}, {4, :days})
      |> informed_entity(stops: ["place-rugg", "place-rcmnl", "place-jaksn"])
    end

    defp service_change_gl do
      scenario("Service change (GL)", ~T[12:00:00])
      |> subscription(route: "line-Green", stop: "place-clmnl", direction: 1)
      |> alert(effect: :service_change)
      |> active_period({-1, :hour}, :service_end)
      |> informed_entity(route: "Green-C")
    end

    defp cr_trip_suspended_here do
      scenario("CR Trip Suspension", ~T[12:00:00])
      |> subscription(route: "CR-Providence", stop: "place-rugg", direction: 0)
      |> alert(cause: :mechanical_issue, effect: :suspension)
      |> active_period(~T[12:00:00], ~T[12:30:00])
      |> trip(id: "some_trip", stops: [{"place-rugg", ~T[12:13:00]}])
      |> informed_entity(trip: "some_trip")
    end

    defp cr_trip_suspended_downstream do
      scenario("CR Trip Suspension Downstream", ~T[11:00:00])
      |> subscription(route: "CR-Fitchburg", stop: "place-FR-0201", direction: 1)
      |> alert(cause: :weather, effect: :suspension)
      |> active_period(~T[11:00:00], ~T[12:00:00])
      |> trip(id: "some_trip", stops: [{"place-FR-0201", ~T[11:15:00]}])
      |> informed_entity(trip: "some_trip", stops: ["place-portr", "place-north"])
    end

    defp cr_trip_shuttle_here do
      scenario("CR Trip Shuttle", ~T[12:00:00])
      |> subscription(route: "CR-Providence", stop: "place-rugg", direction: 0)
      |> alert(effect: :shuttle)
      |> active_period(~T[12:00:00], ~T[12:30:00])
      |> trip(id: "some_trip", stops: [{"place-rugg", ~T[12:13:00]}])
      |> informed_entity(trip: "some_trip", stops: ["place-rugg", "place-forhl"])
    end

    defp cr_trip_shuttle_downstream do
      scenario("CR Trip Shuttle Downstream", ~T[11:00:00])
      |> subscription(route: "CR-Fitchburg", stop: "place-FR-0201", direction: 1)
      |> alert(effect: :shuttle)
      |> active_period(~T[11:00:00], ~T[12:00:00])
      |> trip(id: "some_trip", stops: [{"place-FR-0201", ~T[11:15:00]}])
      |> informed_entity(trip: "some_trip", stops: ["place-portr", "place-north"])
    end

    defp cr_trip_station_bypass_here do
      scenario("CR Trip Station Bypass", ~T[12:00:00])
      |> subscription(route: "CR-Providence", stop: "place-rugg", direction: 0)
      |> alert(effect: :station_closure)
      |> active_period(~T[12:00:00], ~T[12:30:00])
      |> trip(
        id: "some_trip",
        headsign: "Stoughton",
        stops: [{"place-rugg", ~T[12:13:00]}]
      )
      |> informed_entity(trip: "some_trip", stops: ["place-bbsta", "place-rugg"])
    end

    defp cr_trip_station_bypass_downstream do
      scenario("CR Trip Station Bypass Downstream", ~T[11:00:00])
      |> subscription(route: "CR-Fitchburg", stop: "place-FR-0201", direction: 1)
      |> alert(effect: :station_closure)
      |> active_period(~T[11:00:00], ~T[12:00:00])
      |> trip(
        id: "some_trip",
        headsign: "North Station",
        stops: [{"place-FR-0201", ~T[11:15:00]}]
      )
      |> informed_entity(trip: "some_trip", stops: ["place-portr"])
    end

    defp scenario(name, at_time) do
      %Scenario{
        name: name,
        alert: %Alert{
          active_period: [],
          cause: :unknown_cause,
          duration_certainty: :known,
          effect: :unknown_effect,
          id: to_string(System.unique_integer()),
          informed_entity: [],
          last_push_notification_timestamp: t(~N[2000-01-01 00:00:00]),
          lifecycle: :new,
          severity: 9,
          updated_at: t(~N[2000-01-01 00:00:00])
        },
        subscriptions: [],
        at_time: t(at_time),
        schedules: [],
        trips: []
      }
    end

    defp subscription(%Scenario{} = scenario, opts) do
      route = Keyword.fetch!(opts, :route)
      stop = Keyword.fetch!(opts, :stop)
      direction = Keyword.fetch!(opts, :direction)

      user_id =
        case scenario.subscriptions do
          [%Notifications.Subscription{user_id: user_id}] -> user_id
          [] -> :rand.uniform(2 ** 32)
        end

      subscription = %Notifications.Subscription{
        user_id: user_id,
        route_id: route,
        stop_id: stop,
        direction_id: direction,
        include_accessibility: true,
        windows: [
          %Notifications.Window{
            days_of_week: [1, 2, 3, 4, 5, 6, 7],
            start_time: ~T[00:00:00],
            end_time: ~T[23:59:59]
          }
        ]
      }

      update_in(scenario.subscriptions, &(&1 ++ [subscription]))
    end

    defp alert(%Scenario{} = scenario, opts) do
      opts =
        Keyword.new(opts, fn
          {k, v} when k in [:closed_timestamp, :last_push_notification_timestamp, :updated_at] ->
            {k, t(v, scenario.at_time)}

          {k, v} ->
            {k, v}
        end)

      %Scenario{scenario | alert: struct!(scenario.alert, opts)}
    end

    defp active_period(%Scenario{} = scenario, ap_start, ap_end) do
      update_in(
        scenario.alert.active_period,
        &(&1 ++
            [
              %Alert.ActivePeriod{
                start: t(ap_start, scenario.at_time),
                end: t(ap_end, scenario.at_time)
              }
            ])
      )
    end

    defp trip(%Scenario{} = scenario, opts) do
      id = Keyword.fetch!(opts, :id)

      route = Keyword.get_lazy(opts, :route, fn -> hd(scenario.subscriptions).route_id end)

      direction =
        Keyword.get_lazy(opts, :direction, fn -> hd(scenario.subscriptions).direction_id end)

      schedules =
        for {{stop_id, time}, index} <- Enum.with_index(Keyword.fetch!(opts, :stops)) do
          time = t(time, scenario.at_time)

          %MBTAV3API.Schedule{
            arrival_time: time,
            departure_time: time,
            stop_sequence: index,
            route_id: route,
            stop_id: stop_id,
            trip_id: id
          }
        end

      trip = %MBTAV3API.Trip{
        id: id,
        direction_id: direction,
        headsign: Keyword.get(opts, :headsign),
        route_id: route
      }

      %Scenario{
        scenario
        | schedules: schedules ++ scenario.schedules,
          trips: [trip | scenario.trips]
      }
    end

    defp informed_entity(%Scenario{} = scenario, opts \\ []) do
      global = GlobalDataCache.get_data()

      get_list_from_opts = fn singular_key, plural_key ->
        cond do
          list = opts[plural_key] -> list
          one = opts[singular_key] -> [one]
          true -> [nil]
        end
      end

      activities = Keyword.get(opts, :activities, ~w(board exit ride)a)

      directions = get_list_from_opts.(:direction, :directions)
      facilities = get_list_from_opts.(:facility, :facilities)

      routes =
        case get_list_from_opts.(:route, :routes) do
          [nil] -> [hd(scenario.subscriptions).route_id]
          routes -> routes
        end

      stops =
        get_list_from_opts.(:stop, :stops)
        |> Enum.flat_map(fn
          nil -> [nil]
          stop -> children(stop)
        end)

      trips = get_list_from_opts.(:trip, :trips)

      new_informed_entities =
        for direction <- directions,
            facility <- facilities,
            route <- routes,
            stop <- stops,
            trip <- trips do
          route_type = global.routes[route].type

          %Alert.InformedEntity{
            activities: activities,
            direction_id: direction,
            facility: facility,
            route: route,
            route_type: route_type,
            stop: stop,
            trip: trip
          }
        end

      update_in(scenario.alert.informed_entity, &(&1 ++ new_informed_entities))
    end

    defp prior_delivered_notification(%Scenario{} = scenario) do
      user_id = hd(scenario.subscriptions).user_id

      if is_nil(Repo.get(MobileAppBackend.User, user_id)) do
        Repo.insert!(%MobileAppBackend.User{
          id: user_id,
          fcm_token: "not-a-real-token-#{user_id}",
          fcm_last_verified: ~U[2000-01-01 00:00:00Z]
        })
      end

      Repo.insert!(%Notifications.DeliveredNotification{
        user_id: user_id,
        alert_id: scenario.alert.id,
        upstream_timestamp:
          scenario.alert.last_push_notification_timestamp |> DateTime.shift_zone!("Etc/UTC"),
        type: :notification
      })

      scenario
    end

    # converts some broad description of a time to a DateTime in the correct time zone
    defp t(time, base_time \\ DateTime.now!("America/New_York"))
    defp t(nil, _), do: nil
    defp t(:service_start, base_time), do: t(~T[03:00:00], base_time)
    defp t(:service_end, base_time), do: t(~T[03:00:00], base_time) |> DateTime.add(1, :day)
    defp t(%NaiveDateTime{} = t, _), do: DateTime.from_naive!(t, "America/New_York")

    defp t(%Time{} = t, base_time) do
      today = DateTime.to_date(base_time)
      DateTime.new!(today, t, "America/New_York")
    end

    defp t({amount, unit}, base_time) do
      unit =
        case unit do
          :days -> :day
          :hours -> :hour
          :minutes -> :minute
          unit -> unit
        end

      DateTime.add(base_time, amount, unit)
    end

    defp t(opts, base_time) when is_list(opts) do
      Enum.reduce(opts, base_time, &t/2)
    end

    defp children(stop_id) do
      global = GlobalDataCache.get_data()

      [
        stop_id
        | global.stops[stop_id].child_stop_ids
          |> Enum.filter(&Map.has_key?(global.stops, &1))
      ]
    end
  end
end
