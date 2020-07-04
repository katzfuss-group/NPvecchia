
<!-- README.md is generated from README.Rmd. Please edit that file -->

# NPVecchia

<!-- badges: start -->

<!-- badges: end -->

The goal of NPVecchia is to provide users with scalable Gaussian Process
(GP) covariance estimation without assuming its form. We assume that the
GP is de-trended (has zero mean) and that the covariance between points
decreases with distance. Importantly, since this method was developed
for spatial data, we also assume that the locations of the samples are
known and in a low dimensional Euclidean space. The final output of the
methods provided in this package is a sparse estimate of the inverse of
the Cholesky of the covariance matrix. It provides some of the barebones
functionality to accompany an upcoming paper with Dr. Katzfuss.

Many of the functions have C++ counterparts by adding "\_c" to their
names. However, there is no error checking, so errors that occur tend to
be difficult to interpret and fix. That is the big use for the R
versions: to understand the functions and usage better (with
error-checking) before worrying about speed.

## Installation

You can install the development version from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("the-kidd17/NPVecchia", auth_token = "10a6d01e1d65ff744e39674cb07c5fe257320e69")
```

# Detailed Example

## Data Creation

As a first step to experimenting with the package, data must be
simulated. These examples will be on a 2-D grid, though the method
generalizes to random (ungridded) data. We use a unit square as the
domain for simplicity; by changing the range (also known as scale)
parameter in spatial covariance functions, the data can be rescaled to a
unit square.

``` r
#seed for reproducibility
set.seed(1128)
#number of points
n <- 30^2
#Get the grid in 1-D
grd <- seq(0, 1, length.out = sqrt(n))
#expand to 2-D grid
grd2d <- expand.grid(grd, grd)
#Alternative for random (non-gridded) data
#grd2d <- matrix(runif(2 * n), ncol = 2)
```

#### Ordering

It is recommended to use the provided function “orderMaxMinFast” to
order the data in a max-min ordering. Basically, this ordering starts at
a point in the center, then adds points one at a time that maximize the
minimum distance from all previous points in the ordering. While not
required, the decay of the both the regression errors and coefficients
(i.e. the prior) was specifically developed based on this ordering.

``` r
#Order the grid points
order_mmd <- orderMaxMinFast(grd2d, n^2)
grd2d_ordered <- grd2d[order_mmd, ]
```

#### Covariance Function

Now, with the locations, a covariance function is needed. As is common
in spatial, this example will create a Matern covariance matrix. The
package doesn’t rely on functions for using other covariance matrices,
but two useful packages for other covariance functions are ‘geoR’ and
‘RandomFields’.

``` r
#get distances between points
distances <- fields::rdist(grd2d_ordered)

# #If one wants anisotropic distances instead
# mahala_dist <- function(a, b, Aniso_matrix) {
#   sqrt(c(t(a - b) %*% solve(Aniso_matrix, a - b)))
# }
# mahala_dist_vect <- Vectorize(mahala_dist)
# grd2d_ord_list <- as.list(data.frame(t(grd2d_ordered)))
# dists <- outer(grd2d_ord_list, grd2d_ord_list, mahala_dist_vect, 
#                Aniso_matrix = matrix(c(0.5, 0, 0, 1), ncol = 2))

#Specify parameters of the covariance matrix
marginal_variance <- 3
#for unit square, range < 0.5 is recommended to avoid numerical issues
range <- 0.25
#smoothness should similarly not be too large
smoothness <- 1

#create the true covariance matrix
covar_true <- marginal_variance * fields::Matern(distances, range = range, 
                                         nu = smoothness)

