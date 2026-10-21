defmodule MobileAppBackend.ApplicationTest do
  use MobileAppBackend.DataCase, async: false

  alias MobileAppBackend.Application
  alias MobileAppBackend.Notifications.Scheduler
  alias MobileAppBackend.Notifications.StatsReporter

  test "prep_stop cancels only executing scheduler jobs on the current node" do
    current_node = Oban.config().node

    local_scheduler_job = executing_job(Scheduler, current_node)
    remote_scheduler_job = executing_job(Scheduler, "remote@node")
    other_worker_job = executing_job(StatsReporter, current_node)

    state = %{reason: :shutdown}

    assert Application.prep_stop(state) == state
    assert job_state(local_scheduler_job) == "cancelled"
    assert job_state(remote_scheduler_job) == "executing"
    assert job_state(other_worker_job) == "executing"
  end

  defp executing_job(worker, node) do
    worker.new(%{"test_node" => node})
    |> Oban.insert!()
    |> Ecto.Changeset.change(state: "executing", attempted_by: [node])
    |> Repo.update!()
  end

  defp job_state(job), do: Repo.get!(Oban.Job, job.id).state
end
