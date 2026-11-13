"""weft.py: a spike shim for the (c) study. It types values and formats nothing.

v(x)        an inline carrier: `{python} v(depth)`{.num}
claim(x, "_ > 10")   a checked value; the check's outcome rides in the carrier
put(a=..., b=...)    publish named values once; prose then says `a`{.num}
"""
import base64
import datetime
import decimal
import json
import math
import os
import time

from IPython.display import Markdown, display

_seq = 0


class Checked:
    def __init__(self, value, checks):
        self.value = value
        self.checks = checks


def claim(value, *checks, level="fail"):
    """Each check is a string in which `_` is the value. Never raises."""
    if not checks:
        raise TypeError("claim() needs at least one check")
    inner, done = value, []
    if isinstance(value, Checked):
        inner, done = value.value, list(value.checks)
    for c in checks:
        try:
            ok = eval(c, {"_": inner})
            ok = bool(ok) if isinstance(ok, bool) or type(ok).__name__ == "bool_" else None
            why = None if ok is not None else "the check did not give True or False"
        except Exception as e:  # a check that cannot be evaluated is a failed check
            ok, why = None, f"{type(e).__name__}: {e}"
        done.append({"text": c, "ok": ok is True, "why": why, "level": level})
    return Checked(inner, done)


def _typed(x):
    if isinstance(x, Checked):
        d = _typed(x.value)
        d["checks"] = x.checks
        return d
    if callable(x):  # a thunk: an error is carried, and fails only where it prints
        try:
            return _typed(x())
        except Exception as e:
            return {"t": "error", "why": f"{type(e).__name__}: {e}"}
    if x is None:
        return {"t": "missing", "why": "None"}
    tn = type(x).__name__
    if isinstance(x, bool) or tn == "bool_":
        return {"t": "bool", "v": bool(x)}
    if isinstance(x, int):
        return {"t": "int", "v": str(x)}
    if isinstance(x, float):
        if math.isnan(x) or math.isinf(x):
            return {"t": "missing", "why": repr(float(x))}
        return {"t": "float", "v": repr(float(x))}
    if isinstance(x, decimal.Decimal):
        if not x.is_finite():
            return {"t": "missing", "why": str(x)}
        return {"t": "dec", "v": format(x, "f")}
    if isinstance(x, str):
        return {"t": "str", "v": x}
    if isinstance(x, datetime.datetime):
        raise TypeError("weft: convert a datetime to a date, in a time zone you choose")
    if isinstance(x, datetime.date):
        return {"t": "date", "v": x.isoformat()}
    if isinstance(x, (list, tuple)):
        items = [_typed(i) for i in x]
        kinds = {i["t"] for i in items} - {"missing"}
        if len(kinds) > 1 and kinds != {"int", "float"}:
            raise TypeError(f"weft: a list must hold one type, not {sorted(kinds)}")
        return {"t": "list", "v": items}
    raise TypeError(f"weft: cannot carry a value of type {type(x).__name__}; convert it first")


def _stamp(d):
    d["run"] = os.environ.get("WEFT_RUN")
    d["at"] = int(time.time())
    return d


def v(x):
    """An inline carrier. Returns markdown: a code span holding an attribute-safe token."""
    global _seq
    _seq += 1
    d = _stamp(_typed(x))
    d["seq"] = _seq
    raw = json.dumps(d, separators=(",", ":")).encode()
    return Markdown("`wv1:" + base64.urlsafe_b64encode(raw).decode().rstrip("=") + "`")


def put(**named):
    """Publish named values as one data block in the cell's output."""
    block = _stamp({"values": {k: _typed(x) for k, x in named.items()}})
    display(Markdown("\n````{.weft-values}\n" + json.dumps(block, separators=(",", ":")) + "\n````\n"))


# ---- publish without a registration line ---------------------------------------
# auto(): after every cell, publish each top-level variable the prose refers to by name
# (a code span with an attribute block, or the value of n, if, sign or list), when it
# has changed. The names come from the source file; a name missed here fails loudly in
# the filter, and a name too many costs a few bytes.
import re

_last = {}


def _referenced(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    names = set(re.findall(r"`([A-Za-z_]\w*)`\{", text))
    for val in re.findall(r"\b(?:n|if|sign|list)=\"([^\"]*)\"", text):
        names.update(re.findall(r"[A-Za-z_]\w*", re.sub(r"'[^']*'", "", val)))
    return names


def auto(path=None):
    ip = get_ipython()  # noqa: F821
    if path is None:
        d, f = os.environ.get("QUARTO_DOCUMENT_PATH"), os.environ.get("QUARTO_DOCUMENT_FILE")
        path = os.path.join(d, f) if d and f else None
    _last.clear()

    def publish(result=None):
        names = _referenced(path) if path else None
        out = {}
        for k, x in ip.user_ns.items():
            if k.startswith("_") or (names is not None and k not in names):
                continue
            try:
                t = _typed(x) if not callable(x) else None
            except TypeError:
                continue
            if t is not None and _last.get(k) != t:
                out[k] = _last[k] = t
        if out:
            block = _stamp({"values": out})
            display(Markdown("\n````{.weft-values}\n" + json.dumps(block, separators=(",", ":")) + "\n````\n"))

    for old in list(ip.events.callbacks["post_run_cell"]):
        if getattr(old, "_weft", False):
            ip.events.unregister("post_run_cell", old)
    publish._weft = True
    ip.events.register("post_run_cell", publish)
    return path
