#!/usr/bin/env bash
# AI Toolkit Initializer
# 生成 AI 工作流工具箱到项目根目录
#
# Usage:
#   TOOLKIT_DIR=/path/to/project bash bootstrap.sh
#
set -euo pipefail

# TOOLKIT_DIR = 项目根目录（必须有 CLAUDE.md, AGENTS.md）
if [[ -z "${TOOLKIT_DIR:-}" ]]; then
  echo "错误: 请设置 TOOLKIT_DIR"
  echo "用法: TOOLKIT_DIR=/path/to/project bash bootstrap.sh"
  exit 1
fi

echo "Initializing AI workflow toolkit at: $TOOLKIT_DIR/"

# 项目根目录
ROOT_DIR="$TOOLKIT_DIR"

# 创建子目录结构
mkdir -p "$TOOLKIT_DIR/scripts"
mkdir -p "$TOOLKIT_DIR/catalog"
mkdir -p "$TOOLKIT_DIR/memory"
mkdir -p "$TOOLKIT_DIR/roles"
mkdir -p "$TOOLKIT_DIR/instructions"
mkdir -p "$TOOLKIT_DIR/checkpoints"

# ============================================================
# Create scripts/task.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/task.sh" << 'TASKEOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
TASKS_FILE="$ROOT_DIR/tasks/tasks.json"
STATE_FILE="$TOOLKIT_DIR/state.json"

mkdir -p "$(dirname "$TASKS_FILE")"

init_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"current_task_id": null, "phase": null, "last_updated": null}' > "$STATE_FILE"
  fi
}

read_json() {
  local path="$1"
  if [[ ! -f "$path" ]]; then echo '{}'; return; fi
  python3 - "$path" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f: print(f.read(), end='')
except: print('{}')
PY
}

atomic_write() {
  local path="$1" content="$2"
  echo "$content" > "${path}.tmp.$$"
  mv "${path}.tmp.$$" "$path"
}

