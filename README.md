# Soft Machine Desktop — Releases

Installers and signed update manifests for the Soft Machine desktop app
(macOS, Windows, Linux). Source lives in a private repository; this repo
carries release artifacts only.

- Download: https://soft-machine.io/download
- Quick install: `curl -f https://soft-machine.io/install.sh | sh`

In-app updates are automatic and cryptographically signed.

## Install with Nix

A flake here packages the released build for **`x86_64-linux`** (the AppImage,
wrapped with the GTK/WebKit libraries it needs) and **`aarch64-darwin`** (the
signed `.dmg`, unpacked into `Applications/`).

Run it directly:

```sh
nix run github:Soft-Machine-io/desktop-releases
```

Install it into your profile:

```sh
nix profile install github:Soft-Machine-io/desktop-releases
```

Or add it to your own flake (NixOS / nix-darwin / home-manager):

```nix
{
  inputs.soft-machine.url = "github:Soft-Machine-io/desktop-releases";

  # then, in home.packages / environment.systemPackages:
  #   inputs.soft-machine.packages.${pkgs.system}.default
}
```

Intel Macs (`x86_64-darwin`) and other platforms: use the `.dmg` / installer
from the [download page](https://soft-machine.io/download) — nixpkgs upstream
dropped `x86_64-darwin` in 26.11, and the desktop CI ships no `aarch64-linux`
bundle.

### Updating the pin

The flake pins each release by content hash, so bumping it is one command after
a new version is mirrored here:

```sh
./update.sh 0.1.4   # re-prefetches every artifact hash and bumps the version
```
