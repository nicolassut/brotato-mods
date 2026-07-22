#!/bin/zsh
# Usage: poll_ids.sh slug1=id1 slug2=id2 ...  Downloads gen_<slug>.png when completed.
cd "${BROTATO_SCRATCH:-/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad}"
PIPE=/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline
TOKEN=$(python3 -c "import json;print(json.load(open('/Users/nicolassutcliffe/brotato-mods/.mcp.json'))['mcpServers']['pixellab']['headers']['Authorization'])")
typeset -A JOBS
for pair in "$@"; do
  JOBS[${pair#*=}]=${pair%%=*}
done
total=${#JOBS}
for i in $(seq 1 60); do
  done_ct=0
  for id name in ${(kv)JOBS}; do
    [ -f gen_${name}.png ] && { done_ct=$((done_ct+1)); continue }
    s=$(python3 "$PIPE/pixellab_mcp.py" call get_object "{\"object_id\": \"$id\"}" | grep -o 'status: [a-z]*' | head -1)
    if [[ "$s" == *completed* ]]; then
      curl -sf -H "Authorization: $TOKEN" -o gen_${name}.png "https://api.pixellab.ai/mcp/objects/$id/download" && done_ct=$((done_ct+1))
    elif [[ "$s" == *failed* ]]; then
      echo "FAILED: $name ($id)"
    fi
  done
  echo "poll $i: $done_ct/$total"
  [ $done_ct -eq $total ] && echo DOWNLOADED && exit 0
  sleep 20
done
echo TIMEOUT; exit 2
