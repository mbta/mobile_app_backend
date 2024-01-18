defmodule Test.Support.HTTPStub do
  @behaviour MobileAppBackend.HTTP

  def request(req) do
    Req.request(req, cache: false, plug: &Test.Support.Data.respond/1)
  end
end
