# Tentukan versi minimum CMake yang diperlukan
cmake_minimum_required(VERSION 3.13)

# Definisikan nama proyek dan bahasa yang digunakan (C++)
project(VoskLib CXX)

# --- Konfigurasi Path ---
# Atur path root Kaldi dan OpenBLAS. Ubah ini sesuai dengan lokasi instalasi Anda.
set(KALDI_ROOT "/Volumes/F/vosk/opt/kaldi")
set(OPENBLAS_ROOT "${KALDI_ROOT}/tools/OpenBLAS/install") # Asumsi OpenBLAS ada di dalam tools Kaldi
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")
include(GNUInstallDirs)
include(Utils)

# --- Pengaturan Kompilasi ---

# Atur standar C++ yang diperlukan (C++17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

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