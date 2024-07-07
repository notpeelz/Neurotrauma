local NTA = require("NT.afflictions")
local NTAffliction = NTA.Affliction
local NTLimbAffliction = NTA.LimbAffliction

local A = {
  gypsumCast = NTA.Require(NTLimbAffliction, "gypsumcast"),
}

-- spinal cord injury
NTA.Register(NTAffliction({ id = "t_paralysis" }))

for id, limbType in pairs({
  -- skull
  h = LimbType.Head,
  -- neck
  n = LimbType.Head,
  -- humerus
  la = LimbType.LeftArm,
  ra = LimbType.RightArm,
  -- femur
  ll = LimbType.LeftLeg,
  rl = LimbType.RightLeg,
}) do
  NTA.Register(NTAffliction({
    id = id .. "_fracture",
    update = function(self, c)
      if self.value <= 0 then
        return
      end

      if c:get(limbType, A.gypsumCast) > 0 then
        return
      end

      self:add(2 * c.deltaTime)
    end,
  }))
end

for id in pairs({
  la = LimbType.LeftArm,
  ra = LimbType.RightArm,
  ll = LimbType.LeftLeg,
  rl = LimbType.RightLeg,
}) do
  -- traumatic amputation
  NTA.Register(NTAffliction({
    id = string.format("t%s_amputation", id),
  }))
  -- surgical amputation
  NTA.Register(NTAffliction({
    id = string.format("s%s_amputation", id),
  }))
end

for id in pairs({
  -- carotid artery
  h = LimbType.Head,
  -- aorta
  t = LimbType.Torso,
  -- brachial artery
  la = LimbType.LeftArm,
  ra = LimbType.RightArm,
  -- femoral artery
  ll = LimbType.LeftLeg,
  rl = LimbType.RightLeg,
}) do
  NTA.Register(NTAffliction({
    id = id .. "_arterialcut",
  }))
end
