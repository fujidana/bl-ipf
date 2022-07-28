#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0
#pragma IgorVersion=6.3

//#include "SFView_MCPlot"
#include "SPEC_IO"
#include "SPEC_util"



/// Module to handle SPEC scan data.
///
/// The file extension of scan files should be ".spec".
/// Written by So Fujinami.
/// Tested by Igor Pro 8.0 on macOS.


Static StrConstant ksScanFileFilter = "spec scan data file (*.spec):.spec;"
Static StrConstant ks1dFileFilter   = "spec 1D data file (*.dat,*.txt):.dat,.txt;"
Static StrConstant ksXasFileFilter  = "PF 9809 XAS data file (*.xas):.xas;"
Static StrConstant ksMcaFileFilter  = "MCA array data file (*.mca,*.dat):.mca,.dat;"
Static StrConstant ksAllFileFilter  = "All Files:*;"


Menu "Load Waves"
	"-"
	"Load SPEC Scan Files...", /Q, SPEC_openSpecFileDialog()
	"Load 1D Files...",        /Q, SPEC_open1DFileDialog()
	"Load XAS Files...",       /Q, SPEC_openXasFileDialog()
	"Load MCA Files...",       /Q, SPEC_openMcaFileDialog()
End

Menu "Macros"
//	"(Load Waves"
//	"Load SPEC Scan Files...", /Q, SPEC_openSpecFileDialog()
//	"Load 1D Files...",        /Q, SPEC_open1DFileDialog()
//	"Load XAS Files...",       /Q, SPEC_openXasFileDialog()
//	"Load MCA Files...",       /Q, SPEC_openMcaFileDialog()
//	"-"
	"(Data Browser"
	"Display Selection Separately", /Q, SPEC_doActionForDataBrowser(2)
	"Display Selection Together",   /Q, Display; SPEC_doActionForDataBrowser(4)
	"Append Selection",             /Q, SPEC_doActionForDataBrowser(4)
	"Concatenate Columns of Selection...",  /Q, SPEC_doActionForDataBrowser(8)
	"Concatenate Selection",                /Q, SPEC_doActionForDataBrowser(16)
	"Concatenate Selection (No Promotion)", /Q, SPEC_doActionForDataBrowser(32)
// Menu "Macros", dynamic
// 	SPEC_getMenuItem(0), /Q, SPEC_doActionForDataBrowser(2)
// 	SPEC_getMenuItem(1), /Q, Display; SPEC_doActionForDataBrowser(4)
// 	SPEC_getMenuItem(2), /Q, SPEC_doActionForDataBrowser(4)
	"-"
	"(Graphs"
	"Reselect Columns of Traces...", /Q, SPEC_reselectColumnDialog()
	"Concatenate Traces in a 2D Wave...", /Q, SPEC_joinTracesDialog("")
	"Fancy Traces...", /Q, SPEC_fancyTrancesDialog()
	"-"
	"(Joined 2D Wave"
	"Display Columns in a 2D Wave...", /Q, SPEC_multicolDisplayDialog()
	"-"
	"(Other"
	"Configure SPEC Macro Behavior...", /Q, SPEC_configDialog()
	"-"
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


/// @brief Show a Open Dialog for a XAS file.
Function SPEC_openMcaFileDialog()
	Variable i, refNum, errno
	String fileFilter, fileNameList
	fileFilter = ksMcaFileFilter + ksAllFileFilter
	Open/D/R/MULT=1/F=fileFilter refNum
	errno = 0
	fileNameList = S_fileName

	if (strlen(fileNameList) == 0) // User cancel
		return -1
	endif

	for (i = 0; i < ItemsInList(fileNameList, "\r"); i += 1)
		if (WaveExists(SPEC_loadMcaFile(StringFromList(i, fileNameList, "\r"), "")))
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
	Variable action = NumVarOrDefault("root:SV_postprocess", 5)
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
	Variable action = NumVarOrDefault("root:SV_postprocess", 5)
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
	Variable action = NumVarOrDefault("root:SV_postprocess", 5)
	doActionSubroutine(fww, action)

	return 0
End

