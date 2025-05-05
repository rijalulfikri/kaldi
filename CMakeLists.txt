# Tentukan versi minimum CMake yang diperlukan
cmake_minimum_required(VERSION 3.13)

# Definisikan nama proyek dan bahasa yang digunakan (C++)
project(VoskLib CXX)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/src CACHE PATH "Install path prefix." FORCE)
endif(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

# --- Konfigurasi Path ---
# Atur path root Kaldi dan OpenBLAS. Ubah ini sesuai dengan lokasi instalasi Anda.
set(KALDI_ROOT "/Volumes/F/vosk/opt/kaldi")
set(OPENBLAS_ROOT "${KALDI_ROOT}/tools/OpenBLAS/install") # Asumsi OpenBLAS ada di dalam tools Kaldi
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")
include(GNUInstallDirs)
include(Utils)

message(STATUS "CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")
if(CONDA_ROOT)
    message(STATUS "Adding ${CONDA_ROOT} directories")
    set(CMAKE_INCLUDE_PATH "${CONDA_ROOT}/include")
    set(CMAKE_LIBRARY_PATH "${CONDA_ROOT}/lib")
    link_directories("${CONDA_ROOT}/lib")
    include_directories("${CONDA_ROOT}/include")
    if (NOT CUDA_TOOLKIT_ROOT_DIR)
        set(CUDA_TOOLKIT_ROOT_DIR "${CONDA_ROOT}")
    endif()

endif()

include(third_party/get_third_party)
# find_package(PythonInterp)
find_package(Python 3.8 REQUIRED COMPONENTS Interpreter)
if(NOT PYTHON_EXECUTABLE)
    # Attempt to find Python manually if not found
    find_program(PYTHON_EXECUTABLE python3)
    if(NOT PYTHON_EXECUTABLE)
        message(FATAL_ERROR "Needs python to auto-generate most CMake files, but not found.")
    endif()
endif()
message(STATUS "Using Python executable: ${PYTHON_EXECUTABLE}")

message(STATUS "Running gen_cmake_skeleton.py")
option(BUILD_SHARED_LIBS "Build shared Kaldi libraries." OFF)
set(IS_LIB_SHARE "")
if(BUILD_SHARED_LIBS)
    set(IS_LIB_SHARE "--shared")
endif()
execute_process(COMMAND ${PYTHON_EXECUTABLE}
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_cmake_skeleton.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "--quiet"
    ${IS_LIB_SHARE}
)
unset(IS_LIB_SHARE)

# --- Pengaturan Kompilasi ---

# Atur standar C++ yang diperlukan (C++17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_INSTALL_MESSAGE LAZY) # hide "-- Up-to-date: ..."
if(BUILD_SHARED_LIBS)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    if(WIN32)
        set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
        message(FATAL_ERROR "DLL is not supported currently")
    elseif(APPLE)
        set(CMAKE_INSTALL_RPATH "@loader_path")
    else()
        set(CMAKE_INSTALL_RPATH "$ORIGIN;$ORIGIN/../lib;$ORIGIN/../../tools/openfst/lib")
    endif()
endif()


if(APPLE)
    # Use built-in BLAS on MacOS by default.
    set(MATHLIB "Accelerate" CACHE STRING "OpenBLAS|MKL|Accelerate")
else()
    set(MATHLIB "OpenBLAS" CACHE STRING "OpenBLAS|MKL|Accelerate")
endif()
# option(KALDI_BUILD_EXE "If disabled, will make add_kaldi_executable a no-op" ON)
# option(KALDI_BUILD_TEST "If disabled, will make add_kaldi_test_executable a no-op" ON)
# option(KALDI_USE_PATCH_NUMBER "Use MAJOR.MINOR.PATCH format, otherwise MAJOR.MINOR" OFF)

# # if (KALDI_BUILD_TEST)
# #     include(CTest)
# #     enable_testing()
# # endif()

link_libraries(${CMAKE_DL_LIBS})


find_package(Threads)
link_libraries(Threads::Threads)

if(CONDA_ROOT)
    find_package(BLAS REQUIRED)
    find_package(LAPACK REQUIRED)
    link_libraries(BLAS::BLAS)
    link_libraries(LAPACK::LAPACK)
    # OPENBLAS is equivalent to LAPACKE; see
    # https://github.com/kaldi-asr/kaldi/blob/master/src/matrix/kaldi-blas.h#L95-L113
    add_definitions(-DHAVE_OPENBLAS=1)
    if(MSVC)
        link_libraries(cblas lapack)
        # necessary macros to compile on windows, from here:
        # https://icl.cs.utk.edu/lapack-for-windows/lapack/
        add_definitions(-DADD_)
        add_definitions(-DHAVE_LAPACK_CONFIG_H)
        add_definitions(-DLAPACK_COMPLEX_STRUCTURE)
    else()
        include_directories($ENV{PREFIX}/include)
    endif()
else()
    if(MATHLIB STREQUAL "OpenBLAS")
        add_definitions(-DHAVE_CLAPACK=1)
        include_directories(${CMAKE_CURRENT_SOURCE_DIR}/tools/CLAPACK)
        link_libraries(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    elseif(MATHLIB STREQUAL "MKL")
        if(NOT DEFINED ENV{MKLROOT} OR "$ENV{MKLROOT}" STREQUAL "")
            message(FATAL_ERROR "Environment variable MKLROOT is not defined")
        else()
            message(STATUS "Finding MKL from \"$ENV{MKLROOT}\"")
        endif()
        normalize_env_path(ENV{MKLROOT})
        set(BLA_VENDOR "Intel10_64lp_seq") # use the single threaded MKL by default
        find_package(LAPACK REQUIRED)
        add_definitions(-DHAVE_MKL=1)
        include_directories($ENV{MKLROOT}/include)
        link_libraries(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    elseif(MATHLIB STREQUAL "Accelerate")
        execute_process(COMMAND sw_vers -productVersion
            OUTPUT_VARIABLE MACOS_VERSION)
        if(MACOS_VERSION VERSION_LESS "10.12" AND MACOS_VERSION VERSION_GREATER_EQUAL "10.11")
            message(WARNING
                "**BAD WARNING**: You are using OS X El Capitan.  Some versions of this OS"
                " have a bug in the BLAS implementation that affects Kaldi."
                " After compiling, cd to matrix/ and type 'make test'.  The"
                " test will fail if the problem exists in your version."
                " Eventually this issue will be fixed by system updates from"
                " Apple.  Unexplained crashes with reports of NaNs will"
                " be caused by this bug, but some recipes will (sometimes) work."
            )
        endif()
        set(BLA_VENDOR "Apple")
        find_package(BLAS REQUIRED)
        find_package(LAPACK REQUIRED)
        add_definitions(-DHAVE_CLAPACK=1)
        link_libraries(${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
    else()
        message(FATAL_ERROR "${MATHLIB} is not tested and supported, you are on your own now.")
    endif()
endif()

if(MSVC)
    # Added in source, but we actually should do it in build script, whatever...
    # add_definitions(-DWIN32_LEAN_AND_MEAN=1)

    add_compile_options(/permissive- /FS /wd4819 /EHsc /bigobj)

    # some warnings related with fst
    add_compile_options(/wd4018 /wd4244 /wd4267 /wd4291 /wd4305)

    set(CompilerFlags
        CMAKE_CXX_FLAGS
        CMAKE_CXX_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE
        CMAKE_C_FLAGS
        CMAKE_C_FLAGS_DEBUG
        CMAKE_C_FLAGS_RELEASE
        )
    foreach(CompilerFlag ${CompilerFlags})
      string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
    endforeach()
    set(CUDA_USE_STATIC_CUDA_RUNTIME OFF CACHE INTERNAL "")
    if(NOT DEFINED ENV{CUDAHOSTCXX})
        set(ENV{CUDAHOSTCXX} ${CMAKE_CXX_COMPILER})
    endif()
    if(NOT DEFINED CUDA_HOST_COMPILER)
        set(CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    endif()
endif()

find_package(CUDAToolkit)
find_package(CUDA)
if(CUDA_FOUND)
    set(CUDA_PROPAGATE_HOST_FLAGS ON)
    if(MSVC)
        set(KALDI_CUDA_NVCC_FLAGS "--default-stream=per-thread") # Fixes incompatibility with cxx14 and cxx17 for Kaldi vs cuda in VS2019
        list(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler /permissive-,/FS,/wd4819,/EHsc,/bigobj")
        list(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler /wd4018,/wd4244,/wd4267,/wd4291,/wd4305")
        list(APPEND CUDA_NVCC_FLAGS_RELEASE -Xcompiler /MD) # Kaldi will always be dynamically linked to Cuda
        list(APPEND CUDA_NVCC_FLAGS_DEBUG -Xcompiler /MDd)
    else()
    #     list(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler -std=c++${CMAKE_CXX_STANDARD}")
        list(APPEND KALDI_CUDA_NVCC_FLAGS "-Xcompiler -fPIC")
        set(KALDI_CUDA_NVCC_FLAGS "--default-stream=per-thread;-std=c++${CMAKE_CXX_STANDARD}")
    endif()
    set(CUDA_NVCC_FLAGS ${KALDI_CUDA_NVCC_FLAGS} ${CUDA_NVCC_FLAGS})

    add_definitions(-DHAVE_CUDA=1)
    add_definitions(-DCUDA_API_PER_THREAD_DEFAULT_STREAM=1)
    link_libraries(
        ${CUDA_LIBRARIES}
        ${CUDA_CUDA_LIBRARY}
        ${CUDA_CUBLAS_LIBRARIES}
        ${CUDA_CUFFT_LIBRARIES}
        ${CUDA_curand_LIBRARY}
        ${CUDA_cusolver_LIBRARY}
        ${CUDA_cusparse_LIBRARY})

    find_package(NvToolExt REQUIRED)
    include_directories(${NvToolExt_INCLUDE_DIR})
    link_libraries(${NvToolExt_LIBRARIES})


    find_package(CUB REQUIRED)
    include_directories(${CUB_INCLUDE_DIR})
endif()

add_definitions(-DKALDI_NO_PORTAUDIO=1)

if(KALDI_VERSION)
    message(STATUS "KALDI_VERSION set to \"${KALDI_VERSION}\"")
else() # Original functionality
    message(STATUS "Setting KALDI_VERSION with get_version...")
    include(VersionHelper)
    get_version() # this will set KALDI_VERSION and KALDI_PATCH_NUMBER
    if(${KALDI_USE_PATCH_NUMBER})
        set(KALDI_VERSION "${KALDI_VERSION}.${KALDI_PATCH_NUMBER}")
    endif()
endif()

# get_third_party(openfst)
# set(OPENFST_ROOT_DIR ${CMAKE_CURRENT_BINARY_DIR}/openfst)
# include(third_party/openfst_lib_target)
#find_library(OpenFST_LIBRARY
#            NAMES fst
#            PATHS ${CMAKE_CURRENT_SOURCE_DIR}/tools/openfst/lib
#            REQUIRED)
#find_path(OpenFST_INCLUDE_DIR
#            NAMES "fst/fst.h"
#            PATHS "${CMAKE_CURRENT_SOURCE_DIR}/tools/openfst/include"
#            REQUIRED)

# link_libraries(fst)  #TODO ini kok belum bisa????

###
# Tambahkan semua subdirektori utama
set(SUBDIRS
    base bin chain chainbin cudamatrix decoder
    feat featbin fgmmbin fstbin fstext
    gmm gmmbin hmm
    ivector ivectorbin kws kwsbin
    lat latbin lm lmbin matrix
    nnet nnetbin nnet2 nnet2bin nnet3 nnet3bin
    online2 online2bin rnnlm rnnlmbin
    transform tree util
)
add_definitions(-DHAVE_CLAPACK=1)
# target_include_directories
include_directories(vosk PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${KALDI_ROOT}/vosk-api/src # Direktori saat ini (.)
    ${KALDI_ROOT}/src
    ${KALDI_ROOT}/tools/openfst/include
    ${OPENBLAS_ROOT}/include
)
# Tambahkan semua subdirektori utama
foreach(SUBDIR ${SUBDIRS})
    add_subdirectory(src/${SUBDIR})
endforeach()
###
# Definisikan source files untuk library
set(VOSK_SOURCES
    vosk-api/src/recognizer.cc
    vosk-api/src/language_model.cc
    vosk-api/src/model.cc
    vosk-api/src/spk_model.cc
    vosk-api/src/vosk_api.cc
    vosk-api/src/postprocessor.cc
)

# Tambahkan library target (libvosk), tipenya SHARED (.so)
add_library(vosk SHARED ${VOSK_SOURCES})

# Terapkan opsi kompilasi ke target 'vosk'
# -g: Informasi debug
# -O3: Optimasi level 3
# -Wno-deprecated-declarations: Matikan peringatan deprecated
# -fPIC: Position Independent Code (diperlukan untuk shared library)
target_compile_options(vosk PRIVATE
    -g
    -O3
    -Wno-deprecated-declarations
    -fPIC
)

# Tambahkan definisi preprocessor ke target 'vosk'
# -DFST_NO_DYNAMIC_LINKING
target_compile_definitions(vosk PRIVATE
    FST_NO_DYNAMIC_LINKING
)

# Tambahkan include directories ke target 'vosk'
target_include_directories(vosk PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${KALDI_ROOT}/vosk-api/src # Direktori saat ini (.)
    ${KALDI_ROOT}/src
    ${KALDI_ROOT}/tools/openfst/include
    ${OPENBLAS_ROOT}/include
)

# --- Pengaturan Linker ---

# Definisikan path ke static library Kaldi dan dependencies lainnya
# set(KALDI_LIBS 
#     ${KALDI_ROOT}/src/lib/libkaldi-online2.a
#     ${KALDI_ROOT}/src/lib/libkaldi-decoder.a)

# Link library-library tersebut ke target 'vosk'
target_link_libraries(vosk PRIVATE 
    kaldi-online2   #TODO: gunakan yang dibuat oleh CMAKE!!!!
    kaldi-decoder
    kaldi-ivector
    kaldi-gmm
    kaldi-tree
    kaldi-feat
    kaldi-lat
    kaldi-lm
    kaldi-rnnlm
    kaldi-hmm
    kaldi-nnet3
    kaldi-transform
    kaldi-cudamatrix
    kaldi-matrix
    kaldi-fstext
    kaldi-util
    kaldi-base
    # fst # OpenFST library (TODO: bisa ngak ya???)
    ${KALDI_ROOT}/tools/openfst/lib/libfst.a
    ${KALDI_ROOT}/tools/openfst/lib/libfstngram.a
    ${OPENBLAS_ROOT}/lib/libopenblas.a
    # Library berikut mungkin adalah dependensi dari OpenBLAS atau Kaldi math
    # Periksa apakah path dan nama file ini benar untuk instalasi Anda
    ${OPENBLAS_ROOT}/lib/liblapack.a # Mungkin sudah termasuk dalam libopenblas.a
    ${OPENBLAS_ROOT}/lib/libblas.a   # Mungkin sudah termasuk dalam libopenblas.a
    ${OPENBLAS_ROOT}/lib/libf2c.a    # Atau dependensi lain seperti libgfortran, tergantung bagaimana BLAS/LAPACK dikompilasi
)

# Terapkan opsi linker ke target 'vosk'
# -s: Strip symbols (menghapus informasi debug dari hasil akhir)
# -g: Sertakan informasi debug (mungkin redundan jika sudah di compile options, tapi sesuai command line)
# -fPIC: (Biasanya tidak perlu di linker flag jika sudah di compile options, tapi ditambahkan untuk konsistensi)
# Catatan: -s dan -g biasanya saling eksklusif dalam konteks build akhir (Release vs Debug).
#          Menggunakan keduanya secara bersamaan di command line asli mungkin tidak standar.
#          CMake biasanya menangani stripping secara terpisah (misalnya dengan 'strip' tool setelah build).
#          Namun, untuk mereplikasi command line, kita tambahkan flag ini.
target_link_options(vosk PRIVATE
    # -s #Opsional: Hapus simbol debug dari library akhir => membuat library tidak bisa di-debug
    -g
    #-fPIC # Umumnya tidak diperlukan di sini
)

# Opsional: Atur nama output secara eksplisit jika diperlukan (CMake biasanya menanganinya)
# set_target_properties(vosk PROPERTIES OUTPUT_NAME "vosk") # Tanpa "lib" dan ".so"

# Opsional: Atur direktori output library jika tidak ingin di default build directory
set_target_properties(vosk PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

message(STATUS "Configuring Vosk Main Executable (vosk_main)")

add_executable(vosk_main ${KALDI_ROOT}/vosk-api/test_vosk.cc) # MyApp adalah nama target executable
target_link_libraries(vosk_main PRIVATE vosk)



# Opsional: Tambahkan pesan status
message(STATUS "Configuring Vosk Library Build")
message(STATUS "Kaldi Root: ${KALDI_ROOT}")
message(STATUS "OpenBLAS Root: ${OPENBLAS_ROOT}")