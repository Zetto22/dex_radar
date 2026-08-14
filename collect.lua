-- Encounter collectors: Gen 1 (per-map grass/water + per-rod fishing) and
-- Gen 2 (kind-keyed grass/water + fishGroups via map.fishGroup, plus
-- headbutt trees, rock smash, Bug Contest, and live roamers).
-- Section shape is shared: { id, title, habitatRate?, tod?, todLabel?,
--   entries = { { species, minLv, maxLv, rate? } } }.
-- entry.rate is the species' share of that table (slot % / rod pool %).

local M = {}

local TODS = { "MORN", "DAY", "NITE" }

-- Fallback if src.battle.gen2.Encounter is unavailable (data/wild/probabilities.asm).
local GRASS_SLOT_PCT = { 30, 30, 20, 10, 5, 4, 1 }
local WATER_SLOT_PCT = { 60, 30, 10 }

local TOD_LABEL = {
  MORN = "M",
  DAY = "D",
  NITE = "N",
}

local function hasSlots(part)
  return type(part) == "table"
    and type(part.slots) == "table"
    and #part.slots > 0
end

local function fishingRods(mod)
  local fishing = mod.content.field:get("fishing")
  return type(fishing) == "table" and fishing or {}
end

local function superRodGroup(mod, mapId)
  local groups = mod.content.field:get("superRod")
  if type(groups) ~= "table" then return nil end
  local group = groups[mapId]
  if type(group) == "table" and #group > 0 then return group end
  return nil
end