/// @brief Load a MCA array file.
Function/WAVE SPEC_loadMcaFile(filePath, symbPath)
	String filePath, symbPath

	LoadWave/G/M/D/P=$(symbPath)/N=SW2_data_mca_tmp/Q filePath
	if (V_flag == 0)
		printf "Loading Error.\r"
		return $""
	endif
	WAVE lw_data = $StringFromList(0, S_waveNames)
	MatrixTranspose lw_data
	
	WAVE/Z SW_mcaParam
	if (WaveExists(SW_mcaParam))
		SetScale/P x SW_mcaParam[%chOffset], SW_mcaParam[%chSlope], "eV", lw_data
	endif
	
	String waveNameStr
	waveNameStr = ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O lw_data, $waveNameStr
	
	return $waveNameStr
End


/// @brief Show a dialog to select postprocess action.
Function SPEC_configDialog()
	Variable postprocess
	String xColStr, yColStr
	
	postprocess = NumVarOrDefault("root:SV_postprocess", 5)
	xColStr     = StrVarOrDefault("root:SS_xCol", "0")
	yColStr     = StrVarOrDefault("root:SS_yCol", "-1")
	Prompt postprocess, "Post-loading action", popup, "Display last scan;Display all scans;Append last scan;Append All Scans;Do nothing;"
	Prompt xColStr, "Column index/label of x-axis (\"0\" by default)"
	Prompt yColStr, "Column index/label of y-axis (\"-1\" by default)"
	DoPrompt "Postprocess postprocess", postprocess, xColStr, yColStr
	if (V_flag != 0) // cancel
		return V_flag
	endif
	Variable/G SV_postprocess = postprocess
	String/G   SS_xCol        = xColStr
	String/G   SS_yCol        = yColStr
	
	return 0
End


/// @brief Do action to waves selected in the data browser.
Function SPEC_doActionForDataBrowser(option)
	Variable option

	// Exit if a data browser is not found.
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
	
	Variable i, n, xColInd, yColInd
	String xColStr, yColStr, traceNameStr, traceListStr
	
	xColStr = StrVarOrDefault("root:SS_xCol", "0")
	yColStr = StrVarOrDefault("root:SS_yCol", "-1")
	
	// 0x01: normal graph traces, 0x04: omit hidden traces
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x04)
	n = ItemsInList(traceListStr)
	Prompt xColStr, "Column index/label of x-axis (\"0\" by default)"
	Prompt yColStr, "Column index/label of y-axis (\"-1\" by default)"
	DoPrompt "Reselect columns of Traces in " + graphNameStr, xColStr, yColStr
	if (V_flag != 0) // cancel
		return V_flag
	endif
	
	for (i = 0; i < n; i += 1)
		traceNameStr = StringFromList(i, traceListStr)
		WAVE/Z xWave = XWaveRefFromTrace(graphNameStr, traceNameStr)
		WAVE/Z yWave = TraceNameToWaveRef(graphNameStr, traceNameStr)
		
		if (WaveExists(xWave) && WaveDims(xWave) == 2)
			if (strlen(xColStr) == 0)
				// skip
			elseif (isInteger(xColStr))
				xColInd = str2num(xColStr)
				xColInd = (xColInd >= 0) ? xColInd : DimSize(xWave, 1) + xColInd
				ReplaceWave/X trace=$(traceNameStr), xWave[][xColInd]
			elseif (FindDimLabel(xWave, 1, xColStr) >= 0)
				ReplaceWave/X trace=$(traceNameStr), xWave[][%$xColStr]	
			else
				printf "Failed to find x-label '%s' in wave '%s'\r", xColStr, NameOfWave(xWave)
				return 1
			endif
		endif

		if (WaveExists(yWave) && WaveDims(yWave) == 2)
			if (strlen(yColStr) == 0)
				// skip
			elseif (isInteger(yColStr))
				yColInd = str2num(yColStr)
				yColInd = (yColInd >= 0) ? yColInd : DimSize(yWave, 1) + yColInd
				ReplaceWave trace=$(traceNameStr), yWave[][yColInd]
			elseif (FindDimLabel(yWave, 1, yColStr) >= 0)
				ReplaceWave trace=$(traceNameStr), yWave[][%$yColStr]	
			else
				printf "Failed to find y-label '%s' in wave '%s'\r", yColStr, NameOfWave(yWave)
				return 1
			endif
		endif
	endfor
	
	return 0
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
	Prompt colorTableStr, "Color table", popup, CTabList()
	Prompt cycle, "Number of traces per coloring cycle"
	Prompt reversed, "Reversed coloring", popup, "NO;YES;"
	Prompt xOffset, "Horizontal offset per trace"
	Prompt yOffset, "Vertical offset per trace"
	Prompt xMultiplier, "Horizontal multiplier per trace"
	Prompt yMultiplier, "Vertical multiplier per trace"
	DoPrompt "Fancy traces in " + graphNameStr, xOffset, yOffset, xMultiplier, yMultiplier, colorTableStr, cycle, reversed
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
	
	Variable xColInd, yColInd
	String xColStr, yColStr
	xColStr = StrVarOrDefault("root:SS_xCol", "0")
	yColStr = StrVarOrDefault("root:SS_yCol", "-1")
	n = numpnts(inww)
	
	if (n == 0)
		return 1
	endif
	
	if (option == 1) // display last	
		show2DWave(inww[n - 1], xColStr, yColStr, 0)
	elseif (option == 2)  // display all
		for (i = 0; i < n; i += 1)
			show2DWave(inww[i], xColStr, yColStr, 0)
		endfor
	elseif (option == 3) // append last
		// create an empty window if no graph window exists.
		if (strlen(WinList("*", ";", "WIN:1")) == 0)
			show2DWave(inww[n - 1], xColStr, yColStr, 0)
		else
			show2DWave(inww[n - 1], xColStr, yColStr, 1)
		endif
	elseif (option == 4)  // append all
		// create an empty window if no graph window exists.		
		for (i = 0; i < n; i += 1)
			if (i == 0 && strlen(WinList("*", ";", "WIN:1")) == 0)
				show2DWave(inww[i], xColStr, yColStr, 0)
			else
				show2DWave(inww[i], xColStr, yColStr, 1)
			endif
		endfor
	elseif (option == 8) // join specified columns of the 2D waves
		concatenateColumnsOf2DWaves(inww)
	elseif (option == 16) // concatenate waves
		String waveListStr = ""
		for (i = 0; i < n; i += 1)
			waveListStr = waveListStr + GetWavesDataFolder(inww[i], 4) + ";"
		endfor
		Concatenate/O waveListStr, SW_concatAll
	elseif (option == 32) // concatenate waves without promotion
		waveListStr = ""
		for (i = 0; i < n; i += 1)
			waveListStr = waveListStr + GetWavesDataFolder(inww[i], 4) + ";"
		endfor
		Concatenate/O/NP waveListStr, SW_concatAll
	endif
	
	return 0
