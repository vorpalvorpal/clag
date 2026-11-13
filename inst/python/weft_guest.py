"""weft's reader of Python values (rules 1.11 and 2.12 of the spec).

It runs inside Python, so nothing passes through reticulate's conversion: a
value is classified by its Python type and handed to R as JSON text, a typed
record. R turns the record into an R value (R/guest.R, record_value()).

A record is a dict with the keys t, v, why, of, keys and type:

  t     bool, int, float, decimal, string, date, list, missing or error
  v     bool: True or False; int: the digit string; float: the shortest text
        that reads back as the same double; decimal: str() of the Decimal;
        string: the text; date: ISO; list: a list of scalar records;
        missing, error: None
  why   missing and error only: the reason; for an error, the refusal message
        with the subject written as the literal text {S}
  of    lists only: the kind of the elements after the promotions
  keys  lists from a mapping only: the keys
  type  Python's type name: type(x).__module__ and __qualname__, with a
        leading "builtins." removed

Nothing here assigns a name in __main__, imports numpy or pandas (they are
used only when the author already imported them), or raises: a value that
cannot be read is an error record.
"""

import collections.abc as _abc
import datetime as _datetime
import decimal as _decimal
import json as _json
import math as _math
import sys as _sys

_KIND = {"int": "integer", "float": "float", "decimal": "decimal",
         "bool": "bool", "string": "string", "date": "date"}


def _np():
    return _sys.modules.get("numpy")


def _pd():
    return _sys.modules.get("pandas")


def _tname(x):
    t = type(x)
    n = t.__module__ + "." + t.__qualname__
    return n[len("builtins."):] if n.startswith("builtins.") else n


def _rec(t, v=None, why=None, type_=None):
    return {"t": t, "v": v, "why": why, "of": None, "keys": None, "type": type_}


def _missing(why, x):
    return _rec("missing", None, why, _tname(x))


def _error(why, type_):
    return _rec("error", None, why, type_)


def _refuse6(x):
    t = _tname(x)
    return _error("{S} is a Python " + t + ", which weft does not read as a value. "
                  "Bind a bool, int, float, Decimal, str, date, or a list of one of "
                  "these (rule 1.11.1).", t)


def _digits(i):
    try:
        return str(i)
    except ValueError:  # beyond Python's limit on digits in a string
        return "of %d bits" % i.bit_length()


def _scalar(x):
    """The record of a value that is not a list, a mapping or an array."""
    if x is None:
        return _missing("None", x)
    pd = _pd()
    if pd is not None:
        if x is pd.NA:
            return _missing("pandas.NA", x)
        if x is pd.NaT:
            return _missing("pandas.NaT", x)
    np = _np()
    if isinstance(x, bool) or (np is not None and isinstance(x, np.bool_)):
        return _rec("bool", bool(x), None, _tname(x))
    if isinstance(x, int) or (np is not None and isinstance(x, np.integer)):
        return _rec("int", _digits(int(x)), None, _tname(x))
    if isinstance(x, float) or (np is not None and isinstance(x, np.floating)):
        f = float(x)
        if _math.isnan(f):
            return _missing("a float NaN", x)
        if _math.isinf(f):
            return _missing("a float infinity", x)
        return _rec("float", repr(f), None, _tname(x))
    if isinstance(x, _decimal.Decimal):
        if not x.is_finite():
            return _missing("a Decimal NaN or infinity", x)
        return _rec("decimal", str(x), None, _tname(x))
    if isinstance(x, str):
        s = str.__str__(x)
        try:
            s.encode("utf-8")
        except UnicodeEncodeError:
            t = _tname(x)
            return _error("{S} is a Python " + t + " that holds characters that are not "
                          "text (a lone surrogate); weft reads text (rule 1.11.5).", t)
        return _rec("string", s, None, _tname(x))
    if np is not None and isinstance(x, np.datetime64):
        if np.isnat(x):
            return _missing("numpy NaT", x)
        if np.datetime_data(x.dtype)[0] == "D":
            return _rec("date", str(x), None, _tname(x))
        return _refuse5(x)
    if isinstance(x, _datetime.datetime):
        return _refuse5(x)
    if isinstance(x, _datetime.date):
        return _rec("date", x.isoformat(), None, _tname(x))
    return _refuse6(x)


