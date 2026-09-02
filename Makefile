SHELL := /usr/bin/env bash

BASE := work/images/armbian/Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal
PRELOADED := $(BASE)-preloaded.img
FINAL_WORK := $(BASE)-preloaded-firstboot.img
FINAL_POINTER := work/images/armbian/.last-final-image
VENDOR_OUTPUT := work/vendor-output
REBUILD ?= no
VPU_TESTDATA_TAG ?= vpu-testdata-v1
BOARD_LAYER ?=
BOARD_TEST_OUTPUT ?= /var/log/orangepi-zero3w-setup/postboot-acceleration.txt
BOARD_DIAGNOSTICS_OUTPUT ?= /var/log/orangepi-zero3w-setup/diagnostics.txt

.PHONY: help extract preset preloaded firstboot image newsd summary show-unredacted validate test tests clean \
	board-test board-tests board-diagnostics board-gpu-test board-gpu-runtime-test board-vpu-test \
	board-vpu-generate-videos \
	board-vpu-fetch-videos release-vpu-test-videos \
	board-gpu-precheck board-gpu-install board-gpu-verify \
	board-vpu-precheck board-vpu-install board-vpu-verify \
	board-vpu-decode-test \
	board-npu-precheck board-npu-install board-npu-verify board-npu-test npu-test-assets \
	board-core-install board-core-status board-a733-sources

BOARD_WORKFLOW := ./scripts/board-acceleration-workflow.sh
BOARD_LOG ?= /var/log/orangepi-zero3w-setup/acceleration-progress.log
BOARD_ARGS := --log $(BOARD_LOG)

help:
	@printf '%s\n' \
		'Orange Pi Zero 3W setup workflow:' \
		'  1. Put the exact source/base images under work/images/.' \
		'  2. Run: make newsd' \
		'     Cleans generated files, extracts userspace, prompts for first-boot' \
		'     settings, builds both images, and validates the final image.' \
		'  3. Write the reported timestamped *-preloaded-firstboot-...Z.img to the confirmed SD card.' \
		'  4. On the board: GPU precheck/install, reboot, then GPU verify.' \
		'  5. Run the equivalent VPU targets one at a time.' \
		'  6. Run NPU precheck/install/verify when the AI SDK test bundle is present.' \
		'  Board log: /var/log/orangepi-zero3w-setup/acceleration-progress.log' \
		'' \
		'make extract    Generate vendor archives, or reuse existing output' \
		'make preset     Interactively create local first-boot settings' \
		'make preloaded  Create the archive-preloaded Armbian image' \
		'make firstboot  Add local first-boot settings to a separate image' \
		'make image      Run extract, preloaded, firstboot, and validation' \
		'make newsd      Clean, prompt, build, and validate a fresh SD image' \
		'make summary    Show final image and redacted settings summary' \
		'make show-unredacted  Show the summary including local credentials' \
		'make validate   Validate the final image before writing to SD' \
		'make test       Run host/static/archive checks' \
		'make tests      Alias for make test' \
		'make clean      Remove generated outputs but preserve source images' \
		'make board-gpu-precheck/install/verify  Run GPU phases on the board' \
		'make board-gpu-test                     Run GPU checks and runtime validation' \
		'make board-diagnostics                  Capture board diagnostics' \
		'make board-vpu-precheck/install/verify  Run VPU phases on the board' \
		'make board-vpu-test                     Run VPU checks and decode tests' \
		'make board-vpu-decode-test              Run downloaded H.264/H.265 VPU tests' \
		'make board-vpu-generate-videos           Generate local synthetic VPU test videos' \
		'make board-vpu-fetch-videos              Fetch pinned individual VPU release assets' \
		'make release-vpu-test-videos             Publish generated VPU assets to GitHub' \
		'make board-npu-precheck/verify          Run supported NPU checks' \
		'make board-npu-test                     Run NPU test and save evidence' \
		'make board-test BOARD_LAYER=gpu|vpu|npu|all  Run diagnostic board checks' \
		'make board-tests BOARD_LAYER=...        Alias for board-test' \
		'make board-core-install/status          Install or inspect SSH/maintenance core' \
		'make board-a733-sources                 Clone/update maintained A733 sources' \
		'make npu-test-assets                    Stage selected A733 NPU test files' \
		'PowerVR app helper: ./scripts/run-pvr-app.sh COMMAND' \
		'REBUILD=1 make image  Rebuild an existing derived image safely'

