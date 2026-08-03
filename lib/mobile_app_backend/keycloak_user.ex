defmodule MobileAppBackend.KeycloakUser do
  @moduledoc """
  The User schema. All data comes from Keycloak
  """
  use MobileAppBackend.Schema

  @type id :: Ecto.UUID
  @type role :: :developer
  @type t :: %__MODULE__{
          keycloak_id: String.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          roles: [role()]
        }

  schema "users" do
    field :email, :string
    field :keycloak_id, :string
    field :first_name, :string
    field :last_name, :string
    field :roles, {:array, Ecto.Enum}, virtual: true, values: [:developer]

    timestamps()
  end

  @doc """
  Create a new User struct.
  """
  @spec new(
          keycloak_id :: String.t(),
          email :: String.t(),
          first_name :: String.t(),
          last_name :: String.t(),
          roles :: [role()]
        ) :: t()
  def new(keycloak_id, email, first_name, last_name, roles \\ []) do
    %__MODULE__{
      keycloak_id: keycloak_id,
      email: email,
      first_name: first_name,
      last_name: last_name,
      roles: roles
    }
  end

  @doc """
  Returns the Keycloak ID for a user.

  iex> AlertsUI.Models.User.keycloak_id(%AlertsUI.Models.User{keycloak_id: "123", email: "user@example.com"})
  "123"
  """
  @spec keycloak_id(t()) :: String.t()
  def keycloak_id(%__MODULE__{keycloak_id: keycloak_id}), do: keycloak_id
end
