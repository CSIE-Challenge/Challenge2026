# Stage 1: Download Godot binary
FROM --platform=linux/amd64 debian:bookworm-slim AS godot-download
ARG GODOT_VERSION=4.6.3
ARG GODOT_STATUS=stable

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates unzip wget \
	&& rm -rf /var/lib/apt/lists/*

RUN wget -O godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64.zip" \
	&& unzip godot.zip \
	&& mv "Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" /usr/local/bin/godot \
	&& chmod +x /usr/local/bin/godot

# Stage 2: Runtime
FROM --platform=linux/amd64 node:22-bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		dumb-init \
		procps \
		libasound2 \
		libegl1 \
		libfontconfig1 \
		libfreetype6 \
		libgl1 \
		libx11-6 \
		libxcursor1 \
		libxext6 \
		libxfixes3 \
		libxi6 \
		libxinerama1 \
		libxkbcommon0 \
		libxrandr2 \
		libxrender1 \
	&& useradd --create-home --shell /usr/sbin/nologin godot \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=godot-download /usr/local/bin/godot /usr/local/bin/godot

WORKDIR /app
COPY --chown=godot:godot . .
RUN chown godot:godot /app

USER godot

RUN godot --headless --import --path /app

EXPOSE 3000/tcp
EXPOSE 7777-7791/udp

ENV GODOT_BIN=godot
ENV GODOT_PROJECT_PATH=/app

ENTRYPOINT ["dumb-init", "--", "node", "matchmaker/server.js"]
