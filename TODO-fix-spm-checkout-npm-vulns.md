14 package-lock.json files in .build/checkouts/ come from remote SPM deps that include npm tooling in their source repos. These reappear on every clean build / SPM resolve.

These npm files are not used by the Swift build. The vulns are in tree-sitter's dev tooling (eslint, esbuild, ajv, brace-expansion, flatted), not the C library.

## Affected paths

.build/checkouts/tree-sitter-go/package-lock.json
.build/checkouts/tree-sitter-bash/package-lock.json
.build/checkouts/tree-sitter-markdown/package-lock.json
.build/checkouts/tree-sitter-swift/package-lock.json
.build/checkouts/tree-sitter-swift/test-npm-package/package-lock.json
.build/checkouts/tree-sitter/cli/eslint/package-lock.json
.build/checkouts/tree-sitter/lib/binding_web/package-lock.json
.build/index-build/checkouts/tree-sitter-go/package-lock.json
.build/index-build/checkouts/tree-sitter-bash/package-lock.json
.build/index-build/checkouts/tree-sitter-markdown/package-lock.json
.build/index-build/checkouts/tree-sitter-swift/package-lock.json
.build/index-build/checkouts/tree-sitter-swift/test-npm-package/package-lock.json
.build/index-build/checkouts/tree-sitter/cli/eslint/package-lock.json
.build/index-build/checkouts/tree-sitter/lib/binding_web/package-lock.json

## Where they come from

These SPM dependencies in Package.swift fetch repos that contain npm source files:

- tree-sitter (core C lib) — from: "0.25.0" — has cli/eslint/ and lib/binding_web/ with npm lockfiles
- tree-sitter-go — from: "0.23.0"
- tree-sitter-bash — from: "0.23.0"
- tree-sitter-markdown — branch: "split_parser"
- tree-sitter-swift — alex-pinkus fork

## Options

1. Post-build nuke script — add to Makefile or build phase:
   ```sh
   find .build -name "package-lock.json" -path "*/checkouts/*" -delete
   find .build -name "package.json" -path "*/checkouts/*" -delete
   ```

2. Xcode build phase — add a "Run Script" phase that runs the above after SPM resolve

3. Git hook — post-checkout or post-merge hook that cleans them

4. Wait for upstream — tree-sitter repos need to update their npm lockfiles. As of 2026-05-18 even tree-sitter@0.26.8 still ships vulnerable npm deps (ajv, brace-expansion, flatted)

5. Ignore — these are inert source files sitting on disk, not installed, not running, no node_modules. Only flagged because npm audit scans any lockfile it finds.
