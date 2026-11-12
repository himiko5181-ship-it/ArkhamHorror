/* 게임판 카드 크기 배율 (브라우저별 저장). tokens.css 의 --card-width / --card-height 에 곱해진다. */
export type CardScale = '1' | '1.2' | '1.4' | '1.6' | '1.8'
export const CARD_SCALES: CardScale[] = ['1', '1.2', '1.4', '1.6', '1.8']
// v2: 기본값을 키우면서 키를 바꿔 예전 저장값(1.2) 대신 새 기본값이 적용되게 함
const KEY = 'arkhamCardScale2'
const DEFAULT: CardScale = '1.4'

export function getCardScale(): CardScale {
  try {
    const v = localStorage.getItem(KEY)
    return CARD_SCALES.find((s) => s === v) ?? DEFAULT
  } catch {
    return DEFAULT
  }
}

export function applyCardScale(scale: CardScale = getCardScale()) {
  document.documentElement.style.setProperty('--card-scale', scale)
}

export function setCardScale(scale: CardScale) {
  try { localStorage.setItem(KEY, scale) } catch { /* ignore */ }
  applyCardScale(scale)
}
