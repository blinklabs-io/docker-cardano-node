FROM debian:stable-slim as builder
ARG CABAL_VERSION=3.6.2.0
ARG GHC_VERSION=8.10.7
ARG NODE_VERSION=1.35.3

WORKDIR /code

# system dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && \
  apt-get install -y \
    automake \
    build-essential \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libnuma-dev \
    libssl-dev \
    libsystemd-dev \
    libtinfo-dev \
    llvm-dev \
    zlib1g-dev \
    make \
    g++ \
    tmux \
    git \
    jq \
    wget \
    libncursesw5 \
    libtool \
    autoconf

# cabal
ENV CABAL_VERSION=${CABAL_VERSION}
ENV PATH="/root/.cabal/bin:/root/.ghcup/bin:/root/.local/bin:$PATH"
RUN wget https://downloads.haskell.org/~cabal/cabal-install-${CABAL_VERSION}/cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && tar -xf cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && rm cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && mkdir -p ~/.local/bin \
    && mv cabal ~/.local/bin/ \
    && cabal update && cabal --version

# GHC
ENV GHC_VERSION=${GHC_VERSION}
RUN wget https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && tar -xf ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && rm ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && cd ghc-${GHC_VERSION} \
    && ./configure \
    && make install

# Libsodium
RUN git clone https://github.com/input-output-hk/libsodium && \
    cd libsodium && \
    git checkout 66f017f1 && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# secp256k1
RUN git clone https://github.com/bitcoin-core/secp256k1 && \
    cd secp256k1 && \
    git checkout ac83be33 && \
    ./autogen.sh && \
    ./configure --enable-module-schnorrsig --enable-experimental && \
    make && \
    make install

# Install cardano-node
ENV NODE_VERSION=${NODE_VERSION}
RUN echo "Building tags/${NODE_VERSION}..." \
    && echo tags/${NODE_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-node.git \
    && cd cardano-node \
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/${NODE_VERSION} \
    && cabal configure --with-compiler=ghc-$GHC_VERSION \
    && echo "package cardano-crypto-praos" >>  cabal.project.local \
    && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
    && cabal build all \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-$GHC_VERSION/cardano-node-${NODE_VERSION}/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-$GHC_VERSION/cardano-cli-${NODE_VERSION}/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-8.10.7/ /usr/local/share/doc/ghc-8.10.7/ \
    && rm -rf /cardano-node/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-8.10.7

FROM debian:stable-slim as cardano-node
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/include/ /usr/local/include/
COPY --from=builder /root/.local/bin/cardano-* /usr/local/bin/
COPY bin/ /usr/local/bin/
COPY config/ /opt/cardano/config/
RUN apt-get update -y && \
  apt-get install -y \
    libffi7 \
    libgmp10 \
    libncursesw5 \
    libnuma1 \
    libsystemd0 \
    libssl1.1 \
    libtinfo6 \
    llvm-11-runtime \
    pkg-config \
    zlib1g && \
  chmod +x /usr/local/bin/* && \
  rm -rf /var/lib/apt/lists/*
EXPOSE 3001 12788 12798
ENTRYPOINT ["/usr/local/bin/entrypoint"]
