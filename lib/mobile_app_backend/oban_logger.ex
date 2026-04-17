defmodule ObanLogger do
  require Logger

  def handle_event([:oban, :job, :exception], _, meta, nil) do
    log_data = %{
      worker: meta.worker,
      id: meta.id,
      meta: meta.meta,
      state: meta.state,
      max_attempts: meta.max_attempts,
      queue: meta.queue,
      source: meta.source,
      event: meta.event,
      duration: meta.duration,
      attempt: meta.attempt,
      queue_time: meta.queue_time,
      error: meta.error,
      stacktrace: Exception.format_stacktrace(meta.stacktrace)
    }

    Logger.error(Jason.encode!(log_data))
  end
end
