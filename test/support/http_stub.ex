defmodule Test.Support.HTTPStub do
  @moduledoc """
  An implementation of `MobileAppBackend.HTTP` that routes all requests through `Test.Support.Data`.

  Can be used with
  ```elixir
  Mox.stub_with(MobileAppBackend.HTTPMock, Test.Support.HTTPStub)
  ```
  """
  @behaviour MobileAppBackend.HTTP

  alias Test.Support.Data

  @impl MobileAppBackend.HTTP
  def request(req) do
    Req.request(req, cache: false, plug: &Data.respond/1)
  end

  @impl MobileAppBackend.HTTP
  def get(req, opts \\ []) do
    Req.get(req, cache: false, plug: &Data.respond/1)
  end
end
