{pkgs, lib, inputs, config, ... }:
with lib; let
  cfg = config.vimmodule;
in{
  options.vimmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable vim
      '';
    };
  };
  config = mkIf cfg.enable {
    home.packages  = [
      pkgs.nodejs
      pkgs.yarn
      pkgs.coc-clangd
      pkgs.coc-pyright
    ];

    programs.vim = {
      enable = true;
      packageConfigurable = pkgs.vim;
      plugins = with pkgs.vimPlugins; [
        vim-airline
        indentLine
        sensible  #sensible vimrc settings
        vim-surround
      ];
      settings = { ignorecase = true; };
      defaultEditor = true;
      extraConfig = ''
        " set encoding
        set encoding=utf-8
        "show x,y position at all times and show line numbers with width
        set ruler
        set number
        set numberwidth=5

        set autowrite
        set tabstop=2
        set shiftwidth=2

        if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
          syntax on
        endif

        "make it obvious where 80 characters is
        set textwidth=80
        set colorcolumn=+1
        hi ColorColumn ctermbg=220 guibg=#262626

        "for vimwiki
        set nocompatible
        filetype plugin on
        let g:vimwiki_list = [{ 'syntax': 'markdown',
                        \ 'ext': 'md'}]

        "Quicker window movement
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-h> <C-w>h
        nnoremap <C-l> <C-w>l
      '';
    };
  };
}
