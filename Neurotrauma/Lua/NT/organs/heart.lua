local NTOrgans = require("NT.organs")
local NTOrgansBase = require("NT.organs.base")
local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat

local A = {
  stasis = NTA.Require(NTAffliction, "stasis"),
  hypoxemia = NTA.Require(NTAffliction, "hypoxemia"),
  sepsis = NTA.Require(NTAffliction, "sepsis"),
  traumaticShock = NTA.Require(NTAffliction, "traumaticshock"),
  acidosis = NTA.Require(NTAffliction, "acidosis"),
  alcoholWithdrawal = NTA.Require(NTAffliction, "alcoholwithdrawal"),
  bloodPressure = NTA.Require(NTAffliction, "bloodpressure"),
  heartAttack = NTA.Require(NTAffliction, "heartattack"),
  heartDamage = NTA.Require(NTAffliction, "heartdamage"),
  heartRemoved = NTA.Require(NTAffliction, "heartremoved"),
  brainRemoved = NTA.Require(NTAffliction, "brainremoved"),
  tamponade = NTA.Require(NTAffliction, "tamponade"),
  pressureDrug = NTA.Require(NTAffliction, "afpressuredrug"),
  adrenaline = NTA.Require(NTAffliction, "afadrenaline"),
  pneumothorax = NTA.Require(NTAffliction, "pneumothorax"),
  aorticRupture = NTA.Require(NTAffliction, "t_arterialcut"),
  tachycardia = NTA.Require(NTAffliction, "tachycardia"),
  fibrillation = NTA.Require(NTAffliction, "fibrillation"),
  cardiacArrest = NTA.Require(NTAffliction, "cardiacarrest"),
  coma = NTA.Require(NTAffliction, "coma"),
}

local S = {
  bloodAmount = NTA.Require(NTStat, "bloodamount"),
  healingRate = NTA.Require(NTStat, "healingrate"),
  newOrganDamage = NTA.Require(NTStat, "neworgandamage"),
  specificOrganDamageHealMultiplier = NTA.Require(NTStat, "specificOrganDamageHealMultiplier"),
}

NTOrgans.Register(
  "heart",
  NTOrgansBase.Extend(function(base)
    return {
      limbType = LimbType.Torso,
      skillRequirement = 60,
      onExtractSuccess = function(self, args)
        local t = args.targetCharacter
        local u = args.usingCharacter
        HF.SetAffliction(t, "tamponade", 0, u)
        HF.SetAffliction(t, "heartattack", 0, u)
        return base.onExtractSuccess(self, args)
      end,
    }
  end)
)

