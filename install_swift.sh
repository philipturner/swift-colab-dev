#!/bin/bash

if [[ ! -d "/opt/swift" ]]; then
  mkdir "/opt/swift"
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

if [[ -e "swift-version.txt" ]]; then
  old_version=`cat "swift-version.txt"`
  echo $version
  echo $old_version
  
  if [[ $version == $old_version ]]; then
    echo control_path_1
    using_cached_swift=true
  elif [[ -d "toolchain-$version" ]]; then
    echo control_path_2
    mv "toolchain" "toolchain-$old_version"
    mv "toolchain-$version" "toolchain"
    echo $version > "swift-version.txt"
    using_cached_swift=true
  else
    echo control_path_3
    mv "toolchain" "toolchain-$old_version"
    using_cached_swift=false
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
  echo "Using previously downloaded Swift $version"
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
  
  echo $version > "swift-version.txt"
fi

# make another progress file for all the non-Swift dependencies:
#
# patchelf
# wurlitzer
# PythonKit - to avoid "already exists" errors in the output

# if not using cached Swift, delete build products of PythonKit
