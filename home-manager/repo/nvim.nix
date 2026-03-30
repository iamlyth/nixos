{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.nvimmodule;
in{
	options.nvimmodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable nvim.
			'';
		};
	};
	config = mkIf cfg.enable {
		programs.nixvim = {
			enable = true;
			colorschemes.gruvbox.enable = true;
			viAlias = true;
			vimAlias = true;
			globals.mapleader = ",";
			plugins = {
				lualine.enable = true;
				nvim-tree.enable = true;
				web-devicons.enable = true; #explict for nvim-tree
				telescope.enable = true;
				mini-map = {
					enable = true;
					settings = {
						#integrations = lib.nixvim.mkRaw "nil";

						symbols = {
							#encode = lib.nixvim.mkRaw "nil";
							scroll_line = "█";
							scroll_view = "┃";
						};

						window = {
							focusable = true;
							side = "right";
							show_integration_count = true;
							width = 10;
							winblend = 25;
							zindex = 15;
						};
					};
				};
				lsp = {
					enable = true;
					servers = {
						pyright.enable = true;
						nixd.enable = true;
						clangd.enable = true;
					};
					keymaps.lspBuf = {
						"gd" = "definition";
        		"K" = "hover";
        		"gr" = "references";
        		"<leader>rn" = "rename";
					};
				};
			};
			extraConfigLua = ''
				vim.api.nvim_create_autocmd("UiEnter", {
					once = true,
					callback = function()
						MiniMap.open()
					end,
				})
			'';
			opts = {
				number = true;
				numberwidth = 5;
				ruler = true;
				autowrite = true;
				shiftwidth = 2;
				tabstop = 2;
			};
			keymaps = [
				#Nvim Tree
				{
					mode = "n";
        	key = "<C-f>";
        	action = "<cmd>NvimTreeToggle<CR>";
        	options = {
          	silent = true;
          	desc = "Toggle NvimTree";
        	};
				}

				#Window management
				{
					mode = "n";
					key = "<C-j>";
					action = "<C-w>j";
					options.desc = "Move to window below";
				}
				{
					mode = "n";
					key = "<C-k>";
					action = "<C-w>k";
					options.desc = "Move to window above";
				}
				{
					mode = "n";
					key = "<C-h>";
					action = "<C-w>h";
					options.desc = "Move to window left";
				}
				{
					mode = "n";
					key = "<C-l>";
					action = "<C-w>l";
					options.desc = "Move to window right";
			 	}

				#telescope
				{
					mode = "n";
					key = "<leader>ff";
					action = "<cmd>lua require('telescope.builtin').find_files()<CR>";
					options = {
							desc = "Find files";
							silent = true;
					};
				}
				{
					mode = "n";
					key = "<leader>fg";
					action = "<cmd>lua require('telescope.builtin').live_grep()<CR>";
					options = {
							desc = "Find grep";
							silent = true;
					};
				}
				#minimap
				{
					mode = "n";
					key = "<leader>mo";
					action = "<cmd>lua MiniMap.open()<CR>";
					options = {
							desc = "Open minimap";
							silent = true;
					};
				}
				{
					mode = "n";
					key = "<leader>mc";
					action = "<cmd>lua MiniMap.close()<CR>";
					options = {
							desc = "Close minimap";
							silent = true;
					};
				}
				{
					mode = "n";
        	key = "<C-m>";
        	action = "<cmd>lua MiniMap.toggle_focus()<CR>";
        	options = {
          	silent = true;
          	desc = "Toggle minimap focus";
        	};
				}
			];
		};
	};
}
