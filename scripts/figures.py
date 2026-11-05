"""Genere les figures du rapport a partir des fichiers CSV produits par GAMA.

Usage : python scripts/figures.py   (depuis la racine du depot)
Entrees : resultats/*.csv et resultats/export/*.csv
Sorties : rapport/figures/*.pdf
"""
import csv
import glob
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, ListedColormap

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(RACINE, "resultats")
EXP = os.path.join(RES, "export")
FIG = os.path.join(RACINE, "rapport", "figures")
os.makedirs(FIG, exist_ok=True)

COULEURS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6"]
ENCRE = "#333333"
GRILLE = "#e2e2e2"
BLEUS = LinearSegmentedColormap.from_list("bleus", ["#f4f8fd", "#9ec5f4", "#3987e5", "#1c5cab", "#0d366b"])

plt.rcParams.update({
    "font.size": 9,
    "axes.edgecolor": "#888888",
    "axes.labelcolor": ENCRE,
    "axes.titlesize": 9.5,
    "axes.titleweight": "bold",
    "xtick.color": ENCRE,
    "ytick.color": ENCRE,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.color": GRILLE,
    "grid.linewidth": 0.6,
    "legend.frameon": False,
    "lines.linewidth": 1.6,
    "savefig.bbox": "tight",
})


def lire_csv(chemin):
    with open(chemin, newline="") as f:
        lignes = list(csv.reader(f))
    entete = [c.strip("'\"") for c in lignes[0]]
    return entete, [[float(x) if x not in ("true", "false") else float(x == "true") for x in l] for l in lignes[1:] if l]


def lire_matrice(chemin):
    with open(chemin, newline="") as f:
        return np.array([[float(x) for x in l] for l in csv.reader(f) if l])


def sauver(fig, nom):
    fig.savefig(os.path.join(FIG, nom))
    plt.close(fig)
    print("figure :", nom)


# ---------------------------------------------------------------- Schelling
def schelling_similarite():
    _, d = lire_csv(os.path.join(RES, "resultats_similarite.csv"))
    sw = [l[0] for l in d]
    sim = [l[1] for l in d]
    fig, ax = plt.subplots(figsize=(4.6, 3.0))
    ax.plot([0, 100], [0, 100], color="#aaaaaa", lw=1, ls="--", label="similarité = seuil voulu")
    ax.plot(sw, sim, color=COULEURS[0], marker="o", ms=5, label="similarité à l'équilibre")
    for x, y in zip(sw, sim):
        ax.annotate(f"{y:.0f}", (x, y), textcoords="offset points", xytext=(0, 6), ha="center", fontsize=7.5, color=ENCRE)
    ax.set_xlabel("similar_wanted (%)")
    ax.set_ylabel("similarité moyenne (%)")
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 105)
    ax.legend(loc="lower right", fontsize=8)
    sauver(fig, "schelling_similarite.pdf")


def schelling_cartes():
    fichiers = sorted(glob.glob(os.path.join(EXP, "carte_sw*.csv")))
    if not fichiers:
        return
    fig, axes = plt.subplots(1, len(fichiers), figsize=(1.75 * len(fichiers), 2.1))
    fig.suptitle("similar_wanted", fontsize=9, y=1.04)
    cmap = ListedColormap(["#ffffff", COULEURS[0], COULEURS[1]])
    for ax, f in zip(np.atleast_1d(axes), fichiers):
        _, d = lire_csv(f)
        grille = np.zeros((30, 30))
        for x, y, rouge in d:
            grille[int(y), int(x)] = 2 if rouge else 1
        ax.imshow(grille, cmap=cmap, vmin=0, vmax=2, interpolation="nearest")
        sw = os.path.basename(f).split("_sw")[1].split("_")[0]
        ax.set_title(f"{float(sw) * 100:.0f} %")
        ax.set_xticks([]); ax.set_yticks([]); ax.grid(False)
        for s in ax.spines.values():
            s.set_visible(True); s.set_color("#888888")
    sauver(fig, "schelling_cartes.pdf")


