defmodule MobileAppBackend.ClientConfig do
  @type t :: %__MODULE__{
          mapbox_public_token: String.t()
        }

  @derive Jason.Encoder
  defstruct [:mapbox_public_token]
end
