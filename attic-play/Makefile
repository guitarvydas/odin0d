.PHONY: run check build vsh

ODIN_FLAGS ?= -debug -o:none

dev: c-stuff
all: odin-stuff c-stuff

c-stuff:
	cc -o play play.c
	./play

odin-stuff:
	odin run . $(ODIN_FLAGS)