local function appendEntry(order, seen, species, level)
  if type(species) ~= "string" or species == "" then return end
  local lv = tonumber(level) or 1
  local e = seen[species]
  if not e then
    e = { species = species, minLv = lv, maxLv = lv }
    seen[species] = e
    order[#order + 1] = e
  else
    if lv < e.minLv then e.minLv = lv end
    if lv > e.maxLv then e.maxLv = lv end
  end
end

local function appendEntryRange(order, seen, species, minLv, maxLv)
  if type(species) ~= "string" or species == "" then return end
  local lo = tonumber(minLv) or tonumber(maxLv) or 1
  local hi = tonumber(maxLv) or lo
  if hi < lo then lo, hi = hi, lo end
  local e = seen[species]
  if not e then
    e = { species = species, minLv = lo, maxLv = hi }
    seen[species] = e
    order[#order + 1] = e
  else
    if lo < e.minLv then e.minLv = lo end
    if hi > e.maxLv then e.maxLv = hi end
  end
end

-- Ordered unique entries with level ranges from slot rows.
local function entriesFromSlots(slots)
  local order, seen = {}, {}
  if type(slots) ~= "table" then return order end
  for _, slot in ipairs(slots) do
    if type(slot) == "table" then
      appendEntry(order, seen, slot.species, slot.level)
    end
  end
  return order
end

-- Gen 2 grass: union MORN/DAY/NITE into one species list (D3).
local function entriesFromTodSlots(slotsByTod)
  local order, seen = {}, {}
  if type(slotsByTod) ~= "table" then return order end
  for _, tod in ipairs(TODS) do
    local slots = slotsByTod[tod]
    if type(slots) == "table" then
      for _, slot in ipairs(slots) do
        if type(slot) == "table" then
          appendEntry(order, seen, slot.species, slot.level)
        end
      end
    end
  end
  return order
end

local function normalizeTod(tod)
  if tod == "DARK" then return "NITE" end
  if tod == "MORN" or tod == "DAY" or tod == "NITE" then return tod end
  return "DAY"
end

local function absoluteFromCumulative(cumulative)
  local abs, prev = {}, 0
  for i, c in ipairs(cumulative) do
    local n = tonumber(c) or prev
    abs[i] = n - prev
    prev = n
  end
  return abs
end

local function grassSlotPct()
  local ok, Enc = pcall(require, "src.battle.gen2.Encounter")
  if ok and Enc and type(Enc.GRASS_SLOT_CHANCES) == "table" then
    return absoluteFromCumulative(Enc.GRASS_SLOT_CHANCES)
  end
  return GRASS_SLOT_PCT
end

local function waterSlotPct()
  local ok, Enc = pcall(require, "src.battle.gen2.Encounter")
  if ok and Enc and type(Enc.WATER_SLOT_CHANCES) == "table" then
    return absoluteFromCumulative(Enc.WATER_SLOT_CHANCES)
  end
  return WATER_SLOT_PCT
end

-- Fallback Gen 1 encounterBuckets (FieldDefaults / constants.encounterBuckets).
local GEN1_BUCKETS = { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 }

local function gen1Buckets(mod, part)
  if type(part) == "table" and type(part.buckets) == "table" and #part.buckets > 0 then
    return part.buckets
  end
  if mod and mod.content and mod.content.constants and mod.content.constants.get then
    local c = mod.content.constants:get("encounterBuckets")
    if type(c) == "table" and #c > 0 then return c end
  end
  local ok, FD = pcall(require, "src.world.FieldDefaults")
  if ok and FD then
    if FD.CONSTANTS and type(FD.CONSTANTS.encounterBuckets) == "table" then
      return FD.CONSTANTS.encounterBuckets
    end
    if FD.constant then
      local c = FD.constant(nil, "encounterBuckets")
      if type(c) == "table" and #c > 0 then return c end
    end
  end
  return GEN1_BUCKETS
end

-- Absolute slot % out of 256, rounded to nearest (sums to 100 for vanilla).
local function gen1SlotPct(mod, part)
  local buckets = gen1Buckets(mod, part)
  local abs = absoluteFromCumulative(buckets)
  local out = {}
  for i, a in ipairs(abs) do
    out[i] = math.floor(100 * (a or 0) / 256 + 0.5)
  end
  return out
end

-- Sum slot percentages for each species in a flat slot list.
local function speciesRatesFromSlots(slots, slotPct)
  local rates = {}
  if type(slots) ~= "table" or type(slotPct) ~= "table" then return rates end
  for i, slot in ipairs(slots) do
    local pct = tonumber(slotPct[i])
    if pct and type(slot) == "table" and type(slot.species) == "string" then
      local sp = slot.species
      rates[sp] = (rates[sp] or 0) + pct
    end
  end
  return rates
end

local function applySpeciesRates(entries, ratesBySpecies)
  for _, e in ipairs(entries) do
    e.rate = ratesBySpecies[e.species] or 0
  end
end

local function grassRateForTod(row, tod)
  if type(row) ~= "table" or type(row.rates) ~= "table" then return nil end
  local key = normalizeTod(tod)
  local rate = row.rates[key] or row.rates.DAY
  return tonumber(rate)
end

-- Equal share among a fishing pool (Good/Super Rod bite → species pick).
local function equalPoolRates(slots)
  local rates, n = {}, 0
  if type(slots) ~= "table" then return rates end
  for _, slot in ipairs(slots) do
    if type(slot) == "table" and type(slot.species) == "string" then
      n = n + 1
    end
  end
  if n == 0 then return rates end
  local share = math.floor(100 / n + 0.5)
  local assigned = 0
  local last
  for _, slot in ipairs(slots) do
    if type(slot) == "table" and type(slot.species) == "string" then
      local sp = slot.species
      rates[sp] = (rates[sp] or 0) + share
      assigned = assigned + share
      last = sp
    end
  end
  -- Keep total at 100 when 100/n is not exact (e.g. 3-mon Super Rod).
  if last and assigned ~= 100 then
    rates[last] = rates[last] + (100 - assigned)
  end
  return rates
end

-- Gen 1 fishing: one section per rod so rates stay meaningful.
local function appendFishSection(sections, id, title, entries, rates)
  if not entries or #entries == 0 then return end
  applySpeciesRates(entries, rates or {})
  sections[#sections + 1] = {
    id = id,
    title = title,
    entries = entries,
  }
end

local function fishSectionsGen1(mod, mapId, enc)
  local waterOk = enc and hasSlots(enc.water)
  local superGroup = superRodGroup(mod, mapId)
  if not waterOk and not superGroup then return end

  local rods = fishingRods(mod)
  local out = {}

  local old = rods.OLD_ROD
  if type(old) == "table" and type(old.always) == "table" then
    local order, seen = {}, {}
    appendEntry(order, seen, old.always.species, old.always.level)
    local rates = {}
    if old.always.species then rates[old.always.species] = 100 end
    appendFishSection(out, "fish_old", "OLD ROD", order, rates)
  end

  local good = rods.GOOD_ROD
  if type(good) == "table" and type(good.pool) == "table" and #good.pool > 0 then
    local order = entriesFromSlots(good.pool)
    appendFishSection(
      out, "fish_good", "GOOD ROD", order, equalPoolRates(good.pool)
    )
  end

  if superGroup and #superGroup > 0 then
    local order = entriesFromSlots(superGroup)
    appendFishSection(
      out, "fish_super", "SUPER ROD", order, equalPoolRates(superGroup)
    )
  end

  if #out == 0 then return nil end
  return out
end

-- Gen 2 fishing lists: cumulative chance out of 256 (Encounter.fish).
local function fishEntriesFromRodList(list)
  local order, seen = {}, {}
  if type(list) ~= "table" then return order end
  for _, row in ipairs(list) do
    if type(row) == "table" then
      local sp = row.species
      if type(sp) == "string" and sp ~= "" and sp ~= "NO_ITEM" then
        appendEntry(order, seen, sp, row.level)
      end
    end
  end
  return order
end

local function fishRatesFromCumulative(list)
  local rates, prev = {}, 0
  if type(list) ~= "table" then return rates end
  for _, row in ipairs(list) do
    if type(row) == "table" then
      local c = tonumber(row.chance) or prev
      local abs = c - prev
      prev = c
      local sp = row.species
      if type(sp) == "string" and sp ~= "" and sp ~= "NO_ITEM" and abs > 0 then
        rates[sp] = (rates[sp] or 0) + abs
      end
    end
  end
  for sp, abs in pairs(rates) do
    rates[sp] = math.floor(100 * abs / 256 + 0.5)
  end
  return rates
end

local function fishSectionsGen2(group)
  if type(group) ~= "table" then return nil end
  local out = {}
  local rods = {
    { key = "old", id = "fish_old", title = "OLD ROD" },
    { key = "good", id = "fish_good", title = "GOOD ROD" },
    { key = "super", id = "fish_super", title = "SUPER ROD" },
  }
  for _, rod in ipairs(rods) do
    local list = group[rod.key]
    local entries = fishEntriesFromRodList(list)
    if #entries > 0 then
      appendFishSection(
        out, rod.id, rod.title, entries, fishRatesFromCumulative(list)
      )
    end
  end
  if #out == 0 then return nil end
  return out
end

-- Headbutt / Rock Smash lists: absolute chances out of 100 (Encounter.treeSlot).
-- ~10% of trees use the rare list (treeIsRare); the rest use common.
local TREE_RARE_PCT = 10

local function treeRowOk(row)
  if type(row) ~= "table" then return false end
  if type(row.species) ~= "string" or row.species == "" then return false end
  local c = tonumber(row.chance) or 0
  local lv = tonumber(row.level) or 0
  -- Corrupted extracts (ROCK rare) have chances >100 and absurd levels.
  return c > 0 and c <= 100 and lv >= 1 and lv <= 100
end

local function treeListValid(list)
  if type(list) ~= "table" or #list == 0 then return false end
  local sum = 0
  for _, row in ipairs(list) do
    if not treeRowOk(row) then return false end
    sum = sum + (tonumber(row.chance) or 0)
  end
  return sum >= 90 and sum <= 110
end

local function ratesFromAbsoluteTreeList(list)
  local rates = {}
  if type(list) ~= "table" then return rates end
  for _, row in ipairs(list) do
    if treeRowOk(row) then
      local sp = row.species
      rates[sp] = (rates[sp] or 0) + (tonumber(row.chance) or 0)
    end
  end
  return rates
end

local function entriesFromTreeLists(common, rare)
  local order, seen = {}, {}
  local function take(list)
    if type(list) ~= "table" then return end
    for _, row in ipairs(list) do
      if treeRowOk(row) then
        appendEntry(order, seen, row.species, row.level)
      end
    end
  end
  take(common)
  if treeListValid(rare) then take(rare) end
  return order
end

local function mergeTreeRates(common, rare)
  local cr = ratesFromAbsoluteTreeList(common)
  local useRare = treeListValid(rare)
  local rr = useRare and ratesFromAbsoluteTreeList(rare) or {}
  local rates = {}
  local function add(src, weight)
    for sp, pct in pairs(src) do
      rates[sp] = (rates[sp] or 0) + pct * weight / 100
    end
  end
  if useRare then
    add(cr, 100 - TREE_RARE_PCT)
    add(rr, TREE_RARE_PCT)
  else
    add(cr, 100)
  end
  for sp, v in pairs(rates) do
    rates[sp] = math.floor(v + 0.5)
  end
  return rates
end

local function treeSetFor(mod, kind, mapId)
  local byMap = mod.content.encounters:get(kind)
  if type(byMap) ~= "table" then return nil end
  local setName = byMap[mapId]
  if type(setName) ~= "string" or setName == "" then return nil end
  if setName == "TREEMON_SET_NONE" then return nil end
  local sets = mod.content.encounters:get("treeSets")
  local set = type(sets) == "table" and sets[setName] or nil
  if type(set) ~= "table" then return nil end
  return set
end

local function appendTreeSection(sections, id, title, set)
  if type(set) ~= "table" then return end
  local entries = entriesFromTreeLists(set.common, set.rare)
  if #entries == 0 then return end
  applySpeciesRates(entries, mergeTreeRates(set.common, set.rare))
  sections[#sections + 1] = {
    id = id,
    title = title,
    entries = entries,
  }
end

-- Bug Contest pool (National Park); chance 255 is the table sentinel.
local function bugContestSection(mod, mapId)
  if mapId ~= "NATIONAL_PARK" and mapId ~= "NATIONAL_PARK_BUG_CONTEST" then
    return nil
  end
  local list = mod.content.encounters:get("bugContest")
  if type(list) ~= "table" then return nil end
  local order, seen, rates = {}, {}, {}
  for _, row in ipairs(list) do
    if type(row) == "table" then
      local c = tonumber(row.chance) or 0
      if c > 0 and c < 255 and type(row.species) == "string" then
        appendEntryRange(order, seen, row.species, row.min, row.max)
        rates[row.species] = (rates[row.species] or 0) + c
      end
    end
  end
  if #order == 0 then return nil end
  applySpeciesRates(order, rates)
  return {
    id = "contest",
    title = "CONTEST",
    entries = order,
  }
end

-- Roamers currently standing on this map (save.roamers after Burned Tower).
local function roamersSection(mapId, game)
  local save = game and game.save
  local list = save and save.roamers
  if type(list) ~= "table" then return nil end
  local order, seen = {}, {}
  for _, slot in ipairs(list) do
    if type(slot) == "table"
      and type(slot.species) == "string"
      and slot.map == mapId
    then
      appendEntry(order, seen, slot.species, slot.level or 40)
    end
  end
  if #order == 0 then return nil end
  return {
    id = "roamers",
    title = "ROAMERS",
    entries = order,
  }
end

function M.collectGen1(mod, mapId)
  local sections = {}
  if type(mapId) ~= "string" or mapId == "" then
    return sections
  end

  local enc = mod.content.encounters:get(mapId)

  if enc and hasSlots(enc.grass) then
    local entries = entriesFromSlots(enc.grass.slots)
    applySpeciesRates(
      entries, speciesRatesFromSlots(enc.grass.slots, gen1SlotPct(mod, enc.grass))
    )
    sections[#sections + 1] = {
      id = "grass",
      title = "GRASS",
      habitatRate = tonumber(enc.grass.rate),
      entries = entries,
    }
  end

  if enc and hasSlots(enc.water) then
    local entries = entriesFromSlots(enc.water.slots)
    applySpeciesRates(
      entries, speciesRatesFromSlots(enc.water.slots, gen1SlotPct(mod, enc.water))
    )
    sections[#sections + 1] = {
      id = "water",
      title = "WATER",
      habitatRate = tonumber(enc.water.rate),
      entries = entries,
    }
  end

  local fish = fishSectionsGen1(mod, mapId, enc)
  if fish then
    for _, section in ipairs(fish) do
      sections[#sections + 1] = section
    end
  end

  return sections
end

function M.collectGen2(mod, mapId, tod, game)
  local sections = {}
  if type(mapId) ~= "string" or mapId == "" then
    return sections
  end

  local todKey = normalizeTod(tod)
  local todLabel = TOD_LABEL[todKey] or todKey

  local grassKind = mod.content.encounters:get("grass")
  local grassRow = type(grassKind) == "table" and grassKind[mapId] or nil
  if type(grassRow) == "table" and type(grassRow.slots) == "table" then
    local entries = entriesFromTodSlots(grassRow.slots)
    if #entries > 0 then
      local slotsNow = grassRow.slots[todKey] or grassRow.slots.DAY
      applySpeciesRates(entries, speciesRatesFromSlots(slotsNow, grassSlotPct()))
      sections[#sections + 1] = {
        id = "grass",
        title = "GRASS",
        -- Habitat encounter chance (out of 256); kept for exports / debug.
        habitatRate = grassRateForTod(grassRow, todKey),
        tod = todKey,
        todLabel = todLabel,
        entries = entries,
      }
    end
  end

  local waterKind = mod.content.encounters:get("water")
  local waterRow = type(waterKind) == "table" and waterKind[mapId] or nil
  local waterOk = type(waterRow) == "table"
    and type(waterRow.slots) == "table"
    and #waterRow.slots > 0
  if waterOk then
    local entries = entriesFromSlots(waterRow.slots)
    applySpeciesRates(entries, speciesRatesFromSlots(waterRow.slots, waterSlotPct()))
    sections[#sections + 1] = {
      id = "water",
      title = "WATER",
      habitatRate = tonumber(waterRow.rate),
      -- Water tables are not ToD-split; omit todLabel so rates stay "RATE 60".
      entries = entries,
    }
  end

  local map = mod.content.maps:get(mapId)
  -- Gold map headers stamp FISHGROUP_SHORE on almost everything (Poké Centers
  -- included). Only list fish when the map has water encounters, or a
  -- non-default fish group (Dratini / Whirl / Lake / …). Never on indoor/gate.
  local groupId = nil
  local env = map and map.environment
  local indoor = env == "INDOOR" or env == "GATE"
  if not indoor then
    groupId = map and map.fishGroup
    if groupId == "" or groupId == "FISHGROUP_NONE" then
      groupId = nil
    end
    if not groupId and waterOk then
      groupId = "FISHGROUP_POND"
    elseif groupId == "FISHGROUP_SHORE" and not waterOk then
      groupId = nil
    end
  end
  if groupId then
    local groups = mod.content.encounters:get("fishGroups")
    local group = type(groups) == "table" and groups[groupId] or nil
    local fish = fishSectionsGen2(group)
    if fish then
      for _, section in ipairs(fish) do
        sections[#sections + 1] = section
      end
    end
  end

  appendTreeSection(sections, "headbutt", "HEADBUTT", treeSetFor(mod, "trees", mapId))
  appendTreeSection(sections, "rock", "ROCK", treeSetFor(mod, "rocks", mapId))

  local contest = bugContestSection(mod, mapId)
  if contest then
    sections[#sections + 1] = contest
  end

  local roamers = roamersSection(mapId, game)
  if roamers then
    sections[#sections + 1] = roamers
  end

  return sections
end

local function generation(game)
  if type(game) == "table" and type(game.generation) == "number" then
    return game.generation
  end
  -- Game2 does not always expose .generation; Gold's field world is
  -- game.world (not a stack OverworldState like Gen 1's game.overworld).
  if type(game) == "table" and game.world ~= nil and game.overworld == nil then
    return 2
  end
  return 1
end

function M.generation(game)
  return generation(game)
end

function M.normalizeTod(tod)
  return normalizeTod(tod)
end

function M.todLabel(tod)
  local key = normalizeTod(tod)
  return TOD_LABEL[key] or key
end

--- @param tod optional "MORN"|"DAY"|"NITE"|"DARK" (Gen 2 grass slots / rates)
function M.collect(mod, mapId, game, tod)
  if generation(game) == 2 then
    local clock = tod
    if clock == nil and game and game.world then
      clock = game.world.daytime
    end
    return M.collectGen2(mod, mapId, clock, game)
  end
  return M.collectGen1(mod, mapId)
end

function M.isSeen(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.seen and dex.seen[speciesId] and true or false
end

-- Gen 1 stores owned; Gen 2 stores caught.
function M.isOwned(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  if not dex then return false end
  if dex.owned and dex.owned[speciesId] then return true end
  if dex.caught and dex.caught[speciesId] then return true end
  return false
end

return M
