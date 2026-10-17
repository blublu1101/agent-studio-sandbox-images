#!/usr/bin/env bash
# 镜像冒烟测试：在断网容器中检查运行时版本、命令行工具、Python 包与工作区属主。
# 用法：tests/smoke.sh <镜像引用>
set -euo pipefail

IMAGE=${1:?用法: tests/smoke.sh <镜像引用>}

docker run --rm -i --network none "$IMAGE" bash -s <<'EOF'
set -uo pipefail
failed=0
check() {
  local name=$1; shift
  local out
  if out=$("$@" 2>&1); then
    printf 'OK    %-24s %s\n' "$name" "$(printf '%s' "$out" | head -n 1)"
  else
    printf 'FAIL  %-24s %s\n' "$name" "$out"
    failed=1
  fi
}

check "uid:gid=1000:1000" test "$(id -u):$(id -g)" = "1000:1000"
check "python 3.13" sh -c 'python3 --version | grep -E "^Python 3\.13\."'
check "node 22" sh -c 'node --version | grep -E "^v22\."'
check "npm" npm --version
check "numpy/pandas" python3 -c 'import numpy, pandas; print(numpy.__version__, pandas.__version__)'
check "pandas smoke" python3 -c 'import pandas as pd; assert pd.DataFrame({"a": [1, 2]})["a"].sum() == 3'
for tool in sh bash git curl jq unzip zip xz file tree less ps; do
  check "$tool" sh -c "command -v $tool"
done
check "timeout" timeout 5 true
check "cwd=/workspace" test "$(pwd)" = /workspace
check "/workspace owner" test "$(stat -c %u:%g /workspace)" = "1000:1000"
check "/workspace writable" sh -c 'echo ok > /workspace/.probe && rm /workspace/.probe'
check "/usr not writable" sh -c '! touch /usr/local/bin/.probe 2>/dev/null'
exit "$failed"
EOF

echo "冒烟测试通过：$IMAGE"
