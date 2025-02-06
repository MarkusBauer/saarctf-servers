#!/usr/bin/env bash

set -x

pids=()

for i in $(seq 1 400); do
	ip link del tun$i &
	pids[${i}]=$!
done

# wait for all pids
for pid in ${pids[*]}; do
    wait $pid
done

echo "[DONE]"
