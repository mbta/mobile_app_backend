defmodule MobileAppBackend.FinchTelemetryLogger do
  require Logger

  def attach do
    :telemetry.attach_many(
      "finch_telemetry",
      [
        [:finch, :request, :stop],
        [:finch, :request, :exception],
        [:finch, :queue, :stop],
        [:finch, :queue, :exception],
        [:finch, :connect, :stop],
        [:finch, :send, :stop],
        [:finch, :recv, :stop],
        [:finch, :recv, :exception]
      ],
      &__MODULE__.handle_event/4,
      []
    )
  end

  def handle_event(event, measure, _meta, _) do
    Logger.debug(
      "#{__MODULE__} #{inspect(event)} duration=#{System.convert_time_unit(measure.duration, :native, :millisecond)}"
    )
  end
end
