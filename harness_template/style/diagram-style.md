# 도식 규칙 카드

> 실운영 프로젝트의 도식 생성 스크립트(matplotlib 기반)에서 실제 사용 중인 값·구조만 추출. 함께 사용: [prompts/diagram-production.md](../prompts/diagram-production.md), 검수는 [prompts/visual-qa.md](../prompts/visual-qa.md).

## F1. 공통 기반

matplotlib Agg + 한글 폰트 `AppleGothic` + `axes.unicode_minus=False` + dpi 200 + 흰 배경 + `bbox_inches="tight"`. 산출은 문서 트리 `figures/` 하위, png(필요 시 +pdf).

## F2. 도식 팔레트 (hex)

NAVY `#2F3C7E` · GREEN `#0B6E4F` · BROWN `#8A4B08` · RED `#B00020`(핵심/★ 전용) · GRAY `#444444`/`#555555`.
**행위 주체(레인)당 1색** 고정 — 그 주체의 블록 테두리·라벨·화살표가 전부 같은 색.

## F3. 레인 구조 (파이프라인 도식)

수평 레인 = 행위 주체 <!-- 예: 운용자 / 스크립트(자동) / 시스템(자동) -->. 레인 = FancyBboxPatch, 주체색 채움 alpha 0.055(거의 흰색), 좌상단 레인 라벨 bold 주체색. 레인 간 전환은 수직 화살표 + 이탤릭 라벨 <!-- 예: "CLI 실행" -->.

## F4. 카드+화살표 문법

블록 = 흰 채움 + 주체색 테두리 lw 1.6~2 라운드 박스. 순서 블록에는 원형 번호 배지(주체색 채움·흰 숫자). 블록 내부 = 제목 bold(10~10.5pt) + 부제 회색 8.6pt(2줄, linespacing 1.4+). 연결 = `FancyArrowPatch` `-|>`. 결정적 관찰 지점은 제목에 ★ + RED.

## F5. 카드 내부 4층 구조 (비교 도식)

`{{구성명 bold 색}}` / `"{{평이한 질문형 별칭}}"` 이탤릭 / `{{스위치·설정 상태}}` 소자 회색 / 구분선 / `{{실측 원문 증거 bold 색}}`. 카드마다 **실측 증거 층 필수** — 설계만 그린 카드 금지.

## F6. 하단 명세 스트립

도식 하단에 회색(`#F2F2F2`) 라운드 스트립: 라벨 bold <!-- 예: "입력 명세" --> + 옵션·기본값·공통 조건을 ` | ` 구분 1~2줄 8.6pt. 대칭·핵심 주장은 별도 강조 스트립(연한 주체색 배경)으로 분리.

## F7. 그림 내 제목

축 상단 중앙 13~14pt bold, `{{주제}} — {{무엇과 무엇을 담았나}}` 형식, 실측 도식이면 날짜 포함.

## F8. 데이터 차트 정직 문법

각 데이터 점에 수치 annotate(bold). 제목에 총 변화량 + `※ 각 점 = {{판독 규칙}}` 내장. spines top/right 제거, y-grid alpha 0.25. 의미 주석은 화살표 달린 annotate 1개(green bold)로 절제.

## SVG 도식 함정 (실기록)

- SVG `font-size` 속성은 CSS 클래스에 밀린다 → `style` 속성으로 지정.
- 편집 원본(SVG)과 렌더본(PNG/PDF)을 함께 산출 — 수정은 원본 편집→재렌더 <!-- 예: Chrome headless 렌더 -->.
