-- Dex Radar: wild species on the current map (grass / water / fishing).
-- Start menu row + optional overworld hotkey (default R).

local SCREEN = "DexRadar"

local ROW_H = 28
local HEADER_H = 12
local LIST_TOP = 28
local LIST_BOTTOM = 128
local SPRITE_MAX = 24

local HOTKEY_CHOICES = {
  { "R", "r" }, { "F", "f" }, { "G", "g" }, { "H", "h" },
  { "T", "t" }, { "Y", "y" }, { "U", "u" }, { "I", "i" },
  { "O", "o" }, { "P", "p" }, { "C", "c" }, { "V", "v" },
  { "N", "n" }, { "M", "m" }, { "Q", "q" }, { "E", "e" },
  { "OFF", "off" },
}

-- ------- encounter collection (common -> rare; FISH: Old -> Good -> Super)

local function appendUnique(list, seen, species)
  if type(species) ~= "string" or species == "" or seen[species] then
    return
  end
  seen[species] = true
  list[#list + 1] = species
end

local function speciesFromSlots(slots)
  local list, seen = {}, {}
  if type(slots) ~= "table" then return list end
  for _, slot in ipairs(slots) do
    if type(slot) == "table" then
      appendUnique(list, seen, slot.species)
    end
  end
  return list
end

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

local function fishSpecies(mod, mapId, enc)
  local waterOk = enc and hasSlots(enc.water)
  local superGroup = superRodGroup(mod, mapId)
  if not waterOk and not superGroup then
    return nil
  end

  local list, seen = {}, {}
  local rods = fishingRods(mod)

  local old = rods.OLD_ROD
  if type(old) == "table" and type(old.always) == "table" then
    appendUnique(list, seen, old.always.species)
  end

  local good = rods.GOOD_ROD
  if type(good) == "table" and type(good.pool) == "table" then
    for _, slot in ipairs(good.pool) do
      if type(slot) == "table" then
        appendUnique(list, seen, slot.species)
      end
    end
  end

  if superGroup then
    for _, slot in ipairs(superGroup) do
      if type(slot) == "table" then
        appendUnique(list, seen, slot.species)
      end
    end
  end

  if #list == 0 then return nil end
  return list
end

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
      species = speciesFromSlots(enc.grass.slots),
    }
  end

  if enc and hasSlots(enc.water) then
    sections[#sections + 1] = {
      id = "water",
      title = "WATER",
      species = speciesFromSlots(enc.water.slots),
    }
  end

  local fish = fishSpecies(mod, mapId, enc)
  if fish then
    sections[#sections + 1] = {
      id = "fish",
      title = "FISH",
      species = fish,
    }
  end

  return sections
end

local function mapLabel(mod, mapId)
  local map = mod.content.maps:get(mapId)
  if type(map) == "table" then
    return map.label or map.id or mapId
  end
  return mapId
end

