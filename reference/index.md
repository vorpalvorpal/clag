# Package index

## Activating weft

- [`weft_setup()`](https://vorpalvorpal.github.io/weft/reference/weft_setup.md)
  : Activate weft for a document

## Values in prose

Format computed values, with or without units.

- [`fmt_num()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_pct()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_sci()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_no()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_word()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_count()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_ord()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_and()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_or()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_p()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_date()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_range()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_pairs()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_ul()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_ol()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_dl()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_cap()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_a()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_strong()`](https://vorpalvorpal.github.io/weft/reference/fmt.md)
  [`fmt_em()`](https://vorpalvorpal.github.io/weft/reference/fmt.md) :
  Formatter functions
- [`fmt_unit()`](https://vorpalvorpal.github.io/weft/reference/fmt_unit.md)
  : Print a unit alone
- [`u()`](https://vorpalvorpal.github.io/weft/reference/u.md) : A number
  with a unit
- [`unit_defaults()`](https://vorpalvorpal.github.io/weft/reference/unit_defaults.md)
  : The default units weft registers
- [`weft_str()`](https://vorpalvorpal.github.io/weft/reference/weft_str.md)
  : Resolve markup in a string
- [`glue_vec()`](https://vorpalvorpal.github.io/weft/reference/glue_vec.md)
  : Join items into a phrase
- [`py_value()`](https://vorpalvorpal.github.io/weft/reference/py_value.md)
  : Read a Python value
- [`jl_value()`](https://vorpalvorpal.github.io/weft/reference/jl_value.md)
  : Read a Julia value

## Values by name

Publish values under names, for prose that refers to them by name.

- [`weft_put()`](https://vorpalvorpal.github.io/weft/reference/weft_put.md)
  : Publish values by name
- [`weft_values_write()`](https://vorpalvorpal.github.io/weft/reference/weft_values_write.md)
  : Write a values file

## Wording that depends on values

- [`plural()`](https://vorpalvorpal.github.io/weft/reference/plural.md)
  : Choose a plural form
- [`lookup()`](https://vorpalvorpal.github.io/weft/reference/lookup.md)
  [`brk()`](https://vorpalvorpal.github.io/weft/reference/lookup.md) :
  Phrases chosen by key or by range
- [`of_n()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  [`about()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  [`ci()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  [`pm()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  [`clamp()`](https://vorpalvorpal.github.io/weft/reference/phrases.md)
  : Phrase functions
- [`in_range()`](https://vorpalvorpal.github.io/weft/reference/in_range.md)
  : Is a value inside a range?
- [`claim()`](https://vorpalvorpal.github.io/weft/reference/claim.md) :
  Check a value in place

## Checking wording

See which arms a document can choose, and what the last knit did.

- [`arms()`](https://vorpalvorpal.github.io/weft/reference/arms.md) :
  List the arms of every governed span of a document
- [`rehearse()`](https://vorpalvorpal.github.io/weft/reference/rehearse.md)
  : Knit a document under several cases and see which arms they choose
- [`last_knit()`](https://vorpalvorpal.github.io/weft/reference/last_knit.md)
  : The records of the most recent knit

## The dictionary

- [`dict_file`](https://vorpalvorpal.github.io/weft/reference/dict_file.md)
  : The dictionary file

- [`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)
  : Read a dictionary file

- [`` `$`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `[[`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `[`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `$<-`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `[[<-`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `[<-`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`` `names<-`( ``*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`names(`*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`as.list(`*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  [`print(`*`<weft_dict>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_dict.md)
  : Methods for a dictionary

- [`c(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`` `[`( ``*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`` `[[`( ``*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`rev(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`sort(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`unique(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`seq(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`Summary(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`Ops(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`Math(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`format(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  [`print(`*`<weft_year>`*`)`](https://vorpalvorpal.github.io/weft/reference/weft_year.md)
  : A year in a dictionary

- [`dict_glossary()`](https://vorpalvorpal.github.io/weft/reference/dict_glossary.md)
  : The glossary of a dictionary

- [`dict_seed()`](https://vorpalvorpal.github.io/weft/reference/dict_seed.md)
  : Find constants a project defines in more than one document

- [`dict_vale()`](https://vorpalvorpal.github.io/weft/reference/dict_vale.md)
  :

  A Vale rule from the dictionary's `avoid` fields

## targets pipelines

- [`tar_dict()`](https://vorpalvorpal.github.io/weft/reference/tar_dict.md)
  : Targets for a project dictionary
- [`tar_dict_deps()`](https://vorpalvorpal.github.io/weft/reference/tar_dict_deps.md)
  : Add the dictionary entries a pipeline reads to its targets

## Static lints

- [`print(`*`<weft_findings>`*`)`](https://vorpalvorpal.github.io/weft/reference/lints.md)
  [`lints()`](https://vorpalvorpal.github.io/weft/reference/lints.md) :
  Lint a project's documents without running them
- [`checks()`](https://vorpalvorpal.github.io/weft/reference/checks.md)
  [`print(`*`<weft_checks>`*`)`](https://vorpalvorpal.github.io/weft/reference/checks.md)
  : Checks of one value, compared
- [`lint_rules()`](https://vorpalvorpal.github.io/weft/reference/lint_rules.md)
  : The static lints
- [`label_seed()`](https://vorpalvorpal.github.io/weft/reference/label_seed.md)
  : Propose label words from the prose
- [`recall_check()`](https://vorpalvorpal.github.io/weft/reference/recall_check.md)
  [`print(`*`<weft_recall>`*`)`](https://vorpalvorpal.github.io/weft/reference/recall_check.md)
  : Check how well the lints reproduce recorded findings

## Commit gate and release checks

- [`gate()`](https://vorpalvorpal.github.io/weft/reference/gate.md)
  [`print(`*`<weft_gate>`*`)`](https://vorpalvorpal.github.io/weft/reference/gate.md)
  : The commit gate
- [`changes()`](https://vorpalvorpal.github.io/weft/reference/changes.md)
  [`print(`*`<weft_changes>`*`)`](https://vorpalvorpal.github.io/weft/reference/changes.md)
  : What changed in the ledgers since a commit
- [`verify()`](https://vorpalvorpal.github.io/weft/reference/verify.md)
  [`print(`*`<weft_verify>`*`)`](https://vorpalvorpal.github.io/weft/reference/verify.md)
  : Check a project before release
- [`status()`](https://vorpalvorpal.github.io/weft/reference/status.md)
  : What weft has installed in a project

## Setting up a project

- [`use_weft()`](https://vorpalvorpal.github.io/weft/reference/use_weft.md)
  : Set up a project for weft: every installer, from one plan
- [`use_setup()`](https://vorpalvorpal.github.io/weft/reference/use_setup.md)
  : Activate weft in a project's documents
- [`use_quarto()`](https://vorpalvorpal.github.io/weft/reference/use_quarto.md)
  : Set up a Quarto project for weft
- [`use_dictionary()`](https://vorpalvorpal.github.io/weft/reference/use_dictionary.md)
  : Set up the project dictionary
- [`use_hooks()`](https://vorpalvorpal.github.io/weft/reference/use_hooks.md)
  : Install the commit-msg hook that runs the commit gate
- [`use_ci()`](https://vorpalvorpal.github.io/weft/reference/use_ci.md)
  : Write the GitHub Actions workflow that runs weft's static checks
- [`use_agent_docs()`](https://vorpalvorpal.github.io/weft/reference/use_agent_docs.md)
  : Write the agent documents: an AGENTS.md block and a skill
- [`agent_docs()`](https://vorpalvorpal.github.io/weft/reference/agent_docs.md)
  : Print the agent documents of the installed package
