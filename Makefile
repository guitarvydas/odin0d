.PHONY: run check build vsh

ODIN_FLAGS ?= -debug -o:none
0D=syntax/*.odin process/*.odin 0d/*.odin registry0d/*.odin leaf0d/*.odin debug/*.odin process/*.odin

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

demo_basics.bin: demo_basics/*.odin $(0D)
	@echo 'building...'
	odin build demo_basics $(ODIN_FLAGS)

demo_drawio.bin: demo_drawio/*.odin example.drawio $(0D)
	@echo 'building...'
	odin build demo_drawio $(ODIN_FLAGS)

demo_vsh.bin: demo_vsh/*.odin vsh.drawio $(0D)
	@echo 'building...'
	odin build demo_vsh $(ODIN_FLAGS)

clean:
	rm -f demo_basics.bin demo_drawio.bin demo_vsh.bin
