#!/usr/bin/env bash

set -eu

function show_help() {
    echo "Syntax: ./pcap-compress.sh [-j N] [-s SERVICE_ID] [-g]"
    echo "  -j: parallel compression tasks (default: 4)"
    echo "  -s: service ID for team pcaps only (default: all services)"
    echo "  -g: compress gameserver traffic (default: team traffic)"
}

OPTIND=1         # Reset in case getopts has been used previously in the shell.

concurrency=4
prefix=
folder=teamtraffic

while getopts "h?j:s:g" opt; do
  case "$opt" in
    h|\?)
      show_help
      exit 0
      ;;
    j)  concurrency=$OPTARG
      ;;
    g)  folder=gametraffic
      ;;
    s)  prefix="_svc$(printf "%02d" $OPTARG)"
      ;;
  esac
done


before=$(du -hs /mnt/pcaps/$folder)

echo "Compressing pcaps: /mnt/pcaps/$folder/*$prefix.pcap ..."

parallel -j $concurrency zstd --rm -T1 ::: /mnt/pcaps/$folder/*$prefix.pcap

echo "[[ Done ]]"
echo "Before: $before"
echo "After:  $(du -hs /mnt/pcaps/$folder)"

