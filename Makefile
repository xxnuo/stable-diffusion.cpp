VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/projects/work/stable-diffusion.cpp
DOCKER_REGISTRY := registry.lazycat.cloud/x/stable-diffusion.cpp

init-gpu:
	ssh -t $(REMOTE) "sudo ip route add default via 192.168.1.202"

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

build: sync-to-gpu
	mkdir -p build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
	docker build --network=host \
	-t $(DOCKER_REGISTRY):$(VERSION) \
	--progress=plain \
	-f ./Dockerfile.jetson ."
	@echo $(DOCKER_REGISTRY):$(VERSION) >> jetson.dev.version

inspect: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
	docker run -it --rm \
	-v .:/opt/sdcpp \
	-v $(REMOTE_PATH)/../lzc-aipod-imagen:/opt/lzc-aipod-imagen \
	--network=host \
	$(DOCKER_REGISTRY):$(VERSION) \
	bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
	docker push $(DOCKER_REGISTRY):$(VERSION)"
	@echo $(DOCKER_REGISTRY):$(VERSION) >> jetson.version
