defmodule MobileAppBackend.Health.Checker.Alerts do
  use MobileAppBackend.Health.Checker,
    implementation_module: MobileAppBackend.Health.Checker.Alerts.Impl
end

defmodule MobileAppBackend.Health.Checker.Alerts.Impl do
  @moduledoc """
  Check if the number of alerts returned from the backend matches
  the number we have saved in the store
  """

  alias MBTAV3API.Repository
  alias MBTAV3API.Store
  alias MobileAppBackend.Health.Checker.Alerts, as: Checker

  @behaviour MobileAppBackend.Health.Checker

  @impl true
  def healthy? do
    all_stored = Store.Alerts.fetch([])
    from_backend = Repository.alerts([])

    case from_backend do
      {:ok, %{data: from_repo}} ->
        Checker.log_failure(
          length(all_stored) == length(from_repo),
          "stored alert count #{length(all_stored)} != backend alert count #{length(from_repo)}"
        )

      _ ->
        Checker.log_failure(false, "backend alert request failed")
    end
  end
end
