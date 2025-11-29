# CI/CD Quickstart

## Overview

Two-workflow pipeline: `ci-docker.yml` validates builds, `publish.yml` creates multi-arch manifests and distributes to registries.

## Workflows

### ci-docker.yml
- **Runs on**: PRs, main pushes, version tags
- **Build**: Multi-platform (amd64, arm64) with GHA cache
- **PRs**: Validation only (no push)
- **Pushes**: Push by digest to GHCR, export artifacts

### publish.yml
- **Runs on**: After successful ci-docker.yml completion
- **Actions**: Download artifacts → create manifests → publish to GHCR + Docker Hub
- **Additional**: Update Docker Hub description, create GitHub releases

## Required Configuration

### Docker Hub Publishing

**Secret**: `DOCKER_PASSWORD` (required)
- Docker Hub Personal Access Token
- Create at: https://hub.docker.com/settings/security
- Permissions: Read & Write
- Location: Settings → Secrets and variables → Actions → Secrets

### Repository Permissions

**Setting**: Workflow permissions → "Read and write permissions"
- Location: Settings → Actions → General

## Optional Configuration

### Variables (Settings → Secrets and variables → Actions → Variables)

#### `DOCKER_USERNAME`
Docker Hub username. Default: `blinklabs`

#### `DOCKER_IMAGE_NAME`
Docker Hub image name. Default: `blinklabs/cardano-node`

#### `GHCR_IMAGE_NAME`
GHCR image name. Default: `ghcr.io/{owner}/cardano-node`

#### `ENABLE_UPSTREAM_MAIN_PUBLISH`
Control main branch publishing. Default: `true`
- Set to `false`: Skip main branch publishes (tags still published)
- **Use case**: Conserve resources in forks

## Image Tags

### Branch Pushes
`git push origin main` → `main` tag

### Release Tags
`git tag v1.2.3 && git push origin v1.2.3` → `1.2.3` + `latest` tags

### Prerelease Tags
`git tag v1.2.3-rc1 && git push origin v1.2.3-rc1` → `1.2.3-rc1` tag (no `:latest`)

**Prerelease patterns**: `-pre-`, `-rc`, `-alpha`, `-beta`, `-testci`

## Fork Configuration

### Minimal Setup (Tags Only)
```yaml
# Variables
ENABLE_UPSTREAM_MAIN_PUBLISH: false

# Secrets
DOCKER_PASSWORD: <your-token>
```

**Result**: Validates PRs/pushes, publishes tagged releases only

### Full Setup (Custom Registries)
```yaml
# Variables
DOCKER_IMAGE_NAME: myuser/cardano-node
GHCR_IMAGE_NAME: ghcr.io/myuser/cardano-node
ENABLE_UPSTREAM_MAIN_PUBLISH: false  # optional

# Secrets
DOCKER_PASSWORD: <your-token>
DOCKER_USERNAME: myuser
```

## Platform Support

All images are multi-platform manifests:
- `linux/amd64`
- `linux/arm64`

Docker automatically selects the correct architecture when pulling images.

## Troubleshooting

**Publish doesn't trigger**: Check ci-docker.yml logs for failures

**Docker Hub auth fails**: Verify `DOCKER_PASSWORD` token permissions (Read & Write)

**Wrong tags**: Use semver format: `vMAJOR.MINOR.PATCH` (e.g., `v1.2.3`)

**Fork publishes to upstream**: Set custom `DOCKER_IMAGE_NAME` and `GHCR_IMAGE_NAME`
