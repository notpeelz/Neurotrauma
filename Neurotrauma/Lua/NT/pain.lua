local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStatBool = NTA.StatBool

local A = {
  shockPain = NTA.Require(NTAffliction, "shockpain"),
  psychosis = NTA.Require(NTAffliction, "psychosis"),
  anesthesia = NTA.Require(NTAffliction, "anesthesia"),
  analgesia = NTA.Require(NTAffliction, "analgesia"),
  adrenaline = NTA.Require(NTAffliction, "afadrenaline"),
  table = NTA.Require(NTAffliction, "table"),
  drunk = NTA.Require(NTAffliction, "drunk"),
  stasis = NTA.Require(NTAffliction, "stasis"),
  unconsciousness = NTA.Require(NTAffliction, "sym_unconsciousness"),
  vomiting = NTA.Require(NTAffliction, "sym_vomiting"),
}

local S = {
  sedated = NTA.Require(NTStatBool, "sedated"),
}

NTA.Register(NTAffliction({ id = "shockpain" }))

NTA.Register(NTAffliction({
  id = "traumaticshock",
  update = function(self, c)
    local shouldReduce = false

    if c:get(S.sedated) and c:get(A.table) > 0 then
      shouldReduce = true
    end

    if c:getRatio(A.anesthesia) > 0.15 then
      shouldReduce = true
    end

    local d
    if shouldReduce then
      d = -2 * c.deltaTime
    else
      d = -0.5 * c.deltaTime
    end

    local newValue = self:add(d)
    if newValue > 5 and c:get(A.unconsciousness) < 0.1 then
      c:add(A.shockPain, 10 * c.deltaTime)
      c:add(A.psychosis, newValue / self.def.max * c.deltaTime)
    end
  end,
}))

NTA.Register(NTStatBool({
  id = "sedated",
  init = function(self, c)
    self:set(
      c:get(A.analgesia) > 0
        or c:get(A.anesthesia) > 10
        or c:get(A.adrenaline) > 0
        or c:get(A.drunk) > 30
        or c:get(A.stasis) > 0
    )
  end,
}))

NTA.Register(NTAffliction({
  id = "analgesia",
  max = 200,
}))

NTA.Register(NTAffliction({
  id = "anesthesia",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    -- cause bloody vomiting or hallucinations sometimes
    if not NTU.Chance(0.06) then
      return
    end

    -- TODO: API for symptoms? how do we refactor this?
    local case = math.random(7)
    if case == 1 then
      NTC.SetSymptomTrue(c.character, "sym_hematemesis", 5 + math.random() * 10)
    elseif case == 2 then
      NTC.SetSymptomTrue(c.character, "sym_blurredvision", 5 + math.random() * 10)
    elseif case == 3 then
      NTC.SetSymptomTrue(c.character, "sym_confusion", 5 + math.random() * 10)
    elseif case == 4 then
      NTC.SetSymptomTrue(c.character, "sym_fever", 5 + math.random() * 10)
    elseif case == 5 then
      NTC.SetSymptomTrue(c.character, "triggersym_seizure", 1 + math.random() * 2)
    elseif case == 6 then
      NT.Fibrillate(c.character, 5 + math.random() * 30)
    elseif case == 7 then
      c:add(A.psychosis, 10)
    end
  end,
}))
