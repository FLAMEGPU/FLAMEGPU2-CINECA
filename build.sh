#!/bin/bash
# Configure temp dir (important for nsight stuff and RTC cache)
export TMPDIR=$CINECA_SCRATCH/tmp-$user 
mkdir -j $CINECA_SCRATCH/tmp-$user
# Load Modules
module load cmake git gnu cuda/11.0
# Clone Git
git clone https://github.com/FLAMEGPU/FLAMEGPU2-CINECA.git && cd FLAMEGPU2-CINECA
# Configure Build
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=70 -DSEATBELTS=OFF -DEXPORT_RTC_SOURCES=ON -DUSE_NVTX=ON
# Execute Build
# (Use 2 threads to avoid consuming shared node, but keep it under 10 mins)
cmake --build . -j 2 --target all