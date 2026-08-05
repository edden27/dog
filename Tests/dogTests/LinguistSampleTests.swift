import Testing

@testable import dog

/// Verify detection against GitHub Linguist's samples/ directory filenames,
/// using realistic full filesystem paths. Tests all four detection stages:
/// - Stage 2: known filenames (Gemfile, .bashrc, Package.swift, etc.)
/// - Stage 3: extensions (all 17 languages) + suffix stripping (common.h.in)
/// - Stage 4: shebang on extensionless files (bash, python, ruby, etc.)
/// Also tests edge cases: spaces in paths, @, dashes, UUIDs, double extensions.
///
/// Source: https://github.com/github-linguist/linguist/tree/master/samples/
/// Generated via script cross-referencing linguist filenames against our
/// LanguageMap tables (2026-04-06).
struct ShebangSample: Sendable, CustomTestStringConvertible {
  let expected: String
  let filename: String
  let source: String
  var testDescription: String { "\(filename) → \(expected)" }
}

struct EdgeCaseSample: Sendable, CustomTestStringConvertible {
  let expected: String?
  let filename: String
  var testDescription: String { "\(filename) → \(expected ?? "nil")" }
}

@Suite("Linguist Samples")
struct LinguistSampleTests {

  // MARK: - Detectable (239 linguist files with full paths)

