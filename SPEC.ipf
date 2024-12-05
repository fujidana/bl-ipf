#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0
#pragma IgorVersion=6.3

//#include "SFView_MCPlot"
#include "SPEC_IO"
#include "SPEC_util"

//#define SPEC_LOAD_ONE_ROW_DATA_FILE


/// Module to handle SPEC scan data.
///
/// The file extension of scan files should be ".spec".
/// Written by So Fujinami.
/// Tested by Igor Pro 8.0 on macOS.


Constant SPEC_SPEC_DATA_FILE_FORMAT = 1
Constant SPEC_1D_FILE_FORMAT        = 2
Constant SPEC_PF9809_FILE_FORMAT    = 3
Constant SPEC_MCA_ARRAY_FILE_FORMAT = 4

Menu "Load Waves"
	"-"
	"Load SPEC Scan Files...",  /Q, SPEC_openFilesDialog(SPEC_SPEC_DATA_FILE_FORMAT)
	"Load 1D Files...",         /Q, SPEC_openFilesDialog(SPEC_1D_FILE_FORMAT)
	"Load PF9809 XAS Files...", /Q, SPEC_openFilesDialog(SPEC_PF9809_FILE_FORMAT)
	"Load MCA Array Files...",  /Q, SPEC_openFilesDialog(SPEC_MCA_ARRAY_FILE_FORMAT)
End

Menu "Macros"
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

	// This function must return 1 in order to prevent Igor from trying to load the file in a built-in manner.
	String extension = ParseFilePath(4, fileNameStr, ":", 0, 0)
	if (fileKind == 0 && stringmatch(extension, "spec"))
		return (SPEC_loadDataFile(fileNameStr, pathNameStr, SPEC_SPEC_DATA_FILE_FORMAT) == 0)
//	elseif (fileKind == 7 && stringmatch(extension, "dat"))
//		return (SPEC_loadSpec1DFile(fileNameStr, pathNameStr) == 0)
	else
		return 0
	endif
End

/// @brief Show a Open Dialog for multiple selection.
Function SPEC_openFilesDialog(dataFormat)
	Variable dataFormat

	Variable i, refNum, errno
	String fileFilter, fileNameList
	// Set filter string for open dialog
	if (dataFormat == SPEC_SPEC_DATA_FILE_FORMAT)
		fileFilter = "spec scan data file (*.spec):.spec;"
	elseif (dataFormat == SPEC_1D_FILE_FORMAT)
		fileFilter = "spec 1D data file (*.dat,*.txt):.dat,.txt;"
	elseif (dataFormat == SPEC_PF9809_FILE_FORMAT)
		fileFilter = "PF 9809 XAS data file (*.xas):.xas;"
	elseif (dataFormat == SPEC_MCA_ARRAY_FILE_FORMAT)
		fileFilter = "MCA array data file (*.mca,*.dat):.mca,.dat;"
	else
		Abort "Invalid parameters"
	endif

	Open/D/R/MULT=1/F=(fileFilter+"All Files:*;") refNum
	errno = 0
	fileNameList = S_fileName
	if (strlen(fileNameList) == 0) // User cancel
		return -1
	endif

	for (i = 0; i < ItemsInList(fileNameList, "\r"); i += 1)
		errno += SPEC_loadDataFile(StringFromList(i, fileNameList, "\r"), "", dataFormat)
	endfor
	
	return errno
End


