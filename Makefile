.PHONY: run check build vsh

ODIN_FLAGS ?= -debug -o:none

run: runbasic rundrawio runvsh

runbasic: demo_basics.bin
	@echo 'running...'
	./demo_basics.bin
rundrawio: demo_drawio.bin
	@echo 'running...'
	./demo_drawio.bin
runvsh: demo_vsh.bin
	@echo 'running...'
	./demo_vsh.bin

check:
	odin check demo_basics
	odin check demo_drawio
	odin check demo_vsh

demo_basics.bin: demo_basics/*.odin 0d/*.odin syntax/*.odin registry0d/*.odin
	@echo 'building...'
	odin build demo_basics $(ODIN_FLAGS)

demo_drawio.bin: demo_drawio/*.odin 0d/*.odin syntax/*.odin registry0d/*.odin
	@echo 'building...'
	odin build demo_drawio $(ODIN_FLAGS)

demo_vsh.bin: demo_vsh/*.odin syntax/*.odin process/*.odin 0d/*.odin registry0d/*.odin
	@echo 'building...'
	odin build demo_vsh $(ODIN_FLAGS)

clean:
	rm -f demo_basics.bin demo_drawio.bin demo_vsh.bin
