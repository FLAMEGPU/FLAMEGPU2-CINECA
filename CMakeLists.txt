# Set the minimum cmake version to that which supports cuda natively.
cmake_minimum_required(VERSION VERSION 3.18 FATAL_ERROR)

project(FLAMEGPU2-CINECA CUDA CXX)

# Optionaly set the version of flamegpu which should be used.
# Use a branch name such as `master`, or a tagged version such as `v2.0.0-alpha` 
set(FLAMEGPU_VERSION "v2.0.0-alpha.1" CACHE STRING "Git branch or tag to use")

# Our core dependency is FLAMEGPU2 lib, first lets find it
include(${CMAKE_CURRENT_LIST_DIR}/cmake/flamegpu2.cmake)

# Option to enable/disable building the visualisation
option(VISUALISATION "Enable visualisation support" OFF)

# Include common rules.
include(${FLAMEGPU_ROOT}/cmake/common.cmake)

# Define output location of binary files
SET(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE}/)

macro(create_project TARGET_DIR)
      project("${TARGET_DIR}" CUDA CXX)
      # Prepare list of source files
      # Can't do this automatically, as CMake wouldn't know when to regen (as CMakeLists.txt would be unchanged)
      SET(ALL_SRC
          "${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_DIR}/main.cu"
      )

      # Add the executable and set required flags for the target
      add_flamegpu_executable("${TARGET_DIR}" "${ALL_SRC}" "${FLAMEGPU_ROOT}" "${PROJECT_BINARY_DIR}" TRUE)

      # Add src directory to include path
      target_include_directories("${TARGET_DIR}" PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_DIR}")

      # Set the default (visual studio) debugger configure_file
      set_target_properties("${TARGET_DIR}" PROPERTIES VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                                                         VS_DEBUGGER_COMMAND_ARGUMENTS "-s 10")
endmacro()

create_project(boids_spatial3D)
create_project(boids_rtc_spatial3D)
create_project(boids_bruteforce)
create_project(boids_rtc_bruteforce)

# Also set a startup project
#set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"  PROPERTY VS_STARTUP_PROJECT boids_spatial3D)
