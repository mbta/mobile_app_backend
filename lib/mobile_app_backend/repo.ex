defmodule MobileAppBackend.Repo do
  use Ecto.Repo,
    otp_app: :mobile_app_backend,
    adapter: Ecto.Adapters.Postgres

  @doc """
  called before each database connection to add RDS IAM auth
  as configured in runtime.exs when database password not set.
  """
  @spec add_iam_credentials(Keyword.t()) :: Keyword.t()
  def add_iam_credentials(config, auth_token_fn \\ &ExAws.RDS.generate_db_auth_token/4) do
    hostname = Keyword.fetch!(config, :hostname)
    username = Keyword.fetch!(config, :username)
    port = Keyword.get(config, :port, 5432)

    token =
      auth_token_fn.(
        hostname,
        username,
        port,
        %{}
      )

    Keyword.merge(config,
      password: token
    )
  end
end
