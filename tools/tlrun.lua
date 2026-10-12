-- Loads the mod's .tl modules in plain Lua 5.4 (for local tests with a fake api).
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/[^/]+$") or "."
package.path = root .. "/tools/?.lua;" .. package.path
log = log or { error = print, warning = print, message = print, verbose = function() end }
local tl = require("tl")
-- the game has no Lua 5.3+ functions (log 09.10.2026: "attempt to call field 'tointeger'"); remove them here too
-- so the tests fail the same way
math.tointeger = nil
math.type = nil
local M = {}
function M.load(path)
	local f = assert(io.open(path, "rb")); local src = f:read("a"); f:close()
	local env = tl.new_env({ defaults = { gen_target = "5.4", gen_compat = "off", feat_lax = "on" } })
	local code, result = tl.gen(src, env)
	if not code then
		for _, e in ipairs(result.syntax_errors or {}) do print(path .. ":" .. e.y .. ":" .. e.x .. ": " .. e.msg) end
		error("syntax errors in " .. path)
	end
	return assert(load(code, "@" .. path))()
end
return M
