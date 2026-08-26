test_that("Basic expression processing works", {
  # Simple variable interpolation
  text <- "Hello, {{name}}!"
  name <- "World"

  # Test R Markdown format
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"Hello, {name}!\")`")

  # Test Quarto format
  result_quarto <- process_clag_expressions(text, environment(), TRUE)
  expect_equal(result_quarto, "{{clag::clag(\"Hello, {name}!\")}}")

  # Multiple expressions in one line
  text <- "The {{color}} {{animal}} jumps over the {{object}}."
  color <- "brown"
  animal <- "fox"
  object <- "fence"

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"The {color} {animal} jumps over the {object}.\")`")
})

test_that("Pluralization expressions work", {
  # Simple pluralization
  text <- "{{n_files}} file{{?s}}"
  n_files <- 1

  # Test R Markdown format
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"{n_files} file{?s}\")`")

  # Pluralization with quantity
  text <- "There {{?is/are}} {{n_items}} item{{?s}}"
  n_items <- 3

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"There {?is/are} {n_items} item{?s}\")`")

  # Complex pluralization patterns
  text <- "You have {{n_files}} file{{?s}} and {{n_folders}} folder{{?s}}."
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result_rmd,
    "`r clag::clag(\"You have {n_files} file{?s} and {n_folders} folder{?s}.\")`"
  )
})

test_that("Raw passthrough expressions work", {
  # Basic passthrough
  text <- "Today is {{! Sys.Date()}}."

  # Test R Markdown format
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"Today is {! Sys.Date()}.\")`")

  # Multiple passthroughs
  text <- "Current time: {{! Sys.time()}}, R version: {{! R.version.string}}"

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result_rmd,
    "`r clag::clag(\"Current time: {! Sys.time()}, R version: {! R.version.string}\")`"
  )
})

test_that("Special formatters work", {
  # Unordered list
  text <- "{{- items}}"
  items <- c("Item 1", "Item 2")

  # Test R Markdown format
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, "`r clag::clag(\"{- items}\")`")

  # All formatters
  text <- "List: {{- items}}\nOrdered: {{1 steps}}\nDefs: {{= terms}}\nYAML: {{: meta}}\nTasks: {{[ tasks}}"

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expected <- paste(
    "`r clag::clag(\"List: {- items}\")`",
    "`r clag::clag(\"Ordered: {1 steps}\")`",
    "`r clag::clag(\"Defs: {= terms}\")`",
    "`r clag::clag(\"YAML: {: meta}\")`",
    "`r clag::clag(\"Tasks: {[ tasks}\")`",
    sep = "\n"
  )
  expect_equal(result_rmd, expected)
})

test_that("Mixed expressions work", {
  # Mix of raw, pluralization, and regular expressions
  text <- "Today {{! Sys.Date()}}, we have {{n_files}} file{{?s}} and {{- items}} on the list"

  # Test R Markdown format
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result_rmd,
    "`r clag::clag(\"Today {! Sys.Date()}, we have {n_files} file{?s} and {- items} on the list\")`"
  )

  # Line with multiple mixed expressions
  text <- "Summary: {{! format(Sys.Date())}} - {{count}} {{?person/people}} attended, {{! round(percent*100, 1)}}% liked {{- foods}}"

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result_rmd,
    "`r clag::clag(\"Summary: {! format(Sys.Date())} - {count} {?person/people} attended, {! round(percent*100, 1)}% liked {- foods}\")`"
  )
})

test_that("Multi-line documents work", {
  # Document with multiple lines
  text <- "# Title\n\nFirst paragraph with {{var1}}.\n\nSecond paragraph with {{var2}}.\n"

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expected <- paste(
    "# Title\n",
    "\n",
    "`r clag::clag(\"First paragraph with {var1}.\")`\n",
    "\n",
    "`r clag::clag(\"Second paragraph with {var2}.\")`\n",
    sep = ""
  )
  expect_equal(result_rmd, expected)
})

test_that("Trailing newlines are preserved", {
  # Single trailing newline
  text <- "Hello, {{name}}!\n"
  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result, "`r clag::clag(\"Hello, {name}!\")`\n")

  # Multiple trailing newlines
  text <- "Hello, {{name}}!



Who are you?


"
  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result, "`r clag::clag(\"Hello, {name}!\")`



Who are you?


")

  # No trailing newline
  text <- "Hello, {{name}}!"
  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result, "`r clag::clag(\"Hello, {name}!\")`")
})

