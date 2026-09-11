-- SPDX-License-Identifier: MIT

-- xoshiro256** is a random generation algorithm which is used by
-- standard `math.random` function of Lua 5.4.
--
-- This file provides pure Lua 5.4 implementation of this algorithm
-- while allowing creation of individual random states, so you can use
-- the power of xorshift algorithm without the limit of Lua's
-- global random state.

-------------------------------
-- Algorithm implementation
-- Translated from the source code of Lua 5.4 but only consider 64-bit numbers.
--
-- Most comments are copy-pasted too.
--
-- see also https://github.com/lua/lua/blob/v5.4/lmathlib.c#L246
-------------------------------

-- rotate left 'x' by 'n' bits
local function rotl(x, k)
  return (x << k) | (x >> (64 - k))
end

local function next(s)
  local s1 = s[1]
  local s2 = s[2]
  local s3 = s[3] ~ s1
  local s4 = s[4] ~ s2
  local result = rotl(s2 * 5, 7) * 9
  s[1] = s1 ~ s4
  s[2] = s2 ~ s3
  s[3] = s3 ~ (s2 << 17)
  s[4] = rotl(s4, 45)
  return result
end

-------------------------------
-- Convert bits from a random integer into a float in the
-- interval [0,1), getting the higher FIG bits from the
-- random unsigned integer and converting that to a float.
-- Some old Microsoft compilers cannot cast an unsigned long
-- to a floating-point number, so we use a signed long as an
-- intermediary. When lua_Number is float or double, the shift ensures
-- that 'sx' is non negative; in that case, a good compiler will remove
-- the correction.
-------------------------------

local FIGS = 53
local shift64_FIG = 64 - FIGS
local scaleFIG = 0.5 / (1 << (FIGS - 1))

-- I2d, convert 64-bit integers to double.
local function intToDouble(x)
  local sx = x >> shift64_FIG
  local res = sx * scaleFIG
  if sx < 0 then
    res = res + 1.0
  end
  return res
end

local function setseed(s, n1, n2)
  n2 = n2 or 0
  s[1] = n1
  s[2] = 0xff    -- avoid a zero state
  s[3] = n2
  s[4] = 0

  -- discard initial values to "spread" seed
  for _ = 0, 15 do next(s) end

  return n1, n2
end

-------------------------------
-- Project the random integer 'ran' into the interval [0, n].
-- Because 'ran' has 2^B possible values, the projection can only be
-- uniform when the size of the interval is a power of 2 (exact
-- division). Otherwise, to get a uniform projection into [0, n], we
-- first compute 'lim', the smallest Mersenne number not smaller than
-- 'n'. We then project 'ran' into the interval [0, lim].  If the result
-- is inside [0, n], we are done. Otherwise, we try with another 'ran',
-- until we have a result inside the interval.
-------------------------------
local function project(s, x, n)
  -- is 'n + 1' a power of 2?
  if (n & (n + 1)) == 0 then
    return x & n  -- no bias
  end

  local lim = n
  -- compute the smallest (2^b - 1) not smaller than 'n'
  lim = lim | (lim >> 1)
  lim = lim | (lim >> 2)
  lim = lim | (lim >> 4)
  lim = lim | (lim >> 8)
  lim = lim | (lim >> 16)
  lim = lim | (lim >> 32);
  assert((lim & (lim + 1)) == 0   -- 'lim + 1' is a power of 2,
    and lim >= n                  -- not smaller than 'n',
    and (lim >> 1) < n)           -- and it is the smallest one

  while true do
    -- project 'x' into [0..lim]
    x = x & lim
    if (x <= n) then break end
    x = next(s) -- not inside [0..n]? try again
  end

  return x
end

local function random(s, m, n)
  local low, up
  local ret = next(s)
  if m == nil then
    return intToDouble(ret)
  elseif n == nil then
    low = 1
    up = m
    if up == 0 then return ret end
  else
    low = m
    up = n
  end

  assert(low <= up, "interval is empty")
  local p = project(s, ret, up - low)
  return p + low
end

-------------------------------
-- API part
-- Provide a class storing the random state, with the
-- `randomseed` and `random` method, and export the constructor.
-------------------------------

local klass = {}

-- reinitialize random state, see documentation of `math.randomseed`.
function klass:randomseed(n1, n2)
  if n1 == nil then
    n1 = math.random(math.maxinteger)
    n2 = math.random(os.time())
  end

  setseed(self, n1, n2)
end

-- Generate pseudo-random numbers, see documentation of `math.random`.
--
-- - no args: returns a pseudo-random float with uniform distribution in the range [0,1)
-- - both m and n: returns a pseudo-random integer with uniform distribution in the range [m, n]
-- - only m: returns a pseudo-random integer with uniform distribution in the range [1, m]
function klass:random(m, n)
  return random(self, m, n)
end

-- Constructor of the random generator.
local function newGenerator(x, y)
  local ret = setmetatable({}, { __index = klass })
  ret:randomseed(x, y)
  return ret
end

return newGenerator