next_ids() {
  local tasks; tasks=$(read_json "$TASKS_FILE" '{}')
  local max_id=0
  if [[ "$tasks" != '{}' ]] && [[ "$tasks" != '' ]]; then
    max_id=$(echo "$tasks" | python3 -c "
import json, sys; d=json.load(sys.stdin)
ids=[int(t['task_id'].split('-')[1]) for t in d.get('tasks',[]) if t.get('task_id','').startswith('T-')]
print(max(ids) if ids else 0)
" 2>/dev/null || echo "0")
  fi
  echo "T-$(printf '%03d' $((max_id + 1)))"
}

cmd_list() {
  init_state
  local state; state=$(read_json "$STATE_FILE" '{}')
  local current_id; current_id=$(echo "$state" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('current_task_id',''))" 2>/dev/null || echo "")
  echo "=== 任务列表 ==="
  local tasks; tasks=$(read_json "$TASKS_FILE" '{"tasks": []}')
  if [[ "$tasks" == '{}' ]] || [[ "$tasks" == '' ]]; then echo "(暂无任务)"; return; fi
  echo "$tasks" | python3 -c "
import json, sys
d=json.load(sys.stdin); tasks=d.get('tasks',[]); current_id='$current_id'
print(f'{'ID':<10} {'状态':<10} {'优先级':<10} {'名称'}')
print('-'*80)
for t in tasks:
  marker=' ←' if t.get('task_id','')==current_id else ''
  print(f\"{t.get('task_id',''):<10} {t.get('status',''):<10} {t.get('priority',''):<10} {t.get('name','')}{marker}\")
"
}

cmd_current() {
  init_state
  local state; state=$(read_json "$STATE_FILE" '{}')
  local current_id phase
  current_id=$(echo "$state" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('current_task_id',''))" 2>/dev/null || echo "")
  phase=$(echo "$state" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('phase',''))" 2>/dev/null || echo "")
  if [[ -z "$current_id" ]]; then echo "(无当前任务)"; return; fi
  local tasks; tasks=$(read_json "$TASKS_FILE" '{"tasks": []}')
  echo "$tasks" | python3 -c "
import json, sys
d=json.load(sys.stdin); tasks=d.get('tasks',[]); current_id='$current_id'; phase='$phase'
t=next((t for t in tasks if t.get('task_id')==current_id),None)
if not t: print(f'任务 {current_id} 未找到'); sys.exit(0)
print(f\"ID: {t.get('task_id','')}\\nFeature: {t.get('feature_id','')}\\n名称: {t.get('name','')}\\n优先级: {t.get('priority','')}\\n状态: {t.get('status','')}\\n阶段: {phase}\\n范围: {', '.join(t.get('editable_scope',[]))}\\n请求: {t.get('request','')}\")
"
}

cmd_start() {
  local task_id="${1:-}"
  if [[ -z "$task_id" ]]; then echo "用法: task.sh start <task_id>"; exit 1; fi
  init_state
  local tasks; tasks=$(read_json "$TASKS_FILE" '{"tasks": []}')
  local exists; exists=$(echo "$tasks" | python3 -c "import json,sys; d=json.load(sys.stdin); t=next((t for t in d.get('tasks',[]) if t.get('task_id')=='$task_id'),None); print('yes' if t else 'no')" 2>/dev/null)
  if [[ "$exists" != "yes" ]]; then echo "错误: 任务 $task_id 不存在"; exit 1; fi
  local updated; updated=$(echo "$tasks" | python3 -c "
import json, sys, datetime
d=json.load(sys.stdin); now=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
for t in d.get('tasks',[]):
  if t.get('task_id')=='$task_id': t['status']='active'; t['updated_at']=now
print(json.dumps(d,ensure_ascii=False,indent=2))
")
  atomic_write "$TASKS_FILE" "$updated"
  local state; state=$(read_json "$STATE_FILE" '{}')
  echo "$state" | python3 -c "
import json, sys, datetime
d=json.load(sys.stdin); d['current_task_id']='$task_id'; d['phase']='directive'
d['last_updated']=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
print(json.dumps(d,ensure_ascii=False,indent=2))
" > "$STATE_FILE"
  echo "已设置当前任务: $task_id"
  "$SCRIPT_DIR/checkpoint.sh" save "$task_id" "task started" 2>/dev/null || true
}

cmd_done() {
  local task_id="${1:-}"
  if [[ -z "$task_id" ]]; then echo "用法: task.sh done <task_id>"; exit 1; fi
  init_state
  local tasks; tasks=$(read_json "$TASKS_FILE" '{"tasks": []}')
  local exists; exists=$(echo "$tasks" | python3 -c "import json,sys; d=json.load(sys.stdin); t=next((t for t in d.get('tasks',[]) if t.get('task_id')=='$task_id'),None); print('yes' if t else 'no')" 2>/dev/null)
  if [[ "$exists" != "yes" ]]; then echo "错误: 任务 $task_id 不存在"; exit 1; fi
  local updated; updated=$(echo "$tasks" | python3 -c "
import json, sys, datetime
d=json.load(sys.stdin); now=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
for t in d.get('tasks',[]):
  if t.get('task_id')=='$task_id': t['status']='done'; t['updated_at']=now
print(json.dumps(d,ensure_ascii=False,indent=2))
")
  atomic_write "$TASKS_FILE" "$updated"
  local state; state=$(read_json "$STATE_FILE" '{}')
  echo "$state" | python3 -c "
import json, sys, datetime
d=json.load(sys.stdin)
if d.get('current_task_id')=='$task_id': d['current_task_id']=None; d['phase']=None
d['last_updated']=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
print(json.dumps(d,ensure_ascii=False,indent=2))
" > "$STATE_FILE"
  echo "已完成任务: $task_id"
  "$SCRIPT_DIR/checkpoint.sh" save "$task_id" "task completed" 2>/dev/null || true
}

cmd_create() {
  local task_id; task_id=$(next_ids)
  local name="${1:-}" feature_id="${2:-F-001}" priority="${3:-MEDIUM}" editable_scope="${4:-[\"**\"]}"
  if [[ -z "$name" ]]; then echo "用法: task.sh create <任务名称> [feature_id] [priority] [editable_scope]"; exit 1; fi
  init_state
  local tasks; tasks=$(read_json "$TASKS_FILE" '{"tasks": []}')
  local updated; updated=$(echo "$tasks" | python3 -c "
import json, sys, datetime
d=json.load(sys.stdin); now=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
d.setdefault('tasks',[]).append({'task_id':'$task_id','feature_id':'$feature_id','name':\"\"\"$name\"\"\",'status':'idle','priority':'$priority','editable_scope':json.loads('$editable_scope'),'created_at':now,'updated_at':now})
print(json.dumps(d,ensure_ascii=False,indent=2))
")
  atomic_write "$TASKS_FILE" "$updated"
  local toolkit_name; toolkit_name=$(basename "$TOOLKIT_DIR")
  echo "已创建任务: $task_id - $name"
  echo "使用 $toolkit_name/scripts/task.sh start $task_id 开始工作"
}

CMD="${1:-}"
shift
case "$CMD" in
  list) cmd_list "$@" ;;
  current) cmd_current "$@" ;;
  start) cmd_start "$@" ;;
  done) cmd_done "$@" ;;
  create) cmd_create "$@" ;;
  "") echo "用法: task.sh <list|current|start|done|create> [args]" ;;
  *) echo "未知命令: $CMD" ;;
esac
TASKEOF

# ============================================================
# Create scripts/state.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/state.sh" << 'STATEEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$TOOLKIT_DIR/state.json"
init() { if [[ ! -f "$STATE_FILE" ]]; then echo '{"current_task_id": null, "phase": null, "last_updated": null}' > "$STATE_FILE"; fi; }
show() { init; [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "{}"; }
set_state() { init; local c; c=$(cat "$STATE_FILE"); echo "$c" | python3 -c "import json,sys,datetime; d=json.load(sys.stdin); d['$1']='$2'; d['last_updated']=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'); print(json.dumps(d,ensure_ascii=False,indent=2))" > "$STATE_FILE"; cat "$STATE_FILE"; }
clear() { echo '{"current_task_id": null, "phase": null, "last_updated": null}' > "$STATE_FILE"; echo "状态已清除"; }
CMD="${1:-}"
shift
case "$CMD" in show) show "$@" ;; set) set_state "$@" ;; clear) clear "$@" ;; init) init "$@" ;; *) echo "用法: state.sh <show|set|clear|init>" ;; esac
STATEEOF

