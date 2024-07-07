-- TODO: move this to NTOrgans.BaseOrgan

local base = {
  minCondition = 10,
  getName = function(self, args)
    return args.id
  end,
  canExtractOrgan = function(self, args)
    local t = args.targetCharacter
    return not HF.HasAffliction(t, args.name .. "removed", 0)
  end,
  getDamage = function(self, args)
    local t = args.targetCharacter
    return HF.GetAfflictionStrength(t, args.name .. "damage", 0)
  end,
  getTransplantItemId = function(self, args)
    local u = args.usingCharacter
    if NTC.HasTag(u, "organssellforfull") then
      return args.name .. "transplant"
    else
      return args.name .. "transplant_q1"
    end
  end,
  onExtractFail = function(self, args)
    local t = args.targetCharacter
    local u = args.usingCharacter

    HF.AddAfflictionLimb(t, "bleeding", self.limbType, 15, u)
    HF.AddAffliction(t, args.name .. "damage", 20, u)
    HF.AddAfflictionLimb(t, "organdamage", self.limbType, 5, u)

    NT.InflictPain(t, u)
  end,
  onExtractSuccess = function(self, args)
    local t = args.targetCharacter
    local u = args.usingCharacter

    HF.SetAffliction(t, args.name .. "removed", 100, u)
    HF.SetAffliction(t, args.name .. "damage", 100, u)
    HF.AddAffliction(t, "organdamage", (100 - args.damage) / 5, u)

    -- don't spawn the organ if it's too damaged
    if args.damage >= (100 - self.minCondition) then
      return
    end

    local itemId = self:getTransplantItemId(args)
    if itemId == nil then
      return
    end

    local acidosis = HF.GetAfflictionStrength(t, "acidosis")
    local alkalosis = HF.GetAfflictionStrength(t, "alkalosis")
    local sepsis = HF.GetAfflictionStrength(t, "sepsis")

    HF.GiveItemPlusFunction(itemId, function(e)
      local item = e.item

      -- add acidosis, alkalosis and sepsis if the donor has them
      local tags = {}

      if acidosis > 0 then
        table.insert(tags, string.format("acid:%.0f", acidosis))
      elseif alkalosis > 0 then
        table.insert(tags, string.format("alkal:%.0f", alkalosis))
      end

      if sepsis > 10 then
        table.insert(tags, "sepsis")
      end

      item.Tags = table.concat(tags, ",")
      item.Condition = 100 - args.damage
    end, nil, u)
  end,
}

local function Extend(fn)
  local o = fn(base)
  local m = {
    __index = function(_t, k)
      local v = o[k]
      if v ~= nil then
        return v
      end
      return base[k]
    end,
    __newindex = function(_t, k, v)
      o[k] = v
    end,
  }

  return setmetatable({}, m)
end

return { Extend = Extend }
