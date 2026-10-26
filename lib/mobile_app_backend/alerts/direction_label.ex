defmodule MobileAppBackend.Alerts.DirectionLabel do
  use MobileAppBackend.Gettext

  def localized_direction_names do
    %{
      "North" => gettext("Northbound", comment: "A route direction label"),
      "South" => gettext("Southbound", comment: "A route direction label"),
      "East" => gettext("Eastbound", comment: "A route direction label"),
      "West" => gettext("Westbound", comment: "A route direction label"),
      "Inbound" => gettext("Inbound", comment: "A route direction label"),
      "Outbound" => gettext("Outbound", comment: "A route direction label"),
      "Clockwise" => gettext("Clockwise", comment: "A route direction label"),
      "Counterclockwise" => gettext("Counterclockwise", comment: "A route direction label"),
      "Loop" => gettext("Looping", comment: "A route direction label")
    }
  end

  @spec direction_name_formatted(String.t()) :: String.t()
  def direction_name_formatted(direction_name) do
    Map.get(
      localized_direction_names(),
      direction_name,
      gettext("Heading", comment: "A route direction label")
    )
  end
end