# ============================================================
# Create scripts/log.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/log.sh" << 'LOGEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
LOG_FILE="$TOOLKIT_DIR/operations.log"
STATE_FILE="$TOOLKIT_DIR/state.json"
mkdir -p "$(dirname "$LOG_FILE")"
get_val() { python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('$1',''))" 2>/dev/null || echo ""; }
record() {
  local action="${1:-}" detail="${2:-}"
  [[ -z "$action" ]] && echo "用法: log.sh record <action> [detail]" && exit 1
  local ts task_id phase
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  task_id=$(get_val "current_task_id")
  phase=$(get_val "phase")
  echo "[$ts] [${task_id:-NONE}] [${phase:-NONE}] $action $detail" >> "$LOG_FILE"
  echo "已记录: [${task_id:-NONE}] [${phase:-NONE}] $action $detail"
}
show() { [[ ! -f "$LOG_FILE" ]] && echo "(暂无日志)" && return; tail -n "${1:-20}" "$LOG_FILE"; }
clear() { [[ -f "$LOG_FILE" ]] && rm "$LOG_FILE"; echo "日志已清除"; }
CMD="${1:-}"
shift
case "$CMD" in record) record "$@" ;; show) show "$@" ;; clear) clear "$@" ;; *) echo "用法: log.sh <record|show|clear>" ;; esac
LOGEOF

# ============================================================
# Create scripts/checkpoint.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/checkpoint.sh" << 'CHKPEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
CHECKPOINT_DIR="$TOOLKIT_DIR/checkpoints"
mkdir -p "$CHECKPOINT_DIR"
save_checkpoint() {
  local task_id="${1:-}" desc="${2:-auto}"
  [[ -z "$task_id" ]] && echo '{"success":false,"error":"task_id required"}' && return 1
  local ts; ts=$(date '+%Y-%m-%d-%H%M')
  local f="${CHECKPOINT_DIR}/${task_id}-${ts}.json"
  python3 - "$task_id" "$ts" "$desc" "$f" "$ROOT_DIR" <<'PY'
import json, os, sys, datetime
task_id=sys.argv[1]; ts=sys.argv[2]; desc=sys.argv[3]; f=sys.argv[4]; root=sys.argv[5]
files={'tasks.json':os.path.join(root,'tasks','tasks.json'),'current.json':os.path.join(root,'tasks','current-task.json')}
snap={'checkpoint_id':f"{task_id}-{ts}",'task_id':task_id,'description':desc,'created_at':datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),'files':{}}
for n,p in files.items():
  if os.path.exists(p):
    try: snap['files'][n]=json.load(open(p))
    except: pass
