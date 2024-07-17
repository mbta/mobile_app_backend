defmodule MobileAppBackend.AppCheck.MockGuardian do
  @moduledoc """
  Fake app check guardian module for testing
  """

  @valid_response %{"iss" => "valid_issuer", "aud" => ["valid_project"], "sub" => "valid_subject"}

  def decode_and_verify(token, _claims, _opts) do
    case token do
      "valid_token" -> {:ok, @valid_response}
      "invalid_token" -> {:error, "invalid_token"}
      "invalid_issuer" -> {:ok, Map.put(@valid_response, "iss", "invalid_issuer")}
      "invalid_project" -> {:ok, Map.put(@valid_response, "aud", ["invalid_project"])}
      "invalid_subject" -> {:ok, Map.put(@valid_response, "sub", "invalid_subject")}
    end
  end
end
