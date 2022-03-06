#/bin/bash
# Download Swift

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
fi

cd /opt/swift

if [[ $# == 2 && "$1" == "--snapshot" ]]; then
  is_dev=true
  swift_version=$2
elif [[ $# == 1 && "$1" != "--help" ]]; then
  is_dev=false
  swift_version=$1
else
  echo "Usage: bash install_swift.sh [<version>] | [--snapshot <YYYY-MM-DD>]"
  exit -1
fi

echo "Downloading Swift $swift_version"

reinstalling_swift=false
