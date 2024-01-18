defmodule Test.Support.HTTPStub do
  @behaviour MobileAppBackend.HTTP

  alias Test.Support.Data

  def request(req) do
    Req.request(req, cache: false, plug: &Data.respond/1)
  end
end
