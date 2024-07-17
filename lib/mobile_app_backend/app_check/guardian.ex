defmodule MobileAppBackend.AppCheck.Guardian do
  @moduledoc """
  Guardian implementation module for encoding/decoding app check tokens.
  https://github.com/ueberauth/guardian
  """

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