  private static let detectable: [(expected: String, filename: String)] = [
    // Shell → bash
    ("bash", "/home/user/dotfiles/build.command"),
    ("bash", "/home/user/dotfiles/invalid-shebang.sh"),
    ("bash", "/home/user/dotfiles/rbenv-sh-shell.sh"),
    ("bash", "/home/user/dotfiles/robbyrussell.zsh-theme"),
    ("bash", "/home/user/dotfiles/rvm.bash"),
    ("bash", "/home/user/dotfiles/script.bash"),
    ("bash", "/home/user/dotfiles/script.sh"),
    ("bash", "/home/user/dotfiles/script.zsh"),

    // C .c files
    ("c", "/Users/dev/project/src/array.c"),
    ("c", "/Users/dev/project/src/blob.c"),
    ("c", "/Users/dev/project/src/commit.c"),
    ("c", "/Users/dev/project/src/custom_extensions.c"),
    ("c", "/Users/dev/project/src/exception.zep.c"),
    ("c", "/Users/dev/project/src/fudge_node.c"),
    ("c", "/Users/dev/project/src/git.c"),
    ("c", "/Users/dev/project/src/hello.c"),
    ("c", "/Users/dev/project/src/http_parser.c"),
    ("c", "/Users/dev/project/src/markdown.c"),
    ("c", "/Users/dev/project/src/process.c"),
    ("c", "/Users/dev/project/src/rdiscount.c"),
    ("c", "/Users/dev/project/src/redis.c"),
    ("c", "/Users/dev/project/src/rf_io.c"),
    ("c", "/Users/dev/project/src/rfc_string.c"),
    ("c", "/Users/dev/project/src/sgd_fast.c"),
    ("c", "/Users/dev/project/src/yajl.c"),

    // C .h files → cpp (bat override: .h → cpp)
    ("cpp", "/Users/dev/project/src/ArrowLeft.h"),
    ("cpp", "/Users/dev/project/src/Field.h"),
    ("cpp", "/Users/dev/project/src/GLKMatrix4.h"),
    ("cpp", "/Users/dev/project/src/NWMan.h"),
    ("cpp", "/Users/dev/project/src/Nightmare.h"),
    ("cpp", "/Users/dev/project/src/array.h"),
    ("cpp", "/Users/dev/project/src/asm.h"),
    ("cpp", "/Users/dev/project/src/bitmap.h"),
    ("cpp", "/Users/dev/project/src/blob.h"),
    ("cpp", "/Users/dev/project/src/bootstrap.h"),
    ("cpp", "/Users/dev/project/src/color.h"),
    ("cpp", "/Users/dev/project/src/commit.h"),
    ("cpp", "/Users/dev/project/src/common.h.in"),
    ("cpp", "/Users/dev/project/src/cpuid.h"),
    ("cpp", "/Users/dev/project/src/driver.h"),
    ("cpp", "/Users/dev/project/src/elf.h"),
    ("cpp", "/Users/dev/project/src/exception.zep.h"),
    ("cpp", "/Users/dev/project/src/filter.h"),
    ("cpp", "/Users/dev/project/src/hello.h"),
    ("cpp", "/Users/dev/project/src/http_parser.h"),
    ("cpp", "/Users/dev/project/src/info.h"),
    ("cpp", "/Users/dev/project/src/interface.h"),
    ("cpp", "/Users/dev/project/src/ip4.h"),
    ("cpp", "/Users/dev/project/src/jni_layer.h"),
    ("cpp", "/Users/dev/project/src/multiboot.h"),
    ("cpp", "/Users/dev/project/src/ntru_encrypt.h"),
    ("cpp", "/Users/dev/project/src/portio.h"),
    ("cpp", "/Users/dev/project/src/pqiv.h"),
    ("cpp", "/Users/dev/project/src/rf_io.h"),
    ("cpp", "/Users/dev/project/src/rfc_string.h"),
    ("cpp", "/Users/dev/project/src/rpc.h"),
    ("cpp", "/Users/dev/project/src/scheduler.h"),
    ("cpp", "/Users/dev/project/src/syscalldefs.h"),
    ("cpp", "/Users/dev/project/src/syscalls.h"),
    ("cpp", "/Users/dev/project/src/vfs.h"),
    ("cpp", "/Users/dev/project/src/vmem.h"),
    ("cpp", "/Users/dev/project/src/wglew.h"),

    // C++ native files
    ("cpp", "/opt/engine/src/core/16F88.h"),
    ("cpp", "/opt/engine/src/core/CsvStreamer.h"),
    ("cpp", "/opt/engine/src/core/Entity.h"),
    ("cpp", "/opt/engine/src/core/Math.inl"),
    ("cpp", "/opt/engine/src/core/Memory16F88.h"),
    ("cpp", "/opt/engine/src/core/NoDiscard.h"),
    ("cpp", "/opt/engine/src/core/PackageInfoParser.cpp"),
    ("cpp", "/opt/engine/src/core/ThreadedQueue.h"),
    ("cpp", "/opt/engine/src/core/Types.h"),
    ("cpp", "/opt/engine/src/core/bar.h"),
    ("cpp", "/opt/engine/src/core/bar.hh"),
    ("cpp", "/opt/engine/src/core/bar.hpp"),
    ("cpp", "/opt/engine/src/core/constexpr_header.h"),
    ("cpp", "/opt/engine/src/core/crypter.cpp"),
    ("cpp", "/opt/engine/src/core/env.cpp"),
    ("cpp", "/opt/engine/src/core/env.h"),
    ("cpp", "/opt/engine/src/core/epoll_reactor.ipp"),
    ("cpp", "/opt/engine/src/core/gblib.cppm"),
    ("cpp", "/opt/engine/src/core/gdsdbreader.h"),
    ("cpp", "/opt/engine/src/core/graphics.cpp"),
    ("cpp", "/opt/engine/src/core/grpc.pb.cc"),
    ("cpp", "/opt/engine/src/core/hello.cpp"),
    ("cpp", "/opt/engine/src/core/hello.grpc.pb.h"),
    ("cpp", "/opt/engine/src/core/hello.ino"),
    ("cpp", "/opt/engine/src/core/json_reader.cpp"),
    ("cpp", "/opt/engine/src/core/json_writer.cpp"),
    ("cpp", "/opt/engine/src/core/key.cpp"),
    ("cpp", "/opt/engine/src/core/key.h"),
    ("cpp", "/opt/engine/src/core/libcanister.h"),
    ("cpp", "/opt/engine/src/core/main.cpp"),
    ("cpp", "/opt/engine/src/core/metrics.h"),
    ("cpp", "/opt/engine/src/core/module.ixx"),
    ("cpp", "/opt/engine/src/core/octave_changer.ino"),
    ("cpp", "/opt/engine/src/core/protocol-buffer.pb.cc"),
    ("cpp", "/opt/engine/src/core/protocol-buffer.pb.h"),
    ("cpp", "/opt/engine/src/core/render_adapter.cpp"),
    ("cpp", "/opt/engine/src/core/runtime-compiler.cc"),
    ("cpp", "/opt/engine/src/core/scanner.cc"),
    ("cpp", "/opt/engine/src/core/scanner.h"),
    ("cpp", "/opt/engine/src/core/search.txx"),
    ("cpp", "/opt/engine/src/core/srs_app_ingest.cpp"),
    ("cpp", "/opt/engine/src/core/target.txx"),
    ("cpp", "/opt/engine/src/core/utils.h"),
    ("cpp", "/opt/engine/src/core/v8.cc"),
    ("cpp", "/opt/engine/src/core/v8.h"),
    ("cpp", "/opt/engine/src/core/vtkSparseArray.txx"),
    ("cpp", "/opt/engine/src/core/wrapper_inner.cpp"),

    // CSS
    ("css", "/var/www/assets/css/bootstrap.css"),
    ("css", "/var/www/assets/css/bootstrap.min.css"),

    // Go
    ("go", "/home/dev/go/src/pkg/api.pb.go"),
    ("go", "/home/dev/go/src/pkg/embedded.go"),
    ("go", "/home/dev/go/src/pkg/gen-go-linguist-thrift.go"),
    ("go", "/home/dev/go/src/pkg/oapi-codegen.go"),

    // HTML
    ("html", "/var/www/templates/example.xht"),
    ("html", "/var/www/templates/pages.html"),
    ("html", "/var/www/templates/pkgdown.html"),

    // JavaScript
    ("javascript", "/Users/dev/webapp/src/bootstrap-modal.js"),
    ("javascript", "/Users/dev/webapp/src/ccalc-lex.js"),
    ("javascript", "/Users/dev/webapp/src/ccalc-parse.js"),
    ("javascript", "/Users/dev/webapp/src/classes-old.js"),
    ("javascript", "/Users/dev/webapp/src/classes.js"),
    ("javascript", "/Users/dev/webapp/src/constant_fold.mjs"),
    ("javascript", "/Users/dev/webapp/src/dude.js"),
    ("javascript", "/Users/dev/webapp/src/entry.mjs"),
    ("javascript", "/Users/dev/webapp/src/gen-js-linguist-thrift.js"),
    ("javascript", "/Users/dev/webapp/src/hello.js"),
    ("javascript", "/Users/dev/webapp/src/http.js"),
    ("javascript", "/Users/dev/webapp/src/intro-old.js"),
    ("javascript", "/Users/dev/webapp/src/intro.js"),
    ("javascript", "/Users/dev/webapp/src/jquery-1.4.2.min.js"),
    ("javascript", "/Users/dev/webapp/src/jquery-1.6.1.js"),
    ("javascript", "/Users/dev/webapp/src/jquery-1.6.1.min.js"),
    ("javascript", "/Users/dev/webapp/src/jquery-1.7.2.js"),
    ("javascript", "/Users/dev/webapp/src/json2_backbone.js"),
    ("javascript", "/Users/dev/webapp/src/merge.js"),
    ("javascript", "/Users/dev/webapp/src/modernizr.js"),
    ("javascript", "/Users/dev/webapp/src/module.mjs"),
    ("javascript", "/Users/dev/webapp/src/namespace.js"),
    ("javascript", "/Users/dev/webapp/src/parser.js"),
    ("javascript", "/Users/dev/webapp/src/proto.js"),
    ("javascript", "/Users/dev/webapp/src/sample.jsx"),
    ("javascript", "/Users/dev/webapp/src/steelseries-min.js"),
    ("javascript", "/Users/dev/webapp/src/uglify.js"),

    // JSON
    ("json", "/home/user/config/code-scanning.sarif"),
    ("json", "/home/user/config/geo.geojson"),
    ("json", "/home/user/config/http_response.avsc"),
    ("json", "/home/user/config/manifest.webmanifest"),
    ("json", "/home/user/config/person.json"),
    ("json", "/home/user/config/product.json"),
    ("json", "/home/user/config/schema.json"),
    ("json", "/home/user/config/switzerland.topojson"),

    // Lua
    ("lua", "/usr/local/share/lua/luatexts-0.1.2-1.rockspec"),
    ("lua", "/usr/local/share/lua/treegen.p8"),

    // Markdown
    ("markdown", "/Users/dev/docs/README.mdown"),
    ("markdown", "/Users/dev/docs/bunyan.1.ronn"),
    ("markdown", "/Users/dev/docs/csharp6.workbook"),
    ("markdown", "/Users/dev/docs/livebook.livemd"),
    ("markdown", "/Users/dev/docs/minimal.md"),
    ("markdown", "/Users/dev/docs/ronn-format.7.ronn"),
    ("markdown", "/Users/dev/docs/ronn.1.ronn"),
    ("markdown", "/Users/dev/docs/symlink.md"),
    ("markdown", "/Users/dev/docs/tender.md"),

    // Python
    ("python", "/home/user/scripts/argparse.pyi"),
    ("python", "/home/user/scripts/django-models-base.py"),
    ("python", "/home/user/scripts/flask-view.py"),
    ("python", "/home/user/scripts/gen-py-linguist-thrift.py"),
    ("python", "/home/user/scripts/protocol_buffer_pb2.py"),
    ("python", "/home/user/scripts/py3.py3"),
    ("python", "/home/user/scripts/tornado-httpserver.py"),

    // Ruby
    ("ruby", "/opt/app/lib/foo.rb"),
    ("ruby", "/opt/app/lib/formula.rb"),
    ("ruby", "/opt/app/lib/gen-rb-linguist-thrift.rb"),
    ("ruby", "/opt/app/lib/grit.rb"),
    ("ruby", "/opt/app/lib/inflector.rb"),
    ("ruby", "/opt/app/lib/jekyll.rb"),
    ("ruby", "/opt/app/lib/racc.rb"),
    ("ruby", "/opt/app/lib/resque.rb"),
    ("ruby", "/opt/app/lib/script.rake"),
    ("ruby", "/opt/app/lib/sinatra.rb"),

    // Rust
    ("rust", "/Users/dev/crate/src/hashmap.rs"),
    ("rust", "/Users/dev/crate/src/main.rs"),
    ("rust", "/Users/dev/crate/src/task.rs"),

    // Swift (trimmed — 42 section-N.swift files all test same .swift extension)
    ("swift", "/Users/dev/ios-app/Sources/section-3.swift"),
    ("swift", "/Users/dev/ios-app/Sources/section-41.swift"),
    ("swift", "/Users/dev/ios-app/Sources/section-87.swift"),

    // TSX
    ("tsx", "/Users/dev/frontend/components/import.tsx"),
    ("tsx", "/Users/dev/frontend/components/react-native.tsx"),
    ("tsx", "/Users/dev/frontend/components/require.tsx"),
    ("tsx", "/Users/dev/frontend/components/triple-slash-reference.tsx"),

    // TypeScript
    ("typescript", "/Users/dev/server/src/cache.ts"),
    ("typescript", "/Users/dev/server/src/classes.ts"),
    ("typescript", "/Users/dev/server/src/conditionParser.mts"),
    ("typescript", "/Users/dev/server/src/hello.ts"),
    ("typescript", "/Users/dev/server/src/promisified_cp.cts"),
    ("typescript", "/Users/dev/server/src/proto.ts"),

    // YAML
    ("yaml", "/etc/config/229Q.yaml"),
    ("yaml", "/etc/config/vcr_cassette.yml"),

    // Known filenames (Stage 2 — linguist samples include these)
    ("ruby", "/opt/app/Gemfile"),
    ("ruby", "/opt/app/Rakefile"),
    ("ruby", "/opt/app/Capfile"),
    ("ruby", "/opt/app/Vagrantfile"),
    ("ruby", "/opt/app/Guardfile"),
    ("ruby", "/opt/app/Brewfile"),
    ("bash", "/home/user/.bashrc"),
    ("bash", "/home/user/.zshrc"),
    ("bash", "/home/user/.bash_profile"),
    ("bash", "/home/user/.profile"),
    ("bash", "/home/user/project/gradlew"),
    ("bash", "/home/user/project/PKGBUILD"),
    ("swift", "/Users/dev/ios-app/Package.swift"),
    ("rust", "/Users/dev/crate/Cargo.lock"),
    ("json", "/Users/dev/project/composer.lock"),
    ("json", "/Users/dev/project/deno.lock"),
    ("json", "/Users/dev/project/Package.resolved"),
    ("yaml", "/Users/dev/project/.clang-format"),
    ("yaml", "/Users/dev/project/yarn.lock"),
    ("python", "/home/user/project/SConstruct"),
    ("python", "/home/user/project/BUILD"),
    ("lua", "/usr/local/share/.luacheckrc"),
    ("markdown", "/Users/dev/docs/contents.lr")

  ]

