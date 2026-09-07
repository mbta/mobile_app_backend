defmodule Util.StringFormatterTest do
  use ExUnit.Case
  alias Util.StringFormatter

  describe "format_list_for_log/2" do
    test "formats a list with more items than max_items" do
      list = [1, 2, 3, 4, 5]
      assert StringFormatter.format_list_for_log(list, 3) == "1, 2, 3..."
    end

    test "formats a list with fewer items than max_items" do
      list = [1, 2]
      assert StringFormatter.format_list_for_log(list, 3) == "1, 2"
    end
  end
end
