pdf:
	@bash build.sh

epub:
	@bash build.sh epub

mobi:
	@bash build.sh mobi

html:
	@bash build.sh html

toc:
	@bash build.sh toc

clean:
		@rm output/*
