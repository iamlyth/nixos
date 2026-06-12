# Pure zsh configuration. Two consumers:
#   1. home-manager/repo/zsh.nix wraps this into `programs.zsh` (+ direnv).
#   2. pkgs/shell/default.nix uses this to generate a self-contained
#      ZDOTDIR/.zshrc for `nix run .#shell`.
#
# Keep this attrset framework-agnostic (no `pkgs`, `lib`, `config` refs).
# The optional `lite` arg trims oh-my-zsh plugins and disables aliases —
# server-home enables it; everything else leaves it false.
{ lite ? false }:

{
  ohMyZsh = {
    theme = "robbyrussell";
    plugins =
      if lite then [
        "git"
        "history"
        "colored-man-pages"
      ]
      else [
        "git"
        "history"
        "colored-man-pages"
        "history-substring-search"
        "zsh-interactive-cd"
        "direnv"
        "emoji"
        "eza"
        "fzf"
      ];
  };

  history = {
    path = "$HOME/.hf";
    save = 10000;
    size = 10000;
    share = true;
    extended = true;
    ignoreSpace = true;
  };

  shellAliases =
    if lite then { }
    else {
      ll = "eza --long --git -h";
      pingt = "ping -c 5 google.com";
      gitlog = "git log --graph --abbrev-commit --decorate --date=format:'(%m_%d)' --format=format:'%C(bold blue)%h%C(reset) %C(bold green)%ad%C(reset) %C(white)- %an%C(reset)%C(auto)%d%C(reset)'";
    };

  autocd = true;
  enableCompletion = true;
  autosuggestion = true;
  syntaxHighlighting = true;
}
