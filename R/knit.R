#' Custom knit function for clag processing
#'
#' This function reads the raw document, processes clag expressions,
#' and passes the result to the appropriate rendering function.
#'
#' @param input Input file path
#' @param output Output file path (or NULL)
#' @param envir Environment for evaluation
#' @param ... Additional arguments to pass to rmarkdown::render or quarto_render
#'
#' @return The result of the rendering process
#' @export
clag_knit <- function(input, output = NULL, envir = parent.frame(), ...) {
  # Record original working directory to restore later
  original_wd <- getwd()
  on.exit(setwd(original_wd), add = TRUE)

  # Read input file
  content <- readLines(input, warn = FALSE)
  text <- paste(content, collapse = "\n")

  # Detect if we're in a Quarto document
  is_quarto <- detect_quarto_document(text)

  # Process document with clag expressions
  processed_text <- process_clag_expressions(text, envir, is_quarto)

  # Get input file directory and base name
  input_dir <- dirname(input)
  input_base <- basename(input)
  base_name <- tools::file_path_sans_ext(input_base)

  # Create temporary directory to work in
  temp_dir <- tempfile("clag_temp_")
  dir.create(temp_dir)

  # Write the processed text to a temporary file in the temp directory
  temp_file <- file.path(temp_dir, input_base)
  writeLines(processed_text, temp_file)

  # Create an environment that has access to the clag functions
  eval_env <- new.env(parent = envir)
  eval_env$clag <- clag  # Make clag function available
  eval_env$glue_vec <- glue_vec
  eval_env$no <- no
  eval_env$qty <- qty

  # Determine the output file path
  if (is.null(output)) {
    # If output not specified, use the same basename but in the current directory
    output_ext <- if (is_quarto) "html" else "html"
    output <- file.path(original_wd, paste0(base_name, ".", output_ext))
  }

  # Go to temp directory for rendering
  setwd(temp_dir)

  tryCatch({
    if (is_quarto) {
      # Use quarto rendering
      result <- quarto::quarto_render(input_base, output_file = output, ...)
    } else {
      if (requireNamespace("rmarkdown", quietly = TRUE)) {
        # If the output file is a markdown file, just use knitr
        if (!is.null(output) && grepl("\\.md$", output)) {
          result <- knitr::knit(input_base, output, envir = eval_env, ...)
        } else {
          # Use rmarkdown rendering for HTML and other formats
          # Use output_dir to ensure file is created in a predictable location
          result <- rmarkdown::render(
            input = input_base,
            output_file = basename(output),
            output_dir = dirname(output),
            output_format = "all",
            envir = eval_env,
            ...
          )

          # Double-check the result exists
          if (!file.exists(result)) {
            warning("Rendered file not found at: ", result)
          }
        }
      } else {
        # Fall back to knitr::knit if rmarkdown isn't available
        result <- knitr::knit(input_base, output, envir = eval_env, ...)
        warning("Package 'rmarkdown' is not available. Only producing markdown output.")
      }
    }

    # If we got a result, verify the file exists
    if (is.character(result) && !file.exists(result)) {
      # Try to find it in the temp directory
      temp_result <- file.path(temp_dir, basename(result))
      if (file.exists(temp_result)) {
        # If found in temp, copy to the expected location
        file.copy(temp_result, result, overwrite = TRUE)
      } else {
        warning("The rendered output file was not found at: ", result)
      }
    }

    result
  }, finally = {
    # Restore original working directory (also covered by on.exit)
    setwd(original_wd)
  })
}
# clag_knit <- function(input, output = NULL, envir = parent.frame(), ...) {
#  # Read input file
#  content <- readLines(input, warn = FALSE)
#  text <- paste(content, collapse = "\n")
#
#  # Detect if we're in a Quarto document
#  is_quarto <- detect_quarto_document(text)
#
#  # Process document
#  processed_text <- process_clag_expressions(text, envir, is_quarto)
#
#  # Write to temporary file
#  temp_file <- tempfile(fileext = ".Rmd")
#  writeLines(processed_text, temp_file)
#
#  if (is_quarto) {
#    result <- quarto::quarto_render(temp_file, output_file = output, ...)
#  } else {
#    result <- knitr::knit(temp_file, output, ...)
#  }
#
#  return(result)
# }

#' @export
#' @rdname clag_knit
clag_render <- function(input, ...) {
  clag_knit(input, ...)
}

#' Process clag expressions in a document
#'
#' @param text Document text
#' @param envir Environment for evaluation
#' @param is_quarto Are we modifying a quarto document
#' @param test_env Optional test environment for testing
#' @return Processed text
#' @noRd
process_clag_expressions <- function(text, envir = parent.frame(), is_quarto, test_env = NULL) {
  # Helper function to format expressions for R Markdown or Quarto
  format_expr <- function(expr, is_quarto) {
    if (is_quarto) paste0("{{", expr, "}}") else paste0("`r ", expr, "`")
  }

  # Extract trailing newlines
  trailing_newlines <- ""
  if (grepl("\n$", text)) {
    # Count trailing newlines using direct iteration (most reliable method)
    n_count <- 0
    for (i in nchar(text):1) {
      if (substr(text, i, i) == "\n") {
        n_count <- n_count + 1
      } else {
        break
      }
    }
    trailing_newlines <- paste(rep("\n", n_count), collapse = "")
  }

  # Remove trailing newlines before processing
  text_trimmed <- if (nchar(trailing_newlines) > 0) {
    substr(text, 1, nchar(text) - nchar(trailing_newlines))
  } else {
    text
  }

  # Process line by line
  lines <- strsplit(text_trimmed, "\n", fixed = TRUE)[[1]]
  processed_lines <- character(length(lines))

  for (i in seq_along(lines)) {
    line <- lines[i]
    expr_pattern <- "\\{\\{([^{}]*)\\}\\}"
    expr_matches <- gregexpr(expr_pattern, line, perl = TRUE)

    if (expr_matches[[1]][1] == -1) {
      processed_lines[i] <- line
      next
    }

    # Extract all expressions from the line
    all_exprs <- regmatches(line, expr_matches)[[1]]
    expr_contents <- gsub("\\{\\{([^{}]*)\\}\\}", "\\1", all_exprs)

    # Create a substitution mapping
    original_to_clag <- list()
    for (j in seq_along(all_exprs)) {
      original_to_clag[[all_exprs[j]]] <- paste0("{", expr_contents[j], "}")
    }

    # Replace all original expressions with clag-style expressions
    modified_line <- line
    for (orig in names(original_to_clag)) {
      modified_line <- gsub(orig, original_to_clag[[orig]], modified_line, fixed = TRUE)
    }

    # Escape quotes with the same approach for both formats
    escaped_line <- gsub('"', '\\"', modified_line, fixed = TRUE)

    # Wrap the entire line in a single clag call
    clag_call <- paste0('clag::clag("', escaped_line, '")')

    # Format for R Markdown or Quarto
    processed_lines[i] <- format_expr(clag_call, is_quarto)
  }

  # Combine processed lines and add trailing newlines back
  result <- paste(processed_lines, collapse = "\n")
  return(paste0(result, trailing_newlines))
}
