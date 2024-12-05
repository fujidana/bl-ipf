#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// Written by So Fujinami on 2019-10-24.

//#define IGNORES_SCAN_INDEX
//#define SAVES_EXTRA_WAVES
//#define NOT_USE_SPEC_MNEMONIC
//#define SPEC_LOAD_ONE_ROW_DATA_FILE


//Static Constant kTimeZone = +9


// load a Spec data file and return a free wave reference wave
Function/WAVE SPEC_IO_loadSpecScanFile(filePath, symbPath)
	String filePath, symbPath

	Variable fp

	// open a file pointer
	Open/R/Z=1/P=$symbPath fp as filePath
	if (V_flag != 0) // -1: user cancelled
		print "Error in opening file.", V_flag
		return $""
	endif

	Make/WAVE/FREE/N=0 fww
	Make/I/FREE/N=0 fw_blockStart, fw_blockEnd, fw_dataStart, fw_scanInd
	Make/D/FREE/N=0 fw_scanDate
	Make/T/FREE/N=0 ftw_scanCmd, ftw_dimLabel

	SetScale d  0, 0, "dat", fw_scanDate

	Variable lineInd, blockNum, isInBlock, cols, rows
	String lineStr, waveNameStr

	blockNum = 0
	isInBlock = 0

	//	scan file content and separate it to scan blocks.
	for (lineInd = 0; 1; lineInd++)
		FReadLine fp, lineStr

		if (strlen(lineStr) == 0)
			// Quit if the scan reaches EOF
			if (blockNum > 0)
				fw_blockEnd[blockNum - 1] = lineInd
			endif
			break
		elseif (isInBlock)
			// Skip until empty line if is in scan block
			if (stringmatch(lineStr, "\r"))
				fw_blockEnd[blockNum - 1] = lineInd
				isInBlock = 0

			// Capture label names
			elseif (stringmatch(lineStr, "#L *"))
				ftw_dimLabel[blockNum - 1] = lineStr[3,  strlen(lineStr) - 2]
				fw_dataStart[blockNum - 1] = lineInd + 1
			elseif (stringmatch(lineStr, "#D *"))
				// only accept the date line (#D ...) just below the scan line (#S ...).
				if (lineInd == fw_blockStart[blockNum - 1] + 1)
					fw_scanDate[blockNum - 1] = getDateTimeValue(lineStr[3, strlen(lineStr) - 2])
				endif

			// Skip other commend (header) lines
			elseif (stringmatch(lineStr, "#*"))
				// do nothing

			// Parse lines that do not start with "#" as a data array
			else
#ifdef SPEC_LOAD_ONE_ROW_DATA_FILE
				if (rows == 0)
					cols = ItemsInList(lineStr, " ")
					if (cols <= 0)
						Close fp
						printf "[SPEC_IO:spec/ERROR] Failed in spliting data: %s.\r", filePath
						return $""
					endif
					sprintf waveNameStr, "%s_%03d", ParseFilePath(3, filePath, ":", 0, 0), blockNum
					Make/D/O/N=(1, cols) $(waveNameStr)
					WAVE lw_data = $(waveNameStr)
					fww[blockNum - 1] = lw_data
					lw_data[rows][] = str2num(StringFromList(q, lineStr, " "))
					rows += 1
				else
					if (cols != ItemsInList(lineStr, " "))
						Close fp
						printf "[SPEC_IO:spec/ERROR] Mismatch of column number: %s.\r", filePath
						return $""
					endif
					Redimension/N=(rows + 1, cols) lw_data
					lw_data[rows][] = str2num(StringFromList(q, lineStr, " "))
					rows += 1
				endif
#else
				// do nothing
