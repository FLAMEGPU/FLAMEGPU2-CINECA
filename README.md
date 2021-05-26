# FLAME GPU 2 CINECIA Hackathon
This repository contains selected example models for profiling during the hackathon.

**boids_spatial3D**: Reynolds boids flocking model with 3D spatial messaging communication.
**boids_rtc_spatial3D**: boids_spatial3D, implemented with runtime compiled (RTC) agent functions.

## Dependencies

The dependencies below are required for building FLAME GPU 2 projects.

### Required

* [CMake](https://cmake.org/) >= 3.12
  * CMake 3.16 is known to have issues on certain platforms
* [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit) >= 10.0
* [git](https://git-scm.com/): Required by CMake for downloading dependencies
* *Linux:*
  * [make](https://www.gnu.org/software/make/)
  * gcc/g++ >= 6 (version requirements [here](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#system-requirements))
      * gcc/g++ >= 7 required for the test suite 
* *Windows:*
  * Visual Studio 2015 or higher (2019 recommended)


## Building FLAME GPU 2 and the Examples

FLAME GPU 2 uses [CMake](https://cmake.org/), as a cross-platform process, for configuring and generating build directives, e.g. `Makefile` or `.vcxproj`. This is used to build the FLAMEGPU2 library, examples, tests and documentation.

Below the core commands are provided, for the full guide refer to the main [FLAMEGPU2 guide](https://github.com/FLAMEGPU/FLAMEGPU2_dev/blob/master/README.md).

### Linux

These commands can be used to build a high performance version, capable of executing on Marconi for profiling:

```
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=70 -DSEATBELTS=OFF -DUSE_NVTX=ON
cmake --build . -j `nproc` --target all
```

### Windows

FLAMEGPU2 is cross platform, so can be built on Windows too, however you may wish to update `CUDA_ARCH=70` if you don't have a volta GPU.
```
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=70 -DSEATBELTS=OFF -DUSE_NVTX=ON -A x64
ALL_BUILD.sln
```


## Running The Examples

The below commands will execute the respective models for 10 steps, and generate both a timeline and full Nsight Compute data collection.

**boids_spatial3D**
```
nsys profile -o timeline_file ./bin/linux/Release/boids_spatial3D -s 10
ncu --set full -o ncu_file ./bin/linux/Release/boids_spatial3D -s 10
```

**boids_rtc_spatial3D**
*Note: On first run RTC agent functions will be compiled at runtime, this may take upto 2 minutes to complete. Further runs will pull the precompiled agent functions from a cache. RTC cache hits will fail if the body of the agent function, the dynamic RTC header or the underlying FLAMEGPU2 lib commit hash has changed.*
```
nsys profile -o timeline_file ./bin/linux/Release/boids_rtc_spatial3D -s 10
ncu --set full -o ncu_file ./bin/linux/Release/boids_rtc_spatial3D -s 10
```
