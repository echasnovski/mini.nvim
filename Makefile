all: test documentation

test: deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'scripts/minimal_init.vim'}"

test_file: deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "PlenaryBustedFile $(FILE)"

documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c "qa!"

deps/plenary.nvim:
	@mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@
