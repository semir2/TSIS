% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rowmean.R
\name{rowmean}
\alias{rowmean}
\title{Calculate column mean of a matrix or data frame based on a grouping variable}
\usage{
rowmean(x, group, reorder = T, na.rm = T)
}
\arguments{
\item{x}{a matrix or data frame.}

\item{group}{a vector of factor giving grouping, with one element per row of x.}

\item{reorder}{if TRUE, then the result will be in order of \code{sort(unique(group))}.}

\item{na.rm}{logical (TRUE or FALSE). Should NA (including NaN) values be replaced by value 0?}
}
\value{
\code{rowmean} returns a matrix or data frame containing the means. There
will be one row per unique value of group.
}
\description{
Compute column means across rows of a numeric matrix-like object for each level
of a grouping variable.
}
\examples{
x <- matrix(runif(50), ncol = 5)
group <- sample(1:4, 10, TRUE)
xmean <- rowmean(x, group)

}
\seealso{
\code{\link{rowsum}}, \code{\link{rowratio}}
}
