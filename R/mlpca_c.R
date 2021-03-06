#' Maximum likelihood principal component analysis for mode C error conditions
#'
#' @description Performs maximum likelihood principal components analysis for
#'   mode C error conditions (independent errors, general heteroscedastic
#'   case).
#'   Employs ALS algorithm.
#'
#' @param X MxN matrix of measurements
#' @param Xsd MxN matrix of measurements error standard deviations
#' @param p Rank of the model's subspace, p must be than the minimum of M and N
#' @param MaxIter Maximum no. of iterations
#'
#' @return  The parameters returned are the results of SVD on the estimated
#'   subspace. The quantity Ssq represents the sum of squares of weighted
#'   residuals. ErrFlag indicates the convergence condition,
#'   with 0 indicating normal termination and 1 indicating the maximum number of
#'   iterations have been exceeded.
#'
#' @details The returned parameters, U, S and V, are analogs to the
#'   truncated SVD solution, but have somewhat different properties since they
#'   represent the MLPCA solution. In particular, the solutions for different
#'   values of p are not necessarily nested (the rank 1 solution may not be in
#'   the space of the rank 2 solution) and the eigenvectors do not necessarily
#'   account for decreasing amounts of variance, since MLPCA is a subspace
#'   modeling technique and not a variance modeling technique.
#'
#' @references Wentzell, P. D.
#'   "Other topics in soft-modeling: maximum likelihood-based soft-modeling
#'   methods." (2009): 507-558.
#'
#' @export
#'
#' @examples
#'
#' library(RMLPCA)
#' data(data_clean)
#' data(data_error_c)
#' data(sds_c)
#'
#' # data that you will usually have on hands
#' data_noisy <- data_clean + data_error_c
#'
#' # run mlpca_c with rank p = 5
#' results <- RMLPCA::mlpca_c(
#'   X = data_noisy,
#'   Xsd = sds_c,
#'   p = 2
#' )
#'
#' # estimated clean dataset
#' data_cleaned_mlpca <- results$U %*% results$S %*% t(results$V)
mlpca_c <- function(X, Xsd, p, MaxIter = 20000) {
  m <- base::dim(x = X)[1]
  n <- base::dim(x = X)[2]

  if (p > base::min(m, n)) {
    stop("mlpca_c:err1 - Invalid rank for MLPCA decomposition")
  }

  ml <- base::dim(x = Xsd)[1]
  nl <- base::dim(x = Xsd)[2]

  if (m != ml | n != nl) {
    stop("mlpca_c:err2 - Dimensions of data and standard deviations do not matchn")
  }


  if (isFALSE(all(Xsd > 0))) {
    stop("mlpca_c:err3 - Standard deviations must be positive")
  }

  if (isTRUE(any(Xsd == 0))) {
    stop("mlpca_c:err4 - Zero value(s) for standard deviations")
  }

  # Initialization -------------------------------------------------------------


  ConvLim <- 1e-10 # Convergence Limit
  MaxIter <- MaxIter # Maximum no. of iterations
  VarMUlt <- 1000 # Multiplier for missing data
  VarX <- Xsd^2 # Convert sd's to variances
  IndX <- base::which(base::is.na(VarX)) # Find missing values
  VarMax <- base::max(VarX, na.rm = TRUE) # Maximum variance
  VarX[IndX] <- VarMax * VarMUlt # Give missing values large variance

  # Generate Initial estimates assuming homocedastic errors --------------------

  DecomX <- RSpectra::svds(X, p) # Decompose adjusted matrix
  U <- DecomX$u
  S <- base::diag(DecomX$d,
    nrow = base::length(DecomX$d),
    ncol = base::length(DecomX$d)
  )
  V <- DecomX$v

  Count <- 0 # Loop counter
  Sold <- 0 # Holds last value of objective function
  ErrFlag <- -1 # Loop flag

  while (ErrFlag < 0) {
    Count <- Count + 1 # Loop counter

    # Evaluate objective function ----------------------------------------------

    Sobj <- 0 # Initialize sum
    MLX <- base::matrix(
      data = 0,
      nrow = base::dim(X)[1],
      ncol = base::dim(X)[2]
    )

    for (i in 1:n) {
      Q <- base::diag(1 / VarX[, i]) # Inverse of error covariance matrix
      FInter <- base::solve(base::t(U) %*% Q %*% U) # Intermediate calculation
      MLX[, i] <- U %*% (FInter %*% (base::t(U) %*% (Q %*% X[, i]))) # Max.Lik Estimates
      Dx <- base::matrix(data = X[, i] - MLX[, i]) # Residual Vector
      Sobj <- Sobj + base::t(Dx) %*% Q %*% Dx # update objective function
    }


    # Check for convergence or excessive iterations ----------------------------

    if (Count %% 2 == 1) { # check on odd iterations only
      ConvCalc <- base::abs(Sold - Sobj) / Sobj # Convergence Criterion
      if (ConvCalc < ConvLim) {
        ErrFlag <- 0
      }
      if (Count > MaxIter) { # Maximum iterations

        ErrFlag <- 1
        stop("mlpca_c:err5 - Maximum iterations exceeded")
      }
    }

    # Now flip matrices for alternating regression -----------------------------

    if (ErrFlag < 0) { # Only do this part if not done

      Sold <- Sobj # Save most recent objective function
      DecomMLX <- RSpectra::svds(MLX, p) # Decompose Model values
      U <- DecomMLX$u
      S <- base::diag(DecomMLX$d,
        nrow = base::length(DecomMLX$d),
        ncol = base::length(DecomMLX$d)
      )
      V <- DecomMLX$v

      X <- base::t(X) # Flip matrix
      VarX <- base::t(VarX) # And the variances
      n <- base::ncol(X) # Adjust no. of columns
      U <- V # V becomes U in for transpose
    }

    # All done -----------------------------------------------------------------
  }

  DecomFinal <- RSpectra::svds(MLX, p)
  U <- DecomFinal$u
  S <- base::diag(DecomFinal$d,
    nrow = base::length(DecomFinal$d),
    ncol = base::length(DecomFinal$d)
  )
  V <- DecomFinal$v
  Ssq <- Sobj

  result <- base::list(
    "U" = U,
    "S" = S,
    "V" = V,
    "Ssq" = Sobj,
    "ErrFlag" = ErrFlag
  )

  return(result)
}
