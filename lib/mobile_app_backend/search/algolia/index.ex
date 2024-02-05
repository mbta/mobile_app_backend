defmodule MobileAppBackend.Search.Algolia.Index do
  @spec index_name(:stop | :route) :: String.t() | nil
  @doc """
  Get the name of the Algolia index to query for the given data type
  """
  def index_name(:stop) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:stop_index]
  end

  def index_name(:route) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:route_index]
  end

  @spec valid_index_name?(String.t()) :: boolean()
  def valid_index_name?(name) do
    name in [
      Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:stop_index],
      Application.get_env(:mobile_app_backend, MobileAppBackend.Search.Algolia)[:route_index]
    ]
  end
end
