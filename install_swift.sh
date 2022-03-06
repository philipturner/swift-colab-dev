#!/bin/bash

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
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

if [[ -e "swift-version.txt" ]]; then
  old_version = `cat "swift-version.txt"`
  
  if [[ version == old_version ]]; then
    using_cached_swift=true
  elif [[ -e "toolchain-$version" ]]; then
    mv -r "toolchain-$version" toolchain
    using_cached_swift=true
  else
    mv -r toolchain "toolchain-$old_version"
    using_cached_swift=false
  fi
else
  using_cached_swift=false
fi

if [[ using_cached_swift == false && -e toolchain ]]; then
  echo "There should not be an existing 'toolchain' folder unless using cached Swift."
  exit -1
fi

# Download Swift toolchain

# instead, say "using cached download: ---" whenever possible
echo "Downloading Swift $version"
echo $using_cached_swift

# write to swift-version.txt immediately AFTER finish downloading


# if not using cached Swift, delete build products of PythonKit
