"""Where a claim, a published value or an auto-published name goes (rules N50 to N54, N70 to N73 of dev/design-6.md).

report(level, expr, failures, value) -> bool records the failed checks of one
claim() call and says whether it did. There are three back ends, chosen by
kind() each time (N73):

  knitr    R registered one with set_knitr(); it adds each outcome to the knit's
           failures (level "fail") or warned checks (level "warn"). put() hands
           its records to R's waiting names through set_knitr_put(), when R
           registered that.
  jupyter  an IPython shell with a kernel: one weft-values block (N20) is
           displayed, as markdown (N53, N70).
  none     plain Python (N54): report() returns False and the caller raises, or
           warns, by itself; put() prints the block's text to stdout.

This module also writes the block, its records (N22) and its run id (N48).
"""

import json as _json
import os as _os
import re as _re
import sys as _sys
import time as _time

from . import _config
from . import _record

_knitr = None
_knitr_put = None
auto_main = False  # under knitr, auto() asks the hooks to look in __main__ too (N71)

_NAME_RE = _re.compile(r"^[A-Za-z_][A-Za-z0-9_.]{0,63}\Z")
_RESERVED = frozenset(["TRUE", "FALSE", "True", "False", "true", "false", "NA",
                       "NULL", "None", "nothing", "missing", "Inf", "NaN"])
MAX_LIST = 10000


def set_knitr(fn):
    """Register (or, with None, remove) the knitr back end: R's callable."""
    global _knitr
    _knitr = fn


def set_knitr_put(fn):
    """Register (or, with None, remove) R's hand-over of records to its waiting names (N42)."""
    global _knitr_put
    _knitr_put = fn


def is_name(s):
    """True for a NAME (N6)."""
    return (isinstance(s, str) and _NAME_RE.match(s) is not None
            and not s.endswith(".") and s not in _RESERVED)


def _ipython():
    # IPython is never imported here: a kernel has imported it already
    mod = _sys.modules.get("IPython")
    if mod is None:
        return None
    try:
        return mod.get_ipython()
    except Exception:
        return None


def kind():
    """The back end now: "knitr", "jupyter" or "none" (N73)."""
    if _knitr is not None:
        return "knitr"
    ip = _ipython()
    if ip is not None and getattr(ip, "kernel", None) is not None:
        return "jupyter"
    return "none"


# ---- records on the wire (N22) ------------------------------------------------------------------

def wire(rec):
    """A classifier record as the carrier's record: no empty members, no host type."""
    t = rec["t"]
    out = {"t": t}
    if t == "list":
        out["v"] = [wire(e) for e in rec["v"]]
        out["of"] = rec["of"]
        out["keys"] = rec["keys"]
    elif t in ("missing", "error"):
        out["why"] = rec["why"]
    else:
        out["v"] = rec["v"]
    return out


def record_of(x):
    """(wire record, 0) of a value; (None, n) when it is a list of n > 10000 elements (E42)."""
    r = _record.classify(x)
    if r["t"] == "list" and len(r["v"]) > MAX_LIST:
        return None, len(r["v"])
    return wire(r), 0


def dumps(obj):
    return _json.dumps(obj, separators=(",", ":"), ensure_ascii=True)


# ---- run id and time (N48) ----------------------------------------------------------------------

def run_id():
    """First line of .weft/run found walking up from the document's folder (at most 8 levels), else
    WEFT_RUN when not empty, else None. Read at each call, never kept."""
    d = _os.environ.get("QUARTO_DOCUMENT_PATH", "") or _os.getcwd()
    d = _os.path.abspath(d)
    for _ in range(9):
        f = _os.path.join(d, ".weft", "run")
        if _os.path.isfile(f):
            try:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    line = fh.readline().rstrip("\r\n")
                if line.strip():
                    return line
            except OSError:
                pass
        up = _os.path.dirname(d)
        if up == d:
            break
        d = up
    e = _os.environ.get("WEFT_RUN", "")
    return e if e else None


def block_text(values, checks=None):
    """The fenced block (N20): four backticks, the JSON on one line."""
    obj = {"weft": 1, "lang": "python", "run": run_id(), "at": int(_time.time()), "values": values}
    if checks:
        obj["checks"] = checks
    return "````{.weft-values}\n" + dumps(obj) + "\n````"


def _show(text):
    """Display text as markdown in the kernel (N53, N70)."""
    from IPython.display import display, Markdown
    display(Markdown(text))


def publish(values):
    """Publish wire records by name through the back end that is active (N70)."""
    k = kind()
    if k == "knitr" and _knitr_put is not None:
        try:
            if _knitr_put({n: dumps(r) for n, r in values.items()}):
                return
        except Exception:
            pass
    if k == "jupyter":
        _show(block_text(values))
    else:
        print(block_text(values))


# ---- claims (N52, N53) --------------------------------------------------------------------------

def _collects():
    """True when a failed claim is collected in this Quarto kernel (GN2b, GN4): the kernel was started by
    a render (QUARTO_DOCUMENT_PATH is not empty) and `chunk_claims` is collect for the document. The files
    are read at each call."""
    folder = _os.environ.get("QUARTO_DOCUMENT_PATH", "")
    if not folder:
        return False
    name = _os.environ.get("QUARTO_DOCUMENT_FILE", "")
    source = _os.path.join(folder, name) if name else ""
    return _config.chunk_claims(source, folder) == "collect"


def report(level, expr, failures, value=None):
    """Record the failed checks of one claim() call. True when a back end did; the string
    "collected" when every callback for the claim said it collected the failure (G1, GN3).

    failures: list of dicts with text, why (or None) and detail. value: the
    classifier record of the value checked."""
    k = kind()
    if k == "knitr":
        try:
            ok = True
            collected = True
            for f in failures:
                r = _knitr(level, expr, f["detail"])
                ok = bool(r) and ok
                collected = collected and isinstance(r, str) and r == "collected"
            if ok and collected and failures:
                return "collected"
            return ok
        except Exception:
            return False
    if k == "jupyter":
        try:
            v = wire(value) if value is not None else None
            checks = [{"text": f["text"], "ok": False, "level": level, "why": f["why"],
                       "expr": expr, "value": v, "line": None} for f in failures]
            _show(block_text({}, checks))
            if level == "fail" and _collects():
                return "collected"
            return True
        except Exception:
            return False
    return False
