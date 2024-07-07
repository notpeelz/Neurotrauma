local NTOrgans = require("NT.organs")
local NTOrgansBase = require("NT.organs.base")
local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction
local NTStat = NTA.Stat

local A = {
  stasis = NTA.Require(NTAffliction, "stasis"),
  retractedSkin = NTA.Require(NTLimbAffliction, "retractedskin"),
  internalBleeding = NTA.Require(NTAffliction, "internalbleeding"),
  unconsciousness = NTA.Require(NTAffliction, "sym_unconsciousness"),
  traumaticShock = NTA.Require(NTAffliction, "traumaticshock"),
  cerebralHypoxia = NTA.Require(NTAffliction, "cerebralhypoxia"),
  hypoxemia = NTA.Require(NTAffliction, "hypoxemia"),
  lungRemoved = NTA.Require(NTAffliction, "lungremoved"),
  brainRemoved = NTA.Require(NTAffliction, "brainremoved"),
  opiateOverdose = NTA.Require(NTAffliction, "opiateoverdose"),
  lungDamage = NTA.Require(NTAffliction, "lungdamage"),
  needle = NTA.Require(NTAffliction, "needlec"),
  radiationSickness = NTA.Require(NTAffliction, "radiationsickness"),
  respiratoryArrest = NTA.Require(NTAffliction, "respiratoryarrest"),
  pneumothorax = NTA.Require(NTAffliction, "pneumothorax"),
  cardiacArrest = NTA.Require(NTAffliction, "cardiacarrest"),
  fibrillation = NTA.Require(NTAffliction, "fibrillation"),
}

local S = {
  bloodAmount = NTA.Require(NTStat, "bloodamount"),
  healingRate = NTA.Require(NTStat, "healingrate"),
  newOrganDamage = NTA.Require(NTStat, "neworgandamage"),
  specificOrganDamageHealMultiplier = NTA.Require(NTStat, "specificOrganDamageHealMultiplier"),
}

NTOrgans.Register(
  "lungs",
  NTOrgansBase.Extend(function(base)
    return {
      limbType = LimbType.Torso,
      skillRequirement = 50,
      getName = function(self, _args)
        return "lung"
      end,
      onExtractSuccess = function(self, args)
        local t = args.targetCharacter
        local u = args.usingCharacter
        HF.SetAffliction(t, "pneumothorax", 0, u)
        HF.SetAffliction(t, "needlec", 0, u)
        return base.onExtractSuccess(self, args)
      end,
    }
  end)
)

NTA.Register(NTAffliction({
  id = "lungdamage",
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    self:add(
      -0.01 * c:get(S.healingRate) * c:get(S.specificOrganDamageHealMultiplier) * c.deltaTime
    )

    local gain = NTC.GetMultiplier(c.character, "lungdamagegain")
    local dmg = c:get(S.newOrganDamage)
      + (0.25 * math.max(0, c:getRatio(A.radiationSickness) - 0.25))
    self:add(gain * dmg * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "lungremoved",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:getRatio(LimbType.Torso, A.retractedSkin) > 0.99 then
      self:set(100)
    else
      self:set(1)
    end
  end,
}))

-- artifical ventilation
NTA.Register(NTAffliction({
  id = "alv",
}))

NTA.Register(NTAffliction({
  id = "respiratoryarrest",
  update = function(self, c)
    self:add(-0.05 * c.deltaTime)
    if c:get(A.unconsciousness) <= 0 then
      self:add(-0.45 * c.deltaTime)
    end

    if NTC.GetSymptomFalse(c.character, "triggersym_respiratoryarrest") then
      return
    end

    local brainHypoxia = c:getRatio(A.cerebralHypoxia)
    local bloodHypoxia = c:getRatio(A.hypoxemia)

    if
      NTC.GetSymptom(c.character, "triggersym_respiratoryarrest")
      or c:get(A.stasis) > 0
      or c:get(A.lungRemoved) > 0
      or c:get(A.brainRemoved) > 0
      or c:getRatio(A.opiateOverdose) > 0.6
      or (c:getRatio(A.lungDamage) > 0.99 and NTU.Chance(0.8))
      or (c:getRatio(A.traumaticShock) > 0.3 and NTU.Chance(0.2))
      or ((brainHypoxia > 0.5 or bloodHypoxia > 0.7) and NTU.Chance(0.05))
    then
      self:add(10)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "pneumothorax",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:get(A.needle) > 0 then
      self:add(-0.5 * c.deltaTime)
    else
      self:add(0.5 * c.deltaTime)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "needlec",
  update = function(self, c)
    self:add(-0.15 * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "hypoventilation",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTAffliction({
  id = "hyperventilation",
  update = function(self, c)
    -- TODO
  end,
}))

NTA.Register(NTStat({
  id = "availableoxygen",
  max = 100,
  init = function(self, c)
    if c:get(A.cardiacArrest) > 1 then
      return
    end

    if c:get(A.lungRemoved) > 1 then
      return
    end

    local o2 = math.clamp(c.character.Oxygen, 0, 100)
    -- 100% fibrillation stops blood oxygenation
    o2 = o2 * (1 - c:getRatio(A.fibrillation))

    -- 100% pneumothorax cancels out hypoxemia regen
    o2 = 100 * math.min(o2, 1 - c:getRatio(A.pneumothorax) / 2)

    self:set(o2)
  end,
}))

NTA.Register(NTAffliction({
  id = "oxygenlow",
  max = 200,
  update = function(self, c)
    if c:get(A.respiratoryArrest) > 0 then
      self:add(15 * c.deltaTime)
    end
  end,
}))

NT.ItemMethods.lungtransplant = function(item, usingCharacter, targetCharacter, limb)
  local limbtype = limb.type
  local conditionmodifier = 0
  if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
    conditionmodifier = -40
  end
  local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
  if
    HF.HasAffliction(targetCharacter, "lungremoved", 1)
    and limbtype == LimbType.Torso
    and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
  then
    HF.AddAffliction(targetCharacter, "lungdamage", -workcondition, usingCharacter)
    HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
    HF.SetAffliction(targetCharacter, "lungremoved", 0, usingCharacter)
    HF.RemoveItem(item)

    local rejectionchance = HF.Clamp(
      (HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
        / 150
        * NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
      0,
      1
    )
    if NTU.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
      HF.SetAffliction(targetCharacter, "lungdamage", 100)
    end
  end
end

NT.ItemStartsWithMethods.lungtransplant_q = NT.ItemMethods.lungtransplant