#Number of replications
N <- 50
#Create data (can use any multivariate normal function)
datum <- MASS::mvrnorm(N, rep(0, nrow(covar_true)), covar_true)
```

#### Nearest neighbors

Also needed are the nearest neighbors for each point. This only needs to
be done once, so it is useful to allow the number of neighbors to be
large (it will often be decreased automatically by the method). This
outputs a matrix where each row corresponds to that points’ nearest
neighbors (ordered from closest to furthest; NAs fill other spots). Our
methodology does not include each point as a neighbor of itself, so the
first column (that gives each point) is removed.

**Note**: if using an Anisotropic and/or non-stationary covariance, the
ordering and/or neighborhood selection will not be optimal without
accounting for it. Below the function for simply finding neighbors by
spatial distance are the extensions for finding ordering and neighbors
using the tapered sample covariance matrix (using correlation ordering).

``` r
#get nearest neighbors
NNarray <- GpGp::find_ordered_nn(grd2d_ordered, 40)
#Remove points as own neighbors
NNarray <- NNarray[, -1]
```

``` r
#Finds new coorelation ordering based on locations and data
order_cmmd <- order_mm_tapered(grd2d_ordered, datum)
#Reorders data and locations to match the correlation ordering
datum <- datum[, order_cmmd]
grd2d_ordered <- grd2d_ordered[order_cmmd, ]
#Tapering can 
NNarray <- find_nn(grd2d_ordered, datum, 40)
```

## Methodology

To keep the explanation simple, we estimate the Cholesky of the
precision matrix using a series of simple linear regressions. The twist
is that we only regress on the nearest neighbors spatially to
drastically improve the computational cost. The frequentist version is
“get\_mle”, which performs the regressions with a known sparsity
pattern to find the sparse matrix Û such that

![equation](https://latex.codecogs.com/png.latex?%5CSigma%5E%7B-1%7D%20%3D%20%5Chat%7BU%7D%20%5Chat%7BU%7D%27)

``` r
uhat_mle <- get_mle(datum, NNarray)
#Or to decrease the number of neighbors
uhat_mle <- get_mle(datum, NNarray[, 1:9])
```

The Bayesian version is more involved, but adds a prior to further
regularize the non-zero elements. See the [Math
vignette](documents/math.pdf) for the mathematical details of the
method. The priors on all of the regressions rely on 3 hyperparameters
that can be optimized for the best results. To avoid numerical
instabilities, it is recommended to force the hyperparameters to be in
the range \[-6,4\]. The simplest way to find the best hyperparameters is
to optimize the integrated log-likelihood as shown below.

**Note:** Another alternative is to use MCMC to get a distribution on
the hyperparameters. This is very sensitive to inputs, is often not
computationally feasible, and is not included. If one is set on MCMC,
“adaptMCMC” is an easy to use package that includes an adaptive
Metropolis-Hastings algorithm. It improves mixing and adaptively
accounts for our correlated hyperparameters.

``` r
#define initialize thetas (starting values)
thetas_init <- c(1, -1, 0)

thetas_best <- optim(thetas_init, minus_loglikeli_c, datum = datum,
                     NNarray = NNarray, method = "L-BFGS-B",
                     lower = -6, upper = 4)
show(thetas_best)
#> $par
#> [1]  2.1129281 -1.9891448 -0.1982231
#> 
#> $value
#> [1] 28376.37
#> 
#> $counts
#> function gradient 
#>       20       20 
#> 
#> $convergence
#> [1] 0
#> 
#> $message
#> [1] "CONVERGENCE: REL_REDUCTION_OF_F <= FACTR*EPSMCH"
```

With these optimal hyperparameters, it is straightforward to get Û as
follows:

``` r
#get priors
priors_final <- thetas_to_priors(thetas_best$par, n)
show(paste("The method found", ncol(priors_final[[3]]), "neighbors to be sufficient."))
#> [1] "The method found 8 neighbors to be sufficient."
#get posteriors
posteriors <- get_posts(datum, priors_final, NNarray)
#get uhat
uhat <- samp_posts(posteriors, NNarray)
```

## Evaluation

To see the difference, we can evaluate Stein’s loss (the exclusive
Kullback-Leibler divergence). It is defined as

![equation](https://latex.codecogs.com/png.latex?KL%28%5Chat%7B%5CSigma%7D%20%7C%7C%20%5CSigma%29%20%3D%20tr%28%5Chat%7B%5CSigma%7D%20%5CSigma%5E%7B-1%7D%29%20-%20log%20%7C%5Chat%7B%5CSigma%7D%5CSigma%5E%7B-1%7D%7C%20-%20n)

When the number of neighbors is high, the “MLE” version of Û is not
invertible, so some care is needed in choosing \(m < N\) for the
frequentist method. Alternatively, the regressions can be replaced with
some sort of lasso to ensure smaller \(m\).

``` r
covar_true_inv <- solve(covar_true)
get_kl <- function(uhat, covar_inv) {
  # get sigma hat
  sigma_hat <- crossprod(solve(uhat, tol= 1e-35))
  # get sigma hat * sigma inv 
  cov2 <- sigma_hat %*% covar_inv
  # get its determinant
  cov_det <- determinant(cov2)
  return((sum(diag(cov2)) - as.numeric(cov_det$modulus) - n))
}
show(paste("The KL-divergence for our method is", get_kl(uhat, covar_true_inv),
           " while it is", get_kl(uhat_mle, covar_true_inv), "for the MLE."))
#> [1] "The KL-divergence for our method is 60484.5877033228  while it is 83340.5404194815 for the MLE."
```

Another alternative to avoid having to invert the Cholesky is to use the
frobenius norm (or other metric, such as singular value differences) to
compare the estamates to the true precision matrix.

``` r
precision_frobenius <- function(uhat, covar_inv) {
  # get estimated precision
  precision_hat <- Matrix::tcrossprod(uhat)
  sqrt(sum((precision_hat - covar_inv)^2))
}
show(paste("The Frobenius norm for our method is", precision_frobenius(uhat, covar_true_inv),
           " while it is", precision_frobenius(uhat_mle, covar_true_inv), "for the MLE."))
#> [1] "The Frobenius norm for our method is 1278.10578412761  while it is 1652.12060536677 for the MLE."
```