End

// Show 2D graph option: 0 (new), 1 (append)
Static Function show2DWave(inw, xColStr, yColStr, option)
	WAVE inw
	String xColStr, yColStr
	Variable option

	Variable isXColInteger, isYColInteger, xColInd, yColInd
	isXColInteger = isInteger(xColStr)
	isYColInteger = isInteger(yColStr)

	if (isXColInteger && isYColInteger)
		xColInd = str2num(xColStr)
		xColInd = (xColInd >= 0) ? xColInd : DimSize(inw, 1) + xColInd
		yColInd = str2num(yColStr)
		yColInd = (yColInd >= 0) ? yColInd : DimSize(inw, 1) + yColInd

		if (option == 0)
			Display inw[][yColInd] vs inw[][xColInd]
		else
			AppendToGraph inw[][yColInd] vs inw[][xColInd]
		endif
	elseif (isXColInteger)
		xColInd = str2num(xColStr)
		xColInd = (xColInd >= 0) ? xColInd : DimSize(inw, 1) + xColInd
		yColInd = FindDimLabel(inw, 1, yColStr)
		if (yColInd < 0)
			printf "Failed to find y-label '%s' in wave '%s'\r", yColStr, NameOfWave(inw)
			return 1
		endif
		
		if (option == 0)
			Display inw[][%$yColStr] vs inw[][xColInd]
		else
			AppendToGraph inw[][%$yColStr] vs inw[][xColInd]
		endif
	elseif (isYColInteger)
		xColInd = FindDimLabel(inw, 1, xColStr)
		if (xColInd < 0)
			printf "Failed to find x-label '%s' in wave '%s'\r", xColStr, NameOfWave(inw)
			return 1
		endif
		yColInd = str2num(yColStr)
		yColInd = (yColInd >= 0) ? yColInd : DimSize(inw, 1) + yColInd
		
		if (option == 0)
			Display inw[][yColInd] vs inw[][%$xColStr]
		else
			AppendToGraph inw[][yColInd] vs inw[][%$xColStr]
		endif
	else
		xColInd = FindDimLabel(inw, 1, xColStr)
		if (xColInd < 0)
			printf "Failed to find x-label '%s' in wave '%s'\r", xColStr, NameOfWave(inw)
			return 1
		endif
		yColInd = FindDimLabel(inw, 1, yColStr)
		if (yColInd < 0)
			printf "Failed to find y-label '%s' in wave '%s'\r", yColStr, NameOfWave(inw)
			return 1
		endif
		
		if (option == 0)
			Display inw[][%$yColStr] vs inw[][%$xColStr]
		else
			AppendToGraph inw[][%$yColStr] vs inw[][%$xColStr]
		endif
	endif
	
	if (option == 0)
		Label bottom GetDimLabel(inw, 1, xColInd)
		Label left GetDimLabel(inw, 1, yColInd)
	endif
	
	return 0
