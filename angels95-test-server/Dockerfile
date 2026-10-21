FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /usr/sbin/nologin angels

# Release tag. b97+ stamps this into the binary (Source/Version.hpp) and fixes
# the master-side heartbeat limiter. b94's `--campaign` does not exist yet, so
# the COOP service below silently runs plain co-op on this tag.
ARG ANGELS95_TAG=b94
# Canonical repo (the old odelyzid/... path only redirects).
ARG ANGELSERV_URL=https://github.com/TribeWarez/Angels-95/releases/download/${ANGELS95_TAG}/AngelServ-${ANGELS95_TAG}-linux-x86_64
RUN curl -fsSL -o /usr/local/bin/AngelServ "$ANGELSERV_URL" \
    && chmod +x /usr/local/bin/AngelServ

WORKDIR /app

# GameData is gitignored in this repo (large). The build context must contain
# angels95-test-server/GameData/Worlds; scripts/angels95-update.sh refuses to
# update without it rather than baking stale content.
COPY GameData /app/GameData

RUN chown -R angels:angels /app

# The updater verifies the RUNNING build against this label; without it a
# failed rebuild followed by `up --no-build` looks like a successful update.
LABEL org.opencontainers.image.version="${ANGELS95_TAG}" \
      org.opencontainers.image.source="https://github.com/TribeWarez/Angels-95"

USER angels

EXPOSE 27015/udp 27100/udp 8080

ENTRYPOINT ["/usr/local/bin/AngelServ"]