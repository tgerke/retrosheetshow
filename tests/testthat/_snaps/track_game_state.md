# track_game_state() validates its input

    Code
      track_game_state(tibble::tibble(event = "S7"))
    Condition
      Error in `track_game_state()`:
      ! `events_data` must contain game_id, record_type, and line_number.
      i Pass the tibble returned by `get_events()`.

