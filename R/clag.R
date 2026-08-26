#' Create a transformer function for clag processing
#'
#' @param values Environment to store state for pluralization
#' @return A function that can be used as a glue transformer
#' @noRd
create_clag_transformer <- function(values) {
  # TODO:
  #   New format: "{formatter expr [params]}"
  #     .inline: any cli inline markup or any crayon command (preceded with dot).
  #              expr is treated as plain text. To work with expressions
  #              (including other formatters), place within `{}`
  #                "{.red the cat sat on the mat}"
  #                foo <- "the cat sat on the mat"
  #                "{.emph {foo}}"
  #     ?:       cli-style pluralisation. expr is treated as text unless it is
  #              placed within `{}`.
  #                - {? s}: length(x) > 1
  #                - {? cat/cats} length(x) == 1/length(x) > 1
  #                - {? no/cat/cats} length(x) == 0/length(x) == 1/length(x) > 1
  #                - {? no/cat/2 cats/more cats} length(x) ==0/length(x) == 1/length(x) == 2/length(x) > 2 (can be extended to arbitrary length)
  #                - {? cat/cats [var]} var defines the variable to use to choose pluralisation. Useful where it is not clear from context.
  #     -:      bullet list
  #     1.:     ordered list
  #     - [ ]:  todo list
  #     #:      Render expr as a markdown table. expr must be a dataframe or
  #             coerciable into one (eg. a matrix or list).
  #               - Models should be rendered as summary tables via
  #                 `report`/`modelsummary`/`gtsummary`?
  #     %:      Render as plot. For dataframes or things coerciable into them,
  #             use: ggplot2::qplot() with first two columns.
  #             For models use `report`/`modelsummary`
  #     %%:     Render as plot using `GGally::ggpairs()`.
  #     <xml>:  <yaml>/<dl> maybe some others????
  #     &:      Combine with 'and'
  #     |:      Combine with 'or'
  #     !:      Embed file(s) using names as titles
  #     $:      Latex maths - convert [asciimaths](https://asciimath.org/) to
  #             LaTeX (inline) - also have a look at [mathup](https://mathup.xyz/)
  #     $$:     asciimaths to Latex maths block
  #     >:      evaluate expr directly via glue
  #     None:
  #              - If existing filepath(s), embed file.
  #              - If simple vector combine with 'and' (like `cli`)
  #                {c(1,2,3)}: "1, 2 and 3"
  #                {c(1,2,3) [last = "or"]} "1, 2, or 3"
  #              - If ggplot, plot, graphics object, insert image
  #              - If dataframe/coerciable to dataframe print as markdowntable
  #              - If model print summary with `report::report`
  #              - If none of the above, pass directly to glue
  #              - To use special characters without formatter leave a space as
  #                the first character:
  #                - "{.emph * 2}": '* 2' with the .emph formatter
  #                - "{ .emph * 2}: The object `.emph` multiplied by 2.
  #
  # ISSUES:
  #   - some formats treat `expr` as text and require secondary level brackets for
  #     objects, while others expect `expr` to be an object. This is potentially
  #     confusing
  #   - params is possibly a bit unclear.
  #   - Not sure about <xml>
  function(code, envir) {
    ##############################
    ### direct glue expression ###
    ##############################
    if (substr(code, 1, 1) == "!") {
      expr_text <- trimws(substr(code, 2, nchar(code)))

      # Actually evaluate the expression instead of using glue on it
      result <- tryCatch(
        eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
        error = function(e) {
          warning("Failed to evaluate {!", expr_text, "}: ", e$message)
          return(NULL)
        }
      )

      # Return the result directly
      if (is.null(result)) return("")
      return(as.character(result))
      ###############################
      ### pluralization directive ###
      ###############################
    } else if (substr(code, 1, 1) == "?") {
      # The most recent expression sets the quantity
      if (identical(values$qty, values$empty)) {
        values$postprocess <- TRUE
        id <- uuid::UUIDgenerate()
        values$pmarkers[[id]] <- code
        return(id)
      } else {
        return(process_plural(make_quantity(values$qty), code))
      }
      ###########################
      ### Markdown formatters ###
      ###########################
    } else if (stringr::str_detect(code, "^[-\\+\\*=:\\d].+$")) {
      # Update quantity for pluralization
      values$num_subst <- values$num_subst + 1

      ####################
      ### bullet lists ###
      ####################
      if (substr(code, 1, 1) %in% c("-", "*", "+")) {
        #################
        ### todo list ###
        #################
        todo <- stringr::str_extract(code, "^[-\\+\\*]\\s{0,1}\\[(.){0,1}\\]\\s+(.+)$", group = c(1, 2))
        if (!(is.na(todo)[[2]])) {
          checkbox  <- ifelse(is.na(todo[[1]]), " ", todo[[1]])
          expr_text <- stringr::str_trim(todo[[2]])
          expr      <- tryCatch(
            eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
            error = function(e) {
              warning("Failed to evaluate {", expr_text, "}: ", e$message)
              return(NULL)
            }
          )
          # Create bullet vector
          if (!is.null(names(expr)) && all(nchar(names) %in% c(1, 0))) {
            names(expr) <- purrr::map_chr(
              names(expr),
              \(name) {
                if (name == "") {
                  glue::glue("{substr(code, 1, 1)} [{checkbox}]")
                } else {
                  glue::glue("{substr(code, 1, 1)} [{name}]")
                }
              })
          } else names(expr) <- glue::glue("{substr(code, 1, 1)} [{rep(checkbox, length(expr))}]")
        } else {
          ############################
          ### standard bullet list ###
          ############################
          expr_text <- stringr::str_trim(substr(code, 2, nchar(code)))
          expr      <- tryCatch(
            eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
            error = function(e) {
              warning("Failed to evaluate {", expr_text, "}: ", e$message)
              return(NULL)
            }
          )
          if (!is.null(expr)) names(expr) <- rep(substr(code, 1, 1), length(expr))
        }
        values$qty <- expr
        if (is.null(expr)) {
          return("")
        } else {
          return(glue_vec(expr, .item = "{.name} {.item}", .sep = "\n", .last = "\n"))
        }
        #####################
        ### ordered lists ###
        #####################
      } else if (stringr::str_detect(substr(code, 1, 1), "\\d")) {
        bullet    <- stringr::str_extract(
          code,
          "^(\\d+)(\\S)*\\s+(.+)$",
          group = c(1, 2, 3))
        n         <- as.numeric(bullet[[1]]) - 1
        delim     <- ifelse(bullet[[2]] == "", ".", bullet[[2]])
        if (is.na(bullet[[3]])) {
          cli::cli_abort("Failed to evaluate {code}")
        } else expr_text <- stringr::str_trim(bullet[[3]])
        expr <- tryCatch(
          eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
          error = function(e) {
            warning("Failed to evaluate {", expr_text, "}: ", e$message)
            return(NULL)
          }
        )
        values$qty <- expr
        if (is.null(expr)) {
          return("")
        } else {
          names(expr) <- rep(paste0(n, delim), length(expr))
          return(glue_vec(expr, .item = "{as.numeric(stringr::str_extract(.name, '^\\\\d+')) + .i}{stringr::str_extract(.name, '^\\\\d+(.+)$', group = 1)} {.item}", .sep = "\n", .last = "\n"))
        }
        #######################
        ### Definition list ###
        #######################
        # TODO: is there a better option than '='? ':'? '<dl>'?
        # TODO: Find all items that have the same name and combine them so that
        #   the output is:
        #       foo
        #       :   bar
        #       :   baz
        #   instead of:
        #       foo
        #       :   bar
        #       foo
        #       :   baz
      } else if (substr(code, 1, 1) == "=") {
        expr_text <- trimws(substr(code, 2, nchar(code)))
        expr <- tryCatch(
          eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
          error = function(e) {
            warning("Failed to evaluate {", expr_text, "}: ", e$message)
            return(NULL)
          }
        )
        values$qty <- expr
        if (is.null(expr)) return("")

        if (is.null(names(expr)) || any(names(expr) == "")) {
          stop("Definition lists require named vectors")
        }
        return(glue_vec(expr, .item = "{.name}\n:    {.item}", .sep = "\n", .last = "\n"))
        ############
        ### YAML ###
        ############
        # TODO: Think of a better option than ':'. Possibly '<yaml>'
        # Like definition lists, combine items that have the same name.
      } else if (substr(code, 1, 1) == ":") {
        expr_text <- trimws(substr(code, 2, nchar(code)))
        expr <- tryCatch(
          eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
          error = function(e) {
            warning("Failed to evaluate {", expr_text, "}: ", e$message)
            return(NULL)
          }
        )
        values$qty <- expr
        if (is.null(expr)) return("")

        if (is.null(names(expr)) || any(names(expr) == "")) {
          stop("YAML formatting requires named vectors")
        }
        return(glue_vec(expr, .item = "{.name}: {.item}", .sep = "\n", .last = "\n",
          .vec = "---\n{.vec}\n---"))
      }
    }

    # Check for alternative joining (or instead of and)
    if (grepl("^\\|\\s+.+", code)) {
      expr_text <- trimws(substr(code, 2, nchar(code)))
      expr <- tryCatch(
        eval(parse(text = expr_text, keep.source = FALSE), envir = envir),
        error = function(e) {
          warning("Failed to evaluate {", code, "}: ", e$message)
          return(NULL)
        }
      )

      # Update quantity for pluralization
      values$num_subst <- values$num_subst + 1
      values$qty <- expr

      if (is.null(expr)) return("")

      # Format with 'or' instead of 'and'
      return(glue_vec(expr, .last = " or "))
    }

    # For normal expressions
    values$num_subst <- values$num_subst + 1

    # Evaluate the expression
    expr <- tryCatch(
      eval(parse(text = code, keep.source = FALSE), envir = envir),
      error = function(e) {
        warning("Failed to evaluate {", code, "}: ", e$message)
        return(NULL)
      }
    )

    # Update quantity for pluralization - this is key
    values$qty <- expr

    if (is.null(expr)) return("")

    # Special handling for different object types
    if (inherits(expr, "data.frame")) {
      return(pander::pandoc.table.return(expr, justify = "left", style = "multiline"))
    }

    if (inherits(expr, "ggplot")) {
      tmp <- tempfile(fileext = ".png")
      ggplot2::ggsave(tmp, expr, width = 7, height = 5)
      return(paste0("![](", tmp, ")"))
    }

    # Handle qty_marker objects (returned by qty() function)
    if (inherits(expr, "qty_marker")) {
      return("")
    }

    # Use our own vector formatting for everything else
    return(glue_vec(expr))
  }
}

#' Format text with glue syntax, vector formatting, and pluralization
#'
#' @param text Text template with glue-style interpolation
#' @param ... Additional values to use for interpolation
#' @param .envir Environment for evaluation
#' @return Formatted text
#' @export
#' @examples
#' name <- "World"
#' clag("Hello, {name}!")
#'
#' # Pluralization
#' n_files <- 0
#' clag("Found {n_files} file{?s}.")
#' n_files <- 1
#' clag("Found {n_files} file{?s}.")
#'
#' # Vector formatting
#' fruits <- c("apples", "bananas", "oranges")
#' clag("I like {fruits}.")
clag <- function(text, ..., .envir = parent.frame()) {
  # Environment to store state for pluralization
  values <- new.env(parent = emptyenv())
  values$empty <- uuid::UUIDgenerate()
  values$qty <- values$empty
  values$num_subst <- 0L
  values$postprocess <- FALSE
  values$pmarkers <- list()

  # Create a transformer function that handles our special markup
  transformer <- create_clag_transformer(values)

  # Process with glue
  raw <- glue::glue(text, .envir = .envir, .transformer = transformer)

  # Post-process pluralization markers
  if (values$postprocess) {
    raw <- post_process_plurals(raw, values)
  }

  return(raw)
}
