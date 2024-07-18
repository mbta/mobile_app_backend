Mox.defmock(JwksApiMock, for: MobileAppBackend.AppCheck.JwksApi)
Mox.defmock(RepositoryMock, for: MBTAV3API.Repository)
Mox.defmock(MobileAppBackend.HTTPMock, for: MobileAppBackend.HTTP)
Application.put_env(:mobile_app_backend, MobileAppBackend.HTTP, MobileAppBackend.HTTPMock)

case Test.Support.Data.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

ExUnit.start(exclude: [:skip])
{:ok, _} = Application.ensure_all_started(:ex_machina)

unless System.argv() != ["test"] do
  System.at_exit(fn _ -> Test.Support.Data.warn_untouched() end)
end
