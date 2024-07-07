local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat

NTA.Register(NTAffliction({ id = "stasis" }))

NTA.Register(NTStat({
  id = "healingrate",
  max = 100,
  init = function(self, c)
    self:set(NTC.GetMultiplier(c.character, "healingrate"))
  end,
}))
