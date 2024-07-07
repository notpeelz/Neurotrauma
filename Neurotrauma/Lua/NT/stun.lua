local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat

local A = {
  anesthesia = NTA.Require(NTAffliction, "anesthesia"),
  adrenaline = NTA.Require(NTAffliction, "afadrenaline"),
  table = NTA.Require(NTAffliction, "table"),
  drunk = NTA.Require(NTAffliction, "drunk"),
  spinalCordInjury = NTA.Require(NTAffliction, "t_paralysis"),
  vomiting = NTA.Require(NTAffliction, "sym_vomiting"),
  nausea = NTA.Require(NTAffliction, "sym_nausea"),
  unconsciousness = NTA.Require(NTAffliction, "sym_unconsciousness"),
  opiateOverdose = NTA.Require(NTAffliction, "opiateoverdose"),
}

local S = {
  speedMultiplier = NTA.Require(NTStat, "speedmultiplier"),
  withdrawal = NTA.Require(NTStat, "withdrawal"),
}

NTA.Register(NTAffliction({
  id = "givein",
  max = 1,
  update = function(self, c)
    if c:get(A.spinalCordInjury) > 0 or c:get(A.unconsciousness) > 0 then
      self:set(1)
    else
      self:set(0)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "lockedhands",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "stun",
  max = 30,
  update = function(self, c)
    if self.value < 5 and (c:get(A.spinalCordInjury) > 0 or c:getRatio(A.anesthesia) > 0.15) then
      self:set(5)
    end
  end,
  apply = function(self, c)
    c.character.Stun = self:getUncommitted()
  end,
}))

NTA.Register(NTAffliction({
  id = "concussion",
  max = 10,
  update = function(self, c)
    local newValue = self:add(-0.01 * c.deltaTime)
    if newValue <= 0 then
      return
    end

    -- cause headaches, blurred vision, nausea, confusion
    if NTU.Chance(math.min(0.02, 0.08 * newValue / self.def.max)) then
      local case = math.random(4)

      if case == 1 then
        NTC.SetSymptomTrue(c.character, "sym_nausea", 5 + 10 * math.random())
      elseif case == 2 then
        NTC.SetSymptomTrue(c.character, "sym_blurredvision", 5 + 9 * math.random())
      elseif case == 3 then
        NTC.SetSymptomTrue(c.character, "sym_headache", 6 + 8 * math.random())
      elseif case == 4 then
        NTC.SetSymptomTrue(c.character, "sym_confusion", 6 + 8 * math.random())
      end
    end
  end,
}))

NTA.Register(NTStat({
  id = "speedmultiplier",
  default = 1,
  max = 1,
  init = function(self, c)
    if c:get(A.spinalCordInjury) > 0 then
      self:set(0)
      return
    end

    if c:get(A.vomiting) > 0 then
      self:multiply(0.8)
    end

    if c:get(A.nausea) > 0 then
      self:multiply(0.9)
    end

    if c:get(A.anesthesia) > 0 then
      self:multiply(0.5)
    end

    if c:get(A.opiateOverdose) > 0 then
      self:multiply(0.5)
    end

    local withdrawal = c:getRatio(S.withdrawal)
    if withdrawal > 0.8 then
      self:multiply(0.5)
    elseif withdrawal > 0.4 then
      self:multiply(0.7)
    elseif withdrawal > 0.2 then
      self:multiply(0.9)
    end

    local drunk = c:getRatio(A.drunk)
    if drunk > 0.8 then
      self:multiply(0.5)
    elseif drunk > 0.4 then
      self:multiply(0.7)
    elseif drunk > 0.2 then
      self:multiply(0.9)
    end

    local adrenaline = c:getRatio(A.adrenaline)
    if adrenaline > 0 then
      self:add(adrenaline)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "slowdown",
  max = 100,
  apply = function(self, c)
    -- if self:isModified() then
    --   warn("slowdown is immutable")
    -- end
    local slowdown = 1 - c:get(S.speedMultiplier)
    self:set(self.def.max * slowdown)
    NTAffliction.Apply(self, c)
  end,
}))
