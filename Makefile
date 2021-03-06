BUILD := _build

VIM_NAMES := \
	macro \
	specialform \
	qualifier \
	function \
	parameter \
	variable \
	constant \
	cise
	# module
	# class
VIM_FILES = $(addprefix $(BUILD)/, $(addsuffix .vim, $(VIM_NAMES)))

TEXI_NAMES := \
	corelib \
	coresyn \
	macro \
	object \
	modgauche \
	modutil \
	modr7rs \
	modsrfi

.PHONY: build clean lint

build: syntax/gauche.vim ftplugin/gauche.vim

clean:
	rm -rf _build

lint:
	@vint **/*.vim

syntax/gauche.vim: $(VIM_FILES)
	./build.scm syntax $@ $^

ftplugin/gauche.vim: $(BUILD)/atdef.tsv
	./build.scm ftplugin $@ $<

$(BUILD)/macro.vim: $(BUILD)/atdef.tsv
	./build.scm macro $< > $@

$(BUILD)/specialform.vim: $(BUILD)/atdef.tsv
	./build.scm specialform $< > $@

$(BUILD)/qualifier.vim: $(BUILD)/atdef.tsv
	./build.scm qualifier $< > $@

$(BUILD)/function.vim: $(BUILD)/atdef.tsv
	./build.scm function $< > $@

$(BUILD)/parameter.vim: $(BUILD)/atdef.tsv
	./build.scm parameter $< > $@

$(BUILD)/variable.vim: $(BUILD)/atdef.tsv
	./build.scm variable $< > $@

$(BUILD)/constant.vim: $(BUILD)/atdef.tsv
	./build.scm constant $< > $@

$(BUILD)/cise.vim: $(BUILD)/atdef.tsv
	./build.sh cise $< > $@

$(BUILD)/module.vim: $(BUILD)/atdef.tsv
	./build.scm module $< > $@

$(BUILD)/class.vim: $(BUILD)/atdef.tsv
	./build.scm class $< > $@

$(BUILD)/atdef.tsv:
	mkdir -p $(BUILD)
	./build.scm tsv $(TEXI_NAMES) > $@