test_that("Exact newline counts match in various scenarios", {
  # Test with different trailing newline counts
  test_cases <- list(
    list(input = "{{var}}", expected_newlines = 0),
    list(input = "{{var}}\n", expected_newlines = 1),
    list(input = "{{var}}\n\n", expected_newlines = 2),
    list(input = "{{var}}\n\n\n", expected_newlines = 3),
    list(input = "{{var}}\n\n\n\n\n", expected_newlines = 5)
  )

  for (case in test_cases) {
    input <- case$input
    result <- process_clag_expressions(input, environment(), FALSE)

    # Count trailing newlines in result
    result_newlines <- 0
    for (i in nchar(result):1) {
      if (substr(result, i, i) == "\n") {
        result_newlines <- result_newlines + 1
      } else {
        break
      }
    }

    expect_equal(
      result_newlines,
      case$expected_newlines,
      info = paste("Input with", case$expected_newlines, "trailing newlines")
    )
  }
})

test_that("Multi-line document preserves exact trailing newlines", {
  # Test with a complex document structure
  text <- paste(
    "# Title",
    "",
    "First paragraph with {{var1}}.",
    "",
    "Second paragraph with {{var2}}.",
    "",
    "",
    "",
    sep = "\n"
  )

  result <- process_clag_expressions(text, environment(), FALSE)

  # Count trailing newlines in input and result
  count_trailing <- function(str) {
    count <- 0
    for (i in nchar(str):1) {
      if (substr(str, i, i) == "\n") {
        count <- count + 1
      } else {
        break
      }
    }
    return(count)
  }

  input_newlines <- count_trailing(text)
  result_newlines <- count_trailing(result)

  expect_equal(result_newlines, input_newlines)
  expect_equal(result_newlines, 3)  # The test text has 3 trailing newlines
})

test_that("Multiple newlines between content are preserved", {
  # Multiple newlines between content
  text <- "First {{var1}}\n\n\nSecond {{var2}}"
  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result,
    "`r clag::clag(\"First {var1}\")`\n\n\n`r clag::clag(\"Second {var2}\")`"
  )

  # Multiple newlines at beginning, middle, and end
  text <- "\n\nFirst {{var1}}\n\n\nSecond {{var2}}\n\n"
  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(
    result,
    "\n\n`r clag::clag(\"First {var1}\")`\n\n\n`r clag::clag(\"Second {var2}\")`\n\n"
  )
})

test_that("Complex document structure preserves all newlines", {
  # Create a document with various newline patterns
  text <- paste(
    "---",
    "title: Test Document",
    "---",
    "",
    "",
    "# First Section",
    "",
    "Para 1 {{var1}}",
    "",
    "",
    "Para 2 {{var2}}",
    "",
    "```r",
    "code block",
    "```",
    "",
    "# Second Section",
    "",
    "Final {{var3}}",
    "",
    "",
    "",  # Multiple trailing newlines
    sep = "\n"
  )

  result <- process_clag_expressions(text, environment(), FALSE)

  # Check specific patterns
  expect_match(result, "---\ntitle: Test Document\n---\n\n\n", fixed = TRUE)
  expect_match(result, '`r clag::clag(\"Para 1 {var1}\")`\n\n\n`r clag::clag(\"Para 2 {var2}\")`\n\n```r', fixed = TRUE)
  expect_match(result, "```r\ncode block\n```\n\n", fixed = TRUE)
  expect_match(result, "Final.*\n\n\n$", all = TRUE)  # Check trailing newlines at end

  # Count the total number of newlines to make sure none are lost
  original_newlines <- length(gregexpr("\n", text)[[1]])
  result_newlines <- length(gregexpr("\n", result)[[1]])
  expect_equal(original_newlines, result_newlines)
})

test_that("Document with no expressions preserves structure exactly", {
  # Document with no expressions to transform
  text <- paste(
    "# Plain Document",
    "",
    "This has no expressions.",
    "",
    "Just plain text.",
    "",
    "",
    sep = "\n"
  )

  result <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result, text)
})

test_that("Multi-line test case works correctly with trailing newline", {
  text <- "# Title\n\nFirst paragraph with {{var1}}.\n\nSecond paragraph with {{var2}}.\n"
  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expected <- paste(
    "# Title\n",
    "\n",
    "`r clag::clag(\"First paragraph with {var1}.\")`\n",
    "\n",
    "`r clag::clag(\"Second paragraph with {var2}.\")`\n",
    sep = ""
  )
  expect_equal(result_rmd, expected)
})

