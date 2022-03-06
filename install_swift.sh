#/bin/bash
# Download Swift

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
fi

cd /opt/swift

if [[ $# == 2 && $1 == "--snapshot" ]]; then
  is_dev=true
  version=$2
elif [[ $# == 1 && $1 != "--help" ]]; then
  is_dev=false
  version=$1
else
  echo "Usage: bash install_swift.sh [<version>] | [--snapshot <YYYY-MM-DD>]"
  exit -1
fi

if [[ -e "swift-version.txt" ]]; then
  old_version = `cat "swift-version.txt"`
  
  if [[ version != old_version ]]; then
     echo hi
#     mv -r toolchain "toolchain-$version"
  fi
fi

# instead, say "using cached download: ---" whenever possible
echo "Downloading Swift $version"
# write to swift-version.txt immediately AFTER finish downloading

reinstalling_swift=false
