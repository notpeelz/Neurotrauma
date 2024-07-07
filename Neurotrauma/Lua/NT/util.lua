local M = {}

function M.Chance(chance)
  return math.random() < chance
end

return M
