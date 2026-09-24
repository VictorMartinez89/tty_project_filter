#!/usr/bin/env python3
"""metricas_s3_s4.py — todas las metricas de las §3 y §4 del cuaderno 2, con un solo procedimiento.

La §3 comparo cuatro front-ends solo por EXACTITUD (± sigma). La §4 dio la matriz de 11 clases y
un diagrama precision/recall, pero sin tabla. Aqui se calcula todo lo demas, sobre las 10 000 de
test, y se agrega como referencia la cadena del 97,22 % que corre en la placa (§36.15).

CLASIFICACION (lo que el circuito hace: elegir una clase)
  exactitud · precision, recall y F1 (macro, por clase) · exactitud balanceada · kappa de Cohen
  · MCC · top-2 · ROC-AUC uno-contra-todos (con los PUNTAJES ENTEROS de 4 bits, que es lo que
  el circuito tiene) · log-loss y Brier (con las probabilidades del modelo en coma flotante)

REGRESION (donde SI tiene sentido: los puntajes de 4 bits contra los de coma flotante)
  Un clasificador no predice un numero continuo, asi que R2, MAE y RMSE "de la exactitud" no
  significan nada. Pero el circuito SI intenta reproducir un numero continuo: el puntaje de
  cada clase del modelo en coma flotante. MAE, RMSE y R2 de puntaje_4bits*escala contra
  puntaje_float miden cuanto se pierde al cuantizar los pesos. Esa es la regresion honesta aqui.

CLASE NADA (§4): cobertura, precision al hablar, riesgo selectivo, y P/R/F1 con la NADA dentro.

Diferencia con la §3: alli cada numero era el promedio de 5 semillas sobre 20 000; aqui se
entrena UNA vez sobre las 60 000, que es lo que va al silicio. Las sigmas siguen siendo las de
la §19 (1,32 pp con validacion cruzada).
"""
import numpy as np, json, warnings; warnings.filterwarnings("ignore")
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, precision_recall_fscore_support, cohen_kappa_score,
                             matthews_corrcoef, roc_auc_score, log_loss, confusion_matrix,
                             balanced_accuracy_score, r2_score, mean_absolute_error,
                             mean_squared_error, jaccard_score)
import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
import frente_golden as fg
from canny1_mnist import frente_canny1

X, y, Xte, yte = fg.cargar_mnist()
print("front-ends...", flush=True)
F = {}
ms, os_ = fg.frente(X, 110); mt, ot = fg.frente(Xte, 110)
F["Sobel 110 · 24×24"] = (fg.piramide(ms, os_, 1), fg.piramide(mt, ot, 1), None)
F["Sobel 110 · 22×22"] = (fg.piramide(ms[:, 1:-1, 1:-1], os_[:, 1:-1, 1:-1], 1),
                          fg.piramide(mt[:, 1:-1, 1:-1], ot[:, 1:-1, 1:-1], 1), None)
for hi, lo in [(110, 40), (75, 25)]:
    ms, os_ = frente_canny1(X, hi, lo); mt, ot = frente_canny1(Xte, hi, lo)
    F[f"Canny1 {hi}/{lo}"] = (fg.piramide(ms, os_, 1), fg.piramide(mt, ot, 1), mt.sum((1, 2)))

def onehot(v): o = np.zeros((len(v), 10)); o[np.arange(len(v)), v] = 1; return o

def metricas(S_q, pred, proba=None):
    P, R, F1, _ = precision_recall_fscore_support(yte, pred, average="macro", zero_division=0)
    top2 = (np.argsort(-S_q, 1)[:, :2] == yte[:, None]).any(1).mean()
    # AUC uno-contra-todos CLASE POR CLASE con los puntajes enteros: el AUC solo mide el ORDEN,
    # asi que no hace falta convertirlos en probabilidades (sklearn lo exige solo para 'ovr' junto)
    auc = np.mean([roc_auc_score(yte == c, S_q[:, c]) for c in range(10)])
    # especificidad y VPN por clase, desde la matriz: lo que la precision y el recall no miran
    M = confusion_matrix(yte, pred, labels=range(10)); n = M.sum()
    VP = np.diag(M); FP = M.sum(0) - VP; FN = M.sum(1) - VP; VN = n - VP - FP - FN
    d = dict(exactitud=accuracy_score(yte, pred), precision=P, recall=R, f1=F1,
             exact_balanceada=balanced_accuracy_score(yte, pred),
             kappa=cohen_kappa_score(yte, pred), mcc=matthews_corrcoef(yte, pred),
             top2=float(top2), auc=auc, error=1 - accuracy_score(yte, pred),
             especificidad=float(np.mean(VN / (VN + FP))), vpn=float(np.mean(VN / (VN + FN))),
             jaccard=jaccard_score(yte, pred, average="macro"))
    if proba is not None:
        d["logloss"] = log_loss(yte, proba)
        d["brier"] = float(((proba - onehot(yte)) ** 2).sum(1).mean())
    return {k: float(v) for k, v in d.items()}