#endif
			endif
		else
			// Skip until scan block start if it is out of the scan block
			Variable scanInd
			String scanCmd
			sscanf lineStr, "#S %d %[^\r]", scanInd, scanCmd
			if (V_flag > 1)
				Redimension/N=(blockNum + 1) fww
				Redimension/N=(blockNum + 1) fw_blockStart, fw_blockEnd, fw_dataStart, fw_scanInd
				Redimension/N=(blockNum + 1) fw_scanDate
				Redimension/N=(blockNum + 1) ftw_scanCmd, ftw_dimLabel

				fw_blockStart[blockNum] = lineInd
				fw_dataStart[blockNum]  = lineInd
				fw_scanInd[blockNum]    = scanInd
				fw_scanDate[blockNum]   = 0
				ftw_scanCmd[blockNum]   = scanCmd
				cols = 0
				rows = 0

				blockNum += 1
				isInBlock = 1
			endif
		endif
	endfor

	Close fp

	Variable blockInd
	// Variable blockStartPrev, scanIndPrev
	// blockStartPrev = 0
	// scanIndPrev = 0
	for (blockInd = 0; blockInd < blockNum; blockInd += 1)
		Variable dataWaveInd, blockStart, blockEnd, scanDate //, scanInd
		String dimLabelStr //, scanCmd

		blockStart  = fw_blockStart[blockInd]
		blockEnd    = fw_blockEnd[blockInd]
		scanInd     = fw_scanInd[blockInd]
		scanDate    = fw_scanDate[blockInd]
		dimLabelStr = ftw_dimLabel[blockInd]
		scanCmd     = ftw_scanCmd[blockInd]

		// set the wave name to be saved
//#ifdef IGNORES_SCAN_INDEX
		dataWaveInd = blockInd + 1
//#else
//		if (scanInd <= scanIndPrev)
//			printf "Scan number is not incremental (prev: #%d at line %d, curr: #%d at line %d). ", scanIndPrev, blockStartPrev + 1, scanInd, blockStart + 1
//			printf "The older scan data may be overwritten.\r"
//		endif
//		dataWaveInd = scanInd
//		scanIndPrev = scanInd
//		blockStartPrev = blockStart
//#endif
		sprintf waveNameStr, "%s_%03d", ParseFilePath(3, filePath, ":", 0, 0), dataWaveInd

#ifdef SPEC_LOAD_ONE_ROW_DATA_FILE
		WAVE lw_data = fww[blockInd]
#else
		// Load wave
		LoadWave/G/W/M/L={0, blockStart, (blockEnd - blockStart), 0, 0}/D/N=tmp_spec_wave/O/Q/P=$symbPath filePath
		if (V_flag == 0)
			printf "[SPEC_IO:spec/ERROR] No wave loaded by 'LoadWave' from scan #%d, lines between %d--%d.\r", scanInd, blockStart + 1, blockEnd + 1
			continue
		endif
		Duplicate/O $(StringFromList(0, S_waveNames)), $(waveNameStr)
		KillWaves/Z $(StringFromList(0, S_waveNames))
		WAVE lw_data = $(waveNameStr)
		fww[blockInd] = lw_data
#endif

		// add column labels
		if (strlen(dimLabelStr) > 0)
			Variable j
			dimLabelStr = ReplaceString("  ", ReplaceString("    ", dimLabelStr, ";"), ";")
			for (j = 0; j < ItemsInList(dimLabelStr) && j < DimSize(lw_data, 1); j += 1)
				SetDimLabel 1, j, $(StringFromList(j, dimLabelStr)), lw_data
			endfor
		endif

		// set x-scaling of the wave from the first row if the scan is aNscan or dNscan whrere N = empty or 2, 3, 4, 5.
		if (GrepString(scanCmd, "^\\s*[a|d][2-5]?scan\s+"))
			Variable xStart, xEnd
			xStart = lw_data[0][0]
			xEnd = lw_data[DimSize(lw_data, 0) - 1][0]
			if (xStart != xEnd)
				SetScale/I x xStart, xEnd, "", lw_data
			endif
		endif

		// add time stamp and information to the wave note
