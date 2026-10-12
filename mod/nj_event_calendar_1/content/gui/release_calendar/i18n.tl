-- Mod strings in all game languages (game/base/strings: de en es fr it ja ko nl pl pt_BR ru zh_CN zh_TW).
-- The mod has no translation catalog of its own (the game does not read a mod's .mo catalogs, checked on
-- 12.10.2026), hence the table here. Terms follow the game's translations (Vehicle Store, Calendar, Upkeep, …).
-- Language: by how the game translated its own string "Vehicle Store" (it differs in all 13 languages),
-- otherwise by the code from api.util.getLanguage(), otherwise English. Call only while rendering: game
-- translations are not available yet when the module is loaded.

local i18n : ReleaseCalendarI18n = {}

local LANGS <const> = { "en", "de", "es", "fr", "it", "ja", "ko", "nl", "pl", "pt_BR", "ru", "zh_CN", "zh_TW" }

-- the game's translation of "Vehicle Store" -> language
local DETECT : {string : string} = {
	["Vehicle Store"] = "en",
	["Fahrzeugladen"] = "de",
	["Tienda de vehículos"] = "es",
	["Magasin de véhicules"] = "fr",
	["Negozio veicoli"] = "it",
	["車両ストア"] = "ja",
	["운송 수단 상점"] = "ko",
	["Showroom"] = "nl",
	["Sklep z pojazdami"] = "pl",
	["Loja de Veículos"] = "pt_BR",
	["Магазин транспорта"] = "ru",
	["载具商店"] = "zh_CN",
	["車輛商店"] = "zh_TW",
}

