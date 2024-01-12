defmodule MobileAppBackend.Search.Algolia.IndexTest do
  use ExUnit.Case
  alias MobileAppBackend.Search.Algolia.Index
  import Test.Support.Helpers

  describe "index_name/1" do
    test "returns stop index name from config" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        stop_index: "fake_stop_index"
      )

      assert "fake_stop_index" == Index.index_name(:stop)
    end

    test "returns route index name from config" do
      reassign_env(:mobile_app_backend, MobileAppBackend.Search.Algolia,
        route_index: "fake_route_index"
      )

      assert "fake_route_index" == Index.index_name(:route)
    end
  end
end
