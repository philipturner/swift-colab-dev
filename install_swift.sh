#!/bin/bash

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
  mkdir /opt/swift/include
  mkdir /opt/swift/lib
  mkdir /opt/swift/packages
  mkdir /opt/swift/progress
fi

cd /opt/swift

# Extract program arguments

if [[ $# == 2 && $1 == "--snapshot" ]]; then
  is_dev=true
  version=$2
elif [[ $# == 1 && $1 != "--help" ]]; then
  is_dev=false
  version=$1
else
  echo "Usage: ./install_swift.sh [<version>] | [--snapshot <YYYY-MM-DD>]"
  exit -1
fi

# Determine whether to reuse cached files

if [[ -e "progress/swift-version" ]]; then
  old_version=`cat "progress/swift-version"`
  
  if [[ $version == $old_version ]]; then
    using_cached_swift=true
  elif [[ -d "toolchain-$version" ]]; then
    using_cached_swift=true
    mv "toolchain" "toolchain-$old_version"
    mv "toolchain-$version" "toolchain"
    echo $version > "progress/swift-version"  
  else
    using_cached_swift=false
    mv "toolchain" "toolchain-$old_version"
  fi
else
  using_cached_swift=false
fi

if [[ $using_cached_swift == false && -e "toolchain" ]]; then
  echo "There should be no 'toolchain' folder unless using cached Swift."
  exit -1
fi

if [[ $using_cached_swift == true && ! -e "toolchain" ]]; then
  echo "There should be a 'toolchain' folder when using cached Swift."
  exit -1
fi

# Download Swift toolchain

if [[ $using_cached_swift == true ]]; then
  echo "Using cached Swift $version"
else
  echo "Downloading Swift $version"
  
  if [[ $is_dev == true ]]; then
    branch="development"
    release="swift-DEVELOPMENT-SNAPSHOT-$version-a"
  else
    branch="swift-$version-release"
    release="swift-$version-RELEASE"
  fi
  
  tar_file="$release-ubuntu18.04.tar.gz"
  url="https://download.swift.org/$branch/ubuntu1804/$release/$tar_file"
  
  echo $url
  curl $url | tar -xz
  mv "$release-ubuntu18.04" "toolchain"
  
  echo $version > "progress/swift-version"
fi

export PATH="/opt/swift/toolchain/usr/bin:$PATH"

# Download secondary dependencies

if [[ ! -e "progress/downloaded-secondary-deps" ]]; then
  echo "Downloading secondary dependencies"

  apt install patchelf
  pip install wurlitzer
  
  cd "packages"
  git clone --single-branch --branch v0.2.1 \
    https://github.com/pvieito/PythonKit
  cd ../
  
  echo "true" > "progress/downloaded-secondary-deps"
else
  echo "Using cached secondary dependencies"
fi

# Download Swift-Colab

if [[ ! -e "progress/downloaded-swift-colab" ]]; then
  cp -r /content/swift-colab "swift-colab"

  # Don't uncomment this until Swift-Colab 2.0 is stable
#   echo "Downloading Swift-Colab"
#   git clone --single-branch --branch release/latest \
#     https://github.com/philipturner/swift-colab
#   echo "true" > "progress/downloaded-swift-colab"
else
  echo "Using cached Swift-Colab"
fi

# Build LLDB bindings

clang_version=$(ls toolchain/usr/lib/clang)
lldb_path="toolchain/usr/lib/liblldb.so.${clang_version}git"

if [[ ! -e "progress/compiled-lldb-bindings" ]]; then
  echo "Compiling Swift LLDB bindings"
  cd swift-colab/Sources/lldb-process
  
  if [[ ! -d build ]]; then
    mkdir build
  fi
  cd build
  
  clang++ -I../include -c ../lldb_process.cpp

  lldb_process_library_link="/opt/swift/lib/llblldb_process.so"
  ln -s "$(pwd)/liblldb_process.so" $lldb_process_library_link
  
  cd /opt/swift
  # Don't uncomment this until Swift-Colab 2.0 is stable
#   echo "true" > "progress/compiled-lldb-bindings"
else
  echo "Using cached Swift LLDB bindings"
fi

# Build PythonKit

if [[ ! -e "progress/pythonkit-compiler-version" || 
  $version != `cat "progress/pythonkit-compiler-version"` ]]
then
  echo "Compiling PythonKit"
  cd "packages/PythonKit"
  
  if [[ -d .build ]]; then
    echo "Previously compiled with a different Swift version. 
Removing existing PythonKit build products."
    rm -r .build
  fi
  
  swift build -c release -Xswiftc -Onone
  pythonkit_library_link="/opt/swift/lib/libPythonKit.so"
  
  if [[ ! -L $pythonkit_library_link ]]; then
    echo "Adding symbolic link to PythonKit binary"
    ln -s "$(pwd)/.build/release/libPythonKit.so" $pythonkit_library_link
  fi

  cd /opt/swift
  echo $version > "progress/pythonkit-compiler-version"
else
  echo "Using cached PythonKit binary"
fi

# Build JupyterKernel

# for addr in $(ls /opt/swift/swift-colab)
# do
#     echo "> [$addr]"
# done
