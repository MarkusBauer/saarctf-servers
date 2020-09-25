#!/usr/bin/env bash

set -u

./backup-conntrack.sh  & X1=$!
./backup-logs.sh       & X2=$!

wait $X1 ; X1=$?
wait $X2 ; X2=$?

echo ""
echo ""
echo "Backup jobs finished:"

[ $X1 -eq 0 ] && echo "[OK]  Conntrack backup" || echo "[ERR] Conntrack backup"
[ $X2 -eq 0 ] && echo "[OK]  Log backup" || echo "[ERR] Log backup"

echo "Done."