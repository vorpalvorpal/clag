test_that("Basic interpolation with single braces works", {
  # Simple string interpolation
  name <- "World"
  expect_equal(clag("Hello, {name}!"), "Hello, World!")

  # Multiple interpolations
  first <- "John"
  last <- "Doe"
  expect_equal(clag("Name: {first} {last}"), "Name: John Doe")

  # Numeric interpolation
  value <- 42
  expect_equal(clag("The answer is {value}."), "The answer is 42.")

  # Expression interpolation
  expect_equal(clag("2 + 2 = {2 + 2}"), "2 + 2 = 4")

  # Nested expressions
  a <- 10
  b <- 5
  expect_equal(clag("Result: {a + b * 2}"), "Result: 20")
})

test_that("Pluralisation functionality works", {
  # Simple suffix pluralisation with literals
  expect_equal(clag("Found {0} file{?s}."), "Found 0 files.")
  expect_equal(clag("Found {1} file{?s}."), "Found 1 file.")
  expect_equal(clag("Found {2} file{?s}."), "Found 2 files.")

  # Pluralisation with variables
  n_files <- 0
  expect_equal(clag("Found {n_files} file{?s}."), "Found 0 files.")
  n_files <- 1
  expect_equal(clag("Found {n_files} file{?s}."), "Found 1 file.")
  n_files <- 10
  expect_equal(clag("Found {n_files} file{?s}."), "Found 10 files.")

  # Singular/plural form handling
  expect_equal(clag("There {?is/are} {0} item{?s}."), "There are 0 items.")
  expect_equal(clag("There {?is/are} {1} item{?s}."), "There is 1 item.")
  expect_equal(clag("There {?is/are} {10} item{?s}."), "There are 10 items.")

  # Custom singular/plural forms
  expect_equal(clag("The {1} {?child/children} {?has/have} {2} {?toy/toys}."),
    "The 1 child has 2 toys.")
  expect_equal(clag("The {2} {?child/children} {?has/have} {1} {?toy/toys}."),
    "The 2 children have 1 toy.")

  # Zero/singular/plural form handling
  expect_equal(clag("{0} {?no/one/many} cat{?s} found."), "0 no cats found.")
  expect_equal(clag("{1} {?no/one/many} cat{?s} found."), "1 one cat found.")
  expect_equal(clag("{2} {?no/one/many} cat{?s} found."), "2 many cats found.")

  # Helper functions
  expect_equal(clag("Found {no(0)} file{?s}."), cli::pluralize("Found {no(0)} file{?s}."))
  expect_equal(clag("Found {no(1)} file{?s}."), cli::pluralize("Found {no(1)} file{?s}."))
  expect_equal(clag("{3}/{10} {qty(3)}file{?s} need updating."), cli::pluralize("{3}/{10} {cli::qty(3)}file{?s} need updating."))

  # Pluralisation with dots and other punctuation
  n <- 1
  expect_equal(clag("Found {n} file{?s}. It {?was/were} in the folder."),
    "Found 1 file. It was in the folder.")
  n <- 2
  expect_equal(clag("Found {n} file{?s}. They {?was/were} in the folder."),
    "Found 2 files. They were in the folder.")
})

test_that("Special markdown formatters work", {
  # Unordered list
  items <- c("First item", "Second item", "Third item")
  expected_unordered <- "- First item\n- Second item\n- Third item"
  expect_equal(clag("{- items}"), expected_unordered)

  # Ordered list
  steps <- c("Step one", "Step two", "Step three")
  expected_ordered <- "1. Step one\n1. Step two\n1. Step three"
  expect_equal(clag("{1 steps}"), expected_ordered)

  # Definition list
  terms <- c(R = "A language for statistical computing",
    Python = "A general-purpose programming language")
  expected_definition <- "R\n:    A language for statistical computing\nPython\n:    A general-purpose programming language"
  expect_equal(clag("{= terms}"), expected_definition)

  # YAML block
  metadata <- c(title = "Document", author = "Jane Doe")
  expected_yaml <- "---\ntitle: Document\nauthor: Jane Doe\n---"
  expect_equal(clag("{: metadata}"), expected_yaml)

  # Task list
  tasks <- c(x = "Task 1", "Task 2", x = "Task 3")
  expected_tasks <- "- [x] Task 1\n- [ ] Task 2\n- [x] Task 3"
  expect_equal(clag("{[ tasks}"), expected_tasks)

  # Alternative joining (or instead of and)
  options <- c("Option A", "Option B", "Option C")
  expected_or <- "Option A, Option B or Option C"
  expect_equal(clag("{| options}"), expected_or)
})

