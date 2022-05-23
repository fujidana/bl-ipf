#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Constant SPEC_HC_OVER_E = 1.239842


// energy: keV, two_theta: radian
// SPEC_E2q
Function SPEC_get_q(energy_keV, theta_rad)
	Variable energy_keV, theta_rad

	Variable wavelength_nm = SPEC_HC_OVER_E / energy_keV
	return 4 * Pi * sin(theta_rad) / wavelength_nm
End

// q: 1/nm, energy: keV
// SPEC_q2tth
Function SPEC_get_theta(q_nm_inv, energy_keV)
	Variable q_nm_inv, energy_keV

	Variable wavelength_nm = SPEC_HC_OVER_E / energy_keV
	return asin(q_nm_inv * wavelength_nm / 4 / PI)
End

// q: 1/nm, energy: keV
// SPEC_q2tth
Function SPEC_get_energy(q_nm_inv, theta_rad)
	Variable q_nm_inv, theta_rad

	Variable wavelength_nm = 4 * Pi * sin(theta_rad) / q_nm_inv
	return SPEC_HC_OVER_E / wavelength_nm
End
