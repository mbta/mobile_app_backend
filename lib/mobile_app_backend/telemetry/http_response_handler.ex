defmodule MobileAppBackend.Telemetry.HttpResponseHandler do
  require Logger

  def attach do
    :telemetry.attach_many(
      "http-telemetry",
      [[:bandit, :request, :stop], [:bandit, :websocket, :start], [:bandit, :websocket, :stop]],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:bandit, :request, :stop], measurements, metadata, _config) do
    Logger.info("""
    http_response_sent path=#{metadata.conn.request_path} \
    status=#{metadata.conn.status} \
    size=#{Map.get(measurements, :resp_body_bytes, nil)} \
    uncompressed_size=#{Map.get(measurements, :resp_uncompressed_body_bytes, nil)} \
    duration_ms=#{System.convert_time_unit(measurements.duration, :native, :millisecond)}
    """)
  end

  def handle_event([:bandit, :websocket, :start], measurements, metadata, _config) do
    Logger.debug("""
    socket_connection_opened \
    compression_enabled=#{!is_nil(measurements.compress)} \
    """)
  end

  def handle_event([:bandit, :websocket, :stop], measurements, metadata, _config) do
    Logger.info("""
    socket_connection_closed \
    send_text_frame_bytes=#{measurements.send_text_frame_bytes} \
    send_text_frame_count=#{measurements.send_text_frame_count} \
    duration_ms=#{System.convert_time_unit(measurements.duration, :native, :millisecond)}
    """)
  end
end
