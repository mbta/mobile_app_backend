defmodule Mix.Tasks.MockApi do
  require Logger
  use Mix.Task
  @shortdoc "Refresh mock API responses"
  @requirements ["app.start"]

  @urls %{
    stops_boyls:
      {"/stops/place-boyls",
       "include=parent_station%2Cfacilities%2Cchild_stops&fields%5Bfacility%5D=long_name%2Ctype%2Cproperties%2Clatitude%2Clongitude%2Cid&fields%5Bstop%5D=address%2Cname%2Clatitude%2Clongitude%2Caddress%2Cmunicipality%2Cwheelchair_boarding%2Clocation_type%2Cplatform_name%2Cplatform_code%2Cdescription"},
    routes_boyls: {"/routes/", "stop=place-boyls&include=route_patterns"}
  }

  def run(_) do
    test_data_dir = Application.app_dir(:mobile_app_backend, ["priv", "test-data"])
    File.mkdir_p!(test_data_dir)

    url_paths =
      for {name, {path, query}} <- @urls do
        data = get!(path, query)

        filename = "#{name}.json"

        Path.join(test_data_dir, filename)
        |> File.write!(data)

        %{path => %{query => filename}}
      end
      |> Enum.reduce(fn m1, m2 -> Map.merge(m1, m2, fn _k, v1, v2 -> Map.merge(v1, v2) end) end)

    Path.join(test_data_dir, "meta.json")
    |> File.write!(Jason.encode_to_iodata!(url_paths, pretty: true))
  end

  defp get!(path, query) do
    base_url = Application.fetch_env!(:mobile_app_backend, :base_url)
    api_key = Application.fetch_env!(:mobile_app_backend, :api_key)

    url =
      URI.new!(base_url) |> URI.append_path(path) |> URI.append_query(query) |> URI.to_string()

    Logger.info("Downloading #{url}")

    %HTTPoison.Response{body: body, status_code: 200} =
      HTTPoison.get!(url, [
        {"accept", "application/vnd.api+json"}
        | MBTAV3API.Headers.build(api_key, use_cache?: false)
      ])

    body
  end
end
