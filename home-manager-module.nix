{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.gaomontablet;
  package = cfg.package;
in {
  options.programs.gaomontablet = {
    enable = lib.mkEnableOption "the GAOMON tablet driver user service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.gaomon;
      description = "GAOMON driver package.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.gaomontablet = {
      Unit = {
        Description = "GAOMON tablet driver";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${package}/bin/gaomontablet";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = [ "QT_QPA_PLATFORM=xcb" ];
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