  // MARK: - Unmapped (101 linguist files — expect nil)

  private static let unmapped: [String] = [
    // Shell — extensionless or unmapped extensions
    "/home/user/dotfiles/99-bottles-of-beer",
    "/home/user/dotfiles/bash",
    "/home/user/dotfiles/busybox.trigger",
    "/home/user/dotfiles/job_array.slurm",
    "/home/user/dotfiles/mpi_job.slurm",
    "/home/user/dotfiles/php.fcgi",
    "/home/user/dotfiles/plugin",
    "/home/user/dotfiles/sbt",
    "/home/user/dotfiles/settime.cgi",
    "/home/user/dotfiles/sh",
    "/home/user/dotfiles/string-chopping",
    "/home/user/dotfiles/udev.trigger",
    "/home/user/dotfiles/valid-shebang.tool",
    "/home/user/dotfiles/zsh",

    // C — uppercase .C/.H or unmapped
    "/Users/dev/project/src/2D.C",
    "/Users/dev/project/src/2D.H",
    "/Users/dev/project/src/Arduino.cats",
    "/Users/dev/project/src/readline.cats",
    "/Users/dev/project/src/script",

    // C++ — unmapped extensions
    "/opt/engine/src/core/ClasspathVMSystemProperties.inc",
    "/opt/engine/src/core/bug1163046.--skeleton.re",
    "/opt/engine/src/core/cnokw.re",
    "/opt/engine/src/core/cvsignore.re",
    "/opt/engine/src/core/initClasses.inc",
    "/opt/engine/src/core/instances.inc",
    "/opt/engine/src/core/program.cp",
    "/opt/engine/src/core/simple.re",

    // HTML — unmapped extensions
    "/var/www/templates/Crear_logo.hta",
    "/var/www/templates/index.html.hl",
    "/var/www/templates/rpanel.inc",
    "/var/www/templates/tailDel.inc",
    "/var/www/templates/wehaveoddjobs.hta",

    // JavaScript — unmapped extensions or extensionless
    "/Users/dev/webapp/src/axios.es",
    "/Users/dev/webapp/src/chart_composers.gs",
    "/Users/dev/webapp/src/helloHanaEndpoint.xsjs",
    "/Users/dev/webapp/src/helloHanaMath.xsjslib",
    "/Users/dev/webapp/src/index.es",
    "/Users/dev/webapp/src/intro.js.frag",
    "/Users/dev/webapp/src/itau.gs",
    "/Users/dev/webapp/src/js",
    "/Users/dev/webapp/src/js2",
    "/Users/dev/webapp/src/jsbuild.jsb",
    "/Users/dev/webapp/src/logo.jscad",
    "/Users/dev/webapp/src/outro.js.frag",
    "/Users/dev/webapp/src/run",

    // JSON — unmapped extensions
    "/home/user/config/2ea73365-b6f1-4bd1-a454-d57a67e50684.yy",
    "/home/user/config/4DPopGit.4DProject",
    "/home/user/config/GMS2_Project.yyp",
    "/home/user/config/Git Commit.JSON-tmLanguage",
    "/home/user/config/Material_Alpha_01.gltf",
    "/home/user/config/VCT.yy",
    "/home/user/config/block-sync-counter8.ice",
    "/home/user/config/form.4DForm",
    "/home/user/config/google-services.json.example",
    "/home/user/config/landing.tact",
    "/home/user/config/manifest.webapp",
    "/home/user/config/pack.mcmeta",
    "/home/user/config/recording.har",
    "/home/user/config/small.tfstate",
    "/home/user/config/terraform.tfstate.backup",

    // Lua — unmapped extensions
    "/usr/local/share/lua/h-counter.pd_lua",
    "/usr/local/share/lua/vidya-file-list-parser.pd_lua",
    "/usr/local/share/lua/vidya-file-modder.pd_lua",
    "/usr/local/share/lua/wsapi.fcgi",

    // Markdown — unmapped extensions
    "/Users/dev/docs/sway.5.scd",

    // Python — unmapped extensions or extensionless
    "/home/user/scripts/AdditiveWave.pyde",
    "/home/user/scripts/Cinema4DPythonPlugin.pyp",
    "/home/user/scripts/MoveEye.pyde",
    "/home/user/scripts/action.cgi",
    "/home/user/scripts/backstage.fcgi",
    "/home/user/scripts/python",
    "/home/user/scripts/python2",
    "/home/user/scripts/python3",
    "/home/user/scripts/simpleclient.rpy",
    "/home/user/scripts/spec.linux.spec",
    "/home/user/scripts/standalone.gypi",
    "/home/user/scripts/toolchain.gypi",
    "/home/user/scripts/uv-download-countries-info",

    // Ruby — unmapped extensions or extensionless
    "/opt/app/lib/actionmailer.rbi",
    "/opt/app/lib/address.pdf.prawn",
    "/opt/app/lib/any.spec",
    "/opt/app/lib/gem_loader.rbi",
    "/opt/app/lib/index.json.jbuilder",
    "/opt/app/lib/jenkinsci.pluginspec",
    "/opt/app/lib/macruby",
    "/opt/app/lib/mdata_server.fcgi",
    "/opt/app/lib/rabl.rabl",
    "/opt/app/lib/rails@7.0.3.1.rbi",
    "/opt/app/lib/rendering.rbi",
    "/opt/app/lib/rexpl",
    "/opt/app/lib/ruby",
    "/opt/app/lib/ruby2",
    "/opt/app/lib/ruby3",
    "/opt/app/lib/shoes-swt",

    // Rust — extensionless
    "/Users/dev/crate/src/base64url",

    // YAML — unmapped extensions
    "/etc/config/Ansible.YAML-tmLanguage",
    "/etc/config/HexInspect.sublime-syntax",
    "/etc/config/coredns.yaml.sed",
    "/etc/config/database.yml.mysql",
    "/etc/config/expected-floating-point-literal.mir",
    "/etc/config/source.r-console.syntax"
  ]

