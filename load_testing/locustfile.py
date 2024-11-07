import datetime
import random
from hashlib import sha256
from zoneinfo import ZoneInfo

import requests
from locust import HttpUser, between, events, task

from phoenix_channel import PhoenixChannel, PhoenixChannelUser

all_station_ids: list[str] = list(map(lambda stop: stop["id"], requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "id", "filter[location_type]": "1"},
).json()["data"]))

standalone_bus_stop_ids: list[str] = list(map(lambda stop: stop["id"],
filter(lambda stop: stop["relationships"]["parent_station"]["data"] is None, requests.get(
    "https://api-v3.mbta.com/stops",
    {"fields[stop]": "id", "filter[location_type]": "0", "filter[route_type]": "3"},
).json()["data"])))

all_stations_and_bus = all_station_ids + standalone_bus_stop_ids


all_routes: list[dict] = requests.get(
    "https://api-v3.mbta.com/routes",
    {},
).json()["data"]

initial_global_headers = {}
initial_rail_headers = {}


@events.test_start.add_listener
def on_init(environment, **_kwargs):
    # Assume some % of users have already loaded global data before.
    # Fetch global + rail data once from target host to use as baseline etag headers for newly spawned users
    host = environment.host
    print(f'environment host: {host}')

    global initial_global_headers
    global initial_rail_headers

    initial_global_response = requests.get(f"{host}/api/global")
    initial_global_headers = {}
    if initial_global_response.status_code == 200:
        initial_global_headers = {"if-none-match": sha256(initial_global_response.text.encode()).hexdigest()}

    initial_rail_response = requests.get(f"{host}/api/shapes/map-friendly/rail")
    initial_rail_headers = {}
    if initial_rail_response.status_code == 200:
        initial_rail_headers = {"if-none-match": sha256(initial_rail_response.text.encode()).hexdigest()}


@events.init_command_line_parser.add_listener
def _(parser):
    parser.add_argument("--api-key", type=str, env_var="V3_API_KEY", default="", help="API Key for the V3 API. Set to avoid rate limiting.")

class MobileAppUser(HttpUser, PhoenixChannelUser):
    wait_time = between(5, 60)
    socket_path = "/socket"

    prob_reset_initial_load = 0.02
    prob_reset_nearby_stops = 0.3
    prob_filtered_stop_details = 0.76
    prob_already_loaded_global = 0.8
    prob_station = 0.6

    location: dict | None = None
    stop_id: str | None = None
    nearby_stop_ids: list[str] | None = None
    alerts_channel: PhoenixChannel | None = None
    predictions_channel: PhoenixChannel | None = None
    vehicles_channel: PhoenixChannel | None = None
    global_headers: dict = {}
    rail_headers: dict = {}
    v3_api_headers: dict = {} 

   


    def on_start(self):
        self.v3_api_headers = {"x-api-key" : self.environment.parsed_options.api_key}

        if random.random() < self.prob_already_loaded_global:
            self.global_headers = initial_global_headers
            self.rail_headers = initial_rail_headers

        self.app_reload()

    @task(1)
    def app_reload(self):
        print(f'headers in app reload: {self.global_headers}')
        global_response = self.client.get("/api/global", headers=self.global_headers)
        if global_response.status_code == 200:
            self.global_headers = {"if-none-match": sha256(global_response.text.encode()).hexdigest()}
        
        rail_response = self.client.get("/api/shapes/map-friendly/rail", headers=self.rail_headers)
        if rail_response.status_code == 200:
            self.rail_headers = {"if-none-match": sha256(rail_response.text.encode()).hexdigest()}

        if self.alerts_channel is not None:
                self.alerts_channel.leave()
                self.alerts_channel = None
        
        self.alerts_channel = self.socket.channel("alerts")
        self.alerts_channel.join()
    
    def fetch_schedules_for_stops(self, stop_ids):
        self.client.get(f'/api/schedules?stop_ids={stop_ids}&date_time={datetime.datetime.now().astimezone(ZoneInfo("America/New_York")).replace(microsecond=0).isoformat()}' , name="/api/schedules",)


    @task(10)
    def nearby_transit(self):
        nearby_station_ids = random.sample(all_station_ids, random.randint(2,5))
        nearby_bus_ids = random.sample(standalone_bus_stop_ids, random.randint(0,10))
       
        self.nearby_stop_ids = nearby_station_ids + nearby_bus_ids
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
        
        self.fetch_schedules_for_stops(self.nearby_stop_ids)



    @task(5)
    def stop_details(self):
        if random.random() < self.prob_station:
            self.stop_id = random.choice(all_station_ids)
        else: 
            self.stop_id = random.choice(standalone_bus_stop_ids)
        
        self.fetch_schedules_for_stops([self.stop_id])
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
            self.stop_id = random.choice(all_stations_and_bus)
        predictions_for_stop = requests.get(
            "https://api-v3.mbta.com/predictions", 
            params={"stop": self.stop_id}, headers=self.v3_api_headers).json()["data"]
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
