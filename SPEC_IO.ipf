#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//#include "SFWave"

// Written by So Fujinami on 2019-10-24.

//#define IGNORES_SCAN_INDEX
//#define SAVES_EXTRA_WAVES


//Static Constant kTimeZone = +9


//#define NOT_USE_SPEC_MNEMONIC


// load Spec data file and return a free wave reference wave
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
	Make/T/FREE/N=0 ftw_scanStr, ftw_dimLabel
	
	SetScale d  0, 0, "dat", fw_scanDate

	Variable lineInd, blockInd, isInBlock, scanInd
	String lineStr, scanNameStr
	
	Variable year, month, day, hour, minute, second
	String weekdayStr,  monthStr
	
	lineInd = 0
	blockInd = 0
	isInBlock = 0

	//	scan file content and separate it to scan blocks.
	do
		FReadLine fp, lineStr
		
		if (strlen(lineStr) == 0)
			// Quit if the scan reaches EOF
			if (blockInd > 0)
				fw_blockEnd[blockInd - 1] = lineInd
			endif
			break
		elseif (isInBlock)
			// Skip until empty line if is in scan block
			if (stringmatch(lineStr, "\r"))
				fw_blockEnd[blockInd - 1] = lineInd
				isInBlock = 0
			elseif (stringmatch(lineStr, "#L *"))
				ftw_dimLabel[blockInd - 1] = lineStr[3,  strlen(lineStr) - 2]
				fw_dataStart[blockInd - 1] = lineInd + 1
			elseif (stringmatch(lineStr, "#D *"))
				// only accept the date line (#D ...) just below the scan line (#S ...).
				if (lineInd == fw_blockStart[blockInd - 1] + 1)
					sscanf lineStr[3, strlen(lineStr) - 2], "%s %s %d %d:%d:%d %d", weekdayStr, monthStr, day, hour, minute, second, year
					if (V_flag == 7)
						month = WhichListItem(monthStr, "Jan;Feb:Mar;Apr;May;Jun;Jul;Aug;Sep;Oct;Nov;Dec;") + 1
						fw_scanDate[blockInd - 1] = date2secs(year, month, day) + (hour * 60 + minute) * 60 +  second 
					endif
				endif
			endif
		else
			// Skip until scan block start if it is out of the scan block
			sscanf lineStr, "#S %d %[^\r]", scanInd, scanNameStr
			if (V_flag > 1)
				Redimension/N=(blockInd + 1) fw_blockStart, fw_blockEnd, fw_dataStart, fw_scanInd
				Redimension/N=(blockInd + 1) fw_scanDate
				Redimension/N=(blockInd + 1) ftw_scanStr, ftw_dimLabel
				fw_blockStart[blockInd] = lineInd
				fw_dataStart[blockInd]  = lineInd
				fw_scanInd[blockInd]    = scanInd
				fw_scanDate[blockInd]   = 0
				ftw_scanStr[blockInd]   = scanNameStr
				blockInd += 1
				isInBlock = 1
			endif
		endif
		lineInd += 1
	while (1)

	Close fp
	
	Variable i, j, blockStart, blockEnd, blockStartPrev, scanIndPrev
	String waveNameStr, dimLabelStr
	
	Make/FREE/WAVE/N=(blockInd) fww	
	blockStartPrev = 0
	scanIndPrev = 0
	for (i = 0; i < blockInd; i += 1)
		blockStart = fw_blockStart[i]
		blockEnd   = fw_blockEnd[i]
		scanInd    = fw_scanInd[i]
		dimLabelStr = ftw_dimLabel[i]

		// set the wave name to be saved
//#ifdef IGNORES_SCAN_INDEX
		sprintf waveNameStr, "%s_%03d", ParseFilePath(3, filePath, ":", 0, 0), i
//#else
//		if (scanInd <= scanIndPrev)
//			printf "Scan number is not incremental (prev: #%d at line %d, curr: #%d at line %d). ", scanIndPrev, blockStartPrev + 1, scanInd, blockStart + 1
//			printf "The older scan data may be overwritten.\r"
//		endif
//		sprintf waveNameStr, "%s_%03d", ParseFilePath(3, filePath, ":", 0, 0), scanInd
//		scanIndPrev = scanInd
//		blockStartPrev = blockStart
//#endif
		// load wave
		LoadWave/G/W/M/L={0, blockStart, (blockEnd - blockStart), 0, 0}/D/N=tmp_spec_wave/O/Q/P=$symbPath filePath
		if (V_flag == 0)
			printf "Spec Loading Error at %dth scan block (line between %d--%d).\r", i + 1, blockStart + 1, blockEnd + 1
			continue
		endif
		Duplicate/O $(StringFromList(0, S_waveNames)), $(waveNameStr)
		WAVE lw_data = $(waveNameStr)
		KillWaves/Z $(StringFromList(0, S_waveNames))
		
		fww[i] = lw_data

		// add column labels
		if (strlen(dimLabelStr) > 0)
			dimLabelStr = ReplaceString("  ", ReplaceString("    ", dimLabelStr, ";"), ";")
			for (j = 0; j < ItemsInList(dimLabelStr) && j < DimSize(lw_data, 1); j += 1)
				SetDimLabel 1, j, $(StringFromList(j, dimLabelStr)), lw_data
			endfor
		endif

		// add time stamp and information to the wave note
//		SFWave_setValueForKey(lw_data, "key", "value")
		String tmpStr
		sprintf tmpStr, "COMMAND: %s\rSCAN DATE: %sT%s\rSCAN NUMBER: %d\r", ftw_scanStr[i], Secs2Date(fw_scanDate[i], -2), Secs2Time(fw_scanDate[i], 3), fw_scanInd[i]
		Note/K lw_data, tmpStr
	endfor

#ifdef SAVES_EXTRA_WAVES
	sprintf waveNameStr, "%s_date", ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O fw_scanDate, $(waveNameStr)

	sprintf waveNameStr, "%s_cmd", ParseFilePath(3, filePath, ":", 0, 0)
	Duplicate/O ftw_scanStr, $(waveNameStr)
	
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
