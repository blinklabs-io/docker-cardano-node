# docker-cardano-node
Builds a Cardano full node from source on Debian. This image attempts to keep
interface compatibility with `inputoutput/cardano-node`, but may diverge
slightly, particularly with any Nix-specific paths.

## Running a node
To run a Cardano full node on mainnet:
```bash
docker run --detach \
  --name cardano-node \
  -v node-data:/opt/cardano/data \
  -v node-ipc:/opt/cardano/ipc \
  -p 3001:3001 \
  ghcr.io/cloudstruct/cardano-node run
```
The above maps port 3001 on the host to 3001 on the container, suitable
for use as a mainnet relay node.

Node logs can be followed:
```bash
docker logs -f cardano-node
```
## Running the CLI
To run a Cardano CLI command, we use the `node-ipc` volume from our node.
```bash
docker run --rm -ti \
  -v node-ipc:/opt/cardano/ipc \
  ghcr.io/cloudstruct/cardano-node cli <command>
```
This can be added to a shell alias:
```bash
alias cardano-cli="docker run --rm -ti \
  -v node-ipc:/opt/cardano/ipc \
  ghcr.io/cloudstruct/cardano-node cli"
```
Now, you can use cardano-cli commands as you would, normally.
```bash
cardano-cli query tip --mainnet
```
