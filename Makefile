PPI ?= 200

pptx:
	@test -n "$(IN)" || (echo "Usage: make pptx IN=path/to/file.typ" && false)
	touying compile $(IN) --format pptx --root . --ppi $(PPI)

pdf:
	@test -n "$(IN)" || (echo "Usage: make pdf IN=path/to/file.typ" && false)
	touying compile $(IN) --format pdf --root .
