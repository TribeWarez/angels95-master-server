FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /usr/sbin/nologin angels

ARG ANGELS95_TAG=b94
ARG ANGELSERV_URL=https://github.com/odelyzid/angels-95-omega-tech/releases/download/${ANGELS95_TAG}/AngelServ-${ANGELS95_TAG}-linux-x86_64
RUN curl -fsSL -o /usr/local/bin/AngelServ "$ANGELSERV_URL" \
    && chmod +x /usr/local/bin/AngelServ

WORKDIR /app

COPY GameData /app/GameData

RUN chown -R angels:angels /app

USER angels

EXPOSE 27015/udp 27100/udp 8080

ENTRYPOINT ["/usr/local/bin/AngelServ"]