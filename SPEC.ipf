#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0

//#include "SFView_MCPlot"
#include "SPEC_IO"


/// Module to handle SPEC scan data.
///
/// The file extension of scan files should be ".spec".
/// Written by So Fujinami.
/// Tested by Igor Pro 8.0 on macOS.


Static StrConstant ksScanFileFilter = "spec scan data file (*.spec):.spec;"
Static StrConstant ks1dFileFilter   = "spec 1D data file (*.dat,.txt):.dat,.txt;"
Static StrConstant ksXasFileFilter  = "PF 9809 XAS data file (*.xas):.xas;"
Static StrConstant ksAllFileFilter  = "All Files:*;"


Menu "Load Waves"
	"Load SPEC Scan Files...", /Q, SPEC_openSpecFileDialog()
	"Load 1D Files...",        /Q, SPEC_open1DFileDialog()
	"Load XAS Files...",       /Q, SPEC_openXasFileDialog()
End

Menu "Macros"
	"(Load Waves"
	"Load SPEC Scan Files...", /Q, SPEC_openSpecFileDialog()
	"Load 1D Files...",        /Q, SPEC_open1DFileDialog()
	"Load XAS Files...",       /Q, SPEC_openXasFileDialog()
	"-"
	"(Data Browser"
	"Display Selection Separately", /Q, SPEC_doActionForDataBrowser(2)
	"Display Selection Together", /Q, Display; SPEC_doActionForDataBrowser(4)
	"Append Selection", /Q, SPEC_doActionForDataBrowser(4)
	"Join Columns of Selection...", /Q, SPEC_doActionForDataBrowser(8)
// End
// Menu "Macros", dynamic
// 	SPEC_getMenuItem(0), /Q, SPEC_doActionForDataBrowser(2)
// 	SPEC_getMenuItem(1), /Q, Display; SPEC_doActionForDataBrowser(4)
// 	SPEC_getMenuItem(2), /Q, SPEC_doActionForDataBrowser(4)
	"-"
	"(Graphs"
	"Reselect Columns of Traces...", /Q, SPEC_reselectColumnDialog()
	"Join Traces in a 2D Wave...", /Q, SPEC_joinTracesDialog("")
	"Fancy Traces...", /Q, SPEC_fancyTrancesDialog()
	"-"
	"(Other"
	"Configure SPEC Macro Behavior...", /Q, SPEC_configDialog()
	"Display Columns of 2D Wave Together...", /Q, SPEC_multicolDisplayDialog()
End


// Function/S SPEC_getMenuItem(i)
// 	Variable i
	
// 	String tmpStr = ""
// 	if (strlen(GetBrowserSelection(-1)) == 0)
// 		tmpStr = "("
// 	endif
// 	switch(i)
// 		case 0:
// 			tmpStr += "Display Data Browser Selection Separately"
// 			break
// 		case 1:
// 			tmpStr += "Display Data Browser Selection Together"
// 			break
// 		case 2:
// 			tmpStr += "Append Data Browser Selection"
// 			break
// 		default:
// 			tmpStr += "INVALID ARGUMENTS"
// 	endswitch
// 	return tmpStr
// End

/// @brief Hook function invoked when a file is dragged onto the Igor Pro icon.
Static Function BeforeFileOpenHook(refNum, fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr, fileKind)
	Variable refNum, fileKind
	String fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr
	
	// it must return 1 in order to prevent Igor from trying to load the file in a built-in manner.
	String extension = ParseFilePath(4, fileNameStr, ":", 0, 0)
	if (fileKind == 0 && stringmatch(extension, "spec"))
		return (SPEC_loadSpecScanFile(fileNameStr, pathNameStr) == 0)
//	elseif (fileKind == 7 && stringmatch(extension, "dat"))
//		return (SPEC_loadSpec1DFile(fileNameStr, pathNameStr) == 0)
	else
		return 0
	endif
End

/// @brief Show a Open Dialog for a SPEC file.
Function SPEC_openSpecFileDialog()
	Variable i, refNum, errno
	String fileFilter, fileNameList
	fileFilter = ksScanFileFilter + ks1dFileFilter + ksAllFileFilter
	Open/D/R/MULT=1/F=fileFilter refNum
	errno = 0
	fileNameList = S_fileName

	if (strlen(fileNameList) == 0) // User cancel
		return -1
	endif

	for (i = 0; i < ItemsInList(fileNameList, "\r"); i += 1)
		if (SPEC_loadSpecScanFile(StringFromList(i, fileNameList, "\r"), "") != 0)
			errno += 1
		endif
	endfor
	
	return errno
End

