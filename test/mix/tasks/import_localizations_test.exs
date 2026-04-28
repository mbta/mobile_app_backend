defmodule Mix.Tasks.ImportLocalizationsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.ImportLocalizations

  test "rewrites messages" do
    po_message = %Expo.Message.Singular{msgid: ["Have a %{quality} %{time}!"], msgstr: [""]}

    xcstrings = %{
      "strings" => %{
        "Have a %@ %@!" => %{
          "localizations" => %{
            "es" => %{"stringUnit" => %{"value" => "¡Que tenga un %2$@ %1$@!"}}
          }
        }
      }
    }

    assert %Expo.Message.Singular{msgstr: ["¡Que tenga un %{time} %{quality}!"]} =
             ImportLocalizations.rewrite_message(po_message, "es", xcstrings)
  end
end
