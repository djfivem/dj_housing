import type { Dashboard, PropertyCard } from '../types'

const now = Math.floor(Date.now() / 1000)

const properties: PropertyCard[] = [
  {
    id: 'vinewood_hills_mansion',
    label: 'Vinewood Hills Mansion',
    description: 'Modern luxury mansion with a pool, garage, and viewing deck. Perfect for anyone looking for premium living.',
    propertyType: 'shell',
    purchasePrice: 2500000,
    rentalPrice: 25000,
    rentalPeriodHours: 168,
    image: 'mansion',
    bedrooms: 6,
    bathrooms: 6,
    garages: 4,
    status: 'owned',
    listed: false,
    enabled: true,
    owned: true,
    ownerName: 'Diesel',
    rented: false,
    entrance: { x: -174.35, y: 497.88, z: 137.65, w: 191 },
    role: 'owner',
    shellModel: 'shell_michael',
    shellOptions: ['shell_michael', 'shell_ranch'],
  },
  {
    id: 'del_perro_apartment',
    label: 'Del Perro Apartment',
    description: 'High-rise apartment over Del Perro. Uses a base-game apartment IPL.',
    propertyType: 'ipl',
    purchasePrice: 330000,
    rentalPrice: 4500,
    rentalPeriodHours: 168,
    image: 'apartment',
    bedrooms: 2,
    bathrooms: 1,
    garages: 1,
    status: 'rented',
    listed: false,
    enabled: true,
    owned: false,
    rented: true,
    tenantName: 'Diesel',
    entrance: { x: -773.88, y: 312.08, z: 85.7, w: 180 },
    role: 'tenant',
  },
  {
    id: 'sandy_shores_trailer',
    label: 'Sandy Shores Trailer',
    description: 'Compact trailer on the east side of Sandy Shores.',
    propertyType: 'shell',
    purchasePrice: 180000,
    rentalPrice: 1800,
    rentalPeriodHours: 168,
    image: 'trailer',
    bedrooms: 1,
    bathrooms: 1,
    garages: 1,
    status: 'owned',
    listed: false,
    enabled: true,
    owned: true,
    ownerName: 'Diesel',
    rented: false,
    entrance: { x: 1975.52, y: 3818.22, z: 33.44, w: 30 },
    role: 'owner',
    shellModel: 'shell_trailer',
  },
  {
    id: 'mirror_park_house',
    label: 'Mirror Park House',
    description: 'Existing Mirror Park house. Entry uses the configured door and interior. No shell is spawned.',
    propertyType: 'mlo',
    purchasePrice: 650000,
    rentalPrice: 7000,
    rentalPeriodHours: 168,
    image: 'house',
    bedrooms: 3,
    bathrooms: 2,
    garages: 2,
    status: 'available',
    listed: false,
    enabled: true,
    owned: false,
    rented: false,
    entrance: { x: 1229.68, y: -725.36, z: 60.96, w: 110 },
    role: null,
  },
]

let balance = 482750
let bills = [
  { id: 'bill-tax', property_id: 'vinewood_hills_mansion', bill_type: 'property_tax', label: 'Property Tax', amount: 1250, status: 'due', due_at: now + 86400 },
  { id: 'bill-water', property_id: 'vinewood_hills_mansion', bill_type: 'water', label: 'Water Bill', amount: 150, status: 'due', due_at: now + 2 * 86400 },
  { id: 'bill-power', property_id: 'vinewood_hills_mansion', bill_type: 'electricity', label: 'Power', amount: 220, status: 'due', due_at: now + 5 * 86400 },
  { id: 'bill-garbage', property_id: 'vinewood_hills_mansion', bill_type: 'garbage', label: 'Garbage', amount: 90, status: 'due', due_at: now + 5 * 86400 },
  { id: 'bill-rent', property_id: 'del_perro_apartment', bill_type: 'rent', label: 'Rent', amount: 750, status: 'due', due_at: now + 8 * 86400 },
]
const upgrades = new Set<string>()
const furniture: Dashboard['furniture'] = []
const access = [
  { characterId: 'license:diesel', framework: 'standalone', displayName: 'Diesel (Owner)', role: 'owner', revoked: false },
  { characterId: 'license:lala', framework: 'standalone', displayName: 'La-La', role: 'resident', revoked: false },
  { characterId: 'license:ghost', framework: 'standalone', displayName: 'Ghost', role: 'resident', revoked: false },
  { characterId: 'license:bubba', framework: 'standalone', displayName: 'Bubba', role: 'guest', revoked: false },
]
const keys = [
  { id: 'key-owner-1', accessLevel: 'owner', state: 'active', holderName: 'license:diesel' },
]
const vehicles = [
  { id: 'veh-1', plate: '10F239', model_hash: 1, state: 'stored', propertyId: 'vinewood_hills_mansion' },
  { id: 'veh-2', plate: 'PGT220', model_hash: 2, state: 'stored', propertyId: 'vinewood_hills_mansion' },
]
const furniturePrices: Record<string, number> = {
  sofa_modern: 2500,
  tv_stand: 1200,
  bed_double: 2000,
  dining_table: 1800,
  chair_wood: 450,
  dresser: 1300,
}
const seen = new Set<string>()

