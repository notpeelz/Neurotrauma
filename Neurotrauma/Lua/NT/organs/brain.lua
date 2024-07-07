local NTOrgans = require("NT.organs")
local NTOrgansBase = require("NT.organs.base")
local NTU = require("NT.util")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction
local NTStat = NTA.Stat

local A = {
  stasis = NTA.Require(NTAffliction, "stasis"),
  hypoxemia = NTA.Require(NTAffliction, "hypoxemia"),
  radiationSickness = NTA.Require(NTAffliction, "radiationsickness"),
  sepsis = NTA.Require(NTAffliction, "sepsis"),
  liverDamage = NTA.Require(NTAffliction, "liverdamage"),
  kidneyDamage = NTA.Require(NTAffliction, "kidneydamage"),
  traumaticShock = NTA.Require(NTAffliction, "traumaticshock"),
  stroke = NTA.Require(NTAffliction, "stroke"),
  acidosis = NTA.Require(NTAffliction, "acidosis"),
  alkalosis = NTA.Require(NTAffliction, "alkalosis"),
  alcoholWithdrawal = NTA.Require(NTAffliction, "alcoholwithdrawal"),
  bloodPressure = NTA.Require(NTAffliction, "bloodpressure"),
  opiateOverdose = NTA.Require(NTAffliction, "opiateoverdose"),
  mannitol = NTA.Require(NTAffliction, "afmannitol"),
  afstreptokinase = NTA.Require(NTAffliction, "afstreptokinase"),
  retractedSkin = NTA.Require(NTLimbAffliction, "retractedskin"),
}

local S = {
  clottingRate = NTA.Require(NTStat, "clottingrate"),
  healingRate = NTA.Require(NTStat, "healingrate"),
}

NTOrgans.Register(
  "brain",
  NTOrgansBase.Extend(function(_base)
    return {
      limbType = LimbType.Head,
      skillRequirement = 100,
      getDamage = function(self, args)
        local t = args.targetCharacter
        return HF.GetAfflictionStrength(t, "cerebralhypoxia", 0)
      end,
      getTransplantItemId = function(self, _args)
        return "braintransplant"
      end,
      onExtractSuccess = function(self, args)
        local t = args.targetCharacter
        local u = args.usingCharacter

        HF.SetAffliction(t, "brainremoved", 100, u)
        HF.SetAffliction(t, "cerebralhypoxia", 100, u)

        if NTSP ~= nil then
          if HF.HasAffliction(t, "artificialbrain") then
            HF.SetAffliction(t, "artificialbrain", 0, u)
            return
          end
        end

        local itemId = self:getTransplantItemId(args)
        if itemId == nil then
          return
        end

        local client = HF.CharacterToClient(t)

        HF.GiveItemPlusFunction(itemId, function(e)
          local item = e.item
          local tags = {}

          if client ~= nil then
            local accountId = client.AccountId
            if accountId ~= nil then
              table.insert(tags, "brainclient:" .. accountId.StringRepresentation)
              item.Description = client.Name
              client.SetClientCharacter(nil)
            end
          end

          item.Tags = table.concat(tags, ",")
          item.Condition = 100 - args.damage
        end, nil, u)
      end,
      onExtractFail = function(self, args)
        local t = args.targetCharacter
        local u = args.usingCharacter

        HF.AddAfflictionLimb(t, "bleeding", self.limbType, 15, u)
        HF.AddAffliction(t, "cerebralhypoxia", 50, u)
        NT.InflictPain(t, u)
      end,
    }
  end)
)

NTA.Register(NTLimbAffliction({
  id = "spasm",
  targetLimbs = {
    LimbType.Torso,
    LimbType.Head,
    LimbType.LeftArm,
    LimbType.RightArm,
    LimbType.LeftLeg,
    LimbType.RightLeg,
  },
}))

