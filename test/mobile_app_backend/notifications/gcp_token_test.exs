defmodule MobileAppBackend.Notifications.GCPTokenTest do
  use ExUnit.Case, async: false
  import Mox
  import Tesla.Test
  import Test.Support.Helpers
  alias MobileAppBackend.Notifications.GCPToken

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "without GCP provider name, loads GCP auth via Goth" do
    reassign_env(:mobile_app_backend, GCPToken, gcp_provider_name: nil)

    reassign_env(
      :goth,
      :json,
      Jason.encode!(%{
        refresh_token: "a",
        client_id: "b",
        client_secret: "c",
        quota_project_id: ""
      })
    )

    Process.put(
      :goth_http_client,
      {fn data ->
         assert data[:method] == :post
         assert data[:url] == "https://www.googleapis.com/oauth2/v4/token"
         assert data[:headers] == [{"Content-Type", "application/x-www-form-urlencoded"}]

         assert data[:body] ==
                  "grant_type=refresh_token&refresh_token=a&client_id=b&client_secret=c"

         {:ok,
          %{
            status: 200,
            headers: [],
            body: Jason.encode!(%{accessToken: "token", expireTime: ~U[2025-10-14 16:28:00Z]})
          }}
       end, []}
    )

    key = make_ref()
    assert GCPToken.get_token(key) == "token"

    assert :persistent_term.get(key) == %GCPToken.StoredToken{
             token: "token",
             expires: ~U[2025-10-14 16:28:00Z]
           }
  end

  test "with GCP provider name, loads GCP auth via AWS IAM federation" do
    provider_name =
      "projects/12345678/locations/global/workloadIdentityPools/my-pool/providers/my-aws-provider"

    service_account_id = "12345678901234567890"

    reassign_env(:mobile_app_backend, GCPToken,
      gcp_provider_name: provider_name,
      gcp_service_account_id: service_account_id
    )

    reassign_env(:ex_aws, :access_key_id, [""])
    reassign_env(:ex_aws, :secret_access_key, [""])
    reassign_env(:ex_aws, :security_token, ["/+/+"])
    reassign_env(:tesla, :adapter, TeslaMockAdapter)

    expires_in = 10
    expires_at = DateTime.utc_now(:second) |> DateTime.add(expires_in, :second)

    expect_tesla_call(
      times: 2,
      returns: fn
        %Tesla.Env{url: "https://sts.googleapis.com/v1/token"}, _ ->
          %Tesla.Env{status: 200}
          |> json(%{access_token: "federated_access_token", expires_in: expires_in})
          |> then(&{:ok, &1})

        %Tesla.Env{url: "https://iamcredentials.googleapis.com" <> _}, _ ->
          %Tesla.Env{status: 200}
          |> json(%{
            accessToken: "service_account_access_token",
            expireTime: expires_at
          })
          |> then(&{:ok, &1})
      end,
      adapter: TeslaMockAdapter
    )

    key = make_ref()
    assert GCPToken.get_token(key) == "service_account_access_token"

    assert_received_tesla_call(received_env, received_opts, adapter: TeslaMockAdapter)

    assert %Tesla.Env{
             method: :post,
             url: "https://sts.googleapis.com/v1/token",
             headers: [
               {"x-goog-api-client", _},
               {"accept-encoding", "gzip, deflate, identity"},
               {"content-type", "application/json"}
             ],
             body: received_body
           } = received_env

    assert %{
             scope: "https://www.googleapis.com/auth/cloud-platform",
             audience:
               "//iam.googleapis.com/projects/12345678/locations/global/workloadIdentityPools/my-pool/providers/my-aws-provider",
             grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
             requestedTokenType: "urn:ietf:params:oauth:token-type:access_token",
             subjectToken: received_subject_token,
             subjectTokenType: "urn:ietf:params:aws:token-type:aws4_request"
           } = Jason.decode!(received_body, keys: :atoms!)

    assert %{
             headers: [
               %{key: "Authorization", value: aws4_hmac_sha256},
               %{key: "X-Amz-Security-Token", value: "_-_-"},
               %{key: "host", value: "sts.us-east-1.amazonaws.com"},
               %{key: "x-amz-date", value: _},
               %{
                 key: "x-goog-cloud-target-resource",
                 value:
                   "//iam.googleapis.com/projects/12345678/locations/global/workloadIdentityPools/my-pool/providers/my-aws-provider"
               }
             ],
             method: "POST",
             url:
               "https://sts.us-east-1.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15"
           } = Jason.decode!(URI.decode(received_subject_token), keys: :atoms!)

    assert [_, signed_headers] =
             Regex.run(
               ~r"^AWS4-HMAC-SHA256 Credential=/\d+/us-east-1/sts/aws4_request,SignedHeaders=(.*),Signature=[0-9a-f]+$",
               aws4_hmac_sha256
             )

    assert ["host", "x-amz-date", "x-amz-security-token", "x-goog-cloud-target-resource"] =
             String.split(signed_headers, ";")

    assert received_opts == []

    assert_received_tesla_call(received_env, received_opts, adapter: TeslaMockAdapter)

    assert %Tesla.Env{
             method: :post,
             url:
               "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/12345678901234567890:generateAccessToken",
             headers: [
               {"x-goog-api-client", _},
               {"authorization", "Bearer federated_access_token"},
               {"accept-encoding", "gzip, deflate, identity"},
               {"content-type", "application/json"}
             ],
             body: received_body
           } = received_env

    assert %{
             scope: ["https://www.googleapis.com/auth/firebase.messaging"]
           } = Jason.decode!(received_body, keys: :atoms!)

    assert received_opts == []

    assert :persistent_term.get(key) == %GCPToken.StoredToken{
             token: "service_account_access_token",
             expires: expires_at
           }
  end

  test "uses stored token if not expired" do
    key = make_ref()

    reassign_persistent_term(key, %GCPToken.StoredToken{
      token: "existing_token",
      expires: DateTime.add(DateTime.utc_now(), 1, :minute)
    })

    assert GCPToken.get_token(key) == "existing_token"
  end

  test "reloads token if stored token expired" do
    reassign_env(:mobile_app_backend, GCPToken, gcp_provider_name: nil)

    reassign_env(
      :goth,
      :json,
      Jason.encode!(%{
        refresh_token: "a",
        client_id: "b",
        client_secret: "c",
        quota_project_id: ""
      })
    )

    Process.put(
      :goth_http_client,
      {fn _ ->
         {:ok,
          %{
            status: 200,
            headers: [],
            body: Jason.encode!(%{accessToken: "new_token", expireTime: ~U[2025-10-14 16:28:00Z]})
          }}
       end, []}
    )

    key = make_ref()

    reassign_persistent_term(key, %GCPToken.StoredToken{
      token: "old_token",
      expires: DateTime.add(DateTime.utc_now(), -1, :second)
    })

    assert GCPToken.get_token(key) == "new_token"
  end
end
