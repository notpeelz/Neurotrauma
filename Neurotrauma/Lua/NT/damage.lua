local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction
local NTStat = NTA.Stat

local A = {
  burn = NTA.Require(NTLimbAffliction, "burn"),
  burnDeg1 = NTA.Require(NTLimbAffliction, "burn_deg1"),
  burnDeg2 = NTA.Require(NTLimbAffliction, "burn_deg2"),
  burnDeg3 = NTA.Require(NTLimbAffliction, "burn_deg3"),
  bandaged = NTA.Require(NTLimbAffliction, "bandaged"),
  immunity = NTA.Require(NTAffliction, "immunity"),
}

local S = {
  healingRate = NTA.Require(NTStat, "healingrate"),
  clottingRate = NTA.Require(NTStat, "clottingrate"),
}

local function updateHealWithBandage(self, c)
  local heal = (1 / 30) * c:getRatio(A.immunity)
  if c:get(A.bandaged, self.limbType) > 0 then
    heal = heal + 0.1
  end
  self:add(-heal * c:get(S.healingRate) * c.deltaTime)
end

local targetLimbs = {
  LimbType.Head,
  LimbType.Torso,
  LimbType.LeftArm,
  LimbType.RightArm,
  LimbType.LeftLeg,
  LimbType.RightLeg,
}

NTA.Register(NTLimbAffliction({
  id = "lacerations",
  targetLimbs = targetLimbs,
  update = updateHealWithBandage,
}))

NTA.Register(NTLimbAffliction({
  id = "gunshotwound",
  targetLimbs = targetLimbs,
  update = updateHealWithBandage,
}))

NTA.Register(NTLimbAffliction({
  id = "bitewounds",
  targetLimbs = targetLimbs,
  update = updateHealWithBandage,
}))

NTA.Register(NTLimbAffliction({
  id = "explosiondamage",
  targetLimbs = targetLimbs,
  update = updateHealWithBandage,
}))

NTA.Register(NTLimbAffliction({
  id = "blunttrauma",
  targetLimbs = targetLimbs,
  update = updateHealWithBandage,
}))

NTA.Register(NTLimbAffliction({
  id = "bleeding",
  targetLimbs = targetLimbs,
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    local clottingRate = c:get(S.clottingRate)
    local heal = 0.1 * clottingRate

    -- TODO: infection probability (every 5s):
    -- 0-20%: 0
    -- 20-40%: 0.025
    -- 40-60%: 0.05
    -- 60-100%: 0.08

    self:add(-heal * c.deltaTime)
  end,
}))

NTA.Register(NTLimbAffliction({
  id = "burn",
  max = 200,
  targetLimbs = targetLimbs,
  update = function(self, c)
    -- TODO: replace vanilla affliction logic with Lua (and reimplement infection)
    local values = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
    }
    local degree = 0
    if self.value > 50 then
      degree = 3
      values[3] = math.max(5, (self.value - 50) / 50 * 100)
    elseif self.value > 20 then
      degree = 2
      values[2] = math.max(5, (self.value - 20) / 30 * 100)
    elseif self.value > 1 then
      degree = 1
      values[2] = self.value * 5
    end

    c:set(A.burnDeg1, self.limbType, values[1])
    c:set(A.burnDeg2, self.limbType, values[2])
    c:set(A.burnDeg3, self.limbType, values[3])

    -- 3rd-degree burns can't be healed with bandages
    if degree < 3 then
      updateHealWithBandage(self, c)
    end
  end,
}))

NTA.Register(NTLimbAffliction({
  id = "burn_deg1",
  max = 100,
  targetLimbs = targetLimbs,
}))

NTA.Register(NTLimbAffliction({
  id = "burn_deg2",
  max = 100,
  targetLimbs = targetLimbs,
}))

NTA.Register(NTLimbAffliction({
  id = "burn_deg3",
  max = 100,
  targetLimbs = targetLimbs,
}))

NTA.Register(NTLimbAffliction({
  id = "acidburn",
  max = 200,
  targetLimbs = targetLimbs,
  update = function(self, c)
    -- convert acid burns to regular burns
    if self.value > 0 then
      c:add(A.burn, self.limbType, self.value)
      self:set(0)
    end
  end,
}))
