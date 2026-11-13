"""Fabrique les polices de secours de SamaClasse (décision D17).

Atkinson Hyperlegible Next et Playwrite FR Moderne n'ont ni exposants
(10⁻³, 10ⁿ⁺ᵐ), ni flèches, ni grec, ni symboles mathématiques (ℝ, ≈), ni
alphabet phonétique. Ce script découpe dans Noto Sans et Noto Sans Math
(licence OFL, dépôt google/fonts) les seuls blocs Unicode utiles, pour des
fichiers légers (environ 110 Ko pour les deux).

Prérequis : pip install fonttools
Fichiers à télécharger dans <dossier_telechargement> :
  https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans%5Bwdth,wght%5D.ttf
      → enregistrer sous NotoSans-variable.ttf
  https://github.com/google/fonts/raw/main/ofl/notosansmath/NotoSansMath-Regular.ttf
Usage : python sous_ensembles.py <dossier_telechargement> assets/fonts

Si le contenu utilise un nouveau symbole, l'ajouter aux blocs ci-dessous et
relancer ; vérifier ensuite la couverture (requête SQL dans DESIGN.md).
"""
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

src, dst = Path(sys.argv[1]), Path(sys.argv[2])

# Blocs Unicode utiles en cours de collège et lycée, absents d'Atkinson.
TEXTE = [
    (0x00A0, 0x00FF),  # latin-1 : ¹ ² ³ ¼ ½ ¾ µ, absents de Playwrite
    (0x0100, 0x017F),  # latin étendu A : Ŋ ŋ (wolof), absents d'Atkinson
    (0x0250, 0x02FF),  # alphabet phonétique, lettres modificatives (ˣ)
    (0x0300, 0x036F),  # accents combinants : nécessaires avec la lettre de
                       # base dans la même police (ɑ̃ = ɑ + tilde combinant)
    (0x0391, 0x03C9),  # grec moderne (π, Δ, Ω, α…)
    (0x03D1, 0x03D1),  # ϑ
    (0x03D5, 0x03D6),  # ϕ ϖ
    (0x03F5, 0x03F5),  # ϵ
    (0x1D2C, 0x1D6A),  # petites lettres en exposant (ᵃ … ᵐ ᵖ)
    (0x2010, 0x205E),  # ponctuation générale (‿)
    (0x2070, 0x209F),  # exposants et indices (⁰ ⁴ … ⁻ ⁺ ⁿ, ₀ …)
    (0x2100, 0x214F),  # symboles lettres (si Noto Sans les a)
    (0x2150, 0x215F),  # fractions (⅓ …)
    (0x2190, 0x21FF),  # flèches
]
MATHS = [
    (0x2100, 0x214F),  # ℝ ℕ ℤ ℚ …
    (0x2190, 0x21FF),  # flèches
    (0x2200, 0x22FF),  # opérateurs (≈ ≠ ≤ ∈ ∞ √ …)
]


def codes(blocs):
    return [c for a, b in blocs for c in range(a, b + 1)]


def decouper(police, blocs, sortie):
    options = subset.Options()
    # Fonctions typographiques utiles seulement (le reste alourdit le fichier).
    options.layout_features = ["kern", "mark", "mkmk", "ccmp", "locl", "sups", "subs", "frac"]
    options.hinting = False  # inutile au rendu de Flutter, allège le fichier
    options.name_IDs = ["*"]
    options.notdef_outline = True
    sub = subset.Subsetter(options)
    sub.populate(unicodes=codes(blocs))
    sub.subset(police)
    police.save(sortie)
    print(f"{sortie.name}: {sortie.stat().st_size // 1024} Ko, {len(police.getBestCmap())} caractères")


variable = src / "NotoSans-variable.ttf"
# Regular seulement : dans un texte en gras, Flutter épaissit lui-même ces
# symboles isolés, ce qui évite d'embarquer une seconde police (63 Ko).
police = instancer.instantiateVariableFont(TTFont(variable), {"wght": 400, "wdth": 100})
decouper(police, TEXTE, dst / "NotoSansSecours-Regular.ttf")

decouper(TTFont(src / "NotoSansMath-Regular.ttf"), MATHS, dst / "NotoSansMathSecours-Regular.ttf")
