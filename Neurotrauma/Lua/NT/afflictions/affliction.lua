local DEBUG = require("NT.debug")
local NTCharacterAfflictions = require("NT.characterafflictions")

local M = {}

M.name = "Affliction"

function M.Apply(o, c)
  if DEBUG() and (type(o) ~= "table" or type(o.def) ~= "table" or o.def.type ~= M) then
    error("invalid type for parameter 1, expected: Affliction", 2)
  end

  if not o:isModified() then
    return
  end

  c.ca:set(o.def, o.newValue)
end

local function afGet(self)
  return self.value
end

local function afGetRatio(self, v)
  if DEBUG() and v ~= nil and type(v) ~= "number" then
    error("invalid type for parameter 1, expected: number or nil", 2)
  end

  if v == nil then
    v = self.value
  end

  return v / self.def.max
end

local function afGetUncommitted(self)
  return self.newValue
end

local function afSet(self, v)
  if DEBUG() and type(v) ~= "number" then
    error("invalid type for parameter 1, expected: number", 2)
  end
  v = math.max(v, self.def.min)
  v = math.min(v, self.def.max)
  rawset(self, "newValue", v)
end

local function afAdd(self, v)
  if DEBUG() and type(v) ~= "number" then
    error("invalid type for parameter 1, expected: number", 2)
  end

  self:set(self.newValue + v)
  return self.newValue
end

local function afIsModified(self)
  return self.value ~= self.newValue
end

local function afIsModifiedTrue()
  return true
end

local function afUpdateState(self, c)
  local value = c.ca:get(self.def)
  local isModifiedFn = afIsModified

  if value == nil then
    if self.def.default ~= 0 then
      isModifiedFn = afIsModifiedTrue
    end
    value = self.def.default
  end

  rawset(self, "value", value)
  rawset(self, "newValue", math.clamp(value, self.def.min, self.def.max))
  rawset(self, "isModified", isModifiedFn)

  return m
end

local function createState(def)
  local o = {
    value = 0,
    newValue = 0,
    def = def,
    apply = def.apply,
    get = afGet,
    getRatio = afGetRatio,
    getUncommitted = afGetUncommitted,
    set = afSet,
    add = afAdd,
    isModified = afIsModified,
    _updateState = afUpdateState,
  }

  local m = o

  if DEBUG() then
    m = setmetatable({}, {
      __index = function(_t, k)
        return o[k]
      end,
      __newindex = function(_t, k, _v)
        error("field is read-only: " .. k, 2)
      end,
    })
  end

  return m
end

function M.Create(e)
  if e == nil then
    e = {}
  end

  if type(e) ~= "table" then
    error("invalid type for parameter 1, expected: table or nil", 2)
  end

  local members = {
    id = true,
    default = true,
    min = true,
    max = true,
    apply = true,
    update = true,
    postUpdate = true,
  }
  for k in pairs(e) do
    if members[k] == nil then
      error("unsupported field: " .. k, 2)
    end
  end

  if type(e.id) ~= "string" then
    error("invalid or missing required field: id", 2)
  end

  if not AfflictionPrefab.Prefabs.ContainsKey(e.id) then
    error("invalid affliction: " .. e.id, 2)
  end
  local prefab = AfflictionPrefab.Prefabs[e.id]

  e.type = M
  e._createState = createState

  if e.min == nil then
    e.min = 0
  end

  if e.max == nil then
    e.max = prefab.MaxStrength
  end

  if e.max ~= prefab.MaxStrength then
    error(
      string.format(
        "affliction max doesn't match the prefab: expected %.4f; actual: %.4f",
        e.max,
        prefab.MaxStrength
      ),
      2
    )
  end

  if e.max == nil or e.max <= e.min then
    error("invalid or missing required field: max", 2)
  end

  if e.default == nil then
    e.default = e.min
  end

  if e.default > e.max or e.default < e.min then
    error("default value out of range", 2)
  end

  if e.apply == nil then
    e.apply = M.Apply
  end

  return setmetatable(e, {
    __newindex = function(_, k, _v)
      error("field is read-only: " .. k, 2)
    end,
  })
end

return setmetatable(M, {
  __call = function(t, ...)
    return t.Create(...)
  end,
})
