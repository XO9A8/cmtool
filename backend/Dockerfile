# ---------------------------------------------------
# Stage 1: Build binary using official Rust image
# ---------------------------------------------------
FROM rust:slim-bookworm AS builder

WORKDIR /usr/src/app

# Install OpenSSL development dependencies
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Copy dependency manifests
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to build and cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Now copy the actual source code
COPY src ./src

# Clean dummy crate artifacts to ensure a fresh, clean build of real code
RUN rm -rf target/release/deps/cmtool_backend* target/release/cmtool-backend*
RUN cargo build --release

# ---------------------------------------------------
# Stage 2: Runtime image (ultra-lean < 50MB footprint)
# ---------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /usr/src/app/target/release/cmtool-backend /app/cmtool-backend

EXPOSE 3000

ENV PORT=3000
ENV RUST_LOG=info

CMD ["/app/cmtool-backend"]
