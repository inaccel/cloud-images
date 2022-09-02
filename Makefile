PACKER ?= packer

all:
	$(PACKER) init .
	$(PACKER) build .

%: %.pkr.hcl
	$(PACKER) init $<
	$(PACKER) build $<