extract:
	@if [[ -f $(VENDOR_OUTPUT)/pvr-userspace.tar.gz && -f $(VENDOR_OUTPUT)/vpu-userspace.tar.gz && -f $(VENDOR_OUTPUT)/npu-userspace.tar.gz ]]; then \
		echo 'Reusing existing vendor archives in $(VENDOR_OUTPUT)'; \
	else \
		./scripts/extract-vendor-userspace-docker.sh; \
	fi
	@if [[ -f work/images/ai-sdk.tar.gz && ! -f $(VENDOR_OUTPUT)/npu-test-assets.tar.gz ]]; then \
		./scripts/stage-npu-test-assets.sh --sdk-tarball work/images/ai-sdk.tar.gz \
			--output $(VENDOR_OUTPUT)/npu-test-assets.tar.gz; \
	fi

preset:
	@if [[ -e not_logged_in_yet || -e provisioning.sh ]]; then \
		if [[ $(REBUILD) != 1 ]]; then \
			echo 'ERROR: first-boot files already exist; use REBUILD=1 make preset.' >&2; exit 1; \
		fi; \
		stamp=$$(date -u +%Y%m%dT%H%M%SZ); \
		[[ ! -e not_logged_in_yet ]] || mv -- not_logged_in_yet not_logged_in_yet.previous.$$stamp; \
		[[ ! -e provisioning.sh ]] || mv -- provisioning.sh provisioning.sh.previous.$$stamp; \
	fi
	./scripts/create-headless-preset.sh --output ./not_logged_in_yet

preloaded: extract
	@if [[ -f $(PRELOADED) ]]; then \
		echo 'Reusing existing preloaded image: $(PRELOADED)'; \
	else \
		./scripts/prepare-preloaded-image-docker.sh; \
	fi

firstboot: preloaded
	@test -f not_logged_in_yet || { echo 'ERROR: create not_logged_in_yet first.' >&2; exit 1; }
	@test -f provisioning.sh || { echo 'ERROR: provisioning.sh not found.' >&2; exit 1; }
	@if [[ -f $(FINAL_POINTER) && $(REBUILD) != 1 ]]; then \
		echo 'ERROR: final image already exists and contains credentials.' >&2; \
		echo 'Use REBUILD=1 make image to preserve it and create a fresh one.' >&2; \
		exit 1; \
	elif [[ -f $(FINAL_POINTER) ]]; then \
		previous=$$(cat $(FINAL_POINTER)); \
		backup=$${previous%.img}.previous.$$(date -u +%Y%m%dT%H%M%SZ).img; \
		mv -- $$previous $$backup; \
		[[ ! -f $$previous.sha256 ]] || mv -- $$previous.sha256 $$backup.sha256; \
		echo "Preserved previous final image as $$backup"; \
	else \
		true; \
	fi
	@rm -f -- $(FINAL_POINTER) $(FINAL_WORK) $(FINAL_WORK).sha256
	@./scripts/prepare-firstboot-image-docker.sh
	@stamp=$$(date -u +%Y%m%dT%H%M%SZ); \
	final=$(BASE)-preloaded-firstboot-$$stamp.img; \
	mv -- $(FINAL_WORK) $$final; \
	rm -f -- $(FINAL_WORK).sha256; \
	(cd "$$(dirname -- "$$final")" && sha256sum -- "$$(basename -- "$$final")" > "$$(basename -- "$$final").sha256"); \
	printf '%s\n' "$$final" > $(FINAL_POINTER); \
	echo "Final SD image: $$final"

image: firstboot validate

newsd:
	$(MAKE) clean
	$(MAKE) extract
	$(MAKE) preset
	$(MAKE) image
	$(MAKE) summary

summary:
	@test -f $(FINAL_POINTER) || { echo 'ERROR: no final image has been built.' >&2; exit 1; }
	./scripts/show-build-summary.sh "$$(cat $(FINAL_POINTER))"

show-unredacted:
	@test -f $(FINAL_POINTER) || { echo 'ERROR: no final image has been built.' >&2; exit 1; }
	@echo 'WARNING: the following output contains credentials; do not share or save it.' >&2
	./scripts/show-build-summary.sh --unredacted "$$(cat $(FINAL_POINTER))"

validate:
	./scripts/validate-image-before-write.sh "$$(cat $(FINAL_POINTER))"

test:
	@find scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	@tests/static-checks.sh
	@tests/test-archives.sh
	@bash tests/host/test-preboot-extraction.sh
	@git diff --check

tests: test

