FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /usr/sbin/nologin angels

# Release tag. b100+ carries the per-(ip,port) heartbeat limiter (the b94 master
# throttles per SOURCE IP, so only one server behind a shared VPS IP can stay
# listed). Keep this pinned until a release with that fix exists.
ARG ANGELS95_TAG=b100
# Canonical repo (the old odelyzid/... path only redirects).
ARG ANGELMASTER_URL=https://github.com/TribeWarez/Angels-95/releases/download/${ANGELS95_TAG}/AngelMaster-${ANGELS95_TAG}-linux-x86_64
RUN curl -fsSL -o /usr/local/bin/AngelMaster "$ANGELMASTER_URL" \
    && chmod +x /usr/local/bin/AngelMaster \
    && chown angels:angels /usr/local/bin/AngelMaster

# The updater verifies the RUNNING build against this label; without it a
# failed rebuild followed by `up --no-build` looks like a successful update.
LABEL org.opencontainers.image.version="${ANGELS95_TAG}" \
      org.opencontainers.image.source="https://github.com/TribeWarez/Angels-95"

USER angels

EXPOSE 27900/udp 27950

ENTRYPOINT ["/usr/local/bin/AngelMaster"]