defmodule MBTAV3API.JsonApi.ObjectTest do
  use ExUnit.Case, async: true

  alias MBTAV3API.JsonApi
  import MBTAV3API.JsonApi.Object

  doctest MBTAV3API.JsonApi.Object

  test "t/0" do
    {:ok, types} = Code.Typespec.fetch_types(MBTAV3API.JsonApi.Object)

    type_src =
      types
      |> Enum.find_value(fn
        {:type, {:t, _, _} = type} -> type
        _ -> nil
      end)
      |> Code.Typespec.type_to_quoted()
      |> Macro.to_string()

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

  describe "get_one_id/1" do
    test "handles nil" do
      assert is_nil(get_one_id(nil))
    end

    test "handles single reference" do
      assert "123456" = get_one_id(%JsonApi.Reference{id: "123456"})
    end
  end

  describe "get_many_ids/1" do
    test "handles nil" do
      assert is_nil(get_many_ids(nil))
    end

    test "handles empty list" do
      assert [] = get_many_ids([])
    end

    test "handles non-empty list" do
      assert ["a", "b", "c"] =
               get_many_ids([
                 %JsonApi.Reference{id: "a"},
                 %JsonApi.Reference{id: "b"},
                 %JsonApi.Reference{id: "c"}
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

            defstruct [:id, :f1, :f2, :f3, :r2_id, :r3_id]

            @impl true
            def fields, do: [:f1, :f2, :f3, :f4]

            @impl true
            def includes, do: %{r1: MBTAV3API.Stop, r2: MBTAV3API.Trip, r3: MBTAV3API.Alert}
          end
        end

      assert_raise RuntimeError,
                   "Bad object struct BadModule: struct keys [..., :f3, :r2_id, ...] don't match JsonApi.Object `fields() ++ includes()` [..., :f3, :f4, :r1_id, :r2_id, ...]",
                   fn ->
                     Code.compile_quoted(bad_module)
                   end
    end

    test "accepts renames" do
      good_module =
        quote do
          defmodule GoodModule do
            use MBTAV3API.JsonApi.Object, renames: %{field_raw: :field, related_raw: :related}

            defstruct [:id, :field, :related_id]

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
