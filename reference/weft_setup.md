# Activate weft for a document

Installs the knitr hooks that resolve weft's constructs in prose, log
the conditions chunks raise, and check, at the end of the document, that
everything was evaluated (rules 2.1, 9.2). Call it from a setup chunk,
from the document's front matter
(`knitr: opts_knit: weft: !expr weft::weft_setup()`) or from a project's
`.Rprofile`. Attaching the package installs nothing (rule 2.1.3).

## Usage

``` r
weft_setup()
```

## Value

`TRUE`, invisibly.

## Details

Each hook wraps the hook installed before it and calls it (rule 2.1.2).
Installing is idempotent, and works whether or not a knit is in
progress; a call made while a knit is running changes none of that
knit's state.

## Examples

``` r
if (FALSE) { # \dontrun{
weft::weft_setup()
} # }
```
