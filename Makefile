.PHONY: run check build vsh

ODIN_FLAGS ?= -debug -o:none

build: demo_basics.bin demo_drawio.bin vsh.bin

run: build runbasic rundrawio runvsh

runbasic: demo_basics.bin
	./demo_basics.bin
rundrawio: demo_draw.bin
	./demo_drawio.bin
runvsh: vsh.bin
	./vsh.bin

check:
	odin check demo_basics
	odin check demo_drawio

demo_basics.bin: demo_basics/*.odin 0d/*.odin syntax/*.odin registry0d/*.odin
	odin build demo_basics $(ODIN_FLAGS)

demo_drawio.bin: demo_drawio/*.odin 0d/*.odin syntax/*.odin registry0d/*.odin
	odin build demo_drawio $(ODIN_FLAGS)

vsh: vsh.bin

vsh.bin: vsh/*.odin syntax/*.odin
	odin build vsh $(ODIN_FLAGS)

dev:
	rm -f vsh.bin
	@echo
	@echo '*** ' "don't forget to make regress" ' ***'
	@echo
	make runvsh

regress:
	rm -f *.bin
	make run
	make runvsh


