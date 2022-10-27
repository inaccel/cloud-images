PACKER ?= packer

all:
	$(PACKER) init .
ifeq ($(CI), true)
	$(PACKER) build -parallel-builds=1 .
else
	$(PACKER) build .
endif

%: %.pkr.hcl
	$(PACKER) init $<
ifeq ($(CI), true)
	$(PACKER) build -parallel-builds=1 $<
else
	$(PACKER) build $<
endif
