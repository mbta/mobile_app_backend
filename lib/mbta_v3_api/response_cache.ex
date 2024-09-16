defmodule MBTAV3API.ResponseCache do
  @moduledoc """
  Cache used to reduce the number of duplicate API calls.
  Responses are stored as tuple {last_updated_timestamp, response}
  """
  use Nebulex.Cache, otp_app: :mobile_app_backend, adapter: Nebulex.Adapters.Local


  def cache_key(url, params) do
    "#{url} params=#{inspect(params)}"
  end
end
