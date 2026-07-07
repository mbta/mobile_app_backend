# Load Testing

Load testing for the backend, built with [Locust](https://locust.io).

## 1. Run Locust

### Basic Local Usage

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

### Dev Orange Usage
``` 
$ cd load_testing/
$ asdf install
$ poetry install
$ poetry run locust -H https://mobile-app-backend-dev-orange.mbtace.com -u 1 -t 1m
```

## 2.Open Locust UI

You should see the following output

```
...locust.main: Starting web interface at http://0.0.0.0:8089
...locust.main: Starting Locust 2.29.1
```

Navigating to `http://0.0.0.0:8089` in your browser will open a UI that allows you to customize the load testing configuration.

**Note**: Under "Custom Parameters", you can pass your V3 API Key to ensure that you will not hit the rate limit if simulating a high volume of users. The V3 API is hit directly to fetch stop, route, and prediction information in order to get realistic parameters to pass to our application.

## Prod Load Estimation
The following Splunk query provides the maximum requests per 5 min within the time period
[Splunk query](https://mbta.splunkcloud.com/en-US/app/search/search?earliest=1780876800&latest=1783468800&q=search%20index%3Dmobile-app-backend-prod-application%20%2Fapi%20status%3D%22200%22%20%7C%20bucket%20_time%20span%3D5m%20%7C%20stats%20count%20as%20api_count%20by%20path%2C%20_time%20%7C%20stats%20max(api_count)%20as%20max_5min_count%20by%20path%20%7C%20sort%20by%20max_5min_count%20desc&display.page.search.mode=fast&dispatch.sample_ratio=1&display.general.type=visualizations&workload_pool=&display.page.search.tab=visualizations&display.visualizations.charting.chart=pie&sid=1783436141.18936
)