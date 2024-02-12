defmodule Mix.Tasks.UpdateTestData do
  @moduledoc """
  Update cached test data based on API calls in tests.

  Forwards arguments (such as specific tests to run) to `mix test`.
  Only deletes unused test data if run with no arguments.
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

        ran_all_tests = args == []
        data.write_new_data(remove_unused: ran_all_tests)

      {:error, :nofile} ->
        raise "mix update_test_data must be run in the test env"
    end
  end
end