test_that("Quoting and escaping works correctly", {
  # Expressions with quotes
  text <- 'The "{{item}}" is {{color}}'

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, '`r clag::clag("The \\"{item}\\" is {color}")`')

  # Expressions with backslashes and quotes
  text <- 'Path: {{path}} with "{{name}}"'

  result_rmd <- process_clag_expressions(text, environment(), FALSE)
  expect_equal(result_rmd, '`r clag::clag("Path: {path} with \\"{name}\\"")`')
})

test_that("Quote escaping produces correct R code", {
  # Original text
  text <- 'The "{{item}}" is {{color}}'

  # Process using our function
  result <- process_clag_expressions(text, environment(), FALSE)

  # What would be evaluated by knitr
  expected_eval <- '`r clag::clag("The \\"{item}\\" is {color}")`'

  # This test compares what knitr would see
  expect_equal(result, expected_eval)

  # We can test that our gsub produces correct escaping
  original <- 'The "item" is color'
  escaped <- gsub('"', '\\"', original, fixed = TRUE)

  # This is what we want in the final string
  expect_equal(escaped, 'The \\"item\\" is color')

  # Let's build the full string and compare
  quoted <- paste0('"', escaped, '"')
  expect_equal(quoted, '"The \\"item\\" is color"')

  # When R evaluates this string, it would see:
  # "The \"item\" is color"
  # Which correctly has escaped quotes
})

test_that("detect_quarto_document works", {
  # Create a mock Quarto document
  quarto_text <- "---\ntitle: Test\nformat: html\n---\n\nContent"
  expect_true(detect_quarto_document(quarto_text, default = FALSE))

  # Create a mock R Markdown document
  rmd_text <- "---\ntitle: Test\noutput: html_document\n---\n\nContent"
  expect_false(detect_quarto_document(rmd_text, default = FALSE))
})

test_that("Full document processing works", {
  # Skip if knitr is not available
  skip_if_not_installed("knitr")

  # Create a mock document with various clag expressions
  rmd_text <- paste(
    "---",
    "title: Test Document",
    "author: Test Author",
    "knit: clag::clag_knit",
    "---",
    "",
    "```{r setup, include=FALSE}",
    "name <- 'World'",
    "n_items <- 3",
    "items <- c('Item A', 'Item B', 'Item C')",
    "Sys.Date <- function() {return(as.Date('02/02/2022', '%d/%m/%y'))}",
    "```",
    "",
    "# Introduction",
    "",
    "Hello, {{name}}! Today is {{! Sys.Date()}}.",
    "",
    "## Items",
    "",
    "We have {{n_items}} item{{?s}} in our inventory:",
    "",
    "{{- items}}",
    "",
    "Thank you for your attention!",
    sep = "\n"
  )

  # Write to a temporary file
  rmd_file <- tempfile(fileext = ".Rmd")
  writeLines(rmd_text, rmd_file)

  # Create a temp output file
  output_file <- tempfile(fileext = ".md")

  # Process with clag_knit (suppress messages)
  message_log <- tempfile()
  processed <- suppressMessages(
    tryCatch(
      {
        clag_knit(rmd_file, output_file)
        TRUE
      },
      error = function(e) {
        print(paste("Error during knitting:", e$message))
        FALSE
      })
  )

  # Check if processing succeeded
  expect_true(processed)

  # Check if output file exists
  expect_true(file.exists(output_file))

  # Read output and check for key content
  if (file.exists(output_file)) {
    output_content <- readLines(output_file, warn = FALSE)
    output_text <- paste(output_content, collapse = "\n")

    # Check for expected content
    expect_match(output_text, "# Introduction", fixed = TRUE)
    expect_match(output_text, "Hello, World! Today is 2020-02-02.", fixed = TRUE)
    expect_match(output_text, "We have 3 items", fixed = TRUE)
    expect_match(output_text, "- Item A", fixed = TRUE)
    expect_match(output_text, "- Item B", fixed = TRUE)
    expect_match(output_text, "- Item C", fixed = TRUE)
  }

  # Clean up temporary files
  if (file.exists(rmd_file)) file.remove(rmd_file)
  if (file.exists(output_file)) file.remove(output_file)

  # Skip Quarto tests if quarto package is not available
  if (!requireNamespace("quarto", quietly = TRUE)) {
    skip("Quarto package not available")
  }
})
