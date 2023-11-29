defmodule MobileAppBackendWeb.Resolvers.Stop do
  def find_stop(_parent, %{id: id}, _resolution) do
    case Stops.Api.by_gtfs_id(id) do
      {:ok, stop} when not is_nil(stop) -> {:ok, stop}
      x -> {:error, x}
    end
  end
end
