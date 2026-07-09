# 프롬프트 모음집 — Fable5 하네스 템플릿

> 실제 프로젝트 운영에서 반복 사용이 확인된 프롬프트 패턴만 수록.
> 사용법: 파일을 열어 프롬프트 본문을 복사 → `{{placeholder}}`를 프로젝트 값으로 치환 → 투입.
> `<!-- 예: ... -->` 주석은 원 프로젝트의 실사용 예시이며 삭제하고 쓴다.

| # | 패턴 | 언제 쓰나 |
|---|------|-----------|
| ① | [harden-new-harness.md](harden-new-harness.md) | 새 스크립트/러너/하니스를 만든 직후, 비용 큰 본 실행 전에 결함 선제 제거 |
| ② | [adversarial-review.md](adversarial-review.md) | 설계·구현·주장을 확정하기 전 스스로 공격해 살아남는 것만 남길 때 |
| ③ | [visual-qa.md](visual-qa.md) | 덱·차트·도식·PDF 등 렌더링 결과물을 납품하기 전 |
| ④ | [deck-discipline.md](deck-discipline.md) | 실험/진행 결과를 발표 슬라이드로 만들 때 |
| ⑤ | [diagram-production.md](diagram-production.md) | 시스템·파이프라인을 그림 1장으로 설명해야 할 때 |
| ⑥ | [session-restart-recall.md](session-restart-recall.md) | 새 세션 시작 시 이전 상태 복원 + 오늘 할 일 결정 |
| ⑦ | [bulk-audit-delegation.md](bulk-audit-delegation.md) | 인용·수치·인터페이스 등 수십 건 이상 항목의 전수 검증 |
| ⑧ | [root-cause-investigation.md](root-cause-investigation.md) | 버그·원인 불명 실패를 첫 인상으로 고치기 전 |
| ⑨ | [project-deep-review.md](project-deep-review.md) | 트랙/프로젝트 총검토 → 갭 분석 → 실행 단계 플랜이 필요할 때 |
| ⑩ | [parallel-agent-allocation.md](parallel-agent-allocation.md) | 작업을 병렬 에이전트/워크플로우로 쪼갤 때 — 할당 구조 설계 |
| ⑪ | [design-review.md](design-review.md) | 구현 전 설계를 잡아 사용자 결정을 받을 때 ("설계해서 보고해봐") |
| ⑫ | [comparative-judgement.md](comparative-judgement.md) | 가설·직관·대안의 판정을 요구받을 때 ("판단해봐") — 실행 아님 |

스타일 규칙은 [`../style/`](../style/) 참조: [writing-style.md](../style/writing-style.md) · [deck-style.md](../style/deck-style.md) · [diagram-style.md](../style/diagram-style.md)
