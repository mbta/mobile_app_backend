defmodule MobileAppBackendWeb.Plugs.AppCheck do
  @moduledoc """
  Plug for verifying request came from a valid app using Firebase App Check
  https://firebase.google.com/docs/app-check
  """
  use MobileAppBackendWeb, :controller

  import Plug.Conn
  require Logger

  @impl Plug
  def init(opts) do
    opts
  end

  @impl Plug
  def call(conn, _opts) do
    token = List.first(get_req_header(conn, "http_x_firebase_appcheck"))

    case token do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json("missing_app_check_header")
        |> halt()

      token ->
        verify(conn, token)
    end
  end

  @spec verify(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp verify(conn, token) do
    # Perform verification steps defined at https://firebase.google.com/docs/app-check/custom-resource-backend

    peek_headers_fn =
      Application.get_env(:mobile_app_backend, :peek_headers, &JOSE.JWT.peek_protected/1)

    # 1. Obtain the Firebase App Check Public Keys
    with {:ok, jwks} <- MobileAppBackend.AppCheck.JwksApi.read_jwks(),
         %JOSE.JWS{fields: %{"kid" => target_kid} = header_fields} <-
           peek_headers_fn.(token),
         {:ok, secret} <- parse_target_secret(jwks, target_kid),
         # 2. Verify the signature on the App Check token
         # 3. Ensure the token's header uses the algorithm RS256
         {:ok, %{"iss" => issuer, "aud" => projects, "sub" => subject}} <-
           Application.get_env(:mobile_app_backend, MobileAppBackend.AppCheck)[:guardian_module].decode_and_verify(
             token,
             %{},
             secret: secret,
             allowed_algos: ["RS256"]
           ),
         # 4. Ensure the token's header has type JWT
         %{"typ" => "JWT"} <- header_fields,
         # 5. Ensure the token is issued by App Check
         :ok <- validate_issuer(issuer),
         # 6. Ensure the token is not expired (done by decode_and_verify)
         # 7. Ensure the token's audience matches your project
         :ok <- validate_project(projects),
         # 8. The token's subject will be the app ID, you may optionally filter against an allow list
         :ok <- validate_subject(subject) do
      conn
    else
      error ->
        Logger.warning("#{__MODULE__} app_check_failed: #{inspect(error)}")

        conn
        |> put_status(:unauthorized)
        |> json("invalid_token")
        |> halt()
    end
  end

  defp parse_target_secret(jwks, target_kid) do
    case Enum.find(jwks, nil, fn jwk -> Map.get(jwk, "kid") == target_kid end) do
      nil -> {:error, :target_kid_not_found}
      secret_key -> {:ok, secret_key}
    end
  end

  @spec validate_issuer(String.t()) :: :ok | {:error, :invalid_issuer}
  defp validate_issuer(issuer) do
    configured_issuer =
      Application.get_env(:mobile_app_backend, MobileAppBackend.AppCheck)[:issuer]

    if !is_nil(configured_issuer) && configured_issuer == issuer do
      :ok
    else
      {:error, :invalid_issuer}
    end
  end

  @spec validate_project([String.t()]) :: :ok | {:error, :invalid_project}
  defp validate_project(projects) do
    configured_project =
      Application.get_env(:mobile_app_backend, MobileAppBackend.AppCheck)[:project]

    if !is_nil(configured_project) && Enum.any?(projects, &(&1 == configured_project)) do
      :ok
    else
      {:error, :invalid_project}
    end
  end

  @spec validate_subject(String.t()) :: :ok | {:error, :invalid_subject}
  defp validate_subject(subject) do
    configured_subjects =
      Application.get_env(:mobile_app_backend, MobileAppBackend.AppCheck)[:subjects]

    if !is_nil(configured_subjects) && Enum.any?(configured_subjects, &(&1 == subject)) do
      :ok
    else
      {:error, :invalid_subject}
    end
  end
end
