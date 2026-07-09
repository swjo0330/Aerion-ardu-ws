# Fable5 하네스 템플릿 패키지

장기 멀티세션 프로젝트를 Claude Code로 운영하기 위한 **파일 하네스 코어 템플릿군**. 실제 장기 프로젝트 운영에서 실증된 규칙·패턴만 담았다 (이론적 모범사례 발명 없음).

**설계 원리 2줄**:
- 자동 로드되지 않는 절차 파일은 사문화된다 → 항시 규칙은 CLAUDE.md 1곳에, 나머지는 CLAUDE.md가 발동·링크하는 위성 파일로
- 한 사실의 전문은 정본 1곳에만, 나머지는 1줄 포인터 — 수치는 registry, 설계는 specs, 구현 시점 기록은 implementation-notes

## 파일 지도 (참조 체인 = 진입 순서)

```
CLAUDE_TEMPLATE.md            ← 자동 로드 정점. §0 세션표가 "내가 어느 세션인지 → 무엇을 먼저 읽는지" 라우팅
  ├─ FABLE5.md                ← 착수 사고 프로토콜 (CLAUDE §1.5 ⚡발동 — 대형 작업 시 사전점검 블록 출력 의무)
  ├─ implementation-notes_TEMPLATE.md ← 구현 원본 기록 (읽기 2순위 / 쓰기는 매 구현). 닫힌 항목 → 정본 승격
  ├─ EXPERIMENTS_TEMPLATE.md  ← 검증 현황판 (읽기 3순위). 수치는 여기 아님 → registry ★확정 행
  ├─ AGENTS_TEMPLATE.md       ← 아키텍처 + 날짜별 설계 확정 이력 (필요 시 Read)
  ├─ Docs/
  │   ├─ RULES_TEMPLATE.md    ← 상세 규칙 레퍼런스 (CLAUDE에서 내린 예시·체크리스트·명령어)
  │   ├─ wiki-structure.md    ← 문서 루트 구조 가이드 (specs/setups/TODO/experiments/… + 골격 생성 원라이너)
  │   ├─ registry_TEMPLATE.md ← 수치 정본 레지스트리 골격 (★확정/○후보/△이슈 등급제 표) → {{문서 루트}}/experiments/로 이식
  │   └─ experiments-RULES_TEMPLATE.md ← 실험 공통 규칙 골격 → {{문서 루트}}/experiments/RULES.md로 이식
  ├─ memory/
  │   ├─ memory-protocol.md   ← AKC 자율 기억 프로토콜 (6트리거·4저장소 라우팅·투명성)
  │   ├─ MEMORY_TEMPLATE.md   ← 세션 간 메모리 인덱스 골격 (<17KB)
  │   └─ session-restart-protocol.md ← 재시작 읽기 순서 + 종료 배치 기록 체크리스트
  ├─ prompts/                 ← 재사용 프롬프트 8종 (하니스 경화·적대검증·시각 QA·전수감사 등 — 인덱스: prompts/README.md)
  └─ style/                   ← 산출물 스타일 규칙 3종 (writing / deck / diagram)
```

`prompts/`·`style/`의 `{{placeholder}}`는 **사용 시점마다 복사-치환하는 영구 슬롯**이다 — 착수 치환 대상이 아니다 (아래 3단계 참고).

핵심 흐름 3개:
1. **세션 시작** — CLAUDE.md §0 표에서 자기 유형 확인 → session-restart-protocol.md 순서로 읽기
2. **구현 중** — FABLE5 사전점검 블록 → Blind Spot Pass → notes에 5태그 1줄 기록 → 가역성 판단. 새 스크립트/러너/하니스 신설 직후에는 `prompts/harden-new-harness.md`로 결함 선제 제거
3. **마일스톤/종료** — AKC 배치 기록(4저장소 라우팅) + EXPERIMENTS 진행판·간트 갱신 + notes 아카이브 승격

## 새 프로젝트 착수 절차

