# A quieter `claim-word` lint (14 Nov, after v0.1.0)

## Why

On the trial book the lint gave 2,719 findings, 43% of its 6,294
sentences. A labelled sample of 170 findings (one labeller, one book)
put precision at 45% (95% interval 36 to 54). By class, at word level:
direction 64%, extremum 37%, quantifier 36%. The false ones were, in
order: a method or a definition, an idiom, a hyphenated compound, an
instruction, background, a quantifier of a noun that is not data, and a
proper name. The prose view masks code, links, keys and comments
correctly: no hit sat inside one.

Two faults in the sentence text were found on the way: blockquote
markers stay in the reported sentence, and the last sentence of a
numbered list item runs on into the next item's marker.

## Alternatives measured

Each is the share of today's findings left, the precision, and the
share of today's true findings kept.

| change | findings | precision | true kept |
|---|---|---|---|
| today | 2,719 | 45% | 100% |
| only sentences with a value | 941 | 73% | 49% |
| only sentences with a value or a digit | 1,368 | 63% | 67% |
| drop the quantifier class | 774 | 55% | 35% |
| skip compounds, idioms and proper names | 2,523 | 47% | 97% |
| skip headings, captions and list items | 2,232 | 46% | 83% |
| R0: drop the worst words, skip compounds, idioms, names | 2,055 | 63% | 95% |
| R1: R0, and a quantifier needs a value or digit in its sentence | 1,318 | 72% | 72% |
| R1p: as R1, anywhere in the paragraph | 1,815 | 66% | 87% |
| R2: R0, and every class needs a value or digit | 1,073 | 77% | 61% |

Filtering by section (methods against results) did not help: both were
about half true.

## Chosen: R1, with a setting to go back

R1 halves the findings and takes precision from under half to about
seven in ten. Decision 66's test was that a flag most prose carries
tells the author nothing; R1 flags one sentence in five. Its condition
is per sentence, like the message's own "with a value" test. R1p keeps
more true findings but flags 29% of sentences. What R1 loses is mostly
quantifier statements with no number in them; `claim_quantifiers: any`
brings them back.

One departure from the study: it dropped six words (each, both, either,
whole, never, always). "never" and "always" are kept, because they are
claims in principle and the new number condition already silences them
in sentences without a number. The sample had 5 hits of "never" and
none of "always", too few to rule on.

The dropped words and the idiom list were chosen after seeing the
sample, on one book. A second manuscript should confirm them.

## Rules

**CW1** The shipped lexicon loses `each`, `both`, `either` and `whole`
from `quantifier`. It then holds 65 words. A project can put any back
with `claim_words: {add: [...]}`.

**CW2** The shipped lexicon file gains a top-level list `idioms`, of
lower-case phrases. A lexicon word inside a phrase of the list is not a
hit. Matching ignores case and treats any run of white space (a line
break included) as one space, and the phrase must start and end at word
boundaries. The shipped list:

at least, at the very least, at most, most likely, as a whole, on the
whole, no longer, no doubt, no matter, not only, if only, nothing else,
nothing more, best read, best understood, best seen, best practice,
lower bound, lower bounds, lower limit, maximum likelihood, minimum
detectable, significant figures, significant digits, fall short, either
way.

**CW3** `claim_words` takes a third key, `idioms`, a list of phrases a
project adds to the shipped list. It is validated like `add` and `drop`
(strings; anything else is the 5.5.4 config error). Default: empty.
`default_config()` shows it: `claim_words: {add: [], drop: [],
idioms: []}`.

**CW4** A hit with a hyphen directly before or after the word is not a
hit ("whole-record", "best-supported", "all-time"). A hyphen is `-`,
U+2010 or U+2011.

**CW5** A hit that starts with a capital letter and is not the first
word of its sentence is not a hit (a proper name: "Wentworth Falls").
The first word is the first run of letters in the sentence. A word in
all capitals of two letters or more is judged the same way (skipped
unless first).

**CW6** New setting `claim_quantifiers`: `number` (default), `any` or
`none`; any other value is a config error naming the three values and
rule 5.5.5.
- `number`: a word of the `quantifier` list is a hit only in a sentence
  that holds a value or a typed digit. A value is what the message
  already calls one (a `value`, `bare`, `named`, `n`, `sign` or `list`
  row inside the sentence). A typed digit is any of 0 to 9 in the
  sentence's prose view (so a digit inside masked code, a link target
  or a citation key does not count).
- `any`: a quantifier is a hit in any sentence (the 0.1.0 behaviour,
  apart from CW1, CW2, CW4 and CW5).
- `none`: quantifiers are never hits.
Extremum and direction words are hits in any sentence under all three.
A word added by `claim_words: add` is a hit in any sentence, whatever
list a shipped word of the same spelling sat in.

**CW7** The order of the tests: guarded spans and phrase blocks as now;
then CW2, CW4 and CW5 remove hits; then CW6; then sentences are grouped
as now. A sentence whose quantifier is removed but which holds another
hit is still one finding, listing only the words that are hits.

**CW8** Messages, the rule number 5.5.1, the level, `claim_cap` and the
roll-up are unchanged.

**CW9** The reported sentence text of a finding inside a blockquote has
no `>` markers: a line's leading blockquote markers and the one space
after each are removed before white space is collapsed.

**CW10** The last sentence of a list item ends at the end of that item.
It does not hold the next item's marker (`2.`, `-`, `*`, `+`, `(a)`),
in the reported text or in the finding's end position. This holds for
ordered and bulleted lists, nested or not. (Cause not yet known; the
fix belongs wherever sentences are cut, and every lint that uses
sentences gets it.)

## Tests to re-pin

The study lists them: `test-lint-config.R` (the lexicon count and the
dropped list), `test-lint-claims.R`, `helper-3d.R` (`F3D_CLAIMS`),
`test-review-3.R`, and counts in `test-lint-findings.R`,
`test-verify-static.R`, `test-changes-findings.R`, `helper-4c.R`,
`test-trial-fixes.R`, `test-review-code-c.R`, `test-gate-judge.R` and
`test-lint-pandoc.R`. A fixture that used a quantifier with no number to
make a finding is changed to a direction or extremum word, or given a
number, whichever keeps the test's point.

## Documents

Spec 5.5.1 and 5.5.4 (65 words; the idiom list; the quantifier
condition), a new 5.5.5 for `claim_quantifiers`, the settings table, the
lints article, `NEWS.md`.
