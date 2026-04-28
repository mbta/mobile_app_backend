defmodule MobileAppBackend.PresentationStrings do
  use Gettext, backend: MobileAppBackend.Gettext

  alias MBTAV3API.Route

  @spec route_type_text(Route.type(), boolean()) :: String.t()
  def route_type_text(route_type, is_only) do
    cond do
      route_type == :bus && is_only -> gettext("bus")
      route_type == :bus && !is_only -> gettext("buses")
      route_type in [:commuter_rail, :heavy_rail, :light_rail] && is_only -> gettext("train")
      route_type in [:commuter_rail, :heavy_rail, :light_rail] && !is_only -> gettext("trains")
      route_type == :ferry && is_only -> gettext("ferry")
      route_type == :ferry && !is_only -> gettext("ferries")
    end
  end
end
