# Docs/wiki 디렉토리 구조 가이드

> 모든 서사형 문서는 단일 루트 아래, `YYYY-MM-DD-<키워드>.md` 명명. 날짜가 붙어 있어야 "언제 확정된 사실인가"를 나중에 판별할 수 있다.

## 구조와 역할

골격 생성 원라이너 (착수 시 1회):

```bash
mkdir -p {{문서 루트}}/{specs,setups,TODO,experiments,ppt,figures}
```

```
{{문서 루트}}/                       ← 예: Docs/wiki/Methodology/{{project}}/
├── *.md                            ← (루트) 날짜별 작업 기록·실험 결과·리뷰
│                                      예: YYYY-MM-DD-e2e-pipeline-deep-review.md
├── specs/                          ← 설계 스펙·구현 계획 (설계의 정본이 사는 곳)
│   └── {{하위 주제 폴더}}/          ← 주제가 커지면 폴더로 분리 <!-- 예: avoidance/, episodic/ -->
├── setups/                         ← 환경 셋업·빌드·테스트 명령어 (환경 문제 시 필독)
├── TODO/                           ← 작업 계획. 네이밍: YYYY-MM-DD-TODO-<키워드>.md
│                                      세션 간 handoff 문서도 여기 (YYYY-MM-DD-TODO-<대상>-handoff.md)
├── experiments/                    ← 실험 인프라 (실험/수치 트랙 없으면 폴더째 생략)
│   ├── RULES.md                    ← 실험 공통 규칙 (등록=사용자 검토 등) — 골격: `Docs/experiments-RULES_TEMPLATE.md`
│   ├── {{registry}}.md             ← 수치 단일 정본 — ★확정/○후보/△이슈 등급제 — 골격: `Docs/registry_TEMPLATE.md`
│   └── {{트랙 폴더}}/               ← 트랙별 runbook·판정 기준 <!-- 예: Phase-B/YYYY-MM-DD-runbook.md -->
├── ppt/                            ← 발표 자료
└── figures/                        ← 실험·문서 그림 정본
```

## 규칙

- **정본 1곳**: 같은 사실을 두 문서에 전문으로 쓰지 않는다 — 정본 1곳 + 나머지는 링크
- **specs = 설계 정본**: 구현이 specs와 달라지면 `implementation-notes.md`에 `[이탈]` 기록 → 확정 시 specs 갱신
- **수치는 registry에만**: 루트 기록·발표 자료의 수치는 registry ★확정 행 인용
- **상기 프로토콜**: 기억 유실·환경 문제 발생 시 setups/와 최근 날짜별 기록을 먼저 읽는다
- 파생 프로젝트는 별도 하위 폴더로 격리하고 자체 규칙을 두며, 본류 문서와 상호 오염 금지
