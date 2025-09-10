defmodule MobileAppBackend.Schema do
  @moduledoc """
  specific options for Ecto.Schema
  """

  defmacro __using__(_opts) do
    quote do
      use TypedEctoSchema
    end
  end
end
