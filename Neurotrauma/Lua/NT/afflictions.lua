local DEBUG = require("NT.debug")
local NTScheduler = require("NT.scheduler")
local NTAffliction = require("NT.afflictions.affliction")
local NTLimbAffliction = require("NT.afflictions.limbaffliction")
local NTCharacterAfflictions = require("NT.characterafflictions")
local NTStat = require("NT.afflictions.stat")
local NTStatBool = require("NT.afflictions.statbool")

local M = {
  _initialized = false,
  _characterUpdateCallbacks = {},
  _requirements = {},
  _statEntries = {},
  _afflictionEntries = {},
  _limbAfflictionEntries = {},
}

M.Affliction = NTAffliction
M.LimbAffliction = NTLimbAffliction
M.Stat = NTStat
M.StatBool = NTStatBool

local function limbTypeToString(v)
  if v == LimbType.Torso then
    return "Torso"
  end

  if v == LimbType.Head then
    return "Head"
  end

  if v == LimbType.LeftArm or v == LimbType.LeftForearm or v == LimbType.LeftHand then
    return "LeftArm"
  end

  if v == LimbType.RightArm or v == LimbType.RightForearm or v == LimbType.RightHand then
    return "RightArm"
  end

  if v == LimbType.LeftLeg or v == LimbType.LeftThigh or v == LimbType.LeftFoot then
    return "LeftLeg"
  end

  if v == LimbType.RightLeg or v == LimbType.RightThigh or v == LimbType.RightFoot then
    return "RightLeg"
  end

  error("invalid limb type: " .. v, 2)
end

local function validateRequirement(r, level)
  if level == nil then
    level = 2
  end

  local def = r.resolve()
  if def == nil then
    error(string.format("failed to resolve entry: (%s, %s)", r.type.name, r.id), level)
  end

  -- TODO: validate spec (min/max/limbType/etc)
end

function M.Require(t, id, spec)
  if type(t) ~= "table" and t ~= NTAffliction and t ~= NTStat and t ~= NTStatBool then
    error("invalid type for parameter 1, expected: Affliction, LimbAffliction, Stat or StatBool", 2)
  end

  if type(id) ~= "string" then
    error("invalid type for parameter 2, expected: string", 2)
  end

  if spec == nil then
    spec = {}
  end

  if type(spec) ~= "table" then
    error("invalid type for parameter 3, expected: table", 2)
  end

  local function resolve()
    if not M._initialized then
      error("afflictions aren't initialized yet", 3)
    end

    if t == NTAffliction then
      return M._afflictionEntries[id]
    elseif t == NTLimbAffliction then
      return M._limbAfflictionEntries[id]
    elseif t == NTStat or t == NTStatBool then
      return M._statEntries[id]
    else
      -- this shouldn't happen
      error("invalid requirement type", 3)
    end
  end

  local r = {
    -- TODO: (nice to have) implement debug.getinfo in MoonSharp, so we can report
    -- which file has broken dependencies.
    -- file = ...

    type = t,
    id = id,
    resolve = resolve,
    spec = spec,
  }

  if M._initialized then
    validateRequirement(r, 3)
  else
    table.insert(M._requirements, r)
  end

  return setmetatable({}, {
    __index = function(_t, k)
      local def = resolve()
      return def[k]
    end,
    __newindex = function(_t, k, v)
      local def = resolve()
      def[k] = v
    end,
  })
end

function M.Register(e)
  local function throwInvalidType()
    error("invalid type for parameter 2, expected: Affliction, LimbAffliction, Stat or StatBool", 3)
  end

  if type(e) ~= "table" then
    throwInvalidType()
  end

  if type(e.id) ~= "string" then
    error("invalid id field", 2)
  end

  if e.type == NTAffliction then
    if M._afflictionEntries[e.id] ~= nil or M._limbAfflictionEntries[e.id] ~= nil then
      error("affliction is already registered: " .. e.id, 2)
    end

    M._afflictionEntries[e.id] = e
  elseif e.type == NTLimbAffliction then
    if M._afflictionEntries[e.id] ~= nil or M._limbAfflictionEntries[e.id] ~= nil then
      error("affliction is already registered: " .. e.id, 2)
    end

    M._limbAfflictionEntries[e.id] = e
  elseif e.type == NTStat or e.type == NTStatBool then
    if M._statEntries[e.id] ~= nil then
      error("stat is already registered: " .. e.id, 2)
    end

    M._statEntries[e.id] = e
  else
    throwInvalidType()
  end

  return nil
