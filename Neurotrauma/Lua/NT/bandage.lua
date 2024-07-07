local NTA = require("NT.afflictions")
local NTLimbAffliction = NTA.LimbAffliction
local NTStat = NTA.Stat

local A = {
  burn = NTA.Require(NTLimbAffliction, "burn"),
  biteWounds = NTA.Require(NTLimbAffliction, "bitewounds"),
  bleeding = NTA.Require(NTLimbAffliction, "bleeding"),
  lacerations = NTA.Require(NTLimbAffliction, "lacerations"),
  gunshotWound = NTA.Require(NTLimbAffliction, "gunshotwound"),
  explosionDamage = NTA.Require(NTLimbAffliction, "explosiondamage"),
  bandaged = NTA.Require(NTLimbAffliction, "bandaged"),
  dirtyBandage = NTA.Require(NTLimbAffliction, "dirtybandage"),
}

local S = {
  speedMultiplier = NTA.Require(NTStat, "speedmultiplier"),
}

local function getDirty(c, limbType)
  local m = c:getRatio(A.burn, limbType)
    + c:getRatio(A.lacerations, limbType)
    + c:getRatio(A.gunshotWound, limbType)
    + c:getRatio(A.biteWounds, limbType)
    + c:getRatio(A.explosionDamage, limbType)

  -- all of the above afflictions have a maxstrength of 200
  m = m * 2

  return 0.1 + math.min(0.4, m) + c:getRatio(A.bleeding, limbType)
end

NTA.Register(NTLimbAffliction({
  id = "dirtybandage",
  targetLimbs = {
    LimbType.Head,
    LimbType.Torso,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
  },
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:get(A.bandaged, self.limbType) > 0 then
      -- this shouldn't be possible, but just in case...
      self:set(0)
      return
    end

    local dirty = getDirty(c, self.limbType)
    self:add(dirty * c.deltaTime)

    -- dirty bandages slow you down
    c:multiply(S.speedMultiplier, 0.9)
  end,
}))

NTA.Register(NTLimbAffliction({
  id = "bandaged",
  targetLimbs = {
    LimbType.Head,
    LimbType.Torso,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
  },
  update = function(self, c)
    if self.value <= 0 or c:get(A.dirtyBandage, self.limbType) > 0 then
      return
    end

    -- bandages decay into dirty bandages
    local dirty = getDirty(c, self.limbType)
    local newValue = self:add(-dirty * c.deltaTime)
    if newValue <= 0 then
      c:set(A.dirtyBandage, self.limbType, 1)
      self:set(0)
    end
  end,
}))

NTA.Register(NTLimbAffliction({
  id = "gypsumcast",
  targetLimbs = {
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
  },
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    -- leg casts slow you down
    if self.limbType == LimbType.LeftLeg or self.limbType == LimbType.RightLeg then
      c:multiply(S.speedMultiplier, 0.8)
    end

    local limbPrefixes = {
      [LimbType.LeftArm] = "la",
      [LimbType.RightArm] = "ra",
      [LimbType.LeftLeg] = "ll",
      [LimbType.RightLeg] = "rl",
    }
    local limbPrefix = limbPrefixes[self.limbType]
    assert(limbPrefix ~= nil)

    local heal = -1 / 3
    c:add(limbPrefix .. "_fracture", heal * c.deltaTime)
  end,
}))