// Return 0 if succeeded and 1 if failed.
Function SPEC_loadDataFile(fileNameStr, symbPath, dataFormat)
	String fileNameStr, symbPath
	Variable dataFormat

	String typeStr
	if (dataFormat == SPEC_SPEC_DATA_FILE_FORMAT)
		typeStr = "spec data"
	elseif (dataFormat == SPEC_1D_FILE_FORMAT)
		typeStr = "1D"
	elseif (dataFormat == SPEC_PF9809_FILE_FORMAT)
		typeStr = "PF-9809 XAS"
	elseif (dataFormat == SPEC_MCA_ARRAY_FILE_FORMAT)
		typeStr = "MCA array"
	else
		// typeStr = ""
		return 1
	endif

	if (strlen(symbPath))
		printf "[SPEC@%s] Loading %s file: \"%s\" @ %s\r", time(), typeStr, fileNameStr, symbPath
	else
		printf "[SPEC@%s] Loading %s file: \"%s\"\r", time(), typeStr, fileNameStr
	endif

	if (dataFormat == SPEC_SPEC_DATA_FILE_FORMAT)
		WAVE/WAVE/Z fww = SPEC_IO_loadSpecScanFile(fileNameStr, symbPath)
		if (!WaveExists(fww))
			printf "[SPEC@%s] Failed in loading file.\r", time()
			return 1
		endif
	elseif (dataFormat == SPEC_1D_FILE_FORMAT)
		WAVE/Z fw = SPEC_IO_load1DFile(fileNameStr, symbPath)
		if (WaveExists(fw))
			Make/WAVE/FREE/N=1 fww
			fww[0] = fw
		else
			printf "[SPEC@%s] Failed in loading file.\r", time()
			return 1
		endif
	elseif (dataFormat == SPEC_PF9809_FILE_FORMAT)
		WAVE/Z fw = SPEC_IO_loadXasFile(fileNameStr, symbPath)
		if (WaveExists(fw))
			Make/WAVE/FREE/N=1 fww
			fww[0] = fw
		else
			printf "[SPEC@%s] Failed in loading file.\r", time()
			return 1
		endif
	elseif (dataFormat == SPEC_MCA_ARRAY_FILE_FORMAT)
		WAVE/Z fw = SPEC_IO_loadMcaFile(fileNameStr, symbPath)
		if (WaveExists(fw))
			Make/WAVE/FREE/N=1 fww
			fww[0] = fw
		else
			printf "[SPEC@%s] Failed in loading file.\r", time()
			return 1
		endif
	endif

	if (numpnts(fww) == 1)
		printf "[SPEC@%s] 1 %s wave was loaded.\r", time(), typeStr
	else
		printf "[SPEC@%s] %d %s waves were loaded.\r", time(), numpnts(fww), typeStr
	endif

	// Postprocess (optionally draw graphs).
	Variable action = NumVarOrDefault("root:SV_postprocess", 5)
	doActionSubroutine(fww, action)

	return 0
End


