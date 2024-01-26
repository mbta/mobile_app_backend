defmodule MobileAppBackend.HTTP do
  @callback request(Req.Request.t()) :: {:ok, Req.Response.t()} | {:error, term()}

  @spec request(Req.Request.t()) :: {:ok, Req.Response.t()} | {:error, term()}
  def request(req) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.HTTP, Req).request(req)
  end
end
