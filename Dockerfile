FROM ghcr.io/blinklabs-io/haskell:9.6.6-3.12.1.0-3 AS cardano-node-build
# Install cardano-node
ARG NODE_VERSION=10.5.3
ENV NODE_VERSION=${NODE_VERSION}
RUN echo "Building tags/${NODE_VERSION}..." \
    && echo tags/${NODE_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/${NODE_VERSION} \
    && echo "with-compiler: ghc-${GHC_VERSION}" >> cabal.project.local \
    && echo "tests: False" >> cabal.project.local \
    && cabal update \
    && cabal build all \
    && mkdir -p /root/.local/bin/ \
    && cp -p "$(./scripts/bin-path.sh cardano-node)" /root/.local/bin/ \
    && cp -p "$(./scripts/bin-path.sh cardano-tracer)" /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-${GHC_VERSION}/ /usr/local/share/doc/ghc-${GHC_VERSION}/ \
    && rm -rf /code/cardano-node/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-${GHC_VERSION}

FROM ghcr.io/blinklabs-io/cardano-cli:10.12.0.0-1 AS cardano-cli
FROM ghcr.io/blinklabs-io/cardano-configs:20251014-1 AS cardano-configs
FROM ghcr.io/blinklabs-io/mithril-client:0.12.33-1 AS mithril-client
FROM ghcr.io/blinklabs-io/mithril-signer:0.2.276-1 AS mithril-signer
FROM ghcr.io/blinklabs-io/nview:0.11.0 AS nview
FROM ghcr.io/blinklabs-io/txtop:0.13.1 AS txtop

FROM debian:bookworm-slim AS cardano-node
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
COPY --from=cardano-node-build /usr/local/lib/ /usr/local/lib/
COPY --from=cardano-node-build /usr/local/include/ /usr/local/include/
COPY --from=cardano-node-build /root/.local/bin/cardano-* /usr/local/bin/
COPY --from=cardano-configs /config/ /opt/cardano/config/
COPY --from=cardano-cli /usr/local/bin/cardano-cli /usr/local/bin/
COPY --from=mithril-client /bin/mithril-client /usr/local/bin/
COPY --from=mithril-signer /bin/mithril-signer /usr/local/bin/
COPY --from=nview /bin/nview /usr/local/bin/
COPY --from=txtop /bin/txtop /usr/local/bin/
COPY bin/ /usr/local/bin/
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
    lsof \
    netbase \
    pkg-config \
    procps \
    socat \
    sqlite3 \
    wget \
    zlib1g && \
  rm -rf /var/lib/apt/lists/* && \
  chmod +x /usr/local/bin/*
EXPOSE 3001 12788 12798
ENTRYPOINT ["/usr/local/bin/entrypoint"]
