#' Catalog the categorical data representation in a vector
#'
#' A `coding` object holds a list of `code`s that map vector values to human
#' readable labels. An abstraction of factors, this data structure is designed
#' to be portable and not directly attached to the underlying data. Moreover,
#' `coding` objects can be "linked" for recoding and data lineage purposes. An
#' "empty coding" is used to represent data that has no categorical
#' interpretation.
#'
#' @param ... A collection of `code` objects
#' @param .label A label for this coding, available for interoperability
#' @return A `coding` object that contains each `code` input
#'
#' @export
#' @examples
#' coding(code("Yes", 1), code("No", 0), code("Not applicable", NA))
#' empty_coding()
coding <- function(..., .label = NULL) {
  if (missing(..1)) {
    return(empty_coding())
  }

  codes <- list(...)

  if (!all(vlapply(codes, function(x) inherits(x, "code")))) {
    rc_err("coding() only accepts code objects as arguments.")
  }

  loc_labels <- lapply(
    seq_along(codes),
    function(i) list(index = i, label = codes[[i]]$label)
  )
  labels <- vcapply(loc_labels, function(x) x$label)

  if (any(duplicated(labels))) {
    rc_err("Multiple labels set in a single coding. Each label must be unique.")
  }

  values <- lapply(codes, function(x) x$value)
  values_check <- values[!is.na(values)]

  # Case where all values are missing
  if (length(values_check) < 1) {
    values_check <- values[is.na(values)]
  }

  if (!all(vcapply(values_check, typeof) == typeof(values_check[[1]]))) {
    rc_err(c(
      "Coding types must be constant.\n",
      "Perhaps you forgot to wrap your numbers in quotes?"
    ))
  }

  locations <- viapply(loc_labels, function(x) x$index)
  names(locations) <- labels

  structure(
    codes,
    class = "coding",
    labels = locations,
    label = .label
  )
}

#' @rdname coding
#' @export
empty_coding <- function() {
  structure(
    list(),
    class = "coding",
    labels = integer()
  )
}

#' Is an object the empty coding?
#'
#' @param x An object
#' @return TRUE/FALSE if the object is identical to `empty_coding()`
#' @export
#' @examples
#' is_empty_coding(empty_coding())
#' is_empty_coding(coding())
#' is_empty_coding(coding(code("Yes", 1), code("No", 0)))
is_empty_coding <- function(x) {
  identical(x, empty_coding())
}

is_coding <- function(x) inherits(x, "coding")

labels.coding <- function(x, ...) attr(x, "labels", exact = TRUE)

select_codes_if <- function(.coding, .p, ...) {
  rc_assert(is_coding(.coding) && is.function(.p))

  matching_codes <- vlapply(.coding, function(.x) .p(.x, ...))

  if (sum(matching_codes) < 1) {
    return(empty_coding())
  }

  sub_coding <- .coding[matching_codes]
  do.call(coding, sub_coding)
}

select_codes_by_label <- function(.coding, .labels) {
  rc_assert(is.character(.labels))

  select_codes_if(.coding, function(code) code$label %in% .labels)
}

coding_values <- function(coding) {
  stopifnot(is_coding(coding))

  if (is_empty_coding(coding)) {
    return(logical())
  }

  unlist(lapply(coding, function(code) code$value))
}

#' Get missing codes from a coding
#'
#' Takes a coding a returns a new coding
#' with all codes that represent a missing value.
#'
#' @param coding a coding
#' @return A coding that contains all missing codes.
#'   If no codes are found, returns `empty_coding()`
#' @export
#' @examples
#' missing_codes(coding(code("Yes", 1), code("No", 0), code("Missing", NA)))
#' missing_codes(coding(code("Yes", 1), code("No", 0)))
missing_codes <- function(coding) {
  rc_assert(is_coding(coding))

  if (is_empty_coding(coding)) {
    return(coding)
  }

  select_codes_if(coding, function(code) isTRUE(code$missing))
}

coding_contents <- function(coding) {
  if (is_empty_coding(coding)) {
    return(list(
      links = character(),
      labels = character(),
      values = logical(), # To reflect total absence of data
      descriptions = character()
    ))
  }

  dfs <- lapply(coding, as.data.frame)
  content <- dplyr::bind_rows(!!!dfs)
  content[["link"]] <- content[["links_from"]]
  content[["links_from"]] <- NULL

  content <- content[, c("link", setdiff(names(content), "link"))]
  content
}

coding_label <- function(coding) {
  attr(coding, "label", exact = TRUE)
}

#' @export
as.data.frame.coding <- function(x,
                                 row.names = NULL, # nolint
                                 optional = NULL,
                                 suffix = NULL,
                                 ...) {
  out <- coding_contents(x)

  if (!is.null(suffix)) {
    stopifnot(is.character(suffix) || is_positive_integer(suffix))
    names(out) <- ifelse(
      names(out) == "link",
      names(out),
      paste0(names(out), "_", suffix)
    )
  }

  out
}

#' @export
print.coding <- function(x, ...) {
  if (is_empty_coding(x)) {
    cat_line("<Empty Coding>")

    return(invisible())
  }

  if (!is.null(coding_label(x))) {
    cat_line("<Coding: '{coding_label(coding)}'>")
  } else {
    cat_line("<Coding>")
  }

  print(dplyr::as_tibble(as.data.frame(x)))

  invisible()
}

#' @export
as.character.coding <- function(x, include_links_from = FALSE, ...) {
  code_calls <- lapply(x, function(code) {
    if (is.integer(code$value)) {
      code$value <- as.numeric(code$value)
    }

    cmd <- rlang::call2("code", code$label, code$value)

    if (isTRUE(code$missing)) {
      cmd[["missing"]] <- TRUE
    }

    if (!identical(code$links_from, code$label) && isTRUE(include_links_from)) {
      cmd[["links_from"]] <- rlang::call2("c", !!!code$links_from)
    }

    if (!identical(code$description, code$label)) {
      cmd[["description"]] <- code$description
    }

    cmd
  })

  coding_call <- rlang::call2("coding", !!!code_calls)
  out <- rlang::expr_deparse(coding_call, width = 50000L)

  # Sometimes there are very long codings, like a whole system's
  # worth of schools. (2023-06-22)
  if (length(out) > 1) {
    out <- paste0(out, collapse = "")
  }

  out
}

#' Evaluates a coding expression in a safe environment
#'
#' To prevent requiring attaching the `rcoder` package, this function takes in
#' an unevaluated expression -- assumed to be a `coding()` call -- and evaluates
#' the expression with _only_ `coding` and `code` provided to guard against
#' rogue code.
#'
#' @param expr An expression
#' @return An evaluated `coding` object
#' @export
#' @examples
#' eval_coding('coding(code("Yes", 1), code("No", 0))')
eval_coding <- function(expr) {
  rc_assert(rlang::is_expression(expr))

  safe_env <- rlang::new_environment(parent = parent.frame())
  rlang::env_bind(safe_env, code = code, coding = coding)

  rlang::eval_bare(expr, env = safe_env)
}
