defmodule MBTAV3API.RepositoryCache.KeyGenerator do
  @moduledoc """
  Generate a readable cache key based on the module, function, and arguments.
  """

  require Logger

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