with open(f,'w') as fp: json.dump(snap,fp,ensure_ascii=False,indent=2)
print(json.dumps({'success':True,'checkpoint_id':snap['checkpoint_id'],'path':f},ensure_ascii=False))
PY
}
restore_checkpoint() {
  local cid="${1:-}"
  [[ -z "$cid" ]] && echo '{"success":false,"error":"checkpoint_id required"}' && return 1
  local cf; cf=$(ls "$CHECKPOINT_DIR"/${cid}*.json 2>/dev/null | head -1)
  [[ -z "$cf" ]] || [[ ! -f "$cf" ]] && echo "{\"success\":false,\"error\":\"checkpoint not found: $cid\"}" && return 1
  python3 - "$cf" "$ROOT_DIR" <<'PY'
import json, os, sys
cf=sys.argv[1]; root=sys.argv[2]
snap=json.load(open(cf))
for n,data in snap.get('files',{}).items():
  if n=='tasks.json': p=os.path.join(root,'tasks','tasks.json')
  elif n=='current.json': p=os.path.join(root,'tasks','current-task.json')
  else: continue
  with open(p,'w') as fp: json.dump(data,fp,ensure_ascii=False,indent=2)
print(json.dumps({'success':True,'checkpoint_id':snap.get('checkpoint_id'),'restored':list(snap.get('files',{}).keys())},ensure_ascii=False))
PY
}
list_checkpoints() {
  echo "=== 快照列表 ==="
  ls -la "$CHECKPOINT_DIR"/*.json 2>/dev/null | awk '{print $9, $5, $6, $7, $8}' || echo "(无快照)"
}
CMD="${1:-}"
shift
case "$CMD" in save) save_checkpoint "$@" ;; restore) restore_checkpoint "$@" ;; list) list_checkpoints "$@" ;; *) echo "用法: checkpoint.sh <save|restore|list>" ;; esac
CHKPEOF

# ============================================================
# Create scripts/validate.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/validate.sh" << 'VALEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
CONFIG_FILE="$TOOLKIT_DIR/config.json"
STATE_FILE="$TOOLKIT_DIR/state.json"
read_config() { [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE" || echo '{}'; }
get_scope() {
  local tid="${1:-}"
  [[ -z "$tid" ]] || [[ ! -f "$ROOT_DIR/tasks/tasks.json" ]] && echo '["**"]' && return
  python3 - "$ROOT_DIR/tasks/tasks.json" "$tid" <<'PY'
import json, sys
d=json.load(open(sys.argv[1])); t=next((x for x in d.get('tasks',[]) if x.get('task_id')==sys.argv[2]),None)
print(json.dumps(t.get('editable_scope',['**']) if t else ['**']))
PY
}
check_files() {
  local files_json="${1:-[]}"
  local cfg; cfg=$(read_config)
  local fp; fp=$(echo "$cfg" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('forbidden_patterns',[])))" 2>/dev/null || echo "[]")
  if [[ "$fp" == "[]" ]]; then
    local tn; tn=$(basename "$TOOLKIT_DIR")
    fp="[\"**/${tn}/**\",\"**/.gradle/**\",\"**/build/**\",\"**/.idea/**\"]"
  fi
  local tid; [[ -f "$STATE_FILE" ]] && tid=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('current_task_id',''))" 2>/dev/null || echo "")
  local scope; scope=$(get_scope "$tid")
  python3 - "$files_json" "$fp" "$scope" <<'PY'
import json, sys, fnmatch
files=json.loads(sys.argv[1]); forbidden=json.loads(sys.argv[2]); editable=json.loads(sys.argv[3])
violations=[]
for f in files:
  for p in forbidden:
    if fnmatch.fnmatch(f,p) or fnmatch.fnmatch(p,f.replace('**','*')): violations.append(f"禁止区域: {f} (匹配 {p})")
  if editable!=['**']:
    if not any(fnmatch.fnmatch(f,p) or fnmatch.fnmatch(p,f.replace('**','*')) for p in editable): violations.append(f"超出边界: {f}")
print(json.dumps({"valid":len(violations)==0,"violations":violations,"files_checked":len(files)},ensure_ascii=False,indent=2))
PY
}
CMD="${1:-}"
shift
case "$CMD" in check-files) check_files "$@" ;; *) echo "用法: validate.sh check-files <files_json>" ;; esac
VALEOF

# ============================================================
# Create scripts/review.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/review.sh" << 'REVEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
CONFIG_FILE="$TOOLKIT_DIR/config.json"
read_config() { [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE" || echo '{}'; }
do_check() {
  local cfg; cfg=$(read_config)
  local compile_cmd test_cmd fp pp
  compile_cmd=$(echo "$cfg" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('compile_cmd',''))" 2>/dev/null || echo "")
  test_cmd=$(echo "$cfg" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('test_cmd',''))" 2>/dev/null || echo "")
  fp=$(echo "$cfg" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('forbidden_patterns',[])))" 2>/dev/null || echo "[]")
  pp=$(echo "$cfg" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('placeholder_patterns',[])))" 2>/dev/null || echo "[]")
  if [[ "$fp" == "[]" ]]; then local tn; tn=$(basename "$TOOLKIT_DIR"); fp="[\"**/${tn}/**\",\"**/.gradle/**\",\"**/build/**\",\"**/.idea/**\"]"; fi
  if [[ "$pp" == "[]" ]]; then pp='["TODO","FIXME","待实现","后续实现","临时处理","UnsupportedOperationException","NotImplemented","return null;","return Collections.emptyList();"]'; fi
  echo "=== 代码审查 ==="
  local issues=() warnings=() pass=true
  local files=()
  while IFS= read -r f; do files+=("$f"); done < <(git -C "$ROOT_DIR" diff --name-only --diff-filter=ACM 2>/dev/null || true)
  echo "[1/4] 发现 ${#files[@]} 个已修改文件"
  for f in "${files[@]:-}"; do
    for pat in $(echo "$fp" | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)))" 2>/dev/null); do
      [[ "$f" == $pat ]] || [[ "$f" == $(echo "$pat" | sed 's/\*\*/.*/g') ]] && issues+=("禁止区域: $f") && pass=false
    done
  done
  echo "[2/4] 边界检查: $([[ ${#issues[@]} -eq 0 ]] && echo '✓ 通过' || echo '✗ 失败')"
  local placeholders=()
  for f in "${files[@]:-}"; do [[ -f "$ROOT_DIR/$f" ]] && for pat in $(echo "$pp" | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)))" 2>/dev/null); do grep -q -- "$pat" "$ROOT_DIR/$f" 2>/dev/null && placeholders+=("$f: $pat"); done; done
  echo "[3/4] Placeholder 检查: $([[ ${#placeholders[@]} -eq 0 ]] && echo '✓ 无' || echo \"✗ 发现 ${#placeholders[@]} 个\")"
  echo "[4/4] 编译检查..."
  if [[ -n "$compile_cmd" ]]; then
    if (cd "$ROOT_DIR" && eval "$compile_cmd" > /dev/null 2>&1); then echo "    ✓ 编译通过"
    else echo "    ✗ 编译失败"; issues+=("编译失败"); pass=false; fi
  else echo "    ⊘ 未配置"; fi
  echo ""
  if $pass; then echo "✓ 审查通过"; exit 0
  else echo "✗ 审查失败"; for i in "${issues[@]:-}"; do echo "  - $i"; done; exit 1; fi
}
CMD="${1:-}"
shift
case "$CMD" in check) do_check "$@" ;; *) echo "用法: review.sh check" ;; esac
REVEOF

