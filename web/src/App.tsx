import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import heroPhoto from './assets/hero-mansion.jpg'
import apartmentPhoto from './assets/prop-apartment.jpg'
import housePhoto from './assets/prop-house.jpg'
import mansionPhoto from './assets/prop-mansion.jpg'
import trailerPhoto from './assets/prop-trailer.jpg'
import { Desk } from './pages/Desk'
import { idempotency, inGame, money, nui } from './services/nui'
import type { Dashboard, PropertyCard } from './types'

type Modal =
  | { type: 'purchase' | 'rent'; property: PropertyCard; key: string }
  | { type: 'manage' }
  | { type: 'settings' }
  | null

const nav = [
  ['home', 'Home'],
  ['properties', 'My Properties'],
  ['browse', 'Browse Properties'],
  ['garage', 'Garage'],
  ['bills', 'Bills & Payments'],
  ['storage', 'Storage'],
  ['furniture', 'Furniture'],
  ['upgrades', 'Upgrades'],
  ['settings', 'Settings'],
] as const

function photoFor(image?: string) {
  if (image === 'apartment') return apartmentPhoto
  if (image === 'trailer') return trailerPhoto
  if (image === 'house') return housePhoto
  return mansionPhoto
}

function dueLabel(dueAt: number) {
  const days = Math.max(0, Math.ceil((dueAt * 1000 - Date.now()) / 86400000))
  if (days <= 0) return 'Due today'
  return days === 1 ? 'Due in 1 day' : `Due in ${days} days`
}

function accessLabel(role: string) {
  if (role === 'owner' || role === 'coowner') return 'Full Access'
  if (role === 'resident') return 'Resident'
  return 'Limited Access'
}

function project(property: PropertyCard) {
  const x = ((property.entrance?.x ?? 0) + 4000) / 8500
  const y = ((property.entrance?.y ?? 0) + 4500) / 12500
  return { left: `${Math.min(92, Math.max(8, x * 100))}%`, top: `${Math.min(88, Math.max(12, (1 - y) * 100))}%` }
}