local STRINGS : {string : {string : string}} = {
	clock_year = {
		en = "Reporting period: {elapsed} of {total} of game time",
		de = "Berichtszeitraum: {elapsed} von {total} Spielzeit",
		es = "Período contable: {elapsed} de {total} de tiempo de juego",
		fr = "Période comptable : {elapsed} sur {total} de temps de jeu",
		it = "Periodo contabile: {elapsed} di {total} di tempo di gioco",
		ja = "会計期間: ゲーム時間 {total} 中 {elapsed}",
		ko = "회계 기간: 게임 시간 {total} 중 {elapsed}",
		nl = "Verslagperiode: {elapsed} van {total} speeltijd",
		pl = "Okres rozliczeniowy: {elapsed} z {total} czasu gry",
		pt_BR = "Período contábil: {elapsed} de {total} de tempo de jogo",
		ru = "Отчётный период: {elapsed} из {total} игры",
		zh_CN = "结算周期：游戏时间 {elapsed} / {total}",
		zh_TW = "結算週期：遊戲時間 {elapsed} / {total}",
	},
	clock_click = {
		en = "Click: event calendar",
		de = "Klick: Ereigniskalender",
		es = "Clic: calendario de eventos",
		fr = "Clic : calendrier des événements",
		it = "Clic: calendario degli eventi",
		ja = "クリック: イベントカレンダー",
		ko = "클릭: 이벤트 달력",
		nl = "Klik: gebeurtenissenkalender",
		pl = "Kliknij: kalendarz wydarzeń",
		pt_BR = "Clique: calendário de eventos",
		ru = "Клик — календарь событий",
		zh_CN = "点击：事件日历",
		zh_TW = "點擊：事件月曆",
	},
	window_title = {
		en = "Event calendar",
		de = "Ereigniskalender",
		es = "Calendario de eventos",
		fr = "Calendrier des événements",
		it = "Calendario degli eventi",
		ja = "イベントカレンダー",
		ko = "이벤트 달력",
		nl = "Gebeurtenissenkalender",
		pl = "Kalendarz wydarzeń",
		pt_BR = "Calendário de eventos",
		ru = "Календарь событий",
		zh_CN = "事件日历",
		zh_TW = "事件月曆",
	},
	year_in = {
		en = "in ≈ {time} of game time",
		de = "in ≈ {time} Spielzeit",
		es = "en ≈ {time} de tiempo de juego",
		fr = "dans ≈ {time} de temps de jeu",
		it = "tra ≈ {time} di tempo di gioco",
		ja = "ゲーム時間で約 {time} 後",
		ko = "게임 시간 약 {time} 후",
		nl = "over ≈ {time} speeltijd",
		pl = "za ≈ {time} czasu gry",
		pt_BR = "em ≈ {time} de tempo de jogo",
		ru = "через ≈ {time} игры",
		zh_CN = "约 {time} 游戏时间后",
		zh_TW = "約 {time} 遊戲時間後",
	},
	year_in_tip = {
		en = "Game time until January 1 at the current calendar speed",
		de = "Spielzeit bis zum 1. Januar bei der aktuellen Kalendergeschwindigkeit",
		es = "Tiempo de juego hasta el 1 de enero con la velocidad actual del calendario",
		fr = "Temps de jeu jusqu'au 1er janvier à la vitesse actuelle du calendrier",
		it = "Tempo di gioco fino al 1° gennaio alla velocità attuale del calendario",
		ja = "現在のカレンダー速度での1月1日までのゲーム時間",
		ko = "현재 달력 속도 기준 1월 1일까지의 게임 시간",
		nl = "Speeltijd tot 1 januari bij de huidige kalendersnelheid",
		pl = "Czas gry do 1 stycznia przy obecnej prędkości kalendarza",
		pt_BR = "Tempo de jogo até 1º de janeiro na velocidade atual do calendário",
		ru = "Время игры до 1 января при текущей скорости календаря",
		zh_CN = "按当前日历速度计算，到1月1日的游戏时间",
		zh_TW = "以目前月曆速度計算，到1月1日的遊戲時間",
	},
	status_new = {
		en = "new",
		de = "neu",
		es = "nuevo",
		fr = "nouveau",
		it = "nuovo",
		ja = "発売",
		ko = "출시",
		nl = "nieuw",
		pl = "nowy",
		pt_BR = "novo",
		ru = "новый",
		zh_CN = "上市",
		zh_TW = "上市",
	},
	status_retire = {
		en = "leaves the store",
		de = "nicht mehr erhältlich",
		es = "deja de venderse",
		fr = "retiré de la vente",
		it = "fuori produzione",
		ja = "販売終了",
		ko = "판매 종료",
		nl = "uit de verkoop",
		pl = "wycofany ze sprzedaży",
		pt_BR = "sai de linha",
		ru = "уходит из продажи",
		zh_CN = "停售",
		zh_TW = "停售",
	},
	status_milestone = {
		en = "milestone",
		de = "Meilenstein",
		es = "hito",
		fr = "étape",
		it = "traguardo",
		ja = "節目",
		ko = "이정표",
		nl = "mijlpaal",
		pl = "kamień milowy",
		pt_BR = "marco",
		ru = "веха",
		zh_CN = "里程碑",
		zh_TW = "里程碑",
	},
	show_details = {
		en = "Show vehicle details",
		de = "Fahrzeugdetails anzeigen",
		es = "Ver detalles del vehículo",
		fr = "Afficher les détails du véhicule",
		it = "Mostra i dettagli del veicolo",
		ja = "車両の詳細を表示",
		ko = "운송 수단 세부 사항 보기",
		nl = "Voertuigdetails tonen",
		pl = "Pokaż szczegóły pojazdu",
		pt_BR = "Mostrar detalhes do veículo",
		ru = "Показать карточку транспорта",
		zh_CN = "显示载具详情",
		zh_TW = "顯示車輛詳細資訊",
	},
	nothing = {
		en = "Nothing upcoming.",
		de = "Nichts geplant.",
		es = "No hay nada próximo.",
		fr = "Rien à venir.",
		it = "Nulla in arrivo.",
		ja = "予定はありません。",
		ko = "예정된 항목이 없습니다.",
		nl = "Niets gepland.",
		pl = "Brak nadchodzących wydarzeń.",
		pt_BR = "Nada por vir.",
		ru = "Ничего не ожидается.",
		zh_CN = "暂无即将发生的事件。",
		zh_TW = "暫無即將發生的事件。",
	},
	cost_mult = {
		en = "Inflation: ×{mult}",
		de = "Inflation: ×{mult}",
		es = "Inflación: ×{mult}",
		fr = "Inflation : ×{mult}",
		it = "Inflazione: ×{mult}",
		ja = "インフレ: ×{mult}",
		ko = "인플레이션: ×{mult}",
		nl = "Inflatie: ×{mult}",
		pl = "Inflacja: ×{mult}",
		pt_BR = "Inflação: ×{mult}",
		ru = "Инфляция: ×{mult}",
		zh_CN = "通货膨胀：×{mult}",
		zh_TW = "通貨膨脹：×{mult}",
	},
	cost_mult_note = {
		en = "Construction and upkeep costs of buildings whose prices grow with the year",
		de = "Bau- und Unterhaltskosten von Gebäuden, deren Preise mit den Jahren steigen",
		es = "Costes de construcción y conservación de edificios cuyos precios crecen con los años",
		fr = "Coûts de construction et d'entretien des bâtiments dont le prix augmente avec les années",
		it = "Costi di costruzione e manutenzione degli edifici il cui prezzo cresce con gli anni",
		ja = "年とともに価格が上がる建物の建設費と維持費",
		ko = "연도에 따라 가격이 오르는 건물의 건설 및 관리 비용",
		nl = "Bouw- en onderhoudskosten van gebouwen waarvan de prijs met de jaren stijgt",
		pl = "Koszty budowy i utrzymania budowli, których ceny rosną z latami",
		pt_BR = "Custos de construção e manutenção de construções cujo preço cresce com os anos",
		ru = "Цены и содержание построек, чья стоимость растёт с годом",
		zh_CN = "价格随年份上涨的建筑的建造与维护费用",
		zh_TW = "價格隨年份上漲的建築的建造與維護費用",
	},
	milestones = {
		en = "Milestones",
		de = "Meilensteine",
		es = "Hitos",
		fr = "Étapes",
		it = "Traguardi",
		ja = "節目",
		ko = "이정표",
		nl = "Mijlpalen",
		pl = "Kamienie milowe",
		pt_BR = "Marcos",
		ru = "Вехи",
		zh_CN = "里程碑",
		zh_TW = "里程碑",
	},
	status_new_short = {
		en = "new",
		de = "neu",
		es = "nuevo",
		fr = "nouv.",
		it = "nuovo",
		ja = "発売",
		ko = "출시",
		nl = "nieuw",
		pl = "nowy",
		pt_BR = "novo",
		ru = "нов.",
		zh_CN = "上市",
		zh_TW = "上市",
	},
	status_retire_short = {
		en = "ends",
		de = "Ende",
		es = "fin",
		fr = "fin",
		it = "fine",
		ja = "終了",
		ko = "종료",
		nl = "einde",
		pl = "koniec",
		pt_BR = "fim",
		ru = "снят",
		zh_CN = "停售",
		zh_TW = "停售",
	},
	status_milestone_short = {
		en = "event",
		de = "Ereig.",
		es = "hito",
		fr = "étape",
		it = "evento",
		ja = "節目",
		ko = "이정표",
		nl = "mijlp.",
		pl = "zdarz.",
		pt_BR = "marco",
		ru = "веха",
		zh_CN = "里程碑",
		zh_TW = "里程碑",
	},
	engine = {
		en = "Engine",
		de = "Antrieb",
		es = "Motor",
		fr = "Motorisation",
		it = "Motore",
		ja = "動力",
		ko = "동력",
		nl = "Aandrijving",
		pl = "Napęd",
		pt_BR = "Motor",
		ru = "Двигатель",
		zh_CN = "动力",
		zh_TW = "動力",
	},
	engine_horse = {
		en = "horse",
		de = "Pferd",
		es = "caballos",
		fr = "chevaux",
		it = "cavalli",
		ja = "馬",
		ko = "말",
		nl = "paard",
		pl = "konie",
		pt_BR = "cavalos",
		ru = "лошади",
		zh_CN = "马",
		zh_TW = "馬",
	},
	engine_steam = {
		en = "steam",
		de = "Dampf",
		es = "vapor",
		fr = "vapeur",
		it = "vapore",
		ja = "蒸気",
		ko = "증기",
		nl = "stoom",
		pl = "para",
		pt_BR = "vapor",
		ru = "пар",
		zh_CN = "蒸汽",
		zh_TW = "蒸汽",
	},
	engine_diesel = {
		en = "diesel",
		de = "Diesel",
		es = "diésel",
		fr = "diesel",
		it = "diesel",
		ja = "ディーゼル",
		ko = "디젤",
		nl = "diesel",
		pl = "diesel",
		pt_BR = "diesel",
		ru = "дизель",
		zh_CN = "柴油",
		zh_TW = "柴油",
	},
	engine_electric = {
		en = "electric",
		de = "Elektro",
		es = "eléctrico",
		fr = "électrique",
		it = "elettrico",
		ja = "電気",
		ko = "전기",
		nl = "elektrisch",
		pl = "elektr.",
		pt_BR = "elétrico",
		ru = "электро",
		zh_CN = "电力",
		zh_TW = "電力",
	},
	year_now = {
		en = "this year",
		de = "dieses Jahr",
		es = "este año",
		fr = "cette année",
		it = "quest'anno",
		ja = "今年",
		ko = "올해",
		nl = "dit jaar",
		pl = "w tym roku",
		pt_BR = "este ano",
		ru = "в этом году",
		zh_CN = "今年",
		zh_TW = "今年",
	},
	clock_next = {
		en = "Next period: {date}",
		de = "Nächster Zeitraum: {date}",
		es = "Próximo período: {date}",
		fr = "Période suivante : {date}",
		it = "Prossimo periodo: {date}",
		ja = "次の期間: {date}",
		ko = "다음 기간: {date}",
		nl = "Volgende periode: {date}",
		pl = "Następny okres: {date}",
		pt_BR = "Próximo período: {date}",
		ru = "Следующий период: {date}",
		zh_CN = "下一周期：{date}",
		zh_TW = "下一週期：{date}",
	},
}