test_that("Vector formatting with glue_vec works", {
  # Basic vector formatting
  fruits <- c("apple", "banana", "cherry")
  expect_equal(glue_vec(fruits), "apple, banana, and cherry")

  # Custom separators
  expect_equal(glue_vec(fruits, .sep = "; ", .last = " or "),
    "apple; banana or cherry")

  # Custom item template
  expect_equal(glue_vec(fruits, .item = "*{.item}*"),
    "*apple*, *banana*, and *cherry*")

  # Custom vector template
  expect_equal(glue_vec(fruits, .vec = "Fruits: {.vec}"),
    "Fruits: apple, banana, and cherry")

  # Named vector with name in template
  named_items <- c(fruit1 = "apple", fruit2 = "banana", fruit3 = "cherry")
  expect_equal(
    glue_vec(named_items, .item = "[{.name}]: {.item}"),
    "[fruit1]: apple, [fruit2]: banana, and [fruit3]: cherry"
  )

  # Transformation of names and items
  expect_equal(
    glue_vec(named_items, .item = "{.name}: {.item}",
      .transformer_name = toupper, .transformer_item = toupper),
    "FRUIT1: APPLE, FRUIT2: BANANA, and FRUIT3: CHERRY"
  )
})

test_that("Handling different input types works", {
  # Character vectors
  expect_equal(clag("Value: {'test'}"), "Value: test")

  # Numeric values
  expect_equal(clag("Value: {42}"), "Value: 42")
  expect_equal(clag("Value: {pi}"), paste0("Value: ", pi))

  # Logical values
  expect_equal(clag("Value: {TRUE}"), "Value: TRUE")
  expect_equal(clag("Value: {FALSE}"), "Value: FALSE")

  # NULL value (should be empty)
  expect_equal(clag("Value: {NULL}"), "Value: ")

  # NA values
  expect_equal(clag("Value: {NA}"), "Value: NA")

  # Vectors of different lengths
  short_vec <- 1:3
  long_vec <- letters[1:5]
  expect_equal(clag("Short: {short_vec}, Long: {long_vec}"),
    "Short: 1, 2, and 3, Long: a, b, c, d, and e")

  # Data frame (using a simple test to check it produces output)
  if (requireNamespace("pander", quietly = TRUE)) {
    df <- data.frame(a = 1:3, b = letters[1:3])
    result <- clag("Data: {df}")
    expect_equal(result, glue::glue('Data: {pander::pandoc.table.return(df, justify = "left", style = "multiline")}'))
    expect_true(grepl("Data:", result))
    expect_true(grepl("a", result))
    expect_true(grepl("b", result))
  }

  # With ggplot2 (skip actual test as it creates temp files)
  skip("Skipping ggplot test as it creates temporary files")
})

test_that("Proper environment handling works", {
  # Variables from the calling environment
  x <- 10
  expect_equal(clag("Value: {x}"), "Value: 10")

  # Inside a function
  f <- function() {
    y <- 20
    clag("Value: {y}")
  }
  expect_equal(f(), "Value: 20")

  # Nested environments
  g <- function() {
    z <- 30
    h <- function() {
      clag("Value: {z}")
    }
    h()
  }
  expect_equal(g(), "Value: 30")

  # Custom environment
  env <- new.env()
  env$a <- 100
  expect_equal(clag("Value: {a}", .envir = env), "Value: 100")

  # Scope mixing
  b <- 200
  env$c <- 300
  expect_equal(clag("B: {b}, C: {c}", .envir = env), "B: 200, C: 300")

  # Function calls in different environments
  env$double <- function(x) x * 2
  expect_equal(clag("Doubled: {double(5)}", .envir = env), "Doubled: 10")
})

test_that("Input validation works correctly", {
  # glue_vec input validation
  expect_error(glue_vec(environment()), "must be a vector")
  expect_error(glue_vec(1:3, .item = 123), "must be a string")
  expect_error(glue_vec(1:3, .vec = 123), "must be a string")
  expect_error(glue_vec(1:3, .sep = 123), "must be a string")
  expect_error(glue_vec(1:3, .last = 123), "must be a string")
  expect_error(glue_vec(1:3, .width = "not a number"), "must be an integer")
  expect_error(glue_vec(1:3, .transformer_name = "not a function"), "must be a function")
  expect_error(glue_vec(1:3, .transformer_item = "not a function"), "must be a function")

  # No quantity for pluralisation (should throw an error)
  expect_error(clag("File{?s}."))
})

test_that("Edge cases are handled properly", {
  # Empty vector
  expect_equal(glue_vec(character(0)), "")

  # Single element vector
  expect_equal(glue_vec("apple"), "apple")

  # Two element vector (special case for last separator)
  expect_equal(glue_vec(c("apple", "banana")), "apple, and banana")

  # Vector with some empty names
  mixed_names <- c("a", b = "b", "c", d = "d")
  expect_equal(glue_vec(mixed_names), "a, b, c, and d")

  # Special characters in variables
  special_var <- "It's \"quoted\" & has <html>"
  expect_equal(clag("Text: {special_var}"), paste0("Text: ", special_var))

  # Line wrapping with width parameter
  long_items <- c(
    "This is a very long item that should wrap at some point",
    "Another lengthy item that goes beyond the width",
    "A third item to demonstrate width handling"
  )
  result <- glue_vec(long_items, .width = 40)
  expect_true(nchar(result) > 0)
  lines <- strsplit(result, "\n")[[1]]
  for (i in seq_along(lines)) {
    if (i < length(lines)) {
      expect_lte(nchar(lines[i]), 40)
    }
  }
})
