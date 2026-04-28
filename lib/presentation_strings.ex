defmodule MobileAppBackend.PresentationStrings do
  use Gettext, backend: MobileAppBackend.Gettext

  alias MBTAV3API.Route

  @spec route_type_text(Route.type(), boolean()) :: String.t()
  def route_type_text(:bus, true), do: gettext("bus")
  def route_type_text(:bus, false), do: gettext("buses")
  def route_type_text(:ferry, true), do: gettext("ferry")
  def route_type_text(:ferry, false), do: gettext("ferries")
  def route_type_text(_subway, true), do: gettext("train")
  def route_type_text(_subway, false), do: gettext("trains")
end
