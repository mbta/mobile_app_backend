defmodule MBTAV3API.JsonApi.ObjectTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
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

  describe "parse/1" do
    test "dispatches by type" do
      assert %MBTAV3API.Prediction{} = parse(%JsonApi.Item{type: "prediction"})
      assert %MBTAV3API.Stop{} = parse(%JsonApi.Item{type: "stop"})
    end

    test "preserves reference" do
      assert %JsonApi.Reference{} = parse(%JsonApi.Reference{})
    end
  end

  describe "parse_one_related/1" do
    test "handles nil" do
      assert is_nil(parse_one_related(nil))
    end

    test "handles empty list" do
      assert is_nil(parse_one_related([]))
    end

    test "handles single item" do
      assert %MBTAV3API.Route{} = parse_one_related([%JsonApi.Item{type: "route"}])
    end

    test "handles single reference" do
      assert %JsonApi.Reference{} = parse_one_related([%JsonApi.Reference{}])
    end

    test "throws on multiple elements" do
      assert_raise RuntimeError, fn ->
        parse_one_related([:a, :b])
      end
    end
  end

  describe "parse_many_related/1" do
    test "handles nil" do
      assert is_nil(parse_many_related(nil))
    end

    test "handles empty list" do
      assert [] = parse_many_related([])
    end

    test "handles non-empty list" do
      assert [%MBTAV3API.Route{}, %JsonApi.Reference{}, %MBTAV3API.Trip{}] =
               parse_many_related([
                 %JsonApi.Item{type: "route"},
                 %JsonApi.Reference{},
                 %JsonApi.Item{type: "trip"}
               ])
    end
  end
end