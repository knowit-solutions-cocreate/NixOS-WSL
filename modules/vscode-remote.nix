{ config
, lib
, pkgs
, ...
}:
with builtins;
with lib; {
  options.wsl.vscode-remote = with types; {
    enable = mkEnableOption "VS Code Remote support";
  };

  config =
    let
      cfg = config.wsl.vscode-remote;
    in
    mkIf (config.wsl.enable && cfg.enable) {
      # Install wget required for VS Code Remote
      environment.systemPackages = with pkgs; [
        wget
      ];

      # Enable nix-ld for running
      # unpatched binaries like VS Code Remote server
      programs.nix-ld = {
        enable = true;
      };
    };
}
