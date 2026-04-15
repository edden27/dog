// Internal — regenerates UtilityDark.json from UtilityDarkTheme.swift.
//
// Mirrors the Style definitions and TokenType→Style switch in
// cli/Sources/dog/Theme/UtilityDarkTheme.swift, plus the editor UI colors,
// and emits a Zed-schema JSON theme. Loading the emitted JSON via
// ZedThemeLoader reproduces dog's default UtilityDark output byte-for-byte.
//
// If UtilityDarkTheme.swift changes, update the matching tables here and
// rerun. There is no build-time coupling — this is a source-of-parity script.
//
// Usage:
//   swift cli/scripts/generate-utilitydark-zed-json.swift [output.json]
//
// Default output path: cli/Sources/dog/Resources/themes/UtilityDark.json
// (only written if the parent directory exists — otherwise prints to stdout).

import Foundation

// MARK: - Style mirror

struct Style {
  let r: UInt8
  let g: UInt8
  let b: UInt8
  let bold: Bool
  let italic: Bool
  init(r: UInt8, g: UInt8, b: UInt8, bold: Bool = false, italic: Bool = false) {
    self.r = r; self.g = g; self.b = b; self.bold = bold; self.italic = italic
  }
  var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}

// MARK: - Named styles (mirror UtilityDarkTheme.swift)

let kwBoldItalic = Style(r: 238, g: 110, b: 57, bold: true, italic: true)
let kwBold       = Style(r: 238, g: 110, b: 57, bold: true)
let kwItalic     = Style(r: 238, g: 110, b: 57, italic: true)
let kwPlain      = Style(r: 238, g: 110, b: 57)
let pink         = Style(r: 227, g: 132, b: 167)
let fnColor      = Style(r: 129, g: 159, b: 132)
let fnBuiltin    = Style(r: 129, g: 159, b: 132, italic: true)
let typeBuiltin  = Style(r: 129, g: 159, b: 132, bold: true)
let yellow       = Style(r: 232, g: 166, b: 85)
let yellowItalic = Style(r: 232, g: 166, b: 85, italic: true)
let str          = Style(r: 205, g: 190, b: 171, italic: true)
let blueItalic   = Style(r: 158, g: 178, b: 201, italic: true)
let blue         = Style(r: 158, g: 178, b: 201)
let purple       = Style(r: 207, g: 149, b: 249)
let red          = Style(r: 204, g: 67,  b: 61)
let comment      = Style(r: 129, g: 116, b: 100)
let punct        = Style(r: 217, g: 217, b: 217)
let link         = Style(r: 39,  g: 112, b: 189)
let base         = Style(r: 205, g: 190, b: 171)

// Editor UI
let editorBg         = Style(r: 43, g: 43, b: 43)
let gutterBg         = Style(r: 29, g: 29, b: 29)
let lineNumber       = Style(r: 129, g: 116, b: 100)
let activeLineNumber = base
let editorFg         = base
let textColor        = base

// MARK: - Token table (mirror UtilityDarkTheme.color(for:))
//
// Each entry: (zed-scope, Style). Zed-scope is the nvim-treesitter capture
// name — ZedThemeLoader.resolveTokenType does exact match first, so this
// works. Order matters: parents before children. Loader's applyToChildren
// writes the parent's style over every child, then the explicit child entry
// overwrites it back. Sorting by dot-count ensures correctness.

let tokenEntries: [(String, Style)] = [
  // Keywords (bold+italic)
  ("keyword",                   kwBoldItalic),
  ("keyword.function",          kwBoldItalic),
  ("keyword.import",            kwBoldItalic),
  ("keyword.type",              kwBoldItalic),
  ("keyword.directive",         kwBoldItalic),
  ("keyword.directive.define",  kwBoldItalic),
  ("keyword.modifier",          kwBoldItalic),
  ("include",                   kwBoldItalic),

  // Keywords (italic)
  ("keyword.conditional",         kwItalic),
  ("keyword.conditional.ternary", kwItalic),
  ("keyword.coroutine",           kwItalic),
  ("keyword.exception",           kwItalic),
  ("keyword.operator",            kwItalic),
  ("keyword.repeat",              kwItalic),
  ("keyword.return",              kwItalic),
  ("conditional",                 kwItalic),
  ("repeat",                      kwItalic),

  // Plain kwPlain
  ("string.special",        kwPlain),
  ("string.special.symbol", kwPlain),
  ("constant.builtin",      kwPlain),

  // Pink
  ("string.escape", pink),
  ("boolean",       pink),
  ("markup.list",   pink),

  // Functions
  ("function",              fnColor),
  ("function.call",         fnColor),
  ("function.method",       fnColor),
  ("function.method.call",  fnColor),
  ("function.special",      fnColor),
  ("method",                fnColor),
  ("constructor",           fnColor),
  ("function.builtin",        fnBuiltin),
  ("function.method.builtin", fnBuiltin),

  // Types
  ("type.builtin",   typeBuiltin),
  ("module.builtin", typeBuiltin),

  // Yellow
  ("type",               yellow),
  ("type.definition",    yellow),
  ("constant",           yellow),
  ("module",             yellow),
  ("variable.parameter", yellow),
  ("parameter",          yellow),
  ("label",              yellow),
  ("function.macro",     yellow),
  ("constant.macro",     yellow),
  ("string.special.key", yellow),
  ("tag",                yellow),
  ("tag.builtin",        yellow),
  ("variable",           yellow),

  // Strings
  ("string",               str),
  ("string.documentation", str),
  ("string.special.path",  str),
  ("text.literal",         str),

  // Blue italic
  ("character",        blueItalic),
  ("variable.builtin", blueItalic),
  ("markup.quote",     blueItalic),

  // Blue
  ("attribute",         blue),
  ("tag.attribute",     blue),
  ("attribute.builtin", blue),
  ("variable.member",   blue),
  ("field",             blue),
  ("property",          blue),

  // Purple
  ("number",       purple),
  ("number.float", purple),
  ("float",        purple),

  // Red
  ("string.regex",         red),
  ("string.regexp",        red),
  ("string.special.regex", red),
  ("character.special",    red),
  ("error",                red),
  ("tag.error",            red),
  ("escape",               red),

  // Comments
  ("comment",               comment),
  ("comment.documentation", comment),
  ("markup.raw.block",      comment),

  // Punctuation
  ("punctuation.bracket",   punct),
  ("punctuation.delimiter", punct),
  ("punctuation.special",   punct),
  ("delimiter",             punct),
  ("operator",              punct),
  ("embedded",              punct),
  ("tag.delimiter",         punct),

  // Links
  ("markup.link.label",    link),
  ("text.reference",       link),
  ("text.uri",             link),
  ("string.special.url",   link),

  // Headings
  ("markup.heading",   kwBoldItalic),
  ("markup.heading.1", kwBoldItalic),
  ("markup.heading.2", kwBoldItalic),
  ("markup.heading.3", kwBoldItalic),
  ("markup.heading.4", kwBoldItalic),
  ("markup.heading.5", kwBoldItalic),
  ("text.title",       kwBoldItalic),

  // Base
  ("spell",   base),
  ("nospell", base),
  ("none",    base),
  ("conceal", base),
]

