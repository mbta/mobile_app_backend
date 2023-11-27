defmodule MBTAV3API.Headers do
  @moduledoc """
  Builds headers for calling the MBTAV3API.

  Setting `:use_cache?` to `true` will include headers set by MBTAV3API.Cache.cache_headers.
  If `:use_cache?` is set to `true`, you must also include a `:url` and a `:params` option.
  """

  alias MBTAV3API.Cache

  @type header_list :: [{String.t(), String.t()}]

  @spec build(String.t() | nil, Keyword.t()) :: header_list
  def build(api_key, opts) do
    []
    |> api_key_header(api_key)
    |> cache_headers(opts)
  end

  @spec api_key_header(header_list, String.t() | nil) :: header_list
  defp api_key_header(headers, nil), do: headers

  defp api_key_header(headers, <<key::binary>>) do
    api_version = Application.get_env(:mbta_v3_api, :api_version)
    [{"x-api-key", key}, {"MBTA-Version", api_version} | headers]
  end

  @spec cache_headers(header_list, Keyword.t()) :: header_list
  defp cache_headers(headers, opts) do
    if Keyword.get(opts, :use_cache?, true) do
      do_cache_headers(headers, opts)
    else
      headers
    end
  end

  @spec do_cache_headers(header_list, Keyword.t()) :: header_list
  defp do_cache_headers(headers, opts) do
    params = Keyword.fetch!(opts, :params)
    cache_headers_fn = Keyword.get(opts, :cache_headers_fn, &Cache.cache_headers/2)

    opts
    |> Keyword.fetch!(:url)
    |> cache_headers_fn.(params)
    |> Enum.reduce(headers, &[&1 | &2])
  end
end
