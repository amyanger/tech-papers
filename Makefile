# tech-papers — build commands
#
#   make new SLUG=2026-06-26-my-title   scaffold a new paper from the template
#   make all SLUG=2026-06-26-my-title   render PDF + HTML  (default)
#   make pdf SLUG=...                    render PDF only
#   make html SLUG=...                   render HTML only
#   make list                           list existing papers
#   make clean                          remove build/ artifacts

SLUG ?=

.PHONY: all pdf html new list clean

all:
	@scripts/build.sh "$(SLUG)" all

pdf:
	@scripts/build.sh "$(SLUG)" pdf

html:
	@scripts/build.sh "$(SLUG)" html

new:
	@test -n "$(SLUG)" || { echo "Usage: make new SLUG=YYYY-MM-DD-title"; exit 1; }
	@mkdir -p "papers/$(SLUG)/figures"
	@cp -n templates/paper-template.md "papers/$(SLUG)/paper.md"
	@touch "papers/$(SLUG)/refs.bib"
	@echo "Created papers/$(SLUG)/ — edit paper.md, then: make all SLUG=$(SLUG)"

list:
	@ls -1 papers 2>/dev/null || echo "(no papers yet)"

clean:
	@rm -rf build && echo "Removed build/"