NTA.Register(NTAffliction({
  id = "heartdamage",
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    self:add(
      -0.01 * c:get(S.healingRate) * c:get(S.specificOrganDamageHealMultiplier) * c.deltaTime
    )

    local gain = NTC.GetMultiplier(c.character, "heartdamagegain")
    local dmg = c:get(S.newOrganDamage)
    if c:get(A.heartAttack) > 0 then
      dmg = dmg + 0.5
    end
    self:add(gain * dmg * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "heartremoved",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:getRatio(LimbType.Torso, "retractedskin") > 0.99 then
      self:set(100)
    else
      self:set(1)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "cardiacarrest",
  update = function(self, c)
    if NTC.GetSymptomFalse(c.character, "triggersym_cardiacarrest") then
      return
    end

    local heartDamage = c:getRatio(A.heartDamage)
    local traumaticShock = c:getRatio(A.traumaticShock)
    local coma = c:getRatio(A.coma)
    local hypoxemia = c:getRatio(A.hypoxemia)
    local fibrillation = c:getRatio(A.fibrillation)

    if
      NTC.GetSymptom(c.character, "triggersym_cardiacarrest")
      or c:get(A.stasis) > 0
      or c:get(A.heartRemoved) > 0
      or c:get(A.brainRemoved) > 0
      or (heartDamage > 0.99 and NTU.Chance(0.3))
      or (traumaticShock > 0.4 and NTU.Chance(0.1))
      or (coma > 0.4 and NTU.Chance(0.03))
      or (hypoxemia > 0.8 and NTU.Chance(0.01))
      or (fibrillation > 0.2 and NTU.Chance(fibrillation ^ 4))
    then
      self:add(10)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "tamponade",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:get(A.heartRemoved) > 0 then
      self:set(0)
      return
    end

    self:add(0.5 * c.deltaTime)
  end,
}))

local function getFibrillation(c)
  local fib = -0.1

  -- aortic rupture (very fast)
  fib = fib + math.min(2, 100 * c:getRatio(A.aorticRupture))

  -- acidosis (slow)
  fib = fib + math.min(0.5, 0.5 * 100 * c:getRatio(A.acidosis))

  -- low blood pressure
  local bp = 0.9
    - (1 / 90)
      * (
        c:get(A.bloodPressure)
        -- less fibrillation from low bp if bp-reducing medecine is active
        + math.min(20, 5 * 100 * c:getRatio(A.pressureDrug))
      )
  fib = fib + 2 * math.clamp(bp, 0, 1)

  -- hypoxemia
  fib = fib + 1.5 * c:getRatio(A.hypoxemia)

  -- traumatic shock (fast)
  fib = fib + 2.5 * math.max(0, c:getRatio(A.traumaticShock) - 0.05)

  -- faster defib with adrenaline
  if c:get(A.adrenaline) > 0 then
    -- fibrillate half as fast
    fib = 0.5 * (fib - 0.9)
  end

  return fib
    * NTC.GetMultiplier(c.character, "fibrillation")
    * NTConfig.Get("NT_fibrillationSpeed", 1)
end

NTA.Register(NTAffliction({
  id = "tachycardia",
  update = function(self, c)
    if
      c:get(A.cardiacArrest) > 0
      or c:get(A.heartRemoved) > 0
      -- tachycardia leads to fibrillation
      or c:get(A.fibrillation) > 0
    then
      self:set(0)
      return
    end

    if
      not NTC.GetSymptomFalse(c.character, "tachycardia")
      and self.value < 2
      and (
        NTC.GetSymptom(c.character, "tachycardia")
        or c:getRatio(A.sepsis) > 0.2
        or c:get(S.bloodAmount) < 60
        or c:getRatio(A.acidosis) > 0.2
        or c:getRatio(A.pneumothorax) > 0.3
        or c:get(A.adrenaline) > 0
        or c:getRatio(A.alcoholWithdrawal) > 0.75
      )
    then
      self:set(2)
    end

    local fib = getFibrillation(c)
    local newValue = self:add(5 * fib * c.deltaTime)

    if self:getRatio(newValue) >= 1 then
      c:set(A.fibrillation, 5)
      self:set(0)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "fibrillation",
  update = function(self, c)
    if self.value <= 0 or c:get(A.tachycardia) > 0 then
      return
    end

    if
      NTC.GetSymptomFalse(c.character, A.fibrillation)
      or c:get(A.cardiacArrest) > 0
      or c:get(A.heartRemoved) > 0
    then
      self:set(0)
      return
    end

    local fib = getFibrillation(c)
    self:add(fib * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "heartattack",
  update = function(self, c)
    -- TODO
  end,
}))

-- NT.Afflictions.heartattack = {
--   update = function(c, i)
--     c.afflictions[i].strength = c.afflictions[i].strength - NT.Deltatime

--     -- triggers
--     if
--       not NTC.GetSymptomFalse(c.character, "triggersym_heartattack")
--       and not c.stats.stasis
--       and c.afflictions.afstreptokinase.strength <= 0
--       and c.afflictions.heartremoved.strength <= 0
--       and (
--         NTC.GetSymptom(c.character, "triggersym_heartattack")
--         or (
--           c.afflictions.bloodpressure.strength > 150
--           and NTU.Chance(
--             NTConfig.Get("NT_heartattackChance", 1)
--               * ((c.afflictions.bloodpressure.strength - 150) / 50 * 0.02)
--           )
--         )
--       )
--     then
--       c.afflictions[i].strength = c.afflictions[i].strength + 50
--     end

--     if c.afflictions.heartremoved.strength > 0 then
--       c.afflictions[i].strength = 0
--     end
--   end,
-- }

NT.ItemMethods.hearttransplant = function(item, usingCharacter, targetCharacter, limb)
  local limbtype = limb.type
  local conditionmodifier = 0
  if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
    conditionmodifier = -40
  end
  local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
  if
    HF.HasAffliction(targetCharacter, "heartremoved", 1)
    and limbtype == LimbType.Torso
    and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
  then
    HF.AddAffliction(targetCharacter, "heartdamage", -workcondition, usingCharacter)
    HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
    HF.SetAffliction(targetCharacter, "heartremoved", 0, usingCharacter)
    HF.RemoveItem(item)

    local rejectionchance = HF.Clamp(
      (HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
        / 150
        * NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
      0,
      1
    )
    if NTU.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
      HF.SetAffliction(targetCharacter, "heartdamage", 100)
    end
  end
end

NT.ItemStartsWithMethods.hearttransplant_q = NT.ItemMethods.hearttransplant