def _refuse5(x):
    t = _tname(x)
    return _error("{S} is a Python " + t + ", which holds a date and a time; weft reads a "
                  "date. Convert it in Python, in the time zone you mean, with .date() "
                  "(rule 1.11.6).", t)


def _is_container(x):
    np, pd = _np(), _pd()
    return (isinstance(x, (list, tuple, set, frozenset, _abc.Mapping))
            or (np is not None and isinstance(x, np.ndarray))
            or (pd is not None and isinstance(x, pd.Series)))


def _list(items, container, keys):
    t = _tname(container)
    recs = []
    for i, el in enumerate(items):
        if _is_container(el):
            return _error("{S} is a Python " + t + " that holds a " + _tname(el) +
                          "; weft reads a flat list (rule 1.11.4).", t)
        r = _scalar(el)
        if r["t"] == "error":
            # say which element: "Element 2 of `py$x` is a Python complex, ..."
            r["why"] = "Element %d of {S}" % (i + 1) + r["why"][len("{S}"):]
        recs.append(r)
    for r in recs:
        if r["t"] == "error":
            return r
    kinds = []
    for r in recs:
        if r["t"] != "missing" and r["t"] not in kinds:
            kinds.append(r["t"])
    if len(kinds) <= 1:
        of = kinds[0] if kinds else "missing"
    elif set(kinds) == {"int", "float"}:
        of = "float"
    elif set(kinds) == {"int", "decimal"}:
        of = "decimal"
    else:
        return _error("{S} is a Python " + t + " whose elements are of more than one kind (" +
                      ", ".join(_KIND[k] for k in kinds) + "); weft reads a list whose "
                      "elements are all of one kind (rule 1.11.4).", t)
    out = _rec("list", recs, None, t)
    out["of"] = of
    out["keys"] = keys
    return out


def _classify(x):
    np, pd = _np(), _pd()
    if isinstance(x, (set, frozenset)):
        t = _tname(x)
        return _error("{S} is a Python " + t + ", which has no order. Bind sorted() of it "
                      "in a Python chunk (rule 1.11.4).", t)
    if np is not None and isinstance(x, np.ndarray):
        if x.ndim == 0:
            return _classify(x[()])
        if x.ndim >= 2:
            return _error("{S} is a numpy array of %d dimensions; weft reads a flat list "
                          "(rule 1.11.4)." % x.ndim, _tname(x))
        return _list(list(x), x, None)
    if pd is not None and isinstance(x, pd.Series):
        return _list(x.tolist(), x, None)
    if isinstance(x, _abc.Mapping):
        ks = list(x.keys())
        if not all(isinstance(k, str) for k in ks):
            t = _tname(x)
            return _error("{S} is a Python " + t + " whose keys are not all str "
                          "(rule 1.11.4).", t)
        return _list(list(x.values()), x, [str.__str__(k) for k in ks])
    if isinstance(x, (list, tuple)):
        return _list(list(x), x, None)
    return _scalar(x)


def classify(x):
    """The record of one Python value. Never raises."""
    try:
        return _classify(x)
    except Exception as e:  # a property, an iterator or a numpy call that failed
        t = _tname(x)
        return _error("{S} is a Python " + t + " that weft could not read (" +
                      type(e).__name__ + ")" + "; weft reads a bool, int, float, Decimal, "
                      "str, date, or a list of one of these (rule 1.11.1).", t)


def classify_json(x):
    """classify() as JSON text, for R."""
    return _json.dumps(classify(x))


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
