local NTScheduler = require("NT.scheduler")
local NTOrgans = require("NT.organs")
local NTOrgansBase = require("NT.organs.base")
local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction
local NTStat = NTA.Stat

local A = {
  stasis = NTA.Require(NTAffliction, "stasis"),
  bloodPressure = NTA.Require(NTAffliction, "bloodpressure"),
  kidney1Removed = NTA.Require(NTAffliction, "kidney1removed"),
  kidney2Removed = NTA.Require(NTAffliction, "kidney2removed"),
  kidney1Damage = NTA.Require(NTAffliction, "kidney1damage"),
  kidney2Damage = NTA.Require(NTAffliction, "kidney2damage"),
  retractedSkin = NTA.Require(NTLimbAffliction, "retractedskin"),
}

local S = {
  bloodAmount = NTA.Require(NTStat, "bloodamount"),
  healingRate = NTA.Require(NTStat, "healingrate"),
  newOrganDamage = NTA.Require(NTStat, "neworgandamage"),
  specificOrganDamageHealMultiplier = NTA.Require(NTStat, "specificOrganDamageHealMultiplier"),
}

NTOrgans.Register(
  "kidney",
  NTOrgansBase.Extend(function(base)
    return {
      limbType = LimbType.Torso,
      skillRequirement = 30,
      minCondition = 5,
      getName = function(self, args)
        local t = args.targetCharacter

        if not HF.HasAffliction(t, A.kidney1Removed, 1) then
          return "kidney1"
        end

        if not HF.HasAffliction(t, A.kidney2Removed, 1) then
          return "kidney2"
        end

        return nil
      end,
      getTransplantItemId = function(self, args)
        -- kidney1 and kidney2 both give a "kidneytransplant" item
        args.name = "kidney"
        return base.getTransplantItemId(self, args)
      end,
    }
  end)
)

NTA.Register(NTAffliction({ id = "kidney1damage" }))
NTA.Register(NTAffliction({ id = "kidney2damage" }))

local kidneyDmgPrevious = {}
local kidneyDmgNext = {}

NTScheduler.AddTickCallback(function(_deltaTime)
  kidneyDmgPrevious = kidneyDmgNext
  kidneyDmgNext = {}
end)

NTA.Register(NTAffliction({
  id = "kidneydamage",
  max = 200,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    -- get the difference in kidney damage since last tick
    local newDmg = self.value
    local prevDmg = kidneyDmgPrevious[c.character] or newDmg
    local dmgDiff = newDmg - prevDmg

    local heal
    do
      local gain = NTC.GetMultiplier(c.character, "kidneydamagegain")
      -- hypertension will eventually cause enough kidney damage to outpace natural healing
      local bp = math.clamp((c:get(A.bloodPressure) - 120) / 160, 0, 0.5)
      local dmg = c:get(S.newOrganDamage) + bp
      local healingRate = 0.01 * c:get(S.healingRate) * c:get(S.specificOrganDamageHealMultiplier)
      heal = 0.5 * (healingRate - gain * dmg) * c.deltaTime
    end

    local hasKidney1 = c:get(A.kidney1Removed) <= 0
    local hasKidney2 = c:get(A.kidney2Removed) <= 0
    local kidney1Damage = c:get(A.kidney1Damage)
    local kidney2Damage = c:get(A.kidney2Damage)

    -- heal kidneys
    if hasKidney1 and kidney1Damage < 99 then
      c:add(A.kidney1Damage, -heal)
    end
    if hasKidney2 and kidney2Damage < 99 then
      c:add(A.kidney2Damage, -heal)
    end

    -- distribute the new damage between the kidneys
    -- NOTE: we require a difference of >0.0001 to avoid false positives due to floating-point inaccuracy
    if math.abs(dmgDiff) > 0.0001 then
      if hasKidney1 and hasKidney2 then
        local dmgPerKidney = dmgDiff / 2
        c:add(A.kidney1Damage, dmgPerKidney)
        c:add(A.kidney2Damage, dmgPerKidney)
      elseif hasKidney1 then
        c:add(A.kidney1Damage, dmgDiff)
      elseif hasKidney2 then
        c:add(A.kidney2Damage, dmgDiff)
      end
    end
  end,
  postUpdate = function(self, c)
    local hasKidney1 = c:getRatio(A.kidney1Removed) <= 0
    local hasKidney2 = c:getRatio(A.kidney2Removed) <= 0

    local kidneyDamage = 0
    if hasKidney1 then
      kidneyDamage = kidneyDamage + c:getUncommitted(A.kidney1Damage)
    end
    if hasKidney2 then
      kidneyDamage = kidneyDamage + c:getUncommitted(A.kidney2Damage)
    end

    -- at 120% kidney damage: 0% chance for vomiting
    -- at 200% kidney damage: 7% chance for vomiting
    if
      kidneyDamage >= 120
      and not NTC.GetSymptom(c.character, "sym_vomiting")
      and NTU.Chance((kidneyDamage - 120) / 40 * 0.07)
    then
      NTC.SetSymptomTrue(c.character, "sym_vomiting", math.random(3, 10))
    end

    self:set(kidneyDamage)
    kidneyDmgNext[c.character] = kidneyDamage
  end,
}))

NTA.Register(NTAffliction({
  id = "kidney1removed",
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

NTA.Register(NTAffliction({
  id = "kidney2removed",
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

NT.ItemMethods.kidneytransplant = function(item, usingCharacter, targetCharacter, limb)
  local limbType = limb.type
  if limbType ~= LimbType.Torso then
    return
  end

  if not HF.HasAfflictionLimb(targetCharacter, "retractedskin", limbType, 99) then
    return
  end

  local itemCondition = item.Condition
  if not HF.GetSurgerySkillRequirementMet(usingCharacter, 40) then
    itemCondition = itemCondition - 40
  end
  itemCondition = HF.Clamp(itemCondition, 0, 100)

  local targetKidney
  if HF.HasAffliction(targetCharacter, "kidney1removed", 1) then
    targetKidney = "kidney1"
  elseif HF.HasAffliction(targetCharacter, "kidney2removed", 1) then
    targetKidney = "kidney2"
  else
    return
  end

  -- if NTConfig.Get("NT_organRejection", false) then
  --   local immunity = HF.GetAfflictionStrength(targetCharacter, "immunity", 0)
  --   local rejectionChanceMult = NTC.GetMultiplier(usingCharacter, "organrejectionchance")
  --   local rejectionChance = HF.Clamp((immunity - 10) / 150 * rejectionChanceMult, 0, 1)
  --   if NTU.Chance(rejectionChance) then
  --     HF.RemoveItem(item)
  --     return
  --   end
  -- end

  HF.SetAffliction(targetCharacter, targetKidney .. "removed", 0, usingCharacter)
  HF.AddAffliction(targetCharacter, targetKidney .. "damage", -itemCondition, usingCharacter)
  HF.AddAffliction(targetCharacter, "organdamage", -itemCondition / 10, usingCharacter)
  HF.RemoveItem(item)
end

NT.ItemStartsWithMethods.kidneytransplant_q = NT.ItemMethods.kidneytransplant
