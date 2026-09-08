# === Parte 185: el vocabulario de la evaluacion, con los numeros propios ===
# VP/FP/FN/VN solo estan definidos para una pregunta binaria. Con 10 digitos hay
# dos maneras de recuperarlos: (a) uno-contra-el-resto por clase, y (b) la unica
# decision genuinamente binaria del diseno, la clase NADA: hablar o callarse.
import numpy as np
import matplotlib.pyplot as plt

B = "../../clasificador_mnist/"
g = np.load(B + "confusion.npz")          # predicciones SIN rechazar (golden == RTL)
c = np.load(B + "confusion_cmp.npz")      # veredictos de la clase NADA
y, p, val = g["yte"].astype(int), g["pte"].astype(int), c["val"]

M = np.zeros((10, 10), int)
for a, b in zip(y, p): M[a, b] += 1

print("(a) uno-contra-el-resto\n")
print("  clase    VP    FP    FN     VN   precision   recall      F1")
P_, R_, F_ = np.zeros(10), np.zeros(10), np.zeros(10)
for k in range(10):
    VP = M[k, k]; FN = M[k].sum() - VP; FP = M[:, k].sum() - VP
    VN = M.sum() - VP - FP - FN
    P_[k] = VP/(VP+FP); R_[k] = VP/(VP+FN); F_[k] = 2*P_[k]*R_[k]/(P_[k]+R_[k])
    print(f"    {k}     {VP:4d}  {FP:4d}  {FN:4d}  {VN:5d}   {P_[k]:7.2%}  {R_[k]:7.2%}   {F_[k]:.3f}")
print(f"\n  exactitud global = traza/total = {np.trace(M)}/{M.sum()} = {np.trace(M)/M.sum():.2%}")
print(f"  F1 macro (promedio simple de las 10) = {F_.mean():.3f}")

ac = (p == y)
VP = int((val & ac).sum());  FP = int((val & ~ac).sum())
FN = int((~val & ac).sum()); VN = int((~val & ~ac).sum())
print("\n(b) la clase NADA: hablar o callarse\n")
print("                        habria ACERTADO   habria ERRADO")
print(f"  el chip HABLA            VP {VP:5d}        FP {FP:4d}")
print(f"  el chip se CALLA         FN {FN:5d}        VN {VN:4d}")
print(f"\n  cobertura             (VP+FP)/N  = {(VP+FP)/len(y):.2%}")
print(f"  precision al hablar   VP/(VP+FP) = {VP/(VP+FP):.2%}")
print(f"  errores que filtra    VN/(VN+FP) = {VN/(VN+FP):.2%}")
print(f"  aciertos sacrificados FN/(FN+VP) = {FN/(FN+VP):.2%}")

fig, (a1, a2) = plt.subplots(1, 2, figsize=(12, 4.6))
a1.scatter(R_*100, P_*100, s=90, c="#1565c0", zorder=3)
for k in range(10):
    a1.annotate(str(k), (R_[k]*100, P_[k]*100), fontsize=13, weight="bold",
                xytext=(7, -4), textcoords="offset points")
a1.plot([70, 100], [70, 100], "--", c="grey", lw=1, zorder=1)
a1.text(97.5, 95.5, "precisión = recall", fontsize=8, c="grey", rotation=38, ha="right")
# arriba-izquierda = precision alta con recall bajo; abajo-derecha = al reves
a1.text(74.5, 88, "TÍMIDOS\nprecisión alta, recall bajo\ncuando hablan aciertan,\npero se les escapan",
        fontsize=8, c="#ef6c00", ha="left", va="center")
a1.text(99.3, 88.5, "IMANES\nrecall alto, precisión baja\nno se les escapa ninguno,\npero atraen trazos ajenos",
        fontsize=8, c="#c62828", ha="right", va="center")
a1.set_xlabel("recall  (de los que había, cuántos encontré)  %")
a1.set_ylabel("precisión  (de los que dije, cuántos eran)  %")
a1.set_title("Cada dígito falla distinto", fontsize=11)
a1.grid(alpha=.3, zorder=0)

cel = [[(VP, "VP\nhabló y acertó", "#2e7d32"), (FP, "FP\nhabló y erró", "#c62828")],
       [(FN, "FN\nse calló, sabía", "#ef6c00"), (VN, "VN\nse calló, no sabía", "#1565c0")]]
for i in range(2):
    for j in range(2):
        n, tx, col = cel[i][j]
        a2.add_patch(plt.Rectangle((j, 1-i), 1, 1, color=col, alpha=.85))
        a2.text(j+.5, 1.62-i, f"{n}", ha="center", va="center", c="w", fontsize=21, weight="bold")
        a2.text(j+.5, 1.25-i, tx, ha="center", va="center", c="w", fontsize=8.5)
a2.text(.5, 2.12, "habría ACERTADO", ha="center", fontsize=9.5)
a2.text(1.5, 2.12, "habría ERRADO", ha="center", fontsize=9.5)
a2.text(-.06, 1.5, "HABLA", ha="right", va="center", fontsize=9.5)
a2.text(-.06, .5, "se CALLA", ha="right", va="center", fontsize=9.5)
a2.set_xlim(-.95, 2.05); a2.set_ylim(-.05, 2.3); a2.axis("off")
a2.set_title("La clase NADA: la única decisión binaria del diseño", fontsize=11)
plt.tight_layout()
plt.savefig(B + "fig_metricas.png", dpi=150)
plt.show()
