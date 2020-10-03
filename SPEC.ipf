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
Static StrConstant ks1dFileFilter = "spec 1D data file (*.dat):.dat;"
Static StrConstant ksAllFileFilter = "All Files:*;"


Menu "Load Waves"
	"Open Spec Data File...", /Q, SPEC_openDataFileDialog()
End

Menu "Macros"
	"Configure SPEC File Loader...", /Q, SPEC_showConfigDialog()
	"-"
	"Open SPEC Data File...", /Q, SPEC_openDataFileDialog()
	"-"
	"Display Data Browser Selection Separately", /Q, SPEC_doActionForDataBrowser(2)
	"Display Data Browser Selection Together", /Q, Display; SPEC_doActionForDataBrowser(4)
	"Append Data Browser Selection", /Q, SPEC_doActionForDataBrowser(4)
	"-"
	"Fancy Traces...", /Q, SPEC_showFancyDialog()
End

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
Function SPEC_openDataFileDialog()
	Variable refNum
	String fileFilter, extension
	fileFilter = ksScanFileFilter + ks1dFileFilter + ksAllFileFilter
	Open/D/R/F=fileFilter refNum
	if (strlen(S_fileName))
		extension = ParseFilePath(4, S_fileName, ":", 0, 0)
		if (cmpstr(extension, "spec", 0) == 0)
			return SPEC_loadSpecScanFile(S_fileName, "")
		elseif (cmpstr(extension, "dat", 0) == 0)
			return SPEC_loadSpec1DFile(S_fileName, "")
		else
			return -1
		endif
	else
		return -1
	endif
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
	showGraphs(fww, action)

	return 0
End


/// @brief Load a SPEC 1D file.
Function SPEC_loadSpec1DFile(filePath, symbPath)
	String filePath, symbPath
	
	DFREF savedDFR = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	LoadWave/G/M/D/N=spec_tmporary_wave/O/P=$symbPath filePath
	if (V_flag != 1)
		print "Error in loading data part."
		SetDataFolder savedDFR
		return -1
	endif
	WAVE fw_data = $(StringFromList(0, S_waveNames))
	SetDataFolder savedDFR
	
	String baseName = ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O fw_data, $(baseName + "_1d")
	printf "[SPEC@%s] Successfully loaded. Now matrix wave \'%s\' is in the current data folder.\r", time(), baseName
	
	WAVE lw_data = $(baseName + "_1d")
//	showGraph(lw_data)
	
	return 0
End


/// @brief Show a dialog to select postprocess action.
Function SPEC_showConfigDialog()
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
		showGraphs(fww, option)
	endif
	
	return 0
End


/// @brief Show a dialog for fancy traces.
Function SPEC_showFancyDialog()
	String graphNameStr, graphListStr = WinList("*", ";", "WIN:1")
	if (strlen(graphListStr) == 0)
		DoAlert 0, "No graph window found."
		return 1
	endif
	graphNameStr = StringFromList(0, graphListStr)
	
	Variable cycle, reversed, xOffset, yOffset
	String colorTableStr
	colorTableStr = "Rainbow"
	cycle = 0
	reversed = 1
	Prompt colorTableStr, "Color Table", popup, CTabList()
	Prompt cycle, "Number of Traces per Coloring Cycle (set 0 for full range)"
	Prompt reversed, "Reversed Coloring", popup, "NO;YES;"
	Prompt xOffset, "Horizontal Offset per Trace"
	Prompt yOffset, "Vertical Offset per Trace"
	DoPrompt "Fancy Traces in " + graphNameStr, colorTableStr, cycle, reversed, xOffset, yOffset
	if (V_flag != 0) // cancel
		return V_flag
	endif
	reversed -= 1
	
	ColorTab2Wave $colorTableStr
	WAVE M_colors
	
	Variable i, n, red, green, blue
	String traceListStr
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x05)
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
	endfor

	return 0
End

/// @brief show graphs.
Static Function showGraphs(inww, option)
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
