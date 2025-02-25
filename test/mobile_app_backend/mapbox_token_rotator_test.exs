defmodule MobileAppBackend.MapboxTokenRotatorTest do
  use ExUnit.Case
  import Mox
  import Test.Support.Helpers
  alias MobileAppBackend.MapboxTokenRotator

  setup :verify_on_exit!

  test "uses fixed public token if no primary token available" do
    fake_public_token = "pk.fake"

    reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_public_token: fake_public_token
    )

    rotator = start_link_supervised!({MapboxTokenRotator, name: nil})

    assert MapboxTokenRotator.get_public_token(rotator) == fake_public_token
  end

  test "creates temporary token if primary token available" do
    fake_primary_token = "sk.fake"
    fake_username = "fakeusername"
    fake_temporary_token = "tk.fake"

    expiration_interval = :timer.seconds(10)

    approximate_expiration_time =
      DateTime.utc_now()
      |> DateTime.add(expiration_interval, :millisecond)

    test_pid = self()

    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{
           method: :post,
           url: %URI{path: "/tokens/v2/fakeusername"},
           options: %{
             params: %{
               access_token: ^fake_primary_token
             },
             json: %{expires: actual_expiration_time, scopes: ["styles:read", "fonts:read"]}
           }
         } = request ->
        {:ok, actual_expiration_time, _} = actual_expiration_time |> DateTime.from_iso8601()

        expiration_time_drift =
          DateTime.diff(actual_expiration_time, approximate_expiration_time, :millisecond)

        assert expiration_time_drift in 0..100

        send(test_pid, :request_made)

        # use Req.request to still run the JSON decoding step
        Req.request(request,
          adapter: fn request ->
            {request,
             Req.Response.new(status: 201) |> Req.Response.json(%{token: fake_temporary_token})}
          end
        )
      end
    )

    reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_primary_token: fake_primary_token,
      mapbox_username: fake_username,
      token_expiration: expiration_interval,
      token_renewal: :timer.minutes(3)
    )

    rotator = start_link_supervised!({MapboxTokenRotator, name: nil})
    MobileAppBackend.HTTPMock |> allow(self(), rotator)

    receive do
      :request_made -> :ok
    end

    assert MapboxTokenRotator.get_public_token(rotator) == fake_temporary_token
  end

  test "does not crash if token rotation fails" do
    fake_primary_token = "sk.fake"
    fake_username = "fakeusername"

    expiration_interval = :timer.seconds(10)

    approximate_expiration_time =
      DateTime.utc_now()
      |> DateTime.add(expiration_interval, :millisecond)

    test_pid = self()

    expect(
      MobileAppBackend.HTTPMock,
      :request,
      fn %Req.Request{
           method: :post,
           url: %URI{path: "/tokens/v2/fakeusername"},
           options: %{
             params: %{
               access_token: ^fake_primary_token
             },
             json: %{expires: actual_expiration_time, scopes: ["styles:read", "fonts:read"]}
           }
         } = request ->
        {:ok, actual_expiration_time, _} = actual_expiration_time |> DateTime.from_iso8601()

        expiration_time_drift =
          DateTime.diff(actual_expiration_time, approximate_expiration_time, :millisecond)

        assert expiration_time_drift in 0..100

        send(test_pid, :request_made)

        # use Req.request to still run the JSON decoding step
        Req.request(request,
          adapter: fn request ->
            {request,
             Req.Response.new(status: 401) |> Req.Response.json(%{error: :everything_is_bad})}
          end
        )
      end
    )

    reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_primary_token: fake_primary_token,
      mapbox_username: fake_username,
      token_expiration: expiration_interval,
      token_renewal: :timer.minutes(3)
    )

    rotator = start_link_supervised!({MapboxTokenRotator, name: nil})
    MobileAppBackend.HTTPMock |> allow(self(), rotator)

    receive do
      :request_made -> :ok
    end

    assert MapboxTokenRotator.get_public_token(rotator) == ""
  end

  test "refreshes token on interval" do
    refresh_interval = 100

    test_pid = self()

    MobileAppBackend.HTTPMock
    |> expect(
      :request,
      fn %Req.Request{} = request ->
        send(test_pid, :request_made)

        Req.request(request,
          adapter: fn request ->
            {request, Req.Response.new(status: 201) |> Req.Response.json(%{token: "tk.token1"})}
          end
        )
      end
    )
    |> expect(
      :request,
      fn %Req.Request{} = request ->
        send(test_pid, :request_made)

        Req.request(request,
          adapter: fn request ->
            {request, Req.Response.new(status: 201) |> Req.Response.json(%{token: "tk.token2"})}
          end
        )
      end
    )

    reassign_env(:mobile_app_backend, MobileAppBackend.ClientConfig,
      mapbox_primary_token: "sk.token",
      mapbox_username: "user",
      token_expiration: :timer.minutes(5),
      token_renewal: refresh_interval
    )

    rotator = start_link_supervised!({MapboxTokenRotator, name: nil})
    MobileAppBackend.HTTPMock |> allow(self(), rotator)

    first_token_time =
      receive do
        :request_made -> System.monotonic_time(:millisecond)
      end

    assert MapboxTokenRotator.get_public_token(rotator) == "tk.token1"

    second_token_time =
      receive do
        :request_made -> System.monotonic_time(:millisecond)
      end

    assert MapboxTokenRotator.get_public_token(rotator) == "tk.token2"

    actual_interval = second_token_time - first_token_time

    assert (actual_interval - refresh_interval) in -50..50
  end
end