function counts() {
  return {
    owned: properties.filter((property) => property.role === 'owner').length,
    rented: properties.filter((property) => property.role === 'tenant').length,
    pendingBills: bills.filter((bill) => bill.status === 'due' && properties.some((property) => property.id === bill.property_id && property.role)).length,
  }
}

function dashboard(propertyId?: string): Dashboard {
  const selected = properties.find((property) => property.id === propertyId) ?? properties.find((property) => property.role === 'owner') ?? null
  const mine = selected && (selected.role === 'owner' || selected.role === 'tenant' || selected.role === 'coowner')
  return {
    player: { name: 'Diesel', characterId: 'license:diesel', framework: 'standalone' },
    balance,
    counts: counts(),
    properties,
    mine: properties.filter((property) => property.role).map((property) => property.id),
    selected,
    bills: mine && selected ? bills.filter((bill) => bill.property_id === selected.id) : [],
    access: mine && selected ? access : [],
    keys: mine && selected ? keys.filter((key) => key.state !== 'hidden') : [],
    furniture: mine && selected ? furniture.filter((row) => row.id.startsWith(selected.id)) : [],
    upgrades: mine && selected ? [...upgrades].filter((id) => id.startsWith(selected.id)).map((id) => ({ upgrade_id: id.split(':')[1] })) : [],
    vehicles: mine && selected ? vehicles.filter((vehicle) => vehicle.propertyId === selected.id).map((vehicle) => ({ ...vehicle })) : [],
    stashes: [
      { key: 'shared', label: 'Household Storage', stashType: 'shared', accessLevel: 'resident', slots: 50, maxWeight: 150000 },
      { key: 'personal', label: 'Personal Locker', stashType: 'personal', accessLevel: 'resident', slots: 20, maxWeight: 40000 },
    ],
    catalog: {
      furniture: [
        { id: 'sofa_modern', label: 'Sofa', category: 'living', price: 2500, model: 'v_res_tre_sofa_s' },
        { id: 'tv_stand', label: 'TV Stand', category: 'living', price: 1200, model: 'prop_tv_cabinet_03' },
        { id: 'bed_double', label: 'Bed', category: 'bedroom', price: 2000, model: 'v_res_msonbed' },
        { id: 'dining_table', label: 'Dining Table', category: 'kitchen', price: 1800, model: 'v_res_fh_diningtable' },
        { id: 'chair_wood', label: 'Chair', category: 'kitchen', price: 450, model: 'v_res_fh_kitnstool' },
        { id: 'dresser', label: 'Dresser', category: 'bedroom', price: 1300, model: 'v_res_mddresser' },
      ],
      upgrades: [
        { id: 'security', label: 'Security System', description: 'Raises an alarm when a raid starts.', price: 75000 },
        { id: 'garage_expansion', label: 'Custom Garage', description: 'Adds two garage slots.', price: 150000 },
        { id: 'stash_expansion', label: 'Yard Upgrade', description: 'Adds shared stash capacity.', price: 100000 },
        { id: 'interior_finish', label: 'Interior Upgrade', description: 'Premium interior finish.', price: 250000 },
      ],
      shells: {
        shell_michael: { label: 'Mansion Shell', model: 'shell_michael' },
        shell_ranch: { label: 'Ranch Shell', model: 'shell_ranch' },
        shell_v16mid: { label: 'Vinewood House Shell', model: 'shell_v16mid' },
        shell_trailer: { label: 'Trailer Shell', model: 'shell_trailer' },
      },
    },
    police: deskMode() === 'police' || deskMode() === 'both',
    admin: deskMode() === 'admin' || deskMode() === 'both',
    rules: { saleReturnPercent: 60, minListingPrice: 1000 },
    utilities: { weekId: 2810, rates: { water: 150, electricity: 220, garbage: 90 } },
    warrants: deskMode() === 'police' || deskMode() === 'both' ? warrants : [],
    raids: deskMode() === 'police' || deskMode() === 'both' ? raids : [],
    evidence: deskMode() === 'police' || deskMode() === 'both' ? evidence : [],
    audit: deskMode() === 'admin' || deskMode() === 'both' ? audit : [],
    pending: [],
  }
}

