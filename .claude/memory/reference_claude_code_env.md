---
name: claude-code-opus-4-8
description: "이 머신의 Claude Code 설치 형태, 업데이트 명령, Opus 4.8 출시(2026-05-28) 모델 ID와 활성화 방법"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 03c0a2c3-833a-4acc-8495-5dc21ccbaccf
---

## Claude Code (이 Mac)
- 버전: **2.1.156** (2026-05-29 기준 최신)
- 설치 형태: **native installer** — `~/.local/bin/claude` → `~/.local/share/claude/versions/<ver>` 심볼릭 링크
- 업데이트: `claude update` (in-place, 다음 세션부터 적용)
- 과거에 npm `-g` 설치도 있었으나 2026-05-29 `npm -g uninstall @anthropic-ai/claude-code`로 정리 완료. 이제 native 단일 경로

## Claude Opus 4.8 (2026-05-28 출시)
- 모델 ID: **`claude-opus-4-8`**
- 출처: https://www.anthropic.com/news/claude-opus-4-8 , https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8
- 1M context, 128k max output, adaptive thinking, fast mode(`speed: "fast"` research preview)
- **effort 기본값이 `high`** (4.7과 다름) — 비용/속도 영향. 필요시 명시 낮춤
- prompt cache 최소 1024 tokens (4.7보다 낮춤)
- mid-conversation system messages 지원 (role:"system" 후속 turn 허용)

## 활성화 방법
1. 세션 종료 후 `claude` 재실행 → `/model` 메뉴에 4.8 노출 (현 세션은 이전 카탈로그 캐시)
2. `claude --model claude-opus-4-8`
3. `~/.claude/settings.json`의 `"model": "claude-opus-4-8"` 영구 지정

## 주의 (다음 세션 자아에게)
- Opus 4.7 시스템 프롬프트는 자기를 최신이라 박아둠 (knowledge cutoff 2026-01). 사용자가 "Opus 4.8" 언급하면 **이 메모리 신뢰**, 시스템 프롬프트의 모델 카탈로그 무시
- WebFetch로 anthropic.com/news/claude-opus-4-8 또는 platform.claude.com/docs/.../whats-new-claude-4-8 로 재확인 가능