//		SFWave_setValueForKey(lw_data, "key", "value")
		String tmpStr
		sprintf tmpStr, "COMMAND: %s\rSCAN DATE: %sT%s\rSCAN NUMBER: %d\r", scanCmd, Secs2Date(scanDate, -2), Secs2Time(scanDate, 3), scanInd
		Note/K lw_data, tmpStr
	endfor

#ifdef SAVES_EXTRA_WAVES
	sprintf waveNameStr, "%s_date", ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O fw_scanDate, $(waveNameStr)

	sprintf waveNameStr, "%s_cmd", ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O ftw_scanCmd, $(waveNameStr)
	
	sprintf waveNameStr, "%s_scanNum", ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O fw_scanInd, $(waveNameStr)
#endif

	return fww
End


////	// read header lines
////	Make/T/FREE/N=0 ftw_header
////	regExprStr = "^#([A-Za-z][0-9]*) (.*)\r$"
////	for (i = 0; 1; i += 1)
////		// note that FReadLine converts LF into CR.
////		FReadLine fp, lineStr
////		if (strlen(lineStr) == 0) // EOF
////			print "Error in reading header: data part not found in the file."
////			Close fp
////			return $""
////		elseif (stringmatch(lineStr, "\r"))
////			Redimension/N=(i + 1) ftw_header
////			ftw_header[i] = RemoveEnding(lineStr, "\r")
////		elseif (GrepString(lineStr, regExprStr))
////			Redimension/N=(i + 1) ftw_header
////			SplitString/E=regExprStr lineStr, keyStr, valueStr
////			ftw_header[i] = valueStr
////			SetDimLabel 0, i, $keyStr, ftw_header
////		else
////			// if the line is not empty or does not start with "#", it is the starting point of data part. 
////			break
////		endif
////	endfor
////	lineNumber = i
////	Close fp
////	
////	Make/T/FREE/N=0 ftw_Param
////	
////	// parse header lines
////	
////	// because Concatenate produces error is the destination wave is a 0-point wave, 
////	// dummy data point is inserted. This will deleted later.
////	Make/T/FREE/N=1 ftw_MotorName, ftw_MotorMnemonic, ftw_CounterName, ftw_CounterMnemonic, ftw_Position
////	for (i = 0; i < lineNumber; i += 1)
////		keyStr = GetDimLabel(ftw_header, 0, i)
////		valueStr = ftw_header[i]
////		
////		if (strlen(keyStr) == 0)
////			continue
////		elseif (GrepString(keyStr, "^[OoJjP][0-9]+$"))
////			if (cmpstr(keyStr[0], "O", 1) == 0)
////				WAVE/T ftw_src  = ListToTextWave(valueStr, "  ")
////				WAVE/T ftw_dest = ftw_MotorName
////			elseif (cmpstr(keyStr[0], "o", 1) == 0)
////				WAVE/T ftw_src  = ListToTextWave(valueStr, " ")
////				WAVE/T ftw_dest = ftw_MotorMnemonic
////			elseif (cmpstr(keyStr[0], "J", 1) == 0)
////				WAVE/T ftw_src  = ListToTextWave(valueStr, "  ")
////				WAVE/T ftw_dest = ftw_CounterName
////			elseif (cmpstr(keyStr[0], "j", 1) == 0)
////				WAVE/T ftw_src  = ListToTextWave(valueStr, " ")
////				WAVE/T ftw_dest = ftw_CounterMnemonic
////			elseif (cmpstr(keyStr[0], "P", 1) == 0)
////				WAVE/T ftw_src  = ListToTextWave(valueStr, " ")
////				WAVE/T ftw_dest = ftw_Position
////			else
////				print "ERROR"
////				return $""
////			endif
////			Concatenate/NP/T {ftw_src}, ftw_dest
////		else
////			Variable paramIndex = numpnts(ftw_Param)
////			Redimension/N=(paramIndex + 1) ftw_Param
////			ftw_Param[paramIndex] = valueStr
////			SetDimLabel 0, paramIndex, $keyStr, ftw_Param
////		endif
////	endfor
////	
////	// check if the numbers of the name and mnemonic are equal
////	if (numpnts(ftw_MotorName) != numpnts(ftw_MotorMnemonic) || numpnts(ftw_MotorName) != numpnts(ftw_position))
////		print "Error in parsing header: Mismatch of item number between motor mnemonic and motor name"
////		return $""
////	elseif (numpnts(ftw_CounterName) != numpnts(ftw_CounterMnemonic))
////		print "Error in parsing header: Mismatch of item number between counter mnemonic and counter name"
////		return $""
////	endif
////	
////	// delete the dummy data point here.
////	DeletePoints 0, 1, ftw_MotorName, ftw_MotorMnemonic, ftw_CounterName, ftw_CounterMnemonic, ftw_Position
////	
////	// convert a position wave from text to numeric.
////	Make/FREE/N=(numpnts(ftw_Position)) fw_position
////	fw_position = str2num(ftw_position)
////	
////	for (i = 0; i < numpnts(ftw_MotorMnemonic); i += 1)
////		SetDimLabel 0, i, $(ftw_MotorMnemonic[i]) ftw_MotorName, fw_Position
////		SetDimLabel 0, i, $(ftw_MotorName[i]) ftw_MotorMnemonic
////	endfor
////	for (i = 0; i < numpnts(ftw_CounterMnemonic); i += 1)
////		SetDimLabel 0, i, $(ftw_CounterMnemonic[i]) ftw_CounterName
////		SetDimLabel 0, i, $(ftw_CounterName[i]) ftw_CounterMnemonic
////	endfor
////
////	// load data part
////	DFREF savedDFR = GetDataFolderDFR()
////	SetDataFolder NewFreeDataFolder()
////	LoadWave/G/W/M/L={lineNumber - 1, lineNumber, 0, 0, 0}/D/N=spec_tmporary_wave/O/P=$symbPath filePath
////	if (V_flag != 1)
////		print "Error in loading data part."
////		SetDataFolder savedDFR
////		return $""
////	endif
////	WAVE fw2_ScanData = $(StringFromList(0, S_waveNames))
////	SetDataFolder savedDFR
////	
////	Variable epochOffset = 0
////#ifdef CONVERT_SPEC_DATETIME_FOR_IGOR
////	// Unix time starts from 1970-01-01 and Igor Pro's time (Legacy Mac) starts from 1904-01-01
////	// The difference is 66 years including 17 leap years.
////	epochOffset = str2num(ftw_Param[%E]) + ((66 * 365 + 17) * 24 + kTimeZone) * 60 * 60
////#endif
////		
////	// set column labels
////	WAVE/T ftw = ListToTextWave(ftw_Param[numpnts(ftw_Param) - 1], "  ")
////	for (i = 0; i < numpnts(ftw); i += 1)
////		if (i == numpnts(ftw) - 1)
////			valueStr = "selected"
////		else
////			valueStr = ftw[i]
////		endif
////		
////		if (strlen(valueStr) == 0)
////			DeletePoints i, 1, ftw
////			valueStr = ftw[i]
//// 		endif
//// 		
////#ifdef NOT_USE_SPEC_MNEMONIC
////		keyStr = valueStr
//// 		if (stringmatch(valueStr, "Epoch"))
//// 			fw2_ScanData[][i] += epochOffset
//// 		endif
////#else
//// 		if (stringmatch(valueStr, "Epoch"))
//// 			fw2_ScanData[][i] += epochOffset
//// 			keyStr = "dtime"
//// 		elseif (stringmatch(valueStr, "Seconds"))
//// 			// "sec", a mneomnic of "Seconds". is a reserved keyword by Igor Pro.
//// 			// Tt is replaced with "countSec".
//// 			keyStr = "countSec"
//// 		elseif (FindDimLabel(ftw_CounterMnemonic, 0, valueStr) >= 0)
//// 			keyStr = ftw_CounterMnemonic[FindDimLabel(ftw_CounterMnemonic, 0, valueStr)]
//// 		elseif (FindDimLabel(ftw_MotorMnemonic, 0, valueStr) >= 0)
//// 			keyStr = ftw_MotorMnemonic[FindDimLabel(ftw_MotorMnemonic, 0, valueStr)]
//// 		else
//// 			keyStr = valueStr
//// 		endif
////#endif
//// 
//// 		SetDimLabel 1, i, $(keyStr), fw2_ScanData
////	endfor
////	
////	Make/WAVE/FREE/N=5 fww
////	fww[0] = ftw_Param
////	fww[1] = ftw_MotorName
////	fww[2] = ftw_CounterName
////	fww[3] = fw_Position
////	fww[4] = fw2_ScanData
////	return fww


