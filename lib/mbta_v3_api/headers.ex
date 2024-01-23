defmodule MBTAV3API.Headers do
  @moduledoc """
  Builds headers for calling the MBTAV3API.
  """

  @type header_list :: [{String.t(), String.t()}]

  @spec build(String.t() | nil) :: header_list
  def build(api_key) do
    []
    |> api_key_header(api_key)
  end

  @spec api_key_header(header_list, String.t() | nil) :: header_list
  defp api_key_header(headers, nil), do: headers

  defp api_key_header(headers, <<key::binary>>) do
    api_version = Application.get_env(:mobile_app_backend, :api_version)
    [{"x-api-key", key}, {"MBTA-Version", api_version} | headers]
  end
end
