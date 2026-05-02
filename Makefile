PPI ?= 200

.PHONY: new pptx pdf

new:
	@test -n "$(DATE)" || (echo "Usage: make new DATE=YYYY-MM-DD" && false)
	@test ! -e "examples/$(DATE)" || (echo "Directory already exists: examples/$(DATE)" && false)
	mkdir -p "examples/$(DATE)"
	cp rvl_template/main.typ "examples/$(DATE)/main.typ"
	sed -i 's|#import "rvl_theme.typ": \*|#import "../../rvl_template/rvl_theme.typ": *|' "examples/$(DATE)/main.typ"
	@echo "Created examples/$(DATE)/main.typ"
	@echo "Next: edit config-info(...) in examples/$(DATE)/main.typ"

pptx:
	@test -n "$(IN)" || (echo "Usage: make pptx IN=path/to/file.typ" && false)
	touying compile $(IN) --format pptx --root . --ppi $(PPI)

pdf:
	@test -n "$(IN)" || (echo "Usage: make pdf IN=path/to/file.typ" && false)
	touying compile $(IN) --format pdf --root .
