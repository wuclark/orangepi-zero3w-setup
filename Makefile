SHELL := /usr/bin/env bash

BASE := work/images/armbian/Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal
RELEASE_VERSION := $(strip $(shell /usr/bin/cat VERSION 2>/dev/null))
GIT_REVISION := $(strip $(shell /usr/bin/git rev-parse --short HEAD 2>/dev/null || echo nogit))
IMAGE_RELEASE_TAG := v$(RELEASE_VERSION)-g$(GIT_REVISION)
PRELOADED := $(BASE)-preloaded.img
FINAL_WORK := $(BASE)-preloaded-firstboot.img
FINAL_POINTER := work/images/armbian/.last-final-image
VENDOR_OUTPUT := work/vendor-output
REBUILD ?= no
VPU_TESTDATA_TAG ?= vpu-testdata-v1
BOARD_LAYER ?=
BOARD_TEST_OUTPUT ?= /var/log/orangepi-zero3w-setup/postboot-acceleration.txt
BOARD_DIAGNOSTICS_OUTPUT ?= /var/log/orangepi-zero3w-setup/diagnostics.txt
DESKTOP_PROFILE ?=
DESKTOP_REBOOT ?= no
REMOTE_BACKEND ?=
REMOTE_USER ?=
GIT_DEPTH ?= 1

.PHONY: help version docker-toolchain kernel-source extract preset preloaded firstboot image newsd summary show-unredacted validate test tests clean \
	board-test board-tests board-diagnostics board-validation board-base board-packages board-core board-sources board-foundation board-initial-setup board-initial-setup-gui board-acceleration-install board-gpu-test board-gpu-runtime-test board-gpu-compute-deps board-gpu-compute-test wsl-vulkan-compute-deps wsl-vulkan-compute-test board-vpu-test \
	board-gpu-x11-setup board-gpu-wayland-setup board-gpu-wayland-verify board-gpu-sway-setup board-gpu-sway-verify board-gpu-weston-setup \
	board-docker-install board-docker-verify \
	desktop desktop-switch desktop-list desktop-current desktop-rollback \
	lightdm-mask lightdm-unmask \
	desktop-openbox desktop-xfce desktop-i3 desktop-icewm desktop-fluxbox \
	desktop-sway desktop-labwc desktop-enlightenment-x11 desktop-enlightenment-wayland \
	switch-openbox switch-xfce switch-i3 switch-icewm switch-fluxbox switch-sway switch-labwc \
	switch-enlightenment-x11 switch-enlightenment-wayland \
	remote remote-x11vnc remote-wayvnc remote-tigervnc remote-status \
	board-vpu-generate-videos board-vpu-generate-decode-videos \
	board-vpu-fetch-videos release-vpu-test-videos \
	board-gpu-precheck board-gpu-install board-gpu-verify board-headless-benchmark board-system-benchmark board-system-benchmark-deps \
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
		'make kernel-source  Stage the matching PowerVR module source for the image' \
		'make docker-toolchain  Build the pinned Docker extraction toolchain' \
		'make version    Show release version and Git revision used in image names' \
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
		'make board-gpu-compute-deps              Install Vulkan compute build tools' \
		'make board-gpu-compute-test              Run headless Vulkan compute benchmark' \
		'make board-headless-benchmark             Run GPU, VPU, and NPU headless benchmarks' \
		'make board-system-benchmark               Run CPU, compression, crypto, and memory benchmarks' \
		'make board-system-benchmark-deps          Install system benchmark tools' \
		'make board-gpu-wayland-setup             Install Sway and WayVNC as the default Wayland path' \
		'make board-gpu-wayland-verify            Verify the Sway Wayland session and WayVNC' \
		'make board-gpu-weston-setup              Install the explicit Weston PowerVR service path' \
		'make board-gpu-x11-setup                 Switch to XFCE/Xorg and x11vnc' \
		'make board-docker-install DOCKER_APT_UPDATE=1  Install Docker, Buildx, and Compose' \
		'make board-docker-verify                         Verify Docker, Compose, Buildx, and containers' \
		'make wsl-vulkan-compute-deps             Install WSL/Ubuntu CPU Vulkan tools' \
		'make wsl-vulkan-compute-test             Run benchmark with Lavapipe CPU Vulkan' \
		'make board-diagnostics                  Capture board diagnostics' \
		'make board-validation                  Run all installed-layer validations' \
		'make board-foundation                  Install base, packages, core, sources' \
		'make board-initial-setup               Install base, core, and all acceleration layers' \
		'make board-initial-setup-gui           Add XFCE/X11, x11vnc, and enable LightDM' \
		'make board-base/packages/core/sources  Run one foundation step' \
		'  GIT_DEPTH=0 make board-sources       Use full Git history for sources' \
		'make board-acceleration-install        Install GPU, VPU, and NPU layers' \
		'make board-vpu-precheck/install/verify  Run VPU phases on the board' \
		'make board-vpu-test                     Run VPU checks and decode tests' \
		'make board-vpu-decode-test              Run downloaded H.264/H.265 VPU tests' \
		'make board-vpu-generate-videos           Generate local synthetic VPU test videos' \
		'make board-vpu-generate-decode-videos    Generate only the two decode-test videos' \
		'make board-vpu-fetch-videos              Fetch pinned individual VPU release assets' \
		'make release-vpu-test-videos             Publish generated VPU assets to GitHub' \
		'make board-npu-precheck/verify          Run supported NPU checks' \
		'make board-npu-test                     Run NPU test and save evidence' \
		'make board-test BOARD_LAYER=gpu|vpu|npu|all  Run diagnostic board checks' \
		'make board-tests BOARD_LAYER=...        Alias for board-test' \
		'make desktop DESKTOP_PROFILE=openbox    Install a desktop profile' \
		'make desktop-switch DESKTOP_PROFILE=xfce  Switch installed session' \
		'make desktop-list/current             List or show desktop sessions' \
		'make lightdm-mask                    Mask LightDM and stop its session' \
		'make lightdm-unmask                  Unmask and re-enable LightDM' \
		'make desktop-<profile>               Install a named desktop profile' \
		'make switch-<profile>                Switch to an installed profile' \
		'make remote REMOTE_BACKEND=x11vnc   Install a remote backend' \
		'make remote-x11vnc/wayvnc/tigervnc  Install a named remote backend' \
		'make remote-status                   Show remote service status' \
		'make board-core-install/status          Install or inspect SSH/maintenance core' \
		'make board-a733-sources                 Clone/update maintained A733 sources' \
		'make npu-test-assets                    Stage selected A733 NPU test files' \
		'PowerVR app helper: ./scripts/run-pvr-app.sh COMMAND' \
		'REBUILD=1 make image  Rebuild an existing derived image safely'

