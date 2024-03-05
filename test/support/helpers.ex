defmodule Test.Support.Helpers do
  @moduledoc "Test helpers"

  defmacro reassign_env(app, var, value) do
    quote do
      old_value = Application.get_env(unquote(app), unquote(var))
      Application.put_env(unquote(app), unquote(var), unquote(value))

      on_exit(fn ->
        if old_value == nil do
          Application.delete_env(unquote(app), unquote(var))
        else
          Application.put_env(unquote(app), unquote(var), old_value)
        end
      end)
    end
  end

  defmacro set_log_level(log_level) do
    quote do
      old_log_level = Logger.level()

      on_exit(fn ->
        Logger.configure(level: old_log_level)
      end)

      Logger.configure(level: unquote(log_level))
    end
  end

  @spec ok_response([primary_data], [MBTAV3API.JsonApi.Object.t()]) ::
          {:ok, MBTAV3API.JsonApi.Response.t(primary_data)}
        when primary_data: MBTAV3API.JsonApi.Object.t()
  def ok_response(data, included \\ []) do
    {:ok,
     %MBTAV3API.JsonApi.Response{
       data: data,
       included: MBTAV3API.JsonApi.Object.to_full_map(included)
     }}
  end
end
