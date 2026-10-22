#!/usr/bin/env python3
"""mailstead-sig.py - signature HTML sanitizer / renderer / text converter.

Python 3 standard library only. Used by Mailstead's signature subsystem:
  sanitize IN [OUT]                  allowlist-clean HTML (exit 2 if rejected)
  render TPL OUT.html [--txt F] [--set K=V ...]   Mustache-lite render
  totext IN                          HTML -> plain text alternative
  inspect-image FILE                 print "WIDTHxHEIGHT TYPE" (PNG/GIF/JPEG)

Exit codes: 0 ok, 1 usage/IO, 2 rejected content (policy/size/type).
"""
import html
import re
import struct
import sys

ALLOWED_TAGS = {
    "table", "tbody", "thead", "tr", "td", "th", "p", "br", "div", "span",
    "a", "img", "b", "strong", "i", "em", "u", "hr", "font", "small",
    "h1", "h2", "h3", "h4", "ul", "ol", "li",
}
VOID_TAGS = {"br", "hr", "img"}
ALLOWED_ATTRS = {
    "style", "href", "src", "alt", "width", "height", "border",
    "cellpadding", "cellspacing", "align", "valign", "bgcolor",
    "colspan", "rowspan", "dir", "title",
}
ALLOWED_CSS = {
    "color", "background-color", "font-family", "font-size", "font-weight",
    "font-style", "text-decoration", "text-align", "line-height",
    "padding", "margin", "border", "width", "height", "max-width",
    "vertical-align", "display",
}
CSS_PREFIX_OK = ("padding-", "margin-", "border-")
SAFE_URL_SCHEMES = ("https:", "http:", "mailto:", "tel:")
SAFE_SRC_SCHEMES = ("https:", "cid:")
FORBIDDEN_TAGS = {
    "script", "iframe", "object", "embed", "form", "input", "button",
    "link", "meta", "base", "svg", "style",
}
MAX_HTML = 10 * 1024
WARN_HTML = 6 * 1024
MAX_IMAGE = 200 * 1024


class Reject(Exception):
    pass


def _css_ok(prop, value):
    prop = prop.strip().lower()
    value = value.strip()
    if not prop:
        return False
    if not (prop in ALLOWED_CSS or prop.startswith(CSS_PREFIX_OK)):
        return False
    low = value.lower()
    if "url(" in low or "expression(" in low:
        return False
    if prop == "display" and low not in ("block", "inline", "inline-block", "none"):
        return False
    return True


def _clean_style(value):
    out = []
    for decl in value.split(";"):
        if ":" not in decl:
            continue
        prop, _, val = decl.partition(":")
        if _css_ok(prop, val):
            out.append("%s:%s" % (prop.strip().lower(), val.strip()))
    return ";".join(out)


