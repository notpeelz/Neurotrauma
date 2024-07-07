local M = {
  _entries = {},
  _dragAndDrop = false,
}

function M.Register(id, entry)
  assert(type(id) == "string")
  assert(M._entries[id] == nil, "interactive item is already registered: " .. id)

  assert(type(entry) == "table")
  assert(type(entry.onApplyTreatment) == "function")

  M._entries[id] = entry
end

local function initClient()
  Hook.Patch("Barotrauma.CharacterHealth", "OnItemDropped", function(_instance, ptable)
    M._dragAndDrop = not ptable["ignoreMousePos"]
  end, Hook.HookMethodType.Before)

  Hook.Patch("Barotrauma.CharacterHealth", "OnItemDropped", function(_instance, _ptable)
    M._dragAndDrop = false
  end, Hook.HookMethodType.After)

  Hook.Patch("Barotrauma.Item", "ApplyTreatment", function(item, ptable)
    local u = ptable["user"]
    local t = ptable["character"]
    local limb = ptable["targetLimb"]

    if u ~= Character.Controlled then
      return
    end

    if t.IsDead then
      return
    end

    if not item.UseInHealthInterface then
      return
    end

    if CharacterHealth.OpenHealthWindow == nil then
      return
    end

    local itemId = item.Prefab and item.Prefab.Identifier.Value
    local entry = M._entries[itemId]
    if entry ~= nil and entry.onApplyTreatment ~= nil then
      ptable.PreventExecution = true
      entry.onApplyTreatment({
        item = item,
        usingCharacter = u,
        targetCharacter = t,
        targetLimb = limb,
        dragAndDrop = M._dragAndDrop,
      })
    end
  end, Hook.HookMethodType.Before)
end

Hook.Add("neurotrauma.init", "neurotrauma.interactiveitems.init", function()
  if CLIENT then
    initClient()
  end
end)

return M
