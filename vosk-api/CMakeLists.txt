# Definisikan source files untuk library

set(VOSK_SOURCES
    src/recognizer.cc
    src/language_model.cc
    src/model.cc
    src/spk_model.cc
    src/vosk_api.cc
    src/postprocessor.cc
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
    -O0
    -Wno-deprecated-declarations
    -fPIC
)

# Tambahkan definisi preprocessor ke target 'vosk'
# -DFST_NO_DYNAMIC_LINKING
target_compile_definitions(vosk PRIVATE
    FST_NO_DYNAMIC_LINKING
)

set(OPENBLAS_ROOT "${CMAKE_SOURCE_DIR}/tools/OpenBLAS/install") # Asumsi OpenBLAS ada di dalam tools Kaldi

target_include_directories(vosk PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    src
    tools/openfst/include
    ${OPENBLAS_ROOT}/include
)

# --- Pengaturan Linker ---

# Link library-library tersebut ke target 'vosk'
target_link_libraries(vosk PRIVATE 
    kaldi-online2   
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
    ${CMAKE_SOURCE_DIR}/tools/openfst/lib/libfst.a
    ${CMAKE_SOURCE_DIR}/tools/openfst/lib/libfstngram.a
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

add_executable(vosk_main test_vosk.cc) # MyApp adalah nama target executable
target_link_libraries(vosk_main PRIVATE vosk)