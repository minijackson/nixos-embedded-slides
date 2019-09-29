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


pandoc slides.md -t beamer -so slides.pdf --highlight-style breezedark --pdf-engine xelatex
