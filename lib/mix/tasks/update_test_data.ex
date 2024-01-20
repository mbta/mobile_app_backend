defmodule Mix.Tasks.UpdateTestData do
  @moduledoc """
  Update cached test data based on API calls in tests.

  Forwards arguments (such as specific tests to run) to `mix test`.
  Only writes if run with no arguments.
  """

  use Mix.Task
  @shortdoc "Updates test data cache"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    case Code.ensure_loaded(Test.Support.Data) do
      {:module, data} ->
        data.start_link(updating_test_data?: true)

        Mix.Task.run("test", ["--raise"] ++ args)

        if args == [] do
          data.write_new_data()
        else
          Mix.shell().info("Not writing test data, ran with arguments")
        end

      {:error, :nofile} ->
        raise "mix update_test_data must be run in the test env"
    end
  end
end
