# As a workaround we have to build on nodejs 18
# nodejs 20 hangs on build with armv6/armv7
ARG FROM_REGISTRY=docker.io
ARG FROM_PATH=library/node
ARG FROM_TAG=lts-alpine
ARG FROM_IMAGE=${FROM_REGISTRY}/${FROM_PATH}
FROM ${FROM_IMAGE}:${FROM_TAG} AS build_node_modules
ARG FROM_IMAGE

# Update npm to latest
RUN npm install -g npm@latest

# Copy Web UI
COPY src /app
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

ARG FROM_TAG=krypton-alpine
FROM ${FROM_IMAGE}:${FROM_TAG} AS build_amnezia
ARG FROM_IMAGE

WORKDIR /app
# Build amneziawg-tools
RUN apk add linux-headers build-base go git && \
    git clone https://github.com/amnezia-vpn/amneziawg-tools.git && \
    git clone https://github.com/amnezia-vpn/amneziawg-go && \
    cd amneziawg-go && \
    make && \
    cd ../amneziawg-tools/src && \
    make

    # Copy build result to a new image.
# This saves a lot of disk space.
ARG FROM_TAG=lts-alpine
FROM ${FROM_IMAGE}:${FROM_TAG}
HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3
COPY --from=build_node_modules /app /app

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
COPY --from=build_node_modules /node_modules /node_modules

# Copy the needed wg-password scripts
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Copy amneziawg-go
COPY --from=build_amnezia /app/amneziawg-go/amneziawg-go /usr/bin/amneziawg-go
RUN chmod +x /usr/bin/amneziawg-go
# Copy amneziawg-tools
COPY --from=build_amnezia /app/amneziawg-tools/src/wg /usr/bin/awg
COPY --from=build_amnezia /app/amneziawg-tools/src/wg-quick/linux.bash /usr/bin/awg-quick
RUN chmod +x /usr/bin/awg /usr/bin/awg-quick

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    nftables \
    kmod \
    iptables-legacy \
    wireguard-tools \
    mc

COPY assets/modules /etc

RUN mkdir -p /etc/amnezia
RUN ln -s /etc/wireguard /etc/amnezia/amneziawg

# Use iptables-legacy
#RUN update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10 --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-legacy-restore --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-legacy-save
#RUN update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/nftables 20 --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/nftables-restore --slave /usr/sbin/iptables-save iptables-save /usr/sbin/nftables-save

# Set Environment
ENV DEBUG=Server,WireGuard

ADD assets/mc.tar.gz /root/.config

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]