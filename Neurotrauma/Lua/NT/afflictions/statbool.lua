local DEBUG = require("NT.debug")

local M = {}

M.name = "StatBool"

local function statEnsureInitialized(self)
  if not self._initialized then
    error("stat not initialized: " .. self.def.id, 3)
  end
end

local function statInit(self, ...)
  if self._initialized then
    error("stat already initialized: " .. self.def.id, 2)
  end

  rawset(self, "_initialized", true)
  if self.def.init ~= nil then
    self.def.init(self, ...)
  end
end

local function statGet(self)
  self:_ensureInitialized()
  return self.value
end

local function statSet(self, v)
  self:_ensureInitialized()
  if DEBUG() and type(v) ~= "boolean" then
    error("invalid type for parameter 1, expected: boolean", 2)
  end
  rawset(self, "value", v)
end

local function statUpdateState(self, _c)
  rawset(self, "value", self.def.default)
  rawset(self, "_initialized", false)
end

local function createState(def)
  local o = {
    _initialized = false,
    value = false,
    def = def,
    _ensureInitialized = statEnsureInitialized,
    init = statInit,
    get = statGet,
    set = statSet,
    _updateState = statUpdateState,
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
  if type(e) ~= "table" then
    error("invalid type for parameter 1, expected: table", 2)
  end

  local members = {
    id = true,
    init = true,
    default = true,
  }
  for k in pairs(e) do
    if members[k] == nil then
      error("unsupported field: " .. k, 2)
    end
  end

  if type(e.id) ~= "string" then
    error("invalid or missing required field: id", 2)
  end

  e.type = M
  e._createState = createState

  if e.default == nil then
    e.default = false
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
