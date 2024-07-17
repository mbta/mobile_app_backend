defmodule MobileAppBackendWeb.ConfigController do
  use MobileAppBackendWeb, :controller
      require Logger

  def config(conn, _params) do

    token = List.first(get_req_header(conn, "http_x_firebase_appcheck"))

    case token do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json("missing_app_check_header")

      token ->
        verify(conn, token)
    end
  end

  defp verify(conn, token) do
    # Perform verification steps defined at https://firebase.google.com/docs/app-check/custom-resource-backend
    # 1. Obtain the Firebase App Check Public Keys
    jwk_response = Req.get("https://firebaseappcheck.googleapis.com/v1/jwks", cache: true)

    with {:ok, %{body: %{"keys" => jwks}}} <- jwk_response,
         %JOSE.JWS{fields: %{"kid" => target_kid} = header_fields}   <- JOSE.JWT.peek_protected(token),
         {:ok, secret} <- parse_target_secret(jwks, target_kid),
         # 2. Verify the signature on the App Check token
         # 3. Ensure the token's header uses the algorithm RS256
         {:ok, %{"iss" => issuer, "aud" => projects, "sub" => app_id}} <-
           MobileAppBackend.AppCheck.Guardian.decode_and_verify(token, %{},
             secret: secret,
             allowed_algos: ["RS256"]
           ),
         # 4. Ensure the token's header has type JWT
         %{"typ" => "JWT"} <- header_fields do
      # 5. Ensure the token is issued by App Check
      # TODO
      # :ok <- validate_issuer(issuer)
      # 6. Ensure the token is not expired (done by decode_and_verify)
      # 7. Ensure the token's audience matches your project
      # TODO
      # 8. The token's subject will be the app ID, you may optionally filter against an allow list
      # TODO

      # TODO: actual config
      json(conn, %{"mapbox_token" => "TODO"})
    else
      error ->
        Logger.warning("#{__MODULE__} app_check_failed: #{inspect(error)}")
        conn
        |> put_status(:unauthorized)
        |> json("invalid_token")
    end
  end

  defp parse_target_secret(jwks, target_kid) do
    case Enum.find(jwks, nil, fn jwk -> Map.get(jwk, "kid") == target_kid end) do
      nil -> {:error, :target_kid_not_found}
      secret_key -> {:ok, secret_key}
    end
  end
end
