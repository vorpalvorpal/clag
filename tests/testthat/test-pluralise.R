test_that("Simple suffix pluralization works", {
  # Testing numeric values
  expect_equal(clag("Found {0} file{?s}."), cli::pluralize("Found {0} file{?s}."))
  expect_equal(clag("Found {1} file{?s}."), cli::pluralize("Found {1} file{?s}."))
  expect_equal(clag("Found {2} file{?s}."), cli::pluralize("Found {2} file{?s}."))

  # Testing with variables
  n_files <- 0
  expect_equal(clag("Found {n_files} file{?s}."), cli::pluralize("Found {n_files} file{?s}."))
  n_files <- 1
  expect_equal(clag("Found {n_files} file{?s}."), cli::pluralize("Found {n_files} file{?s}."))
  n_files <- 10
  expect_equal(clag("Found {n_files} file{?s}."), cli::pluralize("Found {n_files} file{?s}."))

  # Multiple pluralization in same string
  expect_equal(clag("{1} book{?s} and {2} pencil{?s}"), cli::pluralize("{1} book{?s} and {2} pencil{?s}"))
  expect_equal(clag("{2} book{?s} and {1} pencil{?s}"), cli::pluralize("{2} book{?s} and {1} pencil{?s}"))
})

test_that("Singular/plural form handling works", {
  # Simple is/are cases
  expect_equal(clag("There {?is/are} {0} item{?s}."), cli::pluralize("There {?is/are} {0} item{?s}."))
  expect_equal(clag("There {?is/are} {1} item{?s}."), cli::pluralize("There {?is/are} {1} item{?s}."))
  expect_equal(clag("There {?is/are} {10} item{?s}."), cli::pluralize("There {?is/are} {10} item{?s}."))

  # Custom singular/plural forms
  expect_equal(clag("{1} {?man/men} {?walks/walk} fast."), cli::pluralize("{1} {?man/men} {?walks/walk} fast."))
  expect_equal(clag("{2} {?man/men} {?walks/walk} fast."), cli::pluralize("{2} {?man/men} {?walks/walk} fast."))

  # With variables
  n_people <- 1
  expect_equal(clag("There {?is/are} {n_people} {?person/people} waiting."),
    cli::pluralize("There {?is/are} {n_people} {?person/people} waiting."))
  n_people <- 5
  expect_equal(clag("There {?is/are} {n_people} {?person/people} waiting."),
    cli::pluralize("There {?is/are} {n_people} {?person/people} waiting."))

  # Multiple forms in same string
  expect_equal(clag("The {1} {?child/children} {?has/have} {2} {?toy/toys}."),
    cli::pluralize("The {1} {?child/children} {?has/have} {2} {?toy/toys}."))
  expect_equal(clag("The {2} {?child/children} {?has/have} {1} {?toy/toys}."),
    cli::pluralize("The {2} {?child/children} {?has/have} {1} {?toy/toys}."))
})

test_that("Zero/singular/plural form handling works", {
  # Test with literals
  expect_equal(clag("{0} {?no/one/many} cat{?s} found."), cli::pluralize("{0} {?no/one/many} cat{?s} found."))
  expect_equal(clag("{1} {?no/one/many} cat{?s} found."), cli::pluralize("{1} {?no/one/many} cat{?s} found."))
  expect_equal(clag("{2} {?no/one/many} cat{?s} found."), cli::pluralize("{2} {?no/one/many} cat{?s} found."))

  # With variables
  n_cats <- 0
  expect_equal(clag("{n_cats} {?no/one/many} cat{?s} found."), cli::pluralize("{n_cats} {?no/one/many} cat{?s} found."))
  n_cats <- 1
  expect_equal(clag("{n_cats} {?no/one/many} cat{?s} found."), cli::pluralize("{n_cats} {?no/one/many} cat{?s} found."))
  n_cats <- 5
  expect_equal(clag("{n_cats} {?no/one/many} cat{?s} found."), cli::pluralize("{n_cats} {?no/one/many} cat{?s} found."))

  # Complex cases with multiple forms
  expect_equal(clag("You have {0} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."),
    cli::pluralize("You have {0} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."))
  expect_equal(clag("You have {1} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."),
    cli::pluralize("You have {1} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."))
  expect_equal(clag("You have {5} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."),
    cli::pluralize("You have {5} {?no/one/many} {?message/messages}. {?Nothing/It/They} {?is/are} waiting."))
})

