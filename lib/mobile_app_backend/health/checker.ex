defmodule MobileAppBackend.Health.Checker do
  @moduledoc """
  Behavior defining a module that checks the health of some piece of the system
  """

  require Logger

  @doc """
  Check the health of the module, returns true if healthy.
  """
  @callback healthy? :: boolean()

  @doc """
  Take the result of the health check, and if it's false, log a warning with the module name.
  The Checker implementations can also provide an optional reason for the failure.
  Return the provided result as is, so that this can be chained.
  """
  @spec log_failure(boolean(), module(), String.t()) :: boolean()
  def log_failure(result, module, reason) do
    if !result do
      warning = "Health check failed for #{module}"

      Logger.warning(
        if reason != "" do
          "#{warning}: #{reason}"
        else
          warning
        end
      )
    end

    result
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour MobileAppBackend.Health.Checker
      implementation_module = Keyword.fetch!(opts, :implementation_module)

      def healthy? do
        Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).healthy?()
      end

      def log_failure(result, reason \\ "") do
        MobileAppBackend.Health.Checker.log_failure(result, __MODULE__, reason)
      end
    end
  end
end
