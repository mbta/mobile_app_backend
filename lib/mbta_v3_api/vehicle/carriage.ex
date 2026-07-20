defmodule MBTAV3API.Vehicle.Carriage do
  require Util
  alias MBTAV3API.Vehicle

  @type t :: %__MODULE__{
          occupancy_status: Vehicle.occupancy_status(),
          occupancy_percentage: 0..100 | nil,
          label: String.t() | nil
        }

  @derive Jason.Encoder
  defstruct [:occupancy_status, :occupancy_percentage, :label]

  @spec parse!(map()) :: t()
  def parse!(data) when is_map(data) do
    %__MODULE__{
      occupancy_status: Vehicle.parse_occupancy_status(data["occupancy_status"]),
      occupancy_percentage: data["occupancy_percentage"],
      label: data["label"]
    }
  end
end
