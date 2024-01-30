defmodule Util do
  @spec parse_optional_datetime(String.t() | nil) :: DateTime.t() | nil
  def parse_optional_datetime(data)
  def parse_optional_datetime(nil), do: nil

  def parse_optional_datetime(data) do
    {:ok, datetime, _} = DateTime.from_iso8601(data)
    DateTime.shift_zone!(datetime, "America/New_York")
  end
end
