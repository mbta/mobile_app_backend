# --- Set up Elixir build ---
FROM hexpm/elixir:1.18.4-erlang-27.3.4.2-alpine-3.22.1 AS elixir-builder

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
COPY ./assets assets
COPY ./config config
COPY ./lib lib
COPY ./priv priv
RUN mix compile
RUN mix assets.deploy
RUN mix phx.digest
RUN mix release


# --- Set up runtime container ---
FROM alpine:3.22.1

ENV LANG=C.UTF-8 MIX_ENV=prod REPLACE_OS_VARS=true

RUN apk add --no-cache \
  dumb-init libgcc libstdc++ ncurses-libs

# Fetch Amazon RDS certificate chain
RUN wget -O /usr/local/share/amazon-certs.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
RUN chmod a=r /usr/local/share/amazon-certs.pem

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
