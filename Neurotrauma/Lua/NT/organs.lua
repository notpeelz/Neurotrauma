local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat

local A = {
  stasis = NTA.Require(NTAffliction, "stasis"),
  thiamine = NTA.Require(NTAffliction, "afthiamine"),
  hypoxemia = NTA.Require(NTAffliction, "hypoxemia"),
  radiationSickness = NTA.Require(NTAffliction, "radiationsickness"),
  sepsis = NTA.Require(NTAffliction, "sepsis"),
}

local S = {
  healingRate = NTA.Require(NTStat, "healingrate"),
  newOrganDamage = NTA.Require(NTStat, "neworgandamage"),
}

local M = {
  _entries = {},
}

function M.Get(id)
  return M._entries[id]
end

function M.Iterator()
  return pairs(M._entries)
end

function M.Register(id, o)
  assert(o.limbType ~= nil, "invalid limbType")
  assert(type(o.minCondition) == "number" and o.minCondition >= 0, "invalid minCondition")
  assert(
    o.skillRequirement ~= nil and type(o.skillRequirement) == "number",
    "invalid skillRequirement"
  )

  local fns = {
    "getName",
    "getTransplantItemId",
    "getDamage",
    "canExtractOrgan",
    "onExtractSuccess",
    "onExtractFail",
  }

  for f in fns do
    assert(type(o[f]) == "function", "invalid or missing organ fn: " .. f)
  end

  M._entries[id] = o
end

-- local function organDamageCalc(c, damagevalue)
--   if damagevalue >= 99 then
--     return 100
--   end
--   return damagevalue
--     - 0.01 * c.stats.healingrate * c.stats.specificOrganDamageHealMultiplier * NT.Deltatime
-- end

NTA.Register(NTAffliction({
  id = "bonedamage",
  update = function(c, a)
    -- if c.stats.stasis then
    --   return
    -- end

    -- a.strength = NT.organDamageCalc(
    --   c,
    --   c.afflictions.bonedamage.strength
    --     + NTC.GetMultiplier(c.character, "bonedamagegain")
    --       * (c.afflictions.sepsis.strength / 500 + c.afflictions.hypoxemia.strength / 1000 + math.max(
    --         c.afflictions.radiationsickness.strength - 25,
    --         0
    --       ) / 600)
    --       * dt
    -- )

    -- if a.strength < 90 then
    --   a.strength = a.strength - (c.stats.bonegrowthCount * 0.3) * dt
    -- elseif c.stats.bonegrowthCount >= 6 then
    --   a.strength = a.strength - 2 * dt
    -- end

    -- if c.afflictions.kidneydamage.strength > 70 then
    --   a.strength = a.strength + (c.afflictions.kidneydamage.strength - 70) / 30 * 0.15 * dt
    -- end
  end,
}))

NTA.Register(NTAffliction({
  id = "organdamage",
  max = 200,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end
    local heal = 0.03 * c:get(S.healingRate)
    self:add((c:get(S.newOrganDamage) - heal) * c.deltaTime)
  end,
}))

NTA.Register(NTStat({
  id = "neworgandamage",
  max = 100,
  init = function(self, c)
    local d = (1 / 3) * c:getRatio(A.sepsis)
      + 0.25 * c:getRatio(A.hypoxemia)
      + 0.25 * math.max(0, c:getRatio(A.radiationSickness) - 0.25)

    self:set(
      d * NTC.GetMultiplier(c.character, "anyorgandamage") * NTConfig.Get("NT_organDamageGain", 1)
    )
  end,
}))

NTA.Register(NTStat({
  id = "specificOrganDamageHealMultiplier",
  max = 100,
  init = function(self, c)
    self:set(NTC.GetMultiplier(c.character, "anyspecificorgandamage"))

    if c:get(A.thiamine) > 0 then
      self:add(4)
    end
  end,
}))

return M
