defstruct MobileAppBackend.Alerts.DirectionLabel do
  use Gettext, backend: MobileAppBackend.Gettext

  def localized_direction_names do
    %{
      "North" => gettext("Northbound"),
      "South" => gettext("Southbound"),
      "East" => gettext("Eastbound"),
      "West" => gettext("Westbound"),
      "Inbound" => gettext("Inbound"),
      "Outbound" => gettext("Outbound")
    }
  end

  def direction_name_formatted(direction_name) do
    Map.get(localized_direction_names, direction_name, gettext("Heading"))
  end
end
