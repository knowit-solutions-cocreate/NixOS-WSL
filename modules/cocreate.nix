{ config
, lib
, pkgs
, ...
}:
with builtins;
with lib; {
  options.wsl.cocreate = with types; {
    enable = mkEnableOption "Cocreate development environment";
  };

  config =
    let
      cfg = config.wsl.cocreate;
    in
    mkIf (config.wsl.enable && cfg.enable) {
      # Enable flakes and new nix command
      nix.settings.experimental-features = [ "nix-command" "flakes" ];

      # Install development packages
      environment.systemPackages = with pkgs; [
        sops
        lazygit
        gh
        devenv
        direnv
      ];

      # Enable direnv integration
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # Configure git (commonly needed for development)
      programs.git.enable = true;

      # Enable bash completion for better CLI experience
      programs.bash.completion.enable = true;
      programs.starship.enable = true;
    };
}