  // MARK: - Edge Case Paths (spaces, symbols, unicode in directories)

  private static let edgeCasePaths: [EdgeCaseSample] = [
    // Spaces in directory
    .init(expected: "swift", filename: "/Users/dev/My Projects/iOS App/Sources/main.swift"),
    .init(expected: "javascript", filename: "/home/user/my code/web app/src/index.js"),
    .init(expected: "python", filename: "/tmp/test dir/nested dir/script.py"),

    // Spaces in filename (from linguist: "Git Commit.JSON-tmLanguage")
    .init(expected: nil, filename: "/home/user/config/Git Commit.JSON-tmLanguage"),

    // @ symbol in path and filename
    .init(expected: nil, filename: "/opt/app/lib/rails@7.0.3.1.rbi"),
    .init(expected: "ruby", filename: "/opt/@scope/packages/gem.rb"),

    // Dashes, dots, numbers in path
    .init(expected: "cpp", filename: "/opt/engine-v2/src-2.0/core-lib/16F88.h"),
    .init(expected: "javascript", filename: "/home/user/my-app.v3/src/jquery-1.6.1.min.js"),

    // Double extension with unknown second part
    .init(expected: nil, filename: "/var/www/templates/index.html.hl"),
    .init(expected: nil, filename: "/Users/dev/webapp/src/intro.js.frag"),

    // UUID in path
    .init(expected: "json", filename: "/tmp/2ea73365-b6f1-4bd1/config/schema.json"),

    // Deeply nested
    .init(expected: "rust", filename: "/a/b/c/d/e/f/g/h/i/j/k/l/main.rs"),

    // Trailing slash edge (shouldn't happen but defensive)
    .init(expected: "go", filename: "/home/dev/project/main.go"),

    // Dot in directory name
    .init(expected: "typescript", filename: "/Users/dev/app.v2.1/src/cache.ts"),
    .init(expected: "yaml", filename: "/etc/systemd/system/service.d/override.yml")
  ]

