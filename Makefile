all: test documentation

# Use sequential tests to save execution resources due to presence of timing tests
test: deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.vim \
		-c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'scripts/minimal_init.vim', sequential = true, timeout = 120000 })"

test_file: deps/plenary.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "PlenaryBustedFile $(FILE)"

documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.vim -c "lua require('mini.doc').generate()" -c "qa!"

deps/plenary.nvim:
	@mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@
