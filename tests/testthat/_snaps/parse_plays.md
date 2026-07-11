# parse_plays() requires an event column

    Code
      parse_plays(tibble::tibble(x = 1))
    Condition
      Error in `parse_plays()`:
      ! `plays_data` must contain an event column.
      i Did you extract plays with `get_plays()` first?

