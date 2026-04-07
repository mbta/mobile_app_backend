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
    reassign_env(:mobile_app_backend, :api_version, "3005-01-02")

    assert Headers.build("API_KEY") == [
             {"x-api-key", "API_KEY"},
             {"MBTA-Version", "3005-01-02"}
           ]
  end

  test "derives an outgoing X-Request-Id from the current one" do
    request_id = "1234567890"
    Logger.metadata(request_id: request_id)
    assert [{"X-Request-Id", ^request_id <> "/" <> _}] = Headers.build(nil)
  end
end
