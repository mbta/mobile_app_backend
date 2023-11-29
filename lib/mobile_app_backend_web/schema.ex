defmodule MobileAppBackendWeb.Schema do
  use Absinthe.Schema
  import_types(MobileAppBackendWeb.Schema.RouteTypes)
  import_types(MobileAppBackendWeb.Schema.StopTypes)

  alias MobileAppBackendWeb.Resolvers

  query do
    @desc "Get a stop by ID"
    field :stop, :stop do
      arg(:id, non_null(:id))
      resolve(&Resolvers.Stop.find_stop/3)
    end
  end
end
