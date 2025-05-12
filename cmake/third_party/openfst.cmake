cmake_minimum_required(VERSION 3.14)
include(FetchContent)

FetchContent_Declare(
        openfst
        GIT_REPOSITORY  https://github.com/rijalulfikri/openfst
        GIT_TAG         18e94e63870ebcf79ebb42b7035cd3cb626ec090 # tag win/1.8.0
)
FetchContent_GetProperties(openfst)
if(NOT openfst_POPULATED)
    FetchContent_Populate(openfst)
    
endif()
