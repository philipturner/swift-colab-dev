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
  
  if [[ version == old_version ]]; then
    using_cached_swift=true
  elif [[ -e "toolchain-$version" ]]; then
    mv -r "toolchain-$version" "toolchain"
    using_cached_swift=true
  else
    mv -r "toolchain" "toolchain-$old_version"
    using_cached_swift=false
  fi
else
  using_cached_swift=false
fi

if [[ using_cached_swift == false && -e "toolchain" ]]; then
  echo "There should be no 'toolchain' folder unless using cached Swift."
  exit -1
fi

if [[ using_cached_swift == true && ! -e "toolchain" ]]; then
  echo "There should be a 'toolchain' folder when using cached Swift."
  exit -1
fi

# Download Swift toolchain

if [[ using_cached_swift == true ]]; then
  echo "Using previously downloaded Swift $version"
else
  echo "Downloading Swift $version"
  
  if [[ is_dev ]]; then
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
  mv $tar_file "toolchain"
  
  echo $version > "swift-version.txt"
fi

# write to swift-version.txt immediately AFTER finish downloading

# make another progress file for all the non-Swift dependencies:
#
# patchelf
# wurlitzer
# PythonKit - to avoid "already exists" errors in the output

# if not using cached Swift, delete build products of PythonKit