export function App() {
  const [visible, setVisible] = useState(!inGame())
  const [dash, setDash] = useState<Dashboard | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [section, setSection] = useState<string>('home')
  const [hidden, setHidden] = useState<Record<string, boolean>>({})
  const [query, setQuery] = useState('')
  const [kind, setKind] = useState('all')
  const [sort, setSort] = useState('newest')
  const [priceBand, setPriceBand] = useState('any')
  const [scope, setScope] = useState<'all' | 'mine'>('all')
  const [garageTab, setGarageTab] = useState<'stored' | 'out'>('stored')
  const [shellTab, setShellTab] = useState<'shells' | 'mlo'>('shells')
  const [category, setCategory] = useState('all')
  const [shell, setShell] = useState<string | null>(null)
  const [modal, setModal] = useState<Modal>(null)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [stashNote, setStashNote] = useState<string | null>(null)

  const refresh = useCallback(async (propertyId?: string | null) => {
    const result = await nui<Dashboard>('dashboard', { propertyId: propertyId ?? undefined })
    if (!result.ok || !result.data) {
      setError(result.error ?? 'dashboard_failed')
      return
    }
    setError(null)
    setDash(result.data)
    setSelectedId(result.data.selected?.id ?? propertyId ?? null)
  }, [])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const data = event.data as { action?: string; view?: string; propertyId?: string }
      if (data?.action === 'open') {
        setVisible(true)
        if (data.view) setSection(data.view)
      }
      if (data?.action === 'close') setVisible(false)
      if (data?.action === 'select' && data.propertyId) {
        setSelectedId(data.propertyId)
        void refresh(data.propertyId)
      }
    }
    window.addEventListener('message', onMessage)
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setModal(null)
        setVisible(false)
        void nui('close')
      }
    }
    window.addEventListener('keydown', onKey)
    if (!inGame()) void refresh(null)
    return () => {
      window.removeEventListener('message', onMessage)
      window.removeEventListener('keydown', onKey)
    }
  }, [refresh])

  const selected = dash?.selected ?? dash?.properties.find((property) => property.id === selectedId) ?? null
  const properties = useMemo(() => {
    let list = dash?.properties ?? []
    if (scope === 'mine' || section === 'properties') list = list.filter((property) => property.role)
    if (query) {
      const needle = query.toLowerCase()
      list = list.filter((property) => property.label.toLowerCase().includes(needle) || property.propertyType.includes(needle))
    }
    if (kind === 'owned') list = list.filter((property) => property.status === 'owned')
    if (kind === 'rented') list = list.filter((property) => property.status === 'rented')
    if (kind === 'available') list = list.filter((property) => property.status === 'available')
    if (priceBand === 'low') list = list.filter((property) => property.purchasePrice < 200000)
    if (priceBand === 'mid') list = list.filter((property) => property.purchasePrice >= 200000 && property.purchasePrice <= 700000)
    if (priceBand === 'high') list = list.filter((property) => property.purchasePrice > 700000)
    if (sort === 'price') list = [...list].sort((a, b) => b.purchasePrice - a.purchasePrice)
    if (sort === 'name') list = [...list].sort((a, b) => a.label.localeCompare(b.label))
    return list
  }, [dash, query, kind, sort, section, priceBand, scope])

  async function run(task: () => Promise<void>) {
    if (busy) return
    setBusy(true)
    setNotice(null)
    try {
      await task()
    } finally {
      setBusy(false)
    }
  }

  function focus(id: string) {
    if (id === 'settings') {
      setModal({ type: 'settings' })
      return
    }
    if (id === 'browse') {
      setSection('browse')
      setScope('all')
      setKind('all')
      return
    }
    if (id === 'properties') {
      setSection('properties')
      setScope('mine')
      setKind('all')
      return
    }
    if (id === 'warrants' || id === 'admin') {
      setSection(id)
      return
    }
    setSection('home')
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  if (!visible) return null
  if (!dash) {
    return <div className="app"><p className="notice">{error ?? 'Loading housing...'}</p></div>
  }

  const catalog = dash.catalog.furniture.filter((item) => category === 'all' || item.category === category)
  const ownedUpgrades = new Set((dash.upgrades ?? []).map((row) => row.upgrade_id))

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">⌂</div>
          <div>
            <h1>HOUSING</h1>
            <p>Your Space · Your Rules</p>
          </div>
        </div>
        <nav className="nav">
          {nav.map(([id, label]) => (
            <button key={id} className={section === id ? 'active' : ''} onClick={() => focus(id)}><NavIcon name={id} />{label}</button>
          ))}
          {dash.police && <button className={section === 'warrants' ? 'active' : ''} onClick={() => focus('warrants')}>Warrants</button>}
          {dash.admin && <button className={section === 'admin' ? 'active' : ''} onClick={() => focus('admin')}>Administration</button>}
        </nav>
        <div className="profile">
          <div className="avatar">{dash.player.name.slice(0, 1)}</div>
          <div>
            <strong>{dash.player.name}</strong>
            <span>Welcome back</span>
          </div>
        </div>
      </aside>
      {(section === 'warrants' || section === 'admin') ? (
        <Desk mode={section} dash={dash} busy={busy} run={run} refresh={refresh} setNotice={setNotice} />
      ) : (
      <main className="board">
        <section className="hero" id="home">
          <div className="hero-art" style={{ backgroundImage: `linear-gradient(180deg, rgba(0,0,0,0.08), rgba(0,0,0,0.55)), url(${heroPhoto})` }}>
            <div className="hero-copy">
              <h2>Welcome Home, {dash.player.name}</h2>
              <p>Manage your properties, pay your bills, and make this space your own.</p>
            </div>
            <div className="stats">
              <div className="stat"><NavIcon name="bills" /><div><span className="muted">Bank Balance</span><b>{money(dash.balance)}</b></div></div>
              <div className="stat"><NavIcon name="home" /><div><span className="muted">Owned Properties</span><b>{dash.counts.owned}</b></div></div>
              <div className="stat"><NavIcon name="properties" /><div><span className="muted">Rented Property</span><b>{dash.counts.rented}</b></div></div>
              <div className="stat"><NavIcon name="storage" /><div><span className="muted">Pending Bills</span><b>{dash.counts.pendingBills}</b></div></div>
            </div>
          </div>
          <div className="hero-bottom">
            <div className="panel quick">
              <header><h3>Quick Actions</h3></header>
              <div className="quick-grid">
                <button className="qa" onClick={() => focus('browse')}><NavIcon name="browse" />Browse<span>Properties</span></button>
                <button className="qa" onClick={() => focus('properties')}><NavIcon name="properties" />My<span>Properties</span></button>
                <button className="qa" onClick={() => focus('bills')}><NavIcon name="bills" />Pay<span>Bills</span></button>
                <button className="qa" onClick={() => focus('furniture')}><NavIcon name="furniture" />Furniture<span>Store</span></button>
                <button className="qa" onClick={() => focus('garage')}><NavIcon name="garage" />Garage</button>
                <button className="qa" onClick={() => focus('storage')}><NavIcon name="storage" />Storage</button>
              </div>
            </div>
            <div className="panel recent">
              <header><h3>Recent Properties</h3><button className="text-btn grow" onClick={() => focus('browse')}>View all →</button></header>
              <div className="recent-row">
                {dash.properties.slice(0, 3).map((property) => (
                  <button key={property.id} className="mini" onClick={() => { setSelectedId(property.id); void refresh(property.id) }}>
                    <img src={photoFor(property.image)} alt="" />
                    <strong>{property.label}</strong>
                    <span>{property.role ?? property.status}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <Panel id="browse" title="Browse Properties" hidden={hidden.browse} onClose={() => setHidden({ ...hidden, browse: true })} className="browse">
          <input className="search" placeholder="Search by name, type, or location" value={query} onChange={(event) => setQuery(event.target.value)} />
          <div className="filters">
            <label>Type
              <select aria-label="Type" value={kind} onChange={(event) => setKind(event.target.value)}>
                <option value="all">All</option>
                <option value="owned">Owned</option>
                <option value="rented">Rented</option>
                <option value="available">Available</option>
              </select>
            </label>
            <label>Price Range
              <select aria-label="Price Range" value={priceBand} onChange={(event) => setPriceBand(event.target.value)}>
                <option value="any">Any</option>
                <option value="low">Under $200,000</option>
                <option value="mid">$200,000 – $700,000</option>
                <option value="high">Over $700,000</option>
              </select>
            </label>
            <label>Sort By
              <select aria-label="Sort" value={sort} onChange={(event) => setSort(event.target.value)}>
                <option value="newest">Newest</option>
                <option value="price">Price</option>
                <option value="name">Name</option>
              </select>
            </label>
          </div>
          <div className="scroll">
            {properties.map((property) => (
              <button key={property.id} className={`prop ${selected?.id === property.id ? 'selected' : ''}`} onClick={() => { setSelectedId(property.id); void refresh(property.id) }}>
                <img className="thumb" src={photoFor(property.image)} alt="" />
                <span>
                  <strong>{property.label}</strong>
                  <span className={`badge ${property.status}`}>{property.status}</span>
                  <span className="price">{money(property.listed && property.listingPrice ? property.listingPrice : property.purchasePrice)}</span>
                  <span className="meta"><span>{property.bedrooms} bed</span><span>{property.bathrooms} bath</span><span>{property.garages} car</span></span>
                </span>
              </button>
            ))}
            {properties.length === 0 && <p className="muted">No properties match those filters.</p>}
          </div>
        </Panel>

        {selected && (
          <Panel id="details" title="Property Details" hidden={hidden.details} onClose={() => setHidden({ ...hidden, details: true })} className="details">
            <img className="detail-hero" src={photoFor(selected.image)} alt="" />
            <div className="detail-body">
              <strong>{selected.label}</strong>
              <span className={`badge ${selected.role ?? selected.status}`}>{selected.role ?? selected.status}</span>
              <span className="price">{money(selected.purchasePrice)}</span>
              <span className="meta"><span>{selected.bedrooms} bedrooms</span><span>{selected.bathrooms} bathrooms</span><span>{selected.garages} garages</span></span>
              <p className="muted">{selected.description}</p>
            </div>
            <div className="actions">
              <button className="orange" disabled={busy || !selected.role} onClick={() => run(async () => {
                const result = await nui('enter', { propertyId: selected.id })
                setNotice(result.ok ? `Entering ${selected.label}` : (result.error ?? 'enter_failed'))
              })}>Enter Property</button>
              <button className="ghost" disabled={!selected.role} onClick={() => setModal({ type: 'manage' })}>Manage</button>
            </div>
            {selected.status === 'available' && (
              <div className="actions">
                <button className="orange" disabled={busy} onClick={() => setModal({ type: 'purchase', property: selected, key: idempotency() })}>Purchase</button>
                <button className="ghost" disabled={busy} onClick={() => setModal({ type: 'rent', property: selected, key: idempotency() })}>Rent</button>
              </div>
            )}
          </Panel>
        )}

        <Panel id="furniture" title="Furniture Store" hidden={hidden.furniture} onClose={() => setHidden({ ...hidden, furniture: true })} className="furniture">
          <div className="tabs">
            {['all', 'living', 'bedroom', 'kitchen', 'decor'].map((item) => (
              <button key={item} className={category === item ? 'on' : ''} onClick={() => setCategory(item)}>{item}</button>
            ))}
          </div>
          <div className="card-grid scroll">
            {catalog.map((item) => (
              <button key={item.id} className="card" disabled={busy || !selected?.role} onClick={() => run(async () => {
                if (!selected) return
                const result = await nui('buyFurniture', { propertyId: selected.id, catalogId: item.id, idempotencyKey: idempotency() })
                setNotice(result.ok ? `${item.label} purchased` : (result.error ?? 'purchase_failed'))
                if (result.ok) await refresh(selected.id)
              })}>
                <span className={`furn ${item.category}`} />
                <b>{item.label}</b>
                <span>{money(item.price)}</span>
              </button>
            ))}
          </div>
        </Panel>

        <Panel id="garage" title="Garage" hidden={hidden.garage} onClose={() => setHidden({ ...hidden, garage: true })} className="garage">
          <div className="tabs">
            <button className={garageTab === 'stored' ? 'on' : ''} onClick={() => setGarageTab('stored')}>My Vehicles</button>
            <button className={garageTab === 'out' ? 'on' : ''} onClick={() => setGarageTab('out')}>Out</button>
          </div>
          <div className="scroll">
            {(dash.vehicles ?? []).filter((vehicle) => (garageTab === 'stored' ? vehicle.state === 'stored' : vehicle.state !== 'stored')).map((vehicle) => (
              <div className="veh" key={vehicle.id}>
                <div>
                  <strong>{vehicle.plate}</strong>
                  <div className="muted">{vehicle.state}</div>
                </div>
                <button className="buy" disabled={busy} onClick={() => run(async () => {
                  if (!selected) return
                  const spawning = vehicle.state === 'stored'
                  const result = await nui(spawning ? 'takeVehicle' : 'storeVehicle', { propertyId: selected.id, vehicleId: vehicle.id })
                  setNotice(result.ok ? `${vehicle.plate} ${spawning ? 'spawned' : 'stored'}` : (result.error ?? 'garage_failed'))
                  if (result.ok) await refresh(selected.id)
                })}>{vehicle.state === 'stored' ? 'Spawn' : 'Store'}</button>
              </div>
            ))}
            {(dash.vehicles ?? []).filter((vehicle) => (garageTab === 'stored' ? vehicle.state === 'stored' : vehicle.state !== 'stored')).length === 0 && <p className="muted">No vehicles in this tab.</p>}
          </div>
        </Panel>

        <Panel id="storage" title="Storage" hidden={hidden.storage} onClose={() => setHidden({ ...hidden, storage: true })} className="storage">
          <div className="scroll">
            {(dash.stashes ?? []).map((stash) => (
              <div className="stash" key={stash.key}>
                <div>
                  <strong>{stash.label}</strong>
                  <div className="muted">{stash.slots} slots · {Math.round(stash.maxWeight / 1000)}kg · {stash.stashType}</div>
                </div>
                <button className="buy" disabled={busy || !selected} onClick={() => run(async () => {
                  if (!selected) return
                  const result = await nui('openStash', { propertyId: selected.id, stashKey: stash.key })
                  setStashNote(result.ok ? `Opened ${stash.label}` : (result.error ?? 'stash_failed'))
                })}>Open</button>
              </div>
            ))}
            <p className="cap">{stashNote ?? 'Stash contents stay in the active inventory.'}</p>
          </div>
        </Panel>

        <Panel id="bills" title="Bills & Payments" hidden={hidden.bills} onClose={() => setHidden({ ...hidden, bills: true })} className="bills">
          <div className="scroll">
            {(dash.bills ?? []).filter((bill) => bill.status === 'due').map((bill) => (
              <div className="bill" key={bill.id}>
                <div>
                  <strong>{bill.label}</strong>
                  <div className="muted">{selected?.label} · {dueLabel(bill.due_at)} · {money(bill.amount)}</div>
                </div>
                <button className="buy" disabled={busy} onClick={() => run(async () => {
                  const result = await nui('payBill', { billId: bill.id })
                  setNotice(result.ok ? 'Bill paid' : (result.error ?? 'payment_failed'))
                  if (result.ok && selected) await refresh(selected.id)
                })}>Pay</button>
              </div>
            ))}
            {(dash.bills ?? []).filter((bill) => bill.status === 'due').length === 0 && <p className="muted">No bills due.</p>}
          </div>
          <button className="orange block" disabled={busy || !selected} onClick={() => run(async () => {
            if (!selected) return
            const result = await nui('payAll', { propertyId: selected.id })
            setNotice(result.ok ? 'Bills paid' : (result.error ?? 'payment_failed'))
            if (result.ok) await refresh(selected.id)
          })}>Pay All Bills</button>
        </Panel>

        <Panel id="upgrades" title="Property Upgrades" hidden={hidden.upgrades} onClose={() => setHidden({ ...hidden, upgrades: true })} className="upgrades">
          <div className="scroll">
            {dash.catalog.upgrades.map((upgrade) => (
              <div className="upgrade" key={upgrade.id}>
                <div>
                  <strong>{upgrade.label}</strong>
                  <div className="muted">{upgrade.description}</div>
                </div>
                <button className="buy" disabled={busy || ownedUpgrades.has(upgrade.id) || !selected?.role} onClick={() => run(async () => {
                  if (!selected) return
                  const result = await nui('buyUpgrade', { propertyId: selected.id, upgradeId: upgrade.id, idempotencyKey: idempotency() })
                  setNotice(result.ok ? `${upgrade.label} installed` : (result.error ?? 'upgrade_failed'))
                  if (result.ok) await refresh(selected.id)
                })}>{ownedUpgrades.has(upgrade.id) ? 'Owned' : money(upgrade.price)}</button>
              </div>
            ))}
          </div>
        </Panel>

        <Panel id="map" title="Property Map" hidden={hidden.map} onClose={() => setHidden({ ...hidden, map: true })} className="map-panel">
          <div className="legend">
            <span><i className="dot" style={{ background: 'var(--green)' }} />Owned</span>
            <span><i className="dot" style={{ background: 'var(--blue)' }} />Rented</span>
            <span><i className="dot" style={{ background: 'var(--orange)' }} />Available</span>
          </div>
          <div className="map">
            <svg viewBox="0 0 200 140" aria-hidden="true">
              <path d="M20 30 C40 10, 80 20, 110 18 C150 16, 180 40, 170 70 C160 100, 120 120, 80 112 C40 104, 10 80, 20 30Z" fill="#1c2633" stroke="#334155" />
              <path d="M30 78 C50 90, 70 86, 90 96" fill="none" stroke="#243140" strokeWidth="6" />
            </svg>
            {dash.properties.map((property) => (
              <button key={property.id} className={`blip ${property.role ?? property.status}`} style={project(property)} title={property.label} onClick={() => { setSelectedId(property.id); void refresh(property.id) }} />
            ))}
          </div>
        </Panel>

        <Panel id="shells" title="Shells / MLOs" hidden={hidden.shells} onClose={() => setHidden({ ...hidden, shells: true })} className="shells">
          <div className="tabs">
            <button className={shellTab === 'shells' ? 'on' : ''} onClick={() => setShellTab('shells')}>Shells</button>
            <button className={shellTab === 'mlo' ? 'on' : ''} onClick={() => setShellTab('mlo')}>MLOs</button>
          </div>
          <div className="scroll">
            {shellTab === 'shells' && Object.entries(dash.catalog.shells).map(([id, item]) => (
              <div className="shell-card" key={id}>
                <img src={mansionPhoto} alt="" />
                <div>
                  <strong>{item.label}</strong>
                  <div className="muted">{item.model}</div>
                </div>
                <button className="buy" onClick={() => { setShell(id); setNotice(`${item.label} will be used on the next shell purchase`) }}>{shell === id ? 'Selected' : 'Select'}</button>
              </div>
            ))}
            {shellTab === 'mlo' && <p className="muted">MLO and IPL properties use their built interior. No shell is spawned for them.</p>}
          </div>
        </Panel>

        <Panel id="permissions" title="Property Permissions" hidden={hidden.permissions} onClose={() => setHidden({ ...hidden, permissions: true })} className="permissions">
          <div className="scroll">
            {(dash.access ?? []).filter((row) => !row.revoked).map((row) => (
              <div className="person-row" key={row.characterId}>
                <div className="person">{row.displayName.slice(0, 1)}</div>
                <div>
                  <strong>{row.displayName}</strong>
                  <div className="muted">{accessLabel(row.role)}</div>
                </div>
              </div>
            ))}
            {(dash.access ?? []).length === 0 && <p className="muted">Select a property you manage to see residents.</p>}
          </div>
          <button className="orange block" disabled={!selected?.role} onClick={() => setModal({ type: 'manage' })}>Manage Access</button>
        </Panel>
      </main>
      )}
      <div className="footer-note">More Than Just a House… <b>IT’S YOURS.</b></div>
      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}
      {modal && (
        <div className="modal-back" onClick={() => setModal(null)}>
          <div className="panel modal" onClick={(event) => event.stopPropagation()}>
            {modal.type === 'settings' && (
              <>
                <h3>Settings</h3>
                <p className="muted">Press Escape or use Close to return to the game. Housing focus is released when this UI closes.</p>
                <button className="orange" onClick={() => { setModal(null); setVisible(false); void nui('close') }}>Close Housing</button>
              </>
            )}
            {(modal.type === 'purchase' || modal.type === 'rent') && (
              <>
                <h3>{modal.type === 'purchase' ? 'Confirm purchase' : 'Confirm rental'}</h3>
                <p>{modal.property.label}</p>
                <p className="price">{money(modal.type === 'purchase' ? modal.property.purchasePrice : modal.property.rentalPrice)}</p>
                <p className="muted">The server uses the stored price. This request cannot be submitted twice.</p>
                <button className="orange" disabled={busy} onClick={() => run(async () => {
                  const price = modal.type === 'purchase' ? modal.property.purchasePrice : modal.property.rentalPrice
                  const result = await nui(modal.type === 'purchase' ? 'purchase' : 'rent', {
                    propertyId: modal.property.id,
                    idempotencyKey: modal.key,
                    mode: modal.type === 'purchase' ? 'purchase' : 'rent',
                    expectedPrice: price,
                    shellModel: shell,
                  })
                  setNotice(result.ok ? 'Transaction complete' : (result.error ?? 'transaction_failed'))
                  if (result.ok) {
                    setModal(null)
                    await refresh(modal.property.id)
                  }
                })}>Confirm</button>
              </>
            )}
            {modal.type === 'manage' && selected && (
              <Manage selected={selected} busy={busy} onIssue={(targetSource) => run(async () => {
                const result = await nui('issueKey', { propertyId: selected.id, idempotencyKey: idempotency(), accessLevel: 'guest', targetSource })
                setNotice(result.ok ? 'Key issued' : (result.error ?? 'key_failed'))
                if (result.ok) await refresh(selected.id)
              })} onClose={() => setModal(null)} keys={dash.keys ?? []} onSell={() => run(async () => {
                const percent = dash.rules?.saleReturnPercent ?? 60
                const price = Math.floor(selected.purchasePrice * percent / 100)
                const result = await nui('sell', {
                  propertyId: selected.id,
                  idempotencyKey: idempotency(),
                  mode: 'purchase',
                  expectedPrice: price,
                })
                setNotice(result.ok ? 'Sale recorded' : (result.error ?? 'sale_failed'))
                if (result.ok) {
                  setModal(null)
                  await refresh(selected.id)
                }
              })} onRevoke={(keyId) => run(async () => {
                const result = await nui('revokeKey', { keyId })
                setNotice(result.ok ? 'Key revoked' : (result.error ?? 'key_failed'))
                if (result.ok) await refresh(selected.id)
              })} />
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function NavIcon(props: { name: string }) {
  const common = { width: 16, height: 16, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, 'aria-hidden': true } as const
  if (props.name === 'home') return <svg {...common}><path d="M4 11 12 4l8 7v8a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z" /></svg>
  if (props.name === 'properties') return <svg {...common}><path d="M4 10h7V4H4zm9 10h7v-6h-7zM4 20h7v-8H4zm9-8h7V4h-7z" /></svg>
  if (props.name === 'browse') return <svg {...common}><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></svg>
  if (props.name === 'garage') return <svg {...common}><path d="M4 16h16M6 16l2-6h8l2 6M7 19a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm10 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2z" /></svg>
  if (props.name === 'bills') return <svg {...common}><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M3 10h18" /></svg>
  if (props.name === 'storage') return <svg {...common}><path d="M4 7h16v4H4zm0 6h16v4H4z" /></svg>
  if (props.name === 'furniture') return <svg {...common}><path d="M4 13h16v5H4zM6 13V9a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v4" /></svg>
  if (props.name === 'upgrades') return <svg {...common}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18" /></svg>
  return <svg {...common}><circle cx="12" cy="12" r="3" /><path d="M12 3v2M12 19v2M3 12h2M19 12h2" /></svg>
}

function Panel(props: { id: string; title: string; className: string; hidden?: boolean; onClose: () => void; children: ReactNode }) {
  return (
    <section id={props.id} className={`panel ${props.className} ${props.hidden ? 'hidden' : ''}`}>
      <header>
        <h3>{props.title}</h3>
        <button className="icon-btn spacer" aria-label={`Close ${props.title}`} onClick={props.onClose}>×</button>
      </header>
      {props.children}
    </section>
  )
}

function Manage(props: {
  selected: PropertyCard
  busy: boolean
  keys: { id: string; state: string; accessLevel: string; holderName: string }[]
  onIssue: (targetSource?: number) => void
  onRevoke: (keyId: string) => void
  onSell: () => void
  onClose: () => void
}) {
  const [target, setTarget] = useState('')
  const targetSource = target.trim() === '' ? undefined : Number(target)
  return (
    <>
      <h3>Manage {props.selected.label}</h3>
      <p className="muted">Keys are inventory items. Revocation is checked against the database record, not the item metadata.</p>
      {props.keys.map((key) => (
        <div className="person-row" key={key.id}>
          <div>
            <strong>{key.accessLevel}</strong>
            <div className="muted">{key.state} · {key.holderName}</div>
          </div>
          <button className="ghost" disabled={props.busy || key.state === 'revoked'} onClick={() => props.onRevoke(key.id)}>Revoke</button>
        </div>
      ))}
      <label className="field">Server ID for the recipient
        <input value={target} onChange={(event) => setTarget(event.target.value)} placeholder="Leave empty to issue to yourself" />
      </label>
      <button className="orange" disabled={props.busy || (target !== '' && !Number.isInteger(targetSource))} onClick={() => props.onIssue(targetSource)}>Issue guest key</button>
      {props.selected.role === 'owner' && (
        <button className="ghost" disabled={props.busy} onClick={() => props.onSell()}>Sell to state</button>
      )}
      <button className="ghost" onClick={props.onClose}>Done</button>
    </>
  )
}
