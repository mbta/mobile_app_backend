defmodule MobileAppBackendWeb.Resolvers.Stop do
  def find_stop(_parent, %{id: id}, _resolution) do
    {:ok, Stops.Repo.get!(id)}
  end
end
