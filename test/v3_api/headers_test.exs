defmodule MBTAV3API.HeadersTest do
  use ExUnit.Case
  import Test.Support.Helpers

  alias MBTAV3API.Headers

  test "always adds api header" do
    assert Headers.build("API_KEY", use_cache?: false) |> Enum.map(&elem(&1, 0)) == [
             "x-api-key",
             "MBTA-Version"
           ]

    assert Headers.build("API_KEY", params: [], url: "url") |> Enum.map(&elem(&1, 0)) == [
             "x-api-key",
             "MBTA-Version"
           ]
  end

  test "accepts an :api_version configuration" do
    reassign_env(:mbta_v3_api, :api_version, "3005-01-02")

    assert Headers.build("API_KEY", params: [], url: "url") == [
             {"x-api-key", "API_KEY"},
             {"MBTA-Version", "3005-01-02"}
           ]
  end

  test "calls cache header fn if use_cache? is true" do
    opts = [
      use_cache?: true,
      url: "URL",
      params: [],
      cache_headers_fn: fn "URL", [] -> [{"if-modified-since", "LAST_MODIFIED"}] end
    ]

    actual_opts =
      Headers.build("API_KEY", opts)
      |> Keyword.take(["if-modified-since", "x-api-key"])

    assert actual_opts ==
             [
               {"if-modified-since", "LAST_MODIFIED"},
               {"x-api-key", "API_KEY"}
             ]
  end
end
