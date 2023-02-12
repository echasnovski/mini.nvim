GROUP_DEPTH ?= 1
NVIM_EXEC ?= nvim

all: test documentation

test:
	$(NVIM_EXEC) --version | head -n 1 && echo ''
	$(NVIM_EXEC) --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = $(GROUP_DEPTH) }) } })"

test_file:
	$(NVIM_EXEC) --version | head -n 1 && echo ''
	$(NVIM_EXEC) --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run_file('$(FILE)', { execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = $(GROUP_DEPTH) }) } })"

documentation:
	$(NVIM_EXEC) --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

basic_setup:
	$(NVIM_EXEC) --headless --noplugin -u ./scripts/basic-setup_init.lua

dual_sync:
	chmod u+x scripts/dual_sync.sh && scripts/dual_sync.sh

dual_log:
	chmod u+x scripts/dual_log.sh && scripts/dual_log.sh

dual_push:
	chmod u+x scripts/dual_push.sh && scripts/dual_push.sh
	git branch --force sync
	git push origin sync
	rm -r dual/patches

dual_release:
	chmod u+x scripts/dual_release.sh && scripts/dual_release.sh "$(TAG_NAME)" "$(TAG_MESSAGE)"