/// @brief Show a Open Dialog for a Text file.
Function SPEC_open1DFileDialog()
	Variable i, refNum, errno
	String fileFilter, fileNameList
	fileFilter = ks1dFileFilter + ksAllFileFilter
	Open/D/R/MULT=1/F=fileFilter refNum
	errno = 0
	fileNameList = S_fileName

	if (strlen(fileNameList) == 0) // User cancel
		return -1
	endif

	for (i = 0; i < ItemsInList(fileNameList, "\r"); i += 1)
		if (SPEC_load1DFile(StringFromList(i, fileNameList, "\r"), "") != 0)
			errno += 1
		endif
	endfor
	
	return errno
End

/// @brief Show a Open Dialog for a XAS file.
Function SPEC_openXasFileDialog()
	Variable i, refNum, errno
	String fileFilter, fileNameList
	fileFilter = ksXasFileFilter + ksAllFileFilter
	Open/D/R/MULT=1/F=fileFilter refNum
	errno = 0
	fileNameList = S_fileName

	if (strlen(fileNameList) == 0) // User cancel
		return -1
	endif

	for (i = 0; i < ItemsInList(fileNameList, "\r"); i += 1)
		if (SPEC_loadXasFile(StringFromList(i, fileNameList, "\r"), "") != 0)
			errno += 1
		endif
	endfor
	
	return errno
End



/// @brief Load a SPEC scan file.
Function SPEC_loadSpecScanFile(filePath, symbPath)
	String filePath, symbPath
	
	if (strlen(symbPath))
		printf "[SPEC@%s] Loading SPEC scan file: \"%s\" @ %s\r", time(), filePath, symbPath
	else
		printf "[SPEC@%s] Loading SPEC scan file: \"%s\"\r", time(), filePath
	endif

	WAVE/WAVE/Z fww = SPEC_IO_loadSpecScanFile(filePath, symbPath)
	if (!WaveExists(fww))
		return 1
	endif
	
	if (numpnts(fww) == 1)
		printf "[SPEC@%s] 1 scan dataset was loaded.\r", time()
	else
		printf "[SPEC@%s] %d scan dataset were loaded.\r", time(), numpnts(fww)
	endif
	
	// Postprocess (optionally draw graphs).
	Variable action = NumVarOrDefault("SV_postprocess", 5)
	doActionSubroutine(fww, action)

	return 0
End


/// @brief Load a SPEC 1D file.
Function SPEC_load1DFile(filePath, symbPath)
	String filePath, symbPath
	
	if (strlen(symbPath))
		printf "[SPEC@%s] Loading 1D file: \"%s\" @ %s\r", time(), filePath, symbPath
	else
		printf "[SPEC@%s] Loading 1D file: \"%s\"\r", time(), filePath
	endif
	
	WAVE/Z fw = SPEC_IO_load1DFile(filePath, symbPath)
	if (!WaveExists(fw))
		print "Error in loading data part."
		return -1
	endif
	
	printf "[SPEC@%s] 1D wave was loaded.\r", time()
	
	Make/FREE/WAVE/N=1 fww
	fww[0] = fw

	// Postprocess (optionally draw graphs).
	Variable action = NumVarOrDefault("SV_postprocess", 5)
	doActionSubroutine(fww, action)

	return 0
End


/// @brief Load a PF 9809 XAS file.
Function SPEC_loadXasFile(filePath, symbPath)
	String filePath, symbPath
	
	if (strlen(symbPath))
		printf "[SPEC@%s] Loading XAS file: \"%s\" @ %s\r", time(), filePath, symbPath
	else
		printf "[SPEC@%s] Loading XAS file: \"%s\"\r", time(), filePath
	endif
	
	WAVE/Z fw = SPEC_IO_loadXasFile(filePath, symbPath)
	if (!WaveExists(fw))
		print "Error in loading data part."
		return -1
	endif
	
	printf "[SPEC@%s] XAS wave was loaded.\r", time()
	
	Make/FREE/WAVE/N=1 fww
	fww[0] = fw

	// Postprocess (optionally draw graphs).
	Variable action = NumVarOrDefault("SV_postprocess", 5)
	doActionSubroutine(fww, action)

	return 0
End



