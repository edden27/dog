#!/usr/bin/env python3
"""Show all UtilityDark colors grouped by hex, with token assignments and styles.
Styles sourced from Xcode UtilityDark.xccolortheme font definitions."""
import sys

# style: None, "bold", "italic", "bold+italic"
colors = [
    ("#EE6E39", "bold+italic", [
        "keyword (declarations: func, class, struct, let, var, import, enum)",
    ]),
    ("#EE6E39", "italic", [
        "keyword (control flow: if, else, return, for, while, switch, try, throw)",
    ]),
    ("#EE6E39", None, [
        "string.special, string.special.symbol, constant.builtin",
    ]),
    ("#E384A7", None, [
        "string.escape, boolean",
    ]),
    ("#819F84", None, [
        "function, constructor, method, function.call, function.method",
    ]),
    ("#819F84", "italic", [
        "function.builtin, function.method.builtin",
    ]),
    ("#819F84", "bold", [
        "type.builtin, module.builtin",
    ]),
    ("#E8A655", None, [
        "type, type.definition, constant, module, variable",
        "variable.parameter, parameter, label, macro",
        "tag, tag.builtin",
    ]),
    ("#9EB2C9", "italic", [
        "character, variable.builtin, markup.quote",
    ]),
    ("#9EB2C9", None, [
        "attribute, tag.attribute",
        "property, field, variable.member",
    ]),
    ("#CF95F9", None, [
        "number, float",
    ]),
    ("#CC433D", None, [
        "string.regex, string.regexp, string.special.regex, character.special",
        "error, tag.error, escape",
    ]),
    ("#817464", None, [
        "comment, comment.documentation, string.documentation",
    ]),
    ("#D9D9D9", None, [
        "operator, punctuation (all), delimiter, embedded, tag.delimiter",
    ]),
    ("#2770BD", None, [
        "text.uri, text.reference, markup.link.label, string.special.url",
    ]),
    ("#CDBEAB", "italic", [
        "string",
    ]),
    ("#CDBEAB", "bold", [
        "markup.heading (all), markup.list, text.literal, text.title",
    ]),
    ("#CDBEAB", None, [
        "base text, markup.raw.block, spell, none, conceal",
    ]),
]

BOLD = "\033[1m"
ITALIC = "\033[3m"
RESET = "\033[0m"

for hex_color, style, token_groups in colors:
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    fg = f"\033[38;2;{r};{g};{b}m"
    bg = f"\033[48;2;{r};{g};{b}m"

    # Build styled sample text
    style_prefix = ""
    style_label = ""
    if style == "bold":
        style_prefix = BOLD
        style_label = " [bold]"
    elif style == "italic":
        style_prefix = ITALIC
        style_label = " [italic]"
    elif style == "bold+italic":
        style_prefix = BOLD + ITALIC
        style_label = " [bold+italic]"

    block = f"{bg}      {RESET}"
    text = f"{style_prefix}{fg}{hex_color}{style_label}{RESET}"
    sys.stdout.write(f"{block} {text}  {token_groups[0]}\n")
    for extra in token_groups[1:]:
        sys.stdout.write(f"              {extra}\n")
    sys.stdout.write("\n")
