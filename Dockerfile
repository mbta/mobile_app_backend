# --- Set up Elixir build ---
ARG ELIXIR_VERSION=1.19.5
ARG ERLANG_VERSION=28.5
ARG ALPINE_VERSION=3.23.4

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS elixir-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

RUN apk add --no-cache \
  git
RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /root

COPY ./mix.exs mix.exs
COPY ./mix.lock mix.lock
RUN mix deps.get --only prod
RUN mix deps.compile


# --- Build Elixir release ---
FROM elixir-builder AS app-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

WORKDIR /root

ADD \
  --checksum=sha256:e5bb2084ccf45087bda1c9bffdea0eb15ee67f0b91646106e466714f9de3c7e3 \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  aws-cert-bundle.pem

COPY ./assets assets
COPY ./config config
COPY ./lib lib
COPY ./priv priv
RUN mix compile
RUN mix assets.deploy
RUN mix phx.digest
RUN mix release


# --- Set up runtime container ---
FROM alpine:${ALPINE_VERSION}

ENV LANG=C.UTF-8 MIX_ENV=prod REPLACE_OS_VARS=true

RUN apk add --no-cache \
  dumb-init libgcc libstdc++ ncurses-libs

# Create non-root user
RUN addgroup --system mobileappbackend && adduser --system --ingroup mobileappbackend mobileappbackend
USER mobileappbackend

# Set environment
ENV MIX_ENV=prod PHX_SERVER=true TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /home/mobileappbackend
COPY --from=app-builder --chown=mobileappbackend:mobileappbackend  /root/_build/prod/rel/mobile_app_backend .

COPY --from=app-builder --chown=mobileappbackend:mobileappbackend /root/aws-cert-bundle.pem ./priv/aws-cert-bundle.pem

# HTTP
EXPOSE 4000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["bin/mobile_app_backend", "rpc", "1 + 1"]
CMD ["bin/mobile_app_backend", "start"]
