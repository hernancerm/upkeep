#!/usr/bin/env bash
# Runs a skill on a fixture repo with planted problems, then checks the report against
# evals/<skill>/expected.txt. Each run calls an agent CLI, so it costs tokens.
#
# Usage: evals/run.sh <skill> [claude|agy] [model]
#
# The fixture is two commits: base/ on main, then change/ on a feature branch. The skill
# reviews main...feature.

set -euo pipefail

skill=$1
agent=${2:-claude}
model=${3:-}
root=$(cd "$(dirname "$0")/.." && pwd)
case_dir=$root/evals/$skill
work=$(mktemp -d)

git -C "$work" init -q -b main
cp -R "$case_dir/base/." "$work/"
git -C "$work" add -A
git -C "$work" commit -q -m "feat: base"
git -C "$work" switch -q -c feature
cp -R "$case_dir/change/." "$work/"
git -C "$work" add -A
git -C "$work" commit -q -m "feat: change"

# Project skills, so the run uses this repo's copy and not an installed one. Kept out of git so
# the skill does not review itself.
case $agent in
  claude)
    mkdir -p "$work/.claude"
    cp -R "$root/skills" "$work/.claude/skills"
    echo ".claude/" >> "$work/.git/info/exclude"
    cmd=(
      claude -p "/$skill main..."
      --setting-sources project
      --allowedTools "Bash(git *)" "Bash(cat *)" "Bash(ls *)" "Bash(grep *)" Read Grep Glob
    )
    if [[ -n $model ]]; then
      cmd+=(--model "$model")
    fi
    ;;
  agy)
    mkdir -p "$work/.agents"
    cp -R "$root/skills" "$work/.agents/skills"
    echo ".agents/" >> "$work/.git/info/exclude"
    cmd=(
      agy
      --settings '{"permissions":{"allow":["command(git)","command(cat)","command(ls)","command(grep)"]}}'
    )
    if [[ -n $model ]]; then
      cmd+=(--model "$model")
    fi
    cmd+=("-p=/$skill main...")
    ;;
  *)
    echo "Unknown agent: $agent (expected claude or agy)" >&2
    exit 2
    ;;
esac

report=$work/report.md
(
  cd "$work"
  "${cmd[@]}" > "$report"
)
cat "$report"
echo
echo "--- Checks ($work)"

failed=0
while IFS= read -r line; do
  if [[ -z $line || $line == \#* ]]; then
    continue
  fi
  if [[ $line == !* ]]; then
    pattern=${line#!}
    if grep -Eq -- "$pattern" "$report"; then
      echo "FAIL  unexpected: $pattern"
      failed=1
    else
      echo "ok    absent: $pattern"
    fi
  else
    if grep -Eq -- "$line" "$report"; then
      echo "ok    found: $line"
    else
      echo "FAIL  missing: $line"
      failed=1
    fi
  fi
done < "$case_dir/expected.txt"

exit $failed
