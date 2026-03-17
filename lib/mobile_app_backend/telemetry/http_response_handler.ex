defmodule MobileAppBackend.Telemetry.HttpResponseHandler do
  require Logger

  def attach do
    :telemetry.attach(
      "http-telemetry",
      [:bandit, :request, :stop],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:bandit, :request, :stop], measurements, metadata, _config) do
    Logger.info("""
    http_response_sent path=#{metadata.conn.request_path} \
    status=#{metadata.conn.status} \
    compressed_size=#{Map.get(measurements, :resp_body_bytes, nil)} \
    uncompressed_size=#{Map.get(measurements, :resp_uncompressed_body_bytes, nil)} \ duration_ms=#{System.convert_time_unit(measurements.duration, :native, :millisecond)}
    """)
  end
end
