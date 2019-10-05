#!/bin/sh

# Dependencies:
#
# - pandoc
# - LaTeX with:
#   - XeLaTeX
#   - pgfpages, fvextra, and csquotes
#   - Recent (Git) Metropolis theme
#   - Recent (Git) Owl color theme
#   - See https://pandoc.org/MANUAL.html#creating-a-pdf for additional
#     dependencies


pandoc slides.md -t beamer -so slides.tex \
	--highlight-style breezedark \
	--pdf-engine xelatex \
	--pdf-engine-opt=-aux-directory=./build \
	--pdf-engine-opt=-shell-escape \
	"$@"

latexmk -shell-escape \
	-xelatex \
	-8bit \
	-interaction=nonstopmode \
	-verbose \
	-file-line-error \
	-output-directory=./build slides
