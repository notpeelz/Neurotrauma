if not CLIENT then
  return nil
end

LuaUserData.RegisterType("Barotrauma.GUIContextMenu")
LuaUserData.RegisterType("Barotrauma.ContextMenuOption")
local GUIContextMenu = LuaUserData.CreateStatic("Barotrauma.GUIContextMenu", true)
local GUIContextMenuOption = LuaUserData.CreateStatic("Barotrauma.ContextMenuOption", true)

LuaUserData.MakeMethodAccessible(
  Descriptors["Barotrauma.CharacterHealth"],
  "GetMatchingLimbHealth",
  {
    "Barotrauma.Limb",
  }
)
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.CharacterHealth"], "GetLimbHighlightArea")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.CharacterHealth"], "deadIndicator")

local M = {
  _menu = nil,
  _closeButton = nil,
}

function M.Close()
  if not M.IsOpen() then
    return
  end

  M._closeButton.Visible = false
  M._closeButton.RectTransform.Parent = nil
  M._closeButton = nil
  M._menu.Visible = false
  M._menu.RectTransform.Parent = nil
  M._menu = nil

  if BHUILuaInterop ~= nil then
    BHUILuaInterop.SkipUpdateLimbIndicators = BHUILuaInterop.SkipUpdateLimbIndicators - 1
  end
end

function M.OpenAtLimb(limbType, title, options)
  limbType = HF.NormalizeLimbType(limbType)

  local ohw = CharacterHealth.OpenHealthWindow
  if ohw == nil then
    return
  end

  local character = ohw.Character
  if character == nil then
    return
  end

  local limb = character.AnimController.GetLimb(limbType)
  if limb == nil then
    return
  end

  local limbHealth = ohw.GetMatchingLimbHealth(limb)

  -- HACK: unfortunately we can't grab the drawRect by hooking DrawHealthWindow
  -- because BHUI prevents our hook from running
  local limbSelection = ohw.deadIndicator.Parent
  assert(limbSelection ~= nil, "limbSelection is nil")
  local limbDrawArea = limbSelection.RectTransform.Rect
  assert(limbDrawArea ~= nil, "limbDrawArea is nil")

  local rect = ohw.GetLimbHighlightArea(limbHealth, limbDrawArea)
  return M.OpenAt(rect.Center.ToVector2(), title, options)
end

function M.OpenAt(pos, title, options)
  if M.IsOpen() then
    return
  end

  for i, args in ipairs(options) do
    local label = args.label or ""
    local isEnabled = args.isEnabled == nil
    local onSelected = args.onSelected

    if isEnabled == nil then
      isEnabled = true
    end

    options[i] = GUIContextMenuOption(label, isEnabled, onSelected)
  end

  M._menu = GUIContextMenu.CreateContextMenu(pos, title, nil, table.unpack(options))
  M._closeButton = GUI.Button(GUI.RectTransform(Vector2(1, 1), nil), "", GUI.Alignment.Center, nil)
  M._closeButton.OnClicked = function()
    M.Close()
  end

  if BHUILuaInterop ~= nil then
    BHUILuaInterop.SkipUpdateLimbIndicators = BHUILuaInterop.SkipUpdateLimbIndicators + 1
  end
end

function M.Open(title, options)
  return M.OpenAt(nil, title, options)
end

function M.IsOpen()
  return M._menu ~= nil
end

Hook.Add("neurotrauma.init", "neurotrauma.healthcontextmenu.init", function()
  -- XXX: unfortunately BHUI hooks this method, which prevents our hook from running
  Hook.Patch("Barotrauma.CharacterHealth", "UpdateLimbIndicators", function(_instance, ptable)
    if M.IsOpen() then
      ptable.PreventExecution = true
    end
  end, Hook.HookMethodType.Before)

  Hook.Patch("Barotrauma.CharacterHealth", "set_OpenHealthWindow", function(_instance, ptable)
    local newValue = ptable["value"]
    if newValue == nil then
      M.Close()
    end
  end, Hook.HookMethodType.Before)

  Hook.Patch("Barotrauma.CharacterHealth", "AddToGUIUpdateList", function(instance, _ptable)
    if GUI.DisableHUD then
      return
    end

    if CharacterHealth.OpenHealthWindow ~= instance then
      return
    end

    if M.IsOpen() then
      M._closeButton.AddToGUIUpdateList()
      M._menu.AddToGUIUpdateList()
    end
  end, Hook.HookMethodType.After)
end)

return M