local langCache : string = nil

local function known(code : string) : string
	if not code then
		return nil
	end
	code = code:gsub("-", "_")
	for __, l in ipairs(LANGS) do
		if l == code then
			return l
		end
	end
	local prefix = code:sub(1, 2)
	if prefix == "pt" then
		return "pt_BR"
	end
	if prefix == "zh" then
		local region = code:sub(4, 5):upper()
		return (region == "TW" or region == "HK" or region == "MO") and "zh_TW" or "zh_CN"
	end
	for __, l in ipairs(LANGS) do
		if l == prefix then
			return l
		end
	end
	return nil
end

i18n.language = function() : string
	if langCache then
		return langCache
	end
	local found = DETECT[_("Vehicle Store")]
	local codes : {string} = {}
	if not found then
		local ok, lang = pcall(api.util.getLanguage)
		if ok and type(lang) == "table" then
			for __, field in ipairs({ "code", "core", "locale", "language", "lang" }) do
				local v = (lang as {string : any})[field]
				if type(v) == "string" then
					codes[#codes + 1] = field .. "=" .. (v as string)
					found = found or known(v as string)
				end
			end
		end
	end
	langCache = found or "en"
	log.message("release_calendar: language " .. langCache .. (#codes > 0 and (" (" .. table.concat(codes, ", ") .. ")") or ""))
	return langCache
end

-- string by key in the game language; {name} placeholders are filled from vars
i18n.tr = function(key : string, vars? : {string : any}) : string
	local entry = STRINGS[key]
	local s = entry and (entry[i18n.language()] or entry.en) or key
	if vars then
		s = s:gsub("{(%w+)}", function(name : string) : string
			local v = vars[name]
			return v ~= nil and tostring(v) or ("{" .. name .. "}")
		end)
	end
	return s
end

return i18n
