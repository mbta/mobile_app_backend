defmodule MobileAppBackend.HTTP do
  @callback request(Req.Request.t()) :: {:ok, Req.Response.t()} | {:error, term()}

  @callback get(Req.url() | keyword() | Req.Request.t(), options :: keyword()) ::
              {:ok, Req.Response.t()} | {:error, Exception.t()}

  @spec request(Req.Request.t()) :: {:ok, Req.Response.t()} | {:error, term()}
  def request(req) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.HTTP, Req).request(req)
  end

  @spec get(Req.url() | keyword() | Req.Request.t(), opts :: keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def get(req, opts \\ []) do
    Application.get_env(:mobile_app_backend, MobileAppBackend.HTTP, Req).get(req, opts)
  end
end
