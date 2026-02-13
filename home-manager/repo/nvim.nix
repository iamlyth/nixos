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
			colorschemes.tokyonight.enable = true;
			viAlias = true;
			vimAlias = true;
			globals.mapleader = ",";
			plugins = {
				lualine.enable = true;
				nvim-tree.enable = true;
				web-devicons.enable = true; #explict for nvim-tree
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
				telescope = {
					enable = true;
					defaults = {
							# Layout for better preview
							layout_strategy = "horizontal";
							layout_config = {
								horizontal = {
									preview_width = 0.6;
									prompt_position = "top";
								};
							};
							sorting_strategy = "ascending";

							# Enhanced ripgrep arguments for live_grep
							vimgrep_arguments = [
								"rg"
								"--color=never"
								"--no-heading"
								"--with-filename"
								"--line-number"
								"--column"
								"--smart-case"
								"--trim" # Strip leading whitespace
							];

							initial_mode = "normal";

							# Keymaps inside telescope picker
							mappings = {
								# Insert mode (typing search query)
								i = {
									"<Esc>".__raw = "function() vim.cmd('stopinsert') end";
									"<C-j>".__raw = "require('telescope.actions').move_selection_next";
									"<C-k>".__raw = "require('telescope.actions').move_selection_previous";
									"<C-u>".__raw = "require('telescope.actions').preview_scrolling_up";
									"<C-d>".__raw = "require('telescope.actions').preview_scrolling_down";
									"<C-q>".__raw =
										"require('telescope.actions').send_to_qflist + require('telescope.actions').open_qflist";
								};
								# Normal mode (vim-like navigation)
								n = {
									# Navigation
									j.__raw = "require('telescope.actions').move_selection_next";
									k.__raw = "require('telescope.actions').move_selection_previous";
									H.__raw = "require('telescope.actions').move_to_top";
									M.__raw = "require('telescope.actions').move_to_middle";
									L.__raw = "require('telescope.actions').move_to_bottom";
									gg.__raw = "require('telescope.actions').move_to_top";
									G.__raw = "require('telescope.actions').move_to_bottom";

									# Preview scrolling
									"<C-u>".__raw = "require('telescope.actions').preview_scrolling_up";
									"<C-d>".__raw = "require('telescope.actions').preview_scrolling_down";

									# Actions
									"<CR>".__raw = "require('telescope.actions').select_default";
									l.__raw = "require('telescope.actions').select_default";
									o.__raw = "require('telescope.actions').select_default";
									"<C-x>".__raw = "require('telescope.actions').select_horizontal";
									"<C-v>".__raw = "require('telescope.actions').select_vertical";
									"<C-t>".__raw = "require('telescope.actions').select_tab";

									# Quickfix
									"<C-q>".__raw =
										"require('telescope.actions').send_to_qflist + require('telescope.actions').open_qflist";

									# Close
									q.__raw = "require('telescope.actions').close";
									"<Esc>".__raw = "require('telescope.actions').close";

									# Back to insert mode to refine search
									i.__raw = "function() vim.cmd('startinsert') end";
									"/".__raw = "function() vim.cmd('startinsert') end";
								};
							};
						};

						pickers = {
							live_grep = {
								# Show hidden files but respect .gitignore
								additional_args = [
									"--hidden"
									"--glob"
									"!.git/"
								];
							};
							find_files = {
								hidden = true;
								follow = true;
							};
						};
					};
				};
			};
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
							desc = "Live grep";
							silent = true;
					};
				}
				{
					mode = "n";
					key = "<leader>fb";
					action = "<cmd>lua require('telescope.builtin').buffers()<CR>";
					options = {
							desc = "Buffers";
							silent = true;
					};
				}
				{
					mode = "n";
					key = "<leader>fh";
					action = "<cmd>lua require('telescope.builtin').help_tags()<CR>";
					options = {
							desc = "Help Tags";
							silent = true;
					};
				}
			];
		};
	};
}
