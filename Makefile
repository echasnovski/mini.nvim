NVIM_EXEC ?= nvim

all: test documentation

# Use `make test` to run tests for all modules
test:
	for nvim_exec in $(NVIM_EXEC); do \
		printf "\n======\n\n" ; \
		$$nvim_exec --version | head -n 1 && echo '' ; \
		$$nvim_exec --headless --noplugin -u ./scripts/minimal_init.lua \
			-c "lua require('mini.test').setup()" \
			-c "lua MiniTest.run()" ; \
	done

# Use `make test_xxx` to run tests for module 'mini.xxx'
TEST_MODULES = $(basename $(notdir $(wildcard tests/test_*.lua)))

$(TEST_MODULES):
	for nvim_exec in $(NVIM_EXEC); do \
		printf "\n======\n\n" ; \
		$$nvim_exec --version | head -n 1 && echo '' ; \
		$$nvim_exec --headless --noplugin -u ./scripts/minimal_init.lua \
			-c "lua require('mini.test').setup()" \
			-c "lua MiniTest.run_file('tests/$@.lua')" ; \
	done

documentation:
	$(NVIM_EXEC) --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

lintcommit-ci:
	export LINTCOMMIT_STRICT=true && chmod u+x scripts/lintcommit-ci.sh && scripts/lintcommit-ci.sh

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
