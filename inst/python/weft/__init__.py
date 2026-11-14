"""weft: checks and named values for prose that quotes numbers.

    from weft import claim
    claim(n, "> 10")

Under a weft knit (R's knitr running this Python by reticulate) R loads this
package from its own copy, registers it as `weft`, and attaches the function
forms of rule G19 (fmt_num() and the rest) and the knitr back end. Installed
with pip it is the same code (rule N60).
"""

import collections.abc as _abc
import os as _os
import re as _re
import sys as _sys
import types as _types
import warnings as _warnings

from . import _backend
from . import _record

__weft_package__ = True

_OPERATORS = ("<=", ">=", "==", "!=", "<", ">")

_E50 = "claim() needs at least one check."
_E51 = 'a check is a string, such as "> 10" or "_ % 2 == 0".'
_E54 = 'level is "fail" or "warn".'


class WeftError(Exception):
    """Base of weft's exceptions."""


class ClaimFailed(WeftError, AssertionError):
    """A claim at level "fail" had a failed check."""


class PublishError(WeftError, TypeError):
    """A value that cannot be published by name."""


def _text(x):
    """x as `.val` prints it (rule N8)."""
    r = _record.classify(x)
    t = r["t"]
    if t == "bool":
        return "true" if r["v"] else "false"
    if t == "list":
        return ", ".join(_one(e) for e in r["v"])
    if t == "error":
        s = repr(x)
        return s if len(s) <= 80 else s[:77] + "..."
    return _one(r)


def _one(r):
    if r["t"] == "bool":
        return "true" if r["v"] else "false"
    if r["t"] == "missing":
        return r["why"]
    return str(r["v"])


def _is_bool(r):
    if isinstance(r, bool):
        return True
    np = _sys.modules.get("numpy")
    return np is not None and isinstance(r, np.bool_)


def _type_name(x):
    t = type(x)
    n = t.__module__ + "." + t.__qualname__
    return n[len("builtins."):] if n.startswith("builtins.") else n


def claim(x, *checks, level="fail"):
    """Check the value `x`; return it unchanged when every check passes.

    A check is a string. One that starts with <, <=, >, >=, == or != is read as
    `_ ` followed by it: claim(n, "> 10") checks `_ > 10`. Any other string is a
    Python expression in which `_` is the value: claim(n, "_ % 2 == 0"). It
    sees the caller's globals and locals.

    A failed check at level "fail" is recorded, then raises ClaimFailed. At
    level "warn" it is recorded as a warned check and nothing is raised.
    """
    if not checks:
        raise TypeError(_E50)
    for c in checks:
        if not isinstance(c, str):
            raise TypeError(_E51)
    if not (isinstance(level, str) and level in ("fail", "warn")):
        raise ValueError(_E54)

    frame = _sys._getframe(1)
    ns = dict(frame.f_globals)
    ns.update(frame.f_locals)
    ns["_"] = x
    del frame

    val = None
    failed = []
    for c in checks:
        stripped = c.lstrip(" ")
        shown = c
        src = c
        if stripped.startswith(_OPERATORS):
            src = "_ " + stripped
            shown = src
        why = None
        try:
            r = eval(src, ns)
            ok = _is_bool(r)
        except Exception as e:
            ok = False
            r = None
            why = "%s: %s" % (type(e).__name__, e)
        if ok and r:
            continue
        if val is None:
            val = _text(x)
        if why is not None or not ok:
            if why is None:
                detail = "%s gave a %s, not True or False" % (shown, _type_name(r))
            else:
                detail = "%s was false (value %s); %s" % (shown, val, why)
        else:
            detail = "%s was false (value %s)" % (shown, val)
        if why is None and not ok:
            why_field = "gave a %s, not True or False" % _type_name(r)
        else:
            why_field = why
        failed.append({"text": shown, "why": why_field, "detail": detail})
    if not failed:
        return x

    expr = "claim(" + chr(0x2026) + ", " +", ".join(repr(c) for c in checks) + ")"
    recorded = _backend.report(level, expr, failed, _record.classify(x))
    message = "weft: a claim failed: " + failed[0]["detail"] + "."
    if level == "fail":
        if recorded == "collected":
            return x
        raise ClaimFailed(message)
    if not recorded:
        _warnings.warn(message, UserWarning, stacklevel=2)
    return x


_E41 = ("`%s` is not a name weft can publish: ASCII letters, digits, _ and ., starting with a "
        "letter or _ (rule 1.12.1).")
_E42 = "`%s` is a list of %d elements; weft publishes at most 10000 (rule 2.13.1)."
_E59 = "auto() works in a Jupyter kernel or a weft knit."
_E60 = 'auto() cannot read the document %s; give it: auto("doc.qmd").'


def put(*maps, **named):
    """Publish values by name: put(depth=3.2) or put({"depth": 3.2}).

    Each keyword, and each key of a mapping given positionally, is published
    under that name. Nothing is published when one of them is not a NAME or is a
    list of more than 10000 elements (PublishError). Returns None.
    """
    pairs = []
    for m in maps:
        if not isinstance(m, _abc.Mapping):
            raise PublishError("put() takes keywords or mappings: put(n=3) or put({'n': 3}).")
        pairs.extend(m.items())
    pairs.extend(named.items())
    values = {}
    for k, v in pairs:
        if not _backend.is_name(k):
            raise PublishError(_E41 % (k,))
        rec, n = _backend.record_of(v)
        if rec is None:
            raise PublishError(_E42 % (k, n))
        values[k] = rec
    _backend.publish(values)
    return None


