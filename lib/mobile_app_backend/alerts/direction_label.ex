defmodule MobileAppBackend.Alerts.DirectionLabel do
  use Gettext, backend: MobileAppBackend.Gettext

  defmacrop gt(text) do
    quote do
      gettext_comment("A route direction label")
      gettext(unquote(text))
    end
  end

  def localized_direction_names do
    %{
      "North" => gt("Northbound"),
      "South" => gt("Southbound"),
      "East" => gt("Eastbound"),
      "West" => gt("Westbound"),
      "Inbound" => gt("Inbound"),
      "Outbound" => gt("Outbound"),
      "Clockwise" => gt("Clockwise"),
      "Counterclockwise" => gt("Counterclockwise"),
      "Loop" => gt("Looping")
    }
  end

  @spec direction_name_formatted(String.t()) :: String.t()
  def direction_name_formatted(direction_name) do
    Map.get(localized_direction_names(), direction_name, gt("Heading"))
  end
end
