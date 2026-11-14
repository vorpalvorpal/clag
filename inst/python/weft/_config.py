"""The setting `chunk_claims`, read by the guest at a failed claim (GN4 of dev/design-8.md).

chunk_claims(source, folder) -> "collect" or "stop". The files are read at each call and nothing is
kept: a kernel's environment can go stale, and the files cannot. Standard library only.

  _weft.yml  the first one found in `folder` or up to 8 parents. The first line that starts at
             column 1 with `chunk_claims`, optional spaces or tabs, then `:`. The value is the rest
             of the line, a `#` comment that follows white space removed, trimmed, and one pair of
             surrounding quotes removed.
  document   when `source` ends .qmd or .md: its front matter (from a first line of `---` to the next
             `---` or `...`), the key `chunk_claims` of its `weft:` mapping, in block or flow form.
             The document's value, when it has one, wins over _weft.yml.

The result is "collect" exactly when the value that applies is `collect`; anything else, an absent
key, `Collect`, `true` or an empty value, is "stop".
"""

import os as _os
import re as _re

_KEY = _re.compile(r"^chunk_claims[ \t]*:(.*)$")
_BLOCK_KEY = _re.compile(r"^chunk_claims[ \t]*:(.*)$")
_COMMENT = _re.compile(r"(?:^|\s)#")


def _lines(path):
    """The lines of a file, CR LF read as LF; None when it cannot be read."""
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except OSError:
        return None
    text = raw.decode("utf-8", "replace")
    if text.startswith(chr(0xFEFF)):
        text = text[1:]
    return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")


def _clean(rest):
    """A value as the rest of its line: comment out, trimmed, one pair of quotes off."""
    m = _COMMENT.search(rest)
    if m:
        rest = rest[:m.start()]
    rest = rest.strip(" \t")
    if len(rest) >= 2 and rest[0] == rest[-1] and rest[0] in "\"'":
        rest = rest[1:-1]
    return rest


def _yml_value(folder):
    d = _os.path.abspath(folder) if folder else _os.getcwd()
    for _ in range(9):
        f = _os.path.join(d, "_weft.yml")
        if _os.path.isfile(f):
            lines = _lines(f)
            if lines is None:
                return None
            for line in lines:
                m = _KEY.match(line)
                if m:
                    return _clean(m.group(1))
            return None
        up = _os.path.dirname(d)
        if up == d:
            break
        d = up
    return None


def _split_flow(text):
    """The top-level `key: value` items of a flow mapping `{...}` as (key, rest) pairs."""
    items = []
    depth = 0
    quote = None
    cur = []
    for ch in text:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            cur.append(ch)
        elif ch in "{[":
            depth += 1
            if depth > 1:
                cur.append(ch)
        elif ch in "}]":
            depth -= 1
            if depth >= 1:
                cur.append(ch)
            if depth <= 0:
                break
        elif ch == "," and depth == 1:
            items.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    items.append("".join(cur))
    out = []
    for it in items:
        k, sep, v = _partition_colon(it)
        if sep:
            out.append((k, v))
    return out


def _partition_colon(item):
    """Split at the first colon that is outside quotes: (key, ':', rest)."""
    quote = None
    for i, ch in enumerate(item):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == ":":
            return item[:i], ":", item[i + 1:]
    return item, "", ""


def _balanced(text):
    depth = 0
    quote = None
    seen = False
    for ch in text:
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch in "{[":
            depth += 1
            seen = True
        elif ch in "}]":
            depth -= 1
    return seen and depth <= 0


def _strip_comment(s):
    m = _COMMENT.search(s)
    return s[:m.start()] if m else s


def _front_value(source):
    lines = _lines(source)
    if not lines or lines[0].rstrip(" \t") != "---":
        return None
    end = None
    for i in range(1, len(lines)):
        if lines[i].rstrip(" \t") in ("---", "..."):
            end = i
            break
    if end is None:
        return None
    front = lines[1:end]
    for i, line in enumerate(front):
        m = _re.match(r"^weft[ \t]*:(.*)$", line)
        if not m:
            continue
        rest = _strip_comment(m.group(1)).strip(" \t")
        if rest.startswith("{"):
            text = rest
            j = i + 1
            while not _balanced(text) and j < len(front):
                text += " " + _strip_comment(front[j]).strip(" \t")
                j += 1
            for k, v in _split_flow(text):
                if _clean(k) == "chunk_claims":
                    return _clean(v)
            return None
        indent = None
        for line2 in front[i + 1:]:
            if not line2.strip(" \t"):
                continue
            ind = len(line2) - len(line2.lstrip(" \t"))
            if ind == 0:
                break
            if indent is None:
                indent = ind
            if ind == indent:
                m2 = _BLOCK_KEY.match(line2[ind:])
                if m2:
                    return _clean(m2.group(1))
        return None
    return None


def chunk_claims(source, folder):
    """"collect" when `chunk_claims` is collect for the document `source` in `folder`, else "stop"."""
    try:
        v = None
        if source and str(source).lower().endswith((".qmd", ".md")):
            v = _front_value(str(source))
        if v is None:
            v = _yml_value(folder)
        return "collect" if v == "collect" else "stop"
    except Exception:
        return "stop"
