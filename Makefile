PANDOC := pandoc
BASEDIR = $(CURDIR)
OUTPUTDIR = $(BASEDIR)/output
METADATA = metadata.yaml
BIBLIOGRAPHY = bibliography.bib
CHAPTERS = [0-9]*.md
LICENSE = $(CURDIR)/LICENSE.md

PANDOC_OPTS :=  --filter pandoc-citeproc --toc --chapters --base-header-level=1 --number-sections
TOC_OPTS := --template=$(BASEDIR)/templates/toc.txt --toc --chapters --base-header-level=1 -t markdown

pdf:
	$(PANDOC) $(PANDOC_OPTS) $(CHAPTERS) $(LICENSE) $(METADATA) -o $(OUTPUTDIR)/output.pdf

epub:
	$(PANDOC) $(PANDOC_OPTS) $(CHAPTERS) $(LICENSE) $(METADATA) -o $(OUTPUTDIR)/output.epub

mobi:
	$(PANDOC) $(PANDOC_OPTS) $(CHAPTERS) $(LICENSE) $(METADATA) -o $(OUTPUTDIR)/output.mobi

html:
	$(PANDOC) $(PANDOC_OPTS) $(CHAPTERS) $(LICENSE) $(METADATA) -o $(OUTPUTDIR)/output.html

toc:
	for f in $(CHAPTERS) ; do \
		$(PANDOC) $(TOC_OPTS) $$f -o $(OUTPUTDIR)/$$f.toc ; \
		sed -i "s/#/$$f#/g"  $(OUTPUTDIR)/$$f.toc ; \
	done ; \
	cat $(OUTPUTDIR)/*.toc > $(BASEDIR)/README.md ; \
	rm  $(OUTPUTDIR)/*.toc

