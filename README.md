# 高漫数位板驱动/控制面板程序 For NixOS

This directory packages the x86_64 GAOMON Linux driver from the upstream
download URL. The local reference archive remains in the parent directory for
comparison while the flake fetches the upstream archive during evaluation.

The package keeps the vendor Qt and QML files inside a lightweight FHS
environment, supplies host libraries through Nixpkgs, and copies writable
runtime data into `$XDG_STATE_HOME/gaomontablet`.

The NixOS module installs Udev permissions and an XDG autostart entry. The
Home Manager module provides a user service that starts with the graphical
session.

## NixOS module

```nix
inputs.gaomon.url = "path:/data/Dev/gaoman/nix-flake";

imports = [ inputs.gaomon.nixosModules.default ];

programs.gaomontablet = {
  enable = true;
  user = "alice";
};
```

The NixOS module installs the Udev rules and the XDG autostart entry. When
Home Manager manages graphical-session services, import
`inputs.gaomon.homeManagerModules.default` and enable
`programs.gaomontablet.enable` there. Choose one session startup entry.

The archive is fetched from the upstream URL during the Nix build. The
`curlOptsList` Referer setting is required by the upstream download server.

## Build

```sh
nix flake check
nix build .#gaomon
```

The driver is an x86_64 binary distribution. Hardware validation requires a
graphical session and a connected GAOMON tablet.

## Device permissions

Running the package directly does not change system Udev rules. Enable the
NixOS module before starting the driver:

```nix
imports = [ inputs.gaomon.nixosModules.default ];

programs.gaomontablet = {
  enable = true;
  user = "alice";
};
```

Apply the system configuration, start a new login session, and reconnect the
tablet. The user account must show the `input` group. USB, hidraw, uinput, and
uhid nodes should then be accessible to that group.
