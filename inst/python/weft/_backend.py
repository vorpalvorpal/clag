"""Where a failed or warned claim is recorded (rules N51 to N54 of dev/design-6.md).

A back end is a callable report(level, expr, detail) -> bool that records one
check outcome and says whether it did. Today there is one, the knitr back end:
under a weft knit R registers a callable with set_knitr(), which adds the
outcome to the knit's failures (level "fail") or warned checks (level "warn").
The Jupyter back end (N53) is added beside it by the package for Jupyter.

With no back end that recorded the outcome (plain Python, N54, or R's knit is
not running), report() returns False and the caller raises, or warns, by itself.
"""

_knitr = None


def set_knitr(fn):
    """Register (or, with None, remove) the knitr back end: R's callable."""
    global _knitr
    _knitr = fn


def report(level, expr, detail):
    """Record one outcome with the back end that is active. True when one did."""
    if _knitr is not None:
        try:
            return bool(_knitr(level, expr, detail))
        except Exception:
            return False
    return False
