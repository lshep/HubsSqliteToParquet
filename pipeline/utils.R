fail_if <- function(condition, message) {
  if (isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

assert_non_empty <- function(df, name) {
  fail_if(nrow(df) == 0, paste0(name, " is empty"))
}

assert_no_na <- function(x, name) {
  fail_if(any(is.na(x)), paste0("NA values detected in ", name))
}

assert_file_exists <- function(path, message = NULL) {
  fail_if(!file.exists(path),
          message %||% paste0("Missing file: ", path))
}

assert_equal <- function(a, b, message) {
  fail_if(!identical(a, b), message)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b


assert_query_positive <- function(con, sql, name) {
  val <- dbGetQuery(con, sql)[[1]]
  fail_if(all(val == 0), paste0(name, " returned zero rows"))
}

assert_row_count_match <- function(con, table1, table2, msg = NULL) {
  a <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", table1))$n
  b <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", table2))$n

  fail_if(
    a != b,
    msg %||% paste0("Row mismatch: ", table1, " vs ", table2)
  )
}

assert_no_orphans <- function(con, table, column, msg = NULL) {
  n <- dbGetQuery(con, paste0("
    SELECT COUNT(*) AS n
    FROM ", table, "
    WHERE ", column, " IS NULL
  "))$n

  fail_if(n > 0, msg %||% paste0("Orphans detected in ", table))
}
