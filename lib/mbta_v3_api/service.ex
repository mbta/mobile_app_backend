defmodule MBTAV3API.Service do
  use MBTAV3API.JsonApi.Object

  @type t :: %__MODULE__{
          id: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          added_dates: [Date.t()],
          removed_dates: [Date.t()],
          valid_days: 1..7
        }

  @derive Jason.Encoder
  defstruct [:id, :start_date, :end_date, :added_dates, :removed_dates, :valid_days]

  def fields, do: [:start_date, :end_date, :added_dates, :removed_dates, :valid_days]

  def includes, do: %{}

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      start_date: Date.from_iso8601!(item.attributes["start_date"]),
      end_date: Date.from_iso8601!(item.attributes["end_date"]),
      added_dates: Enum.map(item.attributes["added_dates"], &Date.from_iso8601!/1),
      removed_dates: Enum.map(item.attributes["added_dates"], &Date.from_iso8601!/1),
      valid_days: item.attributes["valid_days"]
    }
  end

  @doc """
  Gets the list of all dates on which this service is active.
  """
  @spec active_dates(t()) :: [Date.t()]
  def active_dates(%__MODULE__{} = service) do
    Date.range(service.start_date, service.end_date)
    |> Enum.filter(&(Date.day_of_week(&1) in service.valid_days))
    |> Kernel.--(service.removed_dates)
    |> Kernel.++(service.added_dates)
    |> Enum.sort(Date)
  end

  @doc """
  Gets the list of dates on which some service in the list is next active.

  Returns a list because the single next service may not actually visit the desired stop and direction.
  """
  @spec next_active([t()], Date.t()) :: [Date.t()]
  def next_active(services, start_date) do
    services
    |> Enum.flat_map(fn service ->
      active_dates(service) |> Enum.find(&Date.after?(&1, start_date)) |> List.wrap()
    end)
    |> Enum.sort(Date)
    |> Enum.dedup()
  end
end
