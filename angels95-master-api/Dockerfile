FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /usr/sbin/nologin angels

ARG ANGELS95_TAG=b94
ARG ANGELMASTER_URL=https://github.com/odelyzid/angels-95-omega-tech/releases/download/${ANGELS95_TAG}/AngelMaster-${ANGELS95_TAG}-linux-x86_64
RUN curl -fsSL -o /usr/local/bin/AngelMaster "$ANGELMASTER_URL" \
    && chmod +x /usr/local/bin/AngelMaster \
    && chown angels:angels /usr/local/bin/AngelMaster

USER angels

EXPOSE 27900/udp 27950

ENTRYPOINT ["/usr/local/bin/AngelMaster"]