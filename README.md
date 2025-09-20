# docker-cardano-node

Builds a Cardano full node from source on Debian. This image attempts to keep
interface compatibility with
[cardano-node](https://github.com/IntersectMBO/cardano-node), but may diverge
slightly, particularly with any Nix-specific paths.

We found that the learning curve for using Nix is too high for many in the
community who need to run a full node for various reasons but don't want to
get too heavy into learning a new operating system just to extend a container
image. This image uses FHS paths and installs into `/usr/local` while taking
advantage of multi-stage image builds to reduce final image size over the
official Nix-based distribution.

## Running a Cardano Node

The container image has some differing behaviors depending on how it's
invoked. There is a `NETWORK` environment variable which can be used as a
short cut to starting nodes on a specific named Cardano network with a default
configuration.

We recommend using this method for running the container if you are not
familiar with running a node.

For nodes on the `preprod` and `mainnet` networks, the container will start
fetching the latest Mithril snapshot if an empty data directory is detected.
This snapshot will be used to bootstrap the node into an operating state much
more rapidly than doing a sync from the beginning of the chain. This behavior
can be disabled in the advanced path below.

### Using NETWORK (Recommended)

Using the `NETWORK` environment variable causes the entrypoint script to use
the simplified path. The only configurable option in this path is the
`NETWORK` environment variable itself.

This is in keeping with the IOHK image behavior.

To run a Cardano full node on preprod:

```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/data/db \
  -v node-ipc:/ipc \
  -e NETWORK=preprod \
  -p 3001:3001 \
  ghcr.io/blinklabs-io/cardano-node
```

Node logs can be followed:

```bash
docker logs -f cardano-node
```

The node can be monitoring using [nview](https://github.com/blinklabs-io/nview)
from within the container. We run `nview` from within the same container as
our running node to get access to information about the node process.

```bash
docker exec -ti cardano-node nview
```

#### Running the Cardano CLI

To run a Cardano CLI command, we use the `node-ipc` volume from our node.

```bash
docker run --rm -ti \
  -e NETWORK=preprod \
  -v node-ipc:/ipc \
  ghcr.io/blinklabs-io/cardano-node cli <command>
```

This can be added to a shell alias:

```bash
alias cardano-cli="docker run --rm -ti \
  -e NETWORK=preprod \
  -v node-ipc:/ipc \
  ghcr.io/blinklabs-io/cardano-node cli"
```

Now, you can use cardano-cli commands as you would, normally.

```bash
cardano-cli query tip --network-magic 1
```

Or, for a node running with NETWORK=mainnet:

```bash
cardano-cli query tip --mainnet
```

### Using run (Recommended for SPO/Advanced)

Using the `run` argument to the image causes the entrypoint script to use the
fully configurable code path. Do not set the `NETWORK` environment variable.

To run a Cardano full node on mainnet with minimal configuration and defaults:

Cardano Node before 10.3.1:
```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/opt/cardano/data \
  -v node-ipc:/opt/cardano/ipc \
  -p 3001:3001 \
  ghcr.io/blinklabs-io/cardano-node run
```

**NOTE** The container paths for persist disks are different in this mode

Cardano Node 10.3.1 and above:
```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/data/db \
  -v node-ipc:/ipc \
  -p 3001:3001 \
  ghcr.io/blinklabs-io/cardano-node run
```

The above maps port 3001 on the host to 3001 on the container, suitable
for use as a mainnet relay node. We use docker volumes for our persistent data
storage and IPC (interprocess communication) so they live beyond the lifetime
of the container. To mount local host paths instead of using Docker's built in
volumes, use the local path on the left side of a `-v` argument.

An example of a more advanced configuration, running a block producer for
mainnet:

```bash
docker run --detach \
  --name cardano-node \
  --restart unless-stopped \
  -e CARDANO_BLOCK_PRODUCER=true \
  -e CARDANO_SHELLEY_KES_KEY=/opt/cardano/config/keys/kes.skey \
  -e CARDANO_SHELLEY_OPERATIONAL_CERTIFICATE=/opt/cardano/config/keys/node.cert \
  -e CARDANO_SHELLEY_VRF_KEY=/opt/cardano/config/keys/vrf.skey \
  -v /srv/cardano/node-keys:/opt/cardano/config/keys \
  -v /srv/cardano/node-db:/data/db \
  -v /srv/cardano/node-ipc:/ipc \
  -p 3001:3001 \
  -p 12798:12798 \
  ghcr.io/blinklabs-io/cardano-node run
```

##### Dynamic Block Forging

To start a block producer in non-producing mode initially (for dynamic block forging):

```bash
docker run --detach \
  --name cardano-node \
  --restart unless-stopped \
  -e CARDANO_BLOCK_PRODUCER=true \
  -e START_AS_NON_PRODUCING=true \
  -e CARDANO_SHELLEY_KES_KEY=/opt/cardano/config/keys/kes.skey \
  -e CARDANO_SHELLEY_OPERATIONAL_CERTIFICATE=/opt/cardano/config/keys/node.cert \
  -e CARDANO_SHELLEY_VRF_KEY=/opt/cardano/config/keys/vrf.skey \
  -v /srv/cardano/node-keys:/opt/cardano/config/keys \
  -v /srv/cardano/node-db:/data/db \
  -v /srv/cardano/node-ipc:/ipc \
  -p 3001:3001 \
  -p 12798:12798 \
  ghcr.io/blinklabs-io/cardano-node run
```

With dynamic block forging enabled, you can control block production without restarting the node:

- **Enable block forging**: Ensure credential files are present and send SIGHUP
  ```bash
  docker exec cardano-node pkill -SIGHUP cardano-node
  ```

- **Disable block forging**: Move/rename credential files and send SIGHUP
  ```bash
  docker exec cardano-node mv /opt/cardano/config/keys/kes.skey /opt/cardano/config/keys/kes.skey.disabled
  docker exec cardano-node pkill -SIGHUP cardano-node
  ```

- **Re-enable block forging**: Restore credential files and send SIGHUP
  ```bash
  docker exec cardano-node mv /opt/cardano/config/keys/kes.skey.disabled /opt/cardano/config/keys/kes.skey
  docker exec cardano-node pkill -SIGHUP cardano-node
  ```

The above uses Docker's built in supervisor to restart a container which fails
for any reason. This will also cause the container to automatically restart
after a host reboot, so long as Docker is configured to start on boot. We
set variables to configure a block producer and pass the paths to the 3 keys
we need. Our node's persistent data and client communication socket are mapped
to `/srv/cardano/node-db` and `/srv/cardano/node-ipc` on the host,
respectively. This allows for running applications directly on the host which
may need access to these. We also map `/srv/cardano/node-keys` on the host to
a path within the container to support running as a block producer. Last, we
add mapping the host's port 12798 to the container 12798, which is the port for
exposing the node's metrics in Prometheus format, for monitoring.

This mode of operation allows configuring multiple facets of the node using
environment variables, described below.

Node logs can be followed:

```bash
docker logs -f -n 500 cardano-node
```

Adding the `-n 500` to the logs command limits the logs to the last 500 lines
before following.

#### Configuration using environment variables

The power in using `run` is being able to configure the node's behavior to
provide the correct type of service.

This behavior can be changed via the following environment variables:

- `CARDANO_CONFIG_BASE`
  - A directory which contains configuration files (default:
    `/opt/cardano/config`)
  - This variable is used as the base for other configuration variable default
- `CARDANO_BIND_ADDR`
  - IP address to bind for listening (default: `0.0.0.0`)
- `CARDANO_BLOCK_PRODUCER`
  - Set to true for a block producing node (default: false)
  - Requires key files and node certificates to be present to start
- `CARDANO_CONFIG`
  - Full path to the Cardano node configuration (default:
    `${CARDANO_CONFIG_BASE}/mainnet/config.json`)
  - Use your own configuration file to modify the node behavior fully
- `CARDANO_DATABASE_PATH`
  - A directory which contains the ledger database files (default:
    `/data/db`)
  - This is the location for persistent data storage for the ledger
- `CARDANO_PORT`
  - TCP port to bind for listening (default: `3001`)
- `CARDANO_RTS_OPTS`
  - Controls the Cardano node's Haskell runtime (default:
    `-N2 -A64m -I0 -qg -qb --disable-delayed-os-memory-return`)
  - This allows tuning the node for specific use cases or resource contraints
- `CARDANO_SOCKET_PATH`
  - UNIX socket path for listening (default: `/ipc/node.socket`)
  - This socket speaks Ouroboros NtC and is used by client software
- `CARDANO_TOPOLOGY`
  - Full path to the Cardano node topology (default:
    `${CARDANO_CONFIG_BASE}/mainnet/topology.json`)

#### Running a block producer

To run a block producing node, you should, at minimum, configure your topology
to recommended settings and have only your own relays listed. You will need to
set `CARDANO_BLOCK_PRODUCER` to `true` and provide the appropriate key files
and operational certificate.

- `CARDANO_SHELLEY_KES_KEY`
  - Stake pool hot key, authenticates (default:
    `${CARDANO_CONFIG_BASE}/keys/kes.skey`)
- `CARDANO_SHELLEY_VRF_KEY`
  - Stake pool signing key, verifies (default:
    `${CARDANO_CONFIG_BASE}/keys/vrf.skey`)
- `CARDANO_SHELLEY_OPERATIONAL_CERTIFICATE`
  - Stake pool identity certificate (default:
    `${CARDANO_CONFIG_BASE}/keys/node.cert`)
- `START_AS_NON_PRODUCING`
  - Start block producer node in non-producing mode (default: `false`)
  - When set to `true`, adds the `--start-as-non-producing-node` flag
  - Only applies when `CARDANO_BLOCK_PRODUCER=true`
  - Enables dynamic block forging control via SIGHUP signals

#### Controlling Mithril snapshots

If the container does not find a protocolMagicId file within the
`CARDANO_DATABASE_PATH` location, it will initiate Mithril snapshot downloads
for preprod and mainnet networks. This can be disabled by setting
`RESTORE_SNAPSHOT` to `false`.

- `AGGREGATOR_ENDPOINT`
  - Mithril Aggregator URL (default:
    `https://aggregator.release-${CARDANO_NETWORK}.api.mithril.network/aggregator`)
- `GENESIS_VERIFICATION_KEY`
  - Network specific Genesis Verification Key (default:
    `reads file at: ${CARDANO_CONFIG_BASE}/${CARDANO_NETWORK}/genesis.vkey`)
- `SNAPSHOT_DIGEST`
  - Digest identifier to fetch (default: `latest`)

#### Running the Cardano CLI

To run a Cardano CLI command, we use the `node-ipc` volume from our node.

```bash
docker run --rm -ti \
  -v node-ipc:/ipc \
  ghcr.io/blinklabs-io/cardano-node cli <command>
```

This can be added to a shell alias:

```bash
alias cardano-cli="docker run --rm -ti \
  -v node-ipc:/ipc \
  ghcr.io/blinklabs-io/cardano-node cli"
```

Now, you can use cardano-cli commands as you would, normally.

```bash
cardano-cli query tip --mainnet
```
