# syntax=docker/dockerfile:1

ARG UPSTREAM_REF=main

FROM debian:bookworm-slim AS upstream

ARG UPSTREAM_REF
RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /upstream
RUN git clone --depth 1 -b "$UPSTREAM_REF" https://github.com/Ap0dexMe0/o11pro-unpacked.git repo

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        ffmpeg \
        python3 \
        python3-pip \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=upstream /upstream/repo/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

COPY --from=upstream /upstream/repo/src /app/src

RUN chmod +x /app/src/RunMe.sh /app/src/o11pro && \
    sed -i \
      -e '/^mkdir -p hls\/live/,/providers cache$/c\mkdir -p /app/data/keys /app/data/epg /app/data/dl /app/data/manifests /app/data/offair /app/data/overlay /app/data/logos /app/data/fonts /app/data/rec /app/data/scripts /app/data/logs /app/data/providers /app/data/cache' \
      -e 's/^PORT="\${1:-1337}"/PORT="${1:-${PORT:-1337}}"/' \
      -e 's/^VERBOSE="\${2:-2}"/VERBOSE="${2:-${VERBOSE:-2}}"/' \
      -e '/^if \[ ! -f "keys.txt" \]; then$/,/^fi$/c\if [ ! -f "/app/data/keys.txt" ]; then\n  touch /app/data/keys.txt\nfi' \
      -e 's|^cp keys.txt keys/|cp /app/data/keys.txt /app/data/keys/|' \
      -e 's|^ARGS="-c o11.cfg -p $PORT -b $BIND -stdout -v $VERBOSE -providers providers -usecdm"|ARGS="-path /app/data -c /app/data/o11.cfg -p $PORT -b $BIND -stdout -v $VERBOSE -providers /app/data/providers -keys /app/data/keys.txt -usecdm"|' \
      -e 's|--dir "\$SCRIPT_DIR/providers"|--dir /app/data/providers|' \
      -e 's|--log "logs/audit.log"|--log "/app/data/logs/audit.log"|' \
      -e 's|--alerts "logs/audit_alerts.log"|--alerts "/app/data/logs/audit_alerts.log"|' \
      /app/src/RunMe.sh

WORKDIR /app/src

ENV GOMEMLIMIT=2GiB \
    GOGC=100 \
    TZ=UTC \
    PYTHONUNBUFFERED=1

EXPOSE 1337 1338 1339

ENTRYPOINT ["./RunMe.sh"]
CMD []
