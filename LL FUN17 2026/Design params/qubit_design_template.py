import numpy as np

# ---------- constants ----------
e = 1.602176634e-19
h = 6.62607015e-34
ħ = h / (2 * np.pi)

def inverse_transmon_from_f_alpha(f01_Hz: float, Ec_Hz: float):
    """
    Invert transmon parameters from target f01 and anharmonicity alpha.

    Inputs
    ------
    f01_Hz : float
        Qubit |0>-|1> frequency in Hz (e.g., 5e9)
    alpha_Hz : float
        Anharmonicity in Hz (typically negative, e.g., -220e6)

    Returns
    -------
    dict with:
        Ec_J, Ej_J, C_F, Ic_A, Ej_over_Ec, f01_check_Hz, alpha_check_Hz
    """
    # Transmon approx: alpha ≈ -Ec/h
    Ec = h * abs(Ec_Hz)

    # Invert f01 ≈ (sqrt(8EjEc) - Ec)/h
    Ej = (h * f01_Hz + Ec)**2 / (8 * Ec)

    # Capacitance and critical current
    C = e**2 / (2 * Ec)
    Ic = (2 * e / ħ) * Ej

    # Checks using the same approximations
    f01_check = (np.sqrt(8 * Ej * Ec) - Ec) / h
    Ec_check = Ec / h  # approx

    return {
        "Ec_J": Ec,
        "Ej_J": Ej,
        "C_F": C,
        "Ic_A": Ic,
        "Ej_over_Ec": Ej / Ec,
        "f01_check_Hz": f01_check,
        "Ec_check_Hz": Ec_check,
    }

def pretty_print(res: dict):
    print("===== Inverse transmon design (approx) =====")
    print(f"C_total  = {res['C_F']*1e15:.2f} fF")
    print(f"Ec/h     = {(res['Ec_J']/h)/1e6:.2f} MHz")
    print(f"Ej/h     = {(res['Ej_J']/h)/1e9:.2f} GHz")
    print(f"Ej/Ec    = {res['Ej_over_Ec']:.1f}")
    print(f"Ic       = {res['Ic_A']*1e9:.2f} nA")
    print("---- consistency checks (approx model) ----")
    print(f"f01_check = {res['f01_check_Hz']/1e9:.6f} GHz")
    print(f"Ec_chk = {res['Ec_check_Hz']/1e6:.2f} MHz")


# ============================================================
# Readout resonator (λ/4 CPW at voltage antinode) utilities
# ============================================================

def n01_transmon(Ej_J: float, Ec_J: float) -> float:
    """
    Transmon charge matrix element n_01 in large EJ/EC limit:
        n01 ≈ (EJ / (32 EC))^(1/4)
    """
    return (Ej_J / (32.0 * Ec_J)) ** 0.25


def Ceff_lambda4_antinode(fr_Hz: float, Z0_ohm: float = 50.0) -> float:
    """
    Effective capacitance seen at the voltage antinode of a λ/4 CPW resonator.

    For λ/4: V(x)=V0 cos(kx), open end at antinode.
    Energy in electric field: (1/2)∫ C' V^2 dx = (1/2) Ceff V0^2
    => Ceff = ∫ C' cos^2(kx) dx = C' l / 2

    Using: ω = π/(2 l v),  C' = 1/(v Z0)
    => Ceff = π / (4 ω Z0)
    """
    ω = 2 * np.pi * fr_Hz
    return np.pi / (4.0 * ω * Z0_ohm)


def Vrms_antinode(fr_Hz: float, Z0_ohm: float = 50.0) -> float:
    """
    Zero-point voltage at the antinode:
        V_rms = sqrt( ħ ω / (2 Ceff) )
    """
    ω = 2 * np.pi * fr_Hz
    Ceff = Ceff_lambda4_antinode(fr_Hz, Z0_ohm)
    return np.sqrt(ħ * ω / (2.0 * Ceff))


