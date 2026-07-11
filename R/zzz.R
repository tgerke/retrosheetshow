# Retrosheet requires this notice to be displayed prominently
#' @noRd
.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "retrosheetshow: Access Retrosheet baseball data\n",
    "\n",
    "NOTICE: The information used here was obtained free of charge from\n",
    "and is copyrighted by Retrosheet. Interested parties may contact\n",
    "Retrosheet at 20 Sunset Rd., Newark, DE 19711.\n",
    "\n",
    "Website: https://www.retrosheet.org"
  )
}
