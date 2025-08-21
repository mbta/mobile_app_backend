defmodule MobileAppBackend.Search.Algolia.Cache do
  @moduledoc """
  Cache used to reduce the number of calls to the Algolia API.
  """
  use Nebulex.Cache,
    otp_app: :mobile_app_backend,
    adapter: Nebulex.Adapters.Local
end
