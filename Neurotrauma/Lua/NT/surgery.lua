local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction

NTA.Register(NTAffliction({
  id = "table",
}))

NTA.Register(NTLimbAffliction({
  id = "retractedskin",
  targetLimbs = { LimbType.Torso },
}))
