# derived from https://github.com/SvenskaSpel/locust-plugins/blob/4.4.3/locust_plugins/users/socketio.py
import json
import logging
import time
import urllib
import urllib.parse
from typing import Any

import gevent
import websockets.sync.client as websockets
from gevent.event import AsyncResult
from locust import User
from locust.env import Environment
from locust.exception import LocustError


def ellipsize_string(string: str, length: int) -> str:
    if len(string) <= length:
        return string
    return string[: length - 1] + "…"


class PhoenixSocket:
    closing = False

    def __init__(
        self, environment: Environment, url: str, headers: dict | list
    ) -> None:
        self.environment = environment
        self.url = f"{url}/websocket?vsn=2.0.0"
        self.ws = websockets.connect(f"{url}/websocket?vsn=2.0.0") 
        self.ws_greenlet = gevent.spawn(self.receive_loop)
        self._next_ref = 0
        self.open_pushes: dict[str, PhoenixPush] = dict()
        gevent.spawn(self.sleep_with_heartbeat)

    def receive_loop(self):
        for message in self.ws:
            logging.debug(ellipsize_string(f"WSR: {message}", 256))
            if message != "":
                self.on_message(message)

    def sleep_with_heartbeat(self):
        while True:
            gevent.sleep(15)
            # [null,"2","phoenix","heartbeat",{}]
            heartbeat_push = PhoenixPush(self, None, self.next_ref(), "phoenix", "heartbeat", {})
            heartbeat_push.send()
        

    def channel(self, topic: str, payload: dict[str, Any] | None = None):
        if payload is None:
            payload = dict()
        return PhoenixChannel(self, topic, payload)

    def disconnect(self):
        self.closing = True
        self.ws.close()


    def on_message(self, message):
        [join_ref, ref, topic, event, payload] = json.loads(message)
        self.on_phoenix_message(join_ref, ref, topic, event, payload, len(message))

    def on_phoenix_message(self, join_ref, ref, topic, event, payload, response_length):
        if "predictions:stops:v2" in topic:
            name = "predictions:stops:v2"
        elif "vehicles:routes" in topic:
            name = "vehicles:routes"
        elif "predictions:trip" in topic:
            name = "predictions:trip"
        else: 
            name = topic
        if (
            event == "phx_reply"
            and (push := self.open_pushes.pop(ref, None)) is not None
        ):
            exception = None
            if payload["status"] == "error":
                exception = ValueError(payload["response"])

            self.environment.events.request.fire(
                request_type=f"WS:SEND {push.event}",
                name=name,
                response_time=(time.monotonic() - push.send_time) * 1000,
                response_length=response_length,
                response=payload,
                exception=exception,
            )
            if exception is None:
                push.reply.set(payload["response"])
                
                self.environment.events.request.fire(
                request_type=f"WS:RECV {event}",
                name=name,
                response_time=None,
                response_length=response_length,
            )
            else:
                push.reply.set_exception(exception)
        else:
            self.environment.events.request.fire(
                request_type=f"WS:RECV {event}",
                name=name,
                response_time=None,
                response_length=response_length,
            )

    def next_ref(self) -> str:
        result = str(self._next_ref)
        self._next_ref += 1
        return result


class PhoenixChannel:
    def __init__(
        self, socket: PhoenixSocket, topic: str, payload: dict[str, Any] | None = None
    ):
        self.socket = socket
        if payload is None:
            payload = dict()
        self.join_ref = socket.next_ref()
        
        self.topic = topic
        self.join_push = PhoenixPush(
            socket, self.join_ref, self.join_ref, topic, "phx_join", payload
        )
   

    def join(self):
        self.join_push.send()
    
        return self.join_push.get_reply()

    def leave(self):
        leave_push = PhoenixPush(
            self.socket, self.join_ref, self.socket.next_ref(), self.topic, "phx_leave", {}
        )
        leave_push.send()
        return leave_push.get_reply()

class PhoenixPush:
    def __init__(
        self,
        socket: PhoenixSocket,
        join_ref: str | None,
        ref: str,
        topic: str,
        event: str,
        payload: dict[str, Any] | None = None,
    ):
        self.socket = socket
        self.join_ref = join_ref
        self.ref = ref
        self.topic = topic
        self.event = event
        if payload is None:
            payload = dict()
        self.payload = payload
        self.reply: AsyncResult = AsyncResult()

    def send(self):
        body = json.dumps(
            [self.join_ref, self.ref, self.topic, self.event, self.payload]
        )

        self.socket.open_pushes[self.ref] = self

        logging.debug(f"WSS: {body}")
        self.send_time = time.monotonic()
        self.socket.ws.send(body)

    def get_reply(self):
        return self.reply.get(5)


class PhoenixChannelUser(User):
    """
    A User that includes a Phoenix channel websocket connection.
    You could easily use this a template for plain WebSockets,
    Phoenix channels just happen to be my use case. You can use multiple
    inheritance to combine this with an HttpUser
    (class MyUser(HttpUser, PhoenixChannelUser)
    """

    abstract = True

    socket_path: str | None = None
    ws_headers: list | dict = []

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)

        if self.host is None:
            raise LocustError(
                "You must specify the base host. Either in the host attribute in the User class, or on the command line using the --host option."
            )
        if self.socket_path is None:
            raise LocustError(
                "You must specify the socket path in the socket_path attribute in the User class."
            )
        host = urllib.parse.urlparse(self.host)
        ws_url = host._replace(
            scheme=host.scheme.replace("http", "ws", 1),
            path=f"{self.socket_path}",
        )
        self.socket = PhoenixSocket(
            self.environment, urllib.parse.urlunparse(ws_url), self.ws_headers
        )

    def on_stop(self):
        self.socket.disconnect()