// load Spec 1D file and return a free wave reference wave
Function/WAVE SPEC_IO_load1DFile(filePath, symbPath)
	String filePath, symbPath

	String waveNameStr
	sprintf waveNameStr, "%s_1D", ParseFilePath(3, filePath, ":", 0, 0)
	
	LoadWave/G/M/L={1, 2, 0, 0, 0}/D/N=tmp_1d_wave/O/Q/P=$symbPath filePath
	if (V_flag == 0)
		printf "[SPEC_IO:1d/ERROR] No wave loaded by 'LoadWave'.\r"
		return $""
	endif
	Duplicate/O $(StringFromList(0, S_waveNames)), $(waveNameStr)
	WAVE lw_data = $(waveNameStr)
	KillWaves/Z $(StringFromList(0, S_waveNames))	
	
	// It is assumed that data in the first column are evenly spaced.
	Variable xStart, xEnd
	xStart = lw_data[0][0]
	xEnd = lw_data[DimSize(lw_data, 0) - 1][0]
	if (xStart != xEnd)
		SetScale/I x xStart, xEnd, "", lw_data
	endif
	
	return lw_data
End


Function/WAVE SPEC_IO_load2DTextFile(filePath, symbPath)
	String filePath, symbPath
	
	String waveNameStr
	sprintf waveNameStr, "%s", ParseFilePath(3, filePath, ":", 0, 0)
	
	LoadWave/G/M/D/N=tmp_general_text_wave/O/Q/P=$symbPath filePath
	if (V_flag == 0)
		printf "[SPEC_IO:2d/ERROR] No wave loaded by 'LoadWave'.\r"
		return $""
	endif
	Duplicate/O $(StringFromList(0, S_waveNames)), $(waveNameStr)
	WAVE lw_data = $(waveNameStr)
	KillWaves/Z $(StringFromList(0, S_waveNames))
	
	return lw_data
