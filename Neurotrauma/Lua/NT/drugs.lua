local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTStat = NTA.Stat

local A = {
  opiateWithdrawal = NTA.Require(NTAffliction, "opiatewithdrawal"),
  chemWithdrawal = NTA.Require(NTAffliction, "chemwithdrawal"),
  alcoholWithdrawal = NTA.Require(NTAffliction, "alcoholwithdrawal"),
}

NTA.Register(NTAffliction({ id = "alcoholwithdrawal" }))
NTA.Register(NTAffliction({ id = "opiatewithdrawal" }))
NTA.Register(NTAffliction({ id = "chemwithdrawal" }))
NTA.Register(NTAffliction({ id = "opiateoverdose" }))
NTA.Register(NTAffliction({
  id = "drunk",
  max = 160,
}))

NTA.Register(NTAffliction({ id = "afmannitol" }))
NTA.Register(NTAffliction({ id = "afstreptokinase" }))
NTA.Register(NTAffliction({ id = "afringerssolution" }))
NTA.Register(NTAffliction({ id = "afsaline" }))
NTA.Register(NTAffliction({ id = "afthiamine" }))
NTA.Register(NTAffliction({ id = "afantibiotics" }))
NTA.Register(NTAffliction({ id = "afadrenaline" }))

NTA.Register(NTAffliction({
  id = "afpressuredrug",
  update = function(self, c)
    self:add(-0.25 * c.deltaTime)
  end,
}))

NTA.Register(NTStat({
  id = "withdrawal",
  max = 100,
  init = function(self, c)
    local strength = math.max(
      c:getRatio(A.opiateWithdrawal),
      c:getRatio(A.chemWithdrawal),
      c:getRatio(A.alcoholWithdrawal)
    )
    self:set(strength * self.def.max)
  end,
}))