/// @brief Show a dialog to select postprocess action.
Function SPEC_configDialog()
	Variable postprocess
	String xColStr, yColStr, colorTable
	
	postprocess = NumVarOrDefault("root:SV_postprocess", 5)
	xColStr     = StrVarOrDefault("root:SS_xCol", "0")
	yColStr     = StrVarOrDefault("root:SS_yCol", "-1")
	colorTable  = StrVarOrDefault("root:SS_colorTable", "Rainbow")
	Prompt postprocess, "Post-loading action", popup, "Display last scan;Display all scans;Append last scan;Append All Scans;Do nothing;"
	Prompt xColStr, "Column index/label of x-axis (\"0\" by default)"
	Prompt yColStr, "Column index/label of y-axis (\"-1\" by default)"
	Prompt colorTable, "Trace Color Tables", popup, CTabList()
	DoPrompt "Postprocess postprocess", postprocess, xColStr, yColStr, colorTable
	if (V_flag != 0) // cancel
		return V_flag
	endif
	Variable/G SV_postprocess = postprocess
	String/G   SS_xCol        = xColStr
	String/G   SS_yCol        = yColStr
	String/G   SS_colorTable  = colorTable
	
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
		elseif (WaveExists($tmpStr) && (WaveType($tmpStr) & 0x02 || WaveType($tmpStr) & 0x04))
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

	Variable colorCycle, xOffset, yOffset, xMultiplier, yMultiplier, tmpNum
	String colorTableStr, userDataStr, tmpStr

	// restore user data
	userDataStr = GetUserData(graphNameStr, "", "SPEC_fancyTraces")
	tmpStr = StringByKey("colorTable", userDataStr)
	if (strlen(tmpStr) != 0)
		colorTableStr = tmpStr
	else
		colorTableStr = StrVarOrDefault("root:SS_colorTable", "Rainbow")
	endif
	tmpNum = NumberByKey("colorCycle", userDataStr)
	colorCycle = numtype(tmpNum) != 2 ? tmpNum : 1
	tmpNum = NumberByKey("xOffset", userDataStr)
	xOffset = numtype(tmpNum) != 2 ? tmpNum : 0
	tmpNum = NumberByKey("yOffset", userDataStr)
	yOffset = numtype(tmpNum) != 2 ? tmpNum : 0
	tmpNum = NumberByKey("xMultiplier", userDataStr)
	xMultiplier = numtype(tmpNum) != 2 ? tmpNum : 1
	tmpNum = NumberByKey("yMultiplier", userDataStr)
	yMultiplier = numtype(tmpNum) != 2 ? tmpNum : 1

	// show a dialog
	Prompt colorTableStr, "Color table", popup, CTabList()
	Prompt colorCycle,  "Coloring cycle (0: not recolor, 1/-1: auto, negative: reversed color)"
	Prompt xOffset,     "Horizontal offset per trace"
	Prompt yOffset,     "Vertical offset per trace"
	Prompt xMultiplier, "Horizontal multiplier per trace"
	Prompt yMultiplier, "Vertical multiplier per trace"
	DoPrompt "Fancy traces in " + graphNameStr, xOffset, yOffset, xMultiplier, yMultiplier, colorTableStr, colorCycle
	if (V_flag != 0) // cancel
		return V_flag
	endif

	colorCycle = round(colorCycle)

	// store selected values in a user data of the window.
	sprintf tmpStr, "colorTable:%s;colorCycle:%d;xOffset:%g;yOffset:%g;xMultiplier:%g;yMultiplier:%g;", colorTableStr, colorCycle, xOffset, yOffset, xMultiplier, yMultiplier
	SetWindow $(graphNameStr) userData(SPEC_fancyTraces)=tmpStr

	Variable i, n, red, green, blue
	String traceListStr, traceNameStr

	// 0x01: normal graph traces, 0x04: omit hidden traces
	traceListStr = TraceNameList(graphNameStr, ";", 0x01 | 0x04)
	n = ItemsInList(traceListStr)
	
	// Prepare a color table wave.

	// If `colorCycle` is negative, prepare the color table reversed.
	ColorTab2Wave $colorTableStr
	WAVE M_colors
	if (colorCycle < 0)
		ImageTransform flipRows, M_colors
		colorCycle = abs(colorCycle)
	endif

	// If `colorCycle` == 1, set the color cycle to the total trace number.
	if (colorCycle == 1)
		colorCycle = n
	endif

	// Prepare an interpolated color table wave.
	Make/N=(colorCycle, 3)/U/I/FREE M_colors2
	M_colors2 = interp2d(M_colors, p / (colorCycle - 1) * (DimSize(M_colors, 0) - 1), q)

	for (i = 0; i < n; i += 1)
		traceNameStr = StringFromList(i, traceListStr)
		if (colorCycle != 0)
			red   = M_colors2[mod(i, colorCycle)][0]
			green = M_colors2[mod(i, colorCycle)][1]
			blue  = M_colors2[mod(i, colorCycle)][2]
			ModifyGraph/W=$(graphNameStr) rgb($traceNameStr)=(red, green, blue)
		endif

		ModifyGraph/W=$(graphNameStr) offset($traceNameStr)={xOffset * i, yOffset * i}
		if (xMultiplier == 1 && yMultiplier == 1)
			ModifyGraph/W=$(graphNameStr) muloffset($traceNameStr)={0, 0}
		else
			ModifyGraph/W=$(graphNameStr) muloffset($traceNameStr)={xMultiplier^i, yMultiplier^i}
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

// Show 2D graph.
//
// option: 0 (new), 1 (append)
// Return 0 if no error occurred. Otherwise return a nonzero value.
Static Function show2DWave(inw, xColStr, yColStr, option)
	WAVE inw
	String xColStr, yColStr
	Variable option

	if (WaveDims(inw) == 1)
		if (option == 0)
			Display inw
		else
			AppendToGraph inw
		endif
		return 0
	elseif (WaveDims(inw) == 2)
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
	endif
	return 1
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
