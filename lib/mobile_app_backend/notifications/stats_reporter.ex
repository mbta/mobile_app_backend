defmodule MobileAppBackend.Notifications.StatsReporter do
  @moduledoc """
  Periodically log stats about notifications usage
  """
  use Oban.Worker, max_attempts: 10
  import Ecto.Query
  require Logger
  alias MobileAppBackend.GlobalDataCache
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    global = GlobalDataCache.get_data()

    counts_by_route =
      Repo.all(from s in Subscription, group_by: [s.route_id], select: {s.route_id, count(s.id)})

    count_subscriptions_by_user =
      Repo.all(from s in Subscription, group_by: [s.user_id], select: count(s.id))

    user_count = length(count_subscriptions_by_user)

    Enum.each(counts_by_route, fn {route_id, count} ->
      mode = Map.get(global.routes, route_id, %{type: :unknown}).type

      Logger.info(
        "#{__MODULE__} counts_by_route route_id=#{route_id} mode=#{mode} count=#{count}"
      )
    end)

    Logger.info(
      "#{__MODULE__} subscriptions_per_user user_count=#{user_count} " <>
        "avg=#{Enum.sum(count_subscriptions_by_user) / user_count} " <>
        "max=#{Enum.max(count_subscriptions_by_user)}"
    )
  end
end