function deskMode() {
  if (typeof location === 'undefined') return ''
  return new URLSearchParams(location.search).get('desk') ?? ''
}

const warrants: Array<Record<string, unknown>> = [
  { id: 'warrant-seeded', status: 'authorised', reason_text: 'Seeded authorised warrant', case_reference: 'CASE-1001', allow_seizure: 1, property_id: 'vinewood_hills_mansion' },
]
const raids: Array<Record<string, unknown>> = []
const evidence: Array<Record<string, unknown>> = []
const audit: Array<Record<string, unknown>> = []

function fail(error: string) {
  return { ok: false, error }
}

export async function handle(event: string, data?: unknown) {
  const payload = (data ?? {}) as Record<string, unknown>
  if (event === 'dashboard') {
    return { ok: true, data: dashboard(typeof payload.propertyId === 'string' ? payload.propertyId : undefined) }
  }
  if (event === 'close') return { ok: true }
  const key = String(payload.idempotencyKey ?? '')
  if (['purchase', 'rent', 'payBill', 'buyFurniture', 'buyUpgrade', 'issueKey'].includes(event)) {
    if (seen.has(key)) return { ok: true, data: { replay: true } }
  }
  if (event === 'purchase' || event === 'rent') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || property.status !== 'available') return fail('property_unavailable')
    const price = event === 'rent' ? property.rentalPrice : property.purchasePrice
    if (payload.expectedPrice !== undefined && payload.expectedPrice !== price) return fail('price_mismatch')
    if (balance < price) return fail('insufficient_funds')
    balance -= price
    property.status = event === 'rent' ? 'rented' : 'owned'
    property.role = event === 'rent' ? 'tenant' : 'owner'
    property.owned = event === 'purchase'
    property.rented = event === 'rent'
    property.ownerName = event === 'purchase' ? 'Diesel' : null
    property.tenantName = event === 'rent' ? 'Diesel' : null
    seen.add(key)
    return { ok: true, data: { propertyId: property.id, price } }
  }
  if (event === 'payBill' || event === 'payAll') {
    const due = bills.filter((bill) => bill.status === 'due' && (event === 'payAll' ? bill.property_id === payload.propertyId : bill.id === payload.billId))
    const total = due.reduce((sum, bill) => sum + bill.amount, 0)
    if (balance < total) return fail('insufficient_funds')
    balance -= total
    due.forEach((bill) => { bill.status = 'paid' })
    return { ok: true, data: { amount: total, paid: total } }
  }
  if (event === 'buyFurniture') {
    const price = furniturePrices[String(payload.catalogId)] ?? 0
    if (price <= 0) return fail('not_found')
    if (balance < price) return fail('insufficient_funds')
    balance -= price
    const labels: Record<string, string> = { sofa_modern: 'Sofa', tv_stand: 'TV Stand', bed_double: 'Bed', dining_table: 'Dining Table', chair_wood: 'Chair', dresser: 'Dresser' }
    furniture.push({ id: `${payload.propertyId}:${key}`, catalog_id: String(payload.catalogId), label: labels[String(payload.catalogId)] ?? 'Furniture', state: 'stored', model: 'prop' })
    seen.add(key)
    return { ok: true, data: { furnitureId: key } }
  }
  if (event === 'buyUpgrade') {
    const id = `${payload.propertyId}:${payload.upgradeId}`
    if (upgrades.has(id)) return fail('already_owned')
    const price = payload.upgradeId === 'security' ? 75000 : payload.upgradeId === 'garage_expansion' ? 150000 : payload.upgradeId === 'stash_expansion' ? 100000 : 250000
    if (balance < price) return fail('insufficient_funds')
    balance -= price
    upgrades.add(id)
    return { ok: true, data: { upgradeId: payload.upgradeId } }
  }
  if (event === 'sell') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || property.role !== 'owner') return fail('not_authorised')
    const price = Math.floor(property.purchasePrice * 0.6)
    if (payload.expectedPrice !== undefined && payload.expectedPrice !== price) return fail('price_mismatch')
    balance += price
    property.status = 'available'
    property.role = null
    property.owned = false
    property.ownerName = null
    return { ok: true, data: { price } }
  }
  if (event === 'requestWarrant') {
    if (deskMode() !== 'police' && deskMode() !== 'both') return fail('not_authorised')
    warrants.unshift({
      id: String(payload.idempotencyKey),
      status: 'requested',
      reason_text: payload.reason,
      case_reference: payload.caseReference,
      allow_seizure: payload.allowSeizure ? 1 : 0,
      property_id: payload.propertyId,
      requester_character_id: 'license:diesel',
    })
    return { ok: true, data: { warrantId: payload.idempotencyKey, status: 'requested' } }
  }
  if (event === 'decideWarrant') {
    const warrant = warrants.find((row) => row.id === payload.warrantId)
    if (!warrant) return fail('not_found')
    if (payload.decision === 'authorise' && warrant.status !== 'requested') return fail('warrant_state')
    if (payload.decision === 'authorise' && warrant.requester_character_id === 'license:diesel') return fail('self_approval')
    warrant.status = payload.decision === 'authorise' ? 'authorised' : 'revoked'
    return { ok: true, data: { warrantId: warrant.id, status: warrant.status } }
  }
  if (event === 'openRaid') {
    const warrant = warrants.find((row) => row.id === payload.warrantId && row.status === 'authorised')
    if (!warrant) return fail('warrant_invalid')
    const id = String(payload.idempotencyKey)
    raids.unshift({ id, state: 'requested', warrant_id: warrant.id, property_id: payload.propertyId, allow_seizure: warrant.allow_seizure })
    return { ok: true, data: { raidId: id, state: 'requested', warrantId: warrant.id } }
  }
  if (event === 'setRaidState') {
    const raid = raids.find((row) => row.id === payload.raidId)
    if (!raid) return fail('not_found')
    const allowed: Record<string, string[]> = { requested: ['authorised', 'cancelled', 'expired'], authorised: ['active', 'cancelled', 'expired'], active: ['completed', 'cancelled', 'expired'] }
    const next = allowed[String(raid.state)] ?? []
    if (!next.includes(String(payload.state))) return fail('raid_state')
    raid.state = payload.state
    return { ok: true, data: { raidId: raid.id, state: raid.state } }
  }
  if (event === 'inspectStash') {
    const raid = raids.find((row) => row.property_id === payload.propertyId && row.state === 'active')
    if (!raid) return fail('raid_state')
    return { ok: true, data: { mode: 'ledger', items: [{ name: 'phone', label: 'Phone', count: 1, slot: 1 }] } }
  }
  if (event === 'seize') {
    const raid = raids.find((row) => row.id === payload.raidId && row.state === 'active')
    if (!raid || raid.allow_seizure !== 1) return fail('seizure_not_authorised')
    if (payload.itemName === 'housing_key') return fail('seizure_not_authorised')
    evidence.unshift({ id: payload.idempotencyKey, item_name: payload.itemName, quantity: payload.quantity, status: 'seized', case_reference: 'CASE-1001' })
    return { ok: true, data: { evidenceId: payload.idempotencyKey, status: 'seized' } }
  }
  if (event === 'transferEvidence') {
    const row = evidence.find((item) => item.id === payload.evidenceId)
    if (!row || row.status !== 'seized') return fail('not_found')
    row.status = payload.status
    return { ok: true, data: { evidenceId: row.id, status: row.status } }
  }
  if (event === 'adminEnable' || event === 'adminRepair' || event === 'adminArchive' || event === 'adminTransfer' || event === 'collectPayouts') {
    if (deskMode() !== 'admin' && deskMode() !== 'both') return fail('not_authorised')
    const property = properties.find((item) => item.id === payload.propertyId)
    if (event === 'adminEnable' && property) property.enabled = payload.enabled === true
    if (event === 'adminArchive') {
      if (!property) return fail('property_not_found')
      if (property.owned && payload.force !== true) return fail('owned')
      property.status = 'archived'
      property.enabled = false
    }
    if (event === 'adminTransfer' && property) {
      property.status = 'owned'
      property.role = 'owner'
      property.ownerName = `Player ${payload.targetSource}`
    }
    audit.unshift({ id: String(payload.idempotencyKey ?? event), action_name: event, category: 'admin' })
    return { ok: true, data: {} }
  }
  if (event === 'renew') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || property.role !== 'tenant') return fail('not_authorised')
    if (payload.mode !== 'renew') return fail('invalid_payload')
    if (payload.expectedPrice !== undefined && payload.expectedPrice !== property.rentalPrice) return fail('price_mismatch')
    if (balance < property.rentalPrice) return fail('insufficient_funds')
    balance -= property.rentalPrice
    return { ok: true, data: { price: property.rentalPrice } }
  }
  if (event === 'list') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || property.role !== 'owner') return fail('not_authorised')
    const price = Number(payload.price)
    if (!Number.isFinite(price) || price < 1000) return fail('invalid_price')
    property.listed = true
    property.listingPrice = price
    return { ok: true, data: { price } }
  }
  if (event === 'unlist') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || property.role !== 'owner') return fail('not_authorised')
    property.listed = false
    property.listingPrice = null
    return { ok: true, data: {} }
  }
  if (event === 'grantAccess') {
    access.push({
      characterId: String(payload.targetCharacterId),
      framework: String(payload.targetFramework),
      displayName: String(payload.displayName || payload.targetCharacterId),
      role: String(payload.role),
      revoked: false,
    })
    return { ok: true, data: {} }
  }
  if (event === 'revokeAccess') {
    const row = access.find((item) => item.characterId === payload.targetCharacterId)
    if (!row || row.role === 'owner') return fail('not_authorised')
    row.revoked = true
    return { ok: true, data: {} }
  }
  if (event === 'revokePropertyKeys') {
    keys.forEach((row) => {
      if (row.accessLevel !== 'owner') row.state = 'revoked'
    })
    return { ok: true, data: { count: keys.length } }
  }
  if (event === 'enter') {
    return { ok: true, data: { propertyId: payload.propertyId, propertyType: 'shell', bucket: 12 } }
  }
  if (event === 'exit') return { ok: true, data: { returnCoords: { x: 0, y: 0, z: 0, w: 0 } } }
  if (event === 'openStash') return { ok: true, data: { stashId: `ah:${payload.propertyId}:${payload.stashKey}` } }
  if (event === 'issueKey') {
    keys.push({ id: key, accessLevel: String(payload.accessLevel ?? 'guest'), state: 'active', holderName: 'license:guest' })
    seen.add(key)
    return { ok: true, data: { keyId: key } }
  }
  if (event === 'revokeKey') {
    const row = keys.find((item) => item.id === payload.keyId)
    if (row) row.state = 'revoked'
    return { ok: true, data: {} }
  }
  if (event === 'storeVehicle' || event === 'takeVehicle') {
    const vehicle = vehicles.find((item) => item.id === payload.vehicleId)
    if (!vehicle || vehicle.propertyId !== payload.propertyId) return fail('not_found')
    if (event === 'takeVehicle' && vehicle.state !== 'stored') return fail('not_stored')
    if (event === 'storeVehicle' && vehicle.state !== 'out') return fail('not_out')
    vehicle.state = event === 'takeVehicle' ? 'out' : 'stored'
    return { ok: true, data: { vehicleId: vehicle.id, plate: vehicle.plate, modelHash: vehicle.model_hash, state: vehicle.state } }
  }
  if (event === 'setPropertyImage') {
    const url = String(payload.imageUrl ?? '')
    const allowed = url.startsWith('https://r2.fivemanage.com/') || url.startsWith('https://fivemanage.com/') || url.startsWith('https://fmapi.net/') || url.includes('.fivemanage.com/')
    if (!allowed) return fail('image_host')
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property || (property.role !== 'owner' && deskMode() !== 'admin' && deskMode() !== 'both')) return fail('not_authorised')
    property.image = url
    return { ok: true, data: { imageUrl: url } }
  }
  if (event === 'prepareImageUpload') {
    return { ok: true, data: { url: 'https://fmapi.net/api/presigned/mock' } }
  }
  if (event === 'captureImage') {
    const property = properties.find((item) => item.id === payload.propertyId)
    if (!property) return fail('property_not_found')
    property.image = 'https://r2.fivemanage.com/images/house-preview.jpg'
    return { ok: true, data: { imageUrl: property.image } }
  }
  return fail('unsupported')
}
