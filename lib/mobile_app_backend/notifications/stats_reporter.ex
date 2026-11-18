defmodule MobileAppBackend.Notifications.StatsReporter do
  @moduledoc """
  Periodically log stats about notifications usage
  """
  use Oban.Worker, max_attempts: 10
  import Ecto.Query
  require Logger
  alias MobileAppBackend.Notifications.Subscription
  alias MobileAppBackend.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    counts_by_route =
      Repo.all(
        from s in Subscription,
          group_by: [s.route_id],
          select: {s.route_id, count(s.user_id, :distinct)}
      )

    subscriptions_by_user =
      Repo.all(
        from s in Subscription,
          join: u in assoc(s, :user),
          group_by: u.id,
          select: {u, count(s.id)}
      )

    subscription_counts = Enum.map(subscriptions_by_user, fn {_user, count} -> count end)

    user_count = length(subscriptions_by_user)

    {installation_id_count, fcm_token_count} =
      Enum.reduce(subscriptions_by_user, {0, 0}, fn {user, _count},
                                                    {installation_id_count, fcm_token_count} ->
        if user.fcm_installation_id do
          {installation_id_count + 1, fcm_token_count}
        else
          {installation_id_count, fcm_token_count + 1}
        end
      end)

    Enum.each(counts_by_route, fn {route_id, count} ->
      Logger.info("#{__MODULE__} users_by_route route_id=#{route_id} count=#{count}")
    end)

    Logger.info(
      "#{__MODULE__} subscriptions_per_user total_user_count=#{user_count} " <>
        "fcm_token_user_count=#{fcm_token_count} " <>
        "installation_id_user_count=#{installation_id_count} " <>
        "avg=#{Enum.sum(subscription_counts) / user_count} " <>
        "max=#{Enum.max(subscription_counts)}"
    )
  end
end