board-test:
	@test -n '$(BOARD_LAYER)' || { echo 'ERROR: choose BOARD_LAYER=gpu, vpu, npu, or all.' >&2; exit 2; }
	@case '$(BOARD_LAYER)' in \
		gpu|vpu|npu|all) ;; \
		*) echo 'ERROR: BOARD_LAYER must be gpu, vpu, npu, or all.' >&2; exit 2 ;; \
	esac
	sudo ./tests/board/test-postboot-acceleration.sh --$(BOARD_LAYER) --output '$(BOARD_TEST_OUTPUT)'

board-tests: board-test

board-diagnostics:
	sudo ./scripts/collect-diagnostics.sh '$(BOARD_DIAGNOSTICS_OUTPUT)'

clean:
	@find $(VENDOR_OUTPUT) -mindepth 1 ! -name .gitkeep -exec rm -rf -- {} + 2>/dev/null || true
	@rm -rf -- work/vendor-output-first-run
	@find work/images/armbian -maxdepth 1 -type f \( \
		-name '$(notdir $(BASE))-preloaded.img' -o \
		-name '$(notdir $(BASE))-preloaded.img.*' -o \
		-name '$(notdir $(BASE))-preloaded-firstboot.img' -o \
		-name '$(notdir $(BASE))-preloaded-firstboot.img.*' -o \
		-name '$(notdir $(BASE))-preloaded-firstboot-*.img' -o \
		-name '$(notdir $(BASE))-preloaded-firstboot-*.img.*' \) -delete 2>/dev/null || true
	@rm -f -- $(FINAL_POINTER)
	@rm -f -- not_logged_in_yet provisioning.sh
	@rm -f -- not_logged_in_yet.previous.* provisioning.sh.previous.*
	@echo 'Removed generated archives, derived images, metadata, and local first-boot files.'
	@echo 'Preserved source/base images under work/images/.'

board-gpu-precheck:
	sudo $(BOARD_WORKFLOW) --layer gpu --action precheck $(BOARD_ARGS)

board-gpu-install:
	sudo $(BOARD_WORKFLOW) --layer gpu --action install --yes $(BOARD_ARGS)

board-gpu-verify:
	sudo $(BOARD_WORKFLOW) --layer gpu --action verify $(BOARD_ARGS)

board-gpu-runtime-test:
	sudo ./scripts/verify.sh

board-gpu-test: board-gpu-verify board-gpu-runtime-test
	@echo 'GPU diagnostic verification complete; run vkcube manually for visible presentation evidence.'

board-vpu-precheck:
	sudo $(BOARD_WORKFLOW) --layer vpu --action precheck $(BOARD_ARGS)

board-vpu-install:
	sudo $(BOARD_WORKFLOW) --layer vpu --action install --yes $(BOARD_ARGS)

board-vpu-verify:
	sudo $(BOARD_WORKFLOW) --layer vpu --action verify $(BOARD_ARGS)

board-vpu-test: board-vpu-verify

board-vpu-decode-test:
	sudo ./scripts/test-vpu-decode.sh --output /var/log/orangepi-zero3w-setup/vpu-decode-test.txt

board-vpu-generate-videos:
	sudo ./scripts/gen_test_videos.sh

board-vpu-fetch-videos:
	sudo ./scripts/fetch-vpu-test-videos.sh --tag $(VPU_TESTDATA_TAG)

release-vpu-test-videos:
	./scripts/publish-vpu-test-videos.sh --tag $(VPU_TESTDATA_TAG)

board-npu-precheck:
	sudo $(BOARD_WORKFLOW) --layer npu --action precheck $(BOARD_ARGS)

board-npu-install:
	sudo $(BOARD_WORKFLOW) --layer npu --action install --yes $(BOARD_ARGS)

board-npu-verify:
	sudo $(BOARD_WORKFLOW) --layer npu --action verify $(BOARD_ARGS)

board-npu-test:
	sudo ./scripts/test-npu.sh --output /var/log/orangepi-zero3w-setup/npu-smoke-test.txt

board-core-install:
	sudo ./setup.sh core

board-core-status:
	sudo ./setup.sh core --status

board-a733-sources:
	sudo ./setup.sh sources

npu-test-assets:
	@test -f work/images/ai-sdk.tar.gz || { echo 'ERROR: work/images/ai-sdk.tar.gz not found.' >&2; exit 1; }
	@./scripts/stage-npu-test-assets.sh --sdk-tarball work/images/ai-sdk.tar.gz \
		--output $(VENDOR_OUTPUT)/npu-test-assets.tar.gz
