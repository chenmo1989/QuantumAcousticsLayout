#!/usr/bin/env python3
"""
Compute (1) coupling g and (2) coupling capacitor Cc for a transmon–λ/4 readout resonator.

Inputs (user-friendly units):
  - fr_GHz: resonator frequency in GHz
  - fq_GHz: qubit frequency in GHz
  - alpha_MHz: transmon anharmonicity in MHz (typically NEGATIVE, e.g. -220)
  - chi_kHz: dispersive shift chi in kHz (NOTE: chi is the ± shift; if you know 2chi, divide by 2)

Outputs:
  - g_MHz: coupling rate g/2π in MHz
  - Cc_fF: coupling capacitance in fF (λ/4 resonator, voltage antinode, Z0=50Ω)

Assumptions:
  - Dispersive regime formula: chi = - g^2 * alpha / (Δ (Δ + alpha))
  - alpha, chi, Δ are in Hz (NOT angular); g returned as g/2π in Hz units
  - Approximate transmon charge matrix element: n01 ≈ (EJ / (32 EC))^(1/4)
  - Approximate EJ/EC from fq and alpha (transmon large-EJ/EC formula):
        f01 ≈ sqrt(8 EJ EC)/h - EC/h,     alpha ≈ -EC/h
  - Coupling relation (capacitive, antinode):
        g(rad/s) ≈ (2e/ħ) * (Cc/CΣ) * Vrms * n01
    with CΣ ≈ Cq from EC.

If you only know alpha but not EC separately, we set EC/h = |alpha|.
"""

import math
import numpy as np

# ---------- constants ----------
e = 1.602176634e-19
h = 6.62607015e-34
hbar = h / (2 * math.pi)

def _vrms_lambda4_antinode(fr_Hz: float, Z0_ohm: float = 50.0) -> float:
    """Zero-point voltage at the open end (voltage antinode) of a λ/4 resonator."""
    omega = 2 * math.pi * fr_Hz
    # Ceff = π / (4 ω Z0)
    Ceff = math.pi / (4.0 * omega * Z0_ohm)
    # Vrms = sqrt( ħ ω / (2 Ceff) )
    return math.sqrt(hbar * omega / (2.0 * Ceff))

def _inverse_transmon_from_f_and_alpha(f01_Hz: float, alpha_Hz: float):
    """
    Approximate inversion:
      EC/h ≈ |alpha|
      f01 ≈ (sqrt(8 EJ EC) - EC)/h
    Returns EJ (J), EC (J), CΣ (F)
    """
    Ec = h * abs(alpha_Hz)           # EC in Joules
    Ej = (h * f01_Hz + Ec) ** 2 / (8.0 * Ec)  # EJ in Joules
    C = e**2 / (2.0 * Ec)            # CΣ in Farads (transmon approximation)
    return Ej, Ec, C

def _n01_transmon(Ej_J: float, Ec_J: float) -> float:
    """Transmon charge matrix element n01 (large EJ/EC)."""
    return (Ej_J / (32.0 * Ec_J)) ** 0.25

def solve_g_and_Cc(
    fr_GHz: float,
    fq_GHz: float,
    alpha_MHz: float,
    chi_kHz: float,
    *,
    Z0_ohm: float = 50.0,
):
    """
    Returns dict with:
      g_MHz, Cc_fF, Delta_GHz, EJ_over_EC
    """
    fr_Hz = fr_GHz * 1e9
    fq_Hz = fq_GHz * 1e9
    alpha_Hz = alpha_MHz * 1e6
    chi_Hz = chi_kHz * 1e3

    Delta_Hz = fq_Hz - fr_Hz

    # Dispersive inversion (Hz-domain, not angular):
    # chi = - g^2 * alpha / (Delta (Delta + alpha))
    denom = alpha_Hz
    num = -chi_Hz * Delta_Hz * (Delta_Hz + alpha_Hz)
    g2 = num / denom

    if g2 <= 0:
        raise ValueError(
            "No real g found. Check signs/inputs:\n"
            " - alpha should usually be negative (e.g. -220 MHz)\n"
            " - chi sign depends on detuning and alpha (try flipping chi sign)\n"
            " - ensure you passed chi (not 2chi); if you have 2chi, divide by 2."
        )

    g_Hz = math.sqrt(g2)            # this is g/2π in Hz units (cQED convention)
    g_MHz = g_Hz / 1e6

    # Invert transmon params from fq and alpha to estimate n01, CΣ
    Ej_J, Ec_J, Cq_F = _inverse_transmon_from_f_and_alpha(fq_Hz, alpha_Hz)
    EJ_over_EC = Ej_J / Ec_J

    # Coupling capacitor from g:
    Vrms = _vrms_lambda4_antinode(fr_Hz, Z0_ohm)
    n01 = _n01_transmon(Ej_J, Ec_J)

    g_rad = 2 * math.pi * g_Hz  # rad/s
    # beta ≈ Cc/CΣ  (assuming Cc << CΣ)
    Cc_F = (g_rad * hbar / (2.0 * e * Vrms * n01)) * Cq_F
    Cc_fF = Cc_F * 1e15

    return {
        "g_MHz": g_MHz,
        "Cc_fF": Cc_fF,
        "Delta_GHz": Delta_Hz / 1e9,
        "EJ_over_EC": EJ_over_EC,
        "Cq_fF": Cq_F * 1e15,
        "Vrms_uV": Vrms * 1e6,
        "chi_kHz": chi_kHz,
        "alpha_MHz": alpha_MHz,
    }

def pretty_print(res: dict):
    print("===== Dispersive + Coupling Cap (λ/4 antinode, Z0=50Ω) =====")
    print(f"Δ = fq-fr      = {res['Delta_GHz']:.6f} GHz")
    print(f"alpha          = {res['alpha_MHz']:.3f} MHz")
    print(f"chi            = {res['chi_kHz']:.3f} kHz  (this is chi, not 2chi)")
    print("---- results ----")
    print(f"g/2π           = {res['g_MHz']:.3f} MHz")
    print(f"Cc (est.)      = {res['Cc_fF']:.4f} fF")
    print("---- internals (approx) ----")
    print(f"CΣ (from alpha)= {res['Cq_fF']:.2f} fF")
    print(f"EJ/EC          = {res['EJ_over_EC']:.1f}")
    print(f"Vrms antinode  = {res['Vrms_uV']:.3f} µV")

if __name__ == "__main__":
    # Example: use your numbers (NOTE: you gave 2chi=272 kHz -> chi=136 kHz)
    fr_GHz = 7.2
    fq_GHz = 4.2
    alpha_MHz = -225.0
    chi_kHz = 620

    out = solve_g_and_Cc(fr_GHz, fq_GHz, alpha_MHz, chi_kHz, Z0_ohm=50.0)
    pretty_print(out)