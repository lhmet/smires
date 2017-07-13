intervals <- list(
  week = structure((0:51) * 7 + 1, .Names = paste0("w", 1:52)),

  month = structure(c(1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335),
                    .Names = month.abb),

  twoSeasons = structure(c(60, 244), .Names = c("summer", "winter")),

  fourSeasons = structure(c(60, 152, 244, 335),
                          .Names = c("spring", "summer", "autumn", "winter")))


twoSeasons <- c("summer" = as.Date("2015-03-01"),
                "winter" = as.Date("2015-09-01"))

start_season <- function(x)
{
  n <- names(x)

  if(is.null(n)) {
    n <- paste0("S", seq_along(x))
    warning("Seasons should have meaningful, unambiguous names.")
  }

  if(anyDuplicated(names(x)) | "" %in% names(x)) {
    n <- make.names(names(x), unique = TRUE)
    warning("Seasons should have meaningful, unambiguous names.")
  }

  day <- .date2julian(x)
  names(day) <- n

  return(day)
}



drop_na_periods <- function(x, period = group_vars(x))
{

  period <- setdiff(period, c("state", "discharge"))
  if(length(period) == 0) {
    warning("Not grouped by period.")
    return(x)
  }

  period <- match.arg(arg = period,
                      choices = c("group", "minor", "major"),
                      several.ok = TRUE)

  if(!period %in% colnames(x)) stop("Period not present in data.")

  # todo: use get_vars()
  # todo: instead of deleting the spells, set value to NA to visualise missingness in plot
  var <- intersect(colnames(x), c("state", "discharge"))
  nas <- x[is.na(x[, var]), period]

  # todo: anti_joins reverses row order...
  y <- suppressMessages(anti_join(x, nas))

  return(y)
}

correct_leapyear <- function(x)
{
  x <- as.Date(x)
  day <- yday(x)

  wrong <- .is_leapyear(x) & day >= 60
  if(any(wrong)) {
    # we are in a leap year and after Feb 28th
    warning("Date falls into a leap year. Using the previous day.")
    x[wrong] <- x[wrong] - 1
  }

  return(x)
}


yday2 <- function(x, correct_leapyear = TRUE)
{
  if(is.instant(x)) {
    x <- as.Date(x)

    if(correct_leapyear) x <- correct_leapyear(x)
    day <- yday(x)

  } else if(is.numeric(x) &&  x <= 365 && x > 0) {
    day <- x
  } else {
    stop("Argument 'x' must be eihter of class Date or an integer in [1, 365]")
  }

  return(day)
}


hydrological_year <- function(x, start = 1)
{
  x <- as.Date(x)
  start <- yday2(start)

  y <- year(x)
  j <- yday(x)
  mask <- j < start
  y[mask] <- y[mask] -1

  y <- factor(y, levels = full_seq(y, period = 1), ordered = TRUE)
  return(y)
}


group_by_interval <- function(.data, minor_interval = intervals$month,
                              major_interval = min(minor_interval))
{
  if (!is.numeric(major_interval) || length(major_interval) != 1) {
    stop("Currently, only years are supported for major intervals.")
  }

  if (is.numeric(major_interval) && is.numeric(minor_interval)) {
    idx <- match(major_interval, minor_interval)
    if(is.na(idx)) {
      candidate <- names(head(sort(abs(minor_interval - major_interval)), 2))
      stop("Major intervals must align with minor intervals.",
           " Minor interval does not contain: ", major_interval, "\n",
           "Consider choosing ", paste(shQuote(minor_interval[candidate]),
                                       collapse = " or "), ". ")
    }
  }

  int <- list(minor = minor_interval, major = major_interval)

  # major periods can only be years or hydrological years
  .data$major <- hydrological_year(.data$time, start = major_interval)


  # assign minor period
  day <- yday(.data$time)
  pos <- rowSums(outer(day, as.numeric(minor_interval), FUN = ">="))
  pos[pos == 0] <- length(minor_interval)
  n <- length(minor_interval)
  lvls <- names(minor_interval)[(seq(idx-1, length.out = n) %% n) + 1]
  .data$minor <- factor(names(minor_interval)[pos], levels = lvls, ordered = TRUE)

  int$minor <- int$minor[lvls]
  int[["minor_hday"]] <- date2hday(int$minor, start = major_interval)

  # update minor interval with correct order
  .data <- set_attr_smires(.data, "interval", int)

  # use integer arithmetic to get unique group numbers
  # todo: test if group_indices() is faster
  grp <- with(.data, as.numeric(minor) + as.numeric(major) * 100)
  .data$group <- as.numeric(factor(grp))

  # in leap years, feb 28th occurs twice
  .data$hday <- date2hday(.data$time, start = major_interval)

  # store interval in attributes
  tbl <- ungroup(.data) %>%
    select(major, minor, group) %>%
    distinct()
  .data <- set_attr_smires(.data, "group_interval", tbl)

  return(.data)
}

