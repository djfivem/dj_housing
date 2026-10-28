Housing = Housing or {}
Housing.Config = Housing.Config or {}

Housing.Config.Permissions = {
    allowCoOwner = true,
    coOwnerCanSell = false,
    coOwnerCanIssueKeys = true,
    residentsCanInviteGuests = false,
    requirePhysicalKeyForEntry = false,
    requirePhysicalKeyForStash = false,
    guestsRequireKey = true,
    maxOwned = 3,
    maxKeysPerProperty = 12,
    adminAce = 'housing.admin',
    policeAce = 'housing.police',
    -- Owners and residents may enter from the access record. Guests need a key item or an unexpired guest grant.
    ownerBypassKey = true,
}
