# Self-contained zsh launcher. `nix run .#shell` from any nix-enabled
# machine drops you into the same oh-my-zsh setup with nvim on PATH —
# without writing to $HOME.
#
# We build a private ZDOTDIR containing a .zshrc that:
#   - points oh-my-zsh at $ZSH and loads the same plugins/theme,
#   - sources zsh-autosuggestions and zsh-syntax-highlighting,
#   - installs the same aliases and history settings,
#   - puts nvim, eza, fzf, and friends on PATH,
#   - sets EDITOR=nvim.
{
  pkgs,
  nvim,                              # the .#nvim package, threaded in by flake.nix
  zshConfig ? import ../../config/zsh.nix { lite = false; },
}:

let
  inherit (pkgs) lib;

  # PATH additions the launcher should always provide. fzf/eza are needed
  # by the corresponding oh-my-zsh plugins; the rest are quality of life.
  runtimePath = lib.makeBinPath [
    nvim
    pkgs.zsh
    pkgs.git
    pkgs.fzf
    pkgs.eza
    pkgs.ripgrep
    pkgs.bat
    pkgs.fd
    pkgs.coreutils
  ];

  aliasLines = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (k: v: "alias ${k}=${lib.escapeShellArg v}") zshConfig.shellAliases);

  pluginsList = lib.concatStringsSep " " zshConfig.ohMyZsh.plugins;

  zshrc = pkgs.writeText "zshrc" ''
    # --- shell-from-flake zshrc (generated; do not edit) ---

    export PATH=${runtimePath}:$PATH
    export EDITOR=nvim

    # History (matches home-manager settings)
    HISTFILE=${zshConfig.history.path}
    HISTSIZE=${toString zshConfig.history.size}
    SAVEHIST=${toString zshConfig.history.save}
    setopt EXTENDED_HISTORY
    setopt HIST_IGNORE_SPACE
    setopt SHARE_HISTORY
    setopt INC_APPEND_HISTORY

    ${lib.optionalString zshConfig.autocd "setopt AUTO_CD"}

    # Completion
    ${lib.optionalString zshConfig.enableCompletion ''
      autoload -U compinit
      compinit -d "$ZDOTDIR/.zcompdump"
    ''}

    # oh-my-zsh
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    ZSH_THEME="${zshConfig.ohMyZsh.theme}"
    plugins=(${pluginsList})
    source "$ZSH/oh-my-zsh.sh"

    # Interactive niceties
    ${lib.optionalString zshConfig.autosuggestion
      ''source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh''}
    ${lib.optionalString zshConfig.syntaxHighlighting
      ''source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh''}

    # Aliases
    ${aliasLines}
  '';

  zdotdir = pkgs.runCommand "shell-zdotdir" { } ''
    mkdir -p $out
    ln -s ${zshrc} $out/.zshrc
  '';
in
pkgs.writeShellApplication {
  name = "shell";
  runtimeInputs = [ pkgs.zsh ];
  text = ''
    export ZDOTDIR=${zdotdir}
    exec ${pkgs.zsh}/bin/zsh -i "$@"
  '';
}
