# clag <img src="man/figures/logo.png" align="right" height="139" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/user/clag/workflows/R-CMD-check/badge.svg)](https://github.com/user/clag/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/clag)](https://CRAN.R-project.org/package=clag)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Overview

`clag` is a package for generating markdown text using the familiar syntax of `glue` with enhanced templating features. Unlike `cli` which produces styled console output, `clag` outputs plain markdown text, making it ideal for document generation in R Markdown and Quarto documents.

Key features:

- ✓ **Text Interpolation**: Standard glue-style `{expr}` in R code, double braces `{{expr}}` in documents
- ✓ **Pluralisation**: Smart pluralisation with `{?s}` or `{{?s}}` syntax
- ✓ **Vector Formatting**: Automatic collapsing with customisable separators
- ✓ **Markdown Formatters**: Special syntax for creating lists, definition lists, YAML blocks, and task lists
- ✓ **Seamless Integration**: Works with both R Markdown and Quarto

## Installation

```r
# Install from CRAN
install.packages("clag")

# Or the development version from GitHub
# install.packages("devtools")
devtools::install_github("vorpalvorpal/clag")
```

## Syntax

`clag` uses two different syntax styles:

1. **Direct Function Calls**: When calling `clag()` directly in R code, use standard glue syntax with single curly braces:

   ```r
   name <- "World"
   clag("Hello, {name}!")
   ```

2. **Document Markup**: When writing in R Markdown or Quarto documents, use double curly braces for interpolation:

   ```markdown
   # My Document

   Hello, {{name}}!
   ```

This distinction allows for cleaner integration with document processors while maintaining compatibility with the standard glue syntax for direct usage.

## Basic Usage

### Text Interpolation

```r
library(clag)

name <- "World"
clag("Hello, {name}!")
#> Hello, World!

# In Rmd/Qmd documents, use {{name}} directly in markdown text
```

### Pluralisation

```r
n_files <- 0
clag("Found {n_files} file{?s}.")
#> Found 0 files.

n_files <- 1
clag("Found {n_files} file{?s}.")
#> Found 1 file.

# Complex pluralisation
n_people <- 1
clag("There {?is/are} {n_people} {?person/people} waiting.")
#> There is 1 person waiting.

n_people <- 5
clag("There {?is/are} {n_people} {?person/people} waiting.")
#> There are 5 people waiting.

# Zero/singular/plural forms
n_cats <- 0
clag("{n_cats} {?no/one/many} cat{?s} found.")
#> 0 no cats found.
```

### Vector Formatting

```r
# Automatic collapse with commas and "and"
fruits <- c("apples", "bananas", "oranges")
clag("I like {fruits}.")
#> I like apples, bananas, and oranges.

# Alternative joining with custom pattern
options <- c("tea", "coffee", "water")
glue_vec(options, .last = " or ")
#> tea, coffee or water
```

## Markdown Formatting

### Unordered Lists

```r
items <- c("First item", "Second item", "Third item with *markdown* formatting")
clag("{- items}")
#> - First item
#> - Second item
#> - Third item with *markdown* formatting

# Direct with glue_vec
glue_vec(items, .item = "- {.item}", .sep = "\n")
```

### Ordered Lists

```r
steps <- c("Clone the repository", "Install dependencies", "Run tests")
clag("{1 steps}")
#> 1. Clone the repository
#> 1. Install dependencies
#> 1. Run tests

# Direct with glue_vec
names(steps) <- 1:length(steps)
glue_vec(steps, .item = "{.name}. {.item}", .sep = "\n")
```

### Definition Lists

```r
terms <- c(
  R = "A language for statistical computing",
  Python = "A general-purpose programming language",
  JavaScript = "A language for web development"
)
clag("{= terms}")
#> R
#> :    A language for statistical computing
#> Python
#> :    A general-purpose programming language
#> JavaScript
#> :    A language for web development

# Direct with glue_vec
glue_vec(terms, .item = "{.name}\n:    {.item}", .sep = "\n")
```

### YAML Blocks

```r
metadata <- c(
  title = "My Document",
  author = "Jane Doe",
  date = "2023-05-15"
)
clag("{: metadata}")
#> ---
#> title: My Document
#> author: Jane Doe
#> date: 2023-05-15
#> ---

# Direct with glue_vec
glue_vec(metadata, .item = "{.name}: {.item}", .sep = "\n", .vec = "---\n{.vec}\n---")
```

