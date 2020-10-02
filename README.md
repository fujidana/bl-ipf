# bl-ipf
Igor Pro procedures for SPring-8 Kyoto-u beamline, supporting SPEC file format.

## How to load the procedures

1. Put the procedure files in Igor Pro's `User Procedures` folder.
2. Input `#include "SPEC"` in the procedure window and compile it.
3. Drag & Drop the SPEC scan file into Igor Pro window or app icons. Several handy actions are available from "Macros" menu bar item.

This tool expects that the extension of SPEC scan file is ".spec".
The loaded waves is two-dimensional and its first column and last columns are _x_-axis and _y_-axis, respectivly.

The following are sample  code to handle multidimensional waves.

```
// Draw graph manually
Display file_000[][DimSize(file_000, 1) - 1] vs file_000[][0]

// Extract a column and convert it to a normal one-dimensional wave (in the following example, save 0-th column as `file_000_c0`)
Duplicate/O/R=[][0]  file_000, file_000_c0
Redimension/N=-1 file_000_c0
```
