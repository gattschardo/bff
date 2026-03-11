all: build/bff

build/bff: src/main.cpp build/
	hipcc -O2 --offload-arch=${ROCM_GPU} $< -o $@

clean:
	$(RM) -r build

build/:
	mkdir -p $@