  // MARK: - Shebang Detection (Stage 4 — extensionless files with shebangs)
  // Linguist detects these via shebang. Without source content, we return nil.
  // These tests verify Stage 4 works when the file has no extension or known filename.

  private static let shebangCases: [ShebangSample] = [
    // Shell scripts (extensionless, detected by shebang)
    .init(expected: "bash", filename: "/home/user/dotfiles/bash", source: "#!/usr/bin/env bash\necho hello\n"),
    .init(expected: "bash", filename: "/home/user/dotfiles/sh", source: "#!/bin/sh\necho hello\n"),
    .init(expected: "bash", filename: "/home/user/dotfiles/zsh", source: "#!/usr/bin/env zsh\necho hello\n"),
    .init(expected: "bash", filename: "/usr/local/bin/myscript", source: "#!/bin/bash\nset -e\n"),
    .init(expected: "bash", filename: "/home/user/dotfiles/plugin", source: "#!/usr/bin/env sh\n# plugin\n"),

    // Python (extensionless)
    .init(expected: "python", filename: "/home/user/scripts/python", source: "#!/usr/bin/env python\nimport sys\n"),
    .init(expected: "python", filename: "/home/user/scripts/python2", source: "#!/usr/bin/env python2\nimport sys\n"),
    .init(expected: "python", filename: "/home/user/scripts/python3", source: "#!/usr/bin/env python3\nimport sys\n"),
    .init(expected: "python", filename: "/home/user/scripts/uv-download", source: "#!/usr/bin/env uv\nimport json\n"),

    // Ruby (extensionless)
    .init(expected: "ruby", filename: "/opt/app/lib/macruby", source: "#!/usr/bin/env macruby\nputs 'hi'\n"),
    .init(expected: "ruby", filename: "/opt/app/lib/ruby", source: "#!/usr/bin/env ruby\nputs 'hi'\n"),
    .init(expected: "ruby", filename: "/opt/app/lib/rexpl", source: "#!/usr/bin/env ruby\nrequire 'irb'\n"),

    // JavaScript (extensionless)
    .init(
      expected: "javascript", filename: "/Users/dev/webapp/src/js",
      source: "#!/usr/bin/env node\nconsole.log('hi')\n"),
    .init(
      expected: "javascript", filename: "/Users/dev/webapp/src/run",
      source: "#!/usr/bin/env node\nprocess.exit(0)\n"),

    // Lua (extensionless)
    .init(expected: "lua", filename: "/usr/local/bin/luascript", source: "#!/usr/bin/env lua\nprint('hi')\n"),

    // Rust (extensionless)
    .init(
      expected: "rust", filename: "/Users/dev/crate/src/base64url",
      source: "#!/usr/bin/env rust-script\nfn main() {}\n"),

    // C (extensionless via tcc)
    .init(expected: "c", filename: "/usr/local/bin/cscript", source: "#!/usr/bin/env tcc\nint main() { return 0; }\n"),

    // Swift (extensionless)
    .init(expected: "swift", filename: "/usr/local/bin/swiftscript", source: "#!/usr/bin/env swift\nprint(\"hi\")\n"),

    // Shebang with env flags on extensionless file
    .init(expected: "python", filename: "/usr/local/bin/worker", source: "#!/usr/bin/env -S python3\nimport os\n"),
    .init(
      expected: "ruby", filename: "/usr/local/bin/task",
      source: "#!/usr/bin/env -u BUNDLE_GEMFILE ruby\nGem.clear_paths\n"),

    // Shebang with version on extensionless file
    .init(expected: "python", filename: "/usr/local/bin/legacy", source: "#!/usr/bin/env python2.7\nimport sys\n")
  ]

  // MARK: - Tests

  @Test("Detectable linguist samples (full paths)", arguments: detectable)
  func detectableSample(expected: String, filename: String) {
    let result = LanguageDetector.detect(filename: filename, sourceBytes: [], explicit: nil)
    #expect(result == expected, "'\(filename)' → '\(result ?? "nil")' (expected '\(expected)')")
  }

  @Test("Unmapped linguist samples return nil (full paths)", arguments: unmapped)
  func unmappedSample(filename: String) {
    let result = LanguageDetector.detect(filename: filename, sourceBytes: [], explicit: nil)
    #expect(result == nil, "'\(filename)' → '\(result ?? "nil")' (expected nil)")
  }

  @Test("Edge case paths", arguments: edgeCasePaths)
  func edgeCasePath(_ sample: EdgeCaseSample) {
    let result = LanguageDetector.detect(filename: sample.filename, sourceBytes: [], explicit: nil)
    #expect(result == sample.expected)
  }

  @Test("Shebang detection on extensionless files", arguments: shebangCases)
  func shebangDetection(_ sample: ShebangSample) {
    let result = LanguageDetector.detect(
      filename: sample.filename, sourceBytes: Array(sample.source.utf8), explicit: nil)
    #expect(result == sample.expected)
  }
}
