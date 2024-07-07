local NTCharacterAfflictions = require("NT.characterafflictions")
local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction

local M = {
  _entries = {},
  _maxWeight = 0,
}

function M.Register(id, weight)
  if type(id) ~= "string" then
    error("invalid type for parameter 1, expected: string", 2)
  end

  if M._entries[id] ~= nil then
    error("blood type is already registered: " .. id, 2)
  end

  NTA.Register(NTAffliction({ id = id }))

  local o = {
    id = id,
    _affliction = NTA.Require(NTAffliction, id),
    _weight = weight,
  }

  function o:assignToCharacter(character)
    local ca
    if
      type(character) == "userdata" and LuaUserData.IsTargetType(character, "Barotrauma.Character")
    then
      ca = NTCharacterAfflictions(character)
    elseif type(character) == "table" and character.type == NTCharacterAfflictions then
      ca = character
    else
      error("invalid type for parameter 1, expected: Character or CharacterAfflictions", 2)
    end

    for _, b in pairs(M._entries) do
      ca:set(b._affliction, 0)
    end

    ca:set(self._affliction, 100)
  end

  M._entries[id] = o
  M._maxWeight = M._maxWeight + weight
end

function M.FromCharacter(character)
  local ca
  if
    type(character) == "userdata" and LuaUserData.IsTargetType(character, "Barotrauma.Character")
  then
    ca = NTCharacterAfflictions(character)
  elseif type(character) == "table" and character.type == NTCharacterAfflictions then
    ca = character
  else
    error("invalid type for parameter 1, expected: Character or CharacterAfflictions", 2)
  end

  for _, b in pairs(M._entries) do
    local value = ca:get(b._affliction)
    if value ~= nil and value > 0 then
      return b
    end
  end

  return nil
end

function M.Random()
  assert(M._maxWeight > 0)

  local r = math.random(1, M._maxWeight)
  local i = 0
  for _, bloodType in pairs(M._entries) do
    i = i + bloodType._weight
    if i >= r then
      return bloodType
    end
  end

  assert(false)
end

M.Register("oplus", 37)
M.Register("ominus", 7)
M.Register("aplus", 36)
M.Register("aminus", 6)
M.Register("bplus", 8)
M.Register("bminus", 2)
M.Register("abplus", 3)
M.Register("abminus", 1)

return M