res, porclase, matrices = {}, {}, {}
for nom, (Ftr, Fte, _) in F.items():
    print(f"  {nom}", flush=True)
    clf = LogisticRegression(max_iter=5000, C=0.002).fit(Ftr, y)
    Wq, esc = fg.cuantizar(clf.coef_, 4); bq = np.round(clf.intercept_ / esc).astype(int)
    S_q = Fte @ Wq.T + bq                           # lo que calcula el circuito
    S_f = clf.decision_function(Fte)                # lo que calcula el modelo
    pred = S_q.argmax(1)
    m = metricas(S_q, pred, clf.predict_proba(Fte))
    m["exactitud_float"] = float(clf.score(Fte, yte))
    # la regresion honesta: puntaje de 4 bits (reescalado) contra puntaje float
    a, b_ = S_f.ravel(), (S_q * esc).ravel()
    m["r2_puntajes"] = float(r2_score(a, b_)); m["mae_puntajes"] = float(mean_absolute_error(a, b_))
    m["rmse_puntajes"] = float(np.sqrt(mean_squared_error(a, b_)))
    m["rango_puntajes"] = float(a.max() - a.min())
    m["acuerdo_float_4bits"] = float((S_f.argmax(1) == pred).mean())
    res[nom] = m
    porclase[nom] = [list(map(float, v)) for v in precision_recall_fscore_support(yte, pred, zero_division=0)[:3]]
    matrices[nom] = confusion_matrix(yte, pred).tolist()
    if nom == "Canny1 110/40": muestra_reg = (a[::37], b_[::37])

# la cadena que corre en silicio: 16 zonas, 78 elegidas, pesos del RTL (no hay modelo float)
print("  la cadena del 97,22 %", flush=True)
p = np.load("pesos_sel78.npz"); W, b, ix = p["W"], p["b"], p["idx"]
mt, ot = frente_canny1(Xte, 90, 32); S78 = fg.piramide(mt, ot, 2)[:, ix] @ W.T + b
pred78 = S78.argmax(1); nom78 = "silicio · 78 caracs"
res[nom78] = metricas(S78, pred78)
porclase[nom78] = [list(map(float, v)) for v in precision_recall_fscore_support(yte, pred78, zero_division=0)[:3]]
matrices[nom78] = confusion_matrix(yte, pred78).tolist()

# ---- §4: el sistema de 11 clases con NADA ----
def once(pred, habla):
    p11 = np.where(habla, pred, 10)
    M = confusion_matrix(yte, p11, labels=range(11))[:10]
    ok = (p11 == yte)
    P, R, F1, _ = precision_recall_fscore_support(yte, p11, labels=range(10), zero_division=0)
    return dict(cobertura=float(habla.mean()), precision_al_hablar=float(ok[habla].mean()),
                riesgo_selectivo=float(1 - ok[habla].mean()),
                errores_filtrados=float((~habla & (pred != yte)).sum() / (pred != yte).sum()),
                aciertos_sacrificados=float((~habla & (pred == yte)).sum() / (pred == yte).sum()),
                recall_con_nada=float(R.mean()), precision_con_nada=float(P.mean()),
                f1_con_nada=float(F1.mean()),
                por_clase=[list(map(float, v)) for v in (P, R, F1)],
                calla_por_clase=[int(v) for v in M[:, 10]]), M.tolist()

d4 = np.load("canny1_completo.npz")
v4, p4 = d4["val"].astype(bool), d4["pte"].astype(int)
sis4, M4 = once(p4, v4)
ss = np.sort(S78, 1); nb = mt.sum((1, 2))
h78 = (nb >= 174) & (nb <= 376) & (ss[:, -1] - ss[:, -2] > 70)
sis78, M78 = once(pred78, h78)
json.dump(dict(front_ends=res, por_clase=porclase, matrices=matrices,
               nada=dict(s4_canny110_40=sis4, silicio_78=sis78), M11=dict(s4=M4, silicio=M78)),
          open("metricas_s3_s4.json", "w"), indent=1)

# ---- impresion ----
cols = ["exactitud", "error", "precision", "recall", "f1", "especificidad", "vpn", "jaccard",
        "exact_balanceada", "kappa", "mcc", "top2", "auc"]
print(f"\n{'':22}" + "".join(f"{c[:9]:>10}" for c in cols))
for n, m in res.items():
    print(f"{n:22}" + "".join(f"{m[c]:10.4f}" for c in cols))
