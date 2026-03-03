# -- Build Stage -------------------------------------------------------------
FROM elixir:1.15-otp-26 as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && 
    apt-get install -y build-essential git && 
    mix local.hex --force && 
    mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Cache dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Compile configuration
COPY config config
COPY lib lib
COPY priv priv

# Compile release
RUN mix compile
RUN mix release

# -- Runtime Stage -----------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies for the "Dark Factory"
# - git: for worktree management
# - bubblewrap: for sandboxing
# - curl/ca-certificates: for API calls
# - openssl: for BEAM crypto
# - locales: for proper encoding
RUN apt-get update && 
    apt-get install -y --no-install-recommends 
    git 
    bubblewrap 
    curl 
    ca-certificates 
    openssl 
    libncurses5 
    locales 
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/hive .

# Create hive data directories
RUN mkdir -p /data/hive/store /data/hive/worktrees
ENV HIVE_HOME=/data/hive

# Server configuration (overridable at runtime)
ENV HIVE_PORT=4000
ENV HIVE_HOST=0.0.0.0

# Expose Dashboard + API port
EXPOSE 4000

# Set entrypoint
CMD ["bin/hive", "start"]
