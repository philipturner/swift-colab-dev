#!/bin/bash
# Process command-line arguments

old_IFS=$IFS
IFS='.'
read -a strarr <<< "$1"
component_count=${#strarr[*]}

if [[ $component_count -ge 2 ]]; then
  # First argument is two components separated by a period like "5.6" or three
  # components like "5.5.3".
  toolchain_type="release"
else
  IFS='-'
  read -a strarr <<< "$1"
  component_count=${#strarr[*]}
  
  if [[ $component_count == 3 ]]; then
    # First argument is three components in the format "YYYY-MM-DD".
    toolchain_type="snapshot"
  else
    # First argument is absent or improperly formatted.
    toolchain_type="invalid"
  fi
fi

version=$1
IFS=$old_IFS

if [[ $# == 1 ]]; then
  # Release mode - tailored for the fastest user experience.
  mode="release"
elif [[ $# == 2 && $2 == "--swift-colab-dev" ]]; then
  # Dev mode - for debugging and modifying Swift-Colab.
  mode="dev"
else
  # Unrecognized flags were passed in.
  mode="invalid"
fi

if [[ $toolchain_type == "invalid" || $mode == "invalid" ]]; then
  echo "Usage: install_swift.sh {MAJOR.MINOR.PATCH | YYYY-MM-DD} [--swift-colab-dev]"
  exit -1
fi

# Move to /opt/swift

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
  mkdir /opt/swift/build
  mkdir /opt/swift/include
  mkdir /opt/swift/lib
  mkdir /opt/swift/packages
  mkdir /opt/swift/progress
  # TODO: change to putting Python in there
  echo "swift" > /opt/swift/runtime_type
fi

cd /opt/swift
echo $mode > /opt/swift/mode # Is this malformatted?

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
  
  if [[ $toolchain_type == "release" ]]; then
    branch="swift-$version-release"
    release="swift-$version-RELEASE"
  elif [[ $toolchain_type == "snapshot" ]]; then
    branch="development"
    release="swift-DEVELOPMENT-SNAPSHOT-$version-a"
  fi
  
  tar_file="$release-ubuntu18.04.tar.gz"
  url="https://download.swift.org/$branch/ubuntu1804/$release/$tar_file"
  
  echo $url
  curl $url | tar -xz
  mv "$release-ubuntu18.04" "toolchain"
  
  echo $version > "progress/swift-version"
fi

export PATH="/opt/swift/toolchain/usr/bin:$PATH"

# Download Swift-Colab

# If in dev mode, re-download philipturner/swift-colab[-dev] every time.
# The easiest way to do this (and repeat behavior for other conditionals)
# is to just add a check of is in dev mode to the conditional.

if [[ ! -e "progress/downloaded-swift-colab" ]]; then
  # Enable these lines only in dev mode
  rm -r swift-colab
  cp -r /content/swift-colab "swift-colab"

  # Enable these lines when not in dev mode
#   echo "Downloading Swift-Colab"
#   git clone --single-branch --branch release/latest \
#     https://github.com/philipturner/swift-colab
#   echo "true" > "progress/downloaded-swift-colab"
else
  echo "Using cached Swift-Colab"
fi

# Build LLDB bindings

if [[ ! -e "progress/compiled-lldb-bindings" ]]; then
  echo "Compiling Swift LLDB bindings"
  cd swift-colab/Sources/LLDBProcess
  
  if [[ ! -d build ]]; then
    mkdir build
  fi
  cd build
  
  clang++ -Wall -O0 -I../include -c ../LLDBProcess.cpp -fpic
  clang++ -Wall -O0 -L/opt/swift/toolchain/usr/lib -shared -o libLLDBProcess.so \
    LLDBProcess.o -llldb
  
  lldb_process_link="/opt/swift/lib/libLLDBProcess.so"
  if [[ ! -L $lldb_process_link ]]; then
    ln -s "$(pwd)/libLLDBProcess.so" $lldb_process_link
  fi
  
  cd /opt/swift
  # Enable this line when not in dev mode
#   echo "true" > "progress/compiled-lldb-bindings"
else
  echo "Using cached Swift LLDB bindings"
fi

# Build JupyterKernel

if [[ ! -e "progress/jupyterkernel-compiler-version" ||
  $version != `cat "progress/jupyterkernel-compiler-version"` ]]
then
  echo "Compiling JupyterKernel"
  
  jupyterkernel_path="packages/JupyterKernel"
  if [[ -d $jupyterkernel_path ]]; then
    echo "\
Previously compiled with a different Swift version. \
Removing existing JupyterKernel build products."
    rm -r $jupyterkernel_path
  fi
  cp -r "swift-colab/Sources/JupyterKernel" $jupyterkernel_path
  
  cd $jupyterkernel_path
  source_files=$(find $(pwd) -name '*.swift' -print)
  
  mkdir build && cd build
  pythonkit_products="/opt/swift/packages/PythonKit/.build/release"
  swiftc -Onone $source_files \
    -emit-module -emit-library -module-name "JupyterKernel"
  
  jupyterkernel_lib="/opt/swift/lib/libJupyterKernel.so"
  if [[ ! -L $jupyterkernel_lib ]]; then
    echo "Adding symbolic link to JupyterKernel binary"
    ln -s "$(pwd)/libJupyterKernel.so" $jupyterkernel_lib
  fi
  
  cd /opt/swift
  # Enable this line when not in dev mode
#   echo $version > "progress/jupyterkernel-compiler-version"
else
  echo "Using cached JupyterKernel library"
fi

# Copy "include" files to /opt/swift/include

swift_colab_include="/opt/swift/swift-colab/Sources/include"

for file in $(ls $swift_colab_include)
do
  src_path="$swift_colab_include/$file"
  dst_path="/opt/swift/include/$file"
  if [[ -e $dst_path ]]; then
    rm $dst_path
  fi
  cp $src_path $dst_path
done

# Overwrite Python kernel

replacing_python_kernel=true

if [[ $replacing_python_kernel == true ]]; then
  register_kernel='
import Foundation

let libJupyterKernel = dlopen("/opt/swift/lib/libJupyterKernel.so", RTLD_LAZY | RTLD_GLOBAL)!
let funcAddress = dlsym(libJupyterKernel, "JupyterKernel_registerSwiftKernel")!

let JupyterKernel_registerSwiftKernel = unsafeBitCast(
  funcAddress, to: (@convention(c) () -> Void).self)
JupyterKernel_registerSwiftKernel()
'
  echo "$register_kernel" > register_kernel.swift
  swift register_kernel.swift
fi
