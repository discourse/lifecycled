VERSION=$(shell git describe --tags --candidates=1 --dirty 2>/dev/null || echo "dev")
FLAGS=-s -w -X main.Version=$(VERSION)
SRC=$(shell find . -type f -name '*.go' -not -path "./vendor/*")
USER=$(shell git config user.name)
EMAIL=$(shell git config user.email)
DIST?=stretch

export GO111MODULE=on

lifecycled: *.go
	go build -o lifecycled -ldflags="$(FLAGS)" -v ./cmd/lifecycled

.PHONY: docker
docker:
	docker run --rm -v $(PWD):/go/src/lifecycled -e GOCACHE=/go/src/lifecycled/build/.cache -u `id -u`:`id -g` golang make -C /go/src/lifecycled
	docker run --rm -v $(PWD):/src -e DIST=$(DIST) debian:$(DIST) /src/docker_buildpkg

.PHONY: test
test:
	gofmt -s -l -w $(SRC)
	go vet -v ./...
	go test -race -v ./...

.PHONY: generate
generate:
	go generate ./...

.PHONY: clean
clean:
	rm -f lifecycled
	rm -rf deb/*
	rm -f *.deb
	rm -f *.changes

.PHONY: release
release: arm64
# 	go get github.com/mitchellh/gox
	gox -ldflags="$(FLAGS)" -output="build/{{.Dir}}-{{.OS}}-{{.Arch}}" -osarch="freebsd/amd64 linux/386 linux/amd64 windows/amd64" ./cmd/lifecycled

# gox currenlty does not build arm64/aarch64 (https://github.com/mitchellh/gox/issues/92)
# Ensure we build both arm64 and aarch64 since `uname` can refer to the same arch using either name
.PHONY: arm64
arm64:
	GOOS=linux GOARCH=arm64 go build -o "build/lifecycled-linux-arm64" -ldflags="$(FLAGS)" -v ./cmd/lifecycled
	cp build/lifecycled-linux-arm64 build/lifecycled-linux-aarch64

.PHONY: package
package:
	rm -rf deb/*
	# binary
	install -D -m 0755 lifecycled deb/usr/sbin/lifecycled
	# upstart init file
	install -D -m 0644 init/upstart/lifecycled.conf deb/etc/init/lifecycled.conf
	# config file
	install -D -m 0644 etc/lifecycled deb/etc/lifecycled
	fpm \
		-s dir \
		-t deb \
		-n lifecycled \
		--deb-generate-changes \
		--deb-dist "$(DIST)" \
		--description "A daemon designed to run on an AWS EC2 instance and listen for various state change mechanisms" \
		--maintainer "$(USER) <$(EMAIL)>" \
		--version "$(VERSION)" \
		--force \
		--chdir deb \
		--deb-no-default-config-files \
		--deb-init init/sysv/lifecycled \
		--config-files /etc/lifecycled \
		.
