defmodule Util.GCP do
  @moduledoc """
  Wrappers for Google Cloud Platform APIs to fill in for the inexplicably-deprecated
  [official Google client libraries](https://github.com/googleapis/elixir-google-api).
  """

  def base_req do
    Req.new(Application.get_env(:mobile_app_backend, __MODULE__, []))
  end
end
