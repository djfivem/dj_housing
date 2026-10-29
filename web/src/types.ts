export type Coords = { x: number; y: number; z: number; w?: number }

export type PropertyCard = {
  id: string
  label: string
  description: string
  propertyType: string
  purchasePrice: number
  rentalPrice: number
  rentalPeriodHours: number
  image: string
  imageUrl?: string | null
  zone?: { points: Array<{ x: number; y: number }>; minZ?: number; maxZ?: number } | null
  bedrooms: number
  bathrooms: number
  garages: number
  status: string
  listed: boolean
  listingPrice?: number | null
  enabled: boolean
  owned: boolean
  ownerName?: string | null
  rented: boolean
  tenantName?: string | null
  entrance?: Coords
  role?: string | null
  shellModel?: string | null
  shellOptions?: string[] | null
}

export type StashInfo = {
  key: string
  label: string
  stashType: string
  accessLevel: string
  slots: number
  maxWeight: number
}

export type Bill = {
  id: string
  property_id: string
  bill_type: string
  label: string
  amount: number
  status: string
  due_at: number
}

export type AccessRow = {
  characterId: string
  framework: string
  displayName: string
  role: string
  revoked: boolean
  expiresAt?: number | null
}

export type KeyRow = {
  id: string
  accessLevel: string
  state: string
  holderName: string
}

export type FurnitureRow = {
  id: string
  catalog_id: string
  label: string
  state: string
  model: string
}

export type UpgradeRow = { upgrade_id: string }

export type VehicleRow = {
  id: string
  plate: string
  model_hash: number
  state: string
}

export type CatalogFurniture = {
  id: string
  label: string
  category: string
  price: number
  model: string
}

export type CatalogUpgrade = {
  id: string
  label: string
  description: string
  price: number
}

export type ShellDef = { label: string; model: string }

export type Dashboard = {
  player: { name: string; characterId: string; framework: string }
  balance: number
  counts: { owned: number; rented: number; pendingBills: number }
  properties: PropertyCard[]
  mine: string[]
  selected?: PropertyCard | null
  bills: Bill[]
  access: AccessRow[]
  keys: KeyRow[]
  furniture: FurnitureRow[]
  upgrades: UpgradeRow[]
  vehicles: VehicleRow[]
  stashes: StashInfo[]
  catalog: {
    furniture: CatalogFurniture[]
    upgrades: CatalogUpgrade[]
    shells: Record<string, ShellDef>
  }
  police: boolean
  admin: boolean
  rules?: { saleReturnPercent: number; minListingPrice: number }
  utilities?: { weekId: number; rates: { water?: number; electricity?: number; garbage?: number } }
  warrants?: Array<Record<string, unknown>>
  raids?: Array<Record<string, unknown>>
  evidence?: Array<Record<string, unknown>>
  audit?: Array<Record<string, unknown>>
  pending?: Array<Record<string, unknown>>
}

export type ApiResult<T = Record<string, unknown>> = {
  ok: boolean
  error?: string
  detail?: unknown
  data?: T
}
