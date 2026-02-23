#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-.}"
SELF_EVOLVE_REPORT="${SELF_EVOLVE_REPORT:-./self-evolve.md}"

cd "$ROOT_DIR"

if command -v rg >/dev/null 2>&1; then
  sh_files="$(rg --files -g '*.sh' || true)"
else
  sh_files="$(find . -type f -name '*.sh' | sed 's#^./##' || true)"
fi

if [[ -z "$sh_files" ]]; then
  echo "no-shell-files"
  exit 0
fi

duplicates="$(printf '%s\n' "$sh_files" | xargs cat | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//' | rg -v '^$|^#' | sort | uniq -d | wc -l | tr -d ' ')"
conditionals="$(printf '%s\n' "$sh_files" | xargs rg -n '\b(if|elif|case)\b' | wc -l | tr -d ' ')"
wrappers="$(printf '%s\n' "$sh_files" | while read -r f; do
  non_comment="$(rg -n -v '^\s*($|#)' "$f" | wc -l | tr -d ' ')"
  invoke_count="$(rg -n '^\s*(bash|sh)\s+' "$f" | wc -l | tr -d ' ')"
  if [[ "$non_comment" -le 6 && "$invoke_count" -ge 1 ]]; then
    echo "$f"
  fi
done | wc -l | tr -d ' ')"

circular=0
edges="$(printf '%s\n' "$sh_files" | while read -r f; do
  while read -r target; do
    printf '%s %s\n' "$f" "$target"
  done < <(rg -o 'bash ./[a-zA-Z0-9_./-]+\.sh' "$f" | sed -E 's#bash ./##')
done)"
if [[ -n "$edges" ]]; then
  while read -r a b; do
    if printf '%s\n' "$edges" | rg -q "^${b} ${a}$"; then
      circular=1
      break
    fi
  done <<< "$edges"
fi

testability=5
if [[ -f tests/test_growth.sh ]]; then
  testability=9
fi

simplicity=$((10 - (duplicates / 10) - (conditionals / 20)))
cohesion=$((9 - wrappers))
coupling=$((9 - (circular * 3) - (wrappers / 2)))
extensibility=$((8 - (duplicates / 20) - circular))

for metric in simplicity cohesion coupling extensibility; do
  value="${!metric}"
  if [[ "$value" -lt 1 ]]; then
    printf -v "$metric" '%s' "1"
  elif [[ "$value" -gt 10 ]]; then
    printf -v "$metric" '%s' "10"
  fi
done

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "## $ts"
  echo
  echo "### Retrospective"
  echo "- 아쉬운 점 1: 성장 루프가 아직 단일 스크립트 중심이라 실제 기능 개발 폭이 좁다."
  echo "- 아쉬운 점 2: 실패 분류가 단순해 원인별 복구 전략이 부족하다."
  echo "- 아쉬운 점 3: 배포 단계 자동화가 아직 비어 있다."
  echo
  echo "### Technical Debt Scan"
  echo "- 반복 코드 탐지: duplicate-lines=$duplicates"
  echo "- 과도한 조건문 탐지: conditionals=$conditionals"
  echo "- 순환참조 가능성 탐지: circular-ref=$circular"
  echo "- 불필요한 레이어 탐지: thin-wrappers=$wrappers"
  echo
  echo "### Structure Scores (10 max)"
  echo "- 단순성: $simplicity"
  echo "- 응집도: $cohesion"
  echo "- 결합도: $coupling"
  echo "- 테스트 가능성: $testability"
  echo "- 확장성: $extensibility"
  echo
  echo "### Improvements (<=7 only)"
  [[ "$simplicity" -le 7 ]] && echo "- 단순성 개선: 중복 텍스트/로깅 포맷 공통 함수화"
  [[ "$cohesion" -le 7 ]] && echo "- 응집도 개선: autopilot와 성장 실행 정책 분리"
  [[ "$coupling" -le 7 ]] && echo "- 결합도 개선: 스크립트 호출 경로를 환경변수로만 주입"
  [[ "$testability" -le 7 ]] && echo "- 테스트 개선: 실패 유형별 회귀 테스트 추가"
  [[ "$extensibility" -le 7 ]] && echo "- 확장성 개선: 단계별 훅(pre/post) 분리"
  echo
  echo "### Evolution Questions"
  echo "- 이 작업을 완전히 자동화할 수 있는가?: 부분 가능(배포 입력은 별도 필요)"
  echo "- 반복 패턴이 있는가?: growth->test->log 패턴 반복"
  echo "- 더 적은 코드로 동일 기능 가능한가?: 가능(메트릭 계산 공통화)"
  echo "- 시스템이 나 없이 유지 가능한가?: 제한적 가능(현재는 로컬 실행 전제)"
  echo
} >> "$SELF_EVOLVE_REPORT"

low_scores=0
for value in "$simplicity" "$cohesion" "$coupling" "$testability" "$extensibility"; do
  if [[ "$value" -le 7 ]]; then
    low_scores=$((low_scores + 1))
  fi
done

echo "scores_low=${low_scores} duplicate=${duplicates} conditionals=${conditionals} circular=${circular} wrappers=${wrappers}"