# ---------------------------------------------------------------- BC de base
def bc_trajectoires():
    cas = [("0.5", "d = 0.5, μ = 0.5 (figure 1)"), ("0.2", "d = 0.2, μ = 0.5 (figure 2)")]
    fig, axes = plt.subplots(1, 2, figsize=(6.6, 2.6), sharey=True)
    for ax, (d, titre) in zip(axes, cas):
        m = lire_matrice(os.path.join(EXP, f"base_d{d}_mu0.5_traj.csv"))[:41]
        t = np.repeat(np.arange(m.shape[0]), m.shape[1])
        ax.scatter(t, m.ravel(), s=0.4, color=COULEURS[0], alpha=0.35, linewidths=0, rasterized=True)
        ax.set_title(titre)
        ax.set_xlabel("cycle (1 cycle = 1000 rencontres)")
        ax.set_xlim(0, 40); ax.set_ylim(0, 1)
    axes[0].set_ylabel("opinion")
    sauver(fig, "bc_trajectoires.pdf")


def bc_figure3():
    fig, axes = plt.subplots(1, 2, figsize=(6.6, 2.9), sharey=True)
    for ax, mu in zip(axes, ["0.5", "0.05"]):
        m = lire_matrice(os.path.join(EXP, f"base_d0.1_mu{mu}_init_final.csv"))
        ax.scatter(m[0], m[1], s=2, color=COULEURS[0], linewidths=0, rasterized=True)
        ax.set_title(f"d = 0.1, μ = {mu}")
        ax.set_xlabel("opinion initiale")
        ax.set_xlim(0, 1); ax.set_ylim(0, 1)
    axes[0].set_ylabel("opinion finale")
    sauver(fig, "bc_figure3.pdf")


def bc_figure4():
    _, d = lire_csv(os.path.join(RES, "figure4_agrege.csv"))
    ds = [l[0] for l in d]
    n = d[0][10]
    fig, ax = plt.subplots(figsize=(6.2, 3.1))
    for k in range(7):
        etiquette = f"{k + 1} pic" + ("s" if k else "") if k < 6 else "7 pics et +"
        ax.plot(ds, [l[1 + k] for l in d], color=COULEURS[k], marker="o", ms=3, label=etiquette)
    ax.set_xlabel("seuil d")
    ax.set_ylabel(f"nombre de simulations (sur {n:.0f})")
    ax.set_xlim(0.04, 0.51)
    ax.legend(ncol=4, fontsize=7.5, loc="upper center", bbox_to_anchor=(0.5, 1.2))
    sauver(fig, "bc_figure4.pdf")

    fig, ax = plt.subplots(figsize=(4.6, 2.8))
    xs = np.linspace(0.05, 0.5, 200)
    ax.plot(xs, 1 / (2 * xs), color="#999999", ls="--", lw=1.2, label="$p_{max} = 1/(2d)$")
    ax.plot(ds, [l[8] for l in d], color=COULEURS[0], marker="o", ms=3.5, label="nombre moyen de pics")
    ax.set_xlabel("seuil d")
    ax.set_ylabel("nombre de pics")
    ax.set_ylim(0, 10.5)
    ax.legend(fontsize=8)
    sauver(fig, "bc_moyenne_pics.pdf")


def bc_convergence():
    _, d = lire_csv(os.path.join(RES, "effet_parametres.csv"))
    d = [l for l in d if l[0] == 1000]
    fig, ax = plt.subplots(figsize=(4.6, 2.9))
    for i, seuil in enumerate([0.1, 0.2, 0.3, 0.5]):
        pts = sorted((l[2], l[5]) for l in d if abs(l[1] - seuil) < 1e-9)
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=COULEURS[i], marker="o", ms=4, label=f"d = {seuil}")
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.set_xticks([0.05, 0.1, 0.3, 0.5]); ax.set_xticklabels(["0.05", "0.1", "0.3", "0.5"])
    ax.set_xlabel("μ (échelle log)")
    ax.set_ylabel("cycles avant structure définitive")
    ax.legend(fontsize=8)
    sauver(fig, "bc_convergence.pdf")


# ---------------------------------------------------------------- Grille
def grille(chemin, col_opinion=2):
    _, d = lire_csv(chemin)
    taille = int(max(l[0] for l in d)) + 1
    g = np.zeros((taille, taille))
    for l in d:
        g[int(l[1]), int(l[0])] = l[col_opinion]
    return g, d


