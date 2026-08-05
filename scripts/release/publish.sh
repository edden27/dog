#!/usr/bin/env bash
#
# One-command release: tag, build all four binaries, create the GitHub
# Release with tarballs attached, and update the Homebrew tap formula.
#
# Usage:
#   scripts/release/publish.sh 0.1.0
#   scripts/release/publish.sh 0.1.0 --skip-build   # reuse existing dist/ tarballs
#
# One-time prerequisites:
#   - gh CLI installed and logged in            (gh auth status)
#   - this repo pushed to github.com/edden27/dog
#   - tap repo exists: github.com/edden27/homebrew-dog
#   - Docker/OrbStack running                   (Linux builds)
#
# Safe to re-run after a failure: every step skips or overwrites cleanly.

set -euo pipefail

VERSION="${1:?usage: $0 <version, e.g. 0.1.0> [--skip-build]}"
SKIP_BUILD=0
[ "${2:-}" = "--skip-build" ] && SKIP_BUILD=1
TAG="v$VERSION"
REPO="edden27/dog"
TAP_REPO="edden27/homebrew-dog"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

step() { echo ""; echo "━━━ $1"; }

# ── sanity checks ────────────────────────────────────────────────────────────
step "sanity checks"
command -v gh >/dev/null || { echo "gh not installed (brew install gh)"; exit 1; }
gh auth status >/dev/null || { echo "not logged in — run: gh auth login"; exit 1; }
[ "$SKIP_BUILD" = 1 ] || docker info >/dev/null 2>&1 || { echo "Docker/OrbStack not running"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean — commit first"; exit 1; }

# --version output comes from Dog.swift, tarball names from the Makefile.
# Refuse to ship if they disagree.
grep -q "version: \"$VERSION\"" Sources/dog/Dog.swift \
  || { echo "Sources/dog/Dog.swift version != $VERSION — update it first"; exit 1; }
echo "ok"

# ── tag ──────────────────────────────────────────────────────────────────────
step "tag $TAG"
git rev-parse "$TAG" >/dev/null 2>&1 || git tag -a "$TAG" -m "dog $TAG"
git push origin "$TAG"

# ── build + package all four platforms ───────────────────────────────────────
step "build (make package)"
if [ "$SKIP_BUILD" = 1 ]; then
    for platform in macos-arm64 macos-x86_64 linux-x86_64 linux-arm64; do
        [ -f "dist/dog-$platform.tar.gz" ] \
            || { echo "--skip-build: dist/dog-$platform.tar.gz missing — run make package first"; exit 1; }
    done
    echo "skipped — using existing dist/ tarballs"
else
    rm -rf dist
    make package
fi

# ── GitHub Release: create as draft, attach tarballs, then publish ───────────
step "GitHub release"
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release create "$TAG" --repo "$REPO" --draft \
        --title "dog $VERSION" --generate-notes
fi
gh release upload "$TAG" dist/dog-*.tar.gz --repo "$REPO" --clobber
gh release edit "$TAG" --repo "$REPO" --draft=false
echo "https://github.com/$REPO/releases/tag/$TAG"

# ── Homebrew tap: regenerate the formula and push it ─────────────────────────
step "Homebrew formula"
sha() { shasum -a 256 "dist/dog-$1.tar.gz" | cut -d' ' -f1; }
BASE="https://github.com/$REPO/releases/download/$TAG"

TAP_DIR="$(mktemp -d)"
git clone --depth 1 "https://github.com/$TAP_REPO.git" "$TAP_DIR"
mkdir -p "$TAP_DIR/Formula"
cat > "$TAP_DIR/Formula/dog.rb" <<EOF
class Dog < Formula
  desc "Like bat but faster w/ deeper theming - perfect for fzf, tv, yazi"
  homepage "https://sh.dog"
  version "$VERSION"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "$BASE/dog-macos-arm64.tar.gz"
      sha256 "$(sha macos-arm64)"
    else
      url "$BASE/dog-macos-x86_64.tar.gz"
      sha256 "$(sha macos-x86_64)"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "$BASE/dog-linux-arm64.tar.gz"
      sha256 "$(sha linux-arm64)"
    else
      url "$BASE/dog-linux-x86_64.tar.gz"
      sha256 "$(sha linux-x86_64)"
    end
  end

  def install
    bin.install "dog"
    generate_completions_from_executable(bin/"dog", "--generate-completion-script")
  end

  test do
    (testpath/"point.swift").write "struct Point { let x, y: Int }"
    assert_match "Point", shell_output("#{bin}/dog --color=always --paging=never point.swift")
    assert_match "let", shell_output("echo 'let x = 1' | #{bin}/dog --color=always --paging=never -l swift")
    assert_match "$VERSION", shell_output("#{bin}/dog --version")
  end
end
EOF

git -C "$TAP_DIR" add Formula/dog.rb
if git -C "$TAP_DIR" diff --cached --quiet; then
    echo "formula unchanged"
else
    git -C "$TAP_DIR" commit -m "dog $VERSION"
    git -C "$TAP_DIR" push
fi
rm -rf "$TAP_DIR"

step "done — dog $VERSION released"
