# Print the agent documents of the installed package

With no `topic`, prints the topics, one per line. With a topic
(`"skill"`, `"syntax"` or `"reports"`), prints that document as the
installed package ships it, without its marker line. The copies
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
writes into a project can be older than the package; this prints the
version that matches the installed code. Nothing is written.

## Usage

``` r
agent_docs(topic = NULL)
```

## Arguments

- topic:

  `NULL`, or one of `"skill"`, `"syntax"`, `"reports"`.

## Value

The text as a character vector of lines, invisibly (the topics when
`topic` is `NULL`).

## Details

The text has the installed package's version in the `skill` front
matter, where
[`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
writes the same version into a copy.