/// @brief Show a dialog to select postprocess action.
Function SPEC_configDialog()
	Variable postprocess, xCol, yCol
	
	postprocess = NumVarOrDefault("SV_postprocess", 5)
	xCol        = NumVarOrDefault("SV_xCol", 0)
	yCol        = NumVarOrDefault("SV_yCol", -1)
	Prompt postprocess, "Post-loading Action", popup, "Display last scan;Display all scans;Append last scan;Append All Scans;Do nothing;"
	Prompt xCol, "Column Index for x-axis (0 by Default)"
	Prompt yCol, "Column Index for y-axis (-1 by Default)"
	DoPrompt "Postprocess postprocess", postprocess, xCol, yCol
	if (V_flag != 0) // cancel
		return V_flag
	endif
	Variable/G SV_postprocess = postprocess
	Variable/G SV_xCol        = xCol
	Variable/G SV_yCol        = yCol
	
	return 0
End


/// @brief Do action to waves selected in the data browser.
Function SPEC_doActionForDataBrowser(option)
	Variable option

	if (strlen(GetBrowserSelection(-1)) == 0)
		printf "[SPEC@%s] Data browser is not open.\r", time()
		Beep
		return 1
	endif
	
	Variable i, j
	String tmpStr
	i = 0
	j = 0
	Make/WAVE/N=0/FREE fww
	do
		tmpStr = GetBrowserSelection(i)
		if (strlen(tmpStr) == 0)
			break
		elseif (WaveExists($tmpStr) && WaveDims($tmpStr) == 2 && (WaveType($tmpStr) & 0x02 || WaveType($tmpStr) & 0x04))
			Redimension/N=(j + 1) fww
			fww[j] = $tmpStr
			j += 1
		endif
		i += 1
	while (1)
	
	printf "[SPEC@%s] %d waves were handled from %d selection in data browser.\r", time(), j, i
	
	if (numpnts(fww) > 0)
		doActionSubroutine(fww, option)
	endif
	
	return 0
End


/// @brief Show a dialog to reselect column indexes of traces.
Function SPEC_reselectColumnDialog()
	String graphNameStr, graphListStr = WinList("*", ";", "WIN:1")
	if (strlen(graphListStr) == 0)
		DoAlert 0, "No graph window found."
		return 1
	endif
	graphNameStr = StringFromList(0, graphListStr)
	
	Variable i, n, xCol, yCol, xCol2, yCol2
	String traceNameStr, traceListStr
	
	xCol = NumVarOrDefault("SV_xCol", 0)
	yCol = NumVarOrDefault("SV_yCol", -1)
	
	// 0x01: normal graph traces, 0x04: omit hidden traces
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x04)
	n = ItemsInList(traceListStr)
	Prompt xCol, "Column Index for x-axis (0 by Default)"
	Prompt yCol, "Column Index for y-axis (-1 by Default)"
	DoPrompt "Reselect columns of Traces in " + graphNameStr, xCol, yCol
	if (V_flag != 0) // cancel
		return V_flag
	endif
	
	for (i = 0; i < n; i += 1)
		traceNameStr = StringFromList(i, traceListStr)
		WAVE/Z xWave = XWaveRefFromTrace(graphNameStr, traceNameStr)
		WAVE/Z yWave = TraceNameToWaveRef(graphNameStr, traceNameStr)
		
		if (WaveExists(xWave) && WaveDims(xWave) == 2)
			xCol2 = xCol >= 0 ? xCol : DimSize(xWave, 1) + xCol
			ReplaceWave/X trace=$(traceNameStr), xWave[][xCol2]	
		endif
		if (WaveExists(yWave) && WaveDims(yWave) == 2)
			yCol2 = yCol >= 0 ? yCol : DimSize(yWave, 1) + yCol
			ReplaceWave trace=$(traceNameStr), yWave[][yCol2]	
		endif
	endfor
End



