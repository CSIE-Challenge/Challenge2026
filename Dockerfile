FROM debian:bookworm-slim AS godot-download

ARG GODOT_VERSION=4.6.3
ARG GODOT_STATUS=stable

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates unzip wget \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget -O godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64.zip" \
	&& unzip godot.zip \
	&& mv "Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" /usr/local/bin/godot \
	&& chmod +x /usr/local/bin/godot

FROM debian:bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		dumb-init \
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

EXPOSE 7777/udp
EXPOSE 7749/tcp

ENTRYPOINT ["dumb-init", "--", "godot", "--headless", "--path", "/app", "--"]
CMD ["--server", "--port", "7777"]
