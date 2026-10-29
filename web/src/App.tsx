import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import apartmentPhoto from './assets/prop-apartment.jpg'
import housePhoto from './assets/prop-house.jpg'
import mansionPhoto from './assets/prop-mansion.jpg'
import trailerPhoto from './assets/prop-trailer.jpg'
import { Desk } from './pages/Desk'
import { idempotency, inGame, money, nui } from './services/nui'
import type { Bill, Dashboard, PropertyCard } from './types'

type Page =
  | 'house'
  | 'market'
  | 'furniture'
  | 'placed'
  | 'interiors'
  | 'bills'
  | 'keys'
  | 'permissions'
  | 'upgrades'
  | 'garage'
  | 'storage'
  | 'listing'
  | 'sell'
  | 'warrants'
  | 'admin'

type Modal =
  | { type: 'purchase' | 'rent' | 'renew'; property: PropertyCard; key: string }
  | { type: 'bill'; bill: Bill }
  | { type: 'locks' }
  | null

const groups: Array<{ label: string; items: Array<[Page, string]> }> = [
  { label: 'General', items: [['house', 'My House']] },
  {
    label: 'Furniture',
    items: [
      ['furniture', 'Order Furniture'],
      ['placed', 'Furniture'],
      ['interiors', 'Interiors'],
    ],
  },
  {
    label: 'Management',
    items: [
      ['bills', 'Bills'],
      ['keys', 'Keys'],
      ['permissions', 'Permissions'],
      ['upgrades', 'Upgrades'],
      ['garage', 'Garage'],
      ['storage', 'Storage'],
    ],
  },
  {
    label: 'Marketplace',
    items: [
      ['market', 'Marketplace'],
      ['listing', 'List Property'],
      ['sell', 'Sell'],
    ],
  },
]

const titles: Record<Page, [string, string]> = {
  house: ['My House', 'Property information, access, and entry'],
  market: ['Marketplace', 'Compare listings and move in'],
  furniture: ['Order Furniture', 'Pay for a piece and it is stored on the property'],
  placed: ['Furniture', 'Pieces purchased for this property'],
  interiors: ['Interiors', 'Shell choice is sent with the next shell purchase'],
  bills: ['Bills', 'Pay utilities and rent manually'],
  keys: ['Keys', 'Physical keys are inventory items checked against the database'],
  permissions: ['Permissions', 'Residents and guests who can use this property'],
  upgrades: ['Upgrades', 'Permanent improvements for the selected property'],
  garage: ['Garage', 'Vehicles stored at this property'],
  storage: ['Storage', 'Stash contents stay in the active inventory'],
  listing: ['List Property', 'Publish an owner listing at a price you set'],
  sell: ['Sell', 'Sell the property back to the state'],
  warrants: ['Warrants & raids', 'Police tools for the selected property'],
  admin: ['Administration', 'Property controls and the audit ledger'],
}

function photoFor(image?: string) {
  if (image && image.startsWith('https://')) return image
  if (image === 'apartment') return apartmentPhoto
  if (image === 'trailer') return trailerPhoto
  if (image === 'house') return housePhoto
  return mansionPhoto
}

function regionOf(property: PropertyCard) {
  if (property.label.includes('Vinewood')) return 'Vinewood Hills'
  if (property.label.includes('Del Perro')) return 'Del Perro'
  if (property.label.includes('Sandy')) return 'Sandy Shores'
  if (property.label.includes('Mirror')) return 'Mirror Park'
  return 'Los Santos'
}

function dueLabel(dueAt: number) {
  const days = Math.max(0, Math.ceil((dueAt * 1000 - Date.now()) / 86400000))
  if (days <= 0) return 'Due today'
  return days === 1 ? 'Due in 1 day' : `Due in ${days} days`
}

function accessLabel(role: string) {
  if (role === 'owner' || role === 'coowner') return 'Full Access'
  if (role === 'resident') return 'Resident'
  if (role === 'tenant') return 'Tenant'
  return 'Limited Access'
}

function normalize(view?: string): Page {
  const map: Record<string, Page> = {
    home: 'house',
    properties: 'house',
    browse: 'market',
    settings: 'house',
    house: 'house',
    market: 'market',
    furniture: 'furniture',
    placed: 'placed',
    interiors: 'interiors',
    bills: 'bills',
    keys: 'keys',
    permissions: 'permissions',
    upgrades: 'upgrades',
    garage: 'garage',
    storage: 'storage',
    listing: 'listing',
    sell: 'sell',
    warrants: 'warrants',
    admin: 'admin',
  }
  return map[view ?? ''] ?? 'house'
}

