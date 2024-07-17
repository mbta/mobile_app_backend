defmodule MobielAppBackend.ClientConfig do
  @type t :: %__MODULE__{
          mapbox_token: String.t()
        }

  @derive Jason.Encoder
  defstruct [:mapbox_token]
end
