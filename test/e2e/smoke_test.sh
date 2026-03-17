#!/usr/bin/env bash
#
# Hive E2E Smoke Test
#
# Exercises the full Hive workflow against a running server:
#   comb registration → quest creation → planning → execution → evaluation
#
# Usage:
#   ./test/e2e/smoke_test.sh              # interactive
#   ./test/e2e/smoke_test.sh --auto       # auto-confirm plan
#   ./test/e2e/smoke_test.sh --no-cleanup # keep artifacts
#   HIVE_SERVER=http://host:4000 ./test/e2e/smoke_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_COMB_SRC="$SCRIPT_DIR/smoke_comb"
AUTO=false
CLEANUP=true
TIMEOUT=300  # 5 minutes
SERVER_URL="${HIVE_SERVER:-http://localhost:4000}"
export HIVE_SERVER="$SERVER_URL"

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --auto) AUTO=true ;;
    --no-cleanup) CLEANUP=false ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

step=0
total_steps=6
start_time=$(date +%s)

print_step() {
  step=$((step + 1))
  echo ""
  echo -e "${BOLD}[$step/$total_steps] $1${NC}"
}

print_ok() {
  echo -e "  ${GREEN}→${NC} $1"
}

print_warn() {
  echo -e "  ${YELLOW}→${NC} $1"
}

print_err() {
  echo -e "  ${RED}→${NC} $1"
}

