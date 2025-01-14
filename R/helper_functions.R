#' Wrapper for data creation
#' 
#' Improves readability for data creation rather than having to call mvrnorm each time. Also, 
#' there are many alternatives to mvrnorm in R, which isn't important for the package usefulness.
#' Lastly, I was curious to see how internal functions work, as it is "good coding practice."
#'
#' @param covar_true covariance matrix (must be symmetric and positive definite)
#' @param N number of replications
#'
#' @return an N * n matrix with each row corresponding to a replication of all covariates/locations
#' @keywords internal
#' 
.create_data <- function(covar_true, N) {
  
  # Lazy creation of data
  datum <- mvrnorm(N, rep(0, nrow(covar_true)), covar_true)
  return(datum)
}