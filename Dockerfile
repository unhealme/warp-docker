ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE}

ARG WARP_VERSION
ARG SS_RUST_VERSION=1.25.0
ARG COMMIT_SHA
ARG TARGETPLATFORM

LABEL org.opencontainers.image.authors="praxe"
LABEL org.opencontainers.image.url="https://github.com/unhealme/warp-docker"
LABEL WARP_VERSION=${WARP_VERSION}
LABEL SS_RUST_VERSION=${SS_RUST_VERSION}
LABEL COMMIT_SHA=${COMMIT_SHA}

COPY entrypoint.sh /entrypoint.sh
COPY ss-local.conf /etc/shadowsocks-rust/ss-local.conf
COPY ./healthcheck /healthcheck

# install dependencies
RUN case ${TARGETPLATFORM} in \
      "linux/amd64")   export ARCH="x86_64" ;; \
      "linux/arm64")   export ARCH="aarch64" ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    echo "Building for ${TARGETPLATFORM} with shadowsocks-rust ${SS_RUST_VERSION}" &&\
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl gnupg lsb-release sudo jq ipcalc xz-utils && \
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    apt-get clean && \
    apt-get autoremove -y && \
    curl -LSsf "https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.${ARCH}-unknown-linux-musl.tar.xz" | tar -x --xz -C /usr/bin && \
    chmod +x /entrypoint.sh && \
    chmod +x /healthcheck/index.sh && \
    useradd -m -s /bin/bash warp && \
    echo "warp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/warp

USER warp

# Accept Cloudflare WARP TOS
RUN mkdir -p /home/warp/.local/share/warp && \
    echo -n 'yes' > /home/warp/.local/share/warp/accepted-tos.txt

ENV WARP_SLEEP=2
ENV REGISTER_WHEN_MDM_EXISTS=
ENV WARP_LICENSE_KEY=
ENV BETA_FIX_HOST_CONNECTIVITY=
ENV WARP_ENABLE_NAT=

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD /healthcheck/index.sh

ENTRYPOINT ["/entrypoint.sh"]
