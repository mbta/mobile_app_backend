defmodule MobileAppBackendWeb.Schema.RouteTypes do
  use Absinthe.Schema.Notation

  object :route do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:long_name, non_null(:string))

    field(:route_patterns, list_of(:route_pattern))
  end

  object :route_pattern do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
  end
end
