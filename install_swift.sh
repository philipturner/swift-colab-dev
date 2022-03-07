#!/bin/bash

if [[ ! -d "/opt/swift" ]]; then
  mkdir "/opt/swift"
  mkdir "/opt/swift/packages"
  mkdir "/opt/swift/progress"
fi

cd "/opt/swift"

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

if [[ -e "progress/swift-version.txt" ]]; then
  old_version=`cat "progress/swift-version.txt"`
  
  if [[ $version == $old_version ]]; then
    using_cached_swift=true
  elif [[ -d "toolchain-$version" ]]; then
    using_cached_swift=true
    mv "toolchain" "toolchain-$old_version"
    mv "toolchain-$version" "toolchain"
    echo $version > "progress/swift-version.txt"  
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
  
  echo $version > "progress/swift-version.txt"
fi

# Download secondary dependencies

if [[ ! -e "progress/downloaded-secondary-deps.txt" ]]; then
  echo "Downloading secondary dependencies"

  apt install patchelf
  pip install wurlitzer
  
  cd "packages"
  git clone --single-branch --branch v0.2.1 \
    https://github.com/pvieito/PythonKit
  cd ../
  
  echo "true" > "progress/downloaded-secondary-deps.txt"
else
  echo "Using cached secondary dependencies"
fi

# Build LLDB bindings

# Build PythonKit
# if previously compiled with a different Swift version, delete and re-compile PythonKit
