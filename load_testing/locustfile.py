import datetime
import random
from zoneinfo import ZoneInfo

import requests
from locust import HttpUser, between, events, task

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

@events.init_command_line_parser.add_listener
def _(parser):
    parser.add_argument("--api-key", type=str, env_var="V3_API_KEY", default="", help="API Key for the V3 API. Set to avoid rate limiting.")

class MobileAppUser(HttpUser, PhoenixChannelUser):
    wait_time = between(5, 20)
    socket_path = "/socket"

    prob_reset_initial_load = 0.02
    prob_reset_nearby_stops = 0.3
    prob_filtered_stop_details = 0.76

    location: dict | None = None
    stop_id: str | None = None
    nearby_stop_ids: list[str] | None = None
    alerts_channel: PhoenixChannel | None = None
    predictions_channel: PhoenixChannel | None = None
    vehicles_channel: PhoenixChannel | None = None
    did_initial_load = False

    v3_api_headers: dict = {}

    def on_start(self):
        self.v3_api_headers = {"x-api-key" : self.environment.parsed_options.api_key}
        self.app_reload()

    @task(1)
    def app_reload(self):
        self.client.get("/api/global")
        self.client.get("/api/shapes/map-friendly/rail")

        if self.alerts_channel is not None:
                self.alerts_channel.leave()
                self.alerts_channel = None
        
        self.alerts_channel = self.socket.channel("alerts")
        self.alerts_channel.join()
        
        self.did_initial_load = True


    @task(10)
    def nearby_transit(self):
        nearby_rail_ids = random.sample(rail_stop_ids, random.randint(2,8))
        nearby_cr_ids = random.sample(cr_stop_ids, random.randint(0,14))
        nearby_bus_ids = random.sample(bus_stop_ids, random.randint(0,14))
       
        self.nearby_stop_ids = nearby_rail_ids + nearby_cr_ids + nearby_bus_ids
        if (
            self.predictions_channel is not None
            and random.random() < self.prob_reset_nearby_stops
        ):
            self.predictions_channel.leave()
            self.predictions_channel = None

            nearby_stops_concat = ",".join(self.nearby_stop_ids)
            self.predictions_channel = self.socket.channel(
                f'predictions:stops:v2:{nearby_stops_concat}'
            )
            self.predictions_channel.join()


    @task(5)
    def stop_details(self):
        self.stop_id = random.choice(all_stop_ids)
        self.client.get(f'/api/schedules?stop_ids={self.stop_id}&date_time={datetime.datetime.now().astimezone(ZoneInfo("America/New_York")).replace(microsecond=0).isoformat()}' , name="/api/schedules",)
        self.client.get(f'/api/stop/map?stop_id={self.stop_id}', name = "/api/stop/map")
       
        if (
            self.predictions_channel is not None
        ):
            self.predictions_channel.leave()
            self.predictions_channel = None

        self.predictions_channel = self.socket.channel(
            f'predictions:stops:v2:{self.stop_id}'
        )
        self.predictions_channel.join()

        if (random.random() < self.prob_filtered_stop_details):
            if (self.vehicles_channel is not None):
                self.vehicles_channel.leave()
                self.vehicles_channel = None

            route = random.choice(all_routes)

            self.vehicles_channel = self.socket.channel(
                f'vehicles:routes:{route["id"]}:0'
            )
            self.vehicles_channel.join()

    @task(5)
    def trip_details(self):
        if self.stop_id is None:
            self.stop_id = random.choice(all_stop_ids)
        predictions_for_stop = requests.get(
            "https://api-v3.mbta.com/predictions", 
            params={"stop": self.stop_id}, v3_api_headers=self.v3_api_headers).json()["data"]
        if (len(predictions_for_stop) != 0):
            prediction = predictions_for_stop[0]
            trip_id = prediction["relationships"]["trip"]["data"]["id"]
            route_id = prediction["relationships"]["route"]["data"]["id"]

        
            self.client.get(f'/api/schedules?trip_id={trip_id}', name="/api/schedules/trip")
            self.client.get(f'/api/trip/map?trip_id={trip_id}', name = "/api/trip/map")
        
            if (
                self.predictions_channel is not None
            ):
                self.predictions_channel.leave()
                self.predictions_channel = None
            self.predictions_channel = self.socket.channel(
                f'predictions:trip:{trip_id}'
            )
            self.predictions_channel.join()

            if (self.vehicles_channel is not None):
                self.vehicles_channel.leave()
                self.vehicles_channel = None

            self.vehicles_channel = self.socket.channel(
                f'vehicles:routes:{route_id}:0'
            )
            self.vehicles_channel.join()
