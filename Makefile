VERSION ?= 0.1.0
DIST    := dist

MAC_BIN         := .build/release/dog
LINUX_X86_BIN   := dog-linux-x86_64
LINUX_ARM_BIN   := dog-linux-arm64

MAC_ARM_TAR     := $(DIST)/dog-$(VERSION)-macos-arm64.tar.gz
MAC_X86_TAR     := $(DIST)/dog-$(VERSION)-macos-x86_64.tar.gz
LINUX_X86_TAR   := $(DIST)/dog-$(VERSION)-linux-x86_64.tar.gz
LINUX_ARM_TAR   := $(DIST)/dog-$(VERSION)-linux-arm64.tar.gz

.PHONY: all release-macos release-linux package package-macos package-linux shas clean help

help:
	@echo "Targets:"
	@echo "  release-macos   Build universal macOS release binary (arm64+x86_64)"
	@echo "  release-linux   Build Linux x86_64 + arm64 release binaries via Docker"
	@echo "  package         Tar + sha256 all platforms (runs both releases)"
	@echo "  package-macos   Tar + sha256 macOS arm64 + x86_64"
	@echo "  package-linux   Tar + sha256 Linux x86_64 + arm64"
	@echo "  shas            Print sha256 of existing tarballs"
	@echo "  clean           Remove dist/ and build artifacts"

# -Xcc -flto=thin: thin LTO on the C targets (tree-sitter runtime + grammars),
# measured -7..-9% on medium+ files with byte-identical output. C-only on
# purpose: -Xswiftc -lto=llvm-thin breaks dual-arch/cross builds (linker looks
# for .o where swiftc emitted bitcode) and adds <1% over C-only.
#
# verify-blob-arch: precompiled-query blobs (perf Item 4) are struct-layout
# dependent; universal builds are only safe if arm64 and x86_64 produce
# byte-identical blobs. The check proves it per-toolchain on every release.
release-macos: verify-blob-arch
	swift build -c release --arch arm64 --arch x86_64 -Xcc -flto=thin
	@ls -la .build/apple/Products/Release/dog

.PHONY: verify-blob-arch
verify-blob-arch:
	bash scripts/verify-query-blob-arch.sh

release-linux:
	bash scripts/generate/linux.sh binary

$(DIST):
	mkdir -p $(DIST)

package-macos: release-macos | $(DIST)
	@UNI=.build/apple/Products/Release/dog; \
	TMP=$$(mktemp -d); \
	lipo -thin arm64  $$UNI -output $$TMP/dog-arm64; \
	lipo -thin x86_64 $$UNI -output $$TMP/dog-x86_64; \
	strip -x $$TMP/dog-arm64 $$TMP/dog-x86_64; \
	install -m 755 $$TMP/dog-arm64  $$TMP/dog && tar -C $$TMP -czf $(MAC_ARM_TAR) dog && rm $$TMP/dog; \
	install -m 755 $$TMP/dog-x86_64 $$TMP/dog && tar -C $$TMP -czf $(MAC_X86_TAR) dog && rm $$TMP/dog; \
	rm -rf $$TMP
	@$(MAKE) shas

package-linux: release-linux | $(DIST)
	@TMP=$$(mktemp -d); \
	install -m 755 $(LINUX_X86_BIN) $$TMP/dog && tar -C $$TMP -czf $(LINUX_X86_TAR) dog && rm $$TMP/dog; \
	install -m 755 $(LINUX_ARM_BIN) $$TMP/dog && tar -C $$TMP -czf $(LINUX_ARM_TAR) dog && rm $$TMP/dog; \
	rm -rf $$TMP
	@$(MAKE) shas

package: package-macos package-linux

shas:
	@echo ""
	@echo "sha256 of tarballs:"
	@for f in $(DIST)/*.tar.gz; do \
	  [ -f "$$f" ] || continue; \
	  shasum -a 256 "$$f"; \
	done

clean:
	rm -rf $(DIST) .build $(LINUX_X86_BIN) $(LINUX_ARM_BIN)
