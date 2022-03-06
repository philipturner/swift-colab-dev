#/bin/bash
# Download Swift

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
fi

cd /opt/swift
reinstalling_swift=false
is_dev=false
swift_version="-1"

if [[ $# == 2 && "$1" == "--snapshot" ]]; then
  is_dev=true
  swift_version="dev ($2)"
elif [[ $# == 1 && "$1" != "--help" ]]; then
  swift_version="$1"
else
  echo "Usage: bash install_swift.sh [<version>] | [--snapshot <YYYY-MM-DD>]"
fi

if [[ $is_dev == false ]]; then
  echo "hello world 1"
else
  echo "hello world 2"
fi

echo $swift_version
echo $is_dev
