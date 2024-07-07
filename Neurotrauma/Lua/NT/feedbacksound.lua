local M = {
  _entries = {},
}

function M.Play(soundId, character)
  if CLIENT and Game.IsMultiplayer then
    assert(
      character == nil or character == Character.Controlled,
      "clients may not request feedback sounds for other players"
    )
  end

  local fn = M._entries[soundId]
  if fn ~= nil then
    fn(character)
  end
end

function M.RegisterBuiltin(id, soundType)
  if M._entries[id] ~= nil then
    error("sound is already registered: " .. id, 2)
  end

  M._entries[id] = function(character)
    if SERVER and Game.IsMultiplayer then
      local client = HF.CharacterToClient(character)

      if client ~= nil then
        local msg = Networking.Start("NT.feedbacksound." .. id)
        Networking.Send(msg, client.Connection)
      end

      return
    end

    SoundPlayer.PlayUISound(GUI.SoundType[soundType])
  end

  if CLIENT and Game.IsMultiplayer then
    Networking.Receive("NT.feedbacksound." .. id, function(_msg)
      SoundPlayer.PlayUISound(GUI.SoundType[soundType])
    end)
  end
end

M.RegisterBuiltin("fail", "PickItemFail")

return M
