defmodule MBTAV3API.FacilityTest do
  use ExUnit.Case

  import Mox

  alias MBTAV3API.{Facility, JsonApi}

  setup :verify_on_exit!

  test "parse!/1" do
    assert Facility.parse!(%JsonApi.Item{
             id: "bike-3",
             attributes: %{
               "long_name" => "Washington St @ Melnea Cass Blvd - Silver Line bike rack",
               "short_name" => "Bike rack",
               "type" => "BIKE_STORAGE"
             }
           }) == %Facility{
             id: "bike-3",
             long_name: "Washington St @ Melnea Cass Blvd - Silver Line bike rack",
             short_name: "Bike rack",
             type: :bike_storage
           }
  end

  test "unexpected enum values fall back" do
    assert Facility.parse!(%JsonApi.Item{
             id: "portal-1",
             attributes: %{
               "long_name" => "Warp portal to Wonderland",
               "short_name" => "Wonderland portal",
               "type" => "PORTAL"
             }
           }) == %Facility{
             id: "portal-1",
             long_name: "Warp portal to Wonderland",
             short_name: "Wonderland portal",
             type: :other
           }
  end
end
