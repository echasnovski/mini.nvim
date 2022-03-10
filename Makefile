documentation:
		nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c "qa!"
