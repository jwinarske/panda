
add_library(pandasafety SHARED test.c)
target_include_directories(pandasafety PRIVATE . ../../board)
