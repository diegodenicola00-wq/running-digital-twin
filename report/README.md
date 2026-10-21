# Report

Technical report of the project (English, LaTeX, ~8-12 pages).

| File | Content |
|---|---|
| `main.tex` | the report: structure, equations, tables, figures |
| `references.bib` | bibliography (entries marked CHECK: verify pages/authors) |
| `figures/` | vector PDF figures, written by the MATLAB scripts (`export_report_figure.m`) |
| `draft/report_draft.docx` | Word draft: text is written here first, then moved into `main.tex` |

## Workflow

1. Write a section in `draft/report_draft.docx` (equations as `[EQ: ...]`,
   figures as `[FIG: fig02]`, citations as `[CITE: Busso 2003]`).
2. The text is moved into `main.tex`, numbers are checked against `notes/results_log.md`.
3. Compile on Overleaf: upload the `report/` folder as a new project
   (New Project > Upload Project, as a zip), compiler pdfLaTeX.
4. Commit `main.tex`, `references.bib`, `figures/` and the draft.

## Writing plan

| When | Sections |
|---|---|
| week of 21 Oct | 3 Data, 4 Training load, 5 Performance measurement |
| after each step | 6 Identification, 7 State estimation, 8 Taper planning |
| 18-21 Nov | pre-registered prediction (committed before the race) |
| after 22 Nov | 9 Race result, 10 Discussion, 11 Conclusions, Abstract |
