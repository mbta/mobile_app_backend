defmodule Mix.Tasks.CheckOtpSync do
  @moduledoc """
  Checks that the `-otp-N` suffix on the `elixir` line in `.tool-versions`
  matches the major version of the `erlang` line.

      mix check_otp_sync
      mix check_otp_sync path/to/.tool-versions

  Raises if the file is missing, either version is missing, the elixir version has no
  `-otp-N` suffix, or the suffix doesn't match the erlang version.
  """

  @shortdoc "Checks elixir's -otp-N suffix matches erlang's version in .tool-versions"

  use Mix.Task

  @elixir_regex ~r/^elixir\s+(?<version>\d+\.\d+\.\d+)-otp-(?<otp>\d+)\s*$/m
  @erlang_regex ~r/^erlang\s+(?<version>\S+)\s*$/m

  @impl Mix.Task
  def run(args) do
    path =
      case args do
        [path | _] -> path
        [] -> ".tool-versions"
      end

    unless File.exists?(path) do
      Mix.raise("#{path} not found")
    end

    contents = File.read!(path)

    elixir_captures = Regex.named_captures(@elixir_regex, contents)
    erlang_captures = Regex.named_captures(@erlang_regex, contents)

    case {elixir_captures, erlang_captures} do
      {nil, _} ->
        Mix.raise("""
        No `elixir` line with an `-otp-N` suffix found in #{path}.
        Expected something like: `elixir 1.20.2-otp-28`
        """)

      {_, nil} ->
        Mix.raise("No `erlang` line found in #{path}")

      {%{"version" => elixir_version, "otp" => elixir_otp}, %{"version" => erlang_version}} ->
        erlang_major = erlang_version |> String.split(".") |> List.first()

        if elixir_otp == erlang_major do
          Mix.shell().info("OK: elixir -otp-#{elixir_otp} matches erlang #{erlang_major}.x")
        else
          Mix.raise("""
          elixir's -otp-#{elixir_otp} suffix does not match erlang's major version (#{erlang_major}) in #{path}

            elixir #{elixir_version}-otp-#{elixir_otp}
            erlang #{erlang_version}
          """)
        end
    end
  end
end