1. **복사**: `cp -r harness_template/ {{새 프로젝트 루트}}/` (또는 필요한 파일만)
2. **문서 골격 생성**: `mkdir -p {{문서 루트}}/{specs,setups,TODO,experiments,ppt,figures}` (구조·역할: `Docs/wiki-structure.md`)
   - **실험/수치 트랙이 있으면**: `Docs/registry_TEMPLATE.md` → `{{문서 루트}}/experiments/{{registry}}.md`, `Docs/experiments-RULES_TEMPLATE.md` → `{{문서 루트}}/experiments/RULES.md` 로 이식·치환 — CLAUDE §0 세션B·EXPERIMENTS 헤더 ①②·Docs/RULES '등록 규칙'·session-restart-protocol '기억 검증 규율'이 전부 이 registry를 가리킨다
   - **없으면**: registry 참조 절을 일괄 삭제 (CLAUDE §0 세션B 수치 열 · EXPERIMENTS 헤더 ①·§2.5 · Docs/RULES '등록 규칙' · session-restart-protocol 수치 행 · wiki-structure `experiments/` 트리) + `experiments/` 폴더 생략
3. **placeholder 치환**: 전 파일에서 `{{PROJECT}}`, `{{문서 루트}}`, `{{registry}}` 등 `{{...}}` 슬롯을 채우고, `<!-- 예: ... -->` 주석은 참고 후 삭제
   - 검색: `grep -rn '{{' . --exclude-dir=prompts --exclude-dir=style` — 남은 슬롯이 0이 될 때까지
   - ※ `prompts/`·`style/`의 `{{placeholder}}`는 사용 시점마다 복사-치환하는 **영구 슬롯** — 착수 시 치환·삭제 금지
   - §0 세션 체계: 단일 세션 운용이면 표 삭제, 다중이면 3행 패턴 채움
   - 해당 없는 절은 삭제 (예: EXPERIMENTS §4.3 실행 세션 시작 게이트 · §4.4 영속성 · §1 러너 계보, memory-protocol ③ 구조화 스토어 행)
4. **개명**: `_TEMPLATE` 접미 제거
   - `CLAUDE_TEMPLATE.md → CLAUDE.md`, `AGENTS_TEMPLATE.md → AGENTS.md`, `EXPERIMENTS_TEMPLATE.md → EXPERIMENTS.md`, `implementation-notes_TEMPLATE.md → implementation-notes.md`, `Docs/RULES_TEMPLATE.md → Docs/RULES.md`
   - **memory 3종 — 기본안: 리포에 그대로 두고 CLAUDE.md 상대 링크로 참조** (템플릿의 링크들이 리포 내 `memory/` 경로를 전제한다). 단, `MEMORY_TEMPLATE.md`의 **내용**은 파일 메모리 위치 `~/.claude/projects/{{프로젝트 슬러그}}/memory/MEMORY.md` 에 인덱스로 개설한다
     - `{{프로젝트 슬러그}}` = 프로젝트 **절대 경로의 `/`를 `-`로 치환**한 것 (예: `/Users/me/swdev/myapp` → `-Users-me-swdev-myapp`). 확인: `ls ~/.claude/projects/` 후 매칭 폴더 확인 (첫 세션 후 자동 생성됨)
     - (선택지) `memory-protocol.md`·`session-restart-protocol.md`를 파일 메모리 폴더로 **이동**할 수도 있다 — 이 경우 **CLAUDE.md §0·§5(AKC)·참조 문서의 `memory/...` 상대 링크와 아래 5단계 예문 경로를 이동 후 절대 경로로 반드시 갱신**할 것 (미갱신 시 첫 세션부터 깨진 경로를 읽게 된다)
   - `FABLE5.md`는 그대로 (개명 불요)
5. **첫 세션 지시 예문**:
   > "CLAUDE.md를 읽고 §0에서 이 세션 유형을 확인한 뒤, memory/session-restart-protocol.md 순서로 진입하라. 이번 작업: {{첫 작업}}. 대형 작업이므로 FABLE5.md 사전점검 블록부터 출력하라."

## 규율 (템플릿 자체의)

- 템플릿은 프로젝트 무관 — 도메인 어휘는 `<!-- 예: -->` 주석에만
- 각 파일은 자동 로드/즉시 참조를 견디는 길이 유지 — 길어지는 내용은 Docs/RULES 또는 wiki로 내린다

---

v0.1 — 착수 시뮬레이션 검증 11건 반영
