.PHONY: all sim clean

all: sim

sim:
	./run_sim.sh

clean:
	rm -rf build sim/build waves
