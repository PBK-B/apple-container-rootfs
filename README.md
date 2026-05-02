# container-rootfs

`container-rootfs` is a CLI for building and running Linux containers from OCI images with host-backed storage.

It supports two workspace modes:
- `rw`: the unpacked root filesystem lives directly on the host
- `ro-layer`: a read-only base plus a host-backed writable `ext4` layer

## Build

```bash
swift build
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
- `run`: launch the container from the workspace
- `remove`: delete the workspace

## Workspace layout

Each container is stored under `containers/<id>/` with:
- `lower/`
- `writable.ext4` for `ro-layer`
- `rootfs-manifest.json`

## Example

```bash
swift build
swift run container-rootfs bootstrap --image docker.io/library/alpine:latest --container-id demo
swift run container-rootfs run --container-id demo -- /bin/sh
```

## Thank

inspired by [lazycat lightos](https://developer.lazycat.cloud/en/advanced-lightos.html), using apple container to make it available on macOS 26 platform
