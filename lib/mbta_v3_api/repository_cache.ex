defmodule MBTAV3API.RepositoryCache do
  @moduledoc """
  Cache used to reduce the number of calls to the V3 API.
  """
  use Nebulex.Cache, otp_app: :mobile_app_backend,
  adapter: Nebulex.Adapters.Local,
  default_key_generator: MBTAV3API.RepositoryCache.KeyGenerator
end