class Sanitizer:
    def __init__(self):
        self.parts = []
        self.open = []
        self.skip_tag = None
        self.skip_depth = 0

    def feed(self, text):
        from html.parser import HTMLParser
        outer = self

        class P(HTMLParser):
            def handle_starttag(self, tag, attrs):
                outer._start(tag, attrs)

            def handle_startendtag(self, tag, attrs):
                outer._start(tag, attrs)
                if tag.lower() not in VOID_TAGS and tag.lower() not in FORBIDDEN_TAGS:
                    outer.parts.append("</%s>" % tag)

            def handle_endtag(self, tag):
                outer._end(tag)

            def handle_data(self, data):
                if outer.skip_tag:
                    return
                outer.parts.append(html.escape(data, quote=False))

            def handle_entityref(self, name):
                if outer.skip_tag:
                    return
                outer.parts.append("&%s;" % name)

            def handle_charref(self, name):
                if outer.skip_tag:
                    return
                outer.parts.append("&#%s;" % name)

        p = P(convert_charrefs=False)
        p.feed(text)
        p.close()
        for tag in reversed(self.open):
            self.parts.append("</%s>" % tag)

    def _start(self, tag, attrs):
        tag = tag.lower()
        if self.skip_tag:
            if tag == self.skip_tag:
                self.skip_depth += 1
            return
        if tag in FORBIDDEN_TAGS:
            self.skip_tag = tag
            self.skip_depth = 1
            return
        if tag not in ALLOWED_TAGS:
            return  # drop unknown tags but keep their content
        clean = []
        href_external = False
        for name, value in attrs:
            name = name.lower()
            value = value or ""
            if name == "style":
                v = _clean_style(value)
                if v:
                    clean.append(("style", v))
                continue
            if name not in ALLOWED_ATTRS:
                continue
            low = value.strip().lower()
            if name in ("href",):
                if not low.startswith(SAFE_URL_SCHEMES):
                    continue
                if low.startswith(("http:", "https:")):
                    href_external = True
            if name in ("src",):
                if low.startswith("data:"):
                    raise Reject("src=data: rejected")
                if not low.startswith(SAFE_SRC_SCHEMES):
                    continue
            if name.startswith("on"):
                continue
            clean.append((name, value))
        if tag == "a" and href_external:
            clean.append(("rel", "noopener noreferrer"))
            clean.append(("target", "_blank"))
        attr_str = "".join(
            ' %s="%s"' % (k, html.escape(v, quote=True)) for k, v in clean
        )
        if tag in VOID_TAGS:
            self.parts.append("<%s%s>" % (tag, attr_str))
        else:
            self.parts.append("<%s%s>" % (tag, attr_str))
            self.open.append(tag)

    def _end(self, tag):
        tag = tag.lower()
        if self.skip_tag:
            if tag == self.skip_tag:
                self.skip_depth -= 1
                if self.skip_depth <= 0:
                    self.skip_tag = None
                    self.skip_depth = 0
            return
        if tag in FORBIDDEN_TAGS and tag not in ALLOWED_TAGS:
            return
        if tag in VOID_TAGS or tag not in ALLOWED_TAGS:
            return
        if tag in self.open:
            self.open.reverse()
            self.open.remove(tag)
            self.open.reverse()
            self.parts.append("</%s>" % tag)

    def result(self):
        return "".join(self.parts)


def sanitize(text):
    if len(text.encode("utf-8")) > MAX_HTML:
        raise Reject("HTML size exceeds %d bytes" % MAX_HTML)
    s = Sanitizer()
    s.feed(text)
    out = s.result()
    if re.search(r"<\s*(script|iframe|object|embed|form|svg|style)\b", out, re.I):
        raise Reject("a forbidden tag remained after cleanup")
    if re.search(r"on\w+\s*=", out, re.I) or re.search(r"javascript:", out, re.I):
        raise Reject("an event handler or javascript: remained")
    return out


_SECTION = re.compile(r"\{\{#([A-Z0-9_]+)\}\}(.*?)\{\{/\1\}\}", re.S)
_VAR = re.compile(r"\{\{([A-Z0-9_]+)\}\}")


def render(template, values):
    def expand(text):
        def section(m):
            name, body = m.group(1), m.group(2)
            val = values.get(name, "")
            if val in ("", None, False, "0", 0):
                return ""
            return expand(body)
        text = _SECTION.sub(section, text)
        text = _VAR.sub(lambda m: html.escape(str(values.get(m.group(1), "")), quote=True), text)
        return text
    return expand(template)


_IMG = re.compile(r"<img\b[^>]*>", re.I)
_TAG = re.compile(r"<[^>]+>")
_LINK = re.compile(r'<a\b[^>]*href="([^"]*)"[^>]*>(.*?)</a>', re.I | re.S)
_BR = re.compile(r"<\s*br\s*/?>", re.I)
_BLOCK = re.compile(r"</\s*(p|div|tr|table|h[1-4]|li)\s*>", re.I)