### Task Lists

```r
tasks <- c(
  done = "Create project structure",
  done = "Write core functions",
  "Add documentation",
  "Write tests"
)
clag("{[ tasks}")
#> - [x] Create project structure
#> - [x] Write core functions
#> - [ ] Add documentation
#> - [ ] Write tests

# Direct with glue_vec
glue_vec(tasks, .sep = "\n", .item = "- [{if (.name == 'done') 'x' else ' '}] {.item}")
```

## Integration with R Markdown and Quarto

### Adding to a Document

Add this to your YAML header:

```yaml
---
title: "My Document"
knit: clag::clag_knit
---
```

Then use double curly braces directly in your text:

```markdown
## Introduction

Hello, {{name}}!

{{- items}}

There {{?is/are}} {{n_results}} result{{?s}}.
```

### Pass-through Syntax

Use `{{! expr}}` to pass variables directly to R Markdown or Quarto without `clag` processing:

```markdown
The current date is {{! Sys.Date()}}.

There are {{! total_count}} items in the {{?category/categories}}.
```

### Manual Processing

You can also use `clag` explicitly in code chunks:

````markdown
```{r}
library(clag)
name <- "World"
items <- c("apple", "banana", "orange")
```

{{name}} likes {{items}}.

Or with a code chunk:

```{r}
clag("Hello, {name}! You have {length(items)} fruit{?s}.")
```
````

## Advanced Usage

### Customizing Vector Formatting

```r
# Customizing list formatting
authors <- c("Alice Smith", "Bob Jones", "Carol Davis")
glue_vec(authors, .item = "**{.item}**", .sep = "\n", .item = "- {.item}")
#> - **Alice Smith**
#> - **Bob Jones**
#> - **Carol Davis**

# Custom separators
glue_vec(1:5, .sep = " | ", .last = " | and finally ")
#> 1 | 2 | 3 | 4 | and finally 5

# Adding pre/post text to the whole vector
packages <- c("dplyr", "ggplot2", "purrr")
glue_vec(packages, .vec = "Required packages: {.vec}", 
        .item = "`{.item}`", .sep = ", ")
#> Required packages: `dplyr`, `ggplot2`, `purrr`
```

### Using `clag` with Data Frames

```r
df <- head(mtcars[1:3, 1:4])
clag("Car data:\n\n{df}")
#> Car data:
#> 
#> ----------------------------------------------
#>             mpg   cyl   disp     hp
#> ---------- ----- ----- ------ ------
#> Mazda RX4  21     6    160     110
#> 
#> Mazda RX4  21     6    160     110
#> Wag
#> 
#> Datsun 710 22.8   4    108      93
#> ----------------------------------------------
```

### Using with ggplot2

```r
library(ggplot2)
plot <- ggplot(mtcars, aes(x = mpg, y = hp)) + 
  geom_point() + 
  theme_minimal()
clag("Here's a plot of horsepower vs mpg:\n\n{plot}")
#> Here's a plot of horsepower vs mpg:
#> 
#> ![](/tmp/RtmpXXXXXX/file123456789.png)
```

### Width Control

```r
# Control line breaking with .width parameter
long_text <- c(
  "This is a very long item that should wrap at the specified width parameter",
  "Another lengthy item to demonstrate width-based wrapping",
  "A third item that helps show how the text gets formatted with width"
)
glue_vec(long_text, .width = 40)
#> This is a very long item that should
#> wrap at the specified width parameter,
#> Another lengthy item to demonstrate
#> width-based wrapping, and A third
#> item that helps show how the text
#> gets formatted with width
```

## How It Works

1. `clag_knit` reads the document before processing
2. Double curly braces `{{var}}` are converted to R expressions
3. Pluralisation directives like `{{?s}}` use the preceding value
4. The processed document is passed to knitr/Quarto for rendering

## Why Double Curly Braces in Documents?

- Less ambiguity with normal markdown text
- Compatible with Quarto's syntax
- Visually distinct from regular text
- Reduced likelihood of unintended substitutions
- Allows regular Markdown syntax (like `{tag}`) to be used without conflicts

## Configuration

You can configure `clag` globally:

```r
options(clag.enabled = TRUE)  # Enable clag preprocessing (default)
options(clag.enabled = FALSE) # Disable clag preprocessing
```

Or per-document via YAML:

```yaml
params:
  clag.enabled: true
```

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
