---------
-- General utility functions.

-- unpack is not global since Lua 5.3
local unpack = table.unpack or unpack

local M = {}

--- Returns a new table with items concatenated from the given tables.
-- Tables are iterated using @{ipairs}, so this function is intended for tables
-- that represent *indexed arrays*.
--
-- @tparam {table,...} ... The tables to concatenate.
-- @treturn table A new table.
-- @see merge
function M.concat (...)
  local result = {}

  for _, tab in ipairs {...} do
    for _, val in ipairs(tab) do
      table.insert(result, val)
    end
  end

  return result
end

--- Returns the `value` if not nil or empty, otherwise returns the
-- `default_value`.
function M.default (value, default_value)
  if M.is_empty(value) then
    return default_value
  end
  return value
end

--- Returns the given value. That's it, this is an identity function.
function M.id (value)
  return value
end

--- Returns true if the `value` is nil, empty string or contains at least one
-- character other than space and tab. If the `value` is not nil and
-- string, then it's converted to string.
-- @treturn bool
function M.is_blank (value)
  return M.is_empty(value) or tostring(value):find('^%s*$') ~= nil
end

--- Returns true if the `value` is nil or empty string.
-- @treturn bool
function M.is_empty (value)
  return value == nil or value == ''
end

--- Returns a new table with the results of running `func(value, key)` once
-- for every key-value pair in the `tab`. Tables are iterated using @{pairs},
-- so this function is intended for tables that represent *associative arrays*.
--
-- @tparam function func The function that accepts at least one argument and
--   returns a value.
-- @tparam table tab The table to map over.
-- @treturn table A new table.
-- @see imap
function M.map (func, tab)
  local result = {}
  for key, val in pairs(tab) do
    result[key] = func(val, key)
  end
  return result
end

--- Returns a new table with the results of running `func(value, index)` once
-- for every item in the `tab`. Tables are iterated using @{ipairs}, so this
-- function is intended for tables that represent *indexed arrays*.
--
-- @tparam function func The function that accepts at least one argument and
--   returns a value.
-- @tparam table tab The table to map over.
-- @treturn table A new table.
-- @see map
function M.imap (func, tab)
  local result = {}
  for i, val in ipairs(tab) do
    table.insert(result, func(val, i))
  end
  return result
end

--- Returns a new table containing the contents of all the given tables.
-- Tables are iterated using @{pairs}, so this function is intended for tables
-- that represent *associative arrays*. Entries with duplicate keys are
-- overwritten with the values from a later table.
--
-- @tparam {table,...} ... The tables to merge.
-- @treturn table A new table.
-- @see concat
function M.merge (...)
  local result = {}

  for _, tab in ipairs {...} do
    for key, val in pairs(tab) do
      result[key] = val
    end
  end

  return result
end

--- Returns type of the given value. If `value` has a metatable with key
-- `__type`, then returns its value; otherwise returns Lua's raw type.
--
-- @param value
-- @treturn string A type of the `value`.
function M.mtype (value)
  local meta = getmetatable(value)

  if meta and meta.__type then
    return meta.__type
  else
    return type(value)
  end
end

--- Partial application.
-- Takes a function `func` and arguments, and returns a function *func2*.
-- When applied, *func2* returns the result of applying `func` to the arguments
-- provided initially followed by the arguments provided to *func2*.
--
-- @param func
-- @param ... Arguments to pass to the `func`.
-- @treturn func A partially applied function.
function M.partial (func, ...)
  local args1 = {...}

  return function(...)
    local args2 = {...}
    -- concat args1 and args2
    for i = 1, #args1 do table.insert(args2, i, args1[i]) end

    return func(unpack(args2))
  end
end

--- Performs left-to-right function composition.
--
-- @tparam {function,...} ... The functions to compose; as multiple arguments,
--   or in a single table.
-- @treturn function A composition of the given functions.
function M.pipe (...)
  local funcs = {...}

  if #funcs == 1 and type(funcs[1]) == 'table' then
    funcs = funcs[1]
  end

  local function pipe_inner (i, ...)
    if i == #funcs then
      return funcs[i](...)
    end
    return pipe_inner(i + 1, funcs[i](...))
  end

  return function(...)
    return pipe_inner(1, ...)
  end
end

--- Returns the result of calling `when_false` with the `value` if `pred`
-- function returns falsy for the `value`; otherwise returns the `value` as is.
--
-- @tparam function pred The predicate function.
-- @tparam function when_false The function to invoke when the `pred` evaluates
--   to a falsy value.
-- @param value The value to test with the `pred` function and pass to the
--   `when_false` if necessary.
-- @return The `value`, or the result of applying `value` to `when_false`.
function M.unless (pred, when_false, value)
  if pred(value) then
    return value
  end
  return when_false(value)
end

return M