def chi_transmon_dispersive(fq_Hz: float, fr_Hz: float, alpha_Hz: float, g_Hz: float) -> float:
    """
    Dispersive shift (Hz) for transmon-resonator in dispersive regime:
        χ = - g^2 α / (Δ (Δ + α))
    with all in angular frequency internally; returns χ in Hz.

    Here g_Hz is g/(2π) in Hz units (common in cQED).
    """
    ωq = 2 * np.pi * fq_Hz
    ωr = 2 * np.pi * fr_Hz
    α = 2 * np.pi * alpha_Hz
    g = 2 * np.pi * g_Hz
    Δ = ωq - ωr

    χ = - (g**2) * α / (Δ * (Δ + α))
    return χ / (2 * np.pi)


def g_from_target_chi(fq_Hz: float, fr_Hz: float, alpha_Hz: float, chi_Hz_target: float) -> float:
    """
    Invert χ = - g^2 α / (Δ (Δ + α)) for g.
    Returns g_Hz (i.e. g/(2π) in Hz units).
    """
    ωq = 2 * np.pi * fq_Hz
    ωr = 2 * np.pi * fr_Hz
    α = 2 * np.pi * alpha_Hz
    χt = 2 * np.pi * chi_Hz_target
    Δ = ωq - ωr

    g2 = - χt * Δ * (Δ + α) / α
    if g2 <= 0:
        raise ValueError("Target chi not achievable with given fq, fr, alpha (check signs / dispersive regime).")
    g = np.sqrt(g2)
    return g / (2 * np.pi)


def coupling_cap_from_g_lambda4_antinode(
    g_Hz: float,
    fr_Hz: float,
    Cq_F: float,
    Ej_J: float,
    Ec_J: float,
    Z0_ohm: float = 50.0,
) -> float:
    """
    Estimate coupling capacitor Cc from target coupling g for λ/4 resonator at antinode.

    Use cQED estimate:
        g = (2e/ħ) * β * V_rms * n01
    where β ≈ Cc / CΣ  (for Cc << CΣ), CΣ ~ Cq_F.

    Solve:
        Cc = (g ħ / (2e V_rms n01)) * CΣ
    """
    Vrms = Vrms_antinode(fr_Hz, Z0_ohm)
    n01 = n01_transmon(Ej_J, Ec_J)

    g_rad = 2 * np.pi * g_Hz
    Cc = (g_rad * ħ / (2.0 * e * Vrms * n01)) * Cq_F
    return Cc


def readout_design_from_targets_lambda4(
    fq_Hz: float,
    Ec_Hz: float,
    fr_Hz: float,
    *,
    g_Hz: float | None = None,
    chi_Hz_target: float | None = None,
    Z0_ohm: float = 50.0,
    optimal_readout: bool = True,
    inverse_transmon_fn=None,
):
    """
    Inputs:
      fq_Hz : qubit f01 in Hz
      Ec_Hz : Ec/h in Hz (positive, e.g. 220e6)
      fr_Hz : resonator frequency in Hz (λ/4 CPW)

    Provide exactly one of:
      g_Hz : coupling rate g/(2π) in Hz (e.g. 120e6)
      chi_Hz_target : desired chi/(2π) in Hz (e.g. -2e6)

    Assumptions:
      - transmon anharmonicity alpha ≈ -Ec/h  => alpha_Hz = -Ec_Hz
      - λ/4 resonator, coupling at voltage antinode
      - "optimal readout": κ ~ |χ|
    """
    if inverse_transmon_fn is None:
        raise ValueError("Pass inverse_transmon_fn=your inverse_transmon_from_f_alpha")

    if (g_Hz is None) == (chi_Hz_target is None):
        raise ValueError("Provide exactly one of g_Hz or chi_Hz_target.")

    alpha_Hz = -abs(Ec_Hz)

    q = inverse_transmon_fn(fq_Hz, Ec_Hz)
    Ej, Ec, Cq, Ic = q["Ej_J"], q["Ec_J"], q["C_F"], q["Ic_A"]

    if g_Hz is None:
        g_Hz = g_from_target_chi(fq_Hz, fr_Hz, alpha_Hz, chi_Hz_target)

    chi_Hz = chi_transmon_dispersive(fq_Hz, fr_Hz, alpha_Hz, g_Hz)

    # optimal readout assumption: linewidth ~ dispersive shift
    kappa_Hz = 2*abs(chi_Hz) if optimal_readout else None

    # Purcell: Γ = (g/Δ)^2 κ   (angular)
    ωq = 2 * np.pi * fq_Hz
    ωr = 2 * np.pi * fr_Hz
    Δ = ωq - ωr
    g = 2 * np.pi * g_Hz
    κ = 2 * np.pi * kappa_Hz if kappa_Hz is not None else None

    T1_purcell = None
    if κ is not None:
        Γp = (g / Δ) ** 2 * κ
        T1_purcell = 1.0 / Γp

    Cc = coupling_cap_from_g_lambda4_antinode(
        g_Hz=g_Hz, fr_Hz=fr_Hz, Cq_F=Cq, Ej_J=Ej, Ec_J=Ec, Z0_ohm=Z0_ohm
    )

    Ceff = Ceff_lambda4_antinode(fr_Hz, Z0_ohm)

    Qc = None
    if kappa_Hz is not None:
        Qc = fr_Hz / kappa_Hz

    return {
        "fq_Hz": fq_Hz,
        "fr_Hz": fr_Hz,
        "Ec_Hz": Ec_Hz,
        "alpha_Hz_used": alpha_Hz,
        "Cq_F": Cq,
        "Ej_J": Ej,
        "Ec_J": Ec,
        "Ic_A": Ic,
        "Ej_over_Ec": Ej / Ec,
        "g_Hz": g_Hz,
        "chi_Hz": chi_Hz,
        "kappa_Hz_opt": kappa_Hz,
        "T1_purcell_s_opt": T1_purcell,
        "Cc_F": Cc,
        "Ceff_res_F_antinode": Ceff,
        "Delta_Hz": fq_Hz - fr_Hz,
        "Z0_ohm": Z0_ohm,
        "Qc_target": Qc
    }


