#!/usr/bin/env bash
# Run bootstrap.sh in a throwaway container with stubbed apt-get/systemctl.
# Expect: normal run exits 0; a failing apt-get/systemctl exits non-zero and never
# prints the completion message. Does not provision a real VM or touch the host.
set -u
here=$(cd "$(dirname "$0")" && pwd)
img=bash:5.2

run() { # $1 = command that should fail inside the stub ("" for none)
  docker run --rm --network none -e FAIL="$1" -v "$here/bootstrap.sh:/bootstrap.sh:ro" "$img" bash -c '
    mkdir -p /stub /etc/apache2/sites-available
    for c in apt-get systemctl chown; do
      printf "#!/bin/sh\n[ \"\$FAIL\" = \"%s\" ] && exit 100\nexit 0\n" "$c" > /stub/$c
      chmod +x /stub/$c
    done
    PATH=/stub:$PATH bash /bootstrap.sh'
}

fail=0
out=$(run ""); rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "프로비저닝 완료" && echo "ok   success path exits 0" || { echo "FAIL success path rc=$rc"; fail=1; }
for c in apt-get systemctl; do
  out=$(run "$c"); rc=$?
  if [ $rc -ne 0 ] && ! echo "$out" | grep -q "프로비저닝 완료"; then echo "ok   $c failure -> rc=$rc, no completion message"
  else echo "FAIL $c failure rc=$rc"; fail=1; fi
done
exit $fail
