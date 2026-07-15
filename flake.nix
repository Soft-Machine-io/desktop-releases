{
  description = "Soft-Machine desktop app — install the released build with Nix.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # Bump `version` and the three `hash` values together on each release.
      # `./update.sh <version>` re-prefetches all three for you.
      version = "0.1.3";
      base = "https://github.com/Soft-Machine-io/desktop-releases/releases/download/v${version}";

      # Per-system release artifact and its sha256. The desktop CI ships no
      # aarch64-linux bundle, and nixpkgs upstream has dropped x86_64-darwin
      # (Intel Mac) as of 26.11 — Intel Mac users install the .dmg from
      # https://soft-machine.io/download instead. So the flake covers the two
      # systems Nix users actually run today.
      artifacts = {
        "x86_64-linux" = {
          name = "Soft-Machine-linux-x86_64.AppImage";
          hash = "sha256-iiGElUeX129P8O8orFCOjcv7gk/S5D4iHUSl9tMSVEM=";
        };
        "aarch64-darwin" = {
          name = "Soft-Machine-macos-arm64.dmg";
          hash = "sha256-eT+o7lk2u9HmA/ZV1KCPIhEMF7divq2bJE9Ig3FlviI=";
        };
      };

      systems = builtins.attrNames artifacts;
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      # The bundle is "Soft-Machine.app"; its executable is soft-machine-desktop.
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
                "$out/Applications/${appName}.app/Contents/MacOS/${pname}" \
                "$out/bin/${pname}"
              runHook postInstall
            '';
          }
        else
          # Linux: wrap the AppImage in an FHS env carrying the GTK/WebKit
          # libraries Tauri (wry) dlopen's at runtime. These mirror the desktop
          # repo's dev shell so a Nix-installed build matches a from-source one.
          pkgs.appimageTools.wrapType2 {
            inherit
              pname
              version
              src
              meta
              ;
            extraPkgs =
              p: with p; [
                webkitgtk_4_1
                gtk3
                libsoup_3
                librsvg
                libayatana-appindicator
                openssl
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
