defmodule Mix.Tasks.Gettext.Check do
  @moduledoc """
  Checks the English PO files under `priv/gettext/en/LC_MESSAGES` and fails if

    * any non-obsolete entry has an empty `msgstr` (for plural entries, if any
      plural form is empty), or
    * any entry in the matching POT template (e.g. `priv/gettext/default.pot`)
      is missing from the PO file.

  Run `mix gettext.update` to fix.

  Usage:

      mix gettext.check [PO_FILE ...]
  """
  use Mix.Task

  alias Expo.Message

  @shortdoc "Checks that English PO files are complete"

  @po_glob "priv/gettext/en/LC_MESSAGES/*.po"

  @impl Mix.Task
  def run(args) do
    files =
      case args do
        [] -> Path.wildcard(@po_glob)
        files -> files
      end

    errors = Enum.flat_map(files, &check_file/1)

    if errors == [] do
      Mix.shell().info("English PO files are complete")
    else
      Mix.raise("""
      English PO files are incomplete:
      #{Enum.join(errors, "\n")}

      Run `mix gettext.update` and commit the result.\
      """)
    end
  end

  @spec check_file(Path.t()) :: [String.t()]
  defp check_file(po_file) do
    messages = active_messages(po_file)

    empty =
      for message <- messages, empty_msgstr?(message) do
        "  #{po_file}: empty msgstr for #{inspect(msgid(message))}"
      end

    empty ++ missing_from_template(po_file, messages)
  end

  # The POT template is at <gettext root>/<domain>.pot, two directories above the PO file
  @spec missing_from_template(Path.t(), [Message.t()]) :: [String.t()]
  defp missing_from_template(po_file, messages) do
    pot_file =
      po_file
      |> Path.dirname()
      |> Path.dirname()
      |> Path.dirname()
      |> Path.join(Path.basename(po_file, ".po") <> ".pot")

    if File.exists?(pot_file) do
      po_keys = MapSet.new(messages, &Message.key/1)

      for message <- active_messages(pot_file),
          not MapSet.member?(po_keys, Message.key(message)) do
        "  #{po_file}: missing #{inspect(msgid(message))} from #{pot_file}"
      end
    else
      ["  #{po_file}: missing POT file #{pot_file}"]
    end
  end

  @spec active_messages(Path.t()) :: [Message.t()]
  defp active_messages(file) do
    Enum.reject(Expo.PO.parse_file!(file).messages, & &1.obsolete)
  end

  @spec msgid(Message.t()) :: String.t()
  defp msgid(message), do: IO.iodata_to_binary(message.msgid)

  @spec empty_msgstr?(Message.t()) :: boolean()
  defp empty_msgstr?(%Message.Singular{msgstr: msgstr}), do: blank?(msgstr)

  defp empty_msgstr?(%Message.Plural{msgstr: msgstr}),
    do: Enum.any?(msgstr, fn {_, str} -> blank?(str) end)

  @spec blank?(iodata()) :: boolean()
  defp blank?(iodata), do: IO.iodata_to_binary(iodata) == ""
end
