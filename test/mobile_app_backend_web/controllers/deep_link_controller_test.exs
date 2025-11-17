defmodule MobileAppBackendWeb.DeepLinkControllerTest do
  use MobileAppBackendWeb.ConnCase
  import Test.Support.Helpers

  describe "root" do
    test "redirects to dotcom, preserving params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end
  end

  describe "stop root" do
    test "redirects to dotcom stop page, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/place-chill?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/stops/place-chill?param_1=val_1"
    end

    test "redirects to dotcom stop page, ignoring remainder of path", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/place-chill/test/path?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/stops/place-chill?param_1=val_1"
    end
  end

  describe "nav paths" do
    test "redirects stop urls, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/s/place-chill?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end

    test "redirects expanded stop urls, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/stop/place-chill/r/line-Green/d/1?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end

    test "redirects alert urls, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/a/1234567/r/line-Green?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end

    test "redirects expanded alert urls, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/alert/1234567/s/place-pktrm?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end

    test "redirects campaign urls, preserving query params", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/c/campaign?param_1=val_1")

      assert redirected_to(conn, 302) == "https://example.com/app-store?param_1=val_1"
    end
  end

  describe "campaigns" do
    test "redirects t-alert campaign", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/t-alert?param_1=val_1")

      assert redirected_to(conn, 302) ==
               "https://example.com/app-store?ct=TAlerts&mt=8&param_1=val_1&pt=117998862&referrer=utm_source%3DTAlerts%26utm_campaign%3DTAlerts"
    end

    test "redirects screens-sl-kiosk campaign", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, dotcom_root: "https://example.com")

      conn = get(conn, ~p"/c/screens-sl-kiosk?param_1=val_1")

      assert redirected_to(conn, 302) ==
               "https://example.com/app-store?ct=screens-sl-kiosk&mt=8&param_1=val_1&pt=117998862&referrer=utm_source%3Dscreens%26utm_campaign%3Dscreens-sl-kiosk"
    end
  end

  describe "Android deep link approval" do
    test "works when configured", %{conn: conn} do
      package_name = "com.mbta.tid.mbta_app"

      cert_fingerprint =
        :rand.bytes(32)
        |> Base.encode16()
        |> String.codepoints()
        |> Enum.chunk_every(2)
        |> Enum.map_join(":", &Enum.join(&1, ""))

      reassign_env(:mobile_app_backend, :deep_links,
        android_cert_fingerprint: cert_fingerprint,
        android_package_name: package_name
      )

      conn = conn |> get(~p"/.well-known/assetlinks.json")

      assert json_response(conn, 200) == [
               %{
                 "relation" => ["delegate_permission/common.handle_all_urls"],
                 "target" => %{
                   "namespace" => "android_app",
                   "package_name" => package_name,
                   "sha256_cert_fingerprints" => [cert_fingerprint]
                 }
               }
             ]
    end

    test "does not crash if not configured", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links,
        android_cert_fingerprint: nil,
        android_package_name: nil
      )

      conn = conn |> get("/.well-known/assetlinks.json")

      assert json_response(conn, 200)
    end
  end

  describe "iOS deep link approval" do
    test "serves iOS deep link approval", %{conn: conn} do
      appid = "#{:rand.bytes(6) |> Base.encode32(padding: false)}.com.mbta.tid.mbtaapp"
      reassign_env(:mobile_app_backend, :deep_links, ios_appid: appid)

      conn = conn |> get(~p"/.well-known/apple-app-site-association")

      assert json_response(conn, 200) == %{
               "applinks" => %{
                 "details" => [
                   %{
                     "appIDs" => [appid],
                     "components" => [
                       %{"/" => "/"},
                       %{"/" => "/*"}
                     ]
                   }
                 ]
               }
             }
    end

    test "does not crash if iOS deep link approval not configured", %{conn: conn} do
      reassign_env(:mobile_app_backend, :deep_links, ios_appid: nil)

      conn = conn |> get("/.well-known/apple-app-site-association")

      assert json_response(conn, 200)
    end
  end
end
