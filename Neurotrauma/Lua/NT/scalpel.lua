local NTOrgans = require("NT.organs")
local NTHealthContextMenu = require("NT.healthcontextmenu")
local NTFeedbackSound = require("NT.feedbacksound")
local NTInteractiveItems = require("NT.interactiveitems")

local M = {}

local function Stab(limbType, targetCharacter, usingCharacter)
  local t = targetCharacter
  local u = usingCharacter

  HF.GiveItem(t, "ntsfx_slash")
  HF.AddAfflictionLimb(t, "bleeding", limbType, 15, u)
  HF.AddAfflictionLimb(t, "lacerations", limbType, 10, u)
  NT.InflictPain(t, u)
end

if SERVER and Game.IsMultiplayer then
  Networking.Receive("NT.scalpel.incision", function(msg, client)
    local characterId = msg.ReadUInt16()
    local limbType = msg.ReadByte()
    local character = Entity.FindEntityByID(characterId)
    if character == nil then
      return
    end
    M.InciseSkin(limbType, character, client.Character)
  end)
end

function M.InciseSkin(limbType, targetCharacter, usingCharacter)
  local t = targetCharacter
  local u = usingCharacter

  if CLIENT and Game.IsMultiplayer then
    assert(
      u == nil or u == Character.Controlled,
      "clients may not create incisions on behalf of other players"
    )
    local msg = Networking.Start("NT.scalpel.incision")
    msg.WriteUInt16(t.ID)
    msg.WriteByte(Byte(limbType))
    Networking.Send(msg)
    return
  end

  if
    -- doesn't work in stasis
    HF.HasAffliction(t, "stasis", 0.1)
    -- can't cut through a cast
    or HF.HasAfflictionLimb(t, "gypsumcast", limbType)
    -- skip if there's already an incision
    or HF.HasAfflictionLimb(t, "surgeryincision", limbType, 1)
  then
    NTFeedbackSound.Play("fail", u)
    return
  end

  -- use painkillers before stabbing patients plz
  if not HF.CanPerformSurgeryOn(t) then
    Stab(limbType, t, u)
    return
  end

  HF.GiveItem(t, "ntsfx_slash")

  if not HF.GetSurgerySkillRequirementMet(u, 30) then
    Stab(limbType, t, u)
    return
  end

  HF.AddAfflictionLimb(t, "surgeryincision", limbType, 1 + HF.GetSurgerySkill(t) / 2, u)
  HF.SetAfflictionLimb(t, "suturedi", limbType, 0, u)
  -- cut through the bandage, into the skin
  HF.SetAfflictionLimb(t, "bandaged", limbType, 0, u)
end

if SERVER and Game.IsMultiplayer then
  for organId in NTOrgans.Iterator() do
    local eventId = "NT.scalpel.extractOrgan." .. organId
    Networking.Receive(eventId, function(msg, client)
      local characterId = msg.ReadUInt16()
      local character = Entity.FindEntityByID(characterId)
      if character == nil then
        return
      end
      M.ExtractOrgan(organId, character, client.Character)
    end)
  end
end

function M.ExtractOrgan(organId, targetCharacter, usingCharacter)
  local t = targetCharacter
  local u = usingCharacter

  if CLIENT and Game.IsMultiplayer then
    assert(
      u == nil or u == Character.Controlled,
      "clients may not create incisions on behalf of other players"
    )
    local msg = Networking.Start("NT.scalpel.extractOrgan." .. organId)
    msg.WriteUInt16(t.ID)
    Networking.Send(msg)
    return
  end

  local o = NTOrgans.Get(organId)
  assert(o ~= nil, "invalid organId")

  if not HF.HasAfflictionLimb(t, "retractedskin", o.limbType, 99) then
    return
  end

  local name = o:getName({
    id = organId,
    targetCharacter = t,
    usingCharacter = u,
  })
  if name == nil then
    return
  end
  assert(type(name) == "string", "invalid getName return value")

  local damage = o:getDamage({
    id = organId,
    name = name,
    targetCharacter = t,
    usingCharacter = u,
  })
  assert(type(damage) == "number", "invalid getDamage return value")

  local canExtractOrgan = o:canExtractOrgan({
    id = organId,
    name = name,
    damage = damage,
    targetCharacter = t,
    usingCharacter = u,
  })
  assert(type(canExtractOrgan) == "boolean", "invalid canExtractOrgan return value")
  if not canExtractOrgan then
    return
  end

  HF.GiveItem(t, "ntsfx_slash")

  if not HF.GetSurgerySkillRequirementMet(u, o.skillRequirement) then
    o:onExtractFail({
      id = organId,
      name = name,
      damage = damage,
      targetCharacter = t,
      usingCharacter = u,
    })
    return
  end

  o:onExtractSuccess({
    id = organId,
    name = name,
    damage = damage,
    targetCharacter = t,
    usingCharacter = u,
  })
end

NTInteractiveItems.Register("advscalpel", {
  onApplyTreatment = function(e)
    local t = e.targetCharacter
    local u = e.usingCharacter
    local limbType = HF.NormalizeLimbType(e.targetLimb.type)

    if not HF.HasAfflictionLimb(t, "retractedskin", limbType, 99) then
      M.InciseSkin(limbType, t, u)
      return
    end

    local options = {
      entries = {},
    }
    function options:add(organId)
      local option = {
        label = "advscalpel.menu.btn." .. organId,
        onSelected = function()
          NTHealthContextMenu.Close()
          M.ExtractOrgan(organId, t, u)
        end,
      }
      table.insert(self.entries, option)
    end

    if limbType == LimbType.Head then
      if not HF.HasAffliction(t, "brainremoved", 1) then
        options:add("brain")
      end
    elseif limbType == LimbType.Torso then
      if
        not HF.HasAffliction(t, "kidney1removed", 1)
        or not HF.HasAffliction(t, "kidney2removed", 1)
      then
        options:add("kidney")
      end

      if not HF.HasAffliction(t, "heartremoved", 1) then
        options:add("heart")
      end

      if not HF.HasAffliction(t, "liverremoved", 1) then
        options:add("liver")
      end

      if not HF.HasAffliction(t, "lungremoved", 1) then
        options:add("lungs")
      end
    end

    if #options.entries == 0 then
      NTFeedbackSound.Play("fail")
      return
    end

    local title = HF.GetText("entityname.advscalpel")
    if e.dragAndDrop then
      NTHealthContextMenu.Open(title, options.entries)
    else
      NTHealthContextMenu.OpenAtLimb(limbType, title, options.entries)
    end
  end,
})

return M
