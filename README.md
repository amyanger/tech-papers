# tech-papers

A repository for writing technical papers in Markdown and rendering them to
clean **PDF** and **HTML** for people to read.

## How it works

Each paper lives in its own folder under `papers/`, written in Markdown.
[Pandoc](https://pandoc.org/) renders it to PDF (via the self-contained
[Tectonic](https://tectonic-typesetting.github.io/) LaTeX engine) and to a
styled, standalone HTML file.

```
papers/<date-slug>/
  paper.md      the document (Markdown + YAML front matter)
  refs.bib      citations for this paper (BibTeX)
  figures/      images and diagrams
```

## Requirements

- [Pandoc](https://pandoc.org/) — `brew install pandoc`
- [Tectonic](https://tectonic-typesetting.github.io/) — `brew install tectonic` (for PDF)

Both are already installed on this machine.

## Writing a paper

**Start a new paper** (creates the folder, copies the template):

```sh
make new SLUG=2026-06-26-my-title
```

**Write** in `papers/2026-06-26-my-title/paper.md`. You get:

- Headings, lists, tables, and `inline code`
- Fenced code blocks with syntax highlighting
- Inline LaTeX math: `$E = mc^2$`
- Citations: `[@key]`, with sources defined in `refs.bib`
- Figures: drop images in `figures/` and reference them with `![caption](figures/x.png)`

**Render** to PDF + HTML:

```sh
make all SLUG=2026-06-26-my-title     # both
make pdf SLUG=2026-06-26-my-title     # PDF only
make html SLUG=2026-06-26-my-title    # HTML only
```

Output lands in `build/` (git-ignored). Open the HTML in Safari to read.

**Other commands:**

```sh
make list     # list existing papers
make clean    # remove build/ artifacts
```

## Citations

Add entries to a paper's `refs.bib` in BibTeX format:

```bibtex
@article{smith2026,
  title   = {A Relevant Paper},
  author  = {Smith, Jane},
  year    = {2026},
  journal = {Journal of Things},
}
```

Cite them inline with `[@smith2026]`. The bibliography is generated
automatically into the **References** section.

## Layout

```
papers/        one folder per paper
templates/     paper-template.md — skeleton for new papers
styles/        paper.css — HTML styling
scripts/       build.sh — the Pandoc render wrapper
build/         generated PDF/HTML (git-ignored)
Makefile       convenience commands
```
