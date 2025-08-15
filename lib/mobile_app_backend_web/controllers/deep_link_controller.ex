defmodule MobileAppBackendWeb.DeepLinkController do
  use MobileAppBackendWeb, :controller

  defp t_alert_cta_campaign_params do
    %{
      "pt" => "117998862",
      "ct" => "TAlerts",
      "mt" => "8",
      "utm_source" => "TAlerts",
      "utm_campaign" => "TAlerts"
    }
  end

  defp config(key) do
    Application.fetch_env!(:mobile_app_backend, :deep_links)
    |> Keyword.get(key)
  end

  defp app_store_redirect(conn, params) do
    redirect(conn, external: "#{config(:dotcom_root)}/app-store?#{URI.encode_query(params)}")
  end

  def root(conn, params) do
    app_store_redirect(conn, params)
  end

  def t_alert_cta(conn, params) do
    app_store_redirect(conn, Map.merge(params, t_alert_cta_campaign_params()))
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