docker-toolchain:
	./scripts/build-docker-toolchain.sh

extract: docker-toolchain
	@if [[ -f $(VENDOR_OUTPUT)/pvr-userspace.tar.gz && -f $(VENDOR_OUTPUT)/vpu-userspace.tar.gz && -f $(VENDOR_OUTPUT)/npu-userspace.tar.gz ]]; then \
		echo 'Reusing existing vendor archives in $(VENDOR_OUTPUT)'; \
	else \
		./scripts/extract-vendor-userspace-docker.sh; \
	fi
	@if [[ -f work/images/ai-sdk.tar.gz && ! -f $(VENDOR_OUTPUT)/npu-test-assets.tar.gz ]]; then \
		./scripts/stage-npu-test-assets.sh --sdk-tarball work/images/ai-sdk.tar.gz \
			--output $(VENDOR_OUTPUT)/npu-test-assets.tar.gz; \
	fi

kernel-source:
	./scripts/prepare-kernel-source.sh

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

preloaded: extract kernel-source docker-toolchain
	@if [[ -f $(PRELOADED) ]]; then \
		echo 'Reusing existing preloaded image: $(PRELOADED)'; \
	else \
		./scripts/prepare-preloaded-image-docker.sh; \
	fi

firstboot: preloaded docker-toolchain
	@test -n '$(RELEASE_VERSION)' || { echo 'ERROR: VERSION is empty.' >&2; exit 1; }
	@[[ '$(RELEASE_VERSION)' =~ ^[0-9]+\.[0-9]+\.[0-9]+$$ ]] || { echo 'ERROR: VERSION must contain MAJOR.MINOR.PATCH.' >&2; exit 1; }
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
	final=$(BASE)-$(IMAGE_RELEASE_TAG)-preloaded-firstboot-$$stamp.img; \
	mv -- $(FINAL_WORK) $$final; \
	rm -f -- $(FINAL_WORK).sha256; \
	(cd "$$(dirname -- "$$final")" && sha256sum -- "$$(basename -- "$$final")" > "$$(basename -- "$$final").sha256"); \
	printf '%s\n' "$$final" > $(FINAL_POINTER); \
	echo "Final SD image: $$final"

image: firstboot validate

version:
	@echo "Release version: $(RELEASE_VERSION)"
	@echo "Git revision:    $(GIT_REVISION)"
	@echo "Image tag:       $(IMAGE_RELEASE_TAG)"

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

board-validation:
	sudo ./scripts/board-validation.sh

board-base:
	sudo ./setup.sh base

board-packages:
	sudo ./setup.sh packages

board-core:
	sudo ./setup.sh core

board-sources:
	sudo env GIT_DEPTH='$(GIT_DEPTH)' ./setup.sh sources

