defmodule Util.FCMTarget do
  alias MobileAppBackend.User

  @type t :: {:installation_id, String.t()} | {:token, String.t()}

  @spec parse!(%{String.t() => String.t()}) :: t()
  def parse!(payload) do
    {:ok, target} = parse(payload)
    target
  end

  @spec parse(%{String.t() => String.t()}) :: {:ok, t()} | :error
  def parse(payload) do
    case payload do
      %{"fcm_installation_id" => installation_id} when not is_nil(installation_id) ->
        {:ok, {:installation_id, installation_id}}

      %{"fcm_token" => token} when not is_nil(token) ->
        {:ok, {:token, token}}

      _ ->
        :error
    end
  end

  def user_where(target)
  def user_where({:installation_id, installation_id}), do: [fcm_installation_id: installation_id]
  def user_where({:token, token}), do: [fcm_token: token]

  def new_user(target)

  def new_user({:installation_id, installation_id}) do
    %User{fcm_installation_id: installation_id}
  end

  def new_user({:token, token}), do: %User{fcm_token: token}
end
