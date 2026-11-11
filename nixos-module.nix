{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.gaomontablet;
in {
  options.programs.gaomontablet = {
    enable = lib.mkEnableOption "the GAOMON tablet driver";

    user = lib.mkOption {
      type = lib.types.str;
      description = "User account that receives access to tablet input devices.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.gaomon;
      defaultText = lib.literalExpression "inputs.gaomon.packages.${pkgs.system}.gaomon";
      description = "GAOMON driver package.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the driver with the graphical desktop session.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "";
        message = "programs.gaomontablet.user must name the desktop user.";
      }
    ];

    environment.systemPackages = [ cfg.package ];
    users.users.${cfg.user}.extraGroups = [ "input" ];
    services.udev.packages = [ cfg.package ];

    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
      KERNEL=="uhid", GROUP="input", MODE="0660"
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="256c", \
        GROUP="input", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="input", KERNEL=="event*", \
        ATTRS{name}=="HUION 256C PEN STYLUS", \
        GROUP="input", MODE="0660", TAG+="uaccess"
    '';

    environment.etc."xdg/autostart/gaomontablet.desktop" = lib.mkIf cfg.autoStart {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=GAOMON Tablet
        Comment=GAOMON tablet driver
        Exec=${cfg.package}/bin/gaomontablet
        Icon=${cfg.package}/share/icons/gaomontablet.png
        Terminal=false
        Categories=Utility;
        X-GNOME-Autostart-Notify=true
      '';
    };
  };
}
