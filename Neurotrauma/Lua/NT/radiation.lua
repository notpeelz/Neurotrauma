local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction

NTA.Register(NTAffliction({
  id = "radiationsickness",
  max = 200,
  update = function(self, c)
    self:add(-0.02 * c.deltaTime)
  end,
}))
