pdf:
	@bash scripts/build.sh

epub:
	@bash scripts/build.sh epub

mobi:
	@bash scripts/build.sh mobi

html:
	@bash scripts/build.sh html

toc:
	@bash scripts/build.sh toc

clean:
	@rm output/*
