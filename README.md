# docker-cardano-node

Builds a Cardano full node from source on Debian. This image attempts to keep
interface compatibility with `inputoutput/cardano-node`, but may diverge
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

### Using run (Recommended for SPO)

Using the `run` argument to the image causes the entrypoint script to use the
fully configurable code path.

To run a Cardano full node on mainnet with minimal configuration and defaults:

```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/opt/cardano/data \
  -v node-ipc:/opt/cardano/ipc \
  -p 3001:3001 \
  ghcr.io/blinklabs-io/cardano-node run
```

The above maps port 3001 on the host to 3001 on the container, suitable
for use as a mainnet relay node. We use docker volumes for our persistent data
storage and IPC (interprocess communication) so they live beyond the lifetime
of the container.

Node logs can be followed:

```bash
docker logs -f cardano-node
```

#### Configuration using environment variables

The power in using `run` is being able to configure the node's behavior to
provide the correct type of service.

This behavior can be changes via the following environment variables:

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
    `${CARDANO_CONFIG_BASE}/mainnet-config.json`)
  - Use your own configuration file to modify the node behavior fully
- `CARDANO_DATABASE_PATH`
  - A directory which contains the ledger database files (default:
    `/opt/cardano/data`)
  - This is the location for persistent data storage for the ledger
- `CARDANO_PORT`
  - TCP port to bind for listening (default: `3001`)
- `CARDANO_RTS_OPTS`
  - Controls the Cardano node's Haskell runtime (default:
    `-N2 -A64m -I0 -qg -qb --disable-delayed-os-memory-return`)
  - This allows tuning the node for specific use cases or resource contraints
- `CARDANO_SOCKET_PATH`
  - UNIX socket path for listening (default: `/opt/cardano/ipc/socket`)
  - This socket speaks Ouroboros NtC and is used by client software
- `CARDANO_TOPOLOGY`
  - Full path to the Cardano node topology (default:
    `${CARDANO_CONFIG_BASE}/mainnet-topology.json`)

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
    `${CARDANO_CONFIG_BASE}/keys/node.cert`

### Using NETWORK (standalone)

Using the `NETWORK` environment variable causes the entrypoint script to use
the simplified path. The only configurable option in this path is the
`NETWORK` environment variable itself.

**NOTE** The container paths for persist disks is different in this mode

This is in keeping with the IOHK image behavior.

To run a Cardano full node on preview:

```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/data/db \
  -v node-ipc:/ipc \
  -e NETWORK=preview \
  -p 3001:3001 \
  ghcr.io/blinklabs-io/cardano-node
```

## Running the CLI

To run a Cardano CLI command, we use the `node-ipc` volume from our node.

```bash
docker run --rm -ti \
  -v node-ipc:/opt/cardano/ipc \
  ghcr.io/blinklabs-io/cardano-node cli <command>
```

This can be added to a shell alias:

```bash
alias cardano-cli="docker run --rm -ti \
  -v node-ipc:/opt/cardano/ipc \
  ghcr.io/blinklabs-io/cardano-node cli"
```

Now, you can use cardano-cli commands as you would, normally.

```bash
cardano-cli query tip --mainnet
```

Or, for preview:

```bash
cardano-cli query tip --network-magic 2
```
