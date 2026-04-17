defmodule ObanLogger do
  require Logger

  def handle_event([:oban, :job, :exception], _, meta, nil) do
    Logger.error(
      "#{__MODULE__} job:exception id=#{meta.id} error=#{inspect(meta.error)} stack_trace=#{inspect(Exception.format_stacktrace(meta.stacktrace))}"
    )
  end
end