cleanup() {
  if [ "$CLEANUP" = true ] && [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

echo ""
echo -e "${BOLD}═══ Hive E2E Smoke Test ═══${NC}"

# ─────────────────────────────────────────────────
# Step 1: Setup
# ─────────────────────────────────────────────────
print_step "Setting up test comb..."

TEMP_DIR=$(mktemp -d /tmp/hive_smoke_XXXXXX)
cp -r "$SMOKE_COMB_SRC"/* "$TEMP_DIR/"
print_ok "Created $TEMP_DIR"

cd "$TEMP_DIR"
git init -q
git add -A
git commit -q -m "Initial commit: calculator with missing multiply"
print_ok "Git repo initialized with $(git log --oneline | wc -l | tr -d ' ') commit(s)"

# Check hive binary
if ! command -v hive &>/dev/null; then
  print_err "hive binary not found on PATH"
  exit 1
fi
print_ok "hive binary found: $(which hive)"

# Check server is reachable
if ! curl -sf "$SERVER_URL/api/v1/health" >/dev/null 2>&1; then
  print_err "Server not reachable at $SERVER_URL"
  print_err "Start the server with: hive server"
  exit 1
fi

SERVER_VERSION=$(curl -sf "$SERVER_URL/api/v1/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('version','?'))" 2>/dev/null || echo "?")
print_ok "Server reachable at $SERVER_URL (v$SERVER_VERSION)"

# ─────────────────────────────────────────────────
# Step 2: Register comb
# ─────────────────────────────────────────────────
print_step "Registering comb..."

COMB_OUTPUT=$(hive comb add "$TEMP_DIR" --name smoke-test 2>&1) || true
echo "  $COMB_OUTPUT"

# Extract comb ID from output (format: "registered (comb-xxxxx)")
COMB_ID=$(echo "$COMB_OUTPUT" | grep -oE 'comb-[a-f0-9]+' | head -1 || true)
if [ -z "$COMB_ID" ]; then
  # Try alternate format
  COMB_ID=$(echo "$COMB_OUTPUT" | grep -oE '[a-f0-9]{8}' | head -1 || true)
fi

if [ -n "$COMB_ID" ]; then
  print_ok "Comb registered: $COMB_ID (smoke-test)"
else
  print_warn "Could not extract comb ID from output"
  COMB_ID="smoke-test"
fi

# ─────────────────────────────────────────────────
# Step 3: Create quest
# ─────────────────────────────────────────────────
print_step "Creating quest..."

QUEST_OUTPUT=$(hive quest new "Implement the multiply function in calculator.py and make test_multiply pass" --comb "$COMB_ID" 2>&1) || true
echo "  $QUEST_OUTPUT"

QUEST_ID=$(echo "$QUEST_OUTPUT" | grep -oE 'msn-[a-f0-9]+' | head -1 || true)
if [ -z "$QUEST_ID" ]; then
  print_err "Could not extract quest ID"
  exit 1
fi
print_ok "Quest created: $QUEST_ID"

# ─────────────────────────────────────────────────
# Step 4: Planning
# ─────────────────────────────────────────────────
print_step "Generating plan..."

PLAN_OUTPUT=$(hive quest plan "$QUEST_ID" 2>&1) || true
echo "$PLAN_OUTPUT" | sed 's/^/  /'

if echo "$PLAN_OUTPUT" | grep -qi "failed\|error"; then
  print_warn "Plan generation had issues (continuing anyway)"
else
  print_ok "Plan generated"
fi

# ─────────────────────────────────────────────────
# Step 5: Execution
# ─────────────────────────────────────────────────
print_step "Running quest..."

START_OUTPUT=$(hive quest start "$QUEST_ID" 2>&1) || true
echo "  $START_OUTPUT"

if echo "$START_OUTPUT" | grep -qi "failed\|error"; then
  print_err "Failed to start quest"
  print_warn "Continuing to evaluation..."
else
  print_ok "Quest started"

  # Poll for completion
  elapsed=0
  last_phase=""
  while [ $elapsed -lt $TIMEOUT ]; do
    STATUS_OUTPUT=$(hive quest status "$QUEST_ID" 2>&1) || true
    current_phase=$(echo "$STATUS_OUTPUT" | grep -i "current phase" | head -1 | sed 's/.*: //' || true)

    if [ -n "$current_phase" ] && [ "$current_phase" != "$last_phase" ]; then
      print_ok "Phase: $current_phase"
      last_phase="$current_phase"
    fi

    if echo "$STATUS_OUTPUT" | grep -qi "completed"; then
      print_ok "Quest completed!"
      break
    fi

    if echo "$STATUS_OUTPUT" | grep -qi "failed"; then
      print_warn "Quest failed or stalled"
      break
    fi

    sleep 10
    elapsed=$((elapsed + 10))

    if [ $((elapsed % 30)) -eq 0 ]; then
      print_warn "  Waiting... (${elapsed}s / ${TIMEOUT}s)"
    fi
  done

  if [ $elapsed -ge $TIMEOUT ]; then
    print_warn "Timed out after ${TIMEOUT}s"
  fi
fi

# ─────────────────────────────────────────────────
# Step 6: Evaluation
# ─────────────────────────────────────────────────
print_step "Evaluating results..."

# Check if multiply was implemented
cd "$TEMP_DIR"

if python3 -c "from calculator import multiply; assert multiply(3,4) == 12" 2>/dev/null; then
  print_ok "multiply() function exists and works"
else
  print_err "multiply() not implemented or broken"
fi

# Run tests
echo ""
echo "  Test results:"
if python3 -m pytest test_calculator.py -v 2>/dev/null; then
  TEST_RESULT="PASS"
elif python3 test_calculator.py 2>&1; then
  TEST_RESULT="PASS"
else
  TEST_RESULT="FAIL"
fi

echo ""

# Show changes
echo "  Changes made:"
git diff --stat HEAD 2>/dev/null | sed 's/^/    /' || echo "    (no changes detected)"

echo ""
echo "  Git log:"
git log --oneline 2>/dev/null | sed 's/^/    /'

echo ""
echo "  Branches:"
git branch -a 2>/dev/null | sed 's/^/    /'

# Final quest status
echo ""
echo "  Final quest status:"
hive quest show "$QUEST_ID" 2>&1 | sed 's/^/    /' || true

end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

echo ""
echo -e "  Total time: ${minutes}m ${seconds}s"

echo ""
if [ "${TEST_RESULT:-FAIL}" = "PASS" ]; then
  echo -e "${BOLD}${GREEN}═══ RESULT: PASS ═══${NC}"
else
  echo -e "${BOLD}${RED}═══ RESULT: FAIL ═══${NC}"
fi
echo ""
