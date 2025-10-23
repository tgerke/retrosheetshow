# Helper functions for tests

# Check if we have internet connection
skip_if_offline <- function() {
  if (!has_internet()) {
    skip("No internet connection")
  }
}

# Simple internet check
has_internet <- function() {
  tryCatch({
    url_exists("https://www.retrosheet.org")
  }, error = function(e) {
    FALSE
  })
}

