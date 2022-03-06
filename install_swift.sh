# Download Swift

if [[ ! -d /opt/swift ]]
then
  mkdir /opt/swift
fi

cd /opt/swift
should_reinstall="false"

echo "$#"
