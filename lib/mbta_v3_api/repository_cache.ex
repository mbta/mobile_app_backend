defmodule MBTAV3API.RepositoryCache do
  @moduledoc """
  Cache used to reduce the number of calls to the V3 API.
  """
  use Nebulex.Cache,
    otp_app: :mobile_app_backend,
    adapter: Nebulex.Adapters.Local

  def generate(mod, fun, []) do
    "#{mod}|#{fun}"
  end

  def generate(mod, fun, args) do
    "#{mod}|#{fun}|#{inspect(args)}"
  end
end
