defmodule MobileAppBackend.Telemetry.WebsocketEventHandler do
  require Logger

  def attach do
    :telemetry.attach_many(
      "websocket-telemetry",
      [[:bandit, :websocket, :start], [:bandit, :websocket, :stop]],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:bandit, :websocket, :start], measurements, _metadata, _config) do
    Logger.debug("""
    socket_connection_opened \
    compression_enabled=#{!is_nil(measurements.compress)} \
    """)
  end

  def handle_event([:bandit, :websocket, :stop], measurements, _metadata, _config) do
    Logger.info("""
    socket_connection_closed \
    send_text_frame_bytes=#{Map.get(measurements, :send_text_frame_bytes)} \
    send_text_frame_count=#{Map.get(measurements, :send_text_frame_count)} \
    duration_ms=#{System.convert_time_unit(measurements.duration, :native, :millisecond)}
    """)
  end
end
