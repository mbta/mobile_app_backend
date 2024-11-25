defmodule MBTAV3API.RepositoryCache do
  @moduledoc """
  Cache used to reduce the number of calls to the V3 API.
  """
  use Nebulex.Cache,
    otp_app: :mobile_app_backend,
    adapter: Nebulex.Adapters.Local,
    default_key_generator: __MODULE__

  @behaviour Nebulex.Caching.KeyGenerator

  @impl Nebulex.Caching.KeyGenerator
  def generate(mod, fun, []) do
    "#{mod}|#{fun}"
  end

  def generate(mod, fun, [arg]) do
    "#{mod}|#{fun}|#{:erlang.phash2(arg)}"
  end

  def generate(mod, fun, args) do
    "#{mod}|#{fun}|#{:erlang.phash2(args)}"
  end
end
