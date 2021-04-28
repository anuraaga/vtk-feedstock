#!/bin/bash

mkdir build
cd build || exit

BUILD_CONFIG=Release
OSNAME=$(uname)

# Use bash "Remove Largest Suffix Pattern" to get rid of all but major version number
PYTHON_MAJOR_VERSION=${PY_VER%%.*}

VTK_ARGS=()

if [ -f "$PREFIX/lib/libOSMesa32${SHLIB_EXT}" ]; then
    VTK_ARGS+=(
        "-DVTK_DEFAULT_RENDER_WINDOW_OFFSCREEN:BOOL=ON"
        "-DVTK_OPENGL_HAS_OSMESA:BOOL=ON"
        "-DOSMESA_INCLUDE_DIR:PATH=${PREFIX}/include"
        "-DOSMESA_LIBRARY:FILEPATH=${PREFIX}/lib/libOSMesa32${SHLIB_EXT}"
    )

    if [[ "${target_platform}" == linux-* ]]; then
        VTK_ARGS+=(
            "-DVTK_USE_X:BOOL=OFF"
        )
    elif [[ "${target_platform}" == osx-* ]]; then
        VTK_ARGS+=(
            "-DVTK_USE_COCOA:BOOL=OFF"
            "-DCMAKE_OSX_SYSROOT:PATH=${CONDA_BUILD_SYSROOT}"
        )
    fi
else
    TCLTK_VERSION=`echo 'puts $tcl_version;exit 0' | tclsh`

    VTK_ARGS+=(
        "-DVTK_DEFAULT_RENDER_WINDOW_OFFSCREEN:BOOL=OFF"
        "-DVTK_OPENGL_HAS_OSMESA:BOOL=OFF"
        "-DVTK_USE_TK:BOOL=ON"
        "-DTCL_INCLUDE_PATH=${PREFIX}/include"
        "-DTK_INCLUDE_PATH=${PREFIX}/include"
        "-DTCL_LIBRARY:FILEPATH=${PREFIX}/lib/libtcl${TCLTK_VERSION}${SHLIB_EXT}"
        "-DTK_LIBRARY:FILEPATH=${PREFIX}/lib/libtk${TCLTK_VERSION}${SHLIB_EXT}"
    )
    if [[ "${target_platform}" == linux-* ]]; then
        VTK_ARGS+=(
            "-DVTK_USE_X:BOOL=ON"
        )
    elif [[ "${target_platform}" == osx-* ]]; then
        VTK_ARGS+=(
            "-DVTK_USE_COCOA:BOOL=ON"
            "-DCMAKE_OSX_SYSROOT:PATH=${CONDA_BUILD_SYSROOT}"
        )
    fi
fi

if [[ "$target_platform" != "linux-ppc64le" && "$target_platform" != "osx-arm64" ]]; then
    VTK_ARGS+=(
        "-DVTK_MODULE_ENABLE_VTK_GUISupportQt:STRING=YES"
        "-DVTK_MODULE_ENABLE_VTK_RenderingQt:STRING=YES"
    )
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  if [[ "$CMAKE_CROSSCOMPILING_EMULATOR" == "" ]]; then
     echo "cross compiling without an emulator is not supported yet in the recipe even though the package does."
     echo "see https://github.com/Kitware/VTK/blob/948a48ec545a4489e50c77a27cb5a84a2234fd30/CMake/vtkCrossCompiling.cmake."
     exit 1
  fi
  CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CROSSCOMPILING_EMULATOR=${CMAKE_CROSSCOMPILING_EMULATOR}"
fi

echo "VTK_ARGS:" "${VTK_ARGS[@]}"

# now we can start configuring
cmake -LAH .. -G "Ninja" ${CMAKE_ARGS} \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=$BUILD_CONFIG \
    -DCMAKE_PREFIX_PATH:PATH="${PREFIX}" \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH:PATH="${PREFIX}/lib" \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DVTK_BUILD_DOCUMENTATION:BOOL=OFF \
    -DVTK_BUILD_TESTING:BOOL=OFF \
    -DVTK_BUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DVTK_LEGACY_SILENT:BOOL=OFF \
    -DVTK_HAS_FEENABLEEXCEPT:BOOL=OFF \
    -DVTK_WRAP_PYTHON:BOOL=ON \
    -DVTK_PYTHON_VERSION:STRING="${PYTHON_MAJOR_VERSION}" \
    -DPython3_FIND_STRATEGY=LOCATION \
    -DPython3_ROOT_DIR=${PREFIX} \
    -DVTK_MODULE_ENABLE_VTK_PythonInterpreter:STRING=NO \
    -DVTK_MODULE_ENABLE_VTK_RenderingFreeType:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingMatplotlib:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_IOFFMPEG:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_ViewsCore:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_ViewsContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_PythonContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingContextOpenGL2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingCore:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingOpenGL2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_WebGLExporter:STRING=YES \
    -DVTK_DATA_EXCLUDE_FROM_ALL:BOOL=ON \
    -DVTK_USE_EXTERNAL:BOOL=ON \
    -DVTK_MODULE_USE_EXTERNAL_VTK_libharu:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_pegtl:BOOL=OFF \
    "${VTK_ARGS[@]}"

# compile & install!
ninja install -v

# The egg-info file is necessary because some packages,
# like mayavi, have a __requires__ in their __invtkRenderWindow::New()it__.py,
# which means pkg_resources needs to be able to find vtk.
# See https://setuptools.readthedocs.io/en/latest/pkg_resources.html#workingset-objects

cat > $SP_DIR/vtk-$PKG_VERSION.egg-info <<FAKE_EGG
Metadata-Version: 2.1
Name: vtk
Version: $PKG_VERSION
Summary: VTK is an open-source toolkit for 3D computer graphics, image processing, and visualization
Platform: UNKNOWN
FAKE_EGG
