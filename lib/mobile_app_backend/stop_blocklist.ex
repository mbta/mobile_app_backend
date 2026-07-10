defmodule MobileAppBackend.StopBlocklist do
  @moduledoc """
  Configuration for stops that should be hidden from the app in places like nearby transit, but
  still should be visible in search + on the map.

  For example, due to a long-term but not indefinite stop closure.
  """
  @callback get :: [String.t()]

  def get do
    Application.get_env(
      :mobile_app_backend,
      MobileAppBackend.StopBlocklist,
      MobileAppBackend.StopBlocklist.Impl
    ).get()
  end
end

defmodule MobileAppBackend.StopBlocklist.Impl do
  alias MobileAppBackend.StopBlocklist
  @behaviour StopBlocklist

  def get do
    ["place-symcl"]
  end
end
