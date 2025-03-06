defmodule MobileAppBackend.Health.Checker do
  @moduledoc """
  Behavior defining a module that checks the health of some piece of the system
  """

  @doc """
  Check the health of the module, returns :ok if healthy or {:error, "cause string"} if not.
  """
  @callback check_health :: :ok | {:error, String.t()}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      require Logger
      @behaviour MobileAppBackend.Health.Checker
      implementation_module = Keyword.fetch!(opts, :implementation_module)

      def check_health do
        healthy =
          Application.get_env(:mobile_app_backend, __MODULE__, unquote(implementation_module)).check_health()

        case healthy do
          {:error, reason} -> Logger.warning("Health check failed for #{__MODULE__}: #{reason}")
          _ -> nil
        end

        healthy
      end
    end
  end
end
