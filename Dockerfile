FROM lukemathwalker/cargo-chef:latest-rust-1.53.0 as planner
WORKDIR /app
COPY . .
# Compute a lock-like file for our project
RUN cargo chef prepare --recipe-path recipe.json

FROM lukemathwalker/cargo-chef:latest-rust-1.53.0 as cacher
WORKDIR /app
COPY --from=planner /app/recipe.json recipe.json
# Build our project dependencies, not our application!
RUN cargo chef cook --release --recipe-path recipe.json

# Builder stage
FROM rust:1.53.0

WORKDIR /app
COPY . .
ENV SQLX_OFFLINE true
RUN cargo build --release

# Runtime stage
FROM debian:buster-slim AS runtime

WORKDIR /app
# Install OpenSSL - it is dynamically linked by some of our dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
# Copy the compiled library from the builder environment
# to our runtime environment
COPY --from=builder /app/target/release/zero2prod zero2prod
# We need the configuration files at runtime
COPY configuration configuration
ENV APP_ENVIRONMENT production
ENTRYPOINT ["./zero2prod"]
