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

  test "__using__/1" do
    expected =
      quote do
        alias MBTAV3API.JsonApi

        @behaviour JsonApi.Object

        Module.put_attribute(__MODULE__, :jsonapi_object_renames, %{a_raw: :a})

        @impl JsonApi.Object
        def jsonapi_type, do: :object_test

        @after_compile JsonApi.Object
      end
      |> Macro.to_string()

    renames_arg = Macro.escape(%{a_raw: :a})

    actual =
      quote do
        MBTAV3API.JsonApi.Object.__using__(renames: unquote(renames_arg))
      end
      |> Macro.expand_once(__ENV__)
      |> Macro.to_string()

    assert expected == actual
  end

  describe "__after_compile__/2" do
    test "correctly raises errors" do
      bad_module =
        quote do
          defmodule BadModule do
            use MBTAV3API.JsonApi.Object

            defstruct [:id, :f1, :f2, :f3, :r2, :r3]

            @impl true
            def fields, do: [:f1, :f2, :f3, :f4]

            @impl true
            def includes, do: %{r1: MBTAV3API.Stop, r2: MBTAV3API.Trip, r3: MBTAV3API.Alert}
          end
        end

      assert_raise RuntimeError,
                   "Bad object struct BadModule: struct keys [..., :f3, :r2, ...] don't match JsonApi.Object `fields() ++ includes()` [..., :f3, :f4, :r1, :r2, ...]",
                   fn ->
                     Code.compile_quoted(bad_module)
                   end
    end

    test "accepts renames" do
      good_module =
        quote do
          defmodule GoodModule do
            use MBTAV3API.JsonApi.Object, renames: %{field_raw: :field, related_raw: :related}

            defstruct [:id, :field, :related]

            @impl true
            def fields, do: [:field_raw]

            @impl true
            def includes, do: %{related_raw: MBTAV3API.Stop}
          end
        end

      assert [{GoodModule, _}] = Code.compile_quoted(good_module)
    end
  end
end
