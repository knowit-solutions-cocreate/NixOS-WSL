{ config
, lib
, pkgs
, ...
}:
with builtins;
with lib; {
  options.wsl.podman = with types; {
    enable = mkEnableOption "Podman container runtime";

    dockerCompat = mkOption {
      type = bool;
      default = true;
      description = "Enable Docker compatibility layer for Podman";
    };

    extraPackages = mkOption {
      type = listOf package;
      default = with pkgs; [
        dive
        podman-tui
        podman-compose
      ];
      description = "Additional packages to install with Podman";
    };
  };

  config =
    let
      cfg = config.wsl.podman;
    in
    mkIf (config.wsl.enable && cfg.enable) {
      # Enable container support and Podman
      virtualisation.containers.enable = true;
      virtualisation.podman = {
        enable = true;
        dockerCompat = cfg.dockerCompat;
        defaultNetwork.settings.dns_enabled = true;
      };

      # Install container management tools
      environment.systemPackages = cfg.extraPackages;
    };
}

