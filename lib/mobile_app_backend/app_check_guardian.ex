defmodule MobileAppBackend.AppCheck.Guardian do
  # , token_verify_module: MobileAppBackend.CustomTokenVerify
  use Guardian, otp_app: :mobile_app_backend, allowed_algos: ["RS256"]

  def subject_for_token(%{id: id}, _claims) do
    sub = to_string(id)
    {:ok, sub}
  end

  def subject_for_token(_, _) do
    {:error, :reason_for_error}
  end

  def resource_from_claims(%{"sub" => id}) do
    {:ok, id}
  end

  def resource_from_claims(_claims) do
    {:error, :reason_for_error}
  end
end

# Protocol.derive(Jason.Encoder, JOSE.JWK)

defmodule MobileAppBackend.CustomTokenVerify do
  @behaviour Guardian.Token.Verify

  def verify_claim(mod, claim_key, claims, options) do
    require Logger
    Logger.error("HIT")
    # Logger.error("MOD: #{mod}  CLAIMS: #{claims}, OPTS: #{options}")
    {:ok, %{}}
  end
end
