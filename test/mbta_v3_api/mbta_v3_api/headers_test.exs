defmodule MBTAV3API.HeadersTest do
  use ExUnit.Case
  import Test.Support.Helpers

  alias MBTAV3API.Headers

  test "always adds api header" do
    assert Headers.build("API_KEY") |> Enum.map(&elem(&1, 0)) == [
             "x-api-key",
             "MBTA-Version"
           ]
  end

  test "accepts an :api_version configuration" do
    reassign_env(:mbta_v3_api, :api_version, "3005-01-02")

    assert Headers.build("API_KEY") == [
             {"x-api-key", "API_KEY"},
             {"MBTA-Version", "3005-01-02"}
           ]
  end
end