# ============================================================
# Create scripts/catalog.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/catalog.sh" << 'CATEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG_DIR="$TOOLKIT_DIR/catalog"
ERRORS_FILE="$CATALOG_DIR/errors.json"
mkdir -p "$CATALOG_DIR"
[[ ! -f "$ERRORS_FILE" ]] && echo '{"catalog_version":"1.0","last_updated":null,"errors":[]}' > "$ERRORS_FILE"
add_error() {
  local et="${1:-}" pat="${2:-}" sol="${3:-}" ev="${4:-}" fl="${5:-}"
  [[ -z "$et" ]] && echo '{"success":false,"error":"error_type required"}' && return 1
  python3 - "$ERRORS_FILE" "$et" "$pat" "$sol" "$ev" "$fl" <<'PY'
import json, sys, datetime
path=sys.argv[1]; et=sys.argv[2]; pat=sys.argv[3]; sol=sys.argv[4]; ev=sys.argv[5]; fl=sys.argv[6]
d=json.load(open(path)); now=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
for e in d.get('errors',[]):
  if e.get('pattern')==pat: e['occurrence_count']=e.get('occurrence_count',0)+1; e['last_seen']=now; eid=e.get('id'); break
else:
  max_id=max([int(e.get('id','ERR-000').split('-')[1]) for e in d.get('errors',[]) if e.get('id','').startswith('ERR-')] or [0])
  d.setdefault('errors',[]).append({'id':f'ERR-{max_id+1:03d}','type':et,'pattern':pat,'solution':sol,'evidence':ev,'file':fl,'first_seen':now,'last_seen':now,'occurrence_count':1,'severity':'medium'})
  eid=(d.get('errors')[-1].get('id') if d.get('errors') else None)
d['last_updated']=now
with open(path,'w') as fp: json.dump(d,fp,ensure_ascii=False,indent=2)
print(json.dumps({'success':True,'error_id':eid},ensure_ascii=False))
PY
}
lookup() {
  local et="${1:-}"
  python3 - "$ERRORS_FILE" "$et" <<'PY'
import json, sys
d=json.load(open(sys.argv[1])); et=sys.argv[2]
errors=[e for e in d.get('errors',[]) if e.get('type','')==et] if et else d.get('errors',[])
print(json.dumps({'count':len(errors),'errors':errors[-10:]},ensure_ascii=False,indent=2))
PY
}
stats() {
  python3 - "$ERRORS_FILE" <<'PY'
import json, sys
from collections import Counter
d=json.load(open(sys.argv[1])); errors=d.get('errors',[])
tc=Counter(e.get('type','') for e in errors)
print(f"=== 错误统计 ===\n总错误: {len(errors)}\n按类型:")
for t,c in tc.most_common(): print(f"  {t}: {c}")
PY
}
CMD="${1:-}"
shift
case "$CMD" in add) add_error "$@" ;; lookup) lookup "$@" ;; stats) stats "$@" ;; init) [[ ! -f "$ERRORS_FILE" ]] && echo '{"catalog_version":"1.0","last_updated":null,"errors":[]}' > "$ERRORS_FILE" ;; *) echo "用法: catalog.sh <add|lookup|stats>" ;; esac
CATEOF

# ============================================================
# Create scripts/supervisor.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/supervisor.sh" << 'SUPEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$TOOLKIT_DIR"
STATE_FILE="$TOOLKIT_DIR/state.json"
SESSION_FILE="$TOOLKIT_DIR/session.json"
mkdir -p "$TOOLKIT_DIR/checkpoints"
get_task() { [[ -f "$STATE_FILE" ]] && python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('current_task_id',''))" 2>/dev/null || echo ""; }
cmd_start() {
  local tid="${1:-}"
  [[ -z "$tid" ]] && echo '{"success":false,"error":"task_id required"}' && return 1
  local now; now=$(date '+%Y-%m-%d %H:%M:%S')
  local sid="sess-$(date '+%Y%m%d-%H%M')"
  cat > "$SESSION_FILE" <<EOF
{"session_id":"$sid","task_id":"$tid","started_at":"$now","checkpoints":[],"review_attempts":0,"errors":[]}
EOF
  # Update state.json with current task and phase
  python3 - "$STATE_FILE" "$tid" "$now" <<'PY'
import json, sys
path, tid, now = sys.argv[1], sys.argv[2], sys.argv[3]
d = {"current_task_id": tid, "phase": "directive", "last_updated": now}
with open(path, 'w') as f: json.dump(d, f)
PY
  "$SCRIPT_DIR/checkpoint.sh" save "$tid" "supervisor started" 2>/dev/null || true
  cat <<INSTRUCTIONS

═══════════════════════════════════════════════════════════════
  SUPERVISOR 已启动 for task: $tid
═══════════════════════════════════════════════════════════════

【强制执行】AI 必须按以下顺序执行：

  1. 读取以下文件（理解上下文）:
     - memory/session-history.md     # 历史会话
     - catalog/errors.json           # 历史错误
     - instructions/directive.md     # 当前阶段指令

  2. 解析用户需求，创建任务:
     - 如果 tasks/tasks.json 中没有该任务
     - 调用: task.sh create "<任务名称>" <feature_id> HIGH '["src/**"]'

  3. 执行阶段门验证:
     - 调用: supervisor.sh gate plan
     - gate 通过后 state.json phase 变为 plan

  4. 进入 PLAN 阶段:
     - 读取 tasks/tasks.json 任务详情
     - 制定实现计划
     - 调用: supervisor.sh gate execute

  5. 进入 EXECUTE 阶段:
     - 实现代码，每次改文件前调用: validate.sh check-files
     - 调用: supervisor.sh gate review

  6. 进入 REVIEW 阶段:
     - 调用: supervisor.sh gate review
     - 失败 → catalog.sh add → 修复 → 重审
     - 通过后调用: supervisor.sh gate complete

  7. 进入 COMPLETE 阶段:
     - 调用: task.sh done
     - supervisor.sh stop

═══════════════════════════════════════════════════════════════

INSTRUCTIONS
}
cmd_gate() {
  local phase="${1:-}"
  local tid; tid=$(get_task)
  [[ -z "$tid" ]] && echo '{"success":false,"error":"no active task"}' && return 1
  echo "=== Gate: $phase ==="
  local passed=false
  case "$phase" in
    directive) [[ -n "$tid" ]] && passed=true ;;
    plan) grep -q "$tid" "$ROOT_DIR/tasks/tasks.json" 2>/dev/null && passed=true ;;
    execute) passed=true ;;
    review) "$SCRIPT_DIR/review.sh" check > /dev/null 2>&1 && passed=true ;;
    complete) passed=true ;;
    *) echo "{\"success\":false,\"error\":\"unknown gate\"}" && return ;;
  esac
  if $passed; then
    # Update state.json with new phase
    python3 - "$STATE_FILE" "$phase" <<'PY'
