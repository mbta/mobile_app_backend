defmodule MBTAV3API.Prediction do
  alias MBTAV3API.JsonApi

  @behaviour JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          arrival_time: DateTime.t() | nil,
          departure_time: DateTime.t() | nil,
          direction_id: 0 | 1,
          revenue: boolean(),
          schedule_relationship: schedule_relationship(),
          status: String.t(),
          stop_sequence: integer() | nil,
          trip: MBTAV3API.Trip.t() | JsonApi.Reference.t() | nil
        }
  @type schedule_relationship ::
          :added | :cancelled | :no_data | :skipped | :unscheduled | :scheduled

  @derive Jason.Encoder
  defstruct [
    :id,
    :arrival_time,
    :departure_time,
    :direction_id,
    :revenue,
    :schedule_relationship,
    :status,
    :stop_sequence,
    :trip
  ]

  def fields do
    [
      :arrival_time,
      :departure_time,
      :direction_id,
      :revenue_status,
      :schedule_relationship,
      :status,
      :stop_sequence
    ]
  end

  def includes, do: %{trip: :trip}

  @spec stream_all(JsonApi.Params.t(), Keyword.t()) ::
          MBTAV3API.Stream.Supervisor.on_start_instance()
  def stream_all(params, opts \\ []) do
    params = JsonApi.Params.flatten_params(params, :prediction)

    MBTAV3API.start_stream("/predictions", params, opts)
  end

  @spec parse(JsonApi.Item.t()) :: t()
  def parse(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      arrival_time: Util.parse_optional_datetime(item.attributes["arrival_time"]),
      departure_time: Util.parse_optional_datetime(item.attributes["departure_time"]),
      direction_id: item.attributes["direction_id"],
      revenue: parse_revenue_status(item.attributes["revenue_status"]),
      schedule_relationship:
        parse_schedule_relationship(item.attributes["schedule_relationship"]),
      stop_sequence: item.attributes["stop_sequence"],
      status: item.attributes["status"],
      trip:
        case item.relationships["trip"] do
          nil -> nil
          [] -> nil
          [trip] -> JsonApi.Object.parse(trip)
          [_ | _] -> raise "Multiple trips"
        end
    }
  end

  @spec parse_revenue_status(String.t() | nil) :: boolean()
  defp parse_revenue_status("REVENUE"), do: true
  defp parse_revenue_status("NON_REVENUE"), do: false
  defp parse_revenue_status(nil), do: true

  @spec parse_schedule_relationship(String.t() | nil) :: schedule_relationship()
  defp parse_schedule_relationship("ADDED"), do: :added
  defp parse_schedule_relationship("CANCELLED"), do: :cancelled
  defp parse_schedule_relationship("NO_DATA"), do: :no_data
  defp parse_schedule_relationship("SKIPPED"), do: :skipped
  defp parse_schedule_relationship("UNSCHEDULED"), do: :unscheduled
  defp parse_schedule_relationship(nil), do: :scheduled
end