test_that("Pluralization works with various input types", {
  # Character that can be coerced to numeric
  expect_equal(clag("Found {'0'} file{?s}."), cli::pluralize("Found {'0'} file{?s}."))
  expect_equal(clag("Found {'1'} file{?s}."), cli::pluralize("Found {'1'} file{?s}."))

  # Logical values
  expect_equal(clag("Found {TRUE} file{?s}."), cli::pluralize("Found {TRUE} file{?s}."))
  expect_equal(clag("Found {FALSE} file{?s}."), cli::pluralize("Found {FALSE} file{?s}."))

  # Vectors (should use length)
  items <- c("apple", "banana")
  expect_equal(clag("Found {length(items)} item{?s}."), cli::pluralize("Found {length(items)} item{?s}."))

  # NA values
  expect_equal(clag("Found {NA} file{?s}."), cli::pluralize("Found {NA} file{?s}."))

  # Other numeric formats
  expect_equal(clag("Found {1.0} file{?s}."), cli::pluralize("Found {1.0} file{?s}."))
  expect_equal(clag("Found {1.5} file{?s}."), cli::pluralize("Found {1.5} file{?s}."))
  expect_equal(clag("Found {0.5} file{?s}."), cli::pluralize("Found {0.5} file{?s}."))

  # Factors
  f <- factor(c("a", "b"))
  expect_equal(clag("Found {length(f)} item{?s}."), cli::pluralize("Found {length(f)} item{?s}."))

  # Edge cases - may need specific tests depending on how cli handles these
  expect_equal(clag("Found {length(numeric(0))} file{?s}."), cli::pluralize("Found {length(numeric(0))} file{?s}."))
  expect_equal(clag("Found {length(character(0))} file{?s}."), cli::pluralize("Found {length(character(0))} file{?s}."))
})

test_that("Pluralization references the correct preceding value", {
  # Make sure pluralization references the immediately preceding value
  expect_equal(clag("There {?is/are} {2} {?box/boxes}."),
    cli::pluralize("There {?is/are} {2} {?box/boxes}."))

  # With multiple values and pluralizations mixed
  x <- 1
  y <- 2
  expect_equal(clag("{x} apple{?s} and {y} orange{?s}"),
    cli::pluralize("{x} apple{?s} and {y} orange{?s}"))

  # Nested expressions
  n1 <- 1
  n2 <- 2
  expect_equal(clag("{if(n1 > 0) n1 else 0} book{?s} and {if(n2 > 0) n2 else 0} pen{?s}"),
    cli::pluralize("{if(n1 > 0) n1 else 0} book{?s} and {if(n2 > 0) n2 else 0} pen{?s}"))
})

test_that("Complex expressions with pluralization work", {
  # With calculated expressions
  expect_equal(clag("Found {2 + 3} file{?s}."), cli::pluralize("Found {2 + 3} file{?s}."))

  # With functions
  get_count <- function() {
    return(1)
  }
  expect_equal(clag("Found {get_count()} file{?s}."), cli::pluralize("Found {get_count()} file{?s}."))

  # With ifelse
  n <- 0
  expect_equal(clag("Found {ifelse(n > 0, n, 'no')} file{?s}."), cli::pluralize("Found {ifelse(n > 0, n, 'no')} file{?s}."))
  n <- 1
  expect_equal(clag("Found {ifelse(n > 0, n, 'no')} file{?s}."), cli::pluralize("Found {ifelse(n > 0, n, 'no')} file{?s}."))

  # With more complex expressions
  counts <- c(1, 0, 2, 3)
  expect_equal(clag("Found {sum(counts)} file{?s}."), cli::pluralize("Found {sum(counts)} file{?s}."))
  expect_equal(clag("Found {length(counts)} count{?s}."), cli::pluralize("Found {length(counts)} count{?s}."))

  # With string manipulation
  text <- "123"
  expect_equal(clag("Found {as.numeric(text)} file{?s}."), cli::pluralize("Found {as.numeric(text)} file{?s}."))
})

test_that("Helper functions no() and qty() work", {
  # no() function
  expect_equal(clag("Found {no(0)} file{?s}."), cli::pluralize("Found {no(0)} file{?s}."))
  expect_equal(clag("Found {no(1)} file{?s}."), cli::pluralize("Found {no(1)} file{?s}."))
  expect_equal(clag("Found {no(2)} file{?s}."), cli::pluralize("Found {no(2)} file{?s}."))

  # qty() function - sets quantity without displaying
  expect_equal(clag("{3}/{10} {qty(3)} file{?s} need updating."), "3/10  files need updating.")
})