import json, sys, datetime
path, phase = sys.argv[1], sys.argv[2]
d = json.load(open(path)) if path else {}
d['phase'] = phase
d['last_updated'] = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
with open(path, 'w') as f: json.dump(d, f)
PY
    echo "{\"gate\":\"$phase\",\"passed\":true,\"task_id\":\"$tid\"}"
  else
    echo "{\"gate\":\"$phase\",\"passed\":false}"
  fi
}
cmd_stop() {
  local tid; tid=$(get_task)
  [[ -n "$tid" ]] && "$SCRIPT_DIR/checkpoint.sh" save "$tid" "supervisor stopped" 2>/dev/null || true
  [[ -f "$SESSION_FILE" ]] && rm "$SESSION_FILE"
  echo "Supervisor stopped"
}
cmd_status() {
  echo "=== Supervisor Status ==="
  [[ -f "$SESSION_FILE" ]] && cat "$SESSION_FILE" || echo "Supervisor not active"
  echo ""
  echo "=== Recent Checkpoints ==="
  "$SCRIPT_DIR/checkpoint.sh" list 2>/dev/null || echo "(无快照)"
}
CMD="${1:-}"
shift # remove CMD from args
case "$CMD" in start) cmd_start "$@" ;; gate) cmd_gate "$@" ;; stop) cmd_stop "$@" ;; status) cmd_status "$@" ;; *) echo "用法: supervisor.sh <start|gate|stop|status>" ;; esac
SUPEOF

# ============================================================
# Create scripts/self-improve.sh
# ============================================================
cat > "$TOOLKIT_DIR/scripts/self-improve.sh" << 'SELFEOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ERRORS_FILE="$TOOLKIT_DIR/catalog/errors.json"
analyze() {
  echo "=== 自我改进分析 ==="
  [[ ! -f "$ERRORS_FILE" ]] && echo "(错误目录为空)" && return
  python3 - "$ERRORS_FILE" <<'PY'
import json, sys
from collections import Counter
d=json.load(open(sys.argv[1])); errors=d.get('errors',[])
if not errors: print("✓ 错误目录为空"); sys.exit(0)
tc=Counter(e.get('type','') for e in errors)
print(f"总错误: {len(errors)}\n按类型:")
for t,c in tc.most_common(): print(f"  {t}: {c}")
recurring=[e for e in errors if e.get('occurrence_count',0)>1]
if recurring: print("\n高频错误:"); [print(f"  [{e.get('id')}] {e.get('pattern','')} ({e.get('occurrence_count')}次)") for e in recurring]
PY
}
CMD="${1:-}"
shift
case "$CMD" in analyze) analyze "$@" ;; *) echo "用法: self-improve.sh analyze" ;; esac
SELFEOF

# ============================================================
# Create config.json
# ============================================================
cat > "$TOOLKIT_DIR/config.json" << 'CFGEOF'
{
  "compile_cmd": "./gradlew assemble",
  "test_cmd": "./gradlew test",
  "forbidden_patterns": [],
  "placeholder_patterns": ["TODO","FIXME","待实现","后续实现","临时处理","UnsupportedOperationException","NotImplemented","return null;","return Collections.emptyList();"],
  "language": "java"
}
CFGEOF

# ============================================================
# Create catalog/errors.json
# ============================================================
cat > "$TOOLKIT_DIR/catalog/errors.json" << 'ERREOF'
{"catalog_version":"1.0","last_updated":null,"errors":[]}
ERREOF

# ============================================================
# Create memory files
# ============================================================
cat > "$TOOLKIT_DIR/memory/session-history.md" << 'HISTEOF'
# Session 历史

## 格式

```
## YYYY-MM-DD
- Session started: <task_id> (<task_name>)
- Session ended: <task_id>
- Result: done/blocked
- Learned: <lessons>
```
HISTEOF

cat > "$TOOLKIT_DIR/memory/project-context.md" << 'PCTXEOF'
# 项目上下文

## 项目概述

（在此填写项目描述）

## 技术栈

- （如：Java 17, Python 3.11, Node.js 18 等）

## 模块结构

```
src/           - 源代码
tests/         - 测试
docs/          - 文档
```

## 构建命令

- （如：./gradlew build, npm run build, cargo build 等）

## 禁止区域

- `<TOOLKIT>/**` - AI 工作流
- `build/**` - 构建输出
- `.gradle/**` - 缓存
- `.idea/**` - IDE 配置
PCTXEOF

cat > "$TOOLKIT_DIR/memory/boundary-rules.md" << 'BRLEOF'
# 边界规则

暂无特定规则。

当错误目录中有 boundary_violation 类型错误时，这里会自动更新。
BRLEOF

# ============================================================
# Create roles files
# ============================================================
cat > "$TOOLKIT_DIR/roles/supervisor.md" << 'SUPREOF'
# Supervisor 角色

## 职责

Supervisor 负责审查和监督，不做具体实现。

### 核心职责

1. **边界执行**: 确保所有文件修改都在 editable_scope 内
2. **审查门**: 在每个阶段结束时运行审查
3. **快照管理**: 定期保存检查点
4. **错误记录**: 将错误记录到 catalog

### Supervisor 介入时机

- **文件编辑前**: validate.sh check-files
- **每 5 个文件变更后**: checkpoint.sh save
- **审查失败时**: catalog.sh add
- **完成前**: supervisor.sh gate review

## Supervisor 不会

