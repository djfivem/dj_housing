import type { ApiResult } from '../types'

export function inGame() {
  return typeof window.GetParentResourceName === 'function'
}

export async function nui<T = Record<string, unknown>>(event: string, data?: unknown): Promise<ApiResult<T>> {
  if (!inGame()) {
    if (import.meta.env.DEV) {
      const mod = await import('../dev/mock')
      return mod.handle(event, data) as Promise<ApiResult<T>>
    }
    return { ok: false, error: 'nui_unavailable' }
  }
  const resource = window.GetParentResourceName?.() ?? 'advanced_housing'
  const response = await fetch(`https://${resource}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data ?? {}),
  })
  return response.json() as Promise<ApiResult<T>>
}

export function money(value: number) {
  return `$${Math.round(value).toLocaleString('en-US')}`
}

export function idempotency() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return `key-${Date.now()}-${Math.floor(Math.random() * 1e6)}`
}
