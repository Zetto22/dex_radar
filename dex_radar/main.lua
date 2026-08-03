-- Dex Radar: wild species on the current map (grass / water / fishing).
-- Compact party-icon list of wild species on the current map.

local SCREEN = "DexRadar"

local ROW_H = 28
local HEADER_H = 12
local VISIBLE_MONS = 3
local LIST_TOP = 28
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
-- Hold-to-scroll (same cadence as engine ListMenu).
local REPEAT_DELAY = 16
local REPEAT_RATE = 4

local HOTKEY_CHOICES = {
  { "R", "r" }, { "F", "f" }, { "G", "g" }, { "H", "h" },
  { "T", "t" }, { "Y", "y" }, { "U", "u" }, { "I", "i" },
  { "O", "o" }, { "P", "p" }, { "C", "c" }, { "V", "v" },
  { "N", "n" }, { "M", "m" }, { "Q", "q" }, { "E", "e" },
  { "OFF", "off" },
}

-- ------- encounter collection

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

-- Ordered unique entries with level ranges from slot rows.
local function entriesFromSlots(slots)
  local order, seen = {}, {}
  if type(slots) ~= "table" then return order end
  for _, slot in ipairs(slots) do
    if type(slot) == "table" and type(slot.species) == "string" and slot.species ~= "" then
      local id = slot.species
      local lv = tonumber(slot.level) or 1
      local e = seen[id]
      if not e then
        e = { species = id, minLv = lv, maxLv = lv }
        seen[id] = e
        order[#order + 1] = e
      else
        if lv < e.minLv then e.minLv = lv end
        if lv > e.maxLv then e.maxLv = lv end
      end
    end
  end
  return order
end

local function appendFishEntry(order, seen, species, level)
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

local function fishEntries(mod, mapId, enc)
  local waterOk = enc and hasSlots(enc.water)
  local superGroup = superRodGroup(mod, mapId)
  if not waterOk and not superGroup then return nil end

  local order, seen = {}, {}
  local rods = fishingRods(mod)

  local old = rods.OLD_ROD
  if type(old) == "table" and type(old.always) == "table" then
    appendFishEntry(order, seen, old.always.species, old.always.level)
  end

  local good = rods.GOOD_ROD
  if type(good) == "table" and type(good.pool) == "table" then
    for _, slot in ipairs(good.pool) do
      if type(slot) == "table" then
        appendFishEntry(order, seen, slot.species, slot.level)
      end
    end
  end

  if superGroup then
    for _, slot in ipairs(superGroup) do
      if type(slot) == "table" then
        appendFishEntry(order, seen, slot.species, slot.level)
      end
    end
  end

  if #order == 0 then return nil end
  return order
end

--- sections: { { id, title, rate?, entries = { { species, minLv, maxLv } } } }
local function collect(mod, mapId)
  local sections = {}
  if type(mapId) ~= "string" or mapId == "" then
    return sections
  end

  local enc = mod.content.encounters:get(mapId)

  if enc and hasSlots(enc.grass) then
    sections[#sections + 1] = {
      id = "grass",
      title = "GRASS",
      rate = tonumber(enc.grass.rate),
      entries = entriesFromSlots(enc.grass.slots),
    }
  end

  if enc and hasSlots(enc.water) then
    sections[#sections + 1] = {
      id = "water",
      title = "WATER",
      rate = tonumber(enc.water.rate),
      entries = entriesFromSlots(enc.water.slots),
    }
  end

  local fish = fishEntries(mod, mapId, enc)
  if fish then
    sections[#sections + 1] = {
      id = "fish",
      title = "FISH",
      rate = nil,
      entries = fish,
    }
  end

  return sections
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

local function mapLabel(mod, mapId)
  local map = mod.content.maps:get(mapId)
  local label
  if type(map) == "table" then
    label = map.label or map.id or mapId
  else
    label = mapId
  end
  return tostring(label or "UNKNOWN")
end

local function isSeen(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.seen and dex.seen[speciesId] and true or false
end

local function isOwned(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.owned and dex.owned[speciesId] and true or false
end

local function levelText(entry)
  if not entry then return "" end
  if entry.minLv == entry.maxLv then
    return ("L%d"):format(entry.minLv)
  end
  return ("L%d-%d"):format(entry.minLv, entry.maxLv)
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
  local function sectionsFor(game, mapId)
    return collect(mod, resolveMapId(mod, mapId))
  end

  -- Sections: { id, title, rate?, entries = { { species, minLv, maxLv } } }
  mod.exports.collect = function(game, mapId)
    return sectionsFor(game, mapId)
  end

  mod.exports.isSeen = function(game, speciesId)
    return isSeen(game, speciesId)
  end

  mod.exports.isOwned = function(game, speciesId)
    return isOwned(game, speciesId)
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

local function markUnshaded(x, y, w, h)
  local ok, P = pcall(require, "src.render.PaletteFX")
  if ok and P and P.markTrueColor then
    P.markTrueColor(x, y, w, h)
  end
end

local function resolveIconPath(game, speciesId)
  local icons = game and game.data and game.data.icons
  if not icons then return nil end
  local def = game.data.pokemon and game.data.pokemon[speciesId]
  local entry = (icons.bySpecies and icons.bySpecies[speciesId])
    or (def and def.icon)
  local path
  if type(entry) == "string" then
    path = icons.icons and icons.icons[entry]
  elseif type(entry) == "table" then
    path = entry.image
  end
  if not path and def and def.dex and icons.byDex then
    local name = icons.byDex[def.dex]
    path = name and icons.icons and icons.icons[name]
  end
  return path
end

local function loadImage(path)
  if not path then return nil end
  local ok, img = pcall(love.graphics.newImage, path)
  if not (ok and img) then return nil end
  img:setFilter("nearest", "nearest")
  return img
end

-- ------- rows / navigation

local function buildRows(mod, game, mapId)
  local sections = collect(mod, mapId)
  local rows, monIndex = {}, {}
  for _, section in ipairs(sections) do
    rows[#rows + 1] = { kind = "header", text = section.title }
    for _, entry in ipairs(section.entries or {}) do
      local def = mod.content.pokemon:get(entry.species)
      local seen = isSeen(game, entry.species)
      local owned = isOwned(game, entry.species)
      local name = (def and def.name) or entry.species
      local row = {
        kind = "mon",
        id = entry.species,
        seen = seen,
        owned = owned,
        name = seen and name or "?????",
        minLv = entry.minLv,
        maxLv = entry.maxLv,
        rate = section.rate,
        iconPath = resolveIconPath(game, entry.species),
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
      local label = mapId and mapLabel(mod, mapId) or "UNKNOWN"
      local mapTicker = mapLabelTicker(Font, label)

      local icons, quads = {}, {}
      local function iconImg(path)
        if not path then return nil end
        if icons[path] ~= nil then return icons[path] or nil end
        local img = loadImage(path)
        icons[path] = img or false
        if img then
          local iw, ih = img:getDimensions()
          quads[path] = love.graphics.newQuad(0, 0, math.min(16, iw), math.min(16, ih), iw, ih)
        end
        return icons[path] or nil
      end

      local Theme = mod.ui.Theme
      local cursorCode = (Theme and Theme.cursor) or 0xED

      local self = {
        game = game,
        isOpaque = true,
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
      }
      ensureVisible(self)

      function self:sgbPalettes(_game)
        local grays = {
          { 255, 255, 255 }, { 170, 170, 170 },
          { 85, 85, 85 }, { 0, 0, 0 },
        }
        return {
          { colors = grays, x = 0, y = 0, w = 160, h = 144 },
          { colors = false, x = 0, y = LIST_TOP, w = 28, h = LIST_BOTTOM - LIST_TOP },
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
        -- advance the map label ticker (the draw pass reads mapTick)
        if self.mapTicker then
          self.mapTick = (self.mapTick or 0) + (dt or 0)
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
          local afterDelay = self.holdFrames - REPEAT_DELAY
          if afterDelay >= 0 and afterDelay % REPEAT_RATE == 0 then
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
        Font.draw("DEX RADAR", 8, 6)
        local ow = (Font.width and Font.width(ownedLabel)) or (#ownedLabel * 8)
        Font.draw(ownedLabel, math.max(8, 160 - 8 - ow), 6)
        if self.mapTicker then
          love.graphics.setScissor(self.mapTicker.x, 14, self.mapTicker.w, 8)
          Font.draw(self.mapLabel, self.mapTicker.x
              + tickerOffset(self.mapTick or 0, self.mapTicker.overflow), 14)
          love.graphics.setScissor()
        else
          Font.draw(self.mapLabel, 8, 14)
        end

        if #self.monIndex == 0 then
          Font.draw("NO WILD", 8, 56)
          Font.draw("POKEMON", 8, 68)
          Font.draw("B: BACK", 8, 128)
          return
        end

        love.graphics.setScissor(0, LIST_TOP, 160, LIST_BOTTOM - LIST_TOP)
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
              local img = iconImg(row.iconPath)
              if img and quads[row.iconPath] then
                if row.seen then
                  love.graphics.setColor(1, 1, 1, 1)
                else
                  love.graphics.setColor(0, 0, 0, 1)
                end
                love.graphics.draw(img, quads[row.iconPath], ix, y + 2)
                markUnshaded(ix, y + 2, ICON, ICON)
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
                Font.draw(("RATE%d"):format(row.rate), nameX, y + 18)
              end
            end
          end
          y = y + h
        end
        love.graphics.setScissor()

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
      label = "DEX RADAR",
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

    local top = game.stack and game.stack:top()
    if not (top and top.isOverworld) then return end

    openRadar(game)
  end)

  publishExports(mod)
end
