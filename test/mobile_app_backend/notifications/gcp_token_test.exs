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

    reassign_env(:mobile_app_backend, GCPToken, gcp_provider_name: provider_name)
    reassign_env(:ex_aws, :access_key_id, [""])
    reassign_env(:ex_aws, :secret_access_key, [""])
    reassign_env(:tesla, :adapter, TeslaMockAdapter)

    expires_in = 10
    expires_at = DateTime.utc_now(:second) |> DateTime.add(expires_in, :second)

    expect_tesla_call(
      times: 1,
      returns: %Tesla.Env{status: 200} |> json(%{access_token: "token", expires_in: expires_in}),
      adapter: TeslaMockAdapter
    )

    key = make_ref()
    assert GCPToken.get_token(key) == "token"

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
             scope: "https://www.googleapis.com/auth/firebase.messaging",
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

    assert aws4_hmac_sha256 =~
             ~r"^AWS4-HMAC-SHA256 Credential=/\d+/us-east-1/sts/aws4_request,SignedHeaders=host;x-amz-date,Signature=[0-9a-f]+$"

    assert received_opts == []

    assert :persistent_term.get(key) == %GCPToken.StoredToken{
             token: "token",
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
