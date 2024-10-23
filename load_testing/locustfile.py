import datetime
import random

import requests
from locust import HttpUser, between, task

from phoenix_channel import PhoenixChannel, PhoenixChannelUser

all_stop_ids: list[str] = list(map(lambda stop: stop["id"],requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "latitude,longitude", "filter[location_type]": "0,1"},
).json()["data"]))

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

all_routes: list[dict] = requests.get(
    "https://api-v3.mbta.com/routes",
    {},
).json()["data"]

class MobileAppUser(HttpUser, PhoenixChannelUser):
    wait_time = between(5, 20)
    socket_path = "/socket"

    prob_reset_initial_load = 0.02
    prob_reset_location = 0.3
    prob_reset_nearby_stops = 0.3
    prob_filtered_stop_details = 1

    location: dict | None = None
    nearby_stop_ids: list[str] | None = None
    alerts_channel: PhoenixChannel | None = None
    stops_channel: PhoenixChannel | None = None
    vehicles_channel: PhoenixChannel | None = None
    did_initial_load = False

    @task 
    def initial_app_load(self):
        should_reset = not self.did_initial_load or random.random() < self.prob_reset_initial_load
        if should_reset:
            self.client.get("/api/global")
            self.client.get("/api/shapes/map-friendly/rail")

            if self.alerts_channel is not None:
                    self.alerts_channel.leave()
                    self.alerts_channel = None
            if self.alerts_channel is None:
                nearby_stops_concat = ",".join(self.nearby_stop_ids)
                self.alerts_channel = self.socket.channel("alerts")
                self.alerts_channel.join()
            self.did_initial_load = True


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


    @task
    def stop_details(self):
        selected_stop_id = random.choice(all_stop_ids)
        self.client.get(f'/api/schedules?stop_ids={selected_stop_id}&date_time={datetime.datetime.now().astimezone().replace(microsecond=0).isoformat()}', name="/api/schedules")
        self.client.get(f'/api/stop/map?stop_id={selected_stop_id}', name = "/api/stop/map")
       
        if (
            self.stops_channel is not None
        ):
            self.stops_channel.leave()
            self.stops_channel = None
        if self.stops_channel is None:
            self.stops_channel = self.socket.channel(
                f'predictions:stops:v2:{selected_stop_id}'
            )
            self.stops_channel.join()

        if (random.random() < self.prob_filtered_stop_details):
            if (self.vehicles_channel is not None):
                self.vehicles_channel.leave()
                self.vehicles_channel = None

            route = random.choice(all_routes)

            if (self.vehicles_channel is None):
                self.vehicles_channel = self.socket.channel(
                    f'vehicles:routes:{route["id"]}:0'
                )
                self.vehicles_channel.join()
                self.stops_channel.join()