- 直接编辑业务代码
- 跳过审查流程
- 修改禁止区域的文件
SUPREOF

cat > "$TOOLKIT_DIR/roles/executor.md" << 'EXREOF'
# Executor 角色

## 职责

Executor 负责具体实现代码，遵循 Supervisor 设定的边界。

### 核心职责

1. **代码实现**: 根据计划实现功能
2. **边界遵守**: 确保所有修改在 editable_scope 内
3. **进度更新**: 每次文件变更后更新状态
4. **记录操作**: 记录关键操作到审计日志

### Executor 不会

- 编辑 `<TOOLKIT>/` 目录
- 编辑禁止区域的文件
- 跳过 validate.sh 检查
- 在 review.sh check 未通过时声称完成
EXREOF

# ============================================================
# Create instructions files
# ============================================================
cat > "$TOOLKIT_DIR/instructions/directive.md" << 'DIREOF'
# 阶段 1: DIRECTIVE

## 入口条件

用户给出了自然语言命令。

## 执行步骤

1. 读取 memory/session-history.md
2. 读取 catalog/errors.json
3. 读取 instructions/directive.md
4. 读取 tasks/tasks.json
5. 调用 scripts/supervisor.sh start <task_id>

## 边界规则

- 永远不在请求模糊时继续
- 永远遵守 forbidden_scope
DIREOF

cat > "$TOOLKIT_DIR/instructions/plan.md" << 'PLANEOF'
# 阶段 2: PLAN

## 入口条件

Directive 阶段通过。

## 执行步骤

1. 读取 tasks/tasks.json
2. 制定实现计划
3. validate.sh check-files 验证边界
4. checkpoint.sh save

## 出口条件

- 实现计划已制定
- 所有计划文件都在边界内
PLANEOF

cat > "$TOOLKIT_DIR/instructions/execute.md" << 'EXECEOF'
# 阶段 3: EXECUTE

## 入口条件

Plan 阶段通过。

## 执行步骤

1. 按计划实现代码
2. 每次改文件前 validate.sh check-files
3. 定期 checkpoint.sh save
4. 定期 log.sh record
5. ./gradlew assemble 验证编译

## 出口条件

- 核心功能已实现
- 编译通过
EXECEOF

cat > "$TOOLKIT_DIR/instructions/review.md" << 'REVEOF'
# 阶段 4: REVIEW

## 入口条件

Execute 阶段完成。

## 执行步骤

1. 自我预审（无 TODO/FIXME/return null）
2. review.sh check
3. 失败 → catalog.sh add → 修复 → 重审
4. 直到通过

## 出口条件

- review.sh check 通过
- 编译通过
REVEOF

cat > "$TOOLKIT_DIR/instructions/complete.md" << 'CMPEOF'
# 阶段 5: COMPLETE

## 入口条件

Review 阶段通过。

## 执行步骤

1. checkpoint.sh save (最终快照)
2. task.sh done <task_id>
3. 更新 memory/session-history.md
4. log.sh record "complete"
5. supervisor.sh stop

## 出口条件

- 任务状态更新为 done
- Snapshot 已保存
CMPEOF

# ============================================================
# Create CLAUDE.md and AGENTS.md
# ============================================================
cat > "$TOOLKIT_DIR/CLAUDE.md" << 'CLAUDEEOF'
# CLAUDE.md - AI 工作流工具箱

**你是一个自主的 AI 编码 Agent。每次人类给你一个开发任务，你必须自己驱动整个工作流。**

## 强制工作流

```
用户下达命令
      │
      ▼
1. DIRECTIVE: 读取 memory/session-history.md, catalog/errors.json, instructions/directive.md
2. PLAN: 制定计划, validate.sh check-files, checkpoint.sh save
3. EXECUTE: 实现代码, 每次改文件前 validate.sh check-files
4. REVIEW: review.sh check
5. COMPLETE: checkpoint.sh save, task.sh done, supervisor.sh stop
```

## 硬性约束

1. 每次改文件前必须 validate.sh check-files
2. 完成前必须 review.sh check 通过
3. 编译必须通过
4. 不允许 TODO/FIXME/NotImplemented
5. 不允许 return null; 作为最终返回值

## 禁止区域

- `<TOOLKIT>/**` - 工作流自身
- `build/**` - 构建输出
- `.gradle/**` - 缓存
- `.idea/**` - IDE 配置
CLAUDEEOF

cat > "$TOOLKIT_DIR/AGENTS.md" << 'AGENTEOF'
# AGENTS.md - AI Agent 行为规范

## 用户只需要做 2 件事

```
1. 运行一次: ./init.sh
2. 下达命令: "实现 FTP 适配器"
```

**AI 全自动完成所有工作。**

---

## 角色定义

- **Executor**: 执行具体代码实现
- **Supervisor**: 边界验证、审查门、快照管理、错误记录

## 启动流程（必须执行）

当用户下达命令时，**必须**按以下顺序执行：

```
1. 创建任务: ai-toolkit/scripts/task.sh create "<任务名称>" F-001 HIGH '["src/**"]'
2. 获取返回的 task_id（如 T-001）
3. 调用: ai-toolkit/scripts/supervisor.sh start <task_id>
4. 阅读输出的【强制执行】指令
5. 按指令顺序执行
```

**注意**: task_id 由 task.sh create 自动生成，不要硬编码。

## 五阶段流转

```
DIRECTIVE → PLAN → EXECUTE → REVIEW → COMPLETE
```

每个阶段通过调用 `supervisor.sh gate <phase>` 进入下一阶段。

