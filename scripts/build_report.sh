#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir/rapport"

if command -v latexmk >/dev/null 2>&1; then
    latexmk -pdf -synctex=1 -interaction=nonstopmode -halt-on-error -file-line-error rapport.tex
elif command -v tectonic >/dev/null 2>&1; then
    tectonic --synctex --keep-logs rapport.tex
elif [[ -x "$project_dir/.tools/tectonic" ]]; then
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$project_dir/.tools/cache}"
    "$project_dir/.tools/tectonic" --synctex --keep-logs rapport.tex
else
    echo "Aucun compilateur LaTeX disponible. Sous Ubuntu, installer :" >&2
    echo "sudo apt install latexmk texlive-latex-extra texlive-lang-french lmodern" >&2
    exit 1
fi
