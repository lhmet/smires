# repeatedly oberserving a low value?

# extract dt
.dt <- function(x) {
  dt <- .get_attr_smires(x, "dt")
  if(is.null(dt)) dt <- median(diff(x$time))

  return(as.period(dt))
}

.guess_deltat <- function(x)
{
  dt <- diff(x)
  dtMed <- median(dt)

  if(dtMed != min(dt) & dtMed <= 7)
    # this logic doesn't work or montly data, February can have 29 days
    stop("Unable to derive dt from time series due to gaps. ")

  units(dtMed) <- "days"

  dt <- if(dtMed == 1) {
    "day"
  } else if(dtMed == 7) {
    "week"
  } else if(dtMed %in% 30:31) {
    "month"
  } else {
    stop("Unable to derive dt from time series, median dt is probably larger than 31 days.")
  }

  return(dt)
}

# just checking the index, ignoring discharges which are NA
.missing_indices <- function(x)
{
  d <- as.numeric(diff(x), unit = "days")
  if(median(d) > 7) {
    # quick check if length of month is plausible
    # todo: correctly determine number of months between two dates
    # https://stackoverflow.com/questions/1995933/number-of-months-between-two-dates/1996404
    sum(!d %in% 28:31)
  } else {
    sum(d < median(d))
  }
}

.fill_na <- function(x, max.len = Inf, warn = TRUE, ...)
{
  # copied from lfstat
  g <- .spell(is.na(x), as.factor = FALSE)
  rl <- rle(g)
  len <- rep(rl$lengths, rl$lengths)

  # indices, for which interpolation is required
  idx <- seq_along(x)[is.na(x) & len <= max.len]
  x[idx] <- approx(seq_along(x), x, xout = idx, rule = 2, ...)$y

  if(length(idx))
    message(sum(diff(idx) > 1) + 1, " gaps (", length(idx),
            " obsevations) were filled using linear interpolation.")

  return(x)
}

.make_ts_regular <- function(x, interval = .guess_deltat(x$time))
{
  # modified from drought2015
  x <- x[!is.na(x$time), ]

  fullseq <- seq(from = min(x$time), to = max(x$time), by = interval)
  missing <- fullseq[!fullseq %in% x$time]

  if(length(missing)) {
    l <- c(list(time = missing), list(NA_real_)[rep(1, ncol(x) - 1)])
    names(l) <- colnames(x)
    gaps <- as.data.frame(l)
    x <- rbind(x, gaps, make.row.names = FALSE)
    x <- x[order(x$time), ]
    rownames(x) <- NULL
  }

  return(x)
}


.msg_ratio <- function(value, total, text)
{
  if(value) {
    perc <- round(value / total, 3) * 100
    perc <- if(perc < 0.01) "< 0.01" else perc
    message("The time series contains ", value, " ", text, " (", perc, " %).",
            sep = "")
  }
}

validate <- function(x, minyear = 10, approx.missing = 5, accuracy = 0,
                     warn = TRUE)
{
  # we agreed on keeping the accuracy argument but
  # checking for negative values explicitly

  # make sure, columns are of correct class
  x$time <- as.Date(x$time)
  x$discharge <- as.numeric(x$discharge)

  # check for NA in time index
  bad <- which(is.na(x$time))
  if(length(bad)){
    stop("Invalid time index at position: ", paste(bad, collapse = ", "))
  }


  # remove complete duplicates and order time series
  x <- unique(x)
  x <- x[order(x$time), ]

  dt <- .guess_deltat(x$time)

  total <- nrow(x)
  .msg_ratio(sum(duplicated(x$time)), total, text = "duplicated indices")

  .msg_ratio(.missing_indices(x$time), total,
             text = "missing indices, it is not regular")

  # todo: dt should be of class 'duration'
  x <- .make_ts_regular(x, interval = dt)
  total <- nrow(x)
  x$discharge <- .fill_na(x$discharge, max.len = approx.missing)


  if(warn){

    if (accuracy > 0)
    {
      nthres <- sum(abs(x$discharge - accuracy) < sqrt(.Machine$double.eps),
                    na.rm = TRUE)
      txt <- paste0("observations equal to the measurement accuracy of '",
                    accuracy, "'")
      .msg_ratio(nthres, total, txt)

      txt <- paste0("observations below the measurement accuracy of '",
                    accuracy, "'")
      .msg_ratio(sum(x$discharge < accuracy, na.rm = TRUE), total, txt)
    }


    nzero <- sum(abs(x$discharge) < sqrt(.Machine$double.eps), na.rm = TRUE)
    txt <- paste0("observations equal to zero")
    .msg_ratio(nzero, total, txt)

    txt <- paste0("observations with a negative discharge. Setting them to NA.")
    negative <- which(x$discharge < 0)
    .msg_ratio(length(negative), total, txt)
    x$discharge[negative] <- NA

    # todo: allow a certain fraction of  missing observations eg na.ratio = 0.2
    .msg_ratio(sum(is.na(x$discharge)), total, text = "missing observations")

    # todo: requirements regarding length of record?
    len <- round(as.numeric(diff(range(x$time)), unit = "days") / 365, 1)
    if(len < minyear)
    {
      message("Time series covers only ", len, " years. A minimum length of ",
              minyear, " years is advised.")
    }

  }

  x <- as_data_frame(x)
  attr_smires(x) <- list("dt" = as.period(1, dt))
  return(x)
}

check_ts <- validate