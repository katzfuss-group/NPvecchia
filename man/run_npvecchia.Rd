% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/basic_functions.R
\name{run_npvecchia}
\alias{run_npvecchia}
\title{Wrapper to get the MAP given data}
\usage{
run_npvecchia(
  datum,
  locs,
  corr_order = T,
  tapering_range = 0.4,
  threshh = 0.001,
  max_m = 50,
  init_theta = c(1, -1, 0)
)
}
\arguments{
\item{datum}{an N * n matrix of the data (N replications of n locations/variables)}

\item{locs}{an n*d matrix of data locations(to match input argument of fields::rdist)}

\item{corr_order}{logical flag (defaults to TRUE). If true, uses correlation ordering. Otherwise,
it uses maximin ordering based on locations.}

\item{tapering_range}{Percentage of the maximum distance for Exponential tapering, which
defaults to 0.4 * the maximum distance.}

\item{threshh}{threshold for number of neighbors (for thetas_to_priors); defaults to 1e-3}

\item{max_m}{number of neighbors to compute initially; a maximum number of neighbors possible for
the methodology}

\item{init_theta}{the initialization of the optimization to find the optimal theta}
}
\value{
A list of two elements: 1) u -- a sparse triangular matrix that is the Cholesky of the precision 
matrix \eqn{\Omega} such that \deqn{\Omega = U U'} and 2) the order of the data that was used to 
calculate it (i.e. the reordered data is approximately normal with mean 0 and precision \eqn{\Omega})
}
\description{
This wraps all of the smaller functions into one simple function to compute the MAP estimate of the
upper Cholesky of the precision matrix.
}
