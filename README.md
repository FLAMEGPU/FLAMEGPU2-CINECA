# FLAME GPU 2 CINECIA Hackathon
This repository contains selected example models for profiling during the hackathon.

* **boids_spatial3D**: Reynolds boids flocking model with 3D spatial messaging communication.
* **boids_rtc_spatial3D**: boids_spatial3D, implemented with runtime compiled (RTC) agent functions.

[Video](https://youtu.be/4GTOQvdV5Mg) of how these models looks is available here.

## Dependencies

The dependencies below are required for building FLAME GPU 2 projects.

### Required

+ [CMake](https://cmake.org/download/) `>= 3.18`
  + CMake `>= 3.15` currently works, but support will be dropped in a future release.
+ [CUDA](https://developer.nvidia.com/cuda-downloads) `>= 11.0` and a Compute Capability `>= 3.5` NVIDIA GPU.
  + CUDA `>= 10.0` currently works, but support will be dropped in a future release.
+ C++17 capable C++ compiler (host), compatible with the installed CUDA version
  + [Microsoft Visual Studio 2019](https://visualstudio.microsoft.com/) (Windows)
  + [make](https://www.gnu.org/software/make/) and either [GCC](https://gcc.gnu.org/) `>= 7` or [Clang](https://clang.llvm.org/) `>= 5` (Linux)
  + Older C++ compilers which support C++14 may currently work, but support will be dropped in a future release.
+ [git](https://git-scm.com/)


## Building FLAME GPU 2 and the Examples

FLAME GPU 2 uses [CMake](https://cmake.org/), as a cross-platform process, for configuring and generating build directives, e.g. `Makefile` or `.vcxproj`. This is used to build the FLAMEGPU2 library, examples, tests and documentation.

Below the core commands are provided, for the full guide refer to the main [FLAMEGPU2 guide](https://github.com/FLAMEGPU/FLAMEGPU2_dev/blob/master/README.md).

### Linux

These commands can be used to build a high performance version, capable of executing on Marconi for profiling:

```
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=70 -DSEATBELTS=OFF -DEXPORT_RTC_SOURCES=ON -DUSE_NVTX=ON
cmake --build . -j `nproc` --target all
```

### Windows

FLAMEGPU2 is cross platform, so can be built on Windows too, however you may wish to update `CUDA_ARCH=70` if you don't have a volta GPU.
```
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=70 -DSEATBELTS=OFF -DUSE_NVTX=ON -DEXPORT_RTC_SOURCES=ON -A x64
ALL_BUILD.sln
```

### Configuring with an out-of-tree FLAMEGPU2

The relevant version of the main FLAMEGPU2 repository will be downloaded via CMake/git at configure time, into `<build>/_deps/FLAMEGPU2-src`.
Instead, you can provide your own local copy of FLAMEGPU2, via `FETCHCONTENT_SOURCE_DIR_FLAMEGPU2`. This will only re-use source files, and not re-use any build directories on disk at the other local location.

i.e.
```bash
cmake .. -DFETCHCONTENT_SOURCE_DIR_FLAMEGPU2=/path/to/FLAMEGPU2
```


## Running The Examples

The below commands will execute the respective models for several steps, and generate both a timeline and full Nsight Compute data collection.

### boids_spatial3D
```
nsys profile -o boids_timeline ./bin/linux-x64/Release/boids_spatial3D -s 10
ncu --set full -o boids_ncu ./bin/linux-x64/Release/boids_spatial3D -s 5
```

### boids_rtc_spatial3D

*Note: On first run RTC agent functions will be compiled at runtime, this may take upto 2 minutes to complete. Further runs will pull the precompiled agent functions from a cache. RTC cache hits will fail if the body of the agent function, the dynamic RTC header or the underlying FLAMEGPU2 lib commit hash has changed.*

```
nsys profile -o boids_rtc_timeline ./bin/linux-x64/Release/boids_rtc_spatial3D -s 10
ncu --set full -o boids_rtc_ncu ./bin/linux-x64/Release/boids_rtc_spatial3D -s 5
```

## Changing the Population Size

The number of agents maps cleanly to the number of active threads, by default these models have 32768 agents each.

In either `main.cu` file you can find the line `env.newProperty("POPULATION_TO_GENERATE", 32768u);`. This value controls the number of agents and can be updated to test different scales.

## FLAMEGPU1

FLAMEGPU1 versions of this model for comparison can be found in this branch of the FLAMEGPU repo: https://github.com/FLAMEGPU/FLAMEGPU/tree/boids-performance
