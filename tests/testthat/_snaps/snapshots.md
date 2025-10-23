# gamelog_fields produces stable output

    Code
      fields <- gamelog_fields()
      cat("Number of fields:", nrow(fields), "\n")
    Output
      Number of fields: 161 
    Code
      cat("First 5 fields:\n")
    Output
      First 5 fields:
    Code
      print(head(fields, 5))
    Output
      # A tibble: 5 x 2
        field_name      description                             
        <chr>           <chr>                                   
      1 date            Date (YYYYMMDD)                         
      2 game_number     Game number (0=single, 1-2=doubleheader)
      3 day_of_week     Day of week                             
      4 visiting_team   Visiting team                           
      5 visiting_league Visiting team league                    

# list_events with invalid type produces clear error

    Code
      list_events(year = 2024, type = "invalid")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "regular", "allstar", "post"

