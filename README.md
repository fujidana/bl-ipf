# bl-ipf

Igor Pro procedure files that help a user handle two-dimensional (2D) data arrays whose rows represent time or scan steps and columns represent data channels.

The script was originally developed for SPring-8 Kyoto University beamline users to handle __spec__ data files.
However, it may be useful for data analysis of other multi-channel data.

## Features

* Supported formats:
  * __spec__ standard data file format (`.spec`, `.dat`): scan data created by __spec__ software
  * text-based 1D diffraction/scattering profile (`.dat`, `.txt`): files created by `dipolar.py`, a Python script that creates a 1D profiles from a two-dimensional detector image.
  * MCA array data, in which each row consists of numbers delimited by a whitespace or a tab. The `dp5` macro counter in BL28XU/BL32B2 outputs spectral of Amptek SDD dvices in this format. Note that this file format is different from a `.mca` file Amptek's DppMCA.exe exports.
* Main features:
  * Load files in the above-mentioned formats as two-dimensional (2D) waves.
  * Display a graph for waves selected in the data browser.
  * Combine multiple 2D waves.
  * Extract specified rows of multiple 2D waves.

## How to load the procedures

1. Put `bl-ipf` folder, which contains the procedure files, in Igor Pro's _User Procedures_ folder.
1. Open the procedure window (Win: `Ctrl+M`, Mac: `Cmd+M`), type `#include "SPEC"` and compile it.
1. Then several handy actions are available from "Macros" menu in the menubar. One can _drag and drop_ a SPEC scan file (`.spec`) into Igor Pro window or app icons. Most functions work on selected waves in _Data Browser_. Data browser can be opened from "Data / Data Browser" menubar item (Win: `Ctrl+B`, Mac: `Cmd+B`).

A loaded wave by this scripts is a two dimensional wave whose first column and last column are by default treated as _x_-axis and _y_-axis, respectively.
This behavior can be changed from "Macros" menu.

## Tips

### Single-row data file

This procedure internally calls Igor Pro's built-in `LoadWave` operation function to load waves from a file.
While `LoadWave` equips variety of options and is fast enough, it can not recognize a data block consisting of a single row as a wave (IOW, two or more lines are necessary to be loaded by `LoadWave`).

This kind of single-row data block is typically created by a __spec__ command such as `dscan 0 0 0 1`.
The procedure author added a workaround in which a file is parsed more primitively without using `LoadWave`.
This workaround may be slower than the default behavior that uses `LoadWave` but can load a file containing single-row data blocks.
To activate it, add `#define SPEC_LOAD_ONE_ROW_DATA_FILE` in the procedure window (Win: `Ctrl+M`, Mac: `Cmd+M`).

### Multi-dimensional wave

This script loads and handles a set of data as a 2D wave.
It may be a bit more difficult for Igor Pro beginners to use a 2D wave than a conventional 1D wave.
For their convenience, a few pieces of commands that handle 2D waves are written below.

```igorpro
// Draw graph from 2D wave manually
Display file_000[][DimSize(file_000, 1) - 1] vs file_000[][0]


// Extract a column and convert it to a normal one-dimensional wave.
// There are several methods to do so. Below two of thems are shown.

// Method 1: extract 0-th column of 2D wave `file_000` as `file_000_col0`
Duplicate/O/R=[][0]  file_000, file_000_col0
Redimension/N=-1 file_000_col0

// Method 2: extract 0-th column of 2D wave `file_000` as W_ExtractedRow
ImageTransform/G=0 getRow file_000
```