def print_readout_summary(res: dict):
    print("===== Readout (λ/4 CPW, antinode) =====")
    print(f"fq            = {res['fq_Hz']/1e9:.4f} GHz")
    print(f"fr            = {res['fr_Hz']/1e9:.4f} GHz")
    print(f"Ej/h          = {(res['Ej_J']/h)/1e9:.2f} GHz")
    print(f"Ec/h          = {(res['Ec_J']/h)/1e6:.2f} MHz")
    print(f"Δ=fq-fr       = {res['Delta_Hz']/1e9:.4f} GHz")
    print(f"EJ/EC         = {res['Ej_over_Ec']:.1f}")
    print(f"C_total       = {res['Cq_F']*1e15:.2f} fF")
    print(f"Ic            = {res['Ic_A']*1e9:.2f} nA")

    print("---- coupling ----")
    print(f"g/2π          = {res['g_Hz']/1e6:.2f} MHz")
    print(f"chi/2π        = {res['chi_Hz']/1e6:.2f} MHz")
    print(f"kappa/2π~2|chi|= {res['kappa_Hz_opt']/1e6:.2f} MHz")

    print("---- inferred capacitors ----")
    print(f"Cc            = {res['Cc_F']*1e15:.3f} fF")
    print(f"Ceff(res)     = {res['Ceff_res_F_antinode']*1e15:.2f} fF  (λ/4 antinode, Z0={res['Z0_ohm']}Ω)")

    print("---- Purcell (simple) ----")
    if res["T1_purcell_s_opt"] is not None:
        print(f"T1_Purcell    = {res['T1_purcell_s_opt']*1e6:.2f} µs  (with κ~2|χ|)")
    else:
        print("T1_Purcell    = (not computed)")
    print(f"Qc target      = {res['Qc_target']:.0f}")

# =========================
# Example usage
# =========================
if __name__ == "__main__":
    # Your targets
    fq = 4.2e9
    Ec = 225e6          # Ec/h in Hz
    fr = 7.2e9

    # Provide g or chi:
    res = readout_design_from_targets_lambda4(
        fq, Ec, fr,
        g_Hz=163e6,
        Z0_ohm=50.0,
        inverse_transmon_fn=inverse_transmon_from_f_alpha,  # <-- your function
    )
    print_readout_summary(res)