## 禁止事项

- 禁止直接实现代码（必须先启动 supervisor）
- 禁止跳过 validate.sh check-files
- 禁止跳过 review.sh check
- 禁止修改 ai-toolkit/**, build/**, .gradle/**, .idea/**
AGENTEOF

# ============================================================
# Create 功能说明书.md
# ============================================================
cat > "$TOOLKIT_DIR/功能说明书.md" << 'FUNCEOF'
# AI 工作流工具箱 - 功能说明书

## 用户只需要做 2 件事

```bash
1. 运行一次: ./init.sh
2. 下达命令: "实现 FTP 适配器"
```

**AI 全自动完成所有工作。**

---

## 工作原理

### 自动化流程

```
用户下达命令
    ↓
AI 自动创建任务 → 制定计划 → 实现代码 → 运行审查 → 完成
    ↓
AI 汇报结果（"已完成 FTP 适配器，变更了 A.java、B.java，审查通过"）
```

### AI 做什么

| 阶段 | AI 自动完成 |
|------|-------------|
| DIRECTIVE | 解析需求，创建/找到任务 |
| PLAN | 制定实现计划 |
| EXECUTE | 实现代码，每次改文件前验证边界 |
| REVIEW | 运行审查（边界+占位符+编译），失败则修复 |
| COMPLETE | 保存快照，更新记忆，汇报结果 |

### 人类不需要做什么

- ❌ 手动创建任务
- ❌ 手动开始任务
- ❌ 手动运行审查
- ❌ 手动更新状态

---

## 文件结构

```
ai-toolkit/
├── scripts/          # 核心脚本（9个）
├── catalog/          # 错误目录
├── memory/           # 跨 session 记忆
├── roles/            # Executor/Supervisor 角色定义
├── instructions/      # 各阶段执行指令
├── config.json       # 配置（编译命令、禁止模式等）
├── state.json        # 当前状态
└── CLAUDE.md         # AI 工作流规范
```

## 核心脚本

| 脚本 | 用途 |
|------|------|
| task.sh | 任务管理 |
| supervisor.sh | 监督模式控制 |
| checkpoint.sh | 快照保存/恢复 |
| validate.sh | 边界验证 |
| review.sh | 代码审查 |
| catalog.sh | 错误目录 |
| log.sh | 操作日志 |
| state.sh | 状态读写 |
| self-improve.sh | 自我改进 |

---

## 断线续接

Session 中断后，AI 自动恢复：

```
1. 读取 state.json
2. 如果有未完成任务 → checkpoint.sh restore → 继续
3. 如果没有/已完成 → 等待新命令
```

---

## 约束

### AI 必须遵守

1. 每次改文件前 validate.sh check-files（确认不在禁止区域）
2. 完成后 review.sh check（边界+占位符+编译）
3. 编译必须通过
4. 禁止区域绝对不能修改

### 禁止的模式

- `TODO` / `FIXME`
- `NotImplemented` / `UnsupportedOperationException`
- `return null;` 作为最终返回值

---

## 错误学习

审查失败时，错误自动记录到 catalog/errors.json。

新 session 开始时，AI 会读取错误目录，防止重复犯错。

AI 可以运行 self-improve.sh analyze 分析错误模式并生成改进建议。
FUNCEOF

# Make all scripts executable
chmod +x "$TOOLKIT_DIR/scripts/"*.sh

# Create helper scripts in TOOLKIT_DIR (for easy access)
cat > "$TOOLKIT_DIR/ai-init.sh" << 'INITEOF'
#!/usr/bin/env bash
# ai-init - 在当前项目初始化 AI toolkit
# 查找全局 bootstrap.sh
BOOTSTRAP=""
for dir in "$HOME/.ai-toolkit" "$HOME/.local/ai-toolkit" "$(dirname "$(dirname "$0")")/ai-toolkit"; do
  [[ -f "$dir/bootstrap.sh" ]] && BOOTSTRAP="$dir/bootstrap.sh" && break
done
if [[ -z "$BOOTSTRAP" ]]; then
  echo "错误: 找不到 bootstrap.sh"
  echo "请从 https://gist/... 下载 bootstrap.sh"
  exit 1
fi
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)" bash "$BOOTSTRAP" "$TOOLKIT_DIR"
INITEOF
chmod +x "$TOOLKIT_DIR/ai-init.sh"

cat > "$TOOLKIT_DIR/uninstall.sh" << 'CLEANEOF'
#!/usr/bin/env bash
# ai-clean - 卸载 AI toolkit
TOOLKIT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "⚠️  即将删除: $TOOLKIT_DIR"
read -p "确认删除? (y/N) " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] && rm -rf "$TOOLKIT_DIR" && echo "✓ 已删除" || echo "已取消"
CLEANEOF
chmod +x "$TOOLKIT_DIR/uninstall.sh"

echo ""
echo "✓ AI 工作流工具箱已初始化: $TOOLKIT_DIR/"
echo ""
echo "完成！你只需要："
echo "  1. 下达自然语言命令，如：\"实现 FTP 适配器\""
echo "  2. AI 全自动完成所有工作"
echo ""
echo "快捷命令:"
echo "  $TOOLKIT_DIR/ai-init.sh    # 重新初始化"
echo "  $TOOLKIT_DIR/uninstall.sh  # 卸载"
echo ""
echo "查看文档:"
echo "  - $TOOLKIT_DIR/功能说明书.md 了解整体设计"
echo "  - $TOOLKIT_DIR/CLAUDE.md 了解工作流规范"
