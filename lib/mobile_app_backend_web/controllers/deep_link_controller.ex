defmodule MobileAppBackendWeb.DeepLinkController do
  use MobileAppBackendWeb, :controller

  defp campaign_params("screens-sl-kiosk"), do: campaign_params("screens-sl-kiosk", "screens")

  defp campaign_params("t-alert"), do: campaign_params("TAlerts", "TAlerts")

  defp campaign_params(_), do: %{}

  defp campaign_params(campaign, source) do
    %{
      "referrer" => "utm_source=#{source}&utm_campaign=#{campaign}",
      "pt" => "117998862",
      "ct" => campaign,
      "mt" => "8"
    }
  end

  defp stop_keys, do: ["s", "stop"]
  defp route_keys, do: ["r", "route"]

  defp config(key) do
    Application.fetch_env!(:mobile_app_backend, :deep_links)
    |> Keyword.get(key)
  end

  defp app_store_redirect(conn, params) do
    redirect(conn, external: "#{config(:dotcom_root)}/app-store?#{URI.encode_query(params)}")
  end

  defp stop_redirect(conn, stop_id, params) do
    redirect(conn,
      external: "#{config(:dotcom_root)}/stops/#{URI.encode(stop_id)}?#{URI.encode_query(params)}"
    )
  end

  defp line_redirect(conn, "line-Green", params), do: line_redirect(conn, "Green", params)

  defp line_redirect(conn, route_id, params) do
    redirect(conn,
      external:
        "#{config(:dotcom_root)}/schedules/#{URI.encode(route_id)}/line?#{URI.encode_query(params)}"
    )
  end

  def root(conn, params) do
    app_store_redirect(conn, params)
  end

  # Any unrecognized strings at the root path are assumed to be stop IDs,
  # along with explicit /s/ or /stop/ deep links
  def stop(conn, %{"stop_id" => stop_id} = params) do
    stop_redirect(conn, stop_id, Map.delete(Map.delete(params, "_"), "stop_id"))
  end

  def alert(conn, %{"path_params" => path_params} = params) do
    final_params = Map.delete(params, "path_params")
    stop_id = find_path_param(path_params, stop_keys())

    if is_nil(stop_id) do
      route_id = find_path_param(path_params, route_keys())

      if is_nil(route_id) do
        app_store_redirect(conn, final_params)
      else
        line_redirect(conn, route_id, final_params)
      end
    else
      stop_redirect(conn, stop_id, final_params)
    end
  end

  def campaign(conn, %{"campaign_id" => campaign_id} = params) do
    remaining_params = Map.delete(Map.delete(params, "campaign_id"), "_")

    app_store_redirect(conn, Map.merge(remaining_params, campaign_params(campaign_id)))
  end

  def t_alert_cta(conn, params) do
    app_store_redirect(conn, Map.merge(params, campaign_params("t-alert")))
  end

  @spec find_path_param([String.t()], [String.t()]) :: String.t() | nil
  def find_path_param(path_params, keys) do
    key_index =
      Enum.find_index(path_params, fn param ->
        Enum.any?(keys, fn key -> key == param end)
      end)

    case key_index do
      nil -> nil
      _ -> Enum.at(path_params, key_index + 1)
    end
  end

  def apple_app_site_association(conn, _params) do
    json(conn, %{
      applinks: %{
        details: [
          %{
            appIDs: [config(:ios_appid)],
            components: [
              %{/: "/"},
              %{/: "/*"}
            ]
          }
        ]
      }
    })
  end

  def assetlinks_json(conn, _params) do
    json(conn, [
      %{
        relation: ["delegate_permission/common.handle_all_urls"],
        target: %{
          namespace: "android_app",
          package_name: config(:android_package_name),
          sha256_cert_fingerprints: [config(:android_cert_fingerprint)]
        }
      }
    ])
  end
end
