#!/bin/sh

if [ $# -eq 0 ]
then
  port=5000
else
  if [ "$1" = "--help" ];
  then
    echo "Start VSCode+RDP Docker Container."
    echo ""
    echo "Usage: `basename $0` [rdp port]"
    exit 0
  fi

  port=$1
fi

echo "Killing any previous instances."
sudo docker rm -f vscoderdp_$port

echo "Running VSCode + RDP Service on PORT $port"
sudo docker run -p $port:3389 --name vscoderdp_$port -itd vscoderdp bash
