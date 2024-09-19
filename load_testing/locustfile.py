import random

import requests
from locust import HttpUser, between, task

from phoenix_channel import PhoenixChannel, PhoenixChannelUser

all_stops: list[dict] = requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "latitude,longitude", "filter[location_type]": "0"},
).json()["data"]

rail_stop_ids: list[str] = list(map(lambda stop: stop["id"], requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "id", "filter[location_type]": "0", "filter[route_type]": "0,1"},
).json()["data"]))

cr_stop_ids: list[str] = list(map(lambda stop: stop["id"], requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "id", "filter[location_type]": "0", "filter[route_type]": "2"},
).json()["data"]))

bus_stop_ids: list[str] = list(map(lambda stop: stop["id"], requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "id", "filter[location_type]": "0", "filter[route_type]": "3"},
).json()["data"]))

class MobileAppUser(HttpUser, PhoenixChannelUser):
    wait_time = between(15, 20)
    socket_path = "/socket"

    prob_reset_map_data = 0.02
    prob_reset_location = 0.3
    prob_reset_nearby_stops = 0.3

    location: dict | None = None
    nearby_stop_ids: list[str] | None = None
    stops_channel: PhoenixChannel | None = None
    has_map_data = False

    # @task TODO: re-instate this after global endpoint optimizations
    def load_map(self):
        if not self.has_map_data or random.random() < self.prob_reset_map_data:
            self.client.get("/api/global")
            self.client.get("/api/shapes/map-friendly/rail")
            self.has_map_data = True

    @task
    def nearby_transit(self):
        nearby_rail_ids = random.sample(rail_stop_ids, random.randint(2,8))
        nearby_cr_ids = random.sample(cr_stop_ids, random.randint(0,14))
        nearby_bus_ids = random.sample(bus_stop_ids, random.randint(0,14))
       
        self.nearby_stop_ids = nearby_rail_ids + nearby_cr_ids + nearby_bus_ids
        if (
            self.stops_channel is not None
            and random.random() < self.prob_reset_nearby_stops
        ):
            self.stops_channel.leave()
            self.stops_channel = None
        if self.stops_channel is None:
            nearby_stops_concat = ",".join(self.nearby_stop_ids)
            self.stops_channel = self.socket.channel(
                f'predictions:stops:v2:{nearby_stops_concat}'
            )
            self.stops_channel.join()