export function App() {
  const [visible, setVisible] = useState(!inGame())
  const [dash, setDash] = useState<Dashboard | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [page, setPage] = useState<Page>('house')
  const [query, setQuery] = useState('')
  const [kind, setKind] = useState('all')
  const [sort, setSort] = useState('newest')
  const [priceBand, setPriceBand] = useState('any')
  const [garageTab, setGarageTab] = useState<'stored' | 'out'>('stored')
  const [shellTab, setShellTab] = useState<'shells' | 'mlo'>('shells')
  const [category, setCategory] = useState('all')
  const [shell, setShell] = useState<string | null>(null)
  const [modal, setModal] = useState<Modal>(null)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [formError, setFormError] = useState<string | null>(null)
  const [stashNote, setStashNote] = useState<string | null>(null)
  const [listPrice, setListPrice] = useState('')
  const [keyTarget, setKeyTarget] = useState('')
  const [grantId, setGrantId] = useState('')
  const [grantName, setGrantName] = useState('')
  const [grantRole, setGrantRole] = useState('resident')
  const [imageUrl, setImageUrl] = useState('')
  const busyRef = useRef(false)
  const modalRef = useRef(modal)
  modalRef.current = modal

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

  const closeUi = useCallback(() => {
    setVisible(false)
    void nui('close')
  }, [])

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const data = event.data as { action?: string; view?: string; propertyId?: string }
      if (data?.action === 'open') {
        setVisible(true)
        if (data.view) setPage(normalize(data.view))
      }
      if (data?.action === 'close') setVisible(false)
      if (data?.action === 'select' && data.propertyId) {
        setSelectedId(data.propertyId)
        void refresh(data.propertyId)
      }
    }
    window.addEventListener('message', onMessage)
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return
      if (modalRef.current) {
        setModal(null)
        setFormError(null)
        return
      }
      closeUi()
    }
    window.addEventListener('keydown', onKey)
    if (!inGame()) void refresh(null)
    return () => {
      window.removeEventListener('message', onMessage)
      window.removeEventListener('keydown', onKey)
    }
  }, [refresh, closeUi])

  useEffect(() => {
    if (!notice) return
    const timer = window.setTimeout(() => setNotice(null), 4200)
    return () => window.clearTimeout(timer)
  }, [notice])

  const selected = dash?.selected ?? dash?.properties.find((property) => property.id === selectedId) ?? null

  useEffect(() => {
    if (!selected) return
    setListPrice(String(selected.listingPrice || selected.purchasePrice))
  }, [selected])

  const market = useMemo(() => {
    let list = dash?.properties ?? []
    if (query) {
      const needle = query.toLowerCase()
      list = list.filter((property) => property.label.toLowerCase().includes(needle) || property.propertyType.includes(needle) || regionOf(property).toLowerCase().includes(needle))
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
  }, [dash, query, kind, sort, priceBand])

  const catalog = useMemo(
    () => (dash?.catalog.furniture ?? []).filter((item) => category === 'all' || item.category === category),
    [dash, category],
  )
  const ownedUpgrades = useMemo(() => new Set((dash?.upgrades ?? []).map((row) => row.upgrade_id)), [dash])
  const visibleVehicles = useMemo(
    () => (dash?.vehicles ?? []).filter((vehicle) => (garageTab === 'stored' ? vehicle.state === 'stored' : vehicle.state !== 'stored')),
    [dash, garageTab],
  )
  const dueBills = useMemo(() => (dash?.bills ?? []).filter((bill) => bill.status === 'due'), [dash])
  const dueTotal = dueBills.reduce((sum, bill) => sum + bill.amount, 0)

  async function run(task: () => Promise<void>) {
    if (busyRef.current) return
    busyRef.current = true
    setBusy(true)
    setNotice(null)
    try {
      await task()
    } finally {
      busyRef.current = false
      setBusy(false)
    }
  }

  function openDeal(type: 'purchase' | 'rent' | 'renew', property: PropertyCard) {
    setFormError(null)
    setModal({ type, property, key: idempotency() })
  }

  if (!visible) return null
  if (!dash) {
    return (
      <div className="stage">
        <div className="window loading"><p className="notice">{error ?? 'Loading housing...'}</p></div>
      </div>
    )
  }

  const [heading, sub] = titles[page]
  const activeKeys = (dash.keys ?? []).filter((key) => key.state !== 'revoked')
  const people = (dash.access ?? []).filter((row) => !row.revoked)
  const returnPercent = dash.rules?.saleReturnPercent ?? 60
  const salePrice = selected ? Math.floor(selected.purchasePrice * returnPercent / 100) : 0
  const minList = dash.rules?.minListingPrice ?? 1000
  const targetSource = keyTarget.trim() === '' ? undefined : Number(keyTarget)
  const grantOk = /^[\w:._-]{1,80}$/.test(grantId.trim()) && grantName.trim().length > 0

  return (
    <div className="stage">
      <div className="window">
        <aside className="side">
          <div className="brand">
            <span className="mark">⌂</span>
            <div>
              <strong>HOUSING</strong>
              <em>Your Space</em>
            </div>
          </div>
          <label className="field slim">
            Property
            <select className="prop-select" aria-label="Property" value={selected?.id ?? ''} onChange={(event) => { setSelectedId(event.target.value); void refresh(event.target.value) }}>
              {dash.properties.map((property) => (
                <option key={property.id} value={property.id}>{property.label}</option>
              ))}
            </select>
          </label>
          <nav className="nav">
            {groups.map((group) => (
              <div key={group.label}>
                <div className="group">{group.label}</div>
                {group.items.map(([id, label]) => (
                  <button key={id} className={page === id ? 'active' : ''} onClick={() => setPage(id)}>
                    <Glyph name={id} />{label}
                  </button>
                ))}
              </div>
            ))}
            {(dash.police || dash.admin) && <div className="group">Desk</div>}
            {dash.police && <button className={page === 'warrants' ? 'active' : ''} onClick={() => setPage('warrants')}><Glyph name="warrants" />Warrants</button>}
            {dash.admin && <button className={page === 'admin' ? 'active' : ''} onClick={() => setPage('admin')}><Glyph name="admin" />Administration</button>}
          </nav>
          <div className="side-foot">
            <div className="who">
              <span className="avatar">{dash.player.name.slice(0, 1)}</span>
              <div>
                <strong>{dash.player.name}</strong>
                <span>{money(dash.balance)}</span>
              </div>
            </div>
          </div>
        </aside>
        <section className="content">
          <header className="top">
            <div>
              <h2>{heading}</h2>
              <p>{sub}</p>
            </div>
            <div className="top-meta">
              <span className="balance-chip">{money(dash.balance)}</span>
              <button className="icon-btn" aria-label="Close housing" onClick={closeUi}>×</button>
            </div>
          </header>
          <div className="body">
            {page === 'house' && selected && (
              <div className="house">
                <div className="tiles">
                  <Tile icon="pin" label="Address" value={selected.description} />
                  <Tile icon="map" label="Region" value={regionOf(selected)} />
                  <Tile icon="garage" label="Garage" value={selected.garages > 0 ? `${selected.garages} spaces` : 'None'} />
                  <Tile icon="house" label="Status" value={selected.listed ? `${selected.status} · listed` : selected.status} />
                  <Tile icon="interiors" label="Type" value={selected.propertyType.toUpperCase()} />
                  <Tile icon="permissions" label="Access" value={selected.role ? accessLabel(selected.role) : 'Public listing'} />
                  <Tile icon="sell" label="Purchase" value={money(selected.purchasePrice)} />
                  <Tile icon="bills" label="Rent / week" value={money(selected.rentalPrice)} />
                </div>
                <div className="house-side">
                  <div className="house-photo" style={{ backgroundImage: `linear-gradient(180deg, rgba(0,0,0,0.05), rgba(0,0,0,0.55)), url(${photoFor(selected.image)})` }}>
                    <span className={`pill ${selected.role ?? selected.status}`}>{selected.role ?? selected.status}</span>
                    <strong>{selected.label}</strong>
                  </div>
                  <div className="actions">
                    <button className="orange" disabled={busy || !selected.role} onClick={() => run(async () => {
                      const result = await nui('enter', { propertyId: selected.id })
                      setNotice(result.ok ? `Entering ${selected.label}` : (result.error ?? 'enter_failed'))
                    })}>Enter Property</button>
                    {selected.status === 'available' && (
                      <>
                        <button className="orange" disabled={busy} onClick={() => openDeal('purchase', selected)}>Purchase</button>
                        <button className="ghost" disabled={busy} onClick={() => openDeal('rent', selected)}>Rent</button>
                      </>
                    )}
                    {selected.role === 'tenant' && (
                      <button className="ghost" disabled={busy} onClick={() => openDeal('renew', selected)}>Renew</button>
                    )}
                  </div>
                  <p className="muted stay">{selected.bedrooms} bed · {selected.bathrooms} bath · {selected.garages} garage</p>
                  {(selected.role === 'owner' || dash.admin) && (
                    <form className="image-form" onSubmit={(event) => {
                      event.preventDefault()
                      void run(async () => {
                        const result = await nui('setPropertyImage', { propertyId: selected.id, imageUrl })
                        setNotice(result.ok ? 'House image saved' : (result.error ?? 'image_failed'))
                        if (result.ok) await refresh(selected.id)
                      })
                    }}>
                      <input aria-label="House image URL" placeholder="https://r2.fivemanage.com/..." value={imageUrl} onChange={(event) => setImageUrl(event.target.value)} />
                      <button className="ghost" type="submit" disabled={busy || imageUrl.trim() === ''}>Save image</button>
                      <button className="ghost" type="button" disabled={busy} onClick={() => run(async () => {
                        const result = await nui('captureImage', { propertyId: selected.id })
                        setNotice(result.ok ? 'House image captured' : (result.error ?? 'image_failed'))
                        if (result.ok) await refresh(selected.id)
                      })}>Capture</button>
                    </form>
                  )}
                </div>
              </div>
            )}

            {page === 'market' && (
              <>
                <div className="market-tools">
                  <input className="search" aria-label="Search properties" placeholder="Search by name, type, or region" value={query} onChange={(event) => setQuery(event.target.value)} />
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
                </div>
                <div className="market-grid">
                  {market.map((property) => (
                    <article key={property.id} className={`market-card ${selected?.id === property.id ? 'on' : ''}`}>
                      <button className="shot" onClick={() => { setSelectedId(property.id); void refresh(property.id) }}>
                        <img src={photoFor(property.image)} alt="" decoding="async" />
                        <span className="price-tag">{money(property.listed && property.listingPrice ? property.listingPrice : property.purchasePrice)}</span>
                      </button>
                      <div className="market-meta">
                        <strong>{property.label}</strong>
                        <span className="muted">{regionOf(property)} · {property.propertyType}</span>
                        <span className={`pill ${property.status}`}>{property.status}</span>
                        <div className="actions">
                          {property.status === 'available' && (
                            <>
                              <button className="orange" disabled={busy} onClick={() => openDeal('purchase', property)}>Purchase</button>
                              <button className="ghost" disabled={busy} onClick={() => openDeal('rent', property)}>Rent</button>
                            </>
                          )}
                          {property.role && (
                            <button className="ghost" onClick={() => { setSelectedId(property.id); void refresh(property.id); setPage('house') }}>Manage</button>
                          )}
                        </div>
                      </div>
                    </article>
                  ))}
                </div>
                {market.length === 0 && <p className="muted empty">No properties match those filters.</p>}
              </>
            )}

            {page === 'bills' && (
              <div className="sheet">
                <Glyph name="bills" big />
                <div className="metrics">
                  <div className="metric"><span>Unpaid</span><b>{dueBills.length}</b></div>
                  <div className="metric"><span>Amount due</span><b>{money(dueTotal)}</b></div>
                  <div className="metric"><span>Bank</span><b>{money(dash.balance)}</b></div>
                </div>
                {dash.utilities && (
                  <div className="rates">
                    <span>This week</span>
                    <span>Water<b>{money(dash.utilities.rates.water ?? 0)}</b></span>
                    <span>Power<b>{money(dash.utilities.rates.electricity ?? 0)}</b></span>
                    <span>Garbage<b>{money(dash.utilities.rates.garbage ?? 0)}</b></span>
                  </div>
                )}
                <table className="table">
                  <thead>
                    <tr><th>Status</th><th>Period</th><th>Type</th><th>Amount</th><th>Actions</th></tr>
                  </thead>
                  <tbody>
                    {(dash.bills ?? []).map((bill) => (
                      <tr key={bill.id}>
                        <td><span className={`pill ${bill.status === 'paid' ? 'paid' : 'due'}`}>{bill.status === 'paid' ? 'Paid' : 'Unpaid'}</span></td>
                        <td>{dueLabel(bill.due_at)}</td>
                        <td>{bill.label}</td>
                        <td>{money(bill.amount)}</td>
                        <td className="actions">
                          <button className="text-btn" onClick={() => { setFormError(null); setModal({ type: 'bill', bill }) }}>View Details</button>
                          {bill.status === 'due' && (
                            <button className="buy" disabled={busy} onClick={() => run(async () => {
                              const result = await nui('payBill', { billId: bill.id })
                              setNotice(result.ok ? 'Bill paid' : (result.error ?? 'payment_failed'))
                              if (result.ok && selected) await refresh(selected.id)
                            })}>Pay</button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {(dash.bills ?? []).length === 0 && <p className="muted empty">No bills for this property.</p>}
                <button className="orange block" disabled={busy || !selected || dueBills.length === 0} onClick={() => run(async () => {
                  if (!selected) return
                  const result = await nui<{ paid?: number; error?: string }>('payAll', { propertyId: selected.id })
                  if (!result.ok) {
                    setNotice(result.error ?? 'payment_failed')
                    return
                  }
                  setNotice(result.data?.error ? `${result.data.error}` : 'Bills paid')
                  await refresh(selected.id)
                })}>Pay All Bills</button>
              </div>
            )}

            {page === 'keys' && (
              <div className="sheet">
                <Glyph name="keys" big />
                <div className="key-grid">
                  <div className="key-card">
                    <span className="muted">Keys</span>
                    <b>{activeKeys.length}</b>
                    <label className="field">Server ID for the recipient
                      <input value={keyTarget} onChange={(event) => setKeyTarget(event.target.value)} placeholder="Leave empty to issue to yourself" />
                    </label>
                    <button className="orange" disabled={busy || !selected?.role || (keyTarget !== '' && !Number.isInteger(targetSource))} onClick={() => run(async () => {
                      if (!selected) return
                      const result = await nui('issueKey', { propertyId: selected.id, idempotencyKey: idempotency(), accessLevel: 'guest', targetSource })
                      setNotice(result.ok ? 'Key issued' : (result.error ?? 'key_failed'))
                      if (result.ok) await refresh(selected.id)
                    })}>Issue guest key</button>
                  </div>
                  <div className="key-card">
                    <span className="muted">Lock replacement</span>
                    <b>Revoke every key</b>
                    <p>Clears key records for this property. Holders keep the item, but the door stops accepting it.</p>
                    <button className="orange" disabled={busy || selected?.role !== 'owner'} onClick={() => setModal({ type: 'locks' })}>Replace locks</button>
                  </div>
                </div>
                <table className="table">
                  <thead><tr><th>Key</th><th>Holder</th><th>Level</th><th>State</th><th></th></tr></thead>
                  <tbody>
                    {(dash.keys ?? []).map((key) => (
                      <tr key={key.id}>
                        <td>{key.id}</td>
                        <td>{key.holderName}</td>
                        <td>{key.accessLevel}</td>
                        <td><span className={`pill ${key.state === 'active' ? 'paid' : 'due'}`}>{key.state}</span></td>
                        <td>
                          <button className="ghost" disabled={busy || key.state === 'revoked'} onClick={() => run(async () => {
                            const result = await nui('revokeKey', { keyId: key.id })
                            setNotice(result.ok ? 'Key revoked' : (result.error ?? 'key_failed'))
                            if (result.ok && selected) await refresh(selected.id)
                          })}>Revoke</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {(dash.keys ?? []).length === 0 && <p className="muted empty">No keys on this property.</p>}
              </div>
            )}

            {page === 'permissions' && (
              <div className="sheet">
                <div className="people">
                  {people.map((row) => (
                    <div className="person-row" key={row.characterId}>
                      <span className="avatar">{row.displayName.slice(0, 1)}</span>
                      <div>
                        <strong>{row.displayName}</strong>
                        <div className="muted">{accessLabel(row.role)}</div>
                      </div>
                      <button className="ghost" disabled={busy || row.role === 'owner' || !selected} onClick={() => run(async () => {
                        if (!selected) return
                        const result = await nui('revokeAccess', { propertyId: selected.id, targetFramework: row.framework, targetCharacterId: row.characterId })
                        setNotice(result.ok ? 'Access revoked' : (result.error ?? 'access_failed'))
                        if (result.ok) await refresh(selected.id)
                      })}>Revoke</button>
                    </div>
                  ))}
                  {people.length === 0 && <p className="muted">Select a property you manage to see residents.</p>}
                </div>
                <div className="grant">
                  <label className="field">Character ID
                    <input value={grantId} onChange={(event) => setGrantId(event.target.value)} placeholder="license:example" />
                  </label>
                  <label className="field">Display name
                    <input value={grantName} onChange={(event) => setGrantName(event.target.value)} placeholder="Name" />
                  </label>
                  <label className="field">Role
                    <select aria-label="Role" value={grantRole} onChange={(event) => setGrantRole(event.target.value)}>
                      <option value="resident">Resident</option>
                      <option value="guest">Guest</option>
                      <option value="coowner">Co-owner</option>
                    </select>
                  </label>
                  <button className="orange" disabled={busy || !selected?.role || !grantOk} onClick={() => run(async () => {
                    if (!selected) return
                    const result = await nui('grantAccess', {
                      propertyId: selected.id,
                      idempotencyKey: idempotency(),
                      role: grantRole,
                      targetCharacterId: grantId.trim(),
                      targetFramework: dash.player.framework,
                      displayName: grantName.trim(),
                    })
                    setNotice(result.ok ? 'Access granted' : (result.error ?? 'access_failed'))
                    if (result.ok) {
                      setGrantId('')
                      setGrantName('')
                      await refresh(selected.id)
                    }
                  })}>Grant access</button>
                </div>
              </div>
            )}

            {page === 'upgrades' && (
              <div className="upgrade-grid">
                {dash.catalog.upgrades.map((upgrade) => {
                  const owned = ownedUpgrades.has(upgrade.id)
                  return (
                    <article className="upgrade-card" key={upgrade.id}>
                      <span className="muted">Price {money(upgrade.price)}</span>
                      <strong>{upgrade.label}</strong>
                      <p>{upgrade.description}</p>
                      <button className="orange" disabled={busy || owned || !selected?.role} onClick={() => run(async () => {
                        if (!selected) return
                        const result = await nui('buyUpgrade', { propertyId: selected.id, upgradeId: upgrade.id, idempotencyKey: idempotency() })
                        setNotice(result.ok ? `${upgrade.label} installed` : (result.error ?? 'upgrade_failed'))
                        if (result.ok) await refresh(selected.id)
                      })}>{owned ? 'Owned' : 'Upgrade'}</button>
                    </article>
                  )
                })}
              </div>
            )}

            {page === 'furniture' && (
              <>
                <div className="tabs">
                  {['all', 'living', 'bedroom', 'kitchen', 'decor'].map((item) => (
                    <button key={item} className={category === item ? 'on' : ''} onClick={() => setCategory(item)}>{item}</button>
                  ))}
                </div>
                <div className="catalog">
                  {catalog.map((item) => (
                    <article className="furn-card" key={item.id}>
                      <div className={`furn-art ${item.category}`}><FurnShape kind={item.id} /></div>
                      <strong>{item.label}</strong>
                      <span className="price">{money(item.price)}</span>
                      <button className="orange" disabled={busy || !selected?.role} onClick={() => run(async () => {
                        if (!selected) return
                        const result = await nui('buyFurniture', { propertyId: selected.id, catalogId: item.id, idempotencyKey: idempotency() })
                        setNotice(result.ok ? `${item.label} purchased` : (result.error ?? 'purchase_failed'))
                        if (result.ok) await refresh(selected.id)
                      })}>Order</button>
                    </article>
                  ))}
                </div>
              </>
            )}

            {page === 'placed' && (
              <div className="people">
                {(dash.furniture ?? []).map((row) => (
                  <div className="person-row" key={row.id}>
                    <div className={`furn-art mini ${row.model}`}><FurnShape kind={row.catalog_id} /></div>
                    <div>
                      <strong>{row.label}</strong>
                      <div className="muted">{row.state} · {row.model}</div>
                    </div>
                  </div>
                ))}
                {(dash.furniture ?? []).length === 0 && <p className="muted empty">Nothing has been ordered for this property.</p>}
              </div>
            )}

            {page === 'interiors' && (
              <>
                <div className="tabs">
                  <button className={shellTab === 'shells' ? 'on' : ''} onClick={() => setShellTab('shells')}>Shells</button>
                  <button className={shellTab === 'mlo' ? 'on' : ''} onClick={() => setShellTab('mlo')}>MLO / IPL</button>
                </div>
                <div className="people">
                  {shellTab === 'shells' && Object.entries(dash.catalog.shells).map(([id, item]) => (
                    <div className="person-row shell-card" key={id}>
                      <img src={photoFor(item.model.includes('trailer') ? 'trailer' : item.model.includes('v16') ? 'house' : 'mansion')} alt="" decoding="async" />
                      <div>
                        <strong>{item.label}</strong>
                        <div className="muted">{item.model}</div>
                      </div>
                      <button className={shell === id ? 'orange' : 'ghost'} onClick={() => { setShell(id); setNotice(`${item.label} will be used on the next shell purchase`) }}>{shell === id ? 'Selected' : 'Select'}</button>
                    </div>
                  ))}
                  {shellTab === 'mlo' && <p className="muted">MLO and IPL properties use their built interior. No shell is spawned for them.</p>}
                </div>
              </>
            )}

            {page === 'garage' && (
              <>
                <div className="tabs">
                  <button className={garageTab === 'stored' ? 'on' : ''} onClick={() => setGarageTab('stored')}>Stored</button>
                  <button className={garageTab === 'out' ? 'on' : ''} onClick={() => setGarageTab('out')}>Out</button>
                </div>
                <div className="people">
                  {visibleVehicles.map((vehicle) => (
                    <div className="person-row" key={vehicle.id}>
                      <div>
                        <strong>{vehicle.plate}</strong>
                        <div className="muted">{vehicle.state}</div>
                      </div>
                      <button className="orange" disabled={busy || !selected} onClick={() => run(async () => {
                        if (!selected) return
                        const spawning = vehicle.state === 'stored'
                        const result = await nui(spawning ? 'takeVehicle' : 'storeVehicle', { propertyId: selected.id, vehicleId: vehicle.id })
                        setNotice(result.ok ? `${vehicle.plate} ${spawning ? 'spawned' : 'stored'}` : (result.error ?? 'garage_failed'))
                        if (result.ok) await refresh(selected.id)
                      })}>{vehicle.state === 'stored' ? 'Spawn' : 'Store'}</button>
                    </div>
                  ))}
                  {visibleVehicles.length === 0 && <p className="muted empty">No vehicles in this tab.</p>}
                </div>
              </>
            )}

            {page === 'storage' && (
              <div className="people">
                {(dash.stashes ?? []).map((stash) => (
                  <div className="person-row" key={stash.key}>
                    <div>
                      <strong>{stash.label}</strong>
                      <div className="muted">{stash.slots} slots · {Math.round(stash.maxWeight / 1000)}kg · {stash.stashType}</div>
                    </div>
                    <button className="orange" disabled={busy || !selected} onClick={() => run(async () => {
                      if (!selected) return
                      const result = await nui('openStash', { propertyId: selected.id, stashKey: stash.key })
                      setStashNote(result.ok ? `Opened ${stash.label}` : (result.error ?? 'stash_failed'))
                    })}>Open</button>
                  </div>
                ))}
                <p className="muted">{stashNote ?? 'Stash contents stay in the active inventory.'}</p>
              </div>
            )}

            {page === 'listing' && selected && (
              <div className="sheet narrow">
                <p className="muted">{selected.role === 'owner' ? `${selected.label} can be listed between ${money(minList)} and the server cap.` : 'Only the owner can publish a listing.'}</p>
                <p>{selected.listed ? `Currently listed at ${money(selected.listingPrice ?? 0)}` : 'This property is not listed.'}</p>
                <label className="field">Listing price
                  <input value={listPrice} onChange={(event) => setListPrice(event.target.value)} inputMode="numeric" />
                </label>
                <div className="actions">
                  <button className="orange" disabled={busy || selected.role !== 'owner'} onClick={() => run(async () => {
                    const price = Number(listPrice)
                    if (!Number.isInteger(price) || price < minList) {
                      setNotice('invalid_price')
                      return
                    }
                    const result = await nui('list', { propertyId: selected.id, price })
                    setNotice(result.ok ? `Listed at ${money(price)}` : (result.error ?? 'list_failed'))
                    if (result.ok) await refresh(selected.id)
                  })}>List for sale</button>
                  <button className="ghost" disabled={busy || selected.role !== 'owner' || !selected.listed} onClick={() => run(async () => {
                    const result = await nui('unlist', { propertyId: selected.id })
                    setNotice(result.ok ? 'Listing removed' : (result.error ?? 'list_failed'))
                    if (result.ok) await refresh(selected.id)
                  })}>Unlist</button>
                </div>
              </div>
            )}

            {page === 'sell' && selected && (
              <div className="sheet narrow">
                <div className="key-card">
                  <span className="muted">Sale return</span>
                  <b>{money(salePrice)}</b>
                  <p>{returnPercent}% of the purchase price is paid back to the owner. The server checks that amount.</p>
                  <button className="orange" disabled={busy || selected.role !== 'owner'} onClick={() => run(async () => {
                    const result = await nui('sell', {
                      propertyId: selected.id,
                      idempotencyKey: idempotency(),
                      mode: 'purchase',
                      expectedPrice: salePrice,
                    })
                    setNotice(result.ok ? 'Sale recorded' : (result.error ?? 'sale_failed'))
                    if (result.ok) await refresh(selected.id)
                  })}>Sell to state</button>
                </div>
              </div>
            )}

            {(page === 'warrants' || page === 'admin') && (
              <Desk mode={page} dash={dash} busy={busy} run={run} refresh={refresh} setNotice={setNotice} />
            )}
          </div>
        </section>
      </div>
      {notice && <div className="toast" role="status">{notice}</div>}
      {modal && (
        <div className="modal-back" onClick={() => { setModal(null); setFormError(null) }}>
          <div className="modal" onClick={(event) => event.stopPropagation()}>
            {(modal.type === 'purchase' || modal.type === 'rent' || modal.type === 'renew') && (
              <>
                <h3>{modal.type === 'purchase' ? 'Confirm purchase' : modal.type === 'renew' ? 'Renew rental' : 'Confirm rental'}</h3>
                <p>{modal.property.label}</p>
                <p className="price">{money(modal.type === 'purchase' ? modal.property.purchasePrice : modal.property.rentalPrice)}</p>
                <p className="muted">The server uses the stored price. This request cannot be submitted twice.</p>
                {formError && <p className="form-error" role="alert">{formError}</p>}
                <div className="actions">
                  <button className="orange" disabled={busy} onClick={() => run(async () => {
                    const price = modal.type === 'purchase' ? modal.property.purchasePrice : modal.property.rentalPrice
                    const result = await nui(modal.type === 'purchase' ? 'purchase' : modal.type === 'renew' ? 'renew' : 'rent', {
                      propertyId: modal.property.id,
                      idempotencyKey: modal.key,
                      mode: modal.type === 'purchase' ? 'purchase' : modal.type,
                      expectedPrice: price,
                      shellModel: modal.property.propertyType === 'shell' && modal.type === 'purchase' ? shell ?? undefined : undefined,
                    })
                    if (!result.ok) {
                      const message = result.error ?? 'transaction_failed'
                      setFormError(message)
                      setNotice(message)
                      return
                    }
                    setFormError(null)
                    setNotice('Transaction complete')
                    setModal(null)
                    await refresh(modal.property.id)
                  })}>Confirm</button>
                  <button className="ghost" onClick={() => { setModal(null); setFormError(null) }}>Cancel</button>
                </div>
              </>
            )}
            {modal.type === 'bill' && (
              <>
                <h3>{modal.bill.label}</h3>
                <p>{dueLabel(modal.bill.due_at)}</p>
                <p className="price">{money(modal.bill.amount)}</p>
                <p className="muted">{modal.bill.bill_type}</p>
                {formError && <p className="form-error" role="alert">{formError}</p>}
                <div className="actions">
                  {modal.bill.status === 'due' && (
                    <button className="orange" disabled={busy} onClick={() => run(async () => {
                      const result = await nui('payBill', { billId: modal.bill.id })
                      if (!result.ok) {
                        setFormError(result.error ?? 'payment_failed')
                        return
                      }
                      setModal(null)
                      setNotice('Bill paid')
                      if (selected) await refresh(selected.id)
                    })}>Pay the Bill</button>
                  )}
                  <button className="ghost" onClick={() => setModal(null)}>Cancel</button>
                </div>
              </>
            )}
            {modal.type === 'locks' && selected && (
              <>
                <h3>Replace locks</h3>
                <p className="muted">Every key record for {selected.label} is revoked. This cannot be undone from the menu.</p>
                <div className="actions">
                  <button className="orange" disabled={busy} onClick={() => run(async () => {
                    const result = await nui('revokePropertyKeys', { propertyId: selected.id })
                    setNotice(result.ok ? 'Locks replaced' : (result.error ?? 'key_failed'))
                    if (result.ok) {
                      setModal(null)
                      await refresh(selected.id)
                    }
                  })}>Replace locks</button>
                  <button className="ghost" onClick={() => setModal(null)}>Cancel</button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function Tile(props: { icon: string; label: string; value: string }) {
  return (
    <div className="tile">
      <span><Glyph name={props.icon} />{props.label}</span>
      <strong>{props.value}</strong>
    </div>
  )
}

function Glyph(props: { name: string; big?: boolean }) {
  const common = {
    width: props.big ? 140 : 16,
    height: props.big ? 140 : 16,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.7,
    'aria-hidden': true,
    className: props.big ? 'watermark' : undefined,
  } as const
  const path = glyphPath(props.name)
  return <svg {...common}>{path}</svg>
}

function glyphPath(name: string): ReactNode {
  if (name === 'house' || name === 'pin') return <path d="M4 11 12 4l8 7v8a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z" />
  if (name === 'market') return <><circle cx="11" cy="11" r="6" /><path d="m16 16 4 4" /></>
  if (name === 'furniture' || name === 'placed') return <path d="M4 13h16v5H4zM6 13V9a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v4" />
  if (name === 'interiors') return <path d="M4 20V8l8-4 8 4v12H4zm6 0v-6h4v6" />
  if (name === 'bills') return <><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M3 10h18" /></>
  if (name === 'keys') return <path d="M14 7a4 4 0 1 0-3.9 5H14v2h2v2h2v-2h1l1-2h-6.1A4 4 0 0 0 14 7z" />
  if (name === 'permissions') return <><circle cx="9" cy="8" r="3" /><path d="M3 19c1-3 3-4.5 6-4.5S14 16 15 19M17 8h4M19 6v4" /></>
  if (name === 'upgrades') return <path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18" />
  if (name === 'garage') return <path d="M4 16h16M6 16l2-6h8l2 6M7 19a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm10 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2z" />
  if (name === 'storage') return <path d="M4 7h16v4H4zm0 6h16v4H4z" />
  if (name === 'listing' || name === 'sell') return <path d="M4 7h16v10H4zM8 7V5h8v2M12 11v3" />
  if (name === 'map') return <path d="M9 4 4 6v14l5-2 6 2 5-2V4l-5 2zM9 4v14M15 6v14" />
  if (name === 'warrants') return <path d="M6 3h9l3 3v15H6zM9 12h6M9 16h6" />
  return <><circle cx="12" cy="12" r="3" /><path d="M12 3v2M12 19v2M3 12h2M19 12h2" /></>
}

function FurnShape(props: { kind: string }) {
  const frame = { viewBox: '0 0 80 48', 'aria-hidden': true } as const
  if (props.kind.includes('tv')) return <svg {...frame}><rect x="14" y="8" width="52" height="28" rx="2" /><path d="M32 36h16M40 36v6" /></svg>
  if (props.kind.includes('bed')) return <svg {...frame}><rect x="8" y="18" width="64" height="16" rx="3" /><rect x="12" y="10" width="20" height="10" rx="2" /></svg>
  if (props.kind.includes('dining') || props.kind.includes('table')) return <svg {...frame}><rect x="16" y="16" width="48" height="6" rx="1" /><path d="M22 22v12M58 22v12" /></svg>
  if (props.kind.includes('chair')) return <svg {...frame}><path d="M28 14h24v14H28zM32 28v10M48 28v10M28 20h24" /></svg>
  if (props.kind.includes('dresser')) return <svg {...frame}><rect x="18" y="8" width="44" height="32" rx="2" /><path d="M18 18h44M18 28h44M36 13v3M36 23v3" /></svg>
  return <svg {...frame}><path d="M8 28h64v8H8zM14 28V18a6 6 0 0 1 6-6h36a6 6 0 0 1 6 6v10" /></svg>
}
