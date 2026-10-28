import { useState } from 'react'
import { idempotency, money, nui } from '../services/nui'
import type { ApiResult, Dashboard } from '../types'

type Props = {
  mode: 'warrants' | 'admin'
  dash: Dashboard
  busy: boolean
  run: (task: () => Promise<void>) => void
  refresh: (propertyId?: string | null) => Promise<void>
  setNotice: (value: string | null) => void
}

function text(row: Record<string, unknown>, key: string) {
  const value = row[key]
  return value == null ? '' : String(value)
}

export function Desk(props: Props) {
  const selected = props.dash.selected
  const propertyId = selected?.id ?? ''
  const [reason, setReason] = useState('Suspected storage of stolen goods')
  const [caseRef, setCaseRef] = useState('CASE-1001')
  const [duration, setDuration] = useState('12')
  const [seizure, setSeizure] = useState(false)
  const [warrantId, setWarrantId] = useState('')
  const [officers, setOfficers] = useState('')
  const [raidId, setRaidId] = useState('')
  const [stashKey, setStashKey] = useState('shared')
  const [itemName, setItemName] = useState('')
  const [quantity, setQuantity] = useState('1')
  const [items, setItems] = useState<Array<Record<string, unknown>>>([])
  const [targetSource, setTargetSource] = useState('')

  async function call(event: string, data: Record<string, unknown>) {
    const result = await nui(event, data)
    props.setNotice(result.ok ? `${event} accepted` : (result.error ?? 'request_failed'))
    if (result.ok && propertyId) await props.refresh(propertyId)
    return result
  }

  return (
    <main className="desk">
      <section className="panel">
        <header><h3>{props.mode === 'warrants' ? 'Warrants & raids' : 'Administration'}</h3></header>
        <div className="scroll">
          <p className="muted">{selected ? selected.label : 'Select a property from Home before using this desk.'}</p>
          {props.mode === 'warrants' && (
            <div className="form-grid">
              <label className="field">Reason
                <input value={reason} onChange={(event) => setReason(event.target.value)} />
              </label>
              <label className="field">Case reference
                <input value={caseRef} onChange={(event) => setCaseRef(event.target.value)} />
              </label>
              <label className="field">Duration hours
                <input value={duration} onChange={(event) => setDuration(event.target.value)} />
              </label>
              <label className="checks">
                <input type="checkbox" checked={seizure} onChange={(event) => setSeizure(event.target.checked)} />
                Request seizure authority
              </label>
              <button className="orange" disabled={props.busy || !propertyId} onClick={() => props.run(async () => {
                await call('requestWarrant', {
                  propertyId,
                  idempotencyKey: idempotency(),
                  reason,
                  caseReference: caseRef,
                  durationHours: Number(duration),
                  scope: { all: true },
                  allowSeizure: seizure,
                })
              })}>Request warrant</button>
              <label className="field">Warrant ID
                <input value={warrantId} onChange={(event) => setWarrantId(event.target.value)} />
              </label>
              <div className="actions">
                <button className="orange" disabled={props.busy || !warrantId} onClick={() => props.run(() => call('decideWarrant', { warrantId, decision: 'authorise' }).then(() => undefined))}>Authorise</button>
                <button className="ghost" disabled={props.busy || !warrantId} onClick={() => props.run(() => call('decideWarrant', { warrantId, decision: 'revoke' }).then(() => undefined))}>Revoke</button>
              </div>
              {(props.dash.warrants ?? []).map((row) => (
                <button className="row" key={text(row, 'id')} onClick={() => setWarrantId(text(row, 'id'))}>
                  <div>
                    <strong>{text(row, 'status')}</strong>
                    <div className="muted">{text(row, 'reason_text') || text(row, 'case_reference')}</div>
                  </div>
                  <span>{text(row, 'id').slice(0, 8)}</span>
                </button>
              ))}
            </div>
          )}
          {props.mode === 'admin' && (
            <div className="form-grid">
              <p className="muted">Archive keeps stash contents in the inventory resource. Evidence rows are not deleted.</p>
              <button className="orange" disabled={props.busy || !propertyId} onClick={() => props.run(() => call('adminEnable', { propertyId, enabled: !(selected?.enabled) }).then(() => undefined))}>
                {selected?.enabled ? 'Disable property' : 'Enable property'}
              </button>
              <button className="ghost" disabled={props.busy || !propertyId} onClick={() => props.run(() => call('adminRepair', { propertyId }).then(() => undefined))}>Repair state</button>
              <button className="ghost" disabled={props.busy || !propertyId} onClick={() => props.run(() => call('adminArchive', { propertyId, force: false }).then(() => undefined))}>Archive if unowned</button>
              <label className="field">Transfer to server ID
                <input value={targetSource} onChange={(event) => setTargetSource(event.target.value)} />
              </label>
              <button className="orange" disabled={props.busy || !Number.isInteger(Number(targetSource))} onClick={() => props.run(() => call('adminTransfer', { propertyId, targetSource: Number(targetSource) }).then(() => undefined))}>Transfer ownership</button>
              <button className="ghost" disabled={props.busy} onClick={() => props.run(() => call('collectPayouts', {}).then(() => undefined))}>Collect payouts</button>
              {(props.dash.pending ?? []).map((row) => (
                <div className="row" key={text(row, 'id')}>
                  <div>
                    <strong>{text(row, 'status')}</strong>
                    <div className="muted">{text(row, 'tx_type')} · {money(Number(row.amount ?? 0))}</div>
                  </div>
                </div>
              ))}
              {(props.dash.audit ?? []).slice(0, 12).map((row) => (
                <div className="row" key={text(row, 'id')}>
                  <div>
                    <strong>{text(row, 'action_name')}</strong>
                    <div className="muted">{text(row, 'category')}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>
      {props.mode === 'warrants' && (
        <section className="panel">
          <header><h3>Active raid</h3></header>
          <div className="scroll form-grid">
            <label className="field">Officer server IDs
              <input value={officers} onChange={(event) => setOfficers(event.target.value)} placeholder="2, 4" />
            </label>
            <button className="orange" disabled={props.busy || !propertyId || !warrantId} onClick={() => props.run(async () => {
              const result = await call('openRaid', {
                propertyId,
                warrantId,
                idempotencyKey: idempotency(),
                officerSources: officers.split(',').map((part) => Number(part.trim())).filter((value) => Number.isInteger(value) && value > 0),
              })
              const id = (result.data as { raidId?: string } | undefined)?.raidId
              if (id) setRaidId(id)
            })}>Open raid</button>
            <label className="field">Raid ID
              <input value={raidId} onChange={(event) => setRaidId(event.target.value)} />
            </label>
            <div className="actions">
              {['authorised', 'active', 'completed', 'cancelled'].map((state) => (
                <button key={state} className="ghost" disabled={props.busy || !raidId} onClick={() => props.run(() => call('setRaidState', { raidId, state }).then(() => undefined))}>{state}</button>
              ))}
            </div>
            {(props.dash.raids ?? []).map((row) => (
              <button className="row" key={text(row, 'id')} onClick={() => setRaidId(text(row, 'id'))}>
                <div>
                  <strong>{text(row, 'state')}</strong>
                  <div className="muted">{text(row, 'warrant_id')}</div>
                </div>
              </button>
            ))}
          </div>
        </section>
      )}
      {props.mode === 'warrants' && (
        <section className="panel">
          <header><h3>Search & evidence</h3></header>
          <div className="scroll form-grid">
            <label className="field">Stash key
              <input value={stashKey} onChange={(event) => setStashKey(event.target.value)} />
            </label>
            <button className="orange" disabled={props.busy || !propertyId} onClick={() => props.run(async () => {
              const result: ApiResult<{ items?: Array<Record<string, unknown>> }> = await call('inspectStash', { propertyId, stashKey })
              setItems(result.data?.items ?? [])
            })}>Inspect stash</button>
            {items.map((item, index) => (
              <div className="row" key={`${text(item, 'name')}-${index}`}>
                <div>
                  <strong>{text(item, 'label') || text(item, 'name')}</strong>
                  <div className="muted">qty {text(item, 'count')} · slot {text(item, 'slot')}</div>
                </div>
                <button className="buy" onClick={() => setItemName(text(item, 'name'))}>Use</button>
              </div>
            ))}
            {items.length === 0 && <p className="muted">Inspection lists items only while a raid is active and the inventory adapter can read the stash.</p>}
            <label className="field">Item
              <input value={itemName} onChange={(event) => setItemName(event.target.value)} />
            </label>
            <label className="field">Quantity
              <input value={quantity} onChange={(event) => setQuantity(event.target.value)} />
            </label>
            <button className="orange" disabled={props.busy || !itemName || !raidId} onClick={() => props.run(() => call('seize', {
              propertyId,
              stashKey,
              raidId,
              itemName,
              quantity: Number(quantity),
              idempotencyKey: idempotency(),
            }).then(() => undefined))}>Seize item</button>
            {(props.dash.evidence ?? []).map((row) => (
              <div className="row" key={text(row, 'id')}>
                <div>
                  <strong>{text(row, 'item_name')} × {text(row, 'quantity')}</strong>
                  <div className="muted">{text(row, 'status')} · {text(row, 'case_reference')}</div>
                </div>
                {text(row, 'status') === 'seized' && (
                  <button className="ghost" disabled={props.busy} onClick={() => props.run(() => call('transferEvidence', { evidenceId: text(row, 'id'), status: 'transferred', note: caseRef }).then(() => undefined))}>Transfer</button>
                )}
              </div>
            ))}
          </div>
        </section>
      )}
      {props.mode === 'admin' && (
        <>
          <section className="panel">
            <header><h3>Property</h3></header>
            <div className="scroll">
              {props.dash.properties.map((property) => (
                <button className="row" key={property.id} onClick={() => void props.refresh(property.id)}>
                  <div>
                    <strong>{property.label}</strong>
                    <div className="muted">{property.status} · {property.enabled ? 'enabled' : 'disabled'}</div>
                  </div>
                  <span className="price">{money(property.purchasePrice)}</span>
                </button>
              ))}
            </div>
          </section>
          <section className="panel">
            <header><h3>Pending transactions</h3></header>
            <div className="scroll">
              {(props.dash.pending ?? []).length === 0 && <p className="muted">No transactions are waiting for review.</p>}
            </div>
          </section>
        </>
      )}
    </main>
  )
}
