#!/usr/bin/env bash

set -u

./backup-databases.sh  & X1=$!
./backup-logs.sh       & X2=$!
./backup-checkers.sh   & X3=$!
./backup-prometheus.sh & X4=$!
./backup-scoreboard.sh & X5=$!

wait $X1 ; X1=$?
wait $X2 ; X2=$?
wait $X3 ; X3=$?
wait $X4 ; X4=$?
wait $X5 ; X5=$?

echo ""
echo ""
echo "Backup jobs finished:"

[ $X1 -eq 0 ] && echo "[OK]  Database backup" || echo "[ERR] Database backup"
[ $X2 -eq 0 ] && echo "[OK]  Log backup" || echo "[ERR] Log backup"
[ $X3 -eq 0 ] && echo "[OK]  Checker backup" || echo "[ERR] Checker backup"
[ $X4 -eq 0 ] && echo "[OK]  Prometheus backup" || echo "[ERR] Prometheus backup"
[ $X5 -eq 0 ] && echo "[OK]  Scoreboard backup" || echo "[ERR] Scoreboard backup"

echo "Done."