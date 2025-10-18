# Retrosheet Attribution Checklist

This document confirms that Retrosheet attribution appears prominently throughout the package as required.

## Required Notice

Per Retrosheet's terms of use:

> The information used here was obtained free of charge from and is copyrighted by Retrosheet. Interested parties may contact Retrosheet at 20 Sunset Rd., Newark, DE 19711.

## Locations Where Notice Appears

### ✅ Package Loading (Most Prominent)
- **File**: `R/zzz.R`
- **Function**: `.onAttach()`
- **Visibility**: Users see this **every time** they run `library(retrosheetshow)`
- **Format**: Startup message

### ✅ Package Documentation
- **File**: `R/retrosheetshow-package.R`
- **Access**: `?retrosheetshow` or `help(package = "retrosheetshow")`
- **Section**: Dedicated "Retrosheet Data Notice" section
- **Visibility**: Users see when reading package help

### ✅ README (Top of File)
- **File**: `README.md`
- **Location**: Immediately after title, before installation
- **Format**: Prominent blockquote
- **Additional**: Full attribution section later in document
- **Visibility**: First thing users see on GitHub/CRAN

### ✅ NOTICE File
- **File**: `inst/NOTICE`
- **Content**: Full terms of use and attribution
- **Access**: Included in installed package
- **Command**: Users can read with `system.file("NOTICE", package = "retrosheetshow")`

### ✅ CITATION File
- **File**: `inst/CITATION`
- **Access**: `citation("retrosheetshow")`
- **Format**: Footer with notice
- **Visibility**: Users see when citing package

### ✅ Example Scripts
- **File**: `inst/examples/getting_started.R`
- **File**: `inst/examples/gamelogs_rosters_schedules.R`
- **Location**: Top of each file in comment block
- **Visibility**: Users see when reading examples

### ✅ Documentation Files
- **File**: `inst/RETROSHEET_FORMAT.md`
- **File**: `inst/COMPARISON.md`
- **File**: `inst/PERFORMANCE.md`
- **Content**: Attribution mentioned in all data-related docs

## User Experience

When a user interacts with the package, they will see the notice in multiple ways:

1. **First time loading the package**:
   ```r
   library(retrosheetshow)
   # retrosheetshow: Access Retrosheet baseball data
   # 
   # NOTICE: The information used here was obtained free of charge from
   # and is copyrighted by Retrosheet. Interested parties may contact
   # Retrosheet at 20 Sunset Rd., Newark, DE 19711.
   # 
   # Website: https://www.retrosheet.org
   ```

2. **Reading package help**:
   ```r
   ?retrosheetshow
   # Shows dedicated "Retrosheet Data Notice" section
   ```

3. **Citing the package**:
   ```r
   citation("retrosheetshow")
   # Shows notice in footer
   ```

4. **Reading README** (GitHub/CRAN):
   - Notice appears in blockquote immediately after title
   - Full attribution section later in document

5. **Looking at examples**:
   - Notice appears at top of all example scripts

6. **Reading NOTICE file**:
   ```r
   readLines(system.file("NOTICE", package = "retrosheetshow"))
   # Full terms of use
   ```

## Compliance Summary

✅ **Requirement Met**: "...this statement must appear prominently"

The notice appears:
- ✅ At package load (startup message)
- ✅ In package documentation
- ✅ At top of README
- ✅ In standalone NOTICE file
- ✅ In citation
- ✅ In all examples
- ✅ Throughout documentation

## Additional Attribution

The package also:
- Links to Retrosheet website throughout documentation
- Encourages users to support Retrosheet (volunteer/donate)
- Clearly states package is not affiliated with Retrosheet
- Acknowledges Retrosheet volunteers' incredible work

## Testing

To verify the notice appears correctly:

```r
# Install and load package
library(retrosheetshow)  # Should show startup message

# Check package help
?retrosheetshow          # Should show notice in help

# Check citation
citation("retrosheetshow")  # Should show notice in footer

# Check NOTICE file
cat(readLines(system.file("NOTICE", package = "retrosheetshow")), sep = "\n")
```

## Maintenance

When updating the package:
- [ ] Ensure startup message in `.onAttach()` remains unchanged
- [ ] Keep README notice at top
- [ ] Maintain NOTICE file
- [ ] Include notice in any new documentation
- [ ] Add notice to any new example scripts

## Contact

For questions about Retrosheet attribution:
- **Retrosheet**: 20 Sunset Rd., Newark, DE 19711
- **Website**: https://www.retrosheet.org

For questions about this package's implementation:
- File an issue on the package repository

