local NTCharacterAfflictions = require("NT.characterafflictions")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat
local NTBloodType = require("NT.bloodtype")

local M = {}

M.BloodType = NTBloodType

local A = {
  cardiacArrest = NTA.Require(NTAffliction, "cardiacarrest"),
  respiratoryArrest = NTA.Require(NTAffliction, "respiratoryarrest"),
  lungRemoved = NTA.Require(NTAffliction, "lungremoved"),
  antibiotics = NTA.Require(NTAffliction, "afantibiotics"),
  liverDamage = NTA.Require(NTAffliction, "liverdamage"),
  bloodLoss = NTA.Require(NTAffliction, "bloodloss"),
  bloodPressure = NTA.Require(NTAffliction, "bloodpressure"),
  hypoventilation = NTA.Require(NTAffliction, "hypoventilation"),
  artificalRespiration = NTA.Require(NTAffliction, "alv"),
  cpr = NTA.Require(NTAffliction, "cpr_buff"),
  kidneyDamage = NTA.Require(NTAffliction, "kidneydamage"),
  tamponade = NTA.Require(NTAffliction, "tamponade"),
  pressureDrug = NTA.Require(NTAffliction, "afpressuredrug"),
  anesthesia = NTA.Require(NTAffliction, "anesthesia"),
  adrenaline = NTA.Require(NTAffliction, "afadrenaline"),
  saline = NTA.Require(NTAffliction, "afsaline"),
  ringers = NTA.Require(NTAffliction, "afringerssolution"),
  alcoholWithdrawal = NTA.Require(NTAffliction, "alcoholwithdrawal"),
  traumaticshock = NTA.Require(NTAffliction, "traumaticshock"),
  fibrillation = NTA.Require(NTAffliction, "fibrillation"),
  stasis = NTA.Require(NTAffliction, "stasis"),
  immunity = NTA.Require(NTAffliction, "immunity"),
  streptokinase = NTA.Require(NTAffliction, "afstreptokinase"),
  acidosis = NTA.Require(NTAffliction, "acidosis"),
  alkalosis = NTA.Require(NTAffliction, "alkalosis"),
  vomiting = NTA.Require(NTAffliction, "sym_vomiting"),
  nausea = NTA.Require(NTAffliction, "nausea"),
}

local S = {
  clottingRate = NTA.Require(NTStat, "clottingrate"),
  healingRate = NTA.Require(NTStat, "healingrate"),
  bloodAmount = NTA.Require(NTStat, "bloodamount"),
  availableOxygen = NTA.Require(NTStat, "availableoxygen"),
}

NTA.Register(NTAffliction({
  id = "sepsis",
  update = function(self, c)
    if c:get(A.antibiotics) > 0 then
      self:add(-1 * c.deltaTime)
    end

    if c:get(A.stasis) > 0 then
      return
    end

    if self.value > 0 then
      self:add(0.05 * c.deltaTime)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "internalbleeding",
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    local v = self:add(-0.02 * c:get(S.clottingRate))
    if v > 0 then
      c:add(A.bloodLoss, (1 / 40) * v * c.deltaTime)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "bloodloss",
  max = 200,
}))

NTA.Register(NTStat({
  id = "bloodamount",
  max = 100,
  init = function(self, c)
    self:set(100 * (1 - c:getRatio(A.bloodLoss)))
  end,
}))

NTA.Register(NTStat({
  id = "clottingrate",
  max = 100,
  default = 1,
  init = function(self, c)
    local r = 1

    r = r * c:get(S.healingRate)
    r = r * NTC.GetMultiplier(c.character, "clottingrate")

    -- the liver is responsible for clotting factors
    r = r * (1 - c:getRatio(A.liverDamage))

    -- blood thinners reduce clotting
    local streptokinase = c:getRatio(A.streptokinase)
    if streptokinase > 0 then
      r = r * 0.02
    end

    self:multiply(r)
  end,
}))