End


Function/WAVE SPEC_IO_loadXasFile(filePath, symbPath)
	String filePath, symbPath

	String waveNameStr
	sprintf waveNameStr, "%s_XAS", ParseFilePath(3, filePath, ":", 0, 0)

	Variable fp
	String lineStr

	// open a file pointer
	Open/R/Z=1/P=$symbPath fp as filePath
	if (V_flag != 0) // -1: user cancelled
		print "Error in opening file.", V_flag
		return $""
	endif

	// read 1st line
	FReadLine fp, lineStr
	if (!stringmatch(lineStr, "  9809  *"))
		print "Not PF 9809 XAS file format."
		Close fp
		return $""
	endif
	
	// read 2nd-4th line
	FReadLine fp, lineStr
	FReadLine fp, lineStr
	FReadLine fp, lineStr
	// read 5th line
	FReadLine fp, lineStr
	String desc
	Variable d_spacing
	sscanf lineStr, " Mono : %s D=%g", desc, d_spacing
	if (V_flag != 2)
		print "Failed in parsing d-spacing value."
		Close fp
		return $""
	endif

	Close fp

	LoadWave/G/M/L={18, 21, 0, 0, 0}/D/N=tmp_1d_wave/O/Q/P=$symbPath filePath
	if (V_flag == 0)
		printf "[SPEC_IO:xas/ERROR] No wave loaded by 'LoadWave'.\r"
		return $""
	endif
	Duplicate/O $(StringFromList(0, S_waveNames)), $(waveNameStr)
	WAVE lw_data = $(waveNameStr)
	KillWaves/Z $(StringFromList(0, S_waveNames))
	
	// add energy column to the first
	InsertPoints/M=1 0, 1, lw_data
	lw_data[][0] = 12.3984 / (2 * d_spacing * sin(pi * lw_data[p][1] / 180))
	
	// add mu-T column to the end
	Variable n
	n = DimSize(lw_data, 1)
	InsertPoints/M=1 (n), 1, lw_data
	lw_data[][n] = log(lw_data[p][4] / lw_data[p][5])

	return lw_data
