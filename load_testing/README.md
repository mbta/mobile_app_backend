# Load Testing

Load testing for the backend, built with [Locust](https://locust.io).

## Basic Local Usage

With `mix phx.server` up in another terminal:

```
$ cd load_testing/
$ asdf install
$ poetry install
$ poetry run locust --host http://localhost:4000 --processes -1
# `processes -1` Launches a worker for each logical core.
# Can also run a specified number of workers.
# See https://docs.locust.io/en/stable/running-distributed.html#single-machine for more options.
```

You should see the following output

```
...locust.main: Starting web interface at http://0.0.0.0:8089
...locust.main: Starting Locust 2.29.1
```

Navigating to `http://0.0.0.0:8089` in your browser will open a UI that allows you to customize the load testing configuration.

**Note**: Under "Custom Parameters", you can pass your V3 API Key to ensure that you will not hit the rate limit if simulating a high volume of users. The V3 API is hit directly to fetch stop, route, and prediction information in order to get realistic parameters to pass to our application.
