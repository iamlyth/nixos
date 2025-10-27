{ pkgs, inputs, config, ... }:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;
    history.path = "$HOME/.hf";
    history.save = 10000;
    history.size = 10000;
    history.share = true;
    history.extended = true;
    history.ignoreSpace = true;
    oh-my-zsh.enable = true;
    oh-my-zsh.theme = "robbyrussell";
    oh-my-zsh.plugins = [
      "git"
      "history"
    ];

    shellAliases = {
      ls = "ls -h --color=auto --group-directories-first";
      ll = "ls -alF";
      pingt = "ping -c 5 google.com";
      gitlog = "git log --graph --abbrev-commit --decorate
      --date=format:'(%m_%d)' --format=format:'%C(bold blue)%h%C(reset) %C(bold
      green)%ad%C(reset) %C(white)- %an%C(reset)%C(auto)%d%C(reset)'";
    };
  };
}