end

function M.AddCharacterUpdateCallback(fn)
  if M._initialized then
    error("can't add character update callbacks post-initialization", 2)
  end
  table.insert(M._characterUpdateCallbacks, fn)
end

-- TODO(perf): reimplement helper methods without parseArgs.
-- I suspect table.unpack/table.pack is responsible for some GC pressure.

local function parseArgs(self, ...)
  local argc = select("#", ...)
  local args = table.pack(...)
  if argc == 0 then
    error("invalid parameter count", 3)
  end

  if #args == 0 then
    error("parameter 1 can't be nil", 3)
  end

  local function throwInvalidType()
    error(
      string.format(
        "invalid type for parameter; expected: %s",
        "Affliction, LimbAffliction, Stat or StatBool"
      ),
      4
    )
  end

  local r = table.remove(args, 1)
  if DEBUG() and type(r) ~= "table" then
    throwInvalidType()
  end

  if r.type == NTAffliction then
    local o = self._afflictions[r.id]

    if o == nil then
      error(string.format("invalid affliction: %s", r.id), 3)
    end

    return o, args
  elseif r.type == NTLimbAffliction then
    if argc == 1 then
      error("invalid parameter count", 3)
    end

    if #args == 0 then
      error("parameter 2 can't be nil", 3)
    end

    local limbType = table.remove(args, 1)
    -- TODO: validate limb type
    limbType = HF.NormalizeLimbType(limbType)

    local o = self._limbAfflictions[limbType][r.id]

    if o == nil then
      error(string.format("invalid limb affliction: (%s, %s)", limbTypeToString(limbType), r.id), 3)
    end

    return o, args
  elseif r.type == NTStat or r.type == NTStatBool then
    local o = self._stats[r.id]

    if o == nil then
      error(string.format("invalid stat: %s", r.id), 3)
    end

    return o, args
  else
    throwInvalidType()
  end
end

local function ctxGetRatio(self, ...)
  local e, args = parseArgs(self, ...)
  if e.getRatio == nil then
    error("operation not supported: getRatio", 2)
  end
  return e:getRatio(table.unpack(args))
end

local function ctxGetUncommitted(self, ...)
  local e, args = parseArgs(self, ...)
  if e.getUncommitted == nil then
    error("operation not supported: getUncommitted", 2)
  end
  return e:getUncommitted(table.unpack(args))
end

local function ctxGet(self, ...)
  local e, args = parseArgs(self, ...)
  if e.get == nil then
    error("operation not supported: get", 2)
  end
  return e:get(table.unpack(args))
end

-- XXX: this method should be avoided if possible, as it might override the
-- modifications done by other afflictions' update logic.
local function ctxSet(self, ...)
  local e, args = parseArgs(self, ...)
  if e.getRatio == nil then
    error("operation not supported: set", 2)
  end
  return e:set(table.unpack(args))
end

local function ctxAdd(self, ...)
  local e, args = parseArgs(self, ...)
  if e.add == nil then
    error("operation not supported: add", 2)
  end
  return e:add(table.unpack(args))
end

local function ctxMultiply(self, ...)
  local e, args = parseArgs(self, ...)
  if e.multiply == nil then
    error("operation not supported: multiply", 2)
  end
  return e:multiply(table.unpack(args))
end

local schedulerContext
local function initSchedulerContext()
  schedulerContext = {
    _afflictions = {},
    _limbAfflictions = {
      [LimbType.Head] = {},
      [LimbType.Torso] = {},
      [LimbType.LeftArm] = {},
      [LimbType.RightArm] = {},
      [LimbType.LeftLeg] = {},
      [LimbType.RightLeg] = {},
    },
    _stats = {},
    deltaTime = nil,
    character = nil,
    ca = NTCharacterAfflictions._CreateEmpty(),
    getRatio = ctxGetRatio,
    getUncommitted = ctxGetUncommitted,
    get = ctxGet,
    set = ctxSet,
    add = ctxAdd,
    multiply = ctxMultiply,
  }

  if DEBUG() then
    schedulerContext = setmetatable(schedulerContext, {
      __newindex = function(_, k, _v)
        error("field is read-only: " .. k, 2)
      end,
    })
  end

  for id, e in pairs(M._statEntries) do
    local o = e:_createState()
    schedulerContext._stats[id] = o
  end

  for id, e in pairs(M._afflictionEntries) do
    local o = e:_createState()
    schedulerContext._afflictions[id] = o
  end

  for id, e in pairs(M._limbAfflictionEntries) do
    for limbType in e.targetLimbs do
      local o = e:_createState(limbType)
      schedulerContext._limbAfflictions[limbType][id] = o
    end
  end
