defmodule MobileAppBackend.AppCheck.TokenMock do
  @moduledoc """
  Fake app check guardian module for testing
  """
  @behaviour MobileAppBackend.AppCheck.Token

  @valid_response_fields %{
    "iss" => "valid_issuer",
    "aud" => ["valid_project"],
    "sub" => "valid_subject",
    # 2034 timestamp
    "exp" => 2_036_773_937
  }

  @impl true
  def peek_headers(_token) do
    %JOSE.JWS{fields: %{"kid" => "target_kid", "typ" => "JWT"}}
  end

  @impl true
  def verify_strict(_jwt, _algos, token) do
    case token do
      "valid_token" ->
        {true, %JOSE.JWT{fields: @valid_response_fields}, %JOSE.JWS{}}

      "invalid_token" ->
        {false, %JOSE.JWS{}, %JOSE.JWT{}}

      "invalid_issuer" ->
        {true, %JOSE.JWT{fields: %{@valid_response_fields | "iss" => "invalid_issuer"}},
         %JOSE.JWS{}}

      "invalid_project" ->
        {true, %JOSE.JWT{fields: %{@valid_response_fields | "aud" => ["invalid_project"]}},
         %JOSE.JWS{}}

      "invalid_subject" ->
        {true, %JOSE.JWT{fields: %{@valid_response_fields | "sub" => "invalid_subject"}},
         %JOSE.JWS{}}

      "expired_token" ->
        {true, %JOSE.JWT{fields: %{@valid_response_fields | "exp" => 1234}}, %JOSE.JWS{}}
    end
  end
end
