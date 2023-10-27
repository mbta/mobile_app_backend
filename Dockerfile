# --- Set up Elixir build ---
FROM hexpm/elixir:1.15.7-erlang-26.1.2-debian-bullseye-20231009-slim as elixir-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

RUN apt-get update --allow-releaseinfo-change
RUN apt-get install --no-install-recommends --yes \
  build-essential ca-certificates git
RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /root
ADD . .
RUN mix deps.get --only prod


# --- Build Elixir release ---
FROM elixir-builder as app-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

WORKDIR /root
RUN mix compile
RUN mix assets.deploy
RUN mix phx.digest
RUN mix release


# --- Set up runtime container ---
FROM debian:bullseye-slim

ENV LANG=C.UTF-8 MIX_ENV=prod REPLACE_OS_VARS=true

RUN apt-get update --allow-releaseinfo-change \
  && apt-get install --no-install-recommends --yes dumb-init \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system mobileappbackend && adduser --system --ingroup mobileappbackend mobileappbackend
USER mobileappbackend

# Set environment
ENV MIX_ENV=prod PHX_SERVER=true TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /home/mobileappbackend
COPY --from=app-builder --chown=mobileappbackend:mobileappbackend  /root/_build/prod/rel/mobile_app_backend .

# HTTP
EXPOSE 4000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["bin/mobile_app_backend", "rpc", "1 + 1"]
CMD ["bin/mobile_app_backend", "start"]
