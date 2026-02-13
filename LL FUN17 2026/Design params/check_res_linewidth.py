import numpy as np
import matplotlib.pyplot as plt

# -------------------------
# your data
# -------------------------
#f_GHz = np.array([7.133, 7.162, 7.200, 7.235, 7.255, 7.302])
#kappa_kHz = np.array([127, 118, 111, 121, 151, 204])

f_GHz = np.array([7.488, 7.524, 7.556, 7.611, 7.635, 7.673])
kappa_kHz = np.array([132, 179, 109, 158, 238, 299])

# -------------------------
# log-log linear fit
# log(kappa) = n log(f) + b
# -------------------------
logf = np.log10(f_GHz)
logk = np.log10(kappa_kHz)

n, b = np.polyfit(logf, logk, 1)   # slope = exponent

print("========== Scaling Fit ==========")
print(f"kappa ∝ f^{n:.3f}")
print(f"(ideal inductive hanger → n ≈ 2)")
print("=================================")

# fitted curve
f_fit = np.linspace(min(f_GHz), max(f_GHz), 200)
k_fit = 10**b * f_fit**n

# -------------------------
# plotting
# -------------------------
plt.figure(figsize=(6,5))

plt.loglog(f_GHz, kappa_kHz, 'o', label='data', markersize=7)
plt.loglog(f_fit, k_fit, '-', label=f'fit: f^{n:.2f}')

plt.xlabel("Resonator frequency (GHz)")
plt.ylabel("κ / 2π (kHz)")
plt.grid(True, which="both", ls="--", alpha=0.4)
plt.legend()

plt.tight_layout()
plt.show()