End

Static Function concatenateColumnsOf2DWaves(inww)
	WAVE/WAVE inww
	
	String outWaveNameStr, colStr
	outWaveNameStr = "SW_concatCols"
	colStr = StrVarOrDefault("root:SS_yCol", "-1")
	Prompt outWaveNameStr, "Output wave name"
	Prompt colStr, "Column index/label to extract"
	DoPrompt "Concatenate column of selected waves", outWaveNameStr, colStr
	if (V_flag != 0) // cancel
		return V_flag
	elseif (strlen(outWaveNameStr) == 0)
		return 0
	endif

	Variable colInd

	// i == 0
	WAVE lw = inww[0]
	if (isInteger(colStr))
		colInd = str2num(colStr)
		colInd = (colInd >= 0) ? colInd : DimSize(lw, 1) + colInd
	else
		colInd = FindDimLabel(lw, 1, colStr)
		if (colInd < 0)
			printf "Failed to find y-label '%s' in wave '%s'\r", colStr, NameOfWave(lw)
			return 1
		endif
	endif
	Duplicate/O/R=[][colInd] lw, $(outWaveNameStr)
	WAVE outWave = $(outWaveNameStr)
	SetScale/P y 0, 1, outWave
	SetDimLabel 1, 0, $(NameOfWave(inww[0])), outWave

	//	i > 0
	Variable i, n
	n = numpnts(inww)
	
	for (i = 1; i < n; i += 1)
		WAVE lw = inww[i]
		if (isInteger(colStr))
			colInd = str2num(colStr)
			colInd = (colInd >= 0) ? colInd : DimSize(lw, 1) + colInd
		else
			colInd = FindDimLabel(lw, 1, colStr)
			if (colInd < 0)
				printf "Failed to find y-label '%s' in wave '%s'\r", colStr, NameOfWave(lw)
				return 1
			endif
		endif
		Duplicate/FREE/R=[][colInd] lw, fw_tmp
		Redimension/N=-1 fw_tmp
		Concatenate {fw_tmp}, outWave
		SetDimLabel 1, i, $(NameOfWave(lw)), outWave
	endfor
End


Static Function isInteger(colStr)
	String colStr

	//	allow decimal and hexadecimal
	return GrepString(colStr, "^\s*[+-]?(\d+|0[xX][0-9a-fA-F]+)\s*$")
End

	
// This assume all column length is equal.
Function SPEC_joinTracesDialog(graphNameStr)
	String graphNameStr
	Variable i, n, col
	String traceListStr, traceNameStr, traceInfoStr
	
	String xOutWaveNameStr, yOutWaveNameStr
	xOutWaveNameStr = "SW_concatXTrace"
	xOutWaveNameStr = "SW_concatYTrace"
	Prompt xOutWaveNameStr, "Output wave name of horizontal-axis traces"
	Prompt yOutWaveNameStr, "Output wave name of vertical-axis traces"
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
	
	DoPrompt "Display columns", xWaveNameStr, yWaveNameStr, colStart, colEnd, colDelta
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

Function SPEC_initMcaParam(offset, slope)
	Variable offset, slope

	Make/O/D/N=2 SW_mcaParam
	SetDimLabel 0, 0, chOffset, SW_mcaParam
	SetDimLabel 0, 1, chSlope, SW_mcaParam
	SW_mcaParam[%chOffset] = offset
	SW_mcaParam[%chSlope] = slope
End