NTA.Register(NTAffliction({
  id = "bloodpressure",
  min = 5,
  max = 200,
  default = 100,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    local bp = c:getRatio(S.bloodAmount)

    -- -50% at 100% tamponade
    bp = bp - (c:getRatio(A.tamponade) / 2)

    -- -45% for blood pressure medication
    bp = bp - math.min(0.45, 5 * c:getRatio(A.pressureDrug))

    -- -15% for propofol
    bp = bp - math.min(0.15, c:getRatio(A.anesthesia))

    -- +30% for adrenaline
    bp = bp + math.min(0.3, c:getRatio(A.adrenaline) * 10)

    -- +30% for saline
    bp = bp + math.min(0.3, 5 * c:getRatio(A.saline))

    -- +30% for ringers
    bp = bp + math.min(0.3, 5 * c:getRatio(A.ringers))

    -- x0.5 if full liver damage
    bp = bp * (1 + 0.5 * (c:getRatio(A.liverDamage) ^ 2))

    -- x0.5 if full kidney damage
    bp = bp * (1 + 0.5 * (c:getRatio(A.kidneyDamage) ^ 2))

    -- x0.5 if full alcohol withdrawal
    bp = bp * (1 + math.min(0.5, c:getRatio(A.alcoholWithdrawal)))

    -- 0 at >=50% traumatic shock
    bp = bp * (1 - math.min(1, 2 * c:getRatio(A.traumaticshock)))

    -- 0 at full fibrillation
    bp = bp * (1 - c:getRatio(A.fibrillation))

    -- 0 if cardiac arrest
    bp = bp * (1 - math.min(1, 100 * c:getRatio(A.cardiacArrest)))

    bp = bp * NTC.GetMultiplier(c.character, "bloodpressure")
    bp = bp * 100

    local lerp = 0.2

    -- increases in bp are 3x slower
    if bp > self.value then
      lerp = lerp / 3
    end

    -- avoid agonizingly slow transitions
    local delta = math.abs(bp - self.value)
    if delta < 0.05 then
      lerp = 1
    elseif delta < 0.5 then
      lerp = 0.5
    end

    -- transition to the new value over time
    local newValue = math.round(math.lerp(self.value, bp, lerp), 2)
    self:add(newValue - self.value)
  end,
}))

NTA.Register(NTAffliction({
  id = "hypoxemia",
  max = 100,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    local gain = NTC.GetMultiplier(c.character, "hypoxemiagain")

    local d = 0

    -- loss because of low blood pressure (+10 at 0 bp)
    d = d - math.min(0, (c:get(A.bloodPressure) - 70) / 7) * gain

    -- loss because of low blood amount (+15 at 0 blood)
    d = d - 100 * math.min(0, (c:getRatio(S.bloodAmount) - 0.6) / 4) * gain

    local requiredO2 = (-c:get(S.availableOxygen) + 50) / 8
    if requiredO2 > 0 then
      -- not enough oxygen, increase hypoxemia
      d = d + requiredO2 * gain
    else
      -- enough oxygen, decrease hypoxemia
      local max = math.clamp((50 - c:get(S.bloodAmount)) / 50, 0, 1)
      d = d + math.lerp(requiredO2 * 2, 0, max)
    end

    self:add(d * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "acidosis",
  update = function(self, c)
    local alkalosis = c:get(A.alkalosis)
    if self.value > 0 and alkalosis > 0 then
      local d = math.min(self.value, alkalosis)
      self:add(-d)
    end

    if c:get(A.stasis) > 0 then
      return
    end

    self:add(-0.03 * c.deltaTime)

    if c:get(A.hypoventilation) > 0 then
      self:add(0.09 * c.deltaTime)
    end

    local ra = c:getRatio(A.respiratoryArrest) > 0
    local alv = c:get(A.artificalRespiration) > 0
    local ca = c:getRatio(A.cardiacArrest) > 0
    local cpr = c:get(A.cpr) > 0
    if (ra and not alv) or (ca and not cpr) then
      self:add(0.18 * c.deltaTime)
    end

    local kd = c:getRatio(A.kidneyDamage)
    if kd > 0.8 then
      self:add((kd - 0.8) * c.deltaTime)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "alkalosis",
  update = function(self, c)
    local acidosis = c:get(A.acidosis)
    if self.value > 0 and acidosis > 0 then
      local d = math.min(self.value, acidosis)
      self:add(-d)
    end

    if c:get(A.stasis) > 0 then
      return
    end

    local d = -0.03

    if c:get(A.vomiting) > 0 then
      d = d + 0.09
    end

    if c:get(A.nausea) > 0 then
      d = d + 0.1
    end

    self:add(d * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "hemotransfusionshock",
}))

NTA.Register(NTAffliction({
  id = "immunity",
  update = function(self, c)
    if self.value < 5 then
      -- assume it has been wiped by "revive" or "heal all"
      local bloodType = NTBloodType.FromCharacter(c.character)
      if bloodType == nil then
        -- first-time character initialization
        self:set(100)
        bloodType = NTBloodType.Random()
        bloodType:assignToCharacter(c.character)
      else
        self:set(5)
      end
    end
  end,
}))

return M
