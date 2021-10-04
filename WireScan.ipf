#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

#include "SPEC"

/// Module to analyze wire scan data, especially saved as SPEC standard data format.
///
/// Input wire-scan data must be a two dimensional and 
/// the first and last column mulst be the motor position and intensity, respectively.
///
/// Written by So Fujinami.
/// Tested by Igor Pro 9.0 on macOS.

//Function WireScan_show()
//Function WireScan_fitSingle(WAVE inwave2d)
//Function WireScan_fitMultiple(String waveBasenameStr, Variable startIndex, Variable endIndex, Variable speepSec)

Menu "Macros"
	Submenu "Wire Scan"
		"Show Graph",            /Q, WireScan_show()
		"Analyze Single Data",   /Q, WireScan_showFitSingleDialog()
		"Analyze Multiple Data", /Q, WireScan_showFitMultiDialog()
	End
End

Function WireScan_show()
	WAVE/Z WSW_x, WSW_I, WSW_dIdx
	if (!WaveExists(WSW_x) || !WaveExists(WSW_I) || !WaveExists(WSW_dIdX))
		Make/N=0 WSW_x, WSW_I, WSW_dIdx
	endif

	DoWindow/F WSFitGraph
	if (V_flag == 0)
		Display/N=WSFitGraph
		AppendToGraph/C=(0,0,65535) WSW_dIdx vs WSW_x
		AppendToGraph/C=(0,0,65535)/L=left2 WSW_I vs WSW_x
		ModifyGraph lblPos(left2)=55
		ModifyGraph axisEnab(left)={0.0, 0.65}, axisEnab(left2)={0.7, 1.0}, freePos(left2)=0
		ModifyGraph grid=1, tick=2, mirror(left)=1,mirror(left2)=1, standoff=0
	endif

	return 0
End

Function WireScan_showFitSingleDialog()
	String waveNameStr
	waveNameStr = StrVarOrDefault("WSS_single_waveName", "")
	Prompt waveNameStr, "2-dimensional wave", popup, WaveList("!WSM_*", ";", "TEXT:0,BYTE:0,WORD:0,DIMS:2,MINCOLS:4")
	DoPrompt "Analyze a Single Wire Scan Data", waveNameStr
	if (V_flag != 0) // cancel
		return V_flag
	endif
	
	String/G WSS_single_waveName = waveNameStr
//	String tmpStr
//	sprintf tmpStr, "WireScan_fitSingle(%s)", waveNameStr
//	Execute/P tmpStr
	return WireScan_fitSingle($waveNameStr)
End

Function WireScan_showFitMultiDialog()
	String basenameStr
	Variable startIndex, endIndex, sleepSec
	basenameStr = StrVarOrDefault("WSS_multi_basename", "")
	startIndex  = NumVarOrDefault("WSV_multi_start", 1)
	endIndex    = NumVarOrDefault("WSV_multi_end", 1)
	sleepSec    = NumVarOrDefault("WSV_multi_sleepSec", 0.0)
	Prompt basenameStr, "Basename of the Wave Names. e.g., \"sample\" for \"sample_001\""
	Prompt startIndex,  "First number of the sequence"
	Prompt endIndex,    "Last number of the sequence"
	Prompt sleepSec,    "Sleeping time after each analysis in second. No update if negative."
	DoPrompt "Analyze Multiple Wire Scan Data", basenameStr, startIndex, endIndex, sleepSec
	if (V_flag != 0) // cancel
		return V_flag
	endif

	String/G WSS_multi_basename   = basenameStr
	Variable/G WSV_multi_start    = startIndex
	Variable/G WSV_multi_end      = endIndex
	Variable/G WSV_multi_sleepSec = sleepSec
	return WireScan_fitMultiple(basenameStr, startIndex, endIndex, sleepSec)
End


Function WireScan_fitSingle(WAVE inwave2d)
	Duplicate/O/R=[][0] inwave2d, WSW_x
	Duplicate/O/R=[][DimSize(inwave2d, 1) - 1] inwave2d, WSW_I
	Redimension/N=-1 WSW_x, WSW_I

	Differentiate/D WSW_I /X=WSW_x/D=WSW_dIdx
//	if (WSW_I[0] > WSW_I[numpnts(WSW_I) - 1])
//		WSW_dIdx *= -1
//	endif
	
	K0=0
	CurveFit/N=1/H="1000"/Q=1/TBOX=256 gauss WSW_dIdx /X=WSW_x/D
//	CurveFit/N=1 gauss WSW_dIdx /X=WSW_x/D

	WAVE W_coef
	printf "[WireScan] wave: %s, FWHM: %g\r", NameOfWave(inwave2d), W_coef[3]*2*sqrt(ln(2))

	return 0
End

Function WireScan_fitMultiple(String waveBasenameStr, Variable startIndex, Variable endIndex, Variable speepSec)
	Variable i
	
	for (i = startIndex; i <= endIndex; i++)
		String waveNameStr
		sprintf waveNameStr, "%s_%03d", waveBasenameStr, i
		if (!WaveExists($waveNameStr))
			printf "[WireScan] ERROR: failed in finding wave: %s\r", waveNameStr
		endif
		WireScan_fitSingle($waveNameStr)
		WAVE W_coef, W_sigma
		if (i == startIndex)
			Duplicate/O W_coef, WSM_coef
			Duplicate/O W_sigma, WSM_sigma
		else
			Concatenate {W_coef}, WSM_coef
			Concatenate {W_sigma}, WSM_sigma
		endif
		if (speepSec >= 0)
			DoUpdate
			Sleep/S speepSec
		endif
	endfor
	
	MatrixTranspose WSM_coef
	MatrixTranspose WSM_sigma
	SetDimLabel 1, 0,    y0, WSM_coef, WSM_sigma
	SetDimLabel 1, 1,     A, WSM_coef, WSM_sigma
	SetDimLabel 1, 2,    x0, WSM_coef, WSM_sigma
	SetDimLabel 1, 3, width, WSM_coef, WSM_sigma
	
	Duplicate/O/R=[][3] WSM_coef, WSW_FWHMCoef
	Duplicate/O/R=[][3] WSM_sigma, WSW_FWHMSigma
	Redimension/N=-1 WSW_FWHMCoef, WSW_FWHMSigma
	
	WSW_FWHMCoef *= 2*sqrt(ln(2))
	WSW_FWHMSigma *= 2*sqrt(ln(2))
	
	printf "[WireScan] multiple waves has been analyzed. The results are stored in WSM_coef, WSW_FWHMCoef, etc.\r"
	
	return 0
End
