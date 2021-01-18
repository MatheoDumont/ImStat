
cmake_minimum_required(VERSION 3.1)

project(tp1)

set(CMAKE_BUILD_TYPE RELEASE)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(OpenCV REQUIRED)

set(CMAKE_CXX_STANDARD 11)

file(COPY "data" DESTINATION ${PROJECT_BINARY_DIR})

# file(GLOB INCLUDES include/*.h)

file(GLOB SOURCES src/*.cpp)

include_directories(
  ${OpenCV_INCLUDE_DIRS}
  include/
)

# add_executable(
#   ${CMAKE_PROJECT_NAME}
#   ${SOURCES}
# )

# target_link_libraries(
#   ${CMAKE_PROJECT_NAME}
#   ${OpenCV_LIBS}
#   ${CMAKE_THREAD_LIBS_INIT}
# )

# exec tp1
add_executable(
  tp1
  src/tp1.cpp
)

target_link_libraries(
  tp1
  # BaseFiles
  ${OpenCV_LIBS}
)
