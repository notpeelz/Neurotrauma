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
}

local S = {
  bloodAmount = NTA.Require(NTStat, "bloodamount"),
  healingRate = NTA.Require(NTStat, "healingrate"),
  newOrganDamage = NTA.Require(NTStat, "neworgandamage"),
  specificOrganDamageHealMultiplier = NTA.Require(NTStat, "specificOrganDamageHealMultiplier"),
}

NTOrgans.Register(
  "liver",
  NTOrgansBase.Extend(function(_base)
    return {
      limbType = LimbType.Torso,
      skillRequirement = 40,
    }
  end)
)

NTA.Register(NTAffliction({
  id = "liverdamage",
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    self:add(
      -0.01 * c:get(S.healingRate) * c:get(S.specificOrganDamageHealMultiplier) * c.deltaTime
    )

    local gain = NTC.GetMultiplier(c.character, "liverdamagegain")
    local dmg = c:get(S.newOrganDamage)
    local newValue = self:add(gain * dmg * c.deltaTime)

    if
      self:getRatio(newValue) > 0.99
      and not NTC.GetSymptom(c.character, "sym_hematemesis")
      and NTU.Chance(0.05)
    then
      -- if liver failed: 5% chance for 6-20 seconds of blood vomiting and internal bleeding
      NTC.SetSymptomTrue(c.character, "sym_hematemesis", math.random(3, 10))
      c:add(A.internalBleeding, 2)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "liverremoved",
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

NT.ItemMethods.livertransplant = function(item, usingCharacter, targetCharacter, limb)
  local limbtype = limb.type
  local conditionmodifier = 0
  if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
    conditionmodifier = -40
  end
  local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
  if
    HF.HasAffliction(targetCharacter, "liverremoved", 1)
    and limbtype == LimbType.Torso
    and HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbtype, 99)
  then
    HF.AddAffliction(targetCharacter, "liverdamage", -workcondition, usingCharacter)
    HF.AddAffliction(targetCharacter, "organdamage", -workcondition / 5, usingCharacter)
    HF.SetAffliction(targetCharacter, "liverremoved", 0, usingCharacter)
    HF.RemoveItem(item)

    local rejectionchance = HF.Clamp(
      (HF.GetAfflictionStrength(targetCharacter, "immunity", 0) - 10)
        / 150
        * NTC.GetMultiplier(usingCharacter, "organrejectionchance"),
      0,
      1
    )
    if NTU.Chance(rejectionchance) and NTConfig.Get("NT_organRejection", false) then
      HF.SetAffliction(targetCharacter, "liverdamage", 100)
    end
  end
end

NT.ItemStartsWithMethods.livertransplant_q = NT.ItemMethods.livertransplant
