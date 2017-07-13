smires <- function(x, major = min(minor), minor = intervals$month, drop_na = "group",
                   rule = "start", threshold = 0.001,
                   fun_group = NULL, fun_minor = NULL, fun_major = NULL,
                   fun_total = NULL,
                   state = c("no-flow", "flow"),
                   invar = "duration", outvar = "variable",
                   drop = FALSE, plot = FALSE) {

  state <- match.arg(state, several.ok = TRUE)

  spells <- x %>%
    group_by_interval(major_interval = major, minor_interval = minor) %>%
    find_spells(rule = rule, threshold = threshold) %>%
    arrange(group)

  spells[, "var"] <- spells[, invar]

  if(plot) print(plot_groups(spells))

  y <- spells %>%
    drop_na_periods(period = drop_na) %>%
    arrange(group)

  if(is.function(fun_group)) {
    y <- y %>% group_by(group, minor, major, state) %>%
      summarise(var = fun_group(var))
  }

  if(is.function(fun_minor)) {
    y <- y %>% group_by(minor, state) %>%
      summarise(var = fun_minor(var))
  }

  if(is.function(fun_major)) {
    if(is.function(fun_minor)) {
      stop("You can eihter aggregate by minor interval or major interval, not both.")
    }
    y <- y %>% group_by(major, state) %>%
      summarise(var = fun_major(var))
  }

  if(is.function(fun_total)) {
    y <- y %>% group_by(state) %>%
      summarise(var = fun_total(var))
  }

  y <- y %>%
    rename(!!outvar := var) %>%
    filter(state %in% !!state) %>%
    ungroup()

  if(drop & nrow(y) == 1) y <- unlist(y[, outvar])

  return(y)
}


metric <- function(x, major = min(minor), minor = intervals$month,
                   drop_na = "group", threshold = 0.001,
                   fun_group = NULL, fun_minor = NULL, fun_major = NULL,
                   fun_total = NULL,
                   invar = "discharge", outvar = "variable",
                   drop = FALSE, plot = FALSE) {

  grouped <- x %>%
    group_by_interval(major_interval = major, minor_interval = minor)

  grouped[, "var"] <- grouped[, invar]


  # mutate drops arguments
  maj <- as.numeric(grouped$major)
  grouped$rescaled <- maj + (.rescale(grouped$var) - 0.4)*0.65

  if(plot) print(plot_groups(grouped))

  y <- grouped %>%
    drop_na_periods(period = drop_na)

  if(is.function(fun_group)) {
    y <- y %>% group_by(group, minor, major) %>%
      summarise(var = fun_group(var))
  }

  if(is.function(fun_minor)) {
    y <- y %>% group_by(minor) %>%
      summarise(var = fun_minor(var))
  }

  if(is.function(fun_major)) {
    if(is.function(fun_minor)) {
      stop("You can eihter aggregate by minor interval or major interval, not both.")
    }
    y <- y %>% group_by(major) %>%
      summarise(var = fun_major(var))
  }

  if(is.function(fun_total)) {
    y <- ungroup(y) %>%
      summarise(var = fun_total(var))
  }

  y <- y %>%
    rename(!!outvar := var)%>%
    ungroup()

  if(drop & nrow(y) == 1) y <- unlist(y[, outvar])

  return(y)
}

## metrics suggested in smires project ----

mean_annual_max_duration_dry <- function(x)
{
  y <- metric(x, period = "year", agg1  = "max", agg2 = "mean")
  y$duration[y$state == "no-flow"]
}

mean_annual_number_dry_days <- function(x)
{
  y <- metric(x, period = "year", agg1  = "sum", agg2 = "mean")
  y$duration[y$state == "no-flow"]
}