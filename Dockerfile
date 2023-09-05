FROM ghcr.io/blinklabs-io/haskell:8.10.7-3.8.1.0-1 as cardano-node-build
# Install cardano-node
ARG NODE_VERSION=8.1.2
ENV NODE_VERSION=${NODE_VERSION}
RUN echo "Building tags/${NODE_VERSION}..." \
    && echo tags/${NODE_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/${NODE_VERSION} \
    && echo "with-compiler: ghc-${GHC_VERSION}" >> cabal.project.local \
    && echo "package cardano-crypto-praos" >> cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >> cabal.project.local \
    && echo "tests: False" >> cabal.project.local \
    && cabal update \
    && cabal build all \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/cardano-node-${NODE_VERSION}/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/cardano-cli-${NODE_VERSION}/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-${GHC_VERSION}/ /usr/local/share/doc/ghc-${GHC_VERSION}/ \
    && rm -rf /code/cardano-node/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-${GHC_VERSION}

FROM debian:bookworm-slim as cardano-node
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
COPY --from=cardano-node-build /usr/local/lib/ /usr/local/lib/
COPY --from=cardano-node-build /usr/local/include/ /usr/local/include/
COPY --from=cardano-node-build /root/.local/bin/cardano-* /usr/local/bin/
COPY --from=ghcr.io/blinklabs-io/nview:0.1.0 /usr/local/bin/nview /usr/local/bin/
COPY --from=ghcr.io/input-output-hk/mithril-client:2335.0-a6caa1c /app/bin/mithril-client /usr/local/bin/
COPY bin/ /usr/local/bin/
COPY config/ /opt/cardano/config/
RUN apt-get update -y && \
  apt-get install -y \
    bc \
    curl \
    iproute2 \
    jq \
    libffi8 \
    libgmp10 \
    liblmdb0 \
    libncursesw5 \
    libnuma1 \
    libsystemd0 \
    libssl3 \
    libtinfo6 \
    llvm-14-runtime \
    netbase \
    pkg-config \
    procps \
    sqlite3 \
    wget \
    zlib1g && \
  rm -rf /var/lib/apt/lists/*
RUN curl -sLo /usr/local/bin/gLiveView.sh \
  https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/gLiveView.sh && \
  curl -sL \
  https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/env | \
  sed \
    -e "s|#CNODE_HOME=.*|CNODE_HOME=/opt/cardano |" \
    -e "s|#CNODE_PORT=.*|CNODE_PORT=\${CARDANO_PORT:-3001} |" \
    -e "s|#CONFIG=.*|CONFIG=\${CARDANO_CONFIG:-/opt/cardano/config/\${CARDANO_NETWORK:-\${NETWORK:-mainnet}}/config.json} |" \
    -e "s|#SOCKET=.*|SOCKET=\${CARDANO_SOCKET_PATH:-/opt/cardano/ipc/socket} |" \
    -e "s|#TOPOLOGY=.*|TOPOLOGY=\${CARDANO_TOPOLOGY:-/opt/cardano/config/\${CARDANO_NETWORK:-\${NETWORK:-mainnet}}/topology.json} |" \
    -e "s|#LOG_DIR=.*|LOG_DIR=\${CARDANO_LOG_DIR:-/opt/cardano/logs} |" \
    -e "s|#DB_DIR=.*|DB_DIR=\${CARDANO_DATABASE_PATH:-/opt/cardano/data} |" > \
    /usr/local/bin/env && \
  chmod +x /usr/local/bin/*
EXPOSE 3001 12788 12798
ENTRYPOINT ["/usr/local/bin/entrypoint"]
