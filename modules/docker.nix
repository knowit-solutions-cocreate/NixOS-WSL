{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; {
  options.wsl.docker = with types; {
    enable = mkEnableOption "Docker container runtime";
    addUserToDockerGroup = mkOption {
      type = bool;
      default = true;
      description = "Adds user to docker group. Defaults to true";
    };
    extraPackages = mkOption {
      type = listOf package;
      default = with pkgs; [
        lazydocker
      ];
      description = "Additional packages to install with Docker";
    };
  };

  config = let
    cfg = config.wsl.docker;
  in
    mkIf (config.wsl.enable && cfg.enable) {
      # Enable container support and Docker
      virtualisation.containers.enable = true;
      virtualisation.docker = {
        enable = true;
      };

      # Install container management tools
      environment.systemPackages = cfg.extraPackages;
    };

    mkIf (config.wsl.enable && cfg.enable && cfg.addUserToDockerGroup) {
      # Add user to docker group. Enabled by default but less secure
      users.groups.docker.members = [
        config.wsl.defaultUser
      ];
    };
}
