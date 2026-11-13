"""weft: checks and named values for prose that quotes numbers.

    from weft import claim
    claim(n, "> 10")

Under a weft knit (R's knitr running this Python by reticulate) R loads this
package from its own copy, registers it as `weft`, and attaches the function
forms of rule G19 (fmt_num() and the rest) and the knitr back end. Installed
with pip it is the same code (rule N60).
"""

import sys as _sys
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
        failed.append(detail)
    if not failed:
        return x

    expr = "claim(…, " + ", ".join(repr(c) for c in checks) + ")"
    recorded = True
    for detail in failed:
        recorded = _backend.report(level, expr, detail) and recorded
    message = "weft: a claim failed: " + failed[0] + "."
    if level == "fail":
        raise ClaimFailed(message)
    if not recorded:
        _warnings.warn(message, UserWarning, stacklevel=2)
    return x


def put(*args, **kwargs):
    """Publish values by name (package 6e)."""
    raise WeftError("put() is not available in this version of weft.")


def auto(*args, **kwargs):
    """Publish the names a document uses (package 6e)."""
    raise WeftError("auto() is not available in this version of weft.")
