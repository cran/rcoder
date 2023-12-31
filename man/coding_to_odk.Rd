% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/interop.R
\name{coding_to_odk}
\alias{coding_to_odk}
\title{Convert a coding object to ODK XLSForm choices}
\usage{
coding_to_odk(coding)
}
\arguments{
\item{coding}{A coding object}
}
\value{
A data.frame or tibble that can be included in an XLSForm 'choices'
        sheet
}
\description{
ODK XLSForms link the categorical codings to a variable type name in the
'survey' sheet. The codings are specified in the 'choices' sheet which has
a `list_name` column that holds the variable type names. Each row that has
that name will be associated with that categorical type coding. This function
converts `coding` objects into tables that can be inserted into that
'choices' sheet. The categorical type is specified with the coding `.label`.
}
\examples{
cdng <- coding(code("Yes", 1), code("No", 0), .label = "yesno")
coding_to_odk(cdng)
}
\seealso{
[odk_to_coding()]
}
