# Load Testing

Load testing for the backend, built with [Locust](https://locust.io).

## Basic Local Usage

With `mix phx.server` up in another terminal:

```
$ cd load_testing/
$ asdf install
$ poetry install
$ poetry run locust --host http://localhost:4000
```
