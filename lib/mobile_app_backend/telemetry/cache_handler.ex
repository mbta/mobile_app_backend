defmodule MobileAppBackend.Telemetry.CacheHandler do
  require Logger

  def attach do
    :telemetry.attach_many(
      "nebulex-cache-handler",
      [
        [:mbtav3api, :repository_cache, :command, :stop],
        [:mbtav3api, :response_cache, :command, :stop]
      ],
      &__MODULE__.handle_event/4,
      []
    )
  end

  def handle_event(
        [:mbtav3api, cache, :command, :stop],
        measurements,
        %{command: :fetch} = metadata,
        _config
      ) do
    result =
      case metadata.result do
        {:error, error} ->
          "miss details=#{inspect(error)}"

        {:ok, _} ->
          "hit"

        other ->
          "unknown details=#{inspect(other)}"
      end

    duration =
      case measurements do
        %{duration: duration} -> System.convert_time_unit(duration, :native, :millisecond)
        _ -> ""
      end

    Logger.info(
      "#{__MODULE__} cache=#{cache} duration=#{duration} result=#{result} key=#{inspect(List.first(metadata.args))}"
    )
  end

  def handle_event(
        [:mbtav3api, _cache, :command, :stop],
        _measurements,
        %{command: _command},
        _config
      ) do
    # Ignore other events
  end
end
