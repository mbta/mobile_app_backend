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
# See https://docs.locust.io/en/stable/running-distributed.html#single-machine for more options
# Keyboard interrupt is only working if running multiple workers
```
