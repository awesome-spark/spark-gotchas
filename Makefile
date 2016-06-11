PANDOC := pandoc
BASEDIR = $(CURDIR)
OUTPUTDIR = $(BASEDIR)/output
METADATA = metadata.yaml
BIBLIOGRAPHY = bibliography.bib

PANDOC_OPTS :=  --filter pandoc-citeproc --toc --chapters --base-header-level=1 --number-sections

pdf:
	$(PANDOC) $(PANDOC_OPTS) *.md $(METADATA) -o $(OUTPUTDIR)/output.pdf

epub:
	$(PANDOC) $(PANDOC_OPTS) *.md $(METADATA) -o $(OUTPUTDIR)/output.epub

mobi:
	$(PANDOC) $(PANDOC_OPTS) *.md $(METADATA) -o $(OUTPUTDIR)/output.mobi

html:
	$(PANDOC) $(PANDOC_OPTS) *.md $(METADATA) -o $(OUTPUTDIR)/output.html