// MARK: - JSON emitter (hand-rolled, stable ordering)

func esc(_ s: String) -> String {
  var out = "\""
  for ch in s.unicodeScalars {
    switch ch {
    case "\"": out += "\\\""
    case "\\": out += "\\\\"
    case "\n": out += "\\n"
    default:   out.unicodeScalars.append(ch)
    }
  }
  out += "\""
  return out
}

func styleEntryJSON(scope: String, style: Style, indent: String) -> String {
  var fields: [String] = []
  fields.append("\"color\": \(esc(style.hex))")
  if style.bold { fields.append("\"font_weight\": 700") }
  if style.italic { fields.append("\"font_style\": \"italic\"") }
  let inner = fields.joined(separator: ", ")
  return "\(indent)\(esc(scope)): { \(inner) }"
}

// Sort: fewer dots first (parents before children). Stable on input order.
let sortedEntries = tokenEntries.enumerated().sorted { a, b in
  let da = a.element.0.filter { $0 == "." }.count
  let db = b.element.0.filter { $0 == "." }.count
  if da != db { return da < db }
  return a.offset < b.offset
}.map { $0.element }

var json = ""
json += "{\n"
json += "  \"$schema\": \"https://zed.dev/schema/themes/v0.2.0.json\",\n"
json += "  \"name\": \"UtilityDark\",\n"
json += "  \"author\": \"dog\",\n"
json += "  \"themes\": [\n"
json += "    {\n"
json += "      \"name\": \"UtilityDark\",\n"
json += "      \"appearance\": \"dark\",\n"
json += "      \"style\": {\n"
json += "        \"background\": \(esc(editorBg.hex)),\n"
json += "        \"editor.background\": \(esc(editorBg.hex)),\n"
json += "        \"editor.foreground\": \(esc(editorFg.hex)),\n"
json += "        \"editor.gutter.background\": \(esc(gutterBg.hex)),\n"
json += "        \"editor.line_number\": \(esc(lineNumber.hex)),\n"
json += "        \"editor.active_line_number\": \(esc(activeLineNumber.hex)),\n"
json += "        \"text\": \(esc(textColor.hex)),\n"
json += "        \"syntax\": {\n"

let syntaxLines = sortedEntries.map {
  styleEntryJSON(scope: $0.0, style: $0.1, indent: "          ")
}
json += syntaxLines.joined(separator: ",\n")
json += "\n        }\n"
json += "      }\n"
json += "    }\n"
json += "  ]\n"
json += "}\n"

// MARK: - Output

let args = CommandLine.arguments
let defaultPath: String = {
  let script = args[0]
  let scriptURL = URL(fileURLWithPath: script)
  let scriptsDir = scriptURL.deletingLastPathComponent()
  let cliDir = scriptsDir.deletingLastPathComponent()
  return cliDir
    .appendingPathComponent("Sources/dog/Resources/themes/UtilityDark.json")
    .path
}()

let outPath = args.count > 1 ? args[1] : defaultPath
let parent = (outPath as NSString).deletingLastPathComponent
var isDir: ObjCBool = false
let parentExists = FileManager.default.fileExists(atPath: parent, isDirectory: &isDir) && isDir.boolValue

if parentExists {
  do {
    try json.write(toFile: outPath, atomically: true, encoding: .utf8)
    FileHandle.standardError.write(Data("wrote \(outPath)\n".utf8))
  } catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    print(json, terminator: "")
    exit(1)
  }
} else {
  FileHandle.standardError.write(Data("parent dir missing (\(parent)) — printing to stdout\n".utf8))
  print(json, terminator: "")
}