/// @brief Show a dialog for fancy traces.
Function SPEC_fancyTrancesDialog()
	String graphNameStr, graphListStr = WinList("*", ";", "WIN:1")
	if (strlen(graphListStr) == 0)
		DoAlert 0, "No graph window found."
		return 1
	endif
	graphNameStr = StringFromList(0, graphListStr)
	
	Variable cycle, reversed, xOffset, yOffset, xMultiplier, yMultiplier
	String colorTableStr
	colorTableStr = "Rainbow"
	cycle = 0
	reversed = 1
	xMultiplier = 1
	yMultiplier = 1
	Prompt colorTableStr, "Color Table", popup, CTabList()
	Prompt cycle, "Number of Traces per Coloring Cycle"
	Prompt reversed, "Reversed Coloring", popup, "NO;YES;"
	Prompt xOffset, "Horizontal Offset per Trace"
	Prompt yOffset, "Vertical Offset per Trace"
	Prompt xMultiplier, "Horizontal Multiplier per Trace"
	Prompt yMultiplier, "Vertical Multiplier per Trace"
	DoPrompt "Fancy Traces in " + graphNameStr, xOffset, yOffset, xMultiplier, yMultiplier, colorTableStr, cycle, reversed
	if (V_flag != 0) // cancel
		return V_flag
	endif
	reversed -= 1
	
	ColorTab2Wave $colorTableStr
	WAVE M_colors
	
	Variable i, n, red, green, blue
	String traceListStr
	// 0x01: normal graph traces, 0x04: omit hidden traces
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x04)
	n = ItemsInList(traceListStr)
	
	if (cycle == 0)
		cycle = n
	endif
	
	Make/N=(cycle, 3)/U/I/FREE M_colors2
	M_colors2 = interp2d(M_colors, p / (cycle - 1) * (DimSize(M_colors, 0) - 1), q)
	
	
	if (reversed)
		ImageTransform flipRows, M_colors2
	endif
	
	for (i = 0; i < n; i += 1)
		red   = M_colors2[mod(i, cycle)][0]
		green = M_colors2[mod(i, cycle)][1]
		blue  = M_colors2[mod(i, cycle)][2]
		ModifyGraph/W=$(graphNameStr) rgb($StringFromList(i, traceListStr))=(red, green, blue)
		ModifyGraph/W=$(graphNameStr) offset($StringFromList(i, traceListStr))={xOffset * i, yOffset * i}
		if (xMultiplier == 1 && yMultiplier == 1)
			ModifyGraph/W=$(graphNameStr) muloffset($StringFromList(i, traceListStr))={0, 0}
		else
			ModifyGraph/W=$(graphNameStr) muloffset($StringFromList(i, traceListStr))={xMultiplier^i, yMultiplier^i}
		endif
		
	endfor

	return 0
End


/// @brief show graphs.
Static Function doActionSubroutine(inww, option)
	WAVE/WAVE inww
	Variable option
	
	Variable i, n
	
	Variable xCol, yCol
	xCol = NumVarOrDefault("SV_xCol", 0)
	yCol = NumVarOrDefault("SV_yCol", -1)
	n = numpnts(inww)
	
	if (n == 0)
		return 1
	endif
	
	if (option == 1) // display last	
		display2DWave(inww[n - 1], xCol, yCol)
	elseif (option == 2)  // display all
		for (i = 0; i < n; i += 1)
			display2DWave(inww[i], xCol, yCol)
		endfor
	elseif (option == 3) // append last
		// create an empty window if no graph window exists.
		if (strlen(WinList("*", ";", "WIN:1")) == 0)
			display2DWave(inww[n - 1], xCol, yCol)
		else
			append2DWave(inww[n - 1], xCol, yCol)
		endif
	elseif (option == 4)  // append all
		// create an empty window if no graph window exists.		
		for (i = 0; i < n; i += 1)
			if (i == 0 && strlen(WinList("*", ";", "WIN:1")) == 0)
				display2DWave(inww[i], xCol, yCol)
			else
				append2DWave(inww[i], xCol, yCol)
			endif
		endfor
	elseif (option == 8) // join columns
		String outWaveNameStr
		Variable col
		col = yCol
		Prompt outWaveNameStr, "Output Wave name"
		Prompt col, "Column Index to extract"
		DoPrompt "Join Column of Selected Waves", outWaveNameStr, col
		if (V_flag != 0) // cancel
			return V_flag
		endif
		
		// i == 0
		if (col < 0)
			Duplicate/O/R=[][DimSize(inww[0], 1) - col] inww[0], $(outWaveNameStr)
		else
			Duplicate/O/R=[][col] inww[0], $(outWaveNameStr)
		endif
		WAVE outWave = $(outWaveNameStr)
		SetScale/P y 0, 1, outWave
		SetDimLabel 1, i, $(NameOfWave(inww[0])), outWave

		//	i > 0
		for (i = 1; i < n; i += 1)
			if (col < 0)
				Duplicate/FREE/R=[][DimSize(inww[i], 1) - col] inww[i], fw
			else
				Duplicate/FREE/R=[][col] inww[i], fw
			endif
			Redimension/N=-1 fw
			Concatenate {fw}, outWave
			SetDimLabel 1, i, $(NameOfWave(inww[i])), outWave
		endfor
	endif
	
	return 0
End

Static Function display2DWave(inw, xCol, yCol)
	WAVE inw
	Variable xCol, yCol

	Variable xCol2, yCol2
	xCol2 = xCol >= 0 ? xCol : DimSize(inw, 1) + xCol
	yCol2 = yCol >= 0 ? yCol : DimSize(inw, 1) + yCol
	Display inw[][yCol2] vs inw[][xCol2]
	Label bottom GetDimLabel(inw, 1, 0)
	Label left GetDimLabel(inw, 1, DimSize(inw, 1) -  1)
