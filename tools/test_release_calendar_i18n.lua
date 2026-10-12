-- Strings of the nj_event_calendar_1 mod (i18n.tl): language from the game's translation of "Vehicle Store", fallback is the code from
-- api.util.getLanguage(); {name} substitutions; every key has all 13 game languages.
local root = arg[0]:match("^(.*)/tools/[^/]+$") or "."
package.path = root .. "/tools/?.lua;" .. package.path
local tlrun = require("tlrun")
local PATH = root .. "/mod/nj_event_calendar_1/content/gui/release_calendar/i18n.tl"

log = { warning = print, message = function() end }
local function load(vehicleStore, language)
	_ = function(s) return s == "Vehicle Store" and vehicleStore or s end
	api = { util = { getLanguage = function() return language end } }
	return tlrun.load(PATH)
end

local function check(name, got, want)
	assert(got == want, name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

check("ru by vanilla string", load("Магазин транспорта", {}).language(), "ru")
check("zh_TW by vanilla string", load("車輛商店", {}).language(), "zh_TW")
check("en by vanilla string", load("Vehicle Store", { locale = "de_DE" }).language(), "en")
-- game translation unknown (language from a mod): by code
check("pt by code", load("?", { code = "pt" }).language(), "pt_BR")
check("zh_HK by locale", load("?", { locale = "zh_HK" }).language(), "zh_TW")
check("ko by core", load("?", { core = "ko" }).language(), "ko")
check("unknown -> en", load("?", { code = "cs" }).language(), "en")
check("getLanguage fails -> en", load("?", nil).language(), "en")

local i18n = load("Fahrzeugladen", {})
check("vars", i18n.tr("year_in", { time = "1:02:03" }), "in ≈ 1:02:03 Spielzeit")
check("missing var kept", i18n.tr("year_in"), "in ≈ {time} Spielzeit")
check("unknown key", i18n.tr("no_such_key"), "no_such_key")

-- completeness: all keys in all languages, same substitutions
local f = assert(io.open(PATH, "rb")); local src = f:read("a"); f:close()
local langs = { "en", "de", "es", "fr", "it", "ja", "ko", "nl", "pl", "pt_BR", "ru", "zh_CN", "zh_TW" }
local stores = { en = "Vehicle Store", de = "Fahrzeugladen", es = "Tienda de vehículos", fr = "Magasin de véhicules",
	it = "Negozio veicoli", ja = "車両ストア", ko = "운송 수단 상점", nl = "Showroom", pl = "Sklep z pojazdami",
	pt_BR = "Loja de Veículos", ru = "Магазин транспорта", zh_CN = "载具商店", zh_TW = "車輛商店" }
local keys = {}
for key in src:gmatch("\n\t([%w_]+) = {\n\t\ten = ") do keys[#keys + 1] = key end
assert(#keys >= 12, "keys found: " .. #keys)
local function vars(s)
	local list = {}
	for v in s:gmatch("{(%w+)}") do list[#list + 1] = v end
	table.sort(list)
	return table.concat(list, ",")
end
local en = {}
for _, l in ipairs(langs) do
	local m = load(stores[l], {})
	check("detect " .. l, m.language(), l)
	for _, key in ipairs(keys) do
		local s = m.tr(key)
		if l == "en" then
			en[key] = s
		else
			-- the same word in some languages ("Inflation", "diesel")
			local sameOk = { cost_mult = true, engine_diesel = true }
			assert(s ~= en[key] or sameOk[key], key .. " not translated to " .. l)
			check(key .. " vars in " .. l, vars(s), vars(en[key]))
		end
	end
end
print("ok: " .. #keys .. " keys × " .. #langs .. " languages")