End


/// @brief Load a MCA array file.
Function/WAVE SPEC_IO_loadMcaFile(filePath, symbPath)
	String filePath, symbPath

#ifdef SPEC_LOAD_ONE_ROW_DATA_FILE
	Variable fp, rows, cols
	String lineStr
	Open/R/P=$(symbPath)/Z fp as filePath
	if (V_flag != 0)
		printf "[SPEC_IO:mca/ERROR] Failed in opening file: %s.\r", filePath
		return $""
	endif
	rows = 0
	do
		FReadLine fp, lineStr

		if (strlen(lineStr) == 0)
			break
		elseif (stringmatch(lineStr, "#*"))
			continue
		elseif (rows == 0)
			cols = ItemsInList(lineStr, " ")
			if (cols <= 0)
				Close fp
				printf "[SPEC_IO:mca/ERROR] Failed in spliting data: %s.\r", filePath
				return $""
			endif
			Make/D/O/N=(cols, 1) SW2_data_mca_tmp0
			SW2_data_mca_tmp0[][rows] = str2num(StringFromList(p, lineStr, " "))
			rows += 1
		else
			if (cols != ItemsInList(lineStr, " "))
				Close fp
				printf "[SPEC_IO:mca/ERROR] Mismatch of column number: %s.\r", filePath
				return $""
			endif
			Redimension/N=(cols, rows + 1) SW2_data_mca_tmp0
			SW2_data_mca_tmp0[][rows] = str2num(StringFromList(p, lineStr, " "))
			rows += 1
		endif
	while (1)
	Close fp
	WAVE lw_data = SW2_data_mca_tmp0
#else
	LoadWave/G/M/D/P=$(symbPath)/N=SW2_data_mca_tmp/Q filePath
	if (V_flag == 0)
		printf "[SPEC_IO:mca/ERROR] No wave loaded by 'LoadWave'.\r"
		return $""
	endif
	WAVE lw_data = $StringFromList(0, S_waveNames)
	MatrixTranspose lw_data
#endif

	WAVE/Z SW_mcaParam
	if (WaveExists(SW_mcaParam))
		SetScale/P x SW_mcaParam[%chOffset], SW_mcaParam[%chSlope], "eV", lw_data
	endif

	String waveNameStr
	waveNameStr = ParsefilePath(3, filePath, ":", 0, 0)
	Duplicate/O lw_data, $waveNameStr

	return $waveNameStr
End


// Convert a date-time string that appears in a spec data file to a numeric value.
Static Function getDateTimeValue(dateTimeStr)
	String dateTimeStr

	Variable year, month, day, hour, minute, second
	String weekdayStr, monthStr

	sscanf dateTimeStr, "%s %s %d %d:%d:%d %d", weekdayStr, monthStr, day, hour, minute, second, year
	if (V_flag == 7)
		month = WhichListItem(monthStr, "Jan;Feb:Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec;") + 1
		return date2secs(year, month, day) + (hour * 60 + minute) * 60 + second
	else
		return 0
	endif
End