print(f"\n{'regresion 4b vs float':22}{'R2':>10}{'MAE':>10}{'RMSE':>10}{'rango':>10}{'acuerdo':>10}{'logloss':>10}{'Brier':>10}")
for n, m in res.items():
    if "r2_puntajes" in m:
        print(f"{n:22}{m['r2_puntajes']:10.4f}{m['mae_puntajes']:10.3f}{m['rmse_puntajes']:10.3f}"
              f"{m['rango_puntajes']:10.2f}{m['acuerdo_float_4bits']:10.4f}{m['logloss']:10.4f}{m['brier']:10.4f}")
for t, s in [("§4 · Canny 110/40, 40 caracs", sis4), ("silicio · 78 caracs", sis78)]:
    print(f"\nNADA · {t}: cobertura {s['cobertura']:.2%} · precision al hablar {s['precision_al_hablar']:.2%}"
          f" · errores filtrados {s['errores_filtrados']:.1%} · aciertos sacrificados {s['aciertos_sacrificados']:.1%}")
    print("   se calla por clase:", s["calla_por_clase"])

# ---- figura ----
fig = plt.figure(figsize=(16, 10.5)); gs = fig.add_gridspec(2, 3, hspace=.42, wspace=.32)
noms = list(res); col = ["#90a4ae", "#546e7a", "#2e7d32", "#66bb6a", "#c0392b"]
ax = fig.add_subplot(gs[0, :2])
cc = ["exactitud", "precision", "recall", "f1", "kappa", "mcc", "auc"]
w = .8 / len(noms); x = np.arange(len(cc))
for i, n in enumerate(noms):
    ax.bar(x + (i - 2) * w, [res[n][c] * 100 for c in cc], w, color=col[i], label=n, ec="#333", lw=.4)
ax.set_xticks(x); ax.set_xticklabels(["exactitud", "precisión\n(macro)", "recall\n(macro)",
                                      "F1\n(macro)", "κ de\nCohen", "MCC", "ROC-AUC\n(macro)"])
ax.set_ylim(80, 100.5); ax.set_ylabel("%"); ax.grid(axis="y", alpha=.3); ax.legend(fontsize=8, ncol=5, loc="upper left")
ax.set_title("A · Siete métricas, cinco cadenas (4 bits, test de 10 000). La §19 da σ ≈ 1,3 pp", fontsize=10.5, loc="left")

ax = fig.add_subplot(gs[0, 2])
xs, ys = muestra_reg
ax.scatter(xs, ys, s=3, alpha=.35, color="#2e7d32")
lim = [min(xs.min(), ys.min()), max(xs.max(), ys.max())]; ax.plot(lim, lim, "k--", lw=.8)
m = res["Canny1 110/40"]
ax.set_title(f"B · La regresión honesta: puntaje 4 bits vs float\nCanny1 110/40 · R² = {m['r2_puntajes']:.4f}"
             f" · MAE = {m['mae_puntajes']:.2f}", fontsize=10, loc="left")
ax.set_xlabel("puntaje del modelo en coma flotante"); ax.set_ylabel("puntaje del circuito (4 bits) × escala")
ax.grid(alpha=.3)

ax = fig.add_subplot(gs[1, :2])
Fc = np.array([porclase[n][2] for n in noms]) * 100
im = ax.imshow(Fc, cmap="Greens", vmin=80, vmax=100, aspect="auto")
for i in range(len(noms)):
    for j in range(10):
        ax.text(j, i, f"{Fc[i, j]:.1f}", ha="center", va="center", fontsize=8.5,
                color="w" if Fc[i, j] > 94 else "#222")
ax.set_yticks(range(len(noms))); ax.set_yticklabels(noms, fontsize=8.5)
ax.set_xticks(range(10)); ax.set_xlabel("dígito")
ax.set_title("C · F1 por dígito (%). El 7, el 8 y el 9 son los difíciles; el Sobel 24×24 además pierde el 4 y el 9 al cuantizar", fontsize=10.5, loc="left")
plt.colorbar(im, ax=ax, fraction=.025)

ax = fig.add_subplot(gs[1, 2])
for t, s, c in [("§4 · Canny 110/40", sis4, "#2e7d32"), ("silicio · 78", sis78, "#c0392b")]:
    ax.bar(np.arange(10) + (-.2 if c == "#2e7d32" else .2), s["calla_por_clase"], .4, color=c, label=t)
ax.set_xticks(range(10)); ax.set_xlabel("dígito"); ax.set_ylabel("veces que se calla (NADA)")
ax.set_title("D · Dónde se calla la clase NADA", fontsize=10.5, loc="left"); ax.legend(fontsize=8); ax.grid(axis="y", alpha=.3)
fig.savefig("../tesis/figuras/fig_metricas_s3_s4.png", dpi=150, facecolor="white", bbox_inches="tight")
print("\n  -> tesis/figuras/fig_metricas_s3_s4.png · metricas_s3_s4.json")
