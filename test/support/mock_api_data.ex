defmodule Test.Support.MockApiData do
  @moduledoc """
  Uses the results of `mix mock_api` to provide real responses to API calls.
  """

  @spec mount(Bypass.t()) :: :ok
  def mount(bypass) do
    test_data_dir = Application.app_dir(:mobile_app_backend, ["priv", "test-data"])

    data =
      Path.join(test_data_dir, "meta.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.new(fn {path, x} ->
        {path,
         Map.new(x, fn {query, filename} ->
           data =
             Path.join(test_data_dir, filename)
             |> File.read!()
             |> Jason.decode!()

           {query, data}
         end)}
      end)

    for {path, query_data} <- data do
      Bypass.stub(bypass, "GET", path, fn conn ->
        data = Map.fetch!(query_data, conn.query_string)
        Phoenix.Controller.json(conn, data)
      end)
    end

    :ok
  end
end
