bl-ipf
====

Igor Pro procedure files for SPring-8 Kyoto University beamline.

Features
----

* Supported files:
  * spec standard data file format (`.spec`, `.dat`): scan data created by __spec__ software
  * text-based 1D diffraction/scattering profile (`.dat`, `.txt`): files created by `dipolar.py`, a Python script that creates a 1D profiles from a two-dimensional detector image.
* Main features:
  * Load files in the above-mentioned formats as two-dimensional waves.
  * Display a graph for waves selected in data browser.
  * Combine multiple profiles into a single two-dimensional wave.

How to load the procedures
----

1. Put `bl-ipf` folder, which contains the procedure files, in Igor Pro's `User Procedures` folder.
2. Input `#include "SPEC"` in the procedure window and compile it.
3. Then several handy actions are available from "Macros" menu bar item. One can _drag and drop_ a SPEC scan file (`.spec`) into Igor Pro window or app icons.

A loaded wave by this scripts is two-dimensional and its first column and last columns are by default treated as _x_-axis and _y_-axis, respectivly.

Tips
----

This scripts load and handle data as two-dimensional waves.
It may be a bit more difficult for Igor Pro beginners to use them than a conventional one dimensional wave.
The followings are some examples that directly use the two-diimensional waves.

```igorpro
// Draw graph from 2D wave manually
Display file_000[][DimSize(file_000, 1) - 1] vs file_000[][0]

// Extract a column and convert it to a normal one-dimensional wave (in the following example, save 0-th column as `file_000_col0`)
Duplicate/O/R=[][0]  file_000, file_000_col0
// At this moment, `file_000_col0` is a 2D wave consisting of (N x 1) points. Convert it it 1D wave consisting of N points.
Redimension/N=-1 file_000_col0
```