End


Static Function append2DWave(inw, xCol, yCol)
	WAVE inw
	Variable xCol, yCol

	Variable xCol2, yCol2
	xCol2 = xCol >= 0 ? xCol : DimSize(inw, 1) + xCol
	yCol2 = yCol >= 0 ? yCol : DimSize(inw, 1) + yCol
	AppendToGraph inw[][yCol2] vs inw[][xCol2]
End


// This assume all column length is equal.
Function SPEC_joinTracesDialog(graphNameStr)
	String graphNameStr
	Variable i, n, col
	String traceListStr, traceNameStr, traceInfoStr
	
	String xOutWaveNameStr, yOutWaveNameStr
	Prompt xOutWaveNameStr, "Output Wave name of Horizontal-axis traces"
	Prompt yOutWaveNameStr, "Output Wave name of Vertical-axis traces"
	DoPrompt "Extract traces in " + graphNameStr, xOutWaveNameStr, yOutWaveNameStr
	if (V_flag != 0) // cancel
		return V_flag
	elseif (strlen(xOutWaveNameStr) == 0 && strlen(yOutWaveNameStr) == 0)
		return 0
	endif

	// 0x01: normal graph traces, 0x04: omit hidden traces
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x04)
	n = ItemsInList(traceListStr)
	
	for (i = 0; i < n; i += 1)
		traceNameStr = StringFromList(i, traceListStr)
		traceInfoStr = TraceInfo(graphNameStr, traceNameStr, 0)

		if (strlen(xOutWaveNameStr) > 0)
			sscanf StringByKey("XRANGE", traceInfoStr), "[*][%d]", col
			if (V_flag == 1)
				WAVE/Z lw_trace = XWaveRefFromTrace(graphNameStr, traceNameStr)
				if (WaveExists(lw_trace))
					if (i == 0)
						Duplicate/O/R=[][col] lw_trace, $(xOutWaveNameStr)
						WAVE xOutWave = $(xOutWaveNameStr)
						SetScale/P y 0, 1, xOutWave
					else
						Duplicate/FREE/R=[][col] lw_trace, fw
						Redimension/N=-1 fw
						Concatenate {fw}, xOutWave
					endif
					SetDimLabel 1, i, $(traceNameStr), xOutWave
				endif
			else
				// error
			endif
		endif

		if (strlen(yOutWaveNameStr) > 0)
			sscanf StringByKey("YRANGE", traceInfoStr), "[*][%d]", col
			if (V_flag == 1)
				WAVE lw_trace = TraceNameToWaveRef(graphNameStr, traceNameStr)
				if (i == 0)
					Duplicate/O/R=[][col] lw_trace, $(yOutWaveNameStr)
					WAVE yOutWave = $(yOutWaveNameStr)
					SetScale/P y 0, 1, yOutWave
				else
					Duplicate/FREE/R=[][col] lw_trace, fw
					Redimension/N=-1 fw
					Concatenate {fw}, yOutWave
				endif
				SetDimLabel 1, i, $(traceNameStr), yOutWave
			else
				// error
			endif
		endif
	endfor
End

Function SPEC_multicolDisplayDialog()
	String xWaveNameStr, yWaveNameStr
	Variable colStart = 0, colEnd = -1, colDelta = 1
	
	
	Prompt xWaveNameStr, "1-dimensional wave for horizontal axis", popup, "_calculated_;" + WaveList("*", ";", "TEXT:0,BYTE:0,WORD:0,DIMS:1")
	Prompt yWaveNameStr, "2-dimensional wave for vertical axis", popup, WaveList("*", ";", "TEXT:0,BYTE:0,WORD:0,DIMS:2,MINCOLS:4")
	Prompt colStart, "First column index"
	Prompt colEnd, "Last column index (-1 represents the last index)"
	Prompt colDelta, "Incremental value"
	
	DoPrompt "Display Columns", xWaveNameStr, yWaveNameStr, colStart, colEnd, colDelta
	if (V_flag != 0) // cancel
		return V_flag
	endif
	
	WAVE/Z xWAVE = $(xWaveNameStr)
	WAVE   yWAVE = $(yWaveNameStr)
	if (colEnd == -1)
		colEnd = DimSize(yWave, 1) - 1
	endif
	
	Variable i
	Display
	for (i = colStart; i <= colEnd; i += colDelta)
		if (stringmatch(xWaveNameStr, "_calculated_"))
			AppendToGraph yWave[][i]
		else
			AppendToGraph yWave[][i] vs xWave
		endif
	endfor
End
