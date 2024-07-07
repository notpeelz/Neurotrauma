local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction

local A = {
  cardiacArrest = NTA.Require(NTAffliction, "cardiacarrest"),
  implacable = NTA.Require(NTAffliction, "implacable"),
  acidosis = NTA.Require(NTAffliction, "acidosis"),
  stroke = NTA.Require(NTAffliction, "stroke"),
  hypoxemia = NTA.Require(NTAffliction, "hypoxemia"),
  stasis = NTA.Require(NTAffliction, "stasis"),
  brainRemoved = NTA.Require(NTAffliction, "brainremoved"),
  cerebralHypoxia = NTA.Require(NTAffliction, "cerebralhypoxia"),
  aorticRupture = NTA.Require(NTAffliction, "t_arterialcut"),
  opiateOverdose = NTA.Require(NTAffliction, "opiateoverdose"),
  seizure = NTA.Require(NTAffliction, "seizure"),
  stun = NTA.Require(NTAffliction, "stun"),
  coma = NTA.Require(NTAffliction, "coma"),
  respiratoryArrest = NTA.Require(NTAffliction, "respiratoryarrest"),
  heartAttack = NTA.Require(NTAffliction, "heartattack"),
  heartDamage = NTA.Require(NTAffliction, "heartdamage"),
  lungDamage = NTA.Require(NTAffliction, "lungdamage"),
  pneumothorax = NTA.Require(NTAffliction, "pneumothorax"),
  tamponade = NTA.Require(NTAffliction, "tamponade"),
  hemotransfusionShock = NTA.Require(NTAffliction, "hemotransfusionshock"),
}

NTA.Register(NTAffliction({
  id = "dyspnea",
  update = function(self, c)
    local hemotransfusionShock = c:getRatio(A.hemotransfusionShock)

    if
      not NTC.GetSymptomFalse(c.character, "dyspnea")
      and c:get(A.respiratoryArrest) <= 0
      and (
        NTC.GetSymptom(c.character, "dyspnea")
        or c:getRatio(A.heartAttack) > 0.01
        or c:getRatio(A.heartDamage) > 0.8
        or c:getRatio(A.hypoxemia) > 0.2
        or c:getRatio(A.lungDamage) > 0.45
        or c:getRatio(A.pneumothorax) > 0.4
        or c:getRatio(A.tamponade) > 0.1
        or (hemotransfusionShock > 0 and hemotransfusionShock < 0.7)
      )
    then
      self:set(2)
    else
      self:set(0)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "coma",
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    self:add(-0.2 * c.deltaTime)

    if NTC.GetSymptomFalse(c.character, "triggersym_coma") then
      return
    end

    local acidosis = c:getRatio(A.acidosis)
    if
      NTC.GetSymptom(c.character, "triggersym_coma")
      or (c:get(A.cardiacArrest) > 0 and NTU.Chance(0.05))
      or (c:get(A.stroke) > 0 and NTU.Chance(0.05))
      or (acidosis > 0.6 and NTU.Chance(0.05 + acidosis - 0.6))
    then
      PrintChat("COMA!")
      self:add(14)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_unconsciousness",
  update = function(self, c)
    if NTC.GetSymptomFalse(c.character, "sym_unconsciousness") then
      self:set(0)
      return
    end

    -- TODO: instead of checking for specific afflictions, maybe their update logic
    -- should give unconsciousness instead?
    local implacable = c:get(A.implacable) > 0
    local vitality = c.character.Vitality
    local hypoxemia = c:getRatio(A.hypoxemia)
    if
      NTC.GetSymptom(c.character, "sym_unconsciousness")
      or c:get(A.stasis) > 0
      or c:get(A.brainRemoved) > 0
      or (not implacable and (vitality <= 0 or hypoxemia > 0.8))
      or c:getRatio(A.cerebralHypoxia) > 0.5
      or c:get(A.coma) > 0
      or c:get(A.aorticRupture) > 0
      or c:get(A.seizure) > 0
      or c:getRatio(A.opiateOverdose) > 0.6
    then
      self:set(2)
      PrintChat("good for stun")
      if c:get(A.stun) < 7 then
        PrintChat("applying stun")
        c:add(A.stun, 7)
      end
    else
      self:set(0)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_vomiting",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_cough",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_paleskin",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_lightheadedness",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_blurredvision",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_confusion",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_headache",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_legswelling",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_weakness",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_wheezing",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_hematemesis",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_fever",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_abdomdiscomfort",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_bloating",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_jaundice",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_sweating",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_palpitations",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_craving",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "sym_scorched",
  update = function(self, c)
    -- TODO
  end,
}))

-- vanilla nausea
NTA.Register(NTAffliction({ id = "nausea" }))

NTA.Register(NTAffliction({
  id = "sym_nausea",
  update = function(self, c)
    -- TODO
  end,
}))
