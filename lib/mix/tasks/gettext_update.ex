defmodule Mix.Tasks.Gettext.Update do
  @moduledoc """
  Runs `mix gettext.extract --merge`, then copies the `msgid` into the `msgstr`
  of every entry with an empty `msgstr` in `priv/gettext/en/LC_MESSAGES/default.po`.
  The `default.pot` template is left with empty `msgstr`s.

  Usage:

      mix gettext.update
  """
  use Mix.Task

  alias Expo.Message

  @shortdoc "Extracts and merges gettext, filling empty English msgstrs with the msgid"

  @po_file "priv/gettext/en/LC_MESSAGES/default.po"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("gettext.extract", ["--merge"])

    transform_file(@po_file, &fill_message/1)
    Mix.shell().info("Filled empty msgstrs in #{@po_file}")
  end

  @spec transform_file(Path.t(), (Message.t() -> Message.t())) :: :ok
  defp transform_file(path, fun) do
    messages = Expo.PO.parse_file!(path)
    transformed = %{messages | messages: Enum.map(messages.messages, fun)}
    File.write!(path, IO.iodata_to_binary(Expo.PO.compose(transformed)))
  end

  @spec fill_message(Message.t()) :: Message.t()
  # The header entry has an empty msgid and must stay as is
  defp fill_message(%Message.Singular{msgid: msgid} = message) do
    if blank?(msgid) or not blank?(message.msgstr) do
      message
    else
      %{message | msgstr: msgid}
    end
  end

  defp fill_message(%Message.Plural{} = message) do
    if Enum.all?(message.msgstr, fn {_, str} -> blank?(str) end) do
      msgstr =
        Map.new(message.msgstr, fn
          {0, _} -> {0, message.msgid}
          {index, _} -> {index, message.msgid_plural}
        end)

      %{message | msgstr: msgstr}
    else
      message
    end
  end

  @spec blank?(iodata()) :: boolean()
  defp blank?(iodata), do: IO.iodata_to_binary(iodata) == ""
end