board-foundation:
	$(MAKE) board-base
	$(MAKE) board-packages
	$(MAKE) board-core
	$(MAKE) board-sources

board-initial-setup:
	$(MAKE) board-base
	$(MAKE) board-packages
	$(MAKE) board-core
	$(MAKE) board-acceleration-install

board-initial-setup-gui:
	$(MAKE) board-initial-setup
	$(MAKE) lightdm-unmask
	$(MAKE) desktop-xfce
	$(MAKE) remote-x11vnc REMOTE_USER='$(REMOTE_USER)'
	sudo systemctl enable lightdm.service

board-acceleration-install:
	$(MAKE) board-gpu-install
	$(MAKE) board-vpu-install
	$(MAKE) board-npu-install

desktop:
	@test -n '$(DESKTOP_PROFILE)' || { echo 'ERROR: choose DESKTOP_PROFILE=openbox, xfce, i3, icewm, fluxbox, sway, labwc, enlightenment-x11, or enlightenment-wayland.' >&2; exit 2; }
	sudo ./setup.sh desktop --profile '$(DESKTOP_PROFILE)'

desktop-switch:
	@test -n '$(DESKTOP_PROFILE)' || { echo 'ERROR: choose DESKTOP_PROFILE=<installed-profile>.' >&2; exit 2; }
	@if [[ '$(DESKTOP_REBOOT)' == 1 || '$(DESKTOP_REBOOT)' == yes ]]; then \
		sudo ./scripts/orangepi-session set '$(DESKTOP_PROFILE)' --reboot; \
	else \
		sudo ./scripts/orangepi-session set '$(DESKTOP_PROFILE)'; \
	fi

desktop-list:
	sudo ./scripts/orangepi-session list

desktop-current:
	sudo ./scripts/orangepi-session current

desktop-rollback:
	@if [[ '$(DESKTOP_REBOOT)' == 1 || '$(DESKTOP_REBOOT)' == yes ]]; then \
		 sudo ./scripts/orangepi-session rollback --reboot; \
	else \
		sudo ./scripts/orangepi-session rollback; \
	fi

lightdm-mask:
	sudo systemctl mask --now lightdm.service

lightdm-unmask:
	sudo systemctl unmask lightdm.service
	sudo systemctl enable lightdm.service

desktop-openbox: DESKTOP_PROFILE := openbox
desktop-openbox: desktop
desktop-xfce: DESKTOP_PROFILE := xfce
desktop-xfce: desktop
desktop-i3: DESKTOP_PROFILE := i3
desktop-i3: desktop
desktop-icewm: DESKTOP_PROFILE := icewm
desktop-icewm: desktop
desktop-fluxbox: DESKTOP_PROFILE := fluxbox
desktop-fluxbox: desktop
desktop-sway: DESKTOP_PROFILE := sway
desktop-sway: desktop
desktop-labwc: DESKTOP_PROFILE := labwc
desktop-labwc: desktop
desktop-enlightenment-x11: DESKTOP_PROFILE := enlightenment-x11
desktop-enlightenment-x11: desktop
desktop-enlightenment-wayland: DESKTOP_PROFILE := enlightenment-wayland
desktop-enlightenment-wayland: desktop

switch-openbox: DESKTOP_PROFILE := openbox
switch-openbox: desktop-switch
switch-xfce: DESKTOP_PROFILE := xfce
switch-xfce: desktop-switch
switch-i3: DESKTOP_PROFILE := i3
switch-i3: desktop-switch
switch-icewm: DESKTOP_PROFILE := icewm
switch-icewm: desktop-switch
switch-fluxbox: DESKTOP_PROFILE := fluxbox
switch-fluxbox: desktop-switch
switch-sway: DESKTOP_PROFILE := sway
switch-sway: desktop-switch
switch-labwc: DESKTOP_PROFILE := labwc
switch-labwc: desktop-switch
switch-enlightenment-x11: DESKTOP_PROFILE := enlightenment-x11
switch-enlightenment-x11: desktop-switch
switch-enlightenment-wayland: DESKTOP_PROFILE := enlightenment-wayland
switch-enlightenment-wayland: desktop-switch

remote:
	@test -n '$(REMOTE_BACKEND)' || { echo 'ERROR: choose REMOTE_BACKEND=x11vnc, wayvnc, or tigervnc.' >&2; exit 2; }
	@case '$(REMOTE_BACKEND)' in \
		x11vnc|wayvnc|tigervnc) ;; \
		*) echo 'ERROR: REMOTE_BACKEND must be x11vnc, wayvnc, or tigervnc.' >&2; exit 2 ;; \
	esac
	@if [[ -n '$(REMOTE_USER)' ]]; then \
		sudo ./setup.sh remote --backend '$(REMOTE_BACKEND)' --user '$(REMOTE_USER)'; \
	else \
		sudo ./setup.sh remote --backend '$(REMOTE_BACKEND)'; \
	fi

