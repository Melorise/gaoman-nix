{
  description = "GAOMON tablet driver package for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          f (import nixpkgs { inherit system; }));
    in {
      packages = forAllSystems (pkgs:
        let
          pname = "gaomontablet";
          version = "16.0.0.49";

          source = pkgs.fetchurl {
            url = "https://driver.gaomon.cn/download/Driver/Linux/GaomonTablet_LinuxDriver_v16.0.0.49.x86_64.tar.xz";
            hash = "sha256-37FX3mZYGO7LeGtFusyL9rc3SE7yQFZ8kqd6mTv+NYs=";
            curlOptsList = [ "-e" "https://driver.gaomon.cn/" ];
          };

          raw = pkgs.stdenvNoCC.mkDerivation {
            pname = "${pname}-raw";
            inherit version;
            src = source;
            dontFixup = true;
            dontStrip = true;

            sourceRoot = ".";

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/libexec"
              cp -a gaomon/gaomontablet "$out/libexec/gaomontablet"
              mkdir -p "$out/share/icons" "$out/share/applications"
              cp -a gaomon/icon/gaomontablet.png "$out/share/icons/gaomontablet.png"
              cp -a gaomon/share/applications/gaomontablet.desktop \
                "$out/share/applications/gaomontablet.desktop"
              runHook postInstall
            '';
          };

          fhs = pkgs.buildFHSEnv {
            name = "${pname}-fhs";
            inherit version;

            targetPkgs = p: with p; [
              bash
              coreutils
              dbus
              python3
              glib
              fontconfig
              freetype
              libusb1
              krb5
              systemd
              bluez
              xdotool
              libglvnd
              zlib
              libxkbcommon
              libx11
              libxext
              libxi
              libxinerama
              libxrandr
              libxtst
              libxcb
            ];

            runScript = pkgs.writeShellScript "${pname}-fhs-run" ''
              set -euo pipefail

              state="''${XDG_STATE_HOME:-$HOME/.local/state}/${pname}"
              mkdir -p "$state"
              cp -a -u ${raw}/libexec/gaomontablet/. "$state/"
              chmod -R u+rwX "$state"
              rm -f "$state/.DriverUI.pid" "$state/.HuionCore.pid"

              if [ ! -e "$state/.paths-patched" ]; then
                python3 - "$state" <<'PY'
              from pathlib import Path
              import os
              import sys

              root = Path(sys.argv[1])
              compat = f"/tmp/g{os.getuid()}".encode()
              replacements = (
                  (b"/usr/lib/gaomontablet/detectSessionProtocol", compat + b"/detectSessionProtocol"),
                  (b"/usr/lib/huiontablet/res", compat + b"/res"),
                  (b"/usr/lib/gaomontablet/gaomontablet.sh", compat + b"/gaomontablet.sh"),
                  (b"/usr/lib/gaomontablet", compat),
                  (b"/usr/lib/huiontablet", compat),
              )

              for path in root.rglob("*"):
                  if not path.is_file():
                      continue
                  data = path.read_bytes()
                  updated = data
                  for old, new in replacements:
                      if len(new) > len(old):
                          raise SystemExit("replacement path is longer than the source path")
                      padded = new + (b"\0" * (len(old) - len(new)))
                      updated = updated.replace(old, padded)
                  if updated != data:
                      path.write_bytes(updated)
              PY
                touch "$state/.paths-patched"
              fi

              compat="/tmp/g$(id -u)"
              ln -sfn "$state" "$compat"
              export LD_LIBRARY_PATH="$state/libs''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export QT_QPA_PLATFORM_PLUGIN_PATH="$state/platforms"
              export QML2_IMPORT_PATH="$state/qml"
              export PATH="$state/xdotool:$PATH"
              cd "$state"

              case "''${1:-supervisor}" in
                --core)
                  shift
                  exec "$state/huionCore" -d "$@"
                  ;;
                --ui)
                  shift
                  exec "$state/gaomontablet" "$@" -d
                  ;;
                --supervisor)
                  shift
                  "$state/huionCore" -d &
                  corePid=$!
                  cleanup() {
                    kill "$corePid" 2>/dev/null || true
                  }
                  trap cleanup EXIT INT TERM
                  exec "$state/gaomontablet" "$@" -d
                  ;;
                *)
                  exec "$state/gaomontablet.sh" "$@"
                  ;;
              esac
            '';
          };

          package = pkgs.runCommand "${pname}-${version}" {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          } ''
            mkdir -p "$out/bin" "$out/share/icons" "$out/share/applications"
            mkdir -p "$out/lib/udev/rules.d"
            makeWrapper ${fhs}/bin/${pname}-fhs "$out/bin/${pname}" \
              --add-flags --supervisor
            makeWrapper ${fhs}/bin/${pname}-fhs "$out/bin/${pname}-core" \
              --add-flags --core
            makeWrapper ${fhs}/bin/${pname}-fhs "$out/bin/${pname}-ui" \
              --add-flags --ui
            ln -s ${raw}/share/icons/gaomontablet.png "$out/share/icons/gaomontablet.png"
            cat > "$out/lib/udev/rules.d/60-gaomontablet.rules" <<'EOF'
            KERNEL=="uinput", GROUP="input", MODE="0660"
            KERNEL=="uhid", GROUP="input", MODE="0660"
            SUBSYSTEM=="usb", ATTR{idVendor}=="256c", GROUP="input", MODE="0660", TAG+="uaccess"
            KERNEL=="hidraw*", ATTRS{idVendor}=="256c", GROUP="input", MODE="0660", TAG+="uaccess"
            SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="HUION 256C PEN STYLUS", GROUP="input", MODE="0660", TAG+="uaccess"
            EOF
            cat > "$out/share/applications/gaomontablet.desktop" <<EOF
            [Desktop Entry]
            Type=Application
            Name=GAOMON Tablet
            Comment=GAOMON tablet driver
            Exec=$out/bin/gaomontablet
            Icon=$out/share/icons/gaomontablet.png
            Terminal=false
            Categories=Utility;
            StartupNotify=true
            EOF
          '';
        in {
          gaomon = package;
          gaomon-raw = raw;
          default = package;
        });

      nixosModules.default = import ./nixos-module.nix { inherit self; };
      homeManagerModules.default = import ./home-manager-module.nix { inherit self; };
    };
}
