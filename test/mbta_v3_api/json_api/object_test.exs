defmodule MBTAV3API.JsonApi.ObjectTest do
  use ExUnit.Case, async: true

  import MBTAV3API.JsonApi.Object

  doctest MBTAV3API.JsonApi.Object

  test "t/0" do
    {:ok, [type: t]} = Code.Typespec.fetch_types(MBTAV3API.JsonApi.Object)
    type_src = t |> Code.Typespec.type_to_quoted() |> Macro.to_string()

    clauses =
      type_src
      |> String.replace_prefix("t() ::", "")
      |> String.splitter("|")
      |> Enum.map(&String.trim/1)

    assert Enum.all?(
             clauses,
             &(String.starts_with?(&1, "MBTAV3API.") and String.ends_with?(&1, ".t()"))
           )
  end

  describe "is_json_object/1" do
    test "properly accepts V3 API objects" do
      assert is_json_object(%MBTAV3API.Stop{})
      assert is_json_object(%MBTAV3API.Route{})
      assert is_json_object(%MBTAV3API.Prediction{})
    end

    test "properly rejects non-V3 API objects" do
      refute is_json_object(~D[2024-02-02])
      refute is_json_object(~T[17:38:00])
      refute is_json_object(URI.parse("https://example.com"))
      refute is_json_object("not even close")
      refute is_json_object(7)
      refute is_json_object(false)
    end
  end
end
