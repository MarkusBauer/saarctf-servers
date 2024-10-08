#!/usr/bin/env bash


if [ "$1" != "noerror" ]; then
	set -ex
fi

git -C /opt/gameserver stash
git -C /opt/gameserver pull
git -C /opt/gameserver stash apply || true
git -C /opt/gameserver submodule init
git -C /opt/gameserver submodule update
git -C /opt/config pull


source /etc/profile.d/env.sh



echo "=== BUILD FLAG SUBMISSION SERVER ==="
cd /opt/gameserver/flag-submission-server
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DPostgreSQL_ADDITIONAL_VERSIONS=15 ..
make -j`nproc`



echo "=== UPDATE DB ==="
cd /opt/gameserver
/opt/gameserver/run.sh -m alembic upgrade head



echo "=== BUILD Frontend ==="
cd /opt/gameserver
npm install
npm run build
cd /opt/gameserver/scoreboard
npm install
npm run build



echo "=== DONE ==="
echo "You might want to restart things depending on your changes:"
echo "  systemctl restart uwsgi"
echo "  systemctl restart submission-server"