# ---- auto() (N45, N71) ------------------------------------------------------------------------

_auto = {"callback": None, "names": [], "last": {}}

_GOV_RE = _re.compile(r'(?<![A-Za-z0-9_.-])(?i:n|if|sign|list)="([^"]*)"')
_TOKEN_RE = _re.compile(r"(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_.]*")
_CODE_RE = _re.compile(r"`([A-Za-z_][A-Za-z0-9_.]{0,63})`\{")
_INCLUDE_RE = _re.compile(r"\{\{<\s*include\s+([^>\s]+)\s*>\}\}")


def _source_names(path):
    """The names a source names (N45): its code spans and governors, and its includes (8 deep)."""
    seen = set()
    found = []
    found_code = []

    def walk(p, depth):
        p = _os.path.abspath(p)
        if p in seen or not _os.path.isfile(p):
            return
        seen.add(p)
        try:
            with open(p, encoding="utf-8", errors="replace") as fh:
                txt = fh.read()
        except OSError:
            return
        found_code.extend(_CODE_RE.findall(txt))
        found.extend(_CODE_RE.findall(txt))
        for g in _GOV_RE.findall(txt):
            found.extend(_TOKEN_RE.findall(_re.sub(r"'[^']*'", " ", g)))
        if depth < 8 and "{{<" in txt:
            for inc in _INCLUDE_RE.findall(txt):
                inc = inc.strip("\"'")
                walk(_os.path.join(_os.path.dirname(p), inc), depth + 1)

    walk(path, 0)
    # a document with no named value (a code span with a name) publishes nothing by itself (N43)
    if not any(_backend.is_name(n) for n in found_code):
        return []
    out = []
    for n in found:
        if _backend.is_name(n) and n not in out:
            out.append(n)
    return out


def _is_code(v):
    return isinstance(v, (_types.ModuleType, _types.FunctionType, _types.BuiltinFunctionType,
                          _types.MethodType, type))


def _changes(names):
    """{name: wire record} for each of `names` bound in __main__ whose record changed since the last call.

    A name that is a module, function or class, or starts with an underscore, is left. A list of more than
    10000 elements raises PublishError (E42), as put() does, and nothing is recorded as published."""
    main = _sys.modules["__main__"].__dict__
    changed = {}
    texts = {}
    for n in names:
        if n.startswith("_") or n not in main:
            continue
        v = main[n]
        if _is_code(v):
            continue
        rec, k = _backend.record_of(v)
        if rec is None:
            raise PublishError(_E42 % (n, k))
        text = _backend.dumps(rec)
        if _auto["last"].get(n) != text:
            texts[n] = text
            changed[n] = rec
    _auto["last"].update(texts)
    return changed


def _publish_changes(*_args):
    """The post_run_cell callback of auto(): publish the changed names in one block.

    A PublishError (E42) is raised out of the callback, which IPython reports as the cell's error output."""
    try:
        changed = _changes(_auto["names"])
    except PublishError:
        raise
    except Exception as e:  # never break a cell from a callback
        _sys.stderr.write("weft: auto() could not publish: %s: %s\n" % (type(e).__name__, e))
        return
    if changed:
        try:
            _backend.publish(changed)
        except Exception as e:
            _sys.stderr.write("weft: auto() could not publish: %s: %s\n" % (type(e).__name__, e))


def _knitr_changes(names):
    """Under knitr, R asks (at each block of prose) which of `names` changed in __main__ since last asked:
    a dict {name: the record's JSON text}. Empty unless auto() was called in the knit (N71)."""
    if not _backend.auto_main:
        return {}
    names = [n for n in names if _backend.is_name(n)]
    return {n: _backend.dumps(r) for n, r in _changes(names).items()}


def auto(path=None):
    """Publish, after each cell, the names the document uses.

    In a Jupyter kernel: registers one post_run_cell callback (a second call
    replaces it) that publishes, in one block, each top-level name of __main__
    that the source names, that is not a module, function or class, and whose
    value changed. `path` is the source; by default QUARTO_DOCUMENT_PATH joined
    to QUARTO_DOCUMENT_FILE. Returns the path used.
    """
    k = _backend.kind()
    if k == "none":
        raise WeftError(_E59)
    if path is None:
        d = _os.environ.get("QUARTO_DOCUMENT_PATH", "")
        f = _os.environ.get("QUARTO_DOCUMENT_FILE", "")
        path = _os.path.join(d, f) if (d and f) else None
    else:
        path = _os.fspath(path)
    if k == "knitr":
        _backend.auto_main = True
        return path
    if path is None:
        raise WeftError(_E60 % "(QUARTO_DOCUMENT_PATH and QUARTO_DOCUMENT_FILE are not set)")
    try:
        with open(path, "rb") as fh:
            fh.read(1)
    except OSError:
        raise WeftError(_E60 % path)
    ip = _backend._ipython()
    old = _auto["callback"]
    if old is not None:
        try:
            ip.events.unregister("post_run_cell", old)
        except Exception:
            pass
    _auto["names"] = _source_names(path)
    _auto["last"] = {}
    _auto["callback"] = _publish_changes
    ip.events.register("post_run_cell", _publish_changes)
    return path
