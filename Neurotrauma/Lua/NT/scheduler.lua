-- the interval (in game ticks) at which all Neurotrauma state is updated
-- i.e. afflictions, stats, etc.
local UPDATE_INTERVAL = 120

local M = {
  _paused = false,
  _tickCallbacks = {},
  _characterUpdateCallbacks = {},
  _characters = {},
  _charIdx = 0,
  _batchTime = 0,
  _batchInterval = 0,
  _updateInterval = UPDATE_INTERVAL,
}

function M.AddCharacterUpdateCallback(fn)
  table.insert(M._characterUpdateCallbacks, fn)
end

function M.AddTickCallback(fn)
  table.insert(M._tickCallbacks, fn)
end

function M.Pause()
  M._paused = true
end

function M.Resume()
  M._paused = false
end

local function update()
  if M._paused or HF.GameIsPaused() then
    return
  end

  if M._charIdx == 0 then
    M._charIdx = 1

    -- IMPORTANT:
    -- This is a copy, not a reference!
    -- MoonSharp creates a copy of the list on access.
    local characters = Character.CharacterList
    local count = #characters
    M._characters = characters

    M._updateInterval = math.min(480, 8 * math.max(count - 30, 0) + UPDATE_INTERVAL)
    M._batchInterval = math.min(UPDATE_INTERVAL, math.ceil(M._updateInterval / count))

    -- Barotrauma updates at a fixed rate of 60 tick/s,
    -- which means you can think of this as roughly ~2s (under normal circumstances).
    -- NOTE: there's no mechanism to account for the lost time between ticks
    --       if the game isn't able to keep up with the update rate.
    M._deltaTime = M._updateInterval / 60

    for cb in M._tickCallbacks do
      cb(M._deltaTime)
    end
  end

  if M._batchTime % M._batchInterval == 0 then
    local character = M._characters[M._charIdx]
    if character ~= nil then
      for cb in M._characterUpdateCallbacks do
        cb(M._deltaTime, character)
      end
    end
    M._charIdx = M._charIdx + 1
    if M._charIdx > #M._characters then
      M._charIdx = 0
      M._batchTime = 0
    end
  end

  M._batchTime = M._batchTime + 1
end

if SERVER or not Game.IsMultiplayer then
  Hook.Add("neurotrauma.init", "neurotrauma.scheduler.init", function()
    -- hook the game loop (runs 60 times per second)
    Hook.Add("think", "NT.update", update)
  end)
end

return M