remote-x11vnc:
	$(MAKE) remote REMOTE_BACKEND=x11vnc REMOTE_USER='$(REMOTE_USER)'
remote-wayvnc:
	$(MAKE) remote REMOTE_BACKEND=wayvnc REMOTE_USER='$(REMOTE_USER)'
remote-tigervnc:
	$(MAKE) remote REMOTE_BACKEND=tigervnc REMOTE_USER='$(REMOTE_USER)'

remote-status:
	sudo systemctl status x11vnc.service --no-pager -l || true
	@echo 'wayvnc and TigerVNC are package-only targets; configure/start their session separately.'

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

board-gpu-compute-deps:
	sudo ./scripts/install-vulkan-compute-deps.sh

board-gpu-compute-test:
	sudo ./scripts/run-vulkan-compute-benchmark.sh \
		--output /var/log/orangepi-zero3w-setup/vulkan-compute-benchmark.txt

board-headless-benchmark:
	sudo ./scripts/board-headless-benchmark.sh

board-system-benchmark-deps:
	sudo ./scripts/install-system-benchmark-deps.sh

board-system-benchmark:
	sudo ./scripts/board-system-benchmark.sh

board-docker-install:
	sudo env DOCKER_APT_UPDATE='$(DOCKER_APT_UPDATE)' DOCKER_USER='$(DOCKER_USER)' ./scripts/install-docker.sh

board-docker-verify:
	./scripts/verify-docker.sh

board-gpu-x11-setup:
	sudo /usr/bin/systemctl disable --now weston-pvr.service 2>/dev/null || true
	if sudo /usr/bin/test -f /etc/systemd/system/weston-pvr.service && ! sudo /usr/bin/test -L /etc/systemd/system/weston-pvr.service; then \
		sudo /usr/bin/mv /etc/systemd/system/weston-pvr.service /etc/systemd/system/weston-pvr.service.disabled; \
	fi
	sudo /usr/bin/systemctl mask weston-pvr.service
	sudo /usr/bin/systemctl unmask lightdm.service
	sudo /usr/bin/systemctl enable getty@tty1.service
	$(MAKE) desktop-xfce
	sudo /usr/bin/systemctl enable --now lightdm.service
	$(MAKE) remote-x11vnc REMOTE_USER='$(REMOTE_USER)'
	sudo /usr/bin/systemctl restart x11vnc.service

board-gpu-sway-setup:
	sudo ./scripts/10-fix-pvr-linker-and-glvnd.sh
	sudo /usr/bin/systemctl disable --now x11vnc.service 2>/dev/null || true
	sudo /usr/bin/systemctl disable --now weston-pvr.service 2>/dev/null || true
	if sudo /usr/bin/test -f /etc/systemd/system/weston-pvr.service && ! sudo /usr/bin/test -L /etc/systemd/system/weston-pvr.service; then \
		sudo /usr/bin/mv /etc/systemd/system/weston-pvr.service /etc/systemd/system/weston-pvr.service.disabled; \
	fi
	sudo /usr/bin/systemctl mask weston-pvr.service
	sudo /usr/bin/systemctl unmask lightdm.service
	$(MAKE) desktop-sway
	$(MAKE) remote-wayvnc REMOTE_USER='$(REMOTE_USER)'
	sudo ./scripts/orangepi-session set sway
	sudo /usr/bin/systemctl enable --now lightdm.service
	sudo /usr/bin/systemctl restart lightdm.service

board-gpu-wayland-setup: board-gpu-sway-setup

board-gpu-weston-setup:
	sudo ./scripts/10-fix-pvr-linker-and-glvnd.sh
	$(MAKE) remote-wayvnc REMOTE_USER='$(REMOTE_USER)'
	sudo ./scripts/20-install-weston-service.sh

board-gpu-wayland-verify:
	./scripts/98-verify-sway-wayvnc.sh

board-gpu-sway-verify: board-gpu-wayland-verify

wsl-vulkan-compute-deps:
	./scripts/install-wsl-vulkan-compute-deps.sh

wsl-vulkan-compute-test:
	@icd=$$(find /usr/share/vulkan/icd.d -maxdepth 1 -type f \( -iname '*lvp*.json' -o -iname '*lavapipe*.json' \) -print -quit); \
	[[ -n $$icd ]] || { echo 'ERROR: Lavapipe ICD not found; run make wsl-vulkan-compute-deps.' >&2; exit 1; }; \
	VK_DRIVER_FILES=$$icd ./scripts/run-vulkan-compute-benchmark.sh \
		--output work/wsl-vulkan-compute-benchmark.txt

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

board-vpu-generate-decode-videos:
	sudo ./scripts/gen_test_videos.sh --decode-pair

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
