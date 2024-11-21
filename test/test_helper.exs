Mox.defmock(AlertsPubSubMock, for: MobileAppBackend.Alerts.PubSub.Behaviour)
Mox.defmock(AlertsStoreMock, for: MBTAV3API.Store)
Mox.defmock(GlobalDataCacheMock, for: MobileAppBackend.GlobalDataCache)
Mox.defmock(MapboxTokenRotatorMock, for: MobileAppBackend.MapboxTokenRotator.Behaviour)
Mox.defmock(MobileAppBackend.HTTPMock, for: MobileAppBackend.HTTP)
Mox.defmock(PredictionsPubSubMock, for: MobileAppBackend.Predictions.PubSub.Behaviour)
Mox.defmock(PredictionsStoreMock, for: MBTAV3API.Store)
Mox.defmock(RepositoryMock, for: MBTAV3API.Repository)
Mox.defmock(StaticInstanceMock, for: MBTAV3API.Stream.StaticInstance)
Mox.defmock(StreamSubscriberMock, for: MobileAppBackend.Predictions.StreamSubscriber)
Mox.defmock(VehiclesPubSubMock, for: MobileAppBackend.Vehicles.PubSub.Behaviour)
Mox.defmock(VehiclesStoreMock, for: MBTAV3API.Store)

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
