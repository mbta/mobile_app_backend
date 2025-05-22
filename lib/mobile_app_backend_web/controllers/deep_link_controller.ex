defmodule MobileAppBackendWeb.DeepLinkController do
  use MobileAppBackendWeb, :controller

  defp config(key) do
    Application.fetch_env!(:mobile_app_backend, :deep_links)
    |> Keyword.get(key)
  end

  def root(conn, params) do
    redirect(conn, external: "#{config(:dotcom_root)}/app-store?#{URI.encode_query(params)}")
  end

  def apple_app_site_association(conn, _params) do
    json(conn, %{
      applinks: %{
        details: [
          %{
            appIDs: [config(:ios_appid)],
            components: [
              %{/: "/go"},
              # %{/: "/"},
              # %{/: "/*"}
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