end

local updateFns
local function initUpdateFns()
  -- PERF: here we prepare a "denormalized" list of functions to be executed
  -- for each character.
  -- On my computer, this seems to have negligible performance benefits,
  -- but I haven't been able to do proper profiling/benchmarking.
  updateFns = {}

  for _, e in pairs(schedulerContext._stats) do
    table.insert(updateFns, function()
      e:_updateState(schedulerContext)
    end)
  end

  for _, e in pairs(schedulerContext._afflictions) do
    table.insert(updateFns, function()
      e:_updateState(schedulerContext)
    end)
  end

  for _, t in pairs(schedulerContext._limbAfflictions) do
    for _, e in pairs(t) do
      table.insert(updateFns, function()
        e:_updateState(schedulerContext)
      end)
    end
  end

  for cb in M._characterUpdateCallbacks do
    table.insert(updateFns, function()
      cb(deltaTime, character)
    end)
  end

  for _, e in pairs(schedulerContext._stats) do
    table.insert(updateFns, function()
      e:init(schedulerContext)
    end)
  end

  -- update

  for _, o in pairs(schedulerContext._afflictions) do
    if o.def.update ~= nil then
      table.insert(updateFns, function()
        o.def.update(o, schedulerContext)
      end)
    end
  end

  for _, t in pairs(schedulerContext._limbAfflictions) do
    for _, o in pairs(t) do
      if o.def.update ~= nil then
        table.insert(updateFns, function()
          o.def.update(o, schedulerContext)
        end)
      end
    end
  end

  -- postUpdate

  for _, o in pairs(schedulerContext._afflictions) do
    if o.def.postUpdate ~= nil then
      table.insert(updateFns, function()
        o.def.postUpdate(o, schedulerContext)
      end)
    end
  end

  for _, t in pairs(schedulerContext._limbAfflictions) do
    for _, o in pairs(t) do
      if o.def.postUpdate ~= nil then
        table.insert(updateFns, function()
          o.def.postUpdate(o, schedulerContext)
        end)
      end
    end
  end

  -- apply

  for _, o in pairs(schedulerContext._afflictions) do
    table.insert(updateFns, function()
      o:apply(schedulerContext)
    end)
  end

  for _, t in pairs(schedulerContext._limbAfflictions) do
    for _, o in pairs(t) do
      table.insert(updateFns, function()
        o:apply(schedulerContext)
      end)
    end
  end
end

Hook.Add("neurotrauma.init", "neurotrauma.afflictions.init", function()
  -- pause the scheduler to avoid spamming errors if something throws an error
  NTScheduler.Pause()

  Hook.Call("neurotrauma.afflictions.init")
  M._initialized = true

  for r in M._requirements do
    validateRequirement(r)
  end

  initSchedulerContext()
  initUpdateFns()

  NTScheduler.Resume()
end)

NTScheduler.AddCharacterUpdateCallback(function(deltaTime, character)
  -- TODO: what logic is specific to monsters?
  if character.Removed or not character.IsHuman or character.IsDead then
    return
  end

  -- HACK: this is a hot code path, so we try to avoid unnecessary allocations
  -- as much as possible, which means violating OOP principles and mutating
  -- objects directly.
  rawset(schedulerContext, "deltaTime", deltaTime)
  rawset(schedulerContext, "character", character)
  rawset(schedulerContext.ca, "character", character)

  for fn in updateFns do
    fn()
  end
end)

M.Register(M.Affliction({
  id = "luabotomy",
  update = function(self)
    if self.value <= 0 then
      return
    end

    self:set(0)
  end,
}))

return M
