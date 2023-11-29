defmodule MobileAppBackendWeb.Schema.StopTypes do
  use Absinthe.Schema.Notation

  alias MobileAppBackendWeb.Resolvers

  object :stop do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:latitude, non_null(:float))
    field(:longitude, non_null(:float))

    field :routes, list_of(:route) do
      resolve(&Resolvers.Route.by_stop/3)
    end
  end
end
