# container-rootfs

`container-rootfs` is a project for preparing and building Linux root filesystems (rootfs) tailored for Apple’s container tool. It provides minimal, customizable system environments required to boot and run containers inside lightweight virtual machines on macOS.

The project focuses on creating efficient and portable rootfs images, enabling fast startup times and reduced resource usage. It supports flexible customization, allowing developers to tailor the filesystem for specific workloads or experiments.

By complementing Apple’s container ecosystem, container-rootfs helps bridge gaps in root filesystem provisioning and simplifies low-level container setup. It is particularly useful for developers exploring Apple’s VM-based container architecture, building custom environments, or optimizing container performance.

> **WARN: This is a failed experiment. In the `rw` mode (the rootfs directory mounted through VirtioFS will have some strange permission problems, which may only apply to those that cannot be mirrored), I don't have a better solution or idea for the time being (maybe I will find it later)**

## Build

```bash
swift build
```

To install as a host-loadable CLI plugin, copy the built `rootfs` binary and `Sources/Plugins/Rootfs/config.toml` into a plugin directory shaped like `libexec/container-plugins/rootfs/`. See [docs/rootfs-plugin.md](docs/rootfs-plugin.md) for the full plugin installation flow.

One-step install after a local build:

```bash
swift build
./scripts/install-rootfs-plugin.sh
```

To run virtual machines on macOS, the executable must be signed with the virtualization entitlement. For local development, sign the built binary after `swift build`:

```bash
codesign --force --sign - --entitlements entitlements.plist .build/arm64-apple-macosx/debug/container-rootfs
```

## Usage

### Prepare a workspace

```bash
swift run container-rootfs bootstrap \
  --image docker.io/library/alpine:latest \
  --container-id demo
```

### Inspect the workspace

```bash
swift run container-rootfs inspect --container-id demo
```

### Run the container

```bash
swift run container-rootfs run \
  --container-id demo \
  -- /bin/sh
```

### Run with a named network

```bash
swift run container-rootfs network create devnet
swift run container-rootfs run \
  --container-id demo \
  --network devnet \
  -- /bin/sh
```

Disable networking entirely:

```bash
swift run container-rootfs run \
  --container-id demo \
  --network none \
  -- /bin/sh
```

Configure DNS and hosts:

```bash
swift run container-rootfs run \
  --container-id demo \
  --network devnet \
  --dns 1.1.1.1 \
  --dns 8.8.8.8 \
  --dns-search example.internal \
  --dns-option ndots:1 \
  --add-host api.local:10.0.0.10 \
  -- /bin/sh
```

Configure environment, working directory, CPUs, and memory:

```bash
swift run container-rootfs run \
  --container-id demo \
  --env APP_ENV=dev \
  --env LOG_LEVEL=debug \
  --workdir /workspace \
  --cpus 2 \
  --memory 1g \
  -- /bin/sh
```

### Run with host mounts

Bind a host directory:

```bash
swift run container-rootfs run \
  --container-id demo \
  --bind /tmp:/data \
  -- /bin/sh
```

Bind a single host file read-only:

```bash
swift run container-rootfs run \
  --container-id demo \
  --bind /etc/hosts:/tmp/hosts:ro \
  -- /bin/sh
```

Use `--mount` syntax:

```bash
swift run container-rootfs run \
  --container-id demo \
  --mount type=bind,source=/tmp,target=/data,readonly \
  -- /bin/sh
```

Defaults:
- `--kernel` is optional. The CLI will try `CONTAINER_ROOTFS_KERNEL`, `./vmlinux`, `./bin/vmlinux`, and common Kata kernel paths.
- `--initfs-reference` is optional. The default is `ghcr.io/apple/containerization/vminit:0.31.0`.
- If no command is provided, the default command is `/bin/sh`.

### Remove a workspace

```bash
swift run container-rootfs remove --container-id demo
```

## Commands

- `plan`: show the workspace layout
- `bootstrap`: pull an OCI image and create the workspace on disk
- `inspect`: print workspace metadata
- `network`: create, list, inspect, and remove named networks
- `run`: launch the container from the workspace
- `remove`: delete the workspace

## Workspace layout

Each container is stored under `containers/<id>/` with:
- `lower/`
- `writable.ext4` for `ro-layer`
- `rootfs-manifest.json`

Internal runtime data is stored separately under `containers/.runtime/`:
- `images/` for pulled OCI image content
- `networks/` for named network manifests
- `containers/` for runtime manager state

The container identifier `.runtime` is reserved for internal runtime data and cannot be used with `--container-id`.

## Example

```bash
swift build
swift run container-rootfs bootstrap --image docker.io/library/alpine:latest --container-id demo
swift run container-rootfs run --container-id demo -- /bin/sh
```

## Thank

inspired by [lazycat lightos](https://developer.lazycat.cloud/en/advanced-lightos.html), using apple container to make it available on macOS 26 platform
