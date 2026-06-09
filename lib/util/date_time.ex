defmodule Util.DateTime do
  @doc """
  Parses a value as an `America/New_York` datetime.

  ## Examples

      iex> Util.DateTime.parse_datetime!("2024-02-02T10:45:52-05:00")
      #DateTime<2024-02-02 10:45:52-05:00 EST America/New_York>
  """
  @spec parse_datetime!(String.t()) :: DateTime.t()
  def parse_datetime!(data) do
    {:ok, datetime, _} = DateTime.from_iso8601(data)
    DateTime.shift_zone!(datetime, "America/New_York")
  end

  @doc """
  Parses an optional value as an `America/New_York` datetime.

  ## Examples

      iex> Util.DateTime.parse_optional_datetime!(nil)
      nil

      iex> Util.DateTime.parse_optional_datetime!("2024-02-02T10:45:52-05:00")
      #DateTime<2024-02-02 10:45:52-05:00 EST America/New_York>
  """
  @spec parse_optional_datetime!(String.t() | nil) :: DateTime.t() | nil
  def parse_optional_datetime!(data)
  def parse_optional_datetime!(nil), do: nil
  def parse_optional_datetime!(data), do: parse_datetime!(data)

  @doc """
  Converts a local time into a GTFS {service date, HH:MM}.

  ## Examples

      iex> import Test.Support.Sigils
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 10:55:39])
      ~D[2024-03-12]
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 00:19:03])
      ~D[2024-03-11]
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 01:23:45])
      ~D[2024-03-11]
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 02:11:00])
      ~D[2024-03-11]
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 03:00:00])
      ~D[2024-03-12]
      iex> Util.DateTime.datetime_to_gtfs(~B[2024-03-12 03:00:00], rounding: :backwards)
      ~D[2024-03-11]
  """
  @spec datetime_to_gtfs(DateTime.t(), rounding: :forwards | :backwards) :: Date.t()
  def datetime_to_gtfs(
        %DateTime{hour: hour, time_zone: "America/New_York"} = datetime,
        opts \\ []
      ) do
    date = DateTime.to_date(datetime)
    rounding = Keyword.get(opts, :rounding, :forwards)

    if hour in [0, 1, 2] or (rounding == :backwards and hour == 3 and datetime.minute == 0) do
      Date.add(date, -1)
    else
      date
    end
  end

  @spec datetime_to_string(Cldr.Calendar.any_date_time(), String.t() | atom()) :: String.t()

  @doc """
  Format the date in a localized string

  ## Examples
      iex> import Test.Support.Sigils
      iex> Util.DateTime.datetime_to_string(~B[2026-04-29 01:23:45], :short_time)
      "1:23 AM"
      iex> Util.DateTime.datetime_to_string(~B[2026-04-29 13:23:45], :short_time)
      "1:23 PM"
      iex> Util.DateTime.datetime_to_string(~B[2026-04-29 01:23:45], :short_month_day)
      "Apr 29"
      iex> Util.DateTime.datetime_to_string(~B[2026-04-29 01:23:45], :wide_weekday)
      "Wednesday"
      iex> Util.DateTime.datetime_to_string(~B[2026-04-29 01:23:45], "h")
      "1"

  """
  def datetime_to_string(datetime, :short_time) do
    datetime_to_string(datetime, "h:mm a")
  end

  def datetime_to_string(datetime, :short_month_day) do
    datetime_to_string(datetime, "MMM d")
  end

  def datetime_to_string(datetime, :wide_weekday) do
    datetime_to_string(datetime, "EEEE")
  end

  def datetime_to_string(datetime, format) do
    {:ok, formatted} = Cldr.DateTime.to_string(datetime, MobileAppBackend.Cldr, format: format)
    formatted
  end

  @doc """
    Make a new date, safely handling daylight savings issues. Always returns the later
    time at a daylight savings boundary.
  ## Examples

      iex> Util.DateTime.new_safe(~D[2027-03-14], ~T[02:00:00])
      #DateTime<2027-03-14 03:00:00-04:00 EDT America/New_York>
      iex> Util.DateTime.new_safe(~D[2027-11-27], ~T[02:00:00])
      #DateTime<2027-11-27 02:00:00-05:00 EST America/New_York>
      iex> Util.DateTime.new_safe(~D[2027-03-15], ~T[02:00:00])
      #DateTime<2027-03-15 02:00:00-04:00 EDT America/New_York>
  """
  @spec new_safe(Date.t(), Time.t()) :: DateTime.t()
  def new_safe(date, time) do
    case DateTime.new(date, time, "America/New_York") do
      {:ok, date_time} -> date_time
      {:ambiguous, _first_dt, second_dt} -> second_dt
      {:gap, _first_dt, second_dt} -> second_dt
      {:error, _error} -> DateTime.new!(date, ~T[23:59:59], "America/New_York")
    end
  end
end
