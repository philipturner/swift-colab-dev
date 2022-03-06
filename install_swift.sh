# Download Swift

if [[ ! -d /opt/swift ]]; then
  mkdir /opt/swift
fi

cd /opt/swift
reinstalling_swift=false
is_dev=false
swift_version="-1"

if [[ $# == 2 && "$1" == "-dev" ]]; then
  is_dev = true
  swift_version = "dev $2"
elif [[ $# == 1 ]]; then
  swift_version = "$1"
else
  echo "Usage: bash install_swift.sh [-dev] VERSION"
fi

echo $swift_version
echo $is_dev