def totext(source):
    def repl_link(m):
        href, label = m.group(1), re.sub(_TAG, "", m.group(2)).strip()
        if label and href and label != href:
            return "%s (%s)" % (label, href)
        return label or href

    def repl_img(m):
        m2 = re.search(r'alt="([^"]*)"', m.group(0), re.I)
        return ("[%s]" % m2.group(1)) if m2 and m2.group(1) else ""

    t = _LINK.sub(repl_link, source)
    t = _IMG.sub(repl_img, t)
    t = _BR.sub("\n", t)
    t = _BLOCK.sub("\n", t)
    t = _TAG.sub("", t)
    t = html.unescape(t)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def inspect_image(path):
    with open(path, "rb") as fh:
        head = fh.read(32)
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", head[16:24])
        return w, h, "png"
    if head[:3] == b"GIF":
        w, h = struct.unpack("<HH", head[6:10])
        return w, h, "gif"
    if head[:2] == b"\xff\xd8":
        with open(path, "rb") as fh:
            data = fh.read()
        i = 2
        while i < len(data) - 9:
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3):
                h, w = struct.unpack(">HH", data[i + 5 : i + 9])
                return w, h, "jpg"
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            seglen = struct.unpack(">H", data[i + 2 : i + 4])[0]
            i += 2 + seglen
        raise Reject("corrupt JPEG (no SOF header)")
    if path.lower().endswith(".svg") or head.lstrip()[:5] == b"<svg ":
        raise Reject("SVG rejected")
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        raise Reject("WebP rejected")
    raise Reject("unsupported image type")


def _check_image_policy(path, kind="logo"):
    import os
    size = os.path.getsize(path)
    if size > MAX_IMAGE:
        raise Reject("image size %d bytes exceeds the limit %d" % (size, MAX_IMAGE))
    w, h, typ = inspect_image(path)
    if kind == "banner" and w > 600:
        raise Reject("banner width %d exceeds 600px" % w)
    if kind == "logo" and (w > 400 or h > 160):
        raise Reject("logo %dx%d exceeds 400x160 (a 2x version is displayed at half dimensions)" % (w, h))
    return w, h, typ


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]
    try:
        if cmd == "sanitize":
            src = sys.stdin.read() if argv[2] == "-" else open(argv[2], encoding="utf-8").read()
            out = sanitize(src)
            if len(argv) >= 4:
                with open(argv[3], "w", encoding="utf-8") as fh:
                    fh.write(out)
            else:
                sys.stdout.write(out)
            if len(out.encode("utf-8")) > WARN_HTML:
                sys.stderr.write("WARN: signature size is near the limit (%.1fKB)\n" % (len(out) / 1024))
            return 0

        if cmd == "render":
            tpl = open(argv[2], encoding="utf-8").read()
            values = {}
            i = 3
            out_html = None
            out_txt = None
            while i < len(argv):
                if argv[i] == "--txt":
                    out_txt = argv[i + 1]; i += 2
                elif argv[i] == "--set":
                    k, _, v = argv[i + 1].partition("=")
                    values[k] = v; i += 2
                else:
                    out_html = argv[i]; i += 1
            rendered = render(tpl, values)
            if out_html:
                with open(out_html, "w", encoding="utf-8") as fh:
                    fh.write(rendered)
            else:
                sys.stdout.write(rendered)
            if out_txt:
                with open(out_txt, "w", encoding="utf-8") as fh:
                    fh.write(totext(rendered))
            return 0

        if cmd == "totext":
            src = sys.stdin.read() if argv[2] == "-" else open(argv[2], encoding="utf-8").read()
            sys.stdout.write(totext(src))
            return 0

        if cmd == "inspect-image":
            kind = "logo"
            if len(argv) >= 4 and argv[3] in ("logo", "banner"):
                kind = argv[3]
            w, h, typ = _check_image_policy(argv[2], kind)
            print("%dx%d %s" % (w, h, typ))
            return 0

        print("unknown command: %s" % cmd, file=sys.stderr)
        return 1
    except Reject as exc:
        print("REJECT: %s" % exc, file=sys.stderr)
        return 2
    except FileNotFoundError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))