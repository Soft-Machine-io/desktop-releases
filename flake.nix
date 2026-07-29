{
  description = "Soft-Machine desktop app — install the released build with Nix.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # Bump `version` and the per-system `hash` values together on each
      # release. `./update.sh <version>` re-prefetches them for you.
      #
      # Since 0.2.x the app is the Electron build shipped from the main
      # soft-machine repo (the Tauri app ended at 0.1.3), and releases are
      # cut automatically per main-branch commit — this pin tracks the
      # latest version update.sh was run against, not necessarily the
      # newest release.
      version = "0.2.1";
      base = "https://github.com/Soft-Machine-io/desktop-releases/releases/download/v${version}";

      # Per-system release artifact and its sha256. The desktop CI ships no
      # aarch64-linux bundle, and nixpkgs upstream has dropped x86_64-darwin
      # (Intel Mac) as of 26.11 — Intel Mac users install the .dmg from
      # https://soft-machine.io/download instead. So the flake covers the two
      # systems Nix users actually run today.
      artifacts = {
        "x86_64-linux" = {
          name = "Soft-Machine-linux-x86_64.AppImage";
          hash = "sha256-0YagW65887ycCQl13AVu9TQ6RrAAH7Aj2L/vBdJJkjY=";
        };
        "aarch64-darwin" = {
          name = "Soft-Machine-macos-arm64.dmg";
          hash = "sha256-e7AFif1bFh19ylqSvUiBv3GWZXInWBpGbheIZ1Gdky0=";
        };
      };

      systems = builtins.attrNames artifacts;
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      # The bundle is "Soft-Machine.app"; Electron names the executable after
      # the product, so it is Contents/MacOS/Soft-Machine.
      appName = "Soft-Machine";
      # The wrapped launcher name is uniform across platforms so `apps.default`
      # can point at it without a per-system branch (appimageTools names the
      # Linux launcher after `pname`).
      pname = "soft-machine-desktop";

      mkPackage =
        system: pkgs:
        let
          art = artifacts.${system};
          src = pkgs.fetchurl {
            url = "${base}/${art.name}";
            inherit (art) hash;
          };
          meta = {
            description = "Soft-Machine desktop app (VM-based agentic cloud development environment)";
            homepage = "https://soft-machine.io";
            downloadPage = "https://soft-machine.io/download";
            # Proprietary first-party distribution; use is governed by
            # https://soft-machine.io/terms. Not redistributable.
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
            platforms = [ system ];
            mainProgram = pname;
          };
        in
        if pkgs.stdenv.isDarwin then
          # macOS: unpack the signed .dmg, drop the .app under $out/Applications
          # (so home-manager / `nix profile` surface it), and add a $out/bin
          # launcher so `nix run` works headlessly too.
          pkgs.stdenvNoCC.mkDerivation {
            inherit
              pname
              version
              src
              meta
              ;
            nativeBuildInputs = [
              pkgs.undmg
              pkgs.makeWrapper
            ];
            sourceRoot = ".";
            unpackPhase = "undmg $src";
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/Applications"
              cp -R "${appName}.app" "$out/Applications/${appName}.app"
              makeWrapper \
                "$out/Applications/${appName}.app/Contents/MacOS/${appName}" \
                "$out/bin/${pname}"
              runHook postInstall
            '';
          }
        else
          # Linux: wrap the AppImage in an FHS env carrying the libraries
          # Electron dlopen's at runtime beyond appimageTools' defaults
          # (Chromium's sandbox/NSS/audio stack).
          pkgs.appimageTools.wrapType2 {
            inherit
              pname
              version
              src
              meta
              ;
            # NB: no mesa/libGL here — the FHS env must not shadow the
            # host's /run/opengl-driver stack (NixOS matches it to the
            # kernel/GPU; a mismatched mesa renders a black window).
            extraPkgs =
              p: with p; [
                nss
                nspr
                alsa-lib
                libdrm
                libxkbcommon
              ];
          };
    in
    {
      packages = forAllSystems (
        system: pkgs:
        let
          pkg = mkPackage system pkgs;
        in
        {
          default = pkg;
          soft-machine-desktop = pkg;
        }
      );

      apps = forAllSystems (
        system: _pkgs: {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/${pname}";
          };
        }
      );

      formatter = forAllSystems (_system: pkgs: pkgs.nixfmt-rfc-style);
    };
}
