defmodule MBTAV3API.Facility do
  use MBTAV3API.JsonApi.Object
  require Util

  @type t :: %__MODULE__{
          id: String.t(),
          long_name: String.t() | nil,
          short_name: String.t() | nil,
          type: facility_type()
        }

  Util.declare_enum(
    :facility_type,
    Util.enum_values(
      :uppercase_string,
      [
        :bike_storage,
        :bridge_plate,
        :electric_car_chargers,
        :elevated_subplatform,
        :elevator,
        :escalator,
        :fare_media_assistance_facility,
        :fare_media_assistant,
        :fare_vending_machine,
        :fare_vending_retailer,
        :fully_elevated_platform,
        :other,
        :parking_area,
        :pick_drop,
        :portable_boarding_lift,
        :ramp,
        :taxi_stand,
        :ticket_window
      ]
    ),
    :other
  )

  @derive Jason.Encoder
  defstruct [:id, :long_name, :short_name, :type]

  @impl JsonApi.Object
  def fields do
    [:long_name, :short_name, :type]
  end

  @impl JsonApi.Object
  def includes, do: %{}

  @impl JsonApi.Object
  def serialize_filter_value(:type, type), do: serialize_facility_type!(type)
  def serialize_filter_value(_field, value), do: value

  @spec parse!(JsonApi.Item.t()) :: t()
  def parse!(%JsonApi.Item{} = item) do
    %__MODULE__{
      id: item.id,
      long_name: item.attributes["long_name"],
      short_name: item.attributes["short_name"],
      type: parse_facility_type(item.attributes["type"])
    }
  end
end
