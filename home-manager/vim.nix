{pkgs, inputs, config, ... }:
{
  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ 
      vim-airline 
      indentLine
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
      set tabstop=4
      set shiftwidth=4

      if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
        syntax on
      endif

      "make it obvious where 80 characters is
      set textwidth=80
      set colorcolumn=+1
      hi ColorColumn ctermbg=220 guibg=#262626

      "Quicker window movement
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-h> <C-w>h
      nnoremap <C-l> <C-w>l
    '';
  };
}
