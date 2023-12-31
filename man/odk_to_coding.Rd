% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/interop.R
\name{odk_to_coding}
\alias{odk_to_coding}
\title{Convert ODK choices to a coding}
\usage{
odk_to_coding(choice_table)
}
\arguments{
\item{choice_table}{A data.frame slice of the "choices" table from an
XLSForm}
}
\value{
A `coding` object that corresponds to the choices' slice
}
\description{
ODK XLSForms link the categorical codings to a variable type name in the
'survey' sheet. The codings are specified in the 'choices' sheet which has
a `list_name` column that holds the variable type names. Each row that has
that name will be associated with that categorical type coding. This function
converts subsets of the choices sheet into individual 'coding' objects.
}
\examples{
choice_excerpt <- data.frame(
  list_name = rep("yesno", 2),
  name = c("Yes", "No"),
  label = c(1, 0)
)

odk_to_coding(choice_excerpt)
}
\seealso{
[coding_to_odk()]
}