NTA.Register(NTAffliction({
  id = "seizure",
  update = function(self, c)
    local newValue

    newValue = self:add(-1 * c.deltaTime)

    local alcoholWithdrawal = c:getRatio(A.alcoholWithdrawal)
    local opiateOverdose = c:getRatio(A.opiateOverdose)
    if
      NTC.GetSymptomFalse(c.character, "triggersym_seizure")
      and c:get(A.stasis) <= 0
      and (
        NTC.GetSymptom(c.character, "triggersym_seizure")
        or (c:getRatio(A.stroke) > 0.02 and NTU.Chance(0.05))
        or (c:getRatio(A.acidosis) > 0.6 and NTU.Chance(0.05))
        or (c:getRatio(A.alkalosis) > 0.6 and NTU.Chance(0.05))
        or NTU.Chance(0.1 * math.min(0.25, c:getRatio(A.radiationSickness)))
        or (alcoholWithdrawal > 0.5 and NTU.Chance(0.1 * alcoholWithdrawal))
        or (opiateOverdose > 0.6 and NTU.Chance(0.2 * opiateOverdose))
      )
    then
      newValue = self:add(10)
    end

    if self:getRatio(newValue) > 0.1 then
      -- TODO: get spasm's limbTypes with c:getDef()?
      for limbType in
        {
          LimbType.Torso,
          LimbType.Head,
          LimbType.LeftArm,
          LimbType.RightArm,
          LimbType.LeftLeg,
          LimbType.RightLeg,
        }
      do
        if NTU.Chance(0.5) then
          c:add(limbType, "spasm", 10)
        end
      end
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "stroke",
  max = 50,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    -- NOTE: strokes are hemorrhagic

    self:add(-0.05 * c:get(S.clottingRate) * c.deltaTime)

    if NTC.GetSymptomFalse(c.character, "triggersym_stroke") then
      return
    end

    local trigger = NTC.GetSymptom(c.character, "triggersym_stroke")

    local bp = c:get(A.bloodPressure)
    if bp > 150 then
      PrintChat("BP TOO HIGH")
      local chance = 0.02 * (bp - 150) / 50

      if c:get(A.streptokinase) > 0 then
        chance = chance + 0.05
      end

      if NTU.Chance(NTConfig.Get("NT_strokeChance", 1) * chance) then
        PrintChat("STROKE RNG!")
        trigger = true
      end
    end

    if trigger then
      PrintChat("STROKE!")
      self:add(5)
    end
  end,
}))

NTA.Register(NTAffliction({
  id = "cerebralhypoxia",
  max = 200,
  update = function(self, c)
    if c:get(A.stasis) > 0 then
      return
    end

    self:add(-0.1 * c:get(S.healingRate) * c.deltaTime)

    local dmg = (
      c:getRatio(A.hypoxemia)
      + math.min(c:getRatio(A.stroke), 0.2) * 0.1
      + c:getRatio(A.sepsis) * 0.4
      + c:getRatio(A.liverDamage) * 0.125
      + c:getRatio(A.kidneyDamage) * 0.1
      + c:getRatio(A.traumaticShock)
    )
      -- NTC multiplier
      * NTC.GetMultiplier(c.character, "neurotraumagain")
      -- config multiplier
      * NTConfig.Get("NT_neurotraumaGain", 1)
      -- mannitol reduces damage gain by up to 50%
      * (1 - math.min(c:get(A.mannitol), 0.5))

    self:add(dmg * c.deltaTime)
  end,
}))

NTA.Register(NTAffliction({
  id = "brainremoved",
  update = function(self, c)
    if self.value <= 0 then
      return
    end

    if c:getRatio(LimbType.Head, A.retractedSkin) > 0.99 then
      self:set(100)
    else
      self:set(1)
    end
  end,
}))

NT.ItemMethods.braintransplant = function(item, usingCharacter, targetCharacter, limb)
  local limbtype = limb.type
  local conditionmodifier = 0
  if not HF.GetSurgerySkillRequirementMet(usingCharacter, 100) then
    conditionmodifier = -40
  end
  local workcondition = HF.Clamp(item.Condition + conditionmodifier, 0, 100)
  if HF.HasAffliction(targetCharacter, "brainremoved", 1) and limbtype == LimbType.Head then
    HF.AddAffliction(targetCharacter, "cerebralhypoxia", -workcondition, usingCharacter)
    HF.SetAffliction(targetCharacter, "brainremoved", 0, usingCharacter)

    -- give character control to the donor
    if SERVER then
      local accountId = nil
      for tag in string.gmatch(item.Tags, "([^,]+)") do
        local s = string.match(tag, "^brainclient:(.+)$")
        if s ~= nil then
          accountId = s
          break
        end
      end

      -- brain has no owner (belongs to a bot?)
      if accountId == nil then
        return
      end

      local client = HF.GetClientByAccountId(accountId)
      if client ~= nil then
        client.SetClientCharacter(targetCharacter)
      end
    end

    HF.RemoveItem(item)
  end
end
