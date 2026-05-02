# Rootfs Plugin Layout

The `rootfs` plugin is packaged as a CLI plugin directory:

```text
container-plugins/rootfs/
├── bin/
│   └── rootfs
└── config.toml
```

Install it under the host plugin root so `container` can discover it as a CLI plugin.

## Install

Build the binary first:

```bash
xcrun swift build
```

Install into the default host plugin root:

```bash
./scripts/install-rootfs-plugin.sh
```

The installer re-signs the installed plugin binary with the local virtualization entitlement so the host can launch VMs through the plugin.

When no install root is provided, the script tries these locations in order:

1. `container system status` -> `installRoot`
2. The real path of the installed `container` binary
3. `brew --prefix container`
4. `/usr/local`

Or install into a custom root:

```bash
./scripts/install-rootfs-plugin.sh "$HOME/.local" ".build/arm64-apple-macosx/debug"
```
