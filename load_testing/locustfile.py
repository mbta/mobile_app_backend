import random

import requests
from locust import HttpUser, between, task

from phoenix_channel import PhoenixChannel, PhoenixChannelUser

all_stops: list[dict] = requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "latitude,longitude", "filter[location_type]": "0"},
).json()["data"]


class MobileAppUser(HttpUser, PhoenixChannelUser):
    wait_time = between(1, 5)
    socket_path = "/socket"

    prob_reset_map_data = 0.02
    prob_reset_location = 0.3
    prob_reset_nearby_stops = 0.3

    location: dict | None = None
    nearby_stop_ids: list[str] | None = None
    stops_channel: PhoenixChannel | None = None
    has_map_data = False

    @task
    def load_map(self):
        if not self.has_map_data or random.random() < self.prob_reset_map_data:
            self.client.get("/api/global")
            self.client.get("/api/shapes/map-friendly/rail")
            self.has_map_data = True

    @task
    def nearby_transit(self):
        if self.location is None or random.random() < self.prob_reset_location:
            self.location = random.choice(all_stops)["attributes"]
        assert self.location is not None
        with self.client.rename_request("/api/nearby"):
            self.nearby_stop_ids = self.client.get(
                "/api/nearby",
                params={
                    "latitude": self.location["latitude"],
                    "longitude": self.location["longitude"],
                },
            ).json()["stop_ids"]
        if (
            self.stops_channel is not None
            and random.random() < self.prob_reset_nearby_stops
        ):
            print("Leaving")
            self.stops_channel.leave()
            self.stops_channel = None
        if self.stops_channel is None:
            self.stops_channel = self.socket.channel(
                "predictions:stops", {"stop_ids": self.nearby_stop_ids}
            )
            self.stops_channel.join()
