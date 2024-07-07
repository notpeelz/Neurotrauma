return function(path)
  local m

  return setmetatable({}, {
    __index = function(_, k)
      if m == nil then
        m = require(path)
      end
      return m[k]
    end,
    __newindex = function(_, k, v)
      if m == nil then
        m = require(path)
      end
      m[k] = v
    end,
    __call = function(_, ...)
      if m == nil then
        m = require(path)
      end
      return m(...)
    end,
  })
end