local function isSeen(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.seen and dex.seen[speciesId] and true or false
end

local function isOwned(game, speciesId)
  local dex = game and game.save and game.save.pokedex
  return dex and dex.owned and dex.owned[speciesId] and true or false
end

-- Tiny pokeball drawn with primitives (pure B/W for GB / SGB palettes).
local function drawPokeball(cx, cy, r)
  r = r or 4
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.arc("fill", "pie", cx, cy, r, math.pi, math.pi * 2)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.line(cx - r, cy, cx + r, cy)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.circle("fill", cx, cy, 1.6)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.circle("line", cx, cy, 1.6)
end

-- ------- screen

local function buildRows(mod, game, mapId)
  local sections = collect(mod, mapId)
  local rows = {}
  for _, section in ipairs(sections) do
    rows[#rows + 1] = { kind = "header", text = section.title }
    for _, speciesId in ipairs(section.species) do
      local def = mod.content.pokemon:get(speciesId)
      local seen = isSeen(game, speciesId)
      local owned = isOwned(game, speciesId)
      local name = (def and def.name) or speciesId
      rows[#rows + 1] = {
        kind = "mon",
        id = speciesId,
        seen = seen,
        owned = owned,
        name = seen and name or "?????",
        path = def and def.spriteFront,
      }
    end
  end
  return rows
end

local function preloadSprites(rows)
  local images = {}
  for _, row in ipairs(rows) do
    if row.kind == "mon" and row.path and images[row.path] == nil then
      local ok, img = pcall(love.graphics.newImage, row.path)
      images[row.path] = ok and img or false
    end
  end
  return images
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

local function currentMapId(mod)
  if not (mod.world and mod.world.current) then return nil end
  local cur = mod.world:current()
  return cur and cur.mapId or nil
end

local function screenFactory(mod)
  return {
    new = function(game)
      local Font = mod.ui.Font
      local mapId = currentMapId(mod)
      local rows = buildRows(mod, game, mapId)
      local images = preloadSprites(rows)
      local label = mapId and mapLabel(mod, mapId) or "UNKNOWN"

      local self = {
        game = game,
        isOpaque = true,
        rows = rows,
        images = images,
        mapLabel = label,
        scroll = 0,
      }

      function self:update(_dt)
        local input = self.game.input
        if input:wasPressed("b") or input:wasPressed("a") then
          self.game.stack:pop()
          return
        end
        local view = LIST_BOTTOM - LIST_TOP
        if input:wasPressed("up") then
          self.scroll = clampScroll(self.scroll - ROW_H, self.rows)
        elseif input:wasPressed("down") then
          self.scroll = clampScroll(self.scroll + ROW_H, self.rows)
        elseif input:wasPressed("left") then
          self.scroll = clampScroll(self.scroll - view, self.rows)
        elseif input:wasPressed("right") then
          self.scroll = clampScroll(self.scroll + view, self.rows)
        end
      end

      function self:draw()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 160, 144)
        Font.drawBox(0, 0, 20, 18)

        love.graphics.setColor(0, 0, 0, 1)
        Font.draw("DEX RADAR", 8, 8)
        Font.draw(self.mapLabel, 8, 18)

        if #self.rows == 0 then
          Font.draw("NO WILD", 8, 56)
          Font.draw("POKEMON", 8, 68)
          Font.draw("B: BACK", 8, 128)
          return
        end

        love.graphics.setScissor(0, LIST_TOP, 160, LIST_BOTTOM - LIST_TOP)
        local y = LIST_TOP - self.scroll
        for _, row in ipairs(self.rows) do
          local h = rowHeight(row)
          if y + h > LIST_TOP and y < LIST_BOTTOM then
            if row.kind == "header" then
              love.graphics.setColor(0, 0, 0, 1)
              Font.draw(row.text, 8, y)
            else
              local img = row.path and self.images[row.path]
              if img then
                local iw, ih = img:getDimensions()
                local scale = math.min(SPRITE_MAX / iw, SPRITE_MAX / ih, 1)
                local sx = 8
                local sy = y + math.floor((ROW_H - ih * scale) / 2)
                if row.seen then
                  love.graphics.setColor(1, 1, 1, 1)
                else
                  love.graphics.setColor(0, 0, 0, 1)
                end
                love.graphics.draw(img, sx, sy, 0, scale, scale)
              else
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("line", 8, y + 4, SPRITE_MAX, SPRITE_MAX)
              end
              love.graphics.setColor(0, 0, 0, 1)
              local nameX, nameY = 40, y + 8
              Font.draw(row.name, nameX, nameY)
              if row.owned and row.seen then
                local textW = (Font.width and Font.width(row.name)) or (#row.name * 8)
                drawPokeball(nameX + textW + 6, nameY + 3, 4)
              end
            end
          end
          y = y + h
        end
        love.graphics.setScissor()

        love.graphics.setColor(0, 0, 0, 1)
        Font.draw("B: BACK", 8, 128)
      end

      return self
    end,
  }
end

-- ------- entry

return function(mod)
  mod.options:define({
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

  mod.exports.collect = function(_game, mapId)
    if not mapId and mod.world and mod.world.current then
      local cur = mod.world:current()
      mapId = cur and cur.mapId
    end
    return collect(mod, mapId)
  end
end
