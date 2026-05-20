ARG BUILD_DATE
ARG FROM_REGISTRY=docker.io
ARG FROM_PATH=library/node
ARG FROM_TAG=krypton-alpine
ARG FROM_IMAGE=${FROM_REGISTRY}/${FROM_PATH}:${FROM_TAG}
FROM ${FROM_IMAGE} AS build

ARG BUILD_DATE
ARG FROM_REGISTRY
ARG FROM_PATH
ARG FROM_TAG
ARG FROM_IMAGE

#ENV DISABLE_IPV6=true

WORKDIR /app

# update corepack
RUN npm install --global corepack@latest
# Install pnpm
RUN corepack enable pnpm


# Copy Web UI
COPY src/package.json src/pnpm-lock.yaml src/pnpm-workspace.yaml ./
RUN pnpm install

# Build UI
COPY src ./
RUN pnpm build

# Build amneziawg-tools
RUN apk add linux-headers build-base go git && \
    git clone https://github.com/amnezia-vpn/amneziawg-tools.git && \
    git clone https://github.com/amnezia-vpn/amneziawg-go && \
    cd amneziawg-go && \
    make && \
    cd ../amneziawg-tools/src && \
    make

FROM ${FROM_IMAGE} AS build-libsql

ARG BUILD_DATE
ARG FROM_REGISTRY
ARG FROM_PATH
ARG FROM_TAG
ARG FROM_IMAGE

#ENV DISABLE_IPV6=true

WORKDIR /app
RUN npm install --no-save --omit=dev libsql

# Copy build result to a new image.
# This saves a lot of disk space.
FROM ${FROM_IMAGE}

ARG BUILD_DATE
ARG FROM_IMAGE
# > Our custom ARGs
# type: rb - ReBuild
ARG TYPE=rb
ARG FROM_TAG=v15.0.3
ARG BUILD_OWNER="AmsterNL"
ARG BUILD_TAG=v15.0.3-${TYPE}
ARG BUILD_TAG_VERSION=${BUILD_TAG}-${BUILD_DATE}

#ENV DISABLE_IPV6=true

LABEL maintainer=${BUILD_OWNER}
LABEL org.opencontainers.image.version="${BUILD_TAG_VERSION}"
LABEL org.opencontainers.image.description="Special image build for update from 14 version"
LABEL org.opencontainers.image.revision="${BUILD_DATE}.${TYPE}"
LABEL org.opencontainers.image.source=https://github.com/wg-easy/wg-easy

WORKDIR /app

HEALTHCHECK --interval=1m --timeout=5s --retries=3 CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1"


# Copy build
COPY --from=build /app/.output /app
# Copy migrations
COPY --from=build /app/server/database/migrations /app/server/database/migrations
# libsql (https://github.com/nitrojs/nitro/issues/3328)
COPY --from=build-libsql /app/node_modules /app/server/node_modules

# cli
COPY --from=build /app/cli/cli.sh /usr/local/bin/cli
RUN chmod +x /usr/local/bin/cli
# Copy amneziawg-go
COPY --from=build /app/amneziawg-go/amneziawg-go /usr/bin/amneziawg-go
RUN chmod +x /usr/bin/amneziawg-go
# Copy amneziawg-tools
COPY --from=build /app/amneziawg-tools/src/wg /usr/bin/awg
COPY --from=build /app/amneziawg-tools/src/wg-quick/linux.bash /usr/bin/awg-quick
RUN chmod +x /usr/bin/awg /usr/bin/awg-quick

# Install Linux packages
RUN apk add --update --no-cache \
    dpkg \
    dumb-init \
    iptables \
    ip6tables \
    nftables \
    kmod \
    iptables-legacy \
    wireguard-go \
    wireguard-tools \
    mc

# Copy mc profile
ADD assets/mc.tar.gz /root/.config
COPY assets/modules /etc

RUN mkdir -p /etc/amnezia
RUN ln -s /etc/wireguard /etc/amnezia/amneziawg

# Use iptables-legacy
RUN update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10 --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-legacy-restore --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-legacy-save
RUN update-alternatives --install /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-legacy 10 --slave /usr/sbin/ip6tables-restore ip6tables-restore /usr/sbin/ip6tables-legacy-restore --slave /usr/sbin/ip6tables-save ip6tables-save /usr/sbin/ip6tables-legacy-save

# Set Environment
ENV DEBUG=Server,WireGuard,Database,CMD,Firewall
ENV PORT=8588
ENV HOST=0.0.0.0
ENV INSECURE=false
ENV INIT_ENABLED=false
ENV DISABLE_IPV6=true

LABEL com.docker.compose.service="wg-easy"
LABEL com.docker.compose.project="wg-easy"

# Run Web UI
CMD ["/usr/bin/dumb-init", "node", "server/index.mjs"]