def grid_cartes():
    seuils = ["0.3", "0.2", "0.15"]
    fig, axes = plt.subplots(2, 3, figsize=(6.8, 4.4), gridspec_kw={"height_ratios": [2.2, 1]})
    for j, s in enumerate(seuils):
        g, d = grille(os.path.join(EXP, f"grille_d{s}_mu0.3.csv"))
        ax = axes[0, j]
        ax.imshow(g, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
        ax.set_title(f"d = {s}, μ = 0.3")
        ax.set_xticks([]); ax.set_yticks([]); ax.grid(False)
        ax = axes[1, j]
        valeurs = np.round(g.ravel() * 100)
        compte = np.bincount(valeurs.astype(int), minlength=101)
        ax.bar(np.arange(101), compte, width=1.0, color=COULEURS[0])
        ax.set_xlim(-1, 101)
        ax.set_xlabel("100 × opinion")
        if j == 0:
            ax.set_ylabel("agents")
    sauver(fig, "grid_cartes.pdf")


def grid_stats():
    _, d = lire_csv(os.path.join(RES, "grid_stats.csv"))
    d = sorted([l for l in d if abs(l[1] - 0.3) < 1e-9])
    fig, ax = plt.subplots(figsize=(4.6, 2.9))
    xs = [l[0] for l in d]
    ax.plot(xs, [l[5] for l in d], color=COULEURS[0], marker="o", ms=4, label="plus grand cluster")
    ax.plot(xs, [100 * l[4] / 841 for l in d], color=COULEURS[1], marker="s", ms=4, label="agents isolés")
    ax.set_xlabel("seuil d")
    ax.set_ylabel("% des 841 agents")
    ax.set_ylim(0, 105)
    ax.legend(fontsize=8, loc="center right")
    sauver(fig, "grid_stats.pdf")


# ---------------------------------------------------------------- Extremistes
def extremistes_tableau():
    _, d = lire_csv(os.path.join(RES, "extremistes.csv"))
    nes = sorted({l[0] for l in d})
    ds = sorted({l[1] for l in d})
    m = np.zeros((len(nes), len(ds)))
    for l in d:
        m[nes.index(l[0]), ds.index(l[1])] = l[2]
    fig, ax = plt.subplots(figsize=(5.2, 2.9))
    im = ax.imshow(m, cmap=BLEUS, vmin=0, vmax=100, aspect="auto")
    for i in range(len(nes)):
        for j in range(len(ds)):
            ax.text(j, i, f"{m[i, j]:.0f}", ha="center", va="center", fontsize=7.5,
                    color="white" if m[i, j] > 55 else ENCRE)
    ax.set_xticks(range(len(ds))); ax.set_xticklabels([f"{x:g}" for x in ds])
    ax.set_yticks(range(len(nes))); ax.set_yticklabels([f"{x:.0f}" for x in nes])
    ax.set_xlabel("seuil d (opinions dans [-1, 1])")
    ax.set_ylabel("nombre d'extrémistes NE")
    ax.grid(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
    cb.set_label("% d'agents normaux capturés")
    sauver(fig, "extremistes_tableau.pdf")


def extremistes_grilles():
    fichiers = sorted(glob.glob(os.path.join(EXP, "extremistes_NE*.csv")))
    if not fichiers:
        return
    fig, axes = plt.subplots(1, len(fichiers), figsize=(2.4 * len(fichiers), 2.6))
    for ax, f in zip(np.atleast_1d(axes), fichiers):
        g, d = grille(f)
        ax.imshow((g + 1) / 2, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
        ex = [(l[0], l[1]) for l in d if l[3]]
        ax.scatter([e[0] for e in ex], [e[1] for e in ex], s=9, marker="s", color="#e34948", linewidths=0)
        nom = os.path.basename(f)[:-4]
        ne = nom.split("NE")[1].split("_")[0]
        seuil = nom.split("_d")[1]
        ax.set_title(f"NE = {ne}, d = {seuil}")
        ax.set_xticks([]); ax.set_yticks([]); ax.grid(False)
    sauver(fig, "extremistes_grilles.pdf")


if __name__ == "__main__":
    schelling_similarite()
    schelling_cartes()
    bc_trajectoires()
    bc_figure3()
    bc_figure4()
    bc_convergence()
    grid_cartes()
    grid_stats()
    extremistes_tableau()
    extremistes_grilles()
