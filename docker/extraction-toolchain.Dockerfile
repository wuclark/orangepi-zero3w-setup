FROM debian:bookworm-20260824-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        e2fsprogs gzip mount p7zip-full tar util-linux xz-utils \
    && rm -rf /var/lib/apt/lists/*
