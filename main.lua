-- Dex Radar: wild species on the current map (grass / water / fishing).
-- Compact party-icon list of wild species on the current map.
-- Gen 1 + Gen 2 collectors live in collect.lua (same section shape).

local SCREEN = "DexRadar"

local ROW_H = 28
local HEADER_H = 12
local VISIBLE_MONS = 3
-- Gen 2 menu font is taller than the 8px cell; y=6 clipped under the box rim.
local TITLE_Y = 8
local MAP_Y = 16
local LIST_TOP = 30
-- Viewport fits one section header + VISIBLE_MONS rows (no partial clip).
local LIST_BOTTOM = LIST_TOP + HEADER_H + VISIBLE_MONS * ROW_H
local ICON = 16
-- Map label window: the header starts at x=8 and the box's 8px padding
-- convention clips at the inner right edge 152, so 144px = 18 glyphs.
-- Labels wider than that scroll instead of truncating.
local MAP_LABEL_X = 8
local MAP_LABEL_W = 152 - MAP_LABEL_X
-- Ticker pacing (the QoL Toggles label ticker's): hold at each end so the
-- player can read the whole label, scroll at 16px/s (half a second per
-- glyph).
local TICKER_HOLD = 1.6
local TICKER_SPEED = 16
-- Hold-to-scroll (same cadence as engine ListMenu at 1X).
local REPEAT_DELAY = 16
local REPEAT_RATE = 4

local HOTKEY_CHOICES = {
  { "R", "r" }, { "F", "f" }, { "G", "g" }, { "H", "h" },
  { "T", "t" }, { "Y", "y" }, { "U", "u" }, { "I", "i" },
  { "O", "o" }, { "P", "p" }, { "C", "c" }, { "V", "v" },
  { "N", "n" }, { "M", "m" }, { "Q", "q" }, { "E", "e" },
  { "OFF", "off" },
}

-- GAME SPEED multiplies logic steps; menus only move on wasPressed edges, so
-- they feel 1X. Scale our hold-repeat / ticker by the same multiplier.
local function logicSpeed(game)
  if game and type(game.logicSpeed) == "function" then
    local ok, speed = pcall(game.logicSpeed, game)
    if ok and tonumber(speed) then
      return math.max(1, tonumber(speed))
    end
  end
  local opts = (game and game.save and game.save.options)
    or (game and game.options)
  local raw = (game and game.speedOverride) or (opts and opts.speed) or 1
  return math.max(1, tonumber(raw) or 1)
end

-- Scissor is in window pixels and ignores the current transform. Gen 2 draws
-- the stack inside translate+scale (letterbox), so GB-space rects must be
-- mapped through transformPoint or the list clips to the wrong corner.
local function withScissor(x, y, w, h, fn)
  local g = love and love.graphics
  if not (g and g.setScissor) then
    fn()
    return
  end
  local px, py, pw, ph = g.getScissor()
  local x1, y1, x2, y2
  if g.transformPoint then
    x1, y1 = g.transformPoint(x, y)
    x2, y2 = g.transformPoint(x + w, y + h)
  else
    x1, y1, x2, y2 = x, y, x + w, y + h
  end
  local sx = math.floor(math.min(x1, x2) + 0.5)
  local sy = math.floor(math.min(y1, y2) + 0.5)
  local sw = math.max(0, math.ceil(math.abs(x2 - x1) - 1e-6))
  local sh = math.max(0, math.ceil(math.abs(y2 - y1) - 1e-6))
  g.setScissor(sx, sy, sw, sh)
  local ok, err = pcall(fn)
  if px then
    g.setScissor(px, py, pw, ph)
  else
    g.setScissor()
  end
  if not ok then
    error(err)
  end
end

-- Gen 1: top stack state is the OverworldController (isOverworld).
-- Gen 2: the field world is game.world (not stacked); ready when no UI is up.
local function fieldReady(game)
  if not game then return false end
  local top = game.stack and game.stack:top()
  if top and top.isOverworld then
    return true
  end
  if game.world and game.world.map and not top then
    return true
  end
  return false
end

local Collect
local function loadCollect(mod)
  if Collect then return Collect end
  if not (mod and mod.read) then
    error("dex_radar: cannot load collect.lua (no mod handle)")
  end
  local src = mod:read("collect.lua")
  if type(src) ~= "string" or src == "" then
    error("dex_radar: cannot load collect.lua (missing or empty)")
  end
  local loader = loadstring or load
  local chunk, err = loader(src, "@dex_radar/collect.lua")
  if not chunk then
    error("dex_radar: cannot load collect.lua (" .. tostring(err) .. ")")
  end
  Collect = chunk()
  return Collect
end

-- Horizontal offset for an overflowing label at time t (seconds): hold at 0,
-- scroll out to -overflow, hold, scroll back to 0.  Content that fits
-- (overflow <= 0) is static.  Pure, so the headless suite can assert the
-- overflow path without drawing.
local function tickerOffset(t, overflow)
  if not (overflow and overflow > 0) then return 0 end
  local scroll = overflow / TICKER_SPEED
  local cycle = 2 * TICKER_HOLD + 2 * scroll
  local p = (t or 0) % cycle
  if p < TICKER_HOLD then return 0 end
  p = p - TICKER_HOLD
  if p < scroll then return -p * TICKER_SPEED end
  p = p - scroll
  if p < TICKER_HOLD then return -overflow end
  p = p - TICKER_HOLD
  return -overflow + p * TICKER_SPEED
end

-- The ticker record for a label drawn with Font at the header, or nil when
-- it fits its window.
local function mapLabelTicker(Font, label)
  local w = Font.width and Font.width(label)
  if not w or w <= MAP_LABEL_W then return nil end
  return { x = MAP_LABEL_X, w = MAP_LABEL_W, overflow = w - MAP_LABEL_W }
end

-- Human map title for the header. Prefer landmark / town-map names over raw ids.
local function prettyMapId(mapId)
  if type(mapId) ~= "string" or mapId == "" then return "UNKNOWN" end
  return (mapId:gsub("_", " "))
end

local function flattenLandmarkName(name)
  if type(name) ~= "string" or name == "" then return nil end
  -- Town-map names keep a cart newline ("CHERRYGROVE\nCITY") — one line here.
  local flat = name:gsub("\n", " "):gsub("%s+", " ")
  return flat:match("^%s*(.-)%s*$")
end

local function gen2LandmarkLabel(game, map)
  if type(map) ~= "table" then return nil end
  local pack = game and game.data and game.data.gen2Landmarks
  if type(pack) ~= "table" then return nil end
  local landmarks = pack.landmarks or pack
  local order = pack.order
  local id = map.landmark
  if type(id) == "number" and type(order) == "table" then
    id = order[id + 1]
  end
  if type(id) ~= "string" then return nil end
  local entry = landmarks[id]
  return flattenLandmarkName(entry and entry.name)
end

local function gen1TownMapLabel(mod, mapId)
  if not (mod and mod.content and mod.content.field and mod.content.field.get) then
    return nil
  end
  local ok, townMap = pcall(function()
    return mod.content.field:get("townMap")
  end)
  if not ok or type(townMap) ~= "table" then return nil end
  local row = townMap[mapId]
  if type(row) == "table" and type(row.name) == "string" and row.name ~= "" then
    return row.name
  end
  return nil
end

local function mapLabel(mod, mapId, game)
  local map = mod.content.maps:get(mapId)
  if type(map) == "table" and type(map.label) == "string" and map.label ~= "" then
    return map.label
  end
  local landmark = gen2LandmarkLabel(game, map)
  if landmark then return landmark end
  local town = gen1TownMapLabel(mod, mapId)
  if town then return town end
  if type(map) == "table" and type(map.id) == "string" and map.id ~= "" then
    return prettyMapId(map.id)
  end
  return prettyMapId(mapId)
end

local function isSeen(game, speciesId)
  return loadCollect().isSeen(game, speciesId)
end

local function isOwned(game, speciesId)
  return loadCollect().isOwned(game, speciesId)
end

local function levelText(entry)
  if not entry then return "" end
  if entry.minLv == entry.maxLv then
    return ("L%d"):format(entry.minLv)
  end
  return ("L%d-%d"):format(entry.minLv, entry.maxLv)
end

-- Gen 2: species % + ToD letter. Gen 1: species % (rod is the section header).
-- No "%" glyph in the GB font — screens showed "RATE 15" when we used "RATE 15%".
local function rateText(row)
  if row.rate == nil then return nil end
  if row.todLabel then
    return ("RATE %d (%s)"):format(row.rate, row.todLabel)
  end
  return ("RATE %d"):format(row.rate)
end

local function ownedCounts(game, sections)
  local seenIds, total, owned = {}, 0, 0
  for _, section in ipairs(sections) do
    for _, entry in ipairs(section.entries or {}) do
      local id = entry.species
      if not seenIds[id] then
        seenIds[id] = true
        total = total + 1
        if isOwned(game, id) then owned = owned + 1 end
      end
    end
  end
  return owned, total
end

-- Resolve mapId: explicit arg, else current overworld map.
local function resolveMapId(mod, mapId)
  if type(mapId) == "string" and mapId ~= "" then return mapId end
  if not (mod.world and mod.world.current) then return nil end
  local cur = mod.world:current()
  return cur and cur.mapId or nil
end

-- Unique species ids in section order (grass → water → fish), first-seen wins.
local function speciesFromSections(sections)
  local list, seen = {}, {}
  for _, section in ipairs(sections or {}) do
    for _, entry in ipairs(section.entries or {}) do
      local id = entry.species
      if type(id) == "string" and id ~= "" and not seen[id] then
        seen[id] = true
        list[#list + 1] = id
      end
    end
  end
  return list
end

local function publishExports(mod)
  local C = loadCollect(mod)
  local function sectionsFor(game, mapId)
    return C.collect(mod, resolveMapId(mod, mapId), game)
  end

  -- Sections (Gen 1 + Gen 2):
  -- { id, title, habitatRate?, tod?, todLabel?,
  --   entries = { { species, minLv, maxLv, rate? }, ... } }
  -- habitatRate = map encounter chance; entry.rate = species share in that table.
  mod.exports.collect = function(game, mapId)
    return sectionsFor(game, mapId)
  end

  mod.exports.isSeen = function(game, speciesId)
    return C.isSeen(game, speciesId)
  end

  mod.exports.isOwned = function(game, speciesId)
    return C.isOwned(game, speciesId)
  end

  -- Unique species on the map (grass → water → fish order).
  mod.exports.speciesOnMap = function(game, mapId)
    return speciesFromSections(sectionsFor(game, mapId))
  end

  -- { owned = n, total = m } for unique species on the map.
  mod.exports.ownedCount = function(game, mapId)
    local owned, total = ownedCounts(game, sectionsFor(game, mapId))
    return { owned = owned, total = total }
  end

  -- true if every unique wild species on the map is owned.
  -- Empty map (no wilds) → true.
  mod.exports.isOwnedOnMap = function(game, mapId)
    local owned, total = ownedCounts(game, sectionsFor(game, mapId))
    return owned >= total
  end
end

-- ------- art helpers

local function drawPokeball(cx, cy, r)
  r = r or 4
  cx, cy = math.floor(cx + 0.5), math.floor(cy + 0.5)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.arc("fill", "pie", cx, cy, r, math.pi, math.pi * 2)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.line(cx - r, cy, cx + r, cy)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", cx, cy, 1.5)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("line", cx, cy, 1.5)
end

-- Rest / alt frames for built-in Gen 1 icon classes (PartyMenu.iconFrames).
-- Selected row animates; others stay on the rest frame.
local ICON_FRAMES = {
  BUG = 1, GRASS = 1, SNAKE = 0, QUADRUPED = 0,
  MON = 3, FAIRY = 3, BIRD = 3, WATER = 0, PIKACHU = 3,
}

local function isGen2IconName(name)
  return type(name) == "string" and name:sub(1, 5) == "ICON_"
end

-- Built-in Gen 1 party icons are OBJ art: bake OBP0 "3100" so shade 2 never
-- shows (same remap as PartyMenu / SpriteRenderer.getObpImage). Gen 2 menu
-- icons and custom mod images load as authored.
local function loadObpIcon(path)
  local okA, Assets = pcall(require, "src.render.Assets")
  if not (okA and Assets and Assets.imageData) then return nil end
  local ok, img = pcall(function()
    local id = Assets.imageData(path)
    id:mapPixel(function(_, _, r, _, _, a)
      local v = 0
      if r > 0.5 then
        v = 1
      elseif r > 0.17 then
        v = 170 / 255
      end
      return v, v, v, a
    end)
    local out = love.graphics.newImage(id)
    out:setFilter("nearest", "nearest")
    return out
  end)
  return ok and img or nil
end

local function loadImage(path)
  if not path then return nil end
  local okA, Assets = pcall(require, "src.render.Assets")
  if okA and Assets and Assets.image then
    local ok, img = pcall(Assets.image, path)
    if ok and img then
      if img.setFilter then img:setFilter("nearest", "nearest") end
      return img
    end
  end
  local src = path
  if okA and Assets and Assets.resolve then
    local okR, resolved = pcall(Assets.resolve, path)
    if okR and resolved then src = resolved end
  end
  local ok, img = pcall(love.graphics.newImage, src)
  if not (ok and img) then return nil end
  img:setFilter("nearest", "nearest")
  return img
end

-- Gold ships menu icons under data.gen2Icons; Gen 1 under data.icons.
local function iconTable(game)
  local data = game and game.data
  if not data then return nil end
  return data.gen2Icons or data.icons
end

-- path, icon class/id name (Gen 1 "BIRD" / Gen 2 "ICON_BIRD"), or nil name
-- for custom { image } art.
local function resolveIcon(game, speciesId)
  local icons = iconTable(game)
  if not icons then return nil, nil end
  local def = game.data.pokemon and game.data.pokemon[speciesId]
  local entry = (icons.species and icons.species[speciesId])
    or (icons.bySpecies and icons.bySpecies[speciesId])
    or (def and def.icon)
  local name, path
  if type(entry) == "string" then
    name = entry
    local slot = icons.icons and icons.icons[entry]
    if type(slot) == "string" then
      path = slot
    elseif type(slot) == "table" then
      path = slot.image
    end
  elseif type(entry) == "table" then
    path = entry.image
  end
  if not path and def and def.dex and icons.byDex then
    name = icons.byDex[def.dex]
    local slot = name and icons.icons and icons.icons[name]
    if type(slot) == "string" then
      path = slot
    elseif type(slot) == "table" then
      path = slot.image
    end
  end
  local okS, Sprites = pcall(require, "src.pokemon.Sprites")
  if okS and Sprites and Sprites.iconPath then
    local hooked = Sprites.iconPath(game.data, { species = speciesId }, path, {
      name = name,
    })
    if type(hooked) == "string" and hooked ~= "" then path = hooked end
  end
  return path, name
end

-- PartyMenu Gen 2: swap frames every 16 logic ticks (rest / attack).
-- Gen 1 PartyMenu: only the cursor mon animates; green-bar pace = 5.
local GEN2_ICON_FRAME_STEPS = 16
local GEN1_ICON_FRAME_STEPS = 5

-- Same source as Gen 2 PartyMenu:drawIcon — cart PartyMenu OBP slot 0.
-- Not a hardcoded RGB: GbcPalette.with applies the player's COLOR mode
-- (GBC / DMG / CLASSIC) at draw time via GbcPalette.resolve.
local function partyMenuObp(game)
  local pals = game and game.data and game.data.gen2Palettes
  local pm = pals and pals.partyMenu
  if type(pm) == "table" and type(pm[1]) == "table" then
    return pm[1]
  end
  return nil
end

local function gen1IconFrame(name, ih, selected, clock)
  local alt = false
  if selected then
    alt = math.floor((clock or 0) / GEN1_ICON_FRAME_STEPS) % 2 == 1
  end
  local ok, PartyMenu = pcall(require, "src.ui.PartyMenu")
  if ok and PartyMenu and PartyMenu.frameFor then
    return PartyMenu.frameFor(name, alt, ih), alt
  end
  if not name or (ih or 0) <= 16 then return 0, alt end
  local rest = ICON_FRAMES[name] or 0
  if not alt then return rest, alt end
  if rest == 1 then return 0, alt end
  if rest == 3 then return 0, alt end
  return (rest == 0) and 1 or 0, alt
end

-- Draw a 16×16 party icon.
-- Gen 2: animated sheet + live PartyMenu OBP (GbcPalette respects COLOR).
-- Gen 1: OBP-baked art; COLORS come from screen sgbPalettes (MEWMON).
local function drawPartyIcon(img, name, x, y, opts)
  opts = opts or {}
  local iw, ih = img:getDimensions()
  if isGen2IconName(name) then
    local frame = (opts.frame or 0) % 2
    local quad = love.graphics.newQuad(0, frame * 16, 16, 16, iw, ih)
    local silhouette = opts.silhouette
    -- Re-read each draw so mid-session palette / COLOR changes apply.
    local colors = opts.colors
    local function paint()
      if silhouette then
        love.graphics.setColor(0, 0, 0, 1)
      else
        love.graphics.setColor(1, 1, 1, 1)
      end
      love.graphics.draw(img, quad, x, y)
    end
    if colors and not silhouette then
      local ok, GbcPalette = pcall(require, "src.render.GbcPalette")
      if ok and GbcPalette and GbcPalette.available and GbcPalette.available()
          and GbcPalette.with then
        GbcPalette.with(colors, paint)
        return
      end
    end
    paint()
    return
  end
  local frame = opts.frame
  if frame == nil then
    frame = 0
    if name and ih > 16 then
      frame = ICON_FRAMES[name] or 0
    end
  end
  local drawY = y + (opts.yNudge or 0)
  if name and name ~= "HELIX" then
    local half = love.graphics.newQuad(0, frame * 16, 8, 16, iw, ih)
    love.graphics.draw(img, half, x, drawY)
    love.graphics.draw(img, half, x + 16, drawY, 0, -1, 1)
  elseif ih > 16 then
    love.graphics.draw(
      img, love.graphics.newQuad(0, frame * 16, 16, 16, iw, ih), x, drawY
    )
  else
    love.graphics.draw(img, x, drawY)
  end
end

-- ------- rows / navigation

local function buildRows(mod, game, mapId)
  local sections = loadCollect(mod).collect(mod, mapId, game)
  local rows, monIndex = {}, {}
  for _, section in ipairs(sections) do
    rows[#rows + 1] = { kind = "header", text = section.title }
    for _, entry in ipairs(section.entries or {}) do
      local def = mod.content.pokemon:get(entry.species)
      local seen = isSeen(game, entry.species)
      local owned = isOwned(game, entry.species)
      local name = (def and def.name) or entry.species
      local iconPath, iconName = resolveIcon(game, entry.species)
      local rate = entry.rate
      local row = {
        kind = "mon",
        id = entry.species,
        seen = seen,
        owned = owned,
        name = seen and name or "?????",
        minLv = entry.minLv,
        maxLv = entry.maxLv,
        rate = rate,
        tod = section.tod,
        todLabel = section.todLabel,
        iconPath = iconPath,
        iconName = iconName,
      }
      rows[#rows + 1] = row
      monIndex[#monIndex + 1] = #rows
    end
  end
  local ownedN, totalN = ownedCounts(game, sections)
  return rows, monIndex, ownedN, totalN, sections
end

local function rowHeight(row)
  return row.kind == "header" and HEADER_H or ROW_H
end

local function totalHeight(rows)
  local h = 0
  for _, row in ipairs(rows) do
    h = h + rowHeight(row)
  end
  return h
end

local function clampScroll(scroll, rows)
  local max = math.max(0, totalHeight(rows) - (LIST_BOTTOM - LIST_TOP))
  if scroll < 0 then return 0 end
  if scroll > max then return max end
  return scroll
end

local function rowOffset(rows, rowIdx)
  local y = 0
  for i = 1, rowIdx - 1 do
    y = y + rowHeight(rows[i])
  end
  return y
end

-- Keep the selected mon fully inside the list viewport (pixel scroll).
local function ensureVisible(self)
  if #self.monIndex == 0 then return end
  local rowIdx = self.monIndex[self.cursor]
  if not rowIdx or not self.rows[rowIdx] then return end
  local y = rowOffset(self.rows, rowIdx)
  local h = rowHeight(self.rows[rowIdx])
  local view = LIST_BOTTOM - LIST_TOP
  if y < self.scroll then
    -- If the row fits with the list at the top, snap to 0 so section
    -- headers stay visible and the "more above" arrow clears.
    if y + h <= view then
      self.scroll = 0
    else
      self.scroll = y
    end
  elseif y + h > self.scroll + view then
    self.scroll = y + h - view
  end
  self.scroll = clampScroll(self.scroll, self.rows)
end

-- Lua 5.1/LuaJIT: negative a % b stays negative; avoid that for wrap.
local function wrapCursor(cursor, delta, n)
  local i = cursor + delta
  while i < 1 do i = i + n end
  while i > n do i = i - n end
  return i
end

local function currentMapId(mod)
  if not (mod.world and mod.world.current) then return nil end
  local cur = mod.world:current()
  return cur and cur.mapId or nil
end

local function screenFactory(mod)
  return {
    new = function(game)
      local Font = mod.ui.Font
      local showLevels = mod.options:get("show_levels")
      local showRates = mod.options:get("show_rates")
      local mapId = currentMapId(mod)
      local rows, monIndex, ownedN, totalN = buildRows(mod, game, mapId)
      local label = mapId and mapLabel(mod, mapId, game) or "UNKNOWN"
      local mapTicker = mapLabelTicker(Font, label)

      local icons = {}
      -- Gen 1 built-in classes bake OBP0 (cache key path#obp); Gen 2 ICON_*
      -- sheets and custom art load as authored.
      local function iconImg(path, name)
        if not path then return nil end
        local key = name and (path .. "#obp") or path
        if isGen2IconName(name) then
          key = path
        end
        if icons[key] ~= nil then return icons[key] or nil end
        local img
        if name and not isGen2IconName(name) then
          img = loadObpIcon(path) or loadImage(path)
        else
          img = loadImage(path)
        end
        icons[key] = img or false
        return icons[key] or nil
      end

      local Theme = mod.ui.Theme
      local cursorCode = (Theme and Theme.cursor) or 0xED

      local Collect = loadCollect(mod)
      local todKey = nil
      if Collect.generation(game) == 2 then
        todKey = Collect.normalizeTod(game.world and game.world.daytime)
      end

      local self = {
        game = game,
        isOpaque = true,
        mapId = mapId,
        rows = rows,
        monIndex = monIndex,
        cursor = 1,
        scroll = 0,
        mapLabel = label,
        mapTicker = mapTicker,
        mapTick = 0,
        ownedN = ownedN,
        totalN = totalN,
        showLevels = showLevels,
        showRates = showRates,
        holdDir = nil,
        holdFrames = 0,
        -- Shared with Gen 1 selected-icon bounce and Gen 2 frame swap.
        iconClock = 0,
        todKey = todKey,
      }
      ensureVisible(self)

      -- Rebuild when Gen 2 time-of-day changes (species % + label).
      function self:reloadForTod()
        local C = loadCollect(mod)
        if C.generation(self.game) ~= 2 then return end
        local nextTod = C.normalizeTod(
          self.game.world and self.game.world.daytime
        )
        if nextTod == self.todKey then return end
        local prevId = nil
        if self.monIndex[self.cursor] then
          local row = self.rows[self.monIndex[self.cursor]]
          prevId = row and row.id
        end
        local newRows, newIndex, ownedN_, totalN_ =
          buildRows(mod, self.game, self.mapId)
        self.rows, self.monIndex = newRows, newIndex
        self.ownedN, self.totalN = ownedN_, totalN_
        self.todKey = nextTod
        self.cursor = 1
        if prevId then
          for i, idx in ipairs(self.monIndex) do
            if self.rows[idx] and self.rows[idx].id == prevId then
              self.cursor = i
              break
            end
          end
        end
        ensureVisible(self)
      end

      -- Live COLORS: PaletteFX.pal(MEWMON) follows the player's COLORS mode
      -- (SGB / ADVANCED / RED++ / …) the same way PartyMenu does.
      function self:sgbPalettes(game_)
        local ok, P = pcall(require, "src.render.PaletteFX")
        if ok and P and P.wholeNamed then
          return P.wholeNamed(game_.data, "MEWMON")
        end
        return {
          {
            colors = {
              { 255, 255, 255 }, { 170, 170, 170 },
              { 85, 85, 85 }, { 0, 0, 0 },
            },
            x = 0, y = 0, w = 160, h = 144,
          },
        }
      end

      function self:moveCursor(delta)
        if #self.monIndex == 0 then return end
        self.cursor = wrapCursor(self.cursor, delta, #self.monIndex)
        ensureVisible(self)
      end

      local function navPressed(screen, dir)
        if dir == "up" then
          screen:moveCursor(-1)
        elseif dir == "down" then
          screen:moveCursor(1)
        elseif dir == "left" then
          screen:moveCursor(-3)
        elseif dir == "right" then
          screen:moveCursor(3)
        end
      end

      function self:update(dt)
        local speed = logicSpeed(self.game)
        -- Party / ListMenu icon clock (Gen 1 selected bounce + Gen 2 frames).
        self.iconClock = (self.iconClock or 0) + 1
        if self.reloadForTod then self:reloadForTod() end
        -- advance the map label ticker in real time (not logic-speed scaled)
        if self.mapTicker then
          self.mapTick = (self.mapTick or 0) + (dt or 0) / speed
        end
        local input = self.game.input
        if input:wasPressed("b") then
          self.game.stack:pop()
          return
        end

        local moved = false
        if input:wasPressed("up") then
          navPressed(self, "up")
          self.holdDir, self.holdFrames = "up", 0
          moved = true
        elseif input:wasPressed("down") then
          navPressed(self, "down")
          self.holdDir, self.holdFrames = "down", 0
          moved = true
        elseif input:wasPressed("left") then
          navPressed(self, "left")
          self.holdDir, self.holdFrames = "left", 0
          moved = true
        elseif input:wasPressed("right") then
          navPressed(self, "right")
          self.holdDir, self.holdFrames = "right", 0
          moved = true
        end

        local dir = self.holdDir
        if dir and input:isDown(dir) then
          self.holdFrames = self.holdFrames + 1
          local delay = REPEAT_DELAY * speed
          local rate = math.max(1, math.floor(REPEAT_RATE * speed + 0.5))
          local afterDelay = self.holdFrames - delay
          if afterDelay >= 0 and afterDelay % rate == 0 then
            navPressed(self, dir)
            moved = true
          end
        else
          self.holdDir, self.holdFrames = nil, 0
        end

        if not moved then ensureVisible(self) end
      end

      function self:draw()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 160, 144)
        Font.drawBox(0, 0, 20, 18)

        love.graphics.setColor(0, 0, 0, 1)
        local ownedLabel = ("%d/%d"):format(self.ownedN, self.totalN)
        Font.draw("D.RADAR", 8, TITLE_Y)
        local ow = (Font.width and Font.width(ownedLabel)) or (#ownedLabel * 8)
        Font.draw(ownedLabel, math.max(8, 160 - 8 - ow), TITLE_Y)
        if self.mapTicker then
          withScissor(self.mapTicker.x, MAP_Y, self.mapTicker.w, 8, function()
            Font.draw(self.mapLabel, self.mapTicker.x
                + tickerOffset(self.mapTick or 0, self.mapTicker.overflow), MAP_Y)
          end)
        else
          Font.draw(self.mapLabel, 8, MAP_Y)
        end

        if #self.monIndex == 0 then
          Font.draw("NO WILD", 8, 56)
          Font.draw("POKEMON", 8, 68)
          Font.draw("B: BACK", 8, 128)
          return
        end

        withScissor(0, LIST_TOP, 160, LIST_BOTTOM - LIST_TOP, function()
          local y = LIST_TOP - self.scroll
          for i, row in ipairs(self.rows) do
            local h = rowHeight(row)
            -- Fully visible rows only — avoids a 1px sliver above "B: BACK".
            if y >= LIST_TOP and y + h <= LIST_BOTTOM then
              if row.kind == "header" then
                love.graphics.setColor(0, 0, 0, 1)
                Font.draw(row.text, 8, y + 2)
              else
                local selected = self.monIndex[self.cursor] == i
                -- ListMenu layout: cursor glyph at x=8, icon/text at x=16
                if selected and Font.drawCode then
                  love.graphics.setColor(0, 0, 0, 1)
                  Font.drawCode(cursorCode, 8, y + 5)
                end
                local ix = 16
                local img = iconImg(row.iconPath, row.iconName)
                if img then
                  if isGen2IconName(row.iconName) then
                    local frame = math.floor(
                      (self.iconClock or 0) / GEN2_ICON_FRAME_STEPS
                    ) % 2
                    drawPartyIcon(img, row.iconName, ix, y + 2, {
                      frame = frame,
                      -- Live cart OBP; GbcPalette applies COLOR (GBC/DMG/CLASSIC).
                      colors = partyMenuObp(self.game),
                      silhouette = not row.seen,
                    })
                  else
                    local _, ih = img:getDimensions()
                    local frame, alt = gen1IconFrame(
                      row.iconName, ih, selected, self.iconClock
                    )
                    local yNudge = 0
                    -- PartyMenu: BALL / HELIX bob one pixel instead of swapping.
                    if alt and (row.iconName == "BALL" or row.iconName == "HELIX") then
                      yNudge = 1
                      frame = (ih > 16) and (ICON_FRAMES[row.iconName] or 0) or 0
                    end
                    if row.seen then
                      love.graphics.setColor(1, 1, 1, 1)
                    else
                      love.graphics.setColor(0, 0, 0, 1)
                    end
                    drawPartyIcon(img, row.iconName, ix, y + 2, {
                      frame = frame,
                      yNudge = yNudge,
                    })
                  end
                else
                  love.graphics.setColor(0, 0, 0, 1)
                  love.graphics.rectangle("line", ix, y + 2, ICON, ICON)
                end

                love.graphics.setColor(0, 0, 0, 1)
                local nameX = ix + ICON + 4
                Font.draw(row.name, nameX, y + 1)
                local afterName = nameX
                  + ((Font.width and Font.width(row.name)) or (#row.name * 8))
                if row.owned and row.seen then
                  drawPokeball(afterName + 6, y + 4, 4)
                end

                if self.showLevels and row.seen then
                  love.graphics.setColor(0, 0, 0, 1)
                  Font.draw(levelText(row), nameX, y + 9)
                end
                if self.showRates and row.seen and row.rate ~= nil then
                  love.graphics.setColor(0, 0, 0, 1)
                  local text = rateText(row)
                  if text then Font.draw(text, nameX, y + 18) end
                end
              end
            end
            y = y + h
          end
        end)

        love.graphics.setColor(0, 0, 0, 1)
        Font.draw("B: BACK", 8, 128)
        local maxScroll = math.max(0, totalHeight(self.rows) - (LIST_BOTTOM - LIST_TOP))
        if Theme and Theme.moreArrow and Font.drawCode then
          -- $EE is the Gen 1 "more below" glyph; flip it for "more above".
          if self.scroll > 0 then
            love.graphics.push()
            love.graphics.translate(144, LIST_TOP)
            love.graphics.scale(1, -1)
            Font.drawCode(Theme.moreArrow, 0, -8)
            love.graphics.pop()
          end
          if self.scroll < maxScroll then
            Font.drawCode(Theme.moreArrow, 144, LIST_BOTTOM - 8)
          end
        end
      end

      return self
    end,
  }
end

-- ------- entry

return function(mod)
  loadCollect(mod)

  mod.options:define({
    {
      key = "show_levels",
      type = "toggle",
      label = "SHOW LEVELS",
      default = true,
    },
    {
      key = "show_rates",
      type = "toggle",
      label = "SHOW RATES",
      default = true,
    },
    {
      key = "hotkey_enabled",
      type = "toggle",
      label = "HOTKEY",
      default = true,
    },
    {
      key = "hotkey",
      type = "choice",
      label = "HOTKEY KEY",
      default = "r",
      choices = HOTKEY_CHOICES,
    },
  })

  mod.content.screens:register(SCREEN, screenFactory(mod))

  local function openRadar(game)
    if not game then return end
    mod.ui.push(game, SCREEN)
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "D.RADAR",
      onSelect = function() openRadar(game) end,
    })
  end)

  local keyWasDown = false
  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id then
      keyWasDown = false
    end
  end)

  mod.hooks:wrap("input.step", function(next, game, dt)
    next(game, dt)

    if not mod.options:get("hotkey_enabled") then
      keyWasDown = false
      return
    end
    local key = mod.options:get("hotkey")
    if not key or key == "off" then
      keyWasDown = false
      return
    end
    if not (love and love.keyboard and love.keyboard.isDown) then
      return
    end

    local down = love.keyboard.isDown(key)
    local edge = down and not keyWasDown
    keyWasDown = down
    if not edge then return end

    if not fieldReady(game) then return end

    openRadar(game)
  end)

  publishExports(mod)
end
