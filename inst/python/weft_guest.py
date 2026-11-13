"""weft's reader of Python values and its recorders (rules 1.11 and 2.12 of the
spec).

It runs inside Python, so nothing passes through reticulate's conversion: a
value is classified by its Python type and handed to R as JSON text, a typed
record. R turns the record into an R value (R/guest.R, record_value()).

The classifier itself is the package's: weft/_record.py (rule N60), so that
weft.claim() and this reader make one record. It is used from the package
`weft` when R has registered it (or pip installed it), and else loaded from the
file beside this one. See that file for the shape of a record.

Nothing here assigns a name in __main__, imports numpy or pandas (they are
used only when the author already imported them), or raises: a value that
cannot be read is an error record.
"""

import collections.abc as _abc
import json as _json
import sys as _sys


def _load_record():
    pkg = _sys.modules.get("weft")
    rec = getattr(pkg, "_record", None) if getattr(pkg, "__weft_package__", False) else None
    if rec is not None:
        return rec
    import importlib.util as _iu
    import os as _os
    path = _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "weft", "_record.py")
    spec = _iu.spec_from_file_location("_weft_record", path)
    mod = _iu.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_record = _load_record()
classify = _record.classify
classify_json = _record.classify_json




def read(steps):
    """The record of the value at a path from __main__, as JSON text.

    The first step is a name in __main__; each later step is a key when the
    object so far is a mapping, else an attribute. A step that is not there
    gives {"t": "absent", "at": <index of the step>}.
    """
    main = _sys.modules.get("__main__")
    obj = None
    for i, name in enumerate(steps):
        try:
            if i == 0:
                d = vars(main)
                if name not in d:
                    return _json.dumps({"t": "absent", "at": 0})
                obj = d[name]
            elif isinstance(obj, _abc.Mapping):
                obj = obj[name]
            else:
                obj = getattr(obj, name)
        except Exception:
            return _json.dumps({"t": "absent", "at": i})
    return classify_json(obj)


# ---- the warning recorder (G25) ----------------------------------------------

import warnings as _warnings

_warnings_seen = []
_orig_showwarning = None


def _show(message, category, filename, lineno, file=None, line=None):
    try:
        _warnings_seen.append(category.__name__ + ": " + str(message))
    except Exception:
        pass
    return _orig_showwarning(message, category, filename, lineno, file, line)


def install_recorder():
    """Wrap warnings.showwarning once: each warning is noted, then shown as before."""
    global _orig_showwarning
    if _warnings.showwarning is _show:
        return
    _orig_showwarning = _warnings.showwarning
    _warnings.showwarning = _show


def drain_warnings():
    """The warnings noted since the last call, as JSON text; the note is cleared."""
    out = _json.dumps(_warnings_seen)
    del _warnings_seen[:]
    return out


# ---- the project's modules (G30) -------------------------------------------------

import os as _os

_SKIP_DIRS = {"site-packages", "dist-packages", ".venv", "venv", "renv"}


def project_modules(root):
    """Paths, relative to root and with /, of the loaded modules whose file lies
    in the project, as JSON text. A module under a folder named site-packages,
    dist-packages, .venv, venv, renv, or starting with a dot, is not one."""
    out = set()
    try:
        real_root = _os.path.realpath(root)
    except Exception:
        return _json.dumps([])
    for mod in list(_sys.modules.values()):
        try:
            f = mod.__dict__.get("__file__")
            if not isinstance(f, str):
                continue
            rel = _os.path.relpath(_os.path.realpath(f), real_root)
        except Exception:
            continue
        if rel.startswith("..") or _os.path.isabs(rel):
            continue
        parts = rel.split(_os.sep)
        if any(d in _SKIP_DIRS or d.startswith(".") for d in parts[:-1]):
            continue
        out.add("/".join(parts))
    return _json.dumps(sorted(out))
