defmodule Mix.Tasks.ImportLocalizations do
  @moduledoc """
  Imports localizations from an iOS Localizable.xcstrings file.

  Usage:

      mix import_localizations ../mobile_app/iosApp/iosApp/Localizable.xcstrings
  """
  use Mix.Task
  @shortdoc "Imports localizations from iOS"
  @requirements ["app.config"]

  @impl Mix.Task
  def run([localizable_xcstrings_path]) do
    localizable_xcstrings_json = localizable_xcstrings_path |> File.read!() |> Jason.decode!()
    gettext_backend_dir = MobileAppBackend.Gettext.__gettext__(:priv)

    for locale <- Application.fetch_env!(:mobile_app_backend, :locale_codes) do
      Mix.Task.rerun("gettext.merge", [gettext_backend_dir, "--locale", locale, "--no-fuzzy"])
      po_path = [gettext_backend_dir, locale, "LC_MESSAGES", "default.po"] |> Path.join()
      %Expo.Messages{} = po_contents = Expo.PO.parse_file!(po_path)

      new_messages =
        Enum.map(po_contents.messages, &rewrite_message(&1, locale, localizable_xcstrings_json))

      new_po_contents = %Expo.Messages{po_contents | messages: new_messages}
      new_po_contents |> Expo.PO.compose() |> then(&File.write!(po_path, &1))
    end
  end

  @spec rewrite_message(Expo.Message.t(), String.t(), map()) :: Expo.Message.t()
  def rewrite_message(%Expo.Message.Singular{} = po_message, locale, localizable_xcstrings_json) do
    [msgid] = po_message.msgid
    {ios_key_regex, interp_index_names} = from_gettext_interp(msgid)

    {ios_key, ios_matching_string} =
      localizable_xcstrings_json["strings"]
      |> Enum.find({nil, nil}, fn {key, _data} -> Regex.match?(ios_key_regex, key) end)

    ios_local_string =
      ios_matching_string["localizations"][locale]["stringUnit"]["value"]

    msgstr =
      cond do
        not is_nil(ios_local_string) ->
          to_gettext_interp(ios_local_string, interp_index_names)

        locale == "en" and not is_nil(ios_key) ->
          to_gettext_interp(ios_key, interp_index_names)

        Expo.Message.has_flag?(po_message, "import-optional") ->
          [msgstr] = po_message.msgstr
          msgstr

        true ->
          raise "no message found for msgid #{inspect(msgid)} (regex #{inspect(ios_key_regex)}, key #{inspect(ios_key)}) and locale #{inspect(locale)}"
      end

    %Expo.Message.Singular{
      po_message
      | msgstr: [msgstr]
    }
  end

  @spec from_gettext_interp(String.t()) :: {Regex.t(), %{String.t() => String.t()}}
  defp from_gettext_interp(text) do
    gettext_pattern_regex = ~r/%\{([\w]+)\}/
    gettext_patterns = Regex.scan(gettext_pattern_regex, text)

    {result_regex, index_names} =
      Enum.reduce(
        gettext_patterns,
        {Regex.escape(text), %{}},
        fn [pattern, name], {result_regex, index_names} ->
          this_index = to_string(map_size(index_names) + 1)

          result_regex =
            String.replace(result_regex, Regex.escape(pattern), "%(#{this_index}\\$)?[@sd]",
              global: false
            )

          index_names = Map.put(index_names, this_index, name)
          {result_regex, index_names}
        end
      )

    {Regex.compile!("^" <> result_regex <> "$"), index_names}
  end

  @spec to_gettext_interp(String.t(), %{String.t() => String.t()}) :: String.t()
  defp to_gettext_interp(text, index_names) do
    ios_pattern_regex = ~r/%(?:(\d+)\$)?[@ds]/

    # if the text contains just %@, we need to know what the index actually is
    {:ok, fallback_index_agent} = Agent.start_link(fn -> 1 end)

    consume_fallback_index = fn ->
      Agent.get_and_update(fallback_index_agent, &{to_string(&1), &1 + 1})
    end

    result =
      Regex.replace(ios_pattern_regex, text, fn _pattern, index ->
        index =
          case index do
            "" -> consume_fallback_index.()
            index -> index
          end

        index_name = Map.get(index_names, index, index)

        "%{#{index_name}}"
      end)

    Agent.stop(fallback_index_agent)

    result
  end
end
