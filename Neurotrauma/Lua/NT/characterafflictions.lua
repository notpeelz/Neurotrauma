local DEBUG = require("NT.debug")
local NTA

local M = {}

local function getAffliction(character, id)
  if character.CharacterHealth == nil then
    return nil
  end

  local a = character.CharacterHealth.GetAffliction(id)
  if a == nil then
    return nil
  end

  return a.Strength
end

local function getAfflictionLimb(character, id, limbType)
  if character.CharacterHealth == nil or character.AnimController == nil then
    return nil
  end

  local limb = character.AnimController.GetLimb(limbType)
  if limb == nil then
    return nil
  end

  local a = character.CharacterHealth.GetAffliction(id, limb)
  if a == nil then
    return nil
  end

  return a.Strength
end

local function setAfflictionLimb(character, id, limbType, strength, aggressor)
  local prefab = AfflictionPrefab.Prefabs[id]
  local resistance = character.CharacterHealth.GetResistance(prefab)
  if resistance >= 1 then
    return
  end

  strength = strength * character.CharacterHealth.MaxVitality / 100 / (1 - resistance)
  local affliction = prefab.Instantiate(strength, aggressor)

  character.CharacterHealth.ApplyAffliction(
    character.AnimController.GetLimb(limbType),
    affliction,
    false
  )
end

local function setAffliction(character, id, strength, aggressor)
  return setAfflictionLimb(character, id, LimbType.Torso, strength, aggressor)
end

local function caGet(self, ...)
  local argc = select("#", ...)
  local args = table.pack(...)
  if argc < 1 then
    error("invalid parameter count", 2)
  end

  if #args == 0 then
    error("parameter 1 can't be nil", 2)
  end

  local function throwInvalidType()
    error("invalid type for parameter; expected: Affliction or LimbAffliction", 3)
  end

  local r = table.remove(args, 1)
  if DEBUG() and type(r) ~= "table" then
    throwInvalidType()
  end

  if r.type == NTA.Affliction then
    return getAffliction(self.character, r.id)
  elseif r.type == NTA.LimbAffliction then
    if argc < 2 then
      error("invalid parameter count", 2)
    end

    if #args == 0 then
      error("parameter 2 can't be nil", 2)
    end

    local limbType = table.remove(args, 1)
    -- TODO(DEBUG): validate limb type
    limbType = HF.NormalizeLimbType(limbType)

    return getAfflictionLimb(self.character, r.id, limbType)
  else
    throwInvalidType()
  end
end

local function caSet(self, ...)
  local argc = select("#", ...)
  local args = table.pack(...)
  if argc < 2 then
    error("invalid parameter count", 2)
  end

  if #args == 0 then
    error("parameter 1 can't be nil", 2)
  end

  if #args == 1 then
    error("parameter 2 can't be nil", 2)
  end

  local function throwInvalidType()
    error("invalid type for parameter; expected: Affliction or LimbAffliction", 3)
  end

  local r = table.remove(args, 1)
  if DEBUG() and type(r) ~= "table" then
    throwInvalidType()
  end

  if r.type == NTA.Affliction then
    local value = table.remove(args, 1)
    return setAffliction(self.character, r.id, value)
  elseif r.type == NTA.LimbAffliction then
    if argc < 3 then
      error("invalid parameter count", 2)
    end

    local limbType = table.remove(args, 1)
    -- TODO: validate limb type
    limbType = HF.NormalizeLimbType(limbType)

    if #args == 0 then
      error("parameter 3 can't be nil", 2)
    end

    local value = table.remove(args, 1)
    return setAfflictionLimb(self.character, r.id, limbType, value)
  else
    throwInvalidType()
  end
end

function M.Create(character)
  if
    type(character) ~= "userdata"
    or not LuaUserData.IsTargetType(character, "Barotrauma.Character")
  then
    error("invalid type for parameter 1, expected: Character", 2)
  end

  local o = M._CreateEmpty()
  rawset(o, "character", character)
  return o
end

function M._CreateEmpty()
  -- lazy-require NTA to avoid dependency cycles
  if NTA == nil then
    NTA = require("NT.afflictions")
  end

  local e = {
    type = M,
    character = nil,
    get = caGet,
    set = caSet,
  }

  if DEBUG() then
    e = setmetatable(e, {
      __newindex = function(_, k, _v)
        error("field is read-only: " .. k, 2)
      end,
    })
  end

  return e
end

return setmetatable(M, {
  __call = function(t, ...)
    return t.Create(...)
  end,
})
