defmodule MobileAppBackend.SSE do
  def child_spec(opts) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.SSE, ServerSentEventStage).child_spec(
      opts
    )
  end
end
