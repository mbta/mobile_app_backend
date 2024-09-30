defmodule MobileAppBackend.HealthCheck do
  @moduledoc """
  Checks whether the application is healthy.
  """

  @doc """
  Returns true if the application is healthy.

  Currently, this only checks whether the GlobalDataCache has been populated.
  """
  @spec healthy?() :: boolean
  def healthy? do
    MobileAppBackend.GlobalDataCache.get_data() != nil
  end
end
