script_name('Bank-Helper')
script_author('Cosmo')
script_version('26.0')

require "moonloader"
require "sampfuncs"
local ffi = require "ffi"
local memory = require "memory"
local dlstatus = require "moonloader".download_status
local bInicfg, inicfg       = pcall(require, "inicfg")
local bImgui, imgui         = pcall(require, "imgui")
local bEncoding, encoding   = pcall(require, "encoding")
local bse, se               = pcall(require, "samp.events")

local mc, sc, wc = '{3F68D1}', '{516894}', '{FFFFFF}'
local mcx = 0x3F68D1

local u8 = encoding.UTF8
encoding.default = 'CP1251'
local noErrorDialog = false
local tag = string.format("[ Central Bank ] %s", wc)
local id_kassa = 0
local distBetweenKassa = 0
local temp_prem = nil
local lections = {}
local status_button_gov = false
local go_credit = false
local unform_pickup_pos = { -2687.625, 820.875, 1500.875 }
local stick_pickup_pos = { -2687.625, 818.125, 1500.875 }
local jsn_upd = "https://gitlab.com/snippets/1978930/raw"
local lect_path = getWorkingDirectory() .. '\\BHelper\\Lections.json'
local calc_font = renderCreateFont('Calibri', 12, 1)

local cfg = inicfg.load({
	main = 
	{
		rank = 1,
		dateuprank = os.time(),
		sex = 1,
		autoF8 = false,
		LectDelay = 5,
		MsgDelay = 2.5,
		rpbat = false,
		rpbat_true = "/me {sex:снял|сняла} дубинку с пояса взяв в правую руку",
		rpbat_false = "/me {sex:повесил|повесила} дубинку на пояс" , 
		colorRchat = 4282626093,
		colorDchat = 4294940723,
		black_theme = true,
		accent_status = false,
		accent = '[Деловая речь]',
		infoupdate = false,
		loginupdate = true,
		KipX = select(1, getScreenResolution()) - 250,
		KipY = select(2, getScreenResolution()) / 2, 
		ki_stat = true,
		expelReason = 'Н.П.Б',
		chat_calc = false,
		pincode = "",
		auto_uniform = true,
		auto_stick = true,
		bank_color = 2150206647,
		time_offset = 0
	},
	Chat = {
		expel = true,
		shtrafs = true,
		incazna = true,
		invite = true,
		uval = true
	},
	nameRank = {
		'Охранник', 
		'Старший охранник', 
		'Начальник охраны', 
		'Ст.Сотрудник банка', 
		'Нач.Отдела сбережений', 
		'Зав.Отдела сбережений', 
		'Менеджер', 
		'Зам.Директора', 
		'Директор Банка', 
		'Министр Финансов'
	},
	govstr = {
		'[Центральный банк] Уважаемые жители штата!',
		'[Центральный банк] На данный момент проходит День Открытых Дверей в Центральный банк!',
		'[Центральный банк] Вам нужно явиться в Холл Банка! Ждём вас!'
	},
	govdep = {
		'[БАНК] - [Всем] Занимаю гос.волну, просьба не перебивать',
		'[БАНК] - [Всем] Освобождаю гос.волну'
	},
	blacklist = {},
	Binds_Name = {},
	Binds_Action = {},
	Binds_Deleay = {}
}, "Bank_Config")

local ui_meta = {
    __index = function(self, v)
        if v == "switch" then
            local switch = function()
                if self.process and self.process:status() ~= "dead" then
                    return false
                end
                self.timer = os.clock()
                self.state = not self.state

                self.process = lua_thread.create(function()
                    local bringFloatTo = function(from, to, start_time, duration)
                        local timer = os.clock() - start_time
                        if timer >= 0.00 and timer <= duration then
                            local count = timer / (duration / 100)
                            return count * ((to - from) / 100)
                        end
                        return (timer > duration) and to or from
                    end

                    while true do wait(0)
                        local a = bringFloatTo(0.00, 1.00, self.timer, self.duration)
                        self.alpha = self.state and a or 1.00 - a
                        if a == 1.00 then break end
                    end
                end)
                return true
            end
            return switch
        end
    end
}

local bank = { state = false, alpha = 0.0, duration = 0.1 }
setmetatable(bank, ui_meta)

local int_bank = { state = false, alpha = 0.0, duration = 0.1 }
setmetatable(int_bank, ui_meta)

local ustav_window = { state = false, alpha = 0.0, duration = 0.1 }
setmetatable(ustav_window, ui_meta)

local infoupdate = { state = false, alpha = 0.0, duration = 0.1 }
setmetatable(infoupdate, ui_meta)

local kassa = {
	state = imgui.ImBool(false),
	name = imgui.ImBuffer(256),
	time = imgui.ImBuffer(256),
	info = { dep = 0, card = 0, credit = 0, recard = 0, vip = 0, addcard = 0 },
	pos = { x = 0, y = 0, z = 0 },
	money = 0
}

-- Imgui variables
local type_window       = imgui.ImInt(1)
local TypeAction        = imgui.ImInt(1)
local giverank          = imgui.ImInt(1)
local text_binder       = imgui.ImBuffer(65536) 
local binder_name       = imgui.ImBuffer(40) 
local binder_delay      = imgui.ImFloat(2.5)
local search_ustav      = imgui.ImBuffer(256)
local credit_sum        = imgui.ImInt(5000)
local mGov              = imgui.ImInt(30)
local hGov              = imgui.ImInt(15)
local gosScreen         = imgui.ImBool(true)
local gosDep            = imgui.ImBool(true)
local typeLect          = imgui.ImInt(1)
local lect_edit_name    = imgui.ImBuffer(256)
local lect_edit_text    = imgui.ImBuffer(65536)
local delayGov          = imgui.ImInt(2500)
local blacklist 		= imgui.ImBuffer(256)
local chat_calc			= imgui.ImBool(cfg.main.chat_calc)
local loginupdate       = imgui.ImBool(cfg.main.loginupdate)
local auto_uniform		= imgui.ImBool(cfg.main.auto_uniform)
local auto_stick 		= imgui.ImBool(cfg.main.auto_stick)
local ki_stat           = imgui.ImBool(cfg.main.ki_stat)
local rank              = imgui.ImInt(cfg.main.rank)
local sex               = imgui.ImInt(cfg.main.sex)
local autoF8            = imgui.ImBool(cfg.main.autoF8)
local LectDelay         = imgui.ImInt(cfg.main.LectDelay)
local MsgDelay			= imgui.ImFloat(cfg.main.MsgDelay)
local rpbat             = imgui.ImBool(cfg.main.rpbat)
local rpbat_true        = imgui.ImBuffer(u8(cfg.main.rpbat_true), 256) 
local rpbat_false       = imgui.ImBuffer(u8(cfg.main.rpbat_false), 256)
local colorRchat        = imgui.ImFloat4(imgui.ImColor(cfg.main.colorRchat):GetFloat4())
local colorDchat        = imgui.ImFloat4(imgui.ImColor(cfg.main.colorDchat):GetFloat4())
local black_theme       = imgui.ImBool(cfg.main.black_theme)
local accent_status     = imgui.ImBool(cfg.main.accent_status)
local accent            = imgui.ImBuffer(u8(cfg.main.accent), 256)
local expelReason       = imgui.ImBuffer(u8(cfg.main.expelReason), 256)
local pincode 			= imgui.ImBuffer(tostring(cfg.main.pincode), 128)
CONNECTED_TO_ARIZONA 	= false
PIN_PASSWORD = false

local govstr = {
	[1] = imgui.ImBuffer(u8(cfg.govstr[1]), 256),
	[2] = imgui.ImBuffer(u8(cfg.govstr[2]), 256),
	[3] = imgui.ImBuffer(u8(cfg.govstr[3]), 256)
}

local govdep = { 
	[1] = imgui.ImBuffer(u8(cfg.govdep[1]), 256),
	[2] = imgui.ImBuffer(u8(cfg.govdep[2]), 256),
}

local chat = {
	['expel'] = imgui.ImBool(cfg.Chat.expel),
	['shtrafs'] = imgui.ImBool(cfg.Chat.shtrafs),
	['incazna'] = imgui.ImBool(cfg.Chat.incazna),
	['invite'] = imgui.ImBool(cfg.Chat.invite),
	['uval'] = imgui.ImBool(cfg.Chat.uval)
}

local UI_COLORS = {
	["B"] = {
		[true] = imgui.ImVec4(0.05, 0.05, 0.07, 1.00),
		[false] = imgui.ImVec4(0.93, 0.93, 0.93, 1.00)
	},
	["E"] = {
		[true] = imgui.ImVec4(0.10, 0.30, 0.50, 1.00),
		[false] = imgui.ImVec4(0.10, 0.30, 0.50, 1.00)
	},
	["T"] = {
		[true] = imgui.ImVec4(0.95, 0.95, 0.95, 1.00),
		[false] = imgui.ImVec4(0.15, 0.15, 0.20, 1.00)
	}
}

local SCRIPT_STYLE = {
	colors = {
		['B'] = UI_COLORS["B"][black_theme.v],
		['E'] = UI_COLORS["E"][black_theme.v],
		['T'] = UI_COLORS["T"][black_theme.v],
	},
	clock = nil
}

local notf_sX, notf_sY = convertGameScreenCoordsToWindowScreenCoords(630, 438)
local notify = {
	messages = {},
	active = 0,
	max = 6,
	list = {
		pos = { x = notf_sX - 200, y = notf_sY },
		npos = { x = notf_sX - 200, y = notf_sY },
		size = { x = 200, y = 0 }
	}
}

local mMenu = {
	status = false,
	isMember = false,
	timer = nil,
	time = { all = 0, today = 0 }, 
	cards = { all = 0, today = 0 }, 
	dep = { all = 0, today = 0 },
	last_up = nil
}

local await = {}

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(0) end
	log('Начало подготовки к запуску..', "Подготовка")

	if loginupdate.v then autoupdate(jsn_upd) end

	if not doesFileExist('moonloader/config/Bank_Config.ini') then
		if inicfg.save(cfg, 'Bank_Config.ini') then log('Создан файл Bank_Config.ini', "Подготовка") end
	end

	if checkData() then
		log('Проверка файлов прошла успешно!', "Подготовка")
	end

	if not checkServer(select(1, sampGetCurrentServerAddress())) then
		addBankMessage('Скрипт работает только на проекте {M}Arizona RP')
		unload(false)
	end

	log('Скрипт готов к работе!', "Подготовка")
	addNotify("Главное меню: {006AC2}/bank\nВзаимодействие: {006AC2}ПКМ + Q", 5)
	addNotify("Текущая версия: {006AC2}"..thisScript().version.."\nСкрипт загружен!", 5)

	if cfg.main.infoupdate then
		infoupdate:switch()
		cfg.main.infoupdate = false
		inicfg.save(cfg, 'Bank_Config.ini')
	end

	sampRegisterChatCommand('bank', function()
		bank:switch()
	end)

	if sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == 'Jeffy_Cosmo' then
		log('Вы вошли как разработчик!')
		devmode = true

		sampRegisterChatCommand('setrankdev', function(rank)
			rank = tonumber(rank)
			if rank and rank >= 1 and rank <= 10 then
				cfg.main.rank = tonumber(rank)
				addBankMessage(string.format('Тестовый ранг [%s] выдан', rank))
			end
		end)
	end

	sampRegisterChatCommand("getprize", function()
		local pX, pY, pZ = getCharCoordinates(PLAYER_PED)

		for id = 0, 4095 do
			local pickup = sampGetPickupHandleBySampId(id)
			if doesPickupExist(pickup) then
				local x, y, z = getPickupCoordinates(pickup)
				bX = math.modf(x) == -2678
				bY = math.modf(y) == 795
				bZ = math.modf(z) == 1501

				local dist = getDistanceBetweenCoords3d(pX, pY, pZ, x, y, z)
				if bX and bY and bZ and dist <= 15 then
					return lua_thread.create(function()
						sampSendPickedUpPickup(id)
						wait(50)
						setGameKeyState(21, 255)
					end)
				end
			end
		end
		addBankMessage("Пикап для получения ларца слишком далеко от вас!")
	end)

	sampRegisterChatCommand('kip', function()
		if not kassa.state.v then 
			addBankMessage('Встаньте на пост или включите панель в настройках')
			return false
		end
		lua_thread.create(function ()
			while imgui.IsMouseDown(0) do wait(0) end
		    process_position = { true, cfg.main.KipX, cfg.main.KipY }
		    addBankMessage('Нажмите {M}ЛКМ{W} что-бы сохранить местоположение, или {M}ESC{W} что-бы отменить')
		    while process_position ~= nil do
		        local x, y = getCursorPos()
		        cfg.main.KipX = x
		        cfg.main.KipY = y
		        wait(0)
		    end
		end)
	end)

	sampRegisterChatCommand('ustav', function()
		ustav_window:switch()
	end)

	sampRegisterChatCommand('ro', function(text)
		if #text > 0 then
			sampSendChat('/r [Объявление] '..text)
			return
		end
		addBankMessage('Используй /ro [text]')
	end)

	sampRegisterChatCommand('rbo', function(text)
		if #text > 0 then
			sampSendChat('/rb [Объявление] '..text)
			return
		end
		addBankMessage('Используй /rbo [text]')
	end)

	sampRegisterChatCommand('fwarn', function(args)
		if cfg.main.rank >= 9 or devmode then
			local id, reason = args:match('^%s*(%d+) (.+)')
			if id ~= nil and reason ~= nil then
				id = tonumber(id)
				if sampIsPlayerConnected(id) then
					play_message(MsgDelay.v, true, {
						{ "/me {sex:открыл|открыла} на планшете раздел «Сотрудники»" },
						{ "/me {sex:выбрал|выбрала} сотрудника %s", rpNick(id) },
						{ "/me в меню {sex:выбрал|выбрала} пункт «Выдать выговор»" },
						{ "/fwarn %s %s", id, reason }
					})
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /fwarn [id] [причина]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('invite', function(id)
		if cfg.main.rank >= 9 or devmode then
			local id = tonumber(id)
			if id ~= nil then
				if sampIsPlayerConnected(id) then
					if not isPlayerOnBlacklist(sampGetPlayerNickname(id)) then 
						play_message(MsgDelay.v, true, {
							{ "/me {sex:достал|достала} планшет и {sex:открыл|открыла} базу данных" },
							{ "/me {sex:перешёл|перешла} в раздел «Сотрудники» и {sex:внёс|внесла} туда нового сотрудника %s", rpNick(id) },
							{ "/me {sex:передал|передала} сотруднику ключи от шкафчика" },
							{ "/invite %s", id }
						})
						return
					end
					addBankMessage('Вы не можете принять этого игрока во фракцию!')
					addBankMessage(string.format('Игрок {M}%s{W} находится в {FF0000}чёрном списке{W}!', rpNick(id)))
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /invite [id]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('giverank', function(args)
		if cfg.main.rank >= 9 or devmode then
			local id, rank = args:match('^%s*(%d+) (%d+)')
			if id ~= nil and rank ~= nil then
				id, rank = tonumber(id), tonumber(rank)
				local result, dist = getDistBetweenPlayers(id)
				if result and dist < 5 then
					if rank >= 1 and rank <= 9 then
						play_message(MsgDelay.v, true, {
							{ "/me {sex:достал|достала} из кармана КПК" },
							{ "/me {sex:включил|включила} КПК и {sex:зашёл|зашла} в раздел «Сотрудники»" },
							{ "/me {sex:выбрал|выбрала} сотрудника %s", rpNick(id) },
							{ "/me {sex:изменил|изменила} должность сотруднику на «%s»", cfg.nameRank[rank] },
							{ "/giverank %s %s", id, rank }
						})
						return
					end
					addBankMessage('Укажите должность от 1 до 9!')
					return
				end
				addBankMessage('Вы далеко от этого сотрудника!')
				return
			end
			addBankMessage('Используй: /giverank [id] [Ранг]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('uninvite', function(args)
		if cfg.main.rank >= 9 or devmode then
			local id, reason = args:match('^%s*(%d+) (.+)')
			if id ~= nil and reason ~= nil then
				id = tonumber(id)
				if sampIsPlayerConnected(id) then
					play_message(MsgDelay.v, true, {
						{ "/me {sex:достал|достала} планшет и {sex:открыл|открыла} базу данных" },
						{ "/me {sex:перешёл|перешла} в раздел «Сотрудники» и {sex:нашёл|нашла} там %s", rpNick(id) },
						{ "/me {sex:выбрал|выбрала} сотрудника и {sex:нажал|нажала} «Уволить»" },
						{ "/uninvite %s %s", id, reason }
					})
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /uninvite [id] [причина]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('blacklist', function(args)
		if cfg.main.rank >= 9 or devmode then
			local id, reason = args:match('^%s*(%d+) (.+)')
			if id ~= nil and reason ~= nil then
				id = tonumber(id)
				if sampIsPlayerConnected(id) then
					play_message(MsgDelay.v, true, {
						{ "/me {sex:открыл|открыла} на планшете раздел «Чёрный список»" },
						{ "/me в меню {sex:выбрал|выбрала} пункт «Добавить»" },
						{ "/me {sex:внёс|внесла} сотрудника %s в чёрный список банка", rpNick(id) },
						{ "/blacklist %s %s", id, reason }
					})
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /blacklist [id] [причина]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('unblacklist', function(id)
		if cfg.main.rank >= 9 or devmode then
			id = tonumber(id)
			if id ~= nil then
				if sampIsPlayerConnected(id) then
					play_message(MsgDelay.v, true, {
						{ "/me {sex:открыл|открыла} на планшете раздел «Чёрный список»" },
						{ "/me в меню {sex:выбрал|выбрала} пункт «Исключить»" },
						{ "/me {sex:исключил|исключила} сотрудника %s из чёрного списка банка", rpNick(id) },
						{ "/unblacklist %s", id }
					})
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /unblacklist [id]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return
	end)

	sampRegisterChatCommand('unfwarn', function(id)
		if cfg.main.rank >= 9 or devmode then
			id = tonumber(id)
			if id ~= nil then
				if sampIsPlayerConnected(id) then
					play_message(MsgDelay.v, true, {
						{ "/me {sex:открыл|открыла} на планшете раздел «Сотрудники»" },
						{ "/me {sex:выбрал|выбрала} сотрудника %s", rpNick(id) },
						{ "/me в меню {sex:выбрал|выбрала} пункт «Снять выговор»" },
						{ "/unfwarn %s", id }
					})
					return
				end
				addBankMessage('Такого игрока нет в сети!')
				return
			end
			addBankMessage('Используй: /unfwarn [id]')
			return
		end
		addBankMessage('Команда доступна только с 9-ого ранга')
		return  
	end)

	lua_thread.create(function()
		while not sampIsLocalPlayerSpawned() do wait(1000) end
		if sampIsLocalPlayerSpawned() then
			await['get_rank'] = os.clock()
			sampSendChat('/stats')
		end
	end)
 	
	while true do

		if isKeyJustPressed(VK_F9) then 
			sampSendChat('/time')
		end

		if cfg.main.rpbat then 
			frpbat()
		end

		local result, id = sampGetPlayerIdOnTargetKey(VK_Q)
		if result then
			if getCharActiveInterior(PLAYER_PED) ~= 0 or devmode then
				addBankMessage('Используй {M}Esc{W} что бы закрыть меню')
				actionId = id

				if not int_bank.state then
					int_bank:switch()
					if sampGetPlayerColor(id) == cfg.main.bank_color and cfg.main.rank >= 9 then
						member_menu(id)
					else
						TypeAction.v = 1
					end
				end
			else
				addBankMessage('Работает только в интерьере!')
			end
		end

		local result, id = sampGetPlayerIdOnTargetKey(VK_G)
		if result and isUniformWearing() and cfg.main.rank >= 5 then
			go_expel(id)
		end

		local result, id = sampGetPlayerIdOnTargetKey(VK_R)
		if result then
			actionId = id
			addBankMessage(string.format('Игрок {M}%s{W} выбран в качестве значения {M}{select_id/name}', rpNick(actionId)))
		end

		if testCheat('BB') and not bank.state and not int_bank.state then
			type_window.v = 1
			bank:switch()
		end

		if status_button_gov then 
			if tonumber(os.date("%S", os.time())) == 00 and antiflud then
				if tonumber(os.date("%H", os.time())) == hGov.v and tonumber(os.date("%M", os.time())) == mGov.v - 1 then
					antiflud = false
					addNotify("Через {006AC2}минуту{SSSSSS} GOV волна\n{006D86}Оставайтесь в игре!", 10)
				end
			end
			if tonumber(os.date("%H", os.time())) == hGov.v and tonumber(os.date("%M", os.time())) == mGov.v then 
				status_button_gov = false
				goGov()
			end
		end

		if sampIsChatInputActive() and chat_calc.v then
			local isCalled, input = pcall(sampGetChatInputText)
		    if isCalled and string.find(input, "[0-9]+") and string.find(input, "[%+%-%*%/%^]+") then 
				local result, answer = pcall(load('return ' .. input))
				if result then
					local output = string.format('Результат: {50AAFF}%s', answer)
					if tonumber(answer) then
						local result = { string.match(answer, "^([^%d]*%d)(%d*)(.-)$") }
						result[2] = string.reverse(string.gsub(string.reverse(result[2]), "(%d%d%d)", "%1 "))
						output = string.format('Результат: {50AAFF}%s', table.concat(result))
					end
					
					local element = getStructElement(sampGetInputInfoPtr(), 0x8, 4)
			        local X = getStructElement(element, 0x8, 4)
			        local Y = getStructElement(element, 0xC, 4) + 45
			        local l = renderGetFontDrawTextLength(calc_font, output)
			        local h = renderGetFontDrawHeight(calc_font)
			        renderDrawBox(X, Y, l + 15, h + 15, 0xFF101010)
			        renderFontDrawText(calc_font, output, X + 7.5, Y + 7.5, 0xFFFFFFFF)
					if isKeyJustPressed(0x09) then 
						sampSetChatInputText(answer) 
					end
				end
			end
		end

		if not sampIsCursorActive() and isKeyJustPressed(VK_BACK) then
			if SPEAKING and not SPEAKING.dead then
				addBankMessage('Отыгровка прервана!')
				SPEAKING:terminate()
			end
		elseif SPEAKING and not SPEAKING.dead then
			local sx, sy = getScreenResolution()
			local text = "Нажмите " .. sc .. "BACKSPACE" .. wc .. ", если хотите прервать отыгровку"
			local len = renderGetFontDrawTextLength(calc_font, text)
			local hei = renderGetFontDrawHeight(calc_font)
			local X, Y = 10, sy - hei - 5

			renderFontDrawText(calc_font, text:gsub("{%x+}", ""), X + 1, Y + 1, 0x40000000)
			renderFontDrawText(calc_font, text, X, Y, 0x90FFFFFF)
		end

		if bank.state or int_bank.state or ustav_window.state or infoupdate.state or process_position then 
			imgui.ShowCursor = true
			imgui.Process = true
		elseif kassa.state.v or #notify.messages > 0 then
			imgui.ShowCursor = false
			imgui.SetMouseCursor(-1)
			imgui.Process = true
		else
			imgui.Process = false
		end

	wait(0)
	end
end

function member_menu(id)
	sampSendChat("/checkjobprogress " .. id)
	mMenu = {
		status = false,
		isMember = true,
		timer = os.clock(),
		time = { all = 0, today = 0 }, 
		cards = { all = 0, today = 0 }, 
		dep = { all = 0, today = 0 },
		last_up = nil
	}
	TypeAction.v = 3
end

function play_message(delay, screen, text_array)
	if SPEAKING ~= nil and not SPEAKING.dead then
		addBankMessage('У вас уже воспроизводится какая-то отыгровка, дождитесь её окончания!')
		addBankMessage('Прервать текущую отыгровку: {M}Ctrl {W}+{M} Backspace!')
		return false
	end
	SPEAKING = lua_thread.create(function()
		for i, line in ipairs(text_array) do
			sampSendChat(string.format(line[1], table.unpack(line, 2)))
			if i ~= #text_array then
				wait(delay * 1000)
			elseif screen == true then
				wait(1000)
				takeAutoScreen()
			end
		end
	end)
	return true
end

function se.onGivePlayerMoney(count)
	if kassa.state.v and count > 0 then
		kassa.money = kassa.money + count
	end
end

function se.onCreatePickup(id, model, pickupType, position)
	if model == 18631 then 
		return {id, 1274, pickupType, position} -- $$$ Dollar $$$
	end
end

function se.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text)
	if ki_stat.v then
		if text:find('Касса') and text:find(sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))) then
			kassa.pos = { 
				x = position.x, 
				y = position.y, 
				z = position.z
			}
			kassa.state.v = true
			kassa.name.v = text:match('Рабочее место: (.+)\n\nЗакреплен')
			kassa.time.v = tostring(text:match('На посту: {FFA441}(%d+){FFFFFF} минут'))
			if kassa.time.v:match('^0') then 
				addBankMessage('Вы встали за кассу! Изменить местоположение виджета: {W}/kip')
				
				kassa.money = 0
				kassa.info = { 
					dep = 0, 
					card = 0, 
					credit = 0, 
					recard = 0, 
					vip = 0,
					addcard = 0
				}
			end
			return false
		end
		if kassa.name.v ~= '' and text:find(kassa.name.v) and text:find('Свободно') then
			kassa.state.v = false
			kassa.name.v = ''
		end
	end
end

function rpNick(id)
	local nick = sampGetPlayerNickname(id)
	return string.gsub(nick, '_', ' ')
end

function goGov()
	lua_thread.create(function()
		if gosDep.v and #govdep[1].v > 0 then sampSendChat('/d '..u8:decode(govdep[1].v)) end
		if #govstr[1].v > 0 then wait(delayGov.v); sampSendChat('/gov '..u8:decode(govstr[1].v)) end
		if #govstr[2].v > 0 then wait(delayGov.v); sampSendChat('/gov '..u8:decode(govstr[2].v)) end
		if #govstr[3].v > 0 then wait(delayGov.v); sampSendChat('/gov '..u8:decode(govstr[3].v)) end
		if gosDep.v and #govdep[1].v > 0 then wait(delayGov.v); sampSendChat('/d '..u8:decode(govdep[2].v)) end
		if gosScreen.v then wait(500); sampSendChat('{screen}') end
	end)
end

function se.onServerMessage(clr, msg)
	local self_id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))

	local send = function(message)
		math.randomseed(os.clock())
		lua_thread.create(function()
			wait(200 + math.random(-100, 100))
			sampSendChat(message)
		end)
	end

	if msg:match('^%* [a-zA-Z_]+ оглушил [a-zA-Z_]+ при помощи Дубинка') then
		local player1, player2 = msg:match('^%* ([a-zA-Z_]+) оглушил ([a-zA-Z_]+) при помощи Дубинка')
		local id1, id2 = getPlayerIdByNickname(player1), getPlayerIdByNickname(player2)
		if id1 and id2 then 
			local color1, color2 = sampGetPlayerColor(id1), sampGetPlayerColor(id2)
			if color1 == color2 and color1 == cfg.main.bank_color then 
				sampAddChatMessage('[Warning] Замечено ТК от сотрудника '..player1..'('..id1..')', 0xAA3333)
			end
			local msg = msg:gsub(player1, player1..'('..id1..')')
			local msg = msg:gsub(player2, player2..'('..id2..')')
			return {clr, msg}
		end
	end

	if msg:find('Используйте: /jobprogress %[ ID игрока %]') then
		return false
	end

	local rank = string.match(msg, "^Лидер [A-z0-9_]+ повысил до (%d+) ранга")
	if rank ~= nil then
		cfg.main.dateuprank = os.time()
		cfg.main.rank = tonumber(rank)
	end

	if msg:find(sampGetPlayerNickname(self_id)..' переодевается в гражданскую одежду') then
		addNotify('{006D86}Рабочий день окончен!\nУдачно отдохнуть!', 5)
		return false
	end

	if msg:find(sampGetPlayerNickname(self_id) .. ' переодевается в рабочую одежду') then
		addNotify('{006D86}Вы начали рабочий день!\nПродуктивного дня!', 5)
		
		lua_thread.create(function ()
			wait(100)
			cfg.main.bank_color = sampGetPlayerColor(self_id)
		end)

		await["uniform"] = nil
		return false
	end

	local member, client, reason = msg:match('%[i%] (.+){FFFFFF} выгнал (.+) из банка! Причина: (.+)')
	if member and client and reason then 
		if chat['expel'].v then
			msg = string.format(tag .. 'Сотрудник %s выгнал из банка %s по причине: %s', sc .. member .. wc, sc .. client .. wc, sc .. reason)
			return { 0x3F68D1FF, msg }
		end
		return false
	end

	local sum, nick = msg:match('^%[БАНК%] {%x+}Организация получила (%d+%$) %(16 процентов%) за оплату штрафа игроком ([A-z0-9_]+)')
	if sum and nick then 
		if chat['shtrafs'].v then
			msg = string.format(tag .. 'Казна банка пополнена на %s. Житель %s внёс оплату за штраф', sc .. sum .. wc, sc .. nick:gsub('_', ' ') .. wc)
			return { 0x3F68D1FF, msg }
		end
		return false
	elseif msg:find('^Остальные деньги были распределены между полицией штата') and chat['shtrafs'].v then
		return false
	end

	local nick, sum = msg:match('^{%x+}([A-z0-9_]+) {%x+}пополнил счет организации на {%x+}(%d+%$)')
	if nick and sum then 
		if chat['incazna'].v then
			msg = string.format(tag .. 'Сотрудник %s пополнил казну банка на %s', sc .. nick:gsub('_', ' ') .. wc, sc .. sum .. wc)
			return { 0x3F68D1FF, msg }
		end
		return false
	end

	local member, leader = msg:match('^Приветствуем нового члена нашей организации ([A-z0-9_]+), которого пригласил: ([A-z0-9_]+)')
	if member and leader then 
		if chat['invite'].v then
			msg = string.format(tag .. 'Новый член нашей организации - %s, которого принял(а) %s', sc .. member:gsub('_', ' ') .. wc, sc .. leader:gsub('_', ' ') .. wc)
			return { 0x3F68D1FF, msg }
		end
		return false
	end

	local leader, member, reason = string.match(msg, '{FFFFFF}(.+) выгнал (.+) из организации. Причина: (.+)')
	if leader and member and reason then 
		if chat['uval'].v then
			msg = string.format(tag .. 'Руководитель %s уволил сотрудника %s по причине: %s', sc .. leader:gsub('_', ' ') .. wc, sc .. member:gsub('_', ' ') .. wc, wc .. reason)
			return { 0x3F68D1FF, msg }
		end
		return false
	end

	local accepted = string.match(msg, '%[Информация%] {FFFFFF}Вы успешно выдали кредит игроку {73B461}(.+)')
	if accepted then
		addNotify("{006D86}Одобрено!\nКредит оформлен!", 8)
		return false
	end

	if msg:find('^%[R%]') and clr == 0x2DB043FF then
		if msg:find('%[Объявление%]') then
			msg = msg:gsub('%[Объявление%] ', '', 1)
			msg = msg:gsub('^%[R%]', '[Объявление]', 1)
			clr = 0xFFAE00FF
		else
			if msg:find('%(%( Премия для сотрудников на должности .+ %)%)$') then
				rank_prem = msg:match('%(%( Премия для сотрудников на должности (.+) %)%)$')
				return false
			end

			local cR, cG, cB, cA = imgui.ImColor(cfg.main.colorRchat):GetRGBA()
			local nick = msg:match('([A-z0-9_]+)%[%d+%]')
			if nick == "Jeffy_Cosmo" then
				msg = msg:gsub("(" .. nick .. "%[%d+%])", "{FFC300}%1" .. ("{%06X}"):format(join_rgb(cR, cG, cB)), 1)

				if msg:find("(( @bh_ver ))", 1, true) and not devmode then
					lua_thread.create(function()
						local text = ("/rb Bank-Helper %s"):format(thisScript().version)
						wait(0); sampSendChat(text)
					end)
				end
			end
			clr = join_argb(cR, cG, cB, cA)
		end

		return { clr, msg }
	end

	if msg:match('^%[D%].*%[%d+%]:') and clr == 0x3399FFFF then
		local r, g, b, a = imgui.ImColor(cfg.main.colorDchat):GetRGBA()
		return { join_argb(r, g, b, a), msg }
	end

	if msg:find('%[Ошибка%] {FFFFFF}Ваш клиент отказался от получения кредита!') then
		addNotify("{006D86}Отмена операции!\nКлиент отказался", 8)
		await['credit_send'] = nil
		return false
	end
	if msg:find('%[Ошибка%] {FFFFFF}У этого человека уже есть задолженность в банке!') and await['credit_send'] then
		addNotify("У человека уже есть\nоформленный кредит!", 8)
		sampSendChat('К сожалению, выяснилось, что на вас уже оформлен один кредит, погасите сначала его')
		await['credit_send'] = nil
		return false
	end

	if msg:find('%[Ошибка%] {FFFFFF}Вы далеко от игрока!') or msg:find('^Отказано в доступе') then 
		await = {}
	end

	if msg:find('%[Ошибка%] {FFFFFF}У этого человека уже есть банковская карта!') then 
		await['card_create'] = nil
		addNotify("{006D86}Операция отменена!\nКарта уже существует", 5)
		return false
	end
	
	if msg:find('%[Ошибка%] {FFFFFF}У этого человека недостаточно средств!') and await['card_create'] then
		addNotify("{006D86}Операция отменена!\nНедостаточно средств", 8)
		sampSendChat('Данная услуга стоит 3.000$, У вас, как я вижу таких денег нет, приходите в другой раз')
		await['card_create'] = nil
		return false
	end

	if msg:find('%[Информация%] {FFFFFF}Вы покинули пост!') then 
		kassa.state.v = false
		addNotify('{006D86}Пост:\nВы покинули пост!', 5)
		return false
	end

	if msg:find("^Добро пожаловать на Arizona Role Play!$") then
		CONNECTED_TO_ARIZONA = true
	end

	if msg:find('выдал премию %(%d+%) всем членам организации') and clr == -218038273 then
		local leader, sum = msg:match('([A-z0-9_]+)%[%d+%] выдал премию %((%d+)%) всем членам организации')
		if leader and sum then
			leader = leader:gsub('_', ' ')
			sum = sumFormat(sum)
			if rank_prem ~= nil then
				msg = string.format('Руководитель %s выдал премию в размере %s$ сотрудникам на должности %s', leader, sum, rank_prem)
				rank_prem = nil
			else
				msg = string.format('Руководитель %s выдал премию в размере %s$ сотрудникам на определённой должности', leader, sum)
			end
			return { clr, msg }
		end
	end
end

function se.onShowDialog(dialogId, style, title, button1, button2, text) -- хук диалогов
	local isAnyAwaitExist = false
	for k, v in pairs(await) do
		if os.clock() - v > 60.0 then
			await[k] = nil
		else
			isAnyAwaitExist = true
		end
	end

	local send = function( ... )
		local args = { ... }
		local onChat = (#args == 1 and type(args[1]) == 'string')
		math.randomseed(os.clock())
		local cooldown = 200 + math.random(-100, 100)
		lua_thread.create(function(); wait(cooldown)
			if onChat then
				sampSendChat(args[1])
			else
				sampSendDialogResponse(dialogId, args[1], args[2], args[3])
			end
		end)
		return cooldown
	end

	if string.find(title, "Паспорт", 1, true) and await["passport"] then
		local nick = (actionId == nil) and "гражданина" or rpNick(actionId)
		lua_thread.create(function(); wait(300)
			sampSendChat("/me {sex:взял|взяла} паспорт у " .. nick)
			wait(MsgDelay.v * 1000)
			sampSendChat("/todo Спасибо, одну секундочку..*рассматривая документ")
		end)
		await["passport"] = nil
	end

	if string.find(title, "Мед. карта", 1, true) and await["medcard"] then
		local nick = (actionId == nil) and "гражданина" or rpNick(actionId)
		lua_thread.create(function(); wait(300)
			sampSendChat("/me {sex:взял|взяла} медицинскую карточку у " .. nick)
			wait(MsgDelay.v * 1000)
			sampSendChat("/todo Так-с, посмотрим..*изучая историю болезней")
		end)
		await["medcard"] = nil
	end

	if string.find(title, "Лицензии", 1, true) and await["licenses"] then
		local nick = (actionId == nil) and "гражданина" or rpNick(actionId)
		lua_thread.create(function(); wait(300)
			sampSendChat("/me {sex:взял|взяла} перечень лизецнзий у " .. nick)
			wait(MsgDelay.v * 1000)
			sampSendChat("/me смотрит даты истечения лицензий..")
		end)
		await["licenses"] = nil
	end

	if await["uniform"] and text:find("Переодеться") then
		sync(table.unpack(unform_pickup_pos))
		sampSendDialogResponse(dialogId, 1, 0, nil)
		return false
	end

	-- /bankmenu
	if dialogId == 713 and isAnyAwaitExist then
		if await['credit_send'] then 		send(1, 0); await['credit_send'] = os.clock()
		elseif await['debt'] then 			send(1, 1); await['debt'] = nil
		elseif await['get_money'] then 		send(1, 2); await['get_money'] = nil
		elseif await['card_create'] then 	send(1, 3); await['card_create'] = nil
		elseif await['card_recreate'] then 	send(1, 4); await['card_recreate'] = nil
		elseif await['dep_plus'] then 		send(1, 5); await['dep_plus'] = nil
		elseif await['dep_minus'] then 		send(1, 6); await['dep_minus'] = nil
		elseif await['dep_plus_10'] then 	send(1, 7); await['dep_plus_10'] = nil
		elseif await['dep_check'] then 		send(1, 8); await['dep_check'] = nil
		elseif await['vip_create'] then 	send(1, 9); await['vip_create'] = nil
		elseif await['addcard'] then 		send(1, 10); await['addcard'] = nil
		end
		return false
	end

	-- Information dialogs
	if dialogId == 0 then

		local kd = text:match('через {%x}(%d+){%x} час.+')
		if kd then
			kd = tonumber(kd)
			if await['dep_minus'] and schet_dep[kd] ~= nil then
				send(string.format('Извините, но снять с депозита вы сможете только через %s %s', kd, plural(kd, {'час', 'часа', 'часов'})))
			elseif await['dep_check'] then
				send(string.format('Вывести деньги с депозита вы сможете через %s', kd, plural(kd, {'час', 'часа', 'часов'})))
			end
		end

		if text:find('Вы успешно отправили предложение на смену пароля') then
			kassa.info.recard = kassa.info.recard + 1
		end

		if text:find('Вы успешно дали {73B461}игроку{FFFFFF} бланк, для пополнения депозита') then
			kassa.info.dep = kassa.info.dep + 1
		end

		if text:find('Вы успешно дали игроку {73B461}бланк{FFFFFF}, для получения своего депозита') then
			kassa.info.dep = kassa.info.dep + 1
		end

		if text:find('форму открытия дополнительного личного счёта') then
			kassa.info.addcard = kassa.info.addcard + 1
		end

		if text:find('форму оформления банковской карты') then
			if text:find('VIP-клиента', 1, true) then
				kassa.info.vip = kassa.info.vip + 1
			else
				kassa.info.card = kassa.info.card + 1
			end
		end
	end

	if string.find(title, "Информация") and string.find(text, "Баланс Фракций") then
		local info = { fractions = {}, price = 0, farm = 0, buy_ls = 0, buy_lv = 0 }

		for line in string.gmatch(text, "[^\n]+") do
			local org, balance = string.match(line, "^%- (.+): {%x+}(%d+){%x+}")
			if org and balance then
				table.insert(info.fractions, { org, tonumber(balance) or 0 })
			end

			local price = string.match(line, "Цена выкупа: {%x+}(%d+)")
			if price then info.price = tonumber(price) end

			local farm = string.match(line, "Закупка продуктов на ферме: {%x+}(%d+)")
			if farm then info.farm = tonumber(farm) end

			local buy_ls = string.match(line, "Продажа продуктов в Los Santos: {%x+}(%d+)")
			if buy_ls then info.buy_ls = tonumber(buy_ls) end

			local buy_lv = string.match(line, "Продажа продуктов в Las Venturas: {%x+}(%d+)")
			if buy_lv then info.buy_lv = tonumber(buy_lv) end
		end

		table.sort(info.fractions, function(a, b) 
			return a[2] > b[2] 
		end)

		local result = "{AAAAAA}"
		result = result .. "Каждой организации необходимо иметь деньги на счету банка чтобы выплачивать\n"
		result = result .. "премии своим работникам, а также закупать патроны и продукты у других предприятий и фракций.\n"

		result = result .. "\n"
		result = result .. "{FFFFFF}Балансы всех гос-организаций по убыванию:\n\n"

		for _, org in ipairs(info.fractions) do
			result = result .. string.format("{FFFFFF} - %s: {73B461}$%s\n", org[1], sumFormat(org[2]))
		end

		result = result .. "\n"
		result = result .. "{FFFFFF}Получатель налогов: {73B461}Центральный Банк\n"

		result = result .. "\n"
		result = result .. ("{FFFFFF}Цена выкупа: {73B461}%s\n"):format(sumFormat(info.price))

		result = result .. "\n"
		result = result .. ("{FFFFFF}Закупка продуктов на ферме: {73B461}%s\n"):format(sumFormat(info.farm))
		result = result .. ("{FFFFFF}Продажа продуктов в Los Santos: {73B461}%s\n"):format(sumFormat(info.buy_ls))
		result = result .. ("{FFFFFF}Продажа продуктов в Las Venturas: {73B461}%s"):format(sumFormat(info.buy_lv))

		return { dialogId, style, title, button1, button2, result }
	end
	
	-- Credit sum
	if dialogId == 227 and await['credit_send'] then
		send(1, nil, credit_sum.v)
		return false
	end

	-- Credit accept
	if dialogId == 228 and await['credit_send'] then
		kassa.info.credit = kassa.info.credit + 1
		await['credit_send'] = nil
	end
	
	-- Report
	if dialogId == 32 and await['report'] then
		addNotify("{006D86}Репорт отправлен!\nОжидайте ответа", 5)
		send(0); await['report'] = nil 
		return false
	end

	if dialogId == 235 and await['get_rank'] then
		if not text:find('Центральный Банк') and not devmode then
			lua_thread.create(function()
				wait(2000)
				addBankMessage('Вы не в организации {M}«Центральный Банк»')
				addBankMessage('Скрипт работает только в этой организации')
				addBankMessage('Если вы считаете, что это ошибка - напишите разработчику {M}vk.com/cosui')
				addBankMessage('Скрипт отключен..')
				log('Скрипт отключен. Вы не в организации "Центральный Банк"')
				unload(false)
			end)
			return false
		end

		local stat_info = string.match(text, 'Должность: {%x+}([^\n]+)')
		if stat_info ~= nil then
			local name, rank = string.match(stat_info, '^(.+)%(([0-9]+)%)$')
			rank = tonumber(rank)

			if name and rank then
				if rank ~= cfg.main.rank then
					cfg.main.rank = rank
				elseif await['rank_update'] then
					addBankMessage('Ваш ранг соответствует рангу в /stats')
				end
				await['rank_update'] = nil
			end
		end

		send(0); await['get_rank'] = nil
		return false
	end

	if dialogId == 2015 then 
		for line in text:gmatch('[^\r\n]+') do
			local name, rank = line:match('^{%x+}[A-z0-9_]+%([0-9]+%)\t(.+)%(([0-9]+)%)\t%d+\t%d+')
			if name and rank then
				name, rank = tostring(name), tonumber(rank)
				if cfg.nameRank[rank] ~= nil and cfg.nameRank[rank] ~= name then
					addBankMessage(string.format('Обновлено название ранга: {M}%s{W} -> {M}%s{W} | {S}%s ранг', cfg.nameRank[rank], name, rank))
					cfg.nameRank[rank] = name
				end
			end
		end
		send(0)
	end

	if string.find(title, "Успеваемость") then
		if await['uprankdate'] then
			local d, m, Y, H, M, S = string.match(text, "Последнее повышение:\n {%x+}(%d+)%.(%d+)%.(%d+) (%d+):(%d+):(%d+)")
			if d ~= nil then
				local datetime = { year = Y, month = m, day = d, hour = H, min = M, sec = S}
				addBankMessage(string.format('Дата последнего повышения по /jobprogress: {M}%s', os.date('%d.%m.%Y', os.time(datetime))))
				cfg.main.dateuprank = os.time(datetime)
			else
				addBankMessage('Не удалось проверить дату повышения по /jobprogress!')
			end

			await['uprankdate'] = nil
			send(0)
			return false
		elseif not mMenu.status and mMenu.timer and os.clock() - mMenu.timer < 5.00 then
			local time = string.match(text, "Времени на постах: {FFB323}(%d+)")
			if time then mMenu.time.all = tonumber(time) end
			local time = string.match(text, "Времени на постах: {F9FF23}(%d+)")
			if time then mMenu.time.today = tonumber(time) end

			local cards = string.match(text, "Выдано банковских карт: {FFB323}(%d+)")
			if cards then mMenu.cards.all = tonumber(cards) end
			local cards = string.match(text, "Выдано банковских карт: {F9FF23}(%d+)")
			if cards then mMenu.cards.today = tonumber(cards) end

			local dep = string.match(text, "Операции с депозитом: {FFB323}(%d+)")
			if dep then mMenu.dep.all = tonumber(dep) end
			local dep = string.match(text, "Операции с депозитом: {F9FF23}(%d+)")
			if dep then mMenu.dep.today = tonumber(dep) end
			
			local d, m, Y, H, M, S = string.match(text, "Последнее повышение:\n {%x+}(%d+)%.(%d+)%.(%d+) (%d+):(%d+):(%d+)")
			if d ~= nil then
				mMenu.last_up = os.time({ year = Y, month = m, day = d, hour = H, min = M, sec = S})
			end

			send(0)
			mMenu.status = true
			return false
		end
	end

	if #pincode.v > 0 then
		if string.find(text, "Вы должны подтвердить свой PIN-код к карточке", 1, true) then
			sampSendDialogResponse(dialogId, 1, nil, pincode.v)
			return false
		end

		if string.find(text, "PIN-код принят!", 1, true) then
			text = "{FFFFFF}PIN-код введен {33AA33}автоматически!"
			return { dialogId, style, title, button1, button2, text }
		end

		if string.find(text, "Вы не правильно ввели PIN-код!", 1, true) then
			text = "{FFFFFF}PIN-код для автоматического ввода {AA3333}неверный!\n{FFFFFF}Вам нужно ввести его вручную"
			button1 = "Понятно"

			cfg.main.pincode = ""
			pincode.v = cfg.main.pincode

			return { dialogId, style, title, button1, button2, text }
		end
	end

	if await["quest"] and string.find(text, "Вы действительно хотите принять квест?") then
		await["quest"] = nil; send(1)
		return false
	end

	QUESTS_DIALOG = nil
	if string.find(title, "Квесты") and string.find(text, "Выдаем депозит") then
		QUESTS_DIALOG = dialogId

		local tags = {
			["Доступен"] = {"Доступен", "{00FF00}", "{AAFFAA}"},
			["В процессе"] = {"Выполняется", "{FFDD00}", "{FFDDAA}"},
			["Можно завершить"] = {"Выполнен", "{30AAFF}", "{AADDFF}"},
			["Выполнен"] = {"Завершён", "{666666}", "{AAAAAA}"}
		}

		local quests = {
			["Выдаем депозит"] = "Пополнить депозит 10 клиентам",
			["Снимаем деньги"] = "Вывести депозит 10 клиентам",
			["Регестрируем счета"] = "Создать 3 банковских карты",
			["Восстанавливаем счета"] = "Восстановить 3 карты",
			["Нелегкая работа"] = "Отстоять 20 минут на посту",
		}

		local new_text = ""
		for line in string.gmatch(text, "[^\n]+") do
			local new_line = ("%s\n"):format(line)
			for old_name, new_name in pairs(quests) do
				if string.find(line, old_name, 1, true) then
					local status = string.match(line, "%[([^%]]+)%]{%x+}$")
					if status ~= nil and tags[status] ~= nil then
						new_line = string.format("%s[%s]%s %s\n", tags[status][2], tags[status][1], tags[status][3], new_name)
					end
					break
				end
			end
			new_text = new_text .. new_line
		end
		return { dialogId, style, title, button1, button2, new_text }
	end
end

function se.onSendDialogResponse(dialogId, but, list, input)
	if QUESTS_DIALOG == dialogId and but == 1 then
		await["quest"] = os.clock()
		return { dialogId, but, list, input }
	end
end

function separator(text)
	local format = text:gsub('{%x+}', '')
	for d in format:gmatch("%d+") do
		local result, out = pcall(sumFormat, d)
		text = text:gsub(d, result and out or d)
	end
	return text
end

function imgui.BeforeDrawFrame()
	if font == nil then
		imgui.SwitchContext()
	    imgui.GetIO().Fonts:Clear()

		local config = imgui.ImFontConfig()
	    config.MergeMode, config.PixelSnapH = true, true
	    local range = {
	    	icon = imgui.ImGlyphRanges({ 0xf000, 0xf83e }),
	    	font = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
	    }
	    font = {}
	    
	    for i, size in ipairs({ 13, 11, 15, 20, 35, 45, 60 }) do
	    	font[size] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(sf_bold, size, nil, range.font)
	    	imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa_base, size, config, range.icon)
		end
	end
end

function imgui.OnDrawFrame()
	local ex, ey = getScreenResolution()
	if int_bank.alpha > 0.00 then
		local _, selfid = sampGetPlayerIdByCharHandle(PLAYER_PED)
		imgui.SetNextWindowSize(imgui.ImVec2(465, 295), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(ex / 2, ey - 305), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0))
		imgui.PushStyleVar(imgui.StyleVar.Alpha, int_bank.alpha)
		imgui.Begin(u8'##IntMenuBank', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar)
			imgui.BeginChild("##ActionIdInfo", imgui.ImVec2(150, 180), true, imgui.WindowFlags.NoScrollbar)
			imgui.SetCursorPosY(18)

			imgui.CenterTextColoredRGB(mc..'Ник игрока')
			if sampIsPlayerConnected(actionId) then
				imgui.CenterTextColoredRGB(rpNick(actionId)..'['..actionId..']')
				if imgui.IsItemClicked() then
					if setClipboardText(u8:decode((sampGetPlayerNickname(actionId)))) then
						addBankMessage(string.format('Ник {M}%s{W} скопирован в буфер обмена!', rpNick(actionId)))
					end
				else imgui.Hint('copytargetnick', u8'Нажми, что-бы скопировать') end
				if TypeAction.v == 2 then
					if isPlayerOnBlacklist(sampGetPlayerNickname(actionId)) then
						imgui.CenterTextColoredRGB('{FF0000}Чёрный список!')
					else
						imgui.NewLine()
					end
				else
					imgui.NewLine()
				end
				imgui.CenterTextColoredRGB(mc..'Игровой уровень')
				local yearold = sampGetPlayerScore(actionId)
				if TypeAction.v == 2 and yearold < 3 then 
					imgui.CenterTextColoredRGB('{FF0000}' .. yearold .. ' уровень')
				else
					imgui.CenterTextColoredRGB(yearold .. ' уровень')
				end
			else
				int_bank:switch()
				addBankMessage('Игрок вышел из игры!')
			end
			imgui.NewLine()
			imgui.CenterTextColoredRGB(mc..'Как одет')

			local bPed, handle = sampGetCharHandleBySampPlayerId(actionId)
			if bPed then
				local bas_skin = isSkinBad(getCharModel(handle))
				imgui.CenterTextColoredRGB(bas_skin and 'Не прилично' or 'Прилично')
			else
				imgui.CenterTextColoredRGB('Неизвестно')
			end

			imgui.EndChild()
			imgui.SameLine()
			if TypeAction.v == 2 or TypeAction.v == 3 then
				imgui.BeginChild("##Actions", imgui.ImVec2(-1, 275), true, imgui.WindowFlags.NoScrollbar)
			end
				if TypeAction.v == 1 then
					if not go_credit then
						imgui.SetCursorPos(imgui.ImVec2(165, 10))
						if imgui.Button(u8('Приветствие ')..fa.ICON_FA_CHILD, imgui.ImVec2(250, 30)) then
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "{hello}, я %s - {my_name}", cfg.nameRank[cfg.main.rank] },
								{ "/todo Чем могу Вам помочь?*поправляя свой бейджик" }
							})
						end

						imgui.SameLine(nil, 5)
						if cfg.main.rank >= 5 then
							if imgui.Button(fa.ICON_FA_GAVEL, imgui.ImVec2(-1, 30)) then
								imgui.OpenPopup("##edit_expel")
							end
							imgui.Hint('expelbut', u8'Выгнать из банка')
						else
							imgui.DisableButton(fa.ICON_FA_LOCK, imgui.ImVec2(-1, 30))
							imgui.Hint('expel2rank', u8'Доступно со 5 ранга')
						end

						if imgui.BeginPopupContextWindow("##edit_expel", 1, false) then
							imgui.PushItemWidth(100)
							imgui.Text(u8'Выгнать игрока с причиной:')
							if imgui.InputText(u8'##ExpelReason', expelReason) then
								cfg.main.expelReason = u8:decode(expelReason.v)
							end
							imgui.PopItemWidth()
							imgui.SameLine()
							if imgui.MainButton(u8'Выгнать') then
								int_bank:switch()
								go_expel(tonumber(actionId))
							end
							if imgui.IsItemClicked(1) then
								int_bank:switch()
								go_expel(tonumber(actionId), true)
							end
							imgui.EndPopup()
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 45))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Снять депозит ')..fa.ICON_FA_MINUS_CIRCLE, imgui.ImVec2(250, 30)) then
								int_bank:switch()
								await['dep_minus'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Депозиты»" },
									{ "/me {sex:выбрал|выбрала} пункт «Снять» и {sex:нажал|нажала} «Распечатать»" },
									{ "/me {sex:взял|взяла} распечатанный бланк и {sex:передал|передала} его %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['dep_minus'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Снять депозит ')..fa.ICON_FA_LOCK, imgui.ImVec2(250, 30))
							imgui.Hint('depositdown5rank', u8'Доступно с 3 ранга')
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 80))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Пополнить депозит ')..fa.ICON_FA_PLUS_CIRCLE, imgui.ImVec2(cfg.main.rank > 3 and 250 or -1, 30)) then
								int_bank:switch()
								await[cfg.main.rank >= 4 and 'dep_plus_10' or 'dep_plus'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Депозиты»" },
									{ "/me {sex:выбрал|выбрала} пункт «Пополнить» и {sex:нажал|нажала} «Распечатать»" },
									{ "/me {sex:взял|взяла} распечатанный бланк и {sex:передал|передала} его %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await[cfg.main.rank >= 4 and 'dep_plus_10' or 'dep_plus'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Пополнить депозит ')..fa.ICON_FA_LOCK, imgui.ImVec2(-1, 30))
							imgui.Hint('depositeup3rank', u8'Доступно с 3 ранга')
						end

						if cfg.main.rank >= 4 then
							imgui.SameLine(nil, 5)

							if imgui.Button(fa.ICON_FA_LEVEL_DOWN_ALT, imgui.ImVec2(-1, 30)) then
								int_bank:switch()
								await['dep_plus'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Депозиты»" },
									{ "/me {sex:выбрал|выбрала} пункт «Пополнить» и {sex:нажал|нажала} «Распечатать»" },
									{ "/me {sex:взял|взяла} распечатанный бланк и {sex:передал|передала} его %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							imgui.Hint('depositold', u8'Выдать форму пополнения депозита\nдо 5 миллионов (без комиссии)')
							if imgui.IsItemClicked(1) then
								await['dep_plus'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 115))
						if cfg.main.rank >= 6 then
							if imgui.Button(u8('Оформить кредит ')..fa.ICON_FA_CALCULATOR, imgui.ImVec2(-1, 30)) then
								go_credit = true
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Кредитование»" },
									{ "/me {sex:выбрал|выбрала} пункт «Оформление кредита» и {sex:нажал|нажала} «Распечатать»" },
									{ "/me {sex:взял|взяла} распечатанный бланк и {sex:начал|начала} заполнять его" },
									{ "Можно ваш паспорт, пожалуйста?" }
								})
							end
							if imgui.IsItemClicked(1) then
								go_credit = true
							end
						else
							imgui.DisableButton(u8('Оформить кредит ')..fa.ICON_FA_LOCK, imgui.ImVec2(-1, 30))
							imgui.Hint('credit6rank', u8'Доступно с 6 ранга')
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 150))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Задолженности ')..fa.ICON_FA_MONEY_CHECK, imgui.ImVec2(291 / 2 - 2.5, 30)) then
								int_bank:switch()
								await['debt'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете базу данных" },
									{ "/me глядя на %s что-то смотрит в базе", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['debt'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Задолженности ')..fa.ICON_FA_LOCK, imgui.ImVec2(291 / 2 - 2.5, 30))
							imgui.Hint('debt3rank', u8'Доступно с 3 ранга')
						end

						imgui.SameLine(nil, 5)

						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Выписка по счёту ')..fa.ICON_FA_PIGGY_BANK, imgui.ImVec2(291 / 2 - 2.5, 30)) then
								int_bank:switch()
								await['get_money'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете базу данных" },
									{ "/me глядя на %s что-то смотрит в базе", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['get_money'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Выписка по счёту ')..fa.ICON_FA_LOCK, imgui.ImVec2(291 / 2 - 2.5, 30))
							imgui.Hint('howmuchmoney3rank', u8'Доступно с 3 ранга')
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 185))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Оформить карту ')..fa.ICON_FA_CREDIT_CARD, imgui.ImVec2(291 / 2 - 2.5, 30)) then
								int_bank:switch()
								await['card_create'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Банковские Карты»" },
									{ "/me {sex:выбрал|выбрала} пункт «Оформление счёта» и {sex:нажал|нажала} «Оформить»" },
									{ "/me {sex:распечатал|распечатала} чистый бланк и {sex:достал|достала} новую карту" },
									{ "/todo Заполните этот бланк и карта ваша!*передавая его %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['card_create'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Оформить карту ')..fa.ICON_FA_LOCK, imgui.ImVec2(291 / 2 - 2.5, 30))
							imgui.Hint('givecard3rank', u8'Доступно с 3 ранга')
						end

						imgui.SameLine(nil, 5)

						if cfg.main.rank >= 3 then
							if imgui.Button(u8('VIP-Карта ')..fa.ICON_FA_TICKET_ALT, imgui.ImVec2(291 / 2 - 2.5, 30)) then
								int_bank:switch()
								await['vip_create'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Банковские Карты»" },
									{ "/me {sex:выбрал|выбрала} пункт «VIP-Клиенты» и {sex:нажал|нажала} «Добавить»" },
									{ "/me {sex:внёс|внесла} клиента в базу и {sex:достал|достала} из пачки новую карту" },
									{ "/me {sex:добавил|добавила} уникальный номер с карты в базу данных" },
									{ "/todo Вот ваша VIP-карта!*передавая её %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['vip_create'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('VIP-Карта ')..fa.ICON_FA_LOCK, imgui.ImVec2(291 / 2 - 2.5, 30))
							imgui.Hint('givevip3rank', u8'Доступно с 3 ранга')
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 220))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Дополнительный счёт ')..fa.ICON_FA_PLUS_CIRCLE, imgui.ImVec2(-1, 30)) then
								int_bank:switch()
								await['addcard'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Банковские счета»" },
									{ "/me {sex:нашёл|нашла} клиента в базе данных и {sex:нажал|нажала} «Дополнительный счёт»" },
									{ "/me {sex:внёс|внесла} какие-то данные и {sex:распечатал|распечатала} новый бланк" },
									{ "/todo Заполните данные в этом бланке, чтобы я {sex:смог|смогла} активировать вам этот счёт!*передавая его %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								await['addcard'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(u8('Дополнительный счёт ')..fa.ICON_FA_LOCK, imgui.ImVec2(-1, 30))
							imgui.Hint('addcard3rank', u8'Доступно с 3 ранга')
						end

						imgui.SetCursorPos(imgui.ImVec2(165, 255))
						if cfg.main.rank >= 3 then
							if imgui.Button(u8('Восстановить PIN-Код ')..fa.ICON_FA_RECYCLE, imgui.ImVec2(-1, 30)) then
								imgui.OpenPopup(u8("Выбор действия##Card"))
							end
						else
							imgui.DisableButton(u8('Восстановить PIN-Код ')..fa.ICON_FA_LOCK, imgui.ImVec2(-1, 30))
							imgui.Hint('restorecard3rank', u8'Доступно с 3 ранга')
						end
						if imgui.BeginPopupModal(u8("Выбор действия##Card"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
							imgui.CenterTextColoredRGB(mc..'Обратите внимание!\nЭтот игрок возможно взломан, хотите\nспросить об этом в /report?')
							imgui.NewLine()
							if imgui.Button(u8('Сообщить в /report'), imgui.ImVec2(150, 30)) then
								imgui.CloseCurrentPopup()
								await['report'] = os.clock()
								sampSendChat('/report')
								sampSendDialogResponse(32, 1, -1, 'Проверьте '..rpNick(actionId)..'['..actionId..'] на взлом (Банк)')
							end
							imgui.SameLine()
							if imgui.Button(u8('Восстановить'), imgui.ImVec2(150, 30)) then
								imgui.CloseCurrentPopup()
								int_bank:switch()
								await['card_recreate'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете раздел «Банковские Карты» и {sex:выбрал|выбрала} пункт «Восстановить»"  },
									{ "/me {sex:прислонил|прислонила} банковскую карту к терминалу и {sex:сбросил|сбросила} PIN-Код" },
									{ "/me {sex:достал|достала} чистый бланк и {sex:заполнил|заполнила} новые данные о карте" },
									{ "/todo Оплатите пошлину и можете снова пользоваться счётом*передавая бланк %s", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								imgui.CloseCurrentPopup()
								await['card_recreate'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
							if imgui.MainButton(u8('Отменить##GoMenu'), imgui.ImVec2(-1, 30)) then
								imgui.CloseCurrentPopup()
							end
							imgui.EndPopup()
						end
						imgui.SetCursorPos(imgui.ImVec2(420, 45))
						if cfg.main.rank >= 3 then
							if imgui.Button(fa.ICON_FA_CLOCK, imgui.ImVec2(35, 30)) then
								int_bank:switch()
								await['dep_check'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:открыл|открыла} на планшете базу данных" },
									{ "/me глядя на %s что-то смотрит в базе", rpNick(actionId) },
									{ "/bankmenu %s", actionId }
								})
							end
							imgui.Hint('getdeptime', u8'Узнать, через сколько можно\nснять с депозита')
							if imgui.IsItemClicked(1) then
								await['dep_check'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end
						else
							imgui.DisableButton(fa.ICON_FA_LOCK, imgui.ImVec2(35, 30))
							imgui.Hint('depositecheck3rank', u8'Доступно с 3 ранга')
						end
					else
						imgui.BeginChild("##CreditWindow", imgui.ImVec2(-1, 275), true, imgui.WindowFlags.NoScrollbar)
							imgui.CenterTextColoredRGB(mc..'Оформление кредита на\n'..mc..'жителя '..sc..rpNick(actionId))
							imgui.NewLine()
							imgui.PushItemWidth(170)
							if imgui.InputInt(u8'Сумма кредита', credit_sum, 0, 0) then
								if credit_sum.v < 5000 then credit_sum.v = 5000 end
								if credit_sum.v > 300000 then credit_sum.v = 300000 end
							end
							imgui.PopItemWidth()
							imgui.NewLine()
							imgui.CenterTextColoredRGB(mc..'Оформление кредита производится\n'..mc..'по установленной системе кредитования\n'..sc..'Ознакомиться с ней вы можете тут:')
							imgui.SetCursorPosX((imgui.GetWindowWidth() - 150) / 2)
							if imgui.Button(u8('Система кредитования##credit'), imgui.ImVec2(150, 20)) then
								imgui.OpenPopup(u8("Система кредитования"))
							end
							system_credit()
							imgui.NewLine()
							if imgui.MainButton(u8('Выдать кредит на '..credit_sum.v..'$'), imgui.ImVec2(-1, 30)) then
								go_credit = false
								int_bank:switch()
								await['credit_send'] = os.clock()
								play_message(MsgDelay.v, false, {
									{ "/me {sex:закончил|закончила} заполнять бланк" },
									{ "/me ставит нужные печати на заполненном бланке" },
									{ "/me передаёт готовый бланк %s", rpNick(actionId) },
									{ "Поставьте подписи в нужных местах и кредит суммой %s$ будет оформлен!", credit_sum.v },
									{ "/bankmenu %s", actionId }
								})
							end
							if imgui.IsItemClicked(1) then
								go_credit = false
								await['credit_send'] = os.clock()
								sampSendChat(("/bankmenu %s"):format(actionId))
								int_bank:switch()
							end

							if imgui.Button(u8('Отменить операцию'), imgui.ImVec2(-1, 30)) then
								go_credit = false
								sampSendChat("/me {sex:выкинул|выкинула} бланк в мусорное ведро")
							end
						imgui.EndChild()
					end
				end
				if TypeAction.v == 2 then
					imgui.CenterTextColoredRGB(mc..'Обязательные критерии:')
					imgui.CenterTextColoredRGB('От 3 лет в штате ( 3+ уровень )')
					imgui.CenterTextColoredRGB('От 35 ед. законопослушности')
					imgui.CenterTextColoredRGB('Отсутствие нахождений в деморгане')
					imgui.CenterTextColoredRGB('Отсутствие наркозависимости')
					imgui.CenterTextColoredRGB('Наличие прививки от коронавируса')
					imgui.NewLine()

					local spacing = imgui.GetStyle().ItemSpacing.y
					imgui.SetCursorPosY(135)
					if imgui.Button(u8('Приветствие'), imgui.ImVec2(-1, 30)) then
						play_message(MsgDelay.v, false, {
							{ "{hello}, я %s - {my_name}", cfg.nameRank[cfg.main.rank] },
							{ "Вы на собеседование?" }
						})
					end
					local len = imgui.GetItemRectSize().x

					do
						local norm_len = len - (spacing * 2)
						if imgui.Button(u8('Паспорт'), imgui.ImVec2(norm_len / 3, 30)) then
							await["passport"] = os.clock()
							play_message(MsgDelay.v, false, {
								{ "Будьте добры, покажите ваш паспорт" },
								{ "/b /showpass %s + 1-2 отыгровки", selfid }
							})
						end
						imgui.SameLine(nil, spacing)
						if imgui.Button(u8('Мед. карта'), imgui.ImVec2(norm_len / 3, 30)) then
							await["medcard"] = os.clock()
							play_message(MsgDelay.v, false, {
								{ "Паспорт в порядке, теперь можно вашу мед-карту?" },
								{ "/b /showmc %s + 1-2 отыгровки", selfid }
							})
						end
						imgui.SameLine(nil, spacing)
						if imgui.Button(u8('Лицензии'), imgui.ImVec2(norm_len / 3, 30)) then
							await["licenses"] = os.clock()
							play_message(MsgDelay.v, false, {
								{ "Отлично, осталось увидеть ваши лицензии. Передайте мне их" },
								{ "/b /showlic %s + 1-2 отыгровки", selfid }
							})
						end
					end

					do
						local norm_len = len - (spacing * 2)

						if imgui.Button(u8('Вопрос 1'), imgui.ImVec2(norm_len / 3, 30)) then
							play_message(MsgDelay.v, false, {
								{ "Будете ли выполнять свои должностные обязанности на работе?" }
							})
						end

						imgui.SameLine(nil, spacing)

						if imgui.Button(u8('Вопрос 2'), imgui.ImVec2(norm_len / 3, 30)) then
							play_message(MsgDelay.v, false, {
								{ "Как долго планируете работать в нашей организации?" }
							})
						end

						imgui.SameLine(nil, spacing)

						if imgui.Button(u8('Вопрос 3'), imgui.ImVec2(norm_len / 3, 30)) then
							play_message(MsgDelay.v, false, {
								{ "До какой должности планируете дойти у нас?" }
							})
						end
					end

					do
						local norm_len = len - (spacing * 1)

						imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.40, 0.00, 1.00))
						imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.30, 0.00, 1.00))
						if imgui.Button(u8('Принять ')..fa.ICON_FA_USER_PLUS, imgui.ImVec2(norm_len / 2, 30)) then
							if not isPlayerOnBlacklist(sampGetPlayerNickname(actionId)) then 
								int_bank:switch()
								if cfg.main.rank >= 9 then
									play_message(MsgDelay.v, true, {
										{ "Поздравляю! Вы нам подходите!" },
										{ "/me {sex:передал|передала} новый бейджик для %s", rpNick(actionId) },
										{ "/invite %s", actionId },
										{ "Можете переодеваться и начинать работать!" }
									})
								else
									local result, kassa = getNumberOfKassa()
									play_message(MsgDelay.v, true, {
										{ "Поздравляю! Вы нам подходите!" },
										{ "Сейчас я позову директора, что бы он вас принял! Одну секундочку.." },
										{ 	(result 
											and 
											"/r Прошу подойти на кассу №%s, нужно принять человека прошедшего собеседование" 
											or
											"/r Прошу подойти ко мне, что-бы принять человека прошедшего собеседование"), kassa 
										}
									})
								end
							else
								addBankMessage('Вы не можете принять этого игрока во фракцию!')
								addBankMessage(string.format('Игрок {M}%s{W} находится в {FF0000}чёрном списке{W}!', rpNick(actionId)))
							end
						end
						if imgui.IsItemClicked(1) and cfg.main.rank >= 9 then
							if not isPlayerOnBlacklist(sampGetPlayerNickname(actionId)) then
								sampSendChat(("/invite %s"):format(actionId))
								int_bank:switch()
							else
								addBankMessage('Вы не можете принять этого игрока во фракцию!')
								addBankMessage(string.format('Игрок {M}%s{W} находится в {FF0000}чёрном списке{W}!', rpNick(actionId)))
							end
						end
						imgui.PopStyleColor(2)

						imgui.SameLine(nil, spacing)

						imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.40, 0.00, 0.00, 1.00))
						imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.00, 0.00, 1.00))
						if imgui.Button(u8('Отклонить ')..fa.ICON_FA_USER_TIMES, imgui.ImVec2(norm_len / 2, 30), { 0.3, 0.1 }) then
							imgui.OpenPopup(u8("Причина отклонения"))
						end
						imgui.PopStyleColor(2)
					end

					if imgui.BeginPopupModal(u8("Причина отклонения"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
						imgui.CenterTextColoredRGB(mc..'Укажите причину отклонения')
						if imgui.Button(u8('Опечатка в паспорте (НонРП ник)'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, у вас опечатка в паспорте" },
								{ "/b НонРП НикНейм" },
								{ "Исправьте это недоразумение и приходите ещё!" }
							})
						end
						if imgui.Button(u8('Мало лет в штате'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы проживаете мало лет в штате" },
								{ "/b Нужен 3+ уровень персонажа" },
								{ "Приходите в другой раз!" }
							})
						end
						if imgui.Button(u8('Трудоустроен'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы уже трудоустроены" },
								{ "Увольтесь и приходите ещё раз!" }
							})
						end
						if imgui.Button(u8('Малая законопослушность'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы не законопослушны" },
								{ "/b 35+ законопослушности - /showpass %s", actionId },
								{ "Приходите в другой раз!" }
							})
						end
						if imgui.Button(u8('Наркозависимость'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы наркозависим" },
								{ "/b Максимум 3 наркозависимости - /showmc %s", actionId },
								{ "Вылечитесь и приходите ещё раз!" }
							})
						end
						if imgui.Button(u8('Нет прививки от коронавируса'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите. Вы не вакцинированы" },
								{ "/b Нужно сделать прививку от коронавируса в больнице - /showmc %s", actionId },
								{ "Приходите в другой раз!" }
							})
						end
						if imgui.Button(u8('Присутствие деморганов'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы психически не здоров" },
								{ "/b Наличие деморганов, обновите мед. карту - /showpass %s", actionId },
								{ "Явитесь на мед. осмотр и приходите ещё раз!" }
							})
						end
						if imgui.Button(u8('Бредит'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
							play_message(MsgDelay.v, false, {
								{ "К сожалению, вы не подходите, вы бредите" },
								{ "/b ООС информация / Бред в RP чат" },
								{ "Выспитесь и приходите ещё раз!" }
							})
						end
						if imgui.Button(u8('Скажу причину вручную'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
							int_bank:switch()
						end
						if imgui.MainButton(u8('Назад'), imgui.ImVec2(250, 30)) then
							imgui.CloseCurrentPopup()
						end
						imgui.EndPopup()
					end
				end
				if TypeAction.v == 3 then
					local ws = imgui.GetWindowSize()

					if not mMenu.status then	
						if os.clock() - mMenu.timer < 5.00 then
							local radius = 40
							imgui.SetCursorPos(imgui.ImVec2((ws.x / 2) - radius, (ws.y / 2) - radius))
							Spinner(radius, 3, 0xAAFF9020)

							local text = u8("Загрузка")
							local ts = imgui.CalcTextSize(text)
							imgui.SetCursorPos(imgui.ImVec2((ws.x - ts.x) / 2, (ws.y - ts.y) / 2))
							imgui.TextColored(imgui.ImVec4(0.13, 0.56, 1.00, 1.00), text)
						else
							imgui.SetCursorPosY((ws.y / 2) - 70)
							imgui.PushFont(font[45])
							imgui.CenterText(" " .. fa.ICON_FA_USER_TIMES, imgui.ImVec4(0.5, 0.5, 0.5, 0.7))
							imgui.PopFont()
							imgui.CenterTextColoredRGB("{AAAAAA}Не удалось получить информацию..\n{AAAAAA}Убедитесь что это ваш сотрудник!")
							imgui.NewLine()
							imgui.SetCursorPosX((ws.x - 150) / 2)
							if imgui.Button(u8"Повторить попытку", imgui.ImVec2(150, 30)) then
								member_menu(actionId)
							end
						end
					else
						imgui.CenterTextColoredRGB(mc.."Меню управления сотрудником")
						imgui.NewLine()

						imgui.TextColoredRGB( ("Времени на постах: " .. mc .. "%d"):format(mMenu.time.all) )
						imgui.SameLine(180)
						imgui.TextDisabled(u8("(Сегодня: %d)"):format(mMenu.time.today))

						imgui.TextColoredRGB( ("Выдано карточек: " .. mc .. "%d"):format(mMenu.cards.all) )
						imgui.SameLine(180)
						imgui.TextDisabled(u8("(Сегодня: %d)"):format(mMenu.cards.today))

						imgui.TextColoredRGB( ("Операций с депозитом: " .. mc .. "%d"):format(mMenu.dep.all) )
						imgui.SameLine(180)
						imgui.TextDisabled(u8("(Сегодня: %d)"):format(mMenu.dep.today))

						imgui.TextColoredRGB( ("{60FF70}Был повышен %s"):format(mMenu.last_up and stringToLower(getTimeAfter(mMenu.last_up)) or "неизвестно когда") )
						if mMenu.last_up then
							imgui.Hint("rankupdate", u8(os.date("%d.%m.%Y в %H:%M", mMenu.last_up)))
						end
						imgui.NewLine()

						local norm_len = ws.x - (5 * 2) - (imgui.GetStyle().WindowPadding.x * 2)
						if imgui.MainButton(u8"Выдать варн", imgui.ImVec2(norm_len / 3, 20)) then
							sampSetChatInputText(("/fwarn %s "):format(actionId))
							sampSetChatInputEnabled(true)
						end
						imgui.SameLine(nil, 5)
						if imgui.MainButton(u8"Выдать мут", imgui.ImVec2(norm_len / 3, 20)) then
							sampSetChatInputText(("/fmute %s "):format(actionId))
							sampSetChatInputEnabled(true)
						end
						imgui.SameLine(nil, 5)
						if imgui.MainButton(u8"Уволить", imgui.ImVec2(norm_len / 3, 20)) then
							sampSetChatInputText(("/uninvite %s "):format(actionId))
							sampSetChatInputEnabled(true)
						end

						if imgui.MainButton(u8"Посмотреть успеваемость", imgui.ImVec2(-1, 20)) then
							sampSendChat(("/checkjobprogress %s"):format(actionId))
						end

						imgui.SetCursorPosY(195)

						imgui.TextColoredRGB("{AAAAAA}Должность в организации:")
						imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(5, 7))
						imgui.BeginGroup()
							for i = 1, 9 do
								imgui.BeginGroup()
									local pos = imgui.GetCursorPos()
									imgui.RadioButton("##nrank" .. i, giverank, i)
									local pos_orig = imgui.GetCursorPos()
									local is = imgui.GetItemRectSize()

									imgui.SetCursorPos(imgui.ImVec2(pos.x + is.x - 5, pos.y + is.y - 10))
									imgui.TextDisabled(tostring(i))
									imgui.SetCursorPos(pos_orig)
								imgui.EndGroup()
								if i ~= 9 then imgui.SameLine(nil, 12) end
							end
						imgui.EndGroup()

						local rank_name = u8(cfg.nameRank[giverank.v] or "Неизвестно")
						if imgui.MainButton(u8("Повысить до [ %s ]"):format(rank_name), imgui.ImVec2(-1, 25)) then
							int_bank:switch()
							play_message(MsgDelay.v, true, {
								{ "/me {sex:достал|достала} из кармана КПК" },
								{ "/me {sex:включил|включила} КПК и {sex:зашёл|зашла} в раздел «Сотрудники»" },
								{ "/me {sex:выбрал|выбрала} сотрудника %s", rpNick(actionId) },
								{ "/me {sex:изменил|изменила} должность сотруднику на %s", cfg.nameRank[giverank.v] },
								{ "/giverank %s %s", actionId, giverank.v }
							})
						end
						if imgui.IsItemClicked(1) then
							sampSendChat(("/giverank %s %s"):format(actionId, giverank.v))
							int_bank:switch()
						end
						imgui.PopStyleVar()
					end
				end
			if TypeAction.v == 2 or TypeAction.v == 3 then
				imgui.EndChild()
			end

			imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.00, 0.40, 0.60, 0.30))
			imgui.SetCursorPos(imgui.ImVec2(10, 200))
			imgui.RadioButton(u8("Банковские Услуги"), TypeAction, 1)
			imgui.SetCursorPos(imgui.ImVec2(10, 230))
			if cfg.main.rank > 4 then
				imgui.RadioButton(u8("Собеседование"), TypeAction, 2)
			else
				imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.FrameBgActive, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
				imgui.RadioButton(u8("Собеседование ")..fa.ICON_FA_LOCK, false)
				imgui.Hint('sobesmenu5rank', u8'Доступно с 5 ранга')
				imgui.PopStyleColor(4)
			end
			imgui.SetCursorPos(imgui.ImVec2(10, 260))
			if cfg.main.rank >= 9 then
				if imgui.RadioButton(u8("Меню сотрудника"), TypeAction, 3) then
					if mMenu.timer == nil or os.clock() - mMenu.timer >= 10 then
						member_menu(actionId)
					end
				end
			else
				imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.FrameBgActive, imgui.ImVec4(0.5, 0.5, 0.5, 0.2))
				imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
				imgui.RadioButton(u8("Меню сотрудника ") .. fa.ICON_FA_LOCK, false)
				imgui.Hint('uprankmenu9+', u8'Доступно с 9 ранга')
				imgui.PopStyleColor(4)
			end
			imgui.PopStyleColor(1)
		imgui.End()
		imgui.PopStyleVar()
	end

	if bank.alpha > 0.00 then
		local _, selfid = sampGetPlayerIdByCharHandle(PLAYER_PED) 
		imgui.PushStyleVar(imgui.StyleVar.Alpha, bank.alpha)
		imgui.SetNextWindowPos(imgui.ImVec2(ex / 2, ey / 2), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
		imgui.Begin(u8'##MainMenu', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)
		
		imgui.BeginGroup()
			imgui.PushFont(font[35])
			imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.ButtonHovered], fa.ICON_FA_UNIVERSITY.. ' Central Bank')
			local len_title = imgui.CalcTextSize(fa.ICON_FA_UNIVERSITY.. ' Central Bank').x
			imgui.PopFont()

			imgui.PushFont(font[11])
			imgui.SetCursorPos( imgui.ImVec2(len_title + 15, 27) )
			imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), 'v'..thisScript().version .. (devmode and ' (Dev)' or ''))
			imgui.PopFont()

			imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 30, 25))
			if imgui.CloseButton(7) then bank:switch() end

			imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 65, 16))
			imgui.PushFont(font[20])
			imgui.TextDisabled(fa.ICON_FA_QUESTION_CIRCLE)
			imgui.PopFont()
			if imgui.IsItemClicked() then
				imgui.OpenPopup(u8("Все команды скрипта"))
			end
			helpCommands()
		imgui.EndGroup()
		imgui.BeginGroup()
			imgui.BeginGroup()
			imgui.BeginChild("##SelfInfo", imgui.ImVec2(180, 125), true, imgui.WindowFlags.NoScrollbar)
				local str_rank = cfg.nameRank[cfg.main.rank]
				if #str_rank > 15 then
					local word = str_rank:match('[^%s]+$')
					str_rank = str_rank:gsub(word, '\n' .. sc .. word)
					imgui.SetCursorPosY(15)
				else
					imgui.SetCursorPosY(25)
				end
				imgui.PushFont(font[45])
				imgui.CenterText(fa.ICON_FA_USER_CIRCLE, imgui.GetStyle().Colors[imgui.Col.ButtonHovered])
				imgui.PopFont()
				imgui.PushFont(font[15])
				imgui.CenterTextColoredRGB(sc .. str_rank .. ' (' .. cfg.main.rank .. ')')
				imgui.PopFont()
				if imgui.IsItemClicked() then
					await['get_rank'] = os.clock()
					await['rank_update'] = os.clock()
					sampSendChat('/stats')
				else
					imgui.Hint('updaterank', u8'Нажмите, что-бы обновить')
				end
				imgui.PushFont(font[11])
				if type(cfg.main.dateuprank) == 'string' then
					imgui.CenterText(u8(string.format('С %s', cfg.main.dateuprank)))
				else
					imgui.CenterText(u8(os.date('C %d.%m.%Y', cfg.main.dateuprank)))
				end
				imgui.PopFont()
				if imgui.IsItemClicked() then
					await['uprankdate'] = os.clock()
					sampSendChat('/jobprogress')
				else
					imgui.Hint('updateprogress', u8'Нажмите, что-бы перепроверить')
				end
			imgui.EndChild()

			if imgui.Button(u8('Биндер ')..fa.ICON_FA_COMMENTS, imgui.ImVec2(180, 30)) then
				type_window.v = 1
			end
			if imgui.Button(u8('Лекции ')..fa.ICON_FA_UNIVERSITY, imgui.ImVec2(180, 30)) then
				type_window.v = 2
			end
			if imgui.Button(u8('Правила ')..fa.ICON_FA_INFO_CIRCLE, imgui.ImVec2(180, 30)) then
				type_window.v = 3
			end
			if cfg.main.rank > 4 then
				if imgui.Button(u8('Ст. Состав ')..fa.ICON_FA_USERS, imgui.ImVec2(180, 30)) then
					type_window.v = 4
				end
			end
			if imgui.Button(u8('Настройки ')..fa.ICON_FA_COG, imgui.ImVec2(180, 30)) then
				type_window.v = 5
			end
		imgui.EndGroup()
		imgui.SameLine()
		imgui.BeginChild("##MenuActive", imgui.ImVec2(350, -1), true, imgui.WindowFlags.NoScrollbar)

		if type_window.v == 1 then -- Бинды
			if #cfg.Binds_Name > 0 then
				imgui.CenterTextColoredRGB(mc..'Меню пользовательских биндов {868686}(?)')
				imgui.Hint('binderBB', u8'Дважды нажми "B" (англ.) для\nбыстрого открытия этого меню')
				imgui.Separator()
				for key_bind, name_bind in pairs(cfg.Binds_Name) do
					imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(2, 2))
					if imgui.Button(name_bind..'##'..key_bind, imgui.ImVec2(269, 30)) then
						play_bind(key_bind)
						bank:switch()
					end 
					imgui.SameLine()    
					if imgui.Button(fa.ICON_FA_PEN..'##'..key_bind, imgui.ImVec2(30, 30)) then
						EditOldBind = true
						getpos = key_bind
						binder_delay.v = cfg.Binds_Deleay[key_bind] / 1000
						local returnwrapped = tostring(cfg.Binds_Action[key_bind]):gsub('~', '\n')
						text_binder.v = returnwrapped
						binder_name.v = tostring(cfg.Binds_Name[key_bind])
						imgui.OpenPopup(u8("Редактирование/Создание бинда"))
						binder_open = true
					end
					imgui.SameLine()
					if imgui.Button(fa.ICON_FA_TRASH..'##'..key_bind, imgui.ImVec2(30, 30)) then
						addBankMessage(string.format('Бинд {M}«%s»{W} удалён из вашего списка!', u8:decode(cfg.Binds_Name[key_bind])))
						table.remove(cfg.Binds_Name, key_bind)
						table.remove(cfg.Binds_Action, key_bind)
						table.remove(cfg.Binds_Deleay, key_bind)
						inicfg.save(cfg, 'Bank_Config.ini')
					end
					imgui.PopStyleVar()
				end
				if imgui.MainButton(u8('Создать новый бинд'), imgui.ImVec2(-1, 30)) then
					imgui.OpenPopup(u8("Редактирование/Создание бинда"))
					binder_delay.v = 2.5
				end
			else
				imgui.SetCursorPosY(60)
				imgui.PushFont(font[45])
				imgui.CenterText(fa.ICON_FA_QUOTE_RIGHT, imgui.ImVec4(0.5, 0.5, 0.5, 0.7))
				imgui.PopFont()
				imgui.NewLine()
				imgui.CenterTextColoredRGB('Бинды для оказания банковских услуг уже\nесть в скрипте! Для их использования нажмите:\n' .. mc .. 'ПКМ + Q (наведясь на игрока)')
				imgui.NewLine()
				imgui.SetCursorPosX((imgui.GetWindowWidth() - 150) / 2)
				if imgui.Button(u8('Хочу создать свой бинд!'), imgui.ImVec2(150, 30)) then
					imgui.OpenPopup(u8("Редактирование/Создание бинда"))
					binder_open = true
				end
			end
			binder()
		end
		if type_window.v == 2 then -- Лекции
			imgui.CenterTextColoredRGB(mc..'Проведение лекций для сотрудников')
			if imgui.MainButton(fa.ICON_FA_PLUS_CIRCLE .. u8' Добавить', imgui.ImVec2(100, 20)) then
				lection_number = nil
				lect_edit_name.v = u8("")
				lect_edit_text.v = u8("")
				imgui.OpenPopup(u8("Редактор лекций"))
			end
			imgui.SameLine()
			imgui.PushItemWidth(80)
			if imgui.DragInt('##LectDelay', LectDelay, 1, 1, 30, u8('%0.0f с.')) then
				if LectDelay.v < 1 then LectDelay.v = 1 end
				if LectDelay.v > 30 then LectDelay.v = 30 end

				cfg.main.LectDelay = LectDelay.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.Hint('delaylection', u8'Задержка между сообщениями')
			imgui.PopItemWidth()
			imgui.SameLine()
			imgui.RadioButton(u8("Чат"), typeLect, 1)
			imgui.SameLine()
			imgui.RadioButton(u8("/r"), typeLect, 2)
			imgui.SameLine()
			imgui.RadioButton(u8("/rb"), typeLect, 3)
			imgui.Separator()
			if #lections.data == 0 then
				imgui.SetCursorPosY(120)
				imgui.CenterTextColoredRGB(mc..'У вас нет ни одной лекции :(')
				imgui.SetCursorPosX((imgui.GetWindowWidth() - 250) / 2)
				if imgui.MainButton(u8'Восстановить стандартные лекции?', imgui.ImVec2(250, 25)) then
					lections = lections_default
					local file = io.open(lect_path, "w")
					file:write(encodeJson(lections))
					file:close()
				end
			else
				for i, block in ipairs(lections.data) do
					local name = block.name
					local data = block.text
					--
					if lections.active.bool == true then
						if name == lections.active.name then
							if imgui.MainButton(fa.ICON_FA_PAUSE .. '##' .. u8(name), imgui.ImVec2(280, 25)) then
								lections.active.bool = false
								lections.active.name = nil
								lections.active.handle:terminate()
								lections.active.handle = nil
							end
						else
							imgui.DisableButton(u8(name), imgui.ImVec2(280, 25))
						end
						imgui.SameLine(nil, 5)
						imgui.DisableButton(fa.ICON_FA_PEN .. '##' .. u8(name), imgui.ImVec2(-1, 25))
					else
						if imgui.Button(u8(name), imgui.ImVec2(280, 25)) then
							lections.active.bool = true
							lections.active.name = name
							lections.active.handle = lua_thread.create(function()
								for i, line in ipairs(data) do
									if typeLect.v == 2 then
										sampProcessChatInput(string.format('/r %s', line))
									elseif typeLect.v == 3 then
										sampProcessChatInput(string.format('/rb %s', line))
									else
										sampProcessChatInput(string.format('%s', line))
									end
									if i ~= #data then
										wait(LectDelay.v * 1000)
									end
								end
								lections.active.bool = false
								lections.active.name = nil
								lections.active.handle = nil
							end)
						end
						imgui.SameLine(nil, 5)
						if imgui.Button(fa.ICON_FA_PEN .. '##' .. u8(name), imgui.ImVec2(-1, 25)) then
							lection_number = i
							lect_edit_name.v = u8(tostring(name))
							lect_edit_text.v = u8(tostring(table.concat(data, '\n')))
							imgui.OpenPopup(u8"Редактор лекций")
						end
					end
				end
			end
			lection_editor()
		end
		if type_window.v == 3 then -- Правила
			imgui.CenterTextColoredRGB(mc..'Информация для сотрудников')
			imgui.NewLine()

			if imgui.Button(u8('Устав Центрального банка ')..fa.ICON_FA_BOOK_OPEN, imgui.ImVec2(-1, 35)) then
				if not ustav_window.state then ustav_window:switch() end
			end
			if imgui.Button(u8('Единая система повышения ')..fa.ICON_FA_SORT_AMOUNT_UP, imgui.ImVec2(-1, 35)) then
				imgui.OpenPopup(u8("Единая система повышения"))
			end
			system_uprank()
			if imgui.Button(u8('Кадровая система ')..fa.ICON_FA_CLOCK, imgui.ImVec2(-1, 35)) then
				imgui.OpenPopup(u8("Кадровая система"))
			end
			system_cadr()
			if imgui.Button(u8('Система кредитования ')..fa.ICON_FA_CALENDAR_CHECK, imgui.ImVec2(-1, 35)) then
				imgui.OpenPopup(u8("Система кредитования"))
			end
			system_credit()
			if imgui.Button(u8('Расположение постов ')..fa.ICON_FA_FLAG, imgui.ImVec2(-1, 35)) then
				imgui.OpenPopup(u8("Расположение постов"))
			end
			post()
		end
		if type_window.v == 4 then -- Ст. Состав
			if imgui.Button(u8('Чёрный список правительства ')..fa.ICON_FA_BAN, imgui.ImVec2(-1, 35)) then
				imgui.OpenPopup(u8("Чёрный список правительства"))
			end
			BlackListGui()
			if cfg.main.rank >= 9 then
				if imgui.Button(u8('Государственная волна ')..fa.ICON_FA_GLOBE, imgui.ImVec2(-1, 35)) then
					imgui.OpenPopup(u8("Планирование государственной волны"))
				end
			else
				imgui.DisableButton(u8('Государственная волна ')..fa.ICON_FA_LOCK, imgui.ImVec2(-1, 35))
				imgui.Hint('goswave8+', u8'Доступно с 9 ранга')
			end
			gov()
		end

		if type_window.v == 5 then -- Настройки
			imgui.CenterTextColoredRGB(mc..'Настройки скрипта')
			
			imgui.NewLine()
			imgui.TextDisabled(u8"Функции:")
			imgui.PushItemWidth(80)
			if imgui.Checkbox(u8'Автоматические обновления', loginupdate) then
				cfg.main.loginupdate = loginupdate.v 
				if inicfg.save(cfg, 'Bank_Config.ini') then
					addBankMessage(string.format('Авто-проверка обновлений при входе в игру {M}%s', (cfg.main.loginupdate and 'включена' or 'выключена')))
				end
			end

			if imgui.Checkbox(u8'Чат-калькулятор', chat_calc) then
				cfg.main.chat_calc = chat_calc.v 
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.SameLine()
			imgui.TextDisabled('(?)')
			imgui.Hint('chatcalc', u8'Если в чате написать математический пример, то под ним появится ответ')

			if imgui.Checkbox(u8'Авто-форма', auto_uniform) then
				cfg.main.auto_uniform = auto_uniform.v 
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.SameLine()
			imgui.TextDisabled('(?)')
			imgui.Hint('autouniform', u8'Вы автоматически неадените форму, как только зайдёте на сервер\nТекущим местом спавна должна быть выбрана организация (/setspawn)')

			if imgui.Checkbox(u8'Авто-дубинка', auto_stick) then
				cfg.main.auto_stick = auto_stick.v 
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.SameLine()
			imgui.TextDisabled('(?)')
			imgui.Hint('autostick', u8'Вы автоматически возьмёте дубинку, как только зайдёте на сервер\nТекущим местом спавна должна быть выбрана организация (/setspawn)')

			imgui.PopItemWidth()
			if imgui.Checkbox(u8'Статистика на кассе', ki_stat) then
				cfg.main.ki_stat = ki_stat.v
				inicfg.save(cfg, 'Bank_Config.ini')
				if kassa.state.v and ki_stat.v == false then 
					kassa.state.v = false 
				end
			end
			imgui.SameLine()
			imgui.TextDisabled('(?)')
			imgui.Hint('kippos', u8'Панель можно переместить командой /kip')
			imgui.PushItemWidth(150)
			if imgui.InputText("##PINCODE", pincode, imgui.InputTextFlags.CharsDecimal + (PIN_PASSWORD and 0 or imgui.InputTextFlags.Password)) then
				cfg.main.pincode = tostring(pincode.v)
			end
			imgui.PopItemWidth()
			imgui.Hint('pinhint', u8'PIN-Код от вашей банковской карты\nВведите его, чтобы он вводился автоматически или\nоставьте пустым, если желаете вводить вручную')
			imgui.SameLine()
			imgui.TextDisabled(PIN_PASSWORD and fa.ICON_FA_EYE or fa.ICON_FA_EYE_SLASH)
			if imgui.IsItemClicked(0) then
				PIN_PASSWORD = not PIN_PASSWORD
			end

			imgui.NewLine()
			imgui.TextDisabled(u8"Сообщения в чате:")
			if imgui.Checkbox(u8'Сообщения о /expel', chat['expel']) then
				cfg.Chat.expel = chat['expel'].v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if imgui.Checkbox(u8'Оплата штрафов', chat['shtrafs']) then
				cfg.Chat.shtrafs = chat['shtrafs'].v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if imgui.Checkbox(u8'Пополнения казны сотрудниками', chat['incazna']) then
				cfg.Chat.incazna = chat['incazna'].v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if imgui.Checkbox(u8'Принятие сотрудников', chat['invite']) then
				cfg.Chat.invite = chat['invite'].v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if imgui.Checkbox(u8'Увольнения сотрудников', chat['uval']) then
				cfg.Chat.uval = chat['uval'].v
				inicfg.save(cfg, 'Bank_Config.ini')
			end

			imgui.NewLine()
			imgui.TextDisabled(u8"RP отыгровки:")
			imgui.TextColoredRGB(mc..'Задержка между сообщениями в отыгровках:')
			imgui.PushItemWidth(100)
			if imgui.SliderFloat('##MsgDelay', MsgDelay, 0.5, 10.0, u8'%0.2f с.') then
				if MsgDelay.v < 0.5 then MsgDelay.v = 0.5 end
				if MsgDelay.v > 10.0 then MsgDelay.v = 10.0 end

				cfg.main.MsgDelay = MsgDelay.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.PopItemWidth()

			imgui.SameLine()
			imgui.TextDisabled("(?)")
			imgui.Hint("handwritehelp", u8"Зажмите CTRL + ЛКМ, чтобы ввести вручную")

			imgui.TextColoredRGB(mc..'Ваш пол:')
			if imgui.RadioButton(u8("Мужской"), sex, 1) then
				cfg.main.sex = sex.v
				if inicfg.save(cfg, 'Bank_Config.ini') then 
					addBankMessage('Пол изменён на {M}Мужской')
				end
			end
			if imgui.RadioButton(u8("Женский"), sex, 2) then 
				cfg.main.sex = sex.v
				if inicfg.save(cfg, 'Bank_Config.ini') then 
					addBankMessage('Пол изменён на {M}Женский')
				end
			end

			imgui.TextColoredRGB(mc..'Авто-Скрин + /time')
			imgui.SameLine()
			imgui.TextDisabled("(?)")
			imgui.Hint('autoscreen', u8'Все ваши повышения, увольнения, выдачи рангов и т.п.\nбудут автоматически скриниться с /time')

			if imgui.Checkbox(u8(autoF8.v and 'Включено' or 'Выключено')..'##autoF8', autoF8) then 
				cfg.main.autoF8 = autoF8.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if autoF8.v then
				if not doesFileExist(getGameDirectory()..'/Screenshot.asi') then
					if imgui.Button(u8'Скачать Screenshot.asi', imgui.ImVec2(150, 20)) then 
						downloadUrlToFile('https://gitlab.com/uploads/-/system/personal_snippet/1978930/0b4025da038173a8b1ce81d5e3848901/Screenshot.asi', getGameDirectory()..'/Screenshot.asi', function (id, status, p1, p2)
							if status == dlstatus.STATUSEX_ENDDOWNLOAD then
								runSampfuncsConsoleCommand('pload Screenshot.asi')
								addBankMessage('Плагин {M}Screenshot.asi{W} загружен! Рекомендуется перезайти в игру!')
							end
						end)
					end
					imgui.Hint('screenplugin', u8('Позволяет делать моментальные скриншоты без зависания игры\nПосле скачивания нужно перезайти в игру\nАвтор: MISTER_GONWIK'), 0, u8'Нажмите, что-бы скачать')
				else
					imgui.TextColoredRGB('{30FF30}Используется Screenshot.asi')
				end
			end

			imgui.TextColoredRGB(mc..'Акцент')
			if imgui.Checkbox(u8(accent_status.v and 'Включено' or 'Выключено')..'##accent_status', accent_status) then 
				cfg.main.accent_status = accent_status.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if cfg.main.accent_status then
				imgui.PushItemWidth(280)
				imgui.InputText(u8"##accent", accent); imgui.SameLine()
				imgui.PopItemWidth()
				if imgui.Button('Save##accent', imgui.ImVec2(-1, 20)) then 
					cfg.main.accent = u8:decode(accent.v)
					if inicfg.save(cfg, 'Bank_Config.ini') then 
						addBankMessage('Акцент сохранён!')
					end
				end
			end
			imgui.TextColoredRGB(mc..'Авто-Отыгровка дубинки')
			if imgui.Checkbox(u8(rpbat.v and 'Включено' or 'Выключено')..'##rpbat', rpbat) then 
				cfg.main.rpbat = rpbat.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			if rpbat.v then
				imgui.TextColoredRGB(mc..'Взять дубинку')
				imgui.PushItemWidth(280)
				imgui.InputText(u8"##rpbat_true", rpbat_true); imgui.SameLine()
				imgui.PopItemWidth()
				if imgui.Button('Save##1', imgui.ImVec2(-1, 20)) then 
					cfg.main.rpbat_true = u8:decode(rpbat_true.v)
					if inicfg.save(cfg, 'Bank_Config.ini') then 
						addBankMessage('Отыгровка сохранена!')
					end
				end

				imgui.TextColoredRGB(mc..'Убрать дубинку')
				imgui.PushItemWidth(280)
				imgui.InputText(u8"##rpbat_false", rpbat_false); imgui.SameLine()
				imgui.PopItemWidth()
				if imgui.Button('Save##2', imgui.ImVec2(-1, 20)) then 
					cfg.main.rpbat_false = u8:decode(rpbat_false.v)
					if inicfg.save(cfg, 'Bank_Config.ini') then 
						addBankMessage('Отыгровка сохранена!')
					end
				end
			end

			imgui.NewLine()
			imgui.TextDisabled(u8"Внешний вид:")
			if imgui.ToggleButton(u8'Тёмная тема', black_theme) then
				SCRIPT_STYLE.clock = os.clock()
				cfg.main.black_theme = black_theme.v
				inicfg.save(cfg, 'Bank_Config.ini')
			end

			if SCRIPT_STYLE.clock ~= nil then
				local result = {}

				SCRIPT_STYLE.colors['B'], result[1] = bringVec4To(UI_COLORS["B"][not black_theme.v], UI_COLORS["B"][black_theme.v], SCRIPT_STYLE.clock, 0.5)
				SCRIPT_STYLE.colors['E'], result[2] = bringVec4To(UI_COLORS["E"][not black_theme.v], UI_COLORS["E"][black_theme.v], SCRIPT_STYLE.clock, 0.3)
				SCRIPT_STYLE.colors['T'], result[3] = bringVec4To(UI_COLORS["T"][not black_theme.v], UI_COLORS["T"][black_theme.v], SCRIPT_STYLE.clock, 0.1)

				set_style(SCRIPT_STYLE.colors)
				if not result[1] and not result[2] and not result[3] then
					SCRIPT_STYLE.clock = nil
				end
			end
		
			if imgui.ColorEdit4(u8'Цвет чата организации', colorRchat, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoAlpha) then
				local clr = imgui.ImColor.FromFloat4(colorRchat.v[1], colorRchat.v[2], colorRchat.v[3], colorRchat.v[4]):GetU32()
				cfg.main.colorRchat = clr
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.SameLine(imgui.GetWindowWidth() - 150)
			if imgui.Button(u8("Тест##RCol"), imgui.ImVec2(50, 20)) then
				local r, g, b, a = imgui.ImColor(cfg.main.colorRchat):GetRGBA()
				sampAddChatMessage('[R] '..cfg.nameRank[cfg.main.rank]..' '..sampGetPlayerNickname(tonumber(selfid))..'['..selfid..']: (( Это сообщение видите только вы! ))', join_rgb(r, g, b))
			end
			imgui.SameLine(imgui.GetWindowWidth() - 95)
			if imgui.Button(u8("Стандартный##Rcol"), imgui.ImVec2(90, 20)) then
				cfg.main.colorRchat = 4282626093
				if inicfg.save(cfg, 'Bank_Config.ini') then 
					addBankMessage('Стандартный цвет чата организации восстановлен!')
					colorRchat = imgui.ImFloat4(imgui.ImColor(cfg.main.colorRchat):GetFloat4())
				end
			end

			if imgui.ColorEdit4(u8'Цвет чата департамента', colorDchat, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoAlpha) then
				local clr = imgui.ImColor.FromFloat4(colorDchat.v[1], colorDchat.v[2], colorDchat.v[3], colorDchat.v[4]):GetU32()
				cfg.main.colorDchat = clr
				inicfg.save(cfg, 'Bank_Config.ini')
			end
			imgui.SameLine(imgui.GetWindowWidth() - 150)
			if imgui.Button(u8("Тест##DCol"), imgui.ImVec2(50, 20)) then
				local r, g, b, a = imgui.ImColor(cfg.main.colorDchat):GetRGBA()
				sampAddChatMessage('[D] '..cfg.nameRank[cfg.main.rank]..' '..sampGetPlayerNickname(tonumber(selfid))..'['..selfid..']: Это сообщение видите только вы!', join_rgb(r, g, b))
			end
			imgui.SameLine(imgui.GetWindowWidth() - 95)
			if imgui.Button(u8("Стандартный##DCol"), imgui.ImVec2(90, 20)) then
				cfg.main.colorDchat = 4294940723
				if inicfg.save(cfg, 'Bank_Config.ini') then 
					addBankMessage('Стандартный цвет чата департамента восстановлен!')
					colorDchat = imgui.ImFloat4(imgui.ImColor(cfg.main.colorDchat):GetFloat4())
				end
			end

			imgui.NewLine()
			imgui.TextDisabled(u8"Связь с разработчиком:")

			imgui.PushStyleVar(imgui.StyleVar.FrameRounding, 5)
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.35, 0.80, 0.8))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.10, 0.35, 0.80, 0.9))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.10, 0.35, 0.80, 1))
			imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
			if imgui.Button(u8("VK"), imgui.ImVec2(80, 25)) then
				os.execute("explorer https://vk.me/cosui")
			end
			imgui.PopStyleColor(4)
			imgui.SameLine(nil, 5)
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.60, 1.00, 0.8))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.60, 1.00, 0.9))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.60, 1.00, 1))
			if imgui.Button(u8("Telegram"), imgui.ImVec2(80, 25)) then
				os.execute("explorer https://t.me/cosmo_way")
			end
			imgui.PopStyleColor(3)
			imgui.SameLine(nil, 5)
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.23, 0.36, 1.0))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.33, 0.46, 1.0))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.35, 0.43, 0.56, 1.0))
			if imgui.Button(u8("Blast Hack"), imgui.ImVec2(80, 25)) then
				os.execute("explorer https://www.blast.hk/threads/58083/")
			end
			imgui.PopStyleColor(3)
			imgui.PopStyleVar()
			
			imgui.NewLine()

			imgui.BeginGroup()
				if imgui.Button(u8('Проверить обновления ')..fa.ICON_FA_DOWNLOAD, imgui.ImVec2(150, 30)) then
					autoupdate(jsn_upd); checkData()
				end

				if imgui.Button(u8('Ручное обновление ')..fa.ICON_FA_DOWNLOAD, imgui.ImVec2(150, 30)) then
					local url = "https://gitlab.com/Cosmo-ctrl/bank-helper-for-arizona-rp/-/raw/main/Bank-Helper.lua?inline=false"
					local path = getWorkingDirectory() .. "\\" .. thisScript().filename
					local command = string.format("bitsadmin /transfer n \"%s\" \"%s\"", url, path)
					os.execute(command)
				end
				imgui.Hint("HandUpdate", u8"Установить последнюю версию принудительно\n(Откроется консоль, может потребоваться некоторое время)")
			imgui.EndGroup()		

			imgui.SameLine(nil, 5)

			imgui.BeginGroup()
				if imgui.RedButton(u8'Удалить Bank-Helper', imgui.ImVec2(-1, 30)) then
					imgui.OpenPopup('##deleteBankHelper')
				end
				imgui.SetNextWindowSize(imgui.ImVec2(400, -1), imgui.Cond.FirstUseEver)
				imgui.PushStyleColor(imgui.Col.ModalWindowDarkening, imgui.ImVec4(0.70, 0.00, 0.00, 0.10))
				if imgui.BeginPopupModal('##deleteBankHelper', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar) then

					imgui.PushFont(font[20])
					imgui.CenterText(fa.ICON_FA_TRASH, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
					imgui.CenterText(u8'УДАЛЕНИЕ BANK HELPER', imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
					imgui.PopFont()
					imgui.Spacing()
					imgui.CenterText(u8'Вы действительно хотите удалить Bank-Helper?')
					imgui.CenterText(u8'Отменить это действие будет невозможно!', imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
					imgui.Spacing()

					imgui.SetCursorPosX((imgui.GetWindowWidth() - 300 - imgui.GetStyle().ItemSpacing.x) / 2)
					if imgui.RedButton(u8'Удалить', imgui.ImVec2(150, 30)) then
						addBankMessage('Прощай :(')
						os.remove(thisScript().path)
						os.remove(getWorkingDirectory() .. '\\config\\Bank_Config.ini')
						unload(false)
					end
					imgui.SameLine()
					imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.20, 0.20, 1.00))
					if imgui.Button(u8'Вернуться', imgui.ImVec2(150, 30)) then
						imgui.CloseCurrentPopup()
					end
					imgui.PopStyleColor()

					imgui.EndPopup()
				end
				imgui.PopStyleColor()

				if imgui.Button(u8('Полезные скрипты ')..fa.ICON_FA_PUZZLE_PIECE, imgui.ImVec2(-1, 30)) then
					type_window.v = 6
				end
			imgui.EndGroup()

			if imgui.GreenButton(u8'Список изменений', imgui.ImVec2(-1, 20)) then
				if not infoupdate.state then infoupdate:switch() end
			end

			imgui.NewLine()
			imgui.CenterTextColoredRGB('{AAAAAA}By Cosmo, 2020 - 2022')
			imgui.Spacing()
		end

		if type_window.v == 6 then 
			imgui.CenterTextColoredRGB(mc..'Репозиторий полезных скриптов {868686}(?)')
			imgui.Hint('aboutrepository', u8'Все скрипты сделаны лично автором этого\nбанк-хелпера и не имеют в себе стиллеров.')
			imgui.Separator()
			imgui.Repository('OnScreenMembers (OSM)', 'OnScreenMembers.lua', 'Скрипт, который может вывести весь /members\nорганизации на ваш экран, крайне полезная вещь для руководителей\nа так же простых сотрудников организации', '/osm', 'https://gitlab.com/uploads/-/system/personal_snippet/1978930/ec1816d3e019ad5e7a06283ec6308d19/OnScreenMembers.lua', 'https://www.blast.hk/threads/59761/')
			imgui.Repository('Timer Online', 'TimerOnline.lua', 'Скрипт, который считает ваш онлайн в игре.\nУмеет считать чистый онлайн, онлайн в АФК,\nа так же онлайн за день и за неделю', '/toset', 'https://gitlab.com/uploads/-/system/personal_snippet/1978930/0e7c0070d9207abd5063ddbf2cd1cf59/TimerOnline.lua', 'https://www.blast.hk/threads/59396/')
			imgui.Repository('Leader Logger', 'LeadLogger.lua', 'Данная утилита будет логировать все лидерские действия в организации такие как повышения, увольнения, инвайты, выговоры и так далее. Очень полезно лидерам при составлении отчётов на форум', '/logger', 'https://gitlab.com/uploads/-/system/personal_snippet/1978930/26668c363e85f146567d4e0cfa4e08ae/LeadLogger.lua', 'https://www.blast.hk/threads/59244/')
			imgui.Repository('Chat Clist', 'cnickchat.lua', 'При разговоре ники игроков в чате будут цветом их клиста', 'Автоматически', 'https://gitlab.com/uploads/-/system/personal_snippet/1978930/28975bb7431741f67540db5406ca0bf8/cnickchat.lua')
			imgui.Repository('Premium', 'Premium.lua', 'Продвинутое и удобное меню выдачи премий сотрудникам', '/prem', 'https://gitlab.com/uploads/-/system/personal_snippet/1978930/a73761a36dc0e6c4eb8277a7639c947c/Premium.lua')
		end
		imgui.EndChild()
		imgui.EndGroup()
		imgui.End()
		imgui.PopStyleVar()
	end

	if ustav_window.alpha > 0.00 then
		local xx, yy = getScreenResolution()
		imgui.SetNextWindowSize(imgui.ImVec2(xx / 1.5, yy / 1.5), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(xx / 2, yy / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.PushStyleVar(imgui.StyleVar.Alpha, ustav_window.alpha)
		imgui.PushStyleVar(imgui.StyleVar.WindowMinSize, imgui.ImVec2(500, 300))
		imgui.Begin(u8'Устав Центрального Банка', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar)
			
			imgui.SetCursorPosX((imgui.GetWindowWidth() - 200) / 2)
			imgui.PushItemWidth(200)
			imgui.PushAllowKeyboardFocus(false)
			imgui.InputText("##search_ustav", search_ustav, imgui.InputTextFlags.EnterReturnsTrue)
			imgui.PopAllowKeyboardFocus()
			imgui.PopItemWidth()
			if not imgui.IsItemActive() and #search_ustav.v == 0 then
				imgui.SameLine((imgui.GetWindowWidth() - imgui.CalcTextSize(fa.ICON_FA_SEARCH..u8(' Поиск по уставу')).x) / 2)
				imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1), fa.ICON_FA_SEARCH..u8(' Поиск по уставу'))
			end
			imgui.CenterTextColoredRGB('{868686}Двойной клик по строке, выведет её в поле ввода в чате')
			imgui.Separator()

			local results = 0
			for line in io.lines(getWorkingDirectory() .. "\\BHelper\\Устав ЦБ.txt") do
				if #line == 0 then line = "\n" end

				if #search_ustav.v <= 0 then
					imgui.TextWrapped(u8(line))
				elseif string.find(stringToLower(line), stringToLower(u8:decode(search_ustav.v)), 1, true) then
					imgui.TextWrapped(u8(line))
					results = results + 1
				else
					goto skip
				end

				if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then
					sampSetChatInputEnabled(true)
					sampSetChatInputText(line)
				end
				
				::skip::
			end

			if #search_ustav.v > 0 and results == 0 then
				imgui.SetCursorPosY((imgui.GetWindowHeight() + 50) / 2)
				imgui.CenterTextColoredRGB('{666666}Похоже, ничего не найдено :(')
			end

			local wsize = imgui.GetWindowSize()
			imgui.SetCursorPos(imgui.ImVec2(wsize.x - 10 - 20 - 5 - 20, 26))
			if imgui.Button(fa.ICON_FA_PEN .. '##ustavedit', imgui.ImVec2(20, 20)) then
				os.execute('explorer '..getWorkingDirectory()..'\\BHelper\\Устав ЦБ.txt')
			end
			imgui.SameLine(nil, 5)
			if imgui.Button(fa.ICON_FA_TIMES .. "##ustavexit", imgui.ImVec2(20, 20)) then
				if ustav_window.state then ustav_window:switch() end
			end
		imgui.End()
		imgui.PopStyleVar(2)
	end
	Window_Info_Update()
	GetKassaInfo()
	GlobalNotify()
end

function imgui.MarkTextByPart(search, str, color)
    local _, r, g, b = explode_argb(color or 0xFFFF0000)
    local hex = ('{%06X}'):format(join_rgb(r, g, b))
    search = search:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%1')
    return str:gsub(search, hex .. '%1{SSSSSS}')
end

function GlobalNotify()
	notify.active = 0
	for k, v in ipairs(notify.messages) do
		local push = false
		if v.active and v.time < os.clock() then
			v.active = false
		end

		if notify.active < notify.max then
			if not v.active then
				if v.showtime > 0 then
					v.active = true
					v.time = os.clock() + v.showtime
					v.showtime = 0
				end
			end
			if v.active then
				notify.active = notify.active + 1
				if v.time + 3.000 >= os.clock() then
					imgui.PushStyleVar(imgui.StyleVar.Alpha, (v.time - os.clock()) / 1.0)
					push = true
				end
				notify.list.pos = imgui.ImVec2(notify.list.pos.x, notify.list.pos.y - 80)

				imgui.SetNextWindowPos(notify.list.pos, _, imgui.ImVec2(0.0, 0.25))
				imgui.SetNextWindowSize(imgui.ImVec2(250, 70))
				imgui.PushStyleVar(imgui.StyleVar.WindowRounding, 5.0)
				imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(0.0, 0.0))
				imgui.PushStyleVar(imgui.StyleVar.ChildWindowRounding, 5.0)
				imgui.Begin(u8'##notifycard'..k, _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoTitleBar)
					
					local p = imgui.GetCursorScreenPos()
					local ws = imgui.GetWindowSize()
					local bar_size = (v.bar_time - (os.clock() - v.start)) / ( v.bar_time / ws.x )
					if bar_size > 0 then
						imgui.GetWindowDrawList():AddRectFilled(
							imgui.ImVec2(p.x, p.y + (ws.y - 5)), 
							imgui.ImVec2(p.x + bar_size, p.y + ws.y), 
							imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.0, 0.5, 1.0, (v.time - os.clock()) / 1.0)), 
							5, 
							bar_size == ws.x and 12 or 8
						)
					end
					imgui.SetCursorPos(imgui.ImVec2(5, 5))
					imgui.BeginGroup()
						imgui.PushFont(font[60])
						imgui.TextColored(imgui.ImVec4(0.0, 0.41, 0.76, 1.00), fa.ICON_FA_UNIVERSITY)
						imgui.PopFont()
					imgui.EndGroup()
					imgui.SameLine(nil, 10)
					imgui.BeginGroup()
						imgui.SetCursorPosY(7.5)
						imgui.PushFont(font[15])
						imgui.TextColoredRGB('{006AC2}Central Bank')
						imgui.PopFont()
						imgui.TextColoredRGB(tostring(v.text))
					imgui.EndGroup()
				imgui.End()
				imgui.PopStyleVar(3)
				if push then
					imgui.PopStyleVar()
				end
			end
		end
	end
	notf_sX, notf_sY = convertGameScreenCoordsToWindowScreenCoords(605, 438)
	notify.list = {
		pos = { x = notf_sX - 200, y = notf_sY + 20 },
		npos = { x = notf_sX - 200, y = notf_sY },
		size = { x = 200, y = 0 }
	}
end

function addNotify(text, time)
	notify.messages[#notify.messages + 1] = { 
		active = false, 
		time = 0, 
		showtime = time,
		text = text,
		start = os.clock(),
		bar_time = time - 1
	}
end

function GetKassaInfo()
	if kassa.state.v then
		imgui.SetNextWindowPos(imgui.ImVec2(cfg.main.KipX, cfg.main.KipY), imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(210, 180), imgui.Cond.FirstUseEver)
		imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
		imgui.PushStyleVar(imgui.StyleVar.WindowRounding, 5)
		imgui.Begin(u8("Статистика"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoBringToFrontOnFocus + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoTitleBar)

			local DL = imgui.GetWindowDrawList()
			local p = imgui.GetCursorScreenPos()
			local ws = imgui.GetWindowSize()
			DL:AddRectFilled(
				imgui.ImVec2(p.x + ws.x - 6, p.y), 
				imgui.ImVec2(p.x + ws.x, p.y + ws.y), 
				imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.0, 0.5, 1.0, 1.00)), 
				imgui.GetStyle().WindowRounding, 
				6
			)
			imgui.SetCursorPos(imgui.ImVec2(8, 8))
			imgui.BeginGroup()
				local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
				local distBetweenKassa = getDistanceBetweenCoords3d(kassa.pos.x, kassa.pos.y, kassa.pos.z, myX, myY, myZ)
				if distBetweenKassa < 10 then

					local title = u8('Работа за кассой')
					local len = imgui.CalcTextSize(title).x
					DL:AddRectFilled(
						imgui.ImVec2(p.x, p.y + 5), 
						imgui.ImVec2(p.x + len + 35, p.y + 25), 
						imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.0, 0.5, 1.0, 1.00)), 
						10, 
						6
					)

					imgui.PushFont(font[15])
					imgui.SetCursorPosY(7)
					imgui.TextColored(imgui.ImVec4(1, 1, 1, 1), title)
					imgui.PopFont()

					imgui.SetCursorPosY(35)
					imgui.Text(fa.ICON_FA_CLOCK);           imgui.SameLine(30); imgui.TextColoredRGB(mc..'Время на посту: {SSSSSS}'         ..kassa.time.v..' мин.')
					imgui.Text(fa.ICON_FA_CHECK_CIRCLE);    imgui.SameLine(30); imgui.TextColoredRGB(mc..'Оформлено депозитов: {SSSSSS}'    ..tostring(kassa.info.dep))
					imgui.Text(fa.ICON_FA_HANDSHAKE);       imgui.SameLine(30); imgui.TextColoredRGB(mc..'Оформлено кредитов: {SSSSSS}'     ..tostring(kassa.info.credit))
					imgui.Text(fa.ICON_FA_CREDIT_CARD);     imgui.SameLine(30); imgui.TextColoredRGB(mc..'Выдано карт: {SSSSSS}'            ..tostring(kassa.info.card))
					imgui.Text(fa.ICON_FA_TICKET_ALT);     	imgui.SameLine(30); imgui.TextColoredRGB(mc..'Выдано VIP-карт: {SSSSSS}'        ..tostring(kassa.info.vip))
					imgui.Text(fa.ICON_FA_RECYCLE);         imgui.SameLine(30); imgui.TextColoredRGB(mc..'Восстановлено карт: {SSSSSS}'     ..tostring(kassa.info.recard))
					imgui.Text(fa.ICON_FA_PLUS_CIRCLE);     imgui.SameLine(30); imgui.TextColoredRGB(mc..'Создано доп. счетов: {SSSSSS}'    ..tostring(kassa.info.addcard))
					imgui.Text(fa.ICON_FA_PIGGY_BANK);      imgui.SameLine(30); imgui.TextColoredRGB(mc..'Заработано: {SSSSSS}$'            ..sumFormat(kassa.money))
				else
					imgui.CenterTextColoredRGB(sc..'Пост: '..kassa.name.v:gsub('\n', ''))
					imgui.SetCursorPosY(60)
					if getActiveInterior() ~= 0 then
						imgui.CenterTextColoredRGB(mc..'Вы далеко отошли!\nПодойдите ближе к кассе!\n{SSSSSS}'..math.floor(distBetweenKassa)..'м. от кассы')
					else
						imgui.CenterTextColoredRGB(mc..'Вы ушли от кассы!\n{SSSSSS}Пост завершится если\nвы не вернётесь в банк!')
					end
				end
			imgui.EndGroup()
		imgui.End()
		imgui.PopStyleVar(2)
	end
end

function lection_editor(lection)
	if imgui.BeginPopupModal(u8"Редактор лекций", _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then

		imgui.InputText(u8"Название лекции##lecteditor", lect_edit_name)
		if lection_number ~= nil then
			imgui.SameLine(600)
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.40, 0.00, 0.00, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.00, 0.00, 1.00))
			if imgui.Button(u8('Удалить ')..fa.ICON_FA_TRASH, imgui.ImVec2(-1, 20)) then
				imgui.CloseCurrentPopup()
				table.remove(lections.data, lection_number)
				local file = io.open(lect_path, "w")
				file:write(encodeJson(lections))
				file:close()
			end
			imgui.PopStyleColor(2)
		end
		imgui.InputTextMultiline("##lecteditortext", lect_edit_text, imgui.ImVec2(700, 300))

		imgui.SetCursorPosX( (imgui.GetWindowWidth() - 300 - imgui.GetStyle().ItemSpacing.x) / 2 )
		if #lect_edit_name.v > 0 and #lect_edit_text.v > 0 then
			if imgui.MainButton(u8"Сохранить##lecteditor", imgui.ImVec2(150, 20)) then
				local pack = function(text, match)
					local array = {}
					for line in text:gmatch('[^' .. match .. ']+') do
						array[#array + 1] = line
					end
					return array
				end
				if lection_number == nil then 
					table.insert(lections.data, {
						name = u8:decode(tostring(lect_edit_name.v)),
						text = pack(u8:decode(tostring(lect_edit_text.v)), '\n')
					})
				else
					lections.data[lection_number].name = u8:decode(tostring(lect_edit_name.v))
					lections.data[lection_number].text = pack(u8:decode(tostring(lect_edit_text.v)), '\n')
				end
				
				local file = io.open(lect_path, "w")
				file:write(encodeJson(lections))
				file:close()
				imgui.CloseCurrentPopup()
			end
		else
			imgui.DisableButton(u8"Сохранить##lecteditor", imgui.ImVec2(150, 20))
			imgui.Hint('errgraflection', u8'Заполнены не все поля!')
		end
		imgui.SameLine()
		if imgui.Button(u8"Отменить##lecteditor", imgui.ImVec2(150, 20)) then
			imgui.CloseCurrentPopup()
		end
		imgui.EndPopup()
	end
end

function go_expel(playerId, withoutRP)
	local self_color = sampGetPlayerColor(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
	local target_color = sampGetPlayerColor(playerId)
	if target_color ~= self_color then
		if not sampIsPlayerPaused(playerId) then
			local cmd_expel = string.format("/expel %s %s", playerId, cfg.main.expelReason)
			if withoutRP then return sampSendChat(cmd_expel) end

			play_message(MsgDelay.v, true, {
				{ "/do Рация висит на поясе." },
				{ "/me {sex:снял|сняла} рацию с пояса и {sex:позвал|позвала} к себе охрану" },
				{ "/do Сотрудник охраны подошёл и схватил за руки %s.", rpNick(playerId) },
				{ "/do Сотрудник вывел %s из банка и закрыл за собой дверь.", rpNick(playerId) },
				{ cmd_expel }
			})
		else
			addBankMessage('Нельзя выгнать игрока который в АФК!')
		end
	else
		addBankMessage('Похоже, вы пытаетесь выгнать сотрудника банка...')
	end
end

function onWindowMessage(msg, wparam, lparam)
	if process_position then
		if msg == 0x0201 then -- LButton
            addBankMessage("Месторасположение сохранено!")
            process_position = nil; consumeWindowMessage(true, true)
		elseif msg == 0x0100 and wparam == 0x1B then -- Esc
			cfg.main.KipX = process_position[2]
			cfg.main.KipY = process_position[3]
			addBankMessage('Вы отменили изменение месторасположения')
			process_position = nil; consumeWindowMessage(true, true)
		end
	end

	if msg == 0x0100 and wparam == 0x1B then -- ESC
		if int_bank.state then
			consumeWindowMessage(true, true)
			int_bank:switch()
		end
		if ustav_window.state then
			consumeWindowMessage(true, true)
			ustav_window:switch()
		end
	end
end

function imgui.Hint(str_id, hint, delay)
	local hovered = imgui.IsItemHovered()
	local animTime = 0.2
	local delay = delay or 0.00
	local show = true

	if not allHints then allHints = {} end
	if not allHints[str_id] then
		allHints[str_id] = {
			status = false,
			timer = 0
		}
	end

	if hovered then
		for k, v in pairs(allHints) do
			if k ~= str_id and os.clock() - v.timer <= animTime  then
				show = false
			end
		end
	end

	if show and allHints[str_id].status ~= hovered then
		allHints[str_id].status = hovered
		allHints[str_id].timer = os.clock() + (hovered and delay or 0.00)
	end

	local getContrastColor = function(col)
	    local luminance = 1 - (0.299 * col.x + 0.587 * col.y + 0.114 * col.z)
	    return luminance < 0.5 and imgui.ImVec4(0, 0, 0, 1) or imgui.ImVec4(1, 1, 1, 1)
	end

	local bg_col = imgui.GetStyle().Colors[imgui.Col.Button]
	local t_col = getContrastColor(bg_col)

	imgui.PushStyleVar(imgui.StyleVar.WindowRounding, 3)
	imgui.PushStyleColor(imgui.Col.PopupBg, bg_col)
	imgui.PushStyleColor(imgui.Col.Text, t_col)
	if show then
		local between = os.clock() - allHints[str_id].timer
		if between <= animTime then
			local s = function(f) 
				return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
			end
			local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
			imgui.PushStyleVar(imgui.StyleVar.Alpha, alpha)
			imgui.SetTooltip(hint)
			imgui.PopStyleVar()
		elseif hovered then
			imgui.SetTooltip(hint)
		end
	end
	imgui.PopStyleColor(2)
	imgui.PopStyleVar()
end

function onScriptTerminate(script, quitGame)
	if script == thisScript() then
		if marker then deleteCheckpoint(marker) end
		if checkpoing then removeBlip(checkpoint) end

		if not sampIsDialogActive() then
			showCursor(false, false)
		end
		if inicfg.save(cfg, 'Bank_Config.ini') then 
			log('Все настройки сохранены!')
		end
		if not noErrorDialog and not devmode then
			addBankMessage("Скрипт завершил свою работу в результате ошибки!", 0xAA3333)
		end
	end
end

function isSkinBad(id)
	local bad_skins = { 63, 64, 75, 77, 78, 79, 87, 134, 135, 136, 137, 152, 178, 200, 212, 230, 237, 239, 244, 246, 252, 256, 257 }
	for i, skin in ipairs(bad_skins) do
		if skin == id then
			return true
		end
	end
	return false
end

function isUniformWearing()
	local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED) 
	if sampGetPlayerColor(id) == cfg.main.bank_color then 
		return true
	end
	return false
end

function system_credit()
	if imgui.BeginPopupModal(u8("Система кредитования"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.InvisibleButton('##widewindowSC', imgui.ImVec2(400, 1))
		local credits = io.open("moonloader/BHelper/Кредитование.txt", "r+")
		for line in credits:lines() do
			imgui.CenterTextColoredRGB(line)
		end
		credits:close()
		imgui.Separator()
		imgui.CenterTextColoredRGB('{464646}> Редактировать файл <')
		imgui.Hint('openpathkredit', u8('Нажмите что бы открыть файл:\n' .. getWorkingDirectory() .. '\\BHelper\\Кредитование.txt'))
		if imgui.IsItemClicked() then
			os.execute('explorer '..getWorkingDirectory()..'\\BHelper\\Кредитование.txt')
		end
		imgui.Spacing()
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 80) / 2)
		if imgui.Button(u8("Понятно##Кредитование"), imgui.ImVec2(80, 20)) then
			imgui.CloseCurrentPopup()
		end

	imgui.EndPopup()
	end
end 

function system_cadr()
	if imgui.BeginPopupModal(u8("Кадровая система"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then

		local cadrsys = io.open("moonloader/BHelper/Кадровая система.txt", "r+")
		for line in cadrsys:lines() do
			imgui.TextColoredRGB(line)
		end
		cadrsys:close()
		imgui.Separator()
		imgui.CenterTextColoredRGB('{464646}> Редактировать файл <')
		imgui.Hint('cardsystempath', u8('Нажмите что бы открыть файл:\n' .. getWorkingDirectory() .. '\\BHelper\\Кадровая система.txt'))
		if imgui.IsItemClicked() then
			os.execute('explorer '..getWorkingDirectory()..'\\BHelper\\Кадровая система.txt')
		end
		imgui.Spacing()
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 80) / 2)
		if imgui.Button(u8("Понятно##Кадровая"), imgui.ImVec2(80, 20)) then
			imgui.CloseCurrentPopup()
		end

	imgui.EndPopup()
	end
end 

function system_uprank()
	if imgui.BeginPopupModal(u8("Единая система повышения"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		
		local file = io.open("moonloader/BHelper/Система повышения.txt", "r+")
		for line in file:lines() do
			imgui.TextColoredRGB(line)
		end
		file:close()
		imgui.Separator()
		imgui.CenterTextColoredRGB('{464646}> Редактировать файл <')
		imgui.Hint('prosystematization', u8('Нажмите что бы открыть файл:\n' .. getWorkingDirectory() .. '\\BHelper\\Система повышения.txt'))
		if imgui.IsItemClicked() then
			os.execute('explorer '..getWorkingDirectory()..'\\BHelper\\Система повышения.txt')
		end
		imgui.Spacing()
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 80) / 2)
		if imgui.Button(u8("Понятно##Promotion"), imgui.ImVec2(80, 20)) then
			imgui.CloseCurrentPopup()
		end

	imgui.EndPopup()
	end
end

local posts = {
	["КОЛЬТ - 2"]   = {x = -2693.7869, y = 797.9387, z = 1500},
	["ВАГА - 2"]    = {x = -2693.7881, y = 794.1193, z = 1500},
	["СТУП - 4"]    = {x = -2687.8120, y = 806.7342, z = 1500},
	["КОР - 5"]     = {x = -2667.4160, y = 789.8926, z = 1500},
	["КАЗНА"]       = {x = -2694.0479, y = 809.4982, z = 1500},
}

function post()
	if imgui.BeginPopupModal(u8("Расположение постов"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		for post, coord in pairs(posts) do
			if imgui.Button(u8(post), imgui.ImVec2(250, 30)) then
				if getCharActiveInterior(PLAYER_PED) ~= 0 or devmode then
					setMarker(1, coord.x, coord.y, coord.z, 1, 0xFFFF0000)
					addBankMessage('Направляйтесь на установленный маркер')
					imgui.CloseCurrentPopup()
					bank:switch()
				else
					addBankMessage('Работает только в интерьере!')
				end
			end
		end
		
		if imgui.MainButton(u8("Форма доклада"), imgui.ImVec2(250, 30)) then
			sampSetChatInputEnabled(true)
			sampSetChatInputText("/r Докладывает: {my_name} | Пост:  | Состояние: Стабильное")
			sampSetChatInputCursor(34, 34)
			addBankMessage('Форма скопирована в буфер обмена, а так же выведена в поле чата')
			addBankMessage('Тег {M}{my_name}{W} автоматически замениться на ваш ник при отправке')
			addBankMessage('Для быстрого использования можете просто ввести в чат !пост (не отправляя)')
			setClipboardText(u8:decode("/r Докладывает {my_name} | Пост: [ВАШ ПОСТ] | Состояние: Стабильное"))
			imgui.CloseCurrentPopup()
			bank:switch()
		end
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 80) / 2)
		if imgui.MainButton(u8("Закрыть##Docs"), imgui.ImVec2(80, 20)) then
			imgui.CloseCurrentPopup()
		end
		imgui.EndPopup()
	end
end

function gov()
	if imgui.BeginPopupModal(u8("Планирование государственной волны"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize) then

		if hGov.v > 23 then hGov.v = 0 end
		if mGov.v > 59 then mGov.v = 0 end
		if hGov.v < 0 then hGov.v = 23 end
		if mGov.v < 0 then mGov.v = 55 end

		imgui.PushButtonRepeat(true)
		imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(1, 1))
		imgui.SetCursorPosX(30)
		if imgui.Button('+##PlusHour', imgui.ImVec2(40, 20)) then
			status_button_gov = false
			hGov.v = hGov.v + 1
		end
		imgui.SameLine(93)
		if imgui.Button('+##PlusMin', imgui.ImVec2(40, 20)) then
			status_button_gov = false 
			mGov.v = mGov.v + 5
		end

		imgui.PushFont(font[35])
		if #tostring(hGov.v) == 1 then zeroh = '0' else zeroh = '' end
		if #tostring(mGov.v) == 1 then zerom = '0' else zerom = '' end
		imgui.SetCursorPosX(27)
		imgui.TextColoredRGB(tostring(zeroh..hGov.v)..'  :  '..tostring(zerom..mGov.v))
		imgui.PopFont()

		imgui.SetCursorPosX(30)
		if imgui.Button('-##MinusHour', imgui.ImVec2(40, 20)) then
			status_button_gov = false
			hGov.v = hGov.v - 1
		end
		imgui.SameLine(93)
		if imgui.Button('-##MinusMin', imgui.ImVec2(40, 20)) then
			status_button_gov = false
			mGov.v = mGov.v - 5
		end
		imgui.PopStyleVar()
		imgui.PopButtonRepeat()

		imgui.CenterTextColoredRGB(mc..'Текст государственной волны:')
		imgui.PushItemWidth(600)
		if gosDep.v then
			imgui.TextDisabled('/d'); imgui.SameLine(40)
			imgui.InputText('##govdep1', govdep[1])
		end
		imgui.TextDisabled('/gov'); imgui.SameLine(40); imgui.InputText('##govstr1', govstr[1])
		imgui.TextDisabled('/gov'); imgui.SameLine(40); imgui.InputText('##govstr2', govstr[2])
		imgui.TextDisabled('/gov'); imgui.SameLine(40); imgui.InputText('##govstr3', govstr[3])
		if gosDep.v then
			imgui.TextDisabled('/d'); imgui.SameLine(40)
			imgui.InputText('##govdep2', govdep[2])
		end
		imgui.PopItemWidth()
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 160) / 2)
		if imgui.Button(u8'Сохранить', imgui.ImVec2(160, 20)) then
			cfg.govstr[1] = u8:decode(govstr[1].v)
			cfg.govstr[2] = u8:decode(govstr[2].v)
			cfg.govstr[3] = u8:decode(govstr[3].v)
			--
			cfg.govdep[1] = u8:decode(govdep[1].v)
			cfg.govdep[2] = u8:decode(govdep[2].v)
			inicfg.save(cfg, 'Bank_Config.ini')
			imgui.CloseCurrentPopup()
		end

		imgui.SetCursorPos(imgui.ImVec2(150, 30))
		imgui.BeginChild("##SettingsGov", imgui.ImVec2(-1, 75), true)
		imgui.ToggleButton('##gosScreen', gosScreen); imgui.SameLine()
		imgui.TextColoredRGB('Авто-Скрин после подачи')
		imgui.ToggleButton('##gosDep', gosDep); imgui.SameLine()
		imgui.TextColoredRGB('Занимать волну в /d')
		imgui.PushItemWidth(100)
		if imgui.InputInt('##delayGov', delayGov) then 
			if delayGov.v < 0 then delayGov.v = 0 end
			if delayGov.v > 10000 then delayGov.v = 10000 end
		end
		imgui.PopItemWidth()
		imgui.SameLine()
		imgui.TextColoredRGB('Задержка {565656}(?)')
		imgui.Hint('infodelaygov', u8('Задержка между сообщениями в GOV-волне\nУказывается в миллисекундах (1000 мс = 1 сек)'))
		imgui.SetCursorPos(imgui.ImVec2(300, 10))
		if not status_button_gov then 
			if tonumber(os.date("%H", os.time())) == hGov.v and tonumber(os.date("%M", os.time())) == mGov.v then
				imgui.DisableButton(u8'Включить##gov', imgui.ImVec2(-1, -1))
			else
				if imgui.GreenButton(u8'Включить##gov', imgui.ImVec2(-1, -1)) then 
					status_button_gov = true
					antiflud = true
				end
			end
		else
			if imgui.RedButton(u8'До подачи: '..getOstTime(), imgui.ImVec2(-1, -1)) then 
				status_button_gov = false
			end
		end
		imgui.EndChild()
		imgui.EndPopup()
	end
end

function getOstTime()
	local datetime = {
		year  = os.date("%Y", os.time()),
		month = os.date("%m", os.time()),
		day   = os.date("%d", os.time()),
		hour  = hGov.v,
		min   = mGov.v,
		sec   = 00
	}
	if os.time(datetime) - os.time() < 0 then
		datetime.day = os.date("%d", os.time()) + 1
		return tostring(get_timer(os.time(datetime) - os.time()))
	else
		return tostring(get_timer(os.time(datetime) - os.time()))
	end
end

function BlackListGui()
	if imgui.BeginPopupModal(u8("Чёрный список правительства"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.CenterText(u8('Вы не сможете принять в организацию игроков,\nкоторые есть в этом списке'))
		if #cfg.blacklist > 0 then
			imgui.CenterText(u8('Что-бы удалить кликните по нику дважды'), imgui.ImVec4(1.0, 0.5, 0.5, 0.7))
		end
		imgui.BeginChild("##BlakList", imgui.ImVec2(300, 250), true, imgui.WindowFlags.NoScrollbar)
		imgui.PushFont(font[15])
		if #cfg.blacklist == 0 then
			imgui.SetCursorPosY(110)
			imgui.CenterTextColoredRGB(sc .. 'Список пуст')
		end
		for i, nick in ipairs(cfg.blacklist) do
			imgui.CenterText(u8(nick))
			if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) then
				addBankMessage(string.format('Игрок {M}%s{W} удалён из чёрного списка!', nick))
				table.remove(cfg.blacklist, i)
			end
		end
		imgui.PopFont()
		imgui.EndChild()

		imgui.BeginGroup()
			imgui.PushItemWidth(200)
			imgui.InputText('##AddNewInList', blacklist)
			imgui.PopItemWidth()
			if #blacklist.v <= 0 then
				imgui.SameLine(5)
				imgui.TextColored(imgui.ImVec4(1, 1, 1, 0.2), u8"Введите никнейм")
			end
		imgui.EndGroup()
		
		imgui.SameLine(nil, 5)

		if #blacklist.v > 0 then
			if imgui.Button(u8'Добавить', imgui.ImVec2(-1, 20)) then
				table.insert(cfg.blacklist, u8:decode(tostring(blacklist.v)))
				blacklist.v = ''
			end
		else
			imgui.DisableButton(u8'Добавить', imgui.ImVec2(-1, 20))
		end

		if imgui.Button(u8("Закрыть##BlackList"), imgui.ImVec2(-1, 25)) then
			inicfg.save(cfg, 'Bank_Config.ini')
			addBankMessage('Список сохранён!')
			imgui.CloseCurrentPopup()
		end
		imgui.EndPopup()
	end
end

function binder()
	if imgui.BeginPopupModal(u8("Редактирование/Создание бинда"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.BeginChild("##EditBinder", imgui.ImVec2(500, 355), true)
			imgui.PushItemWidth(150)
			imgui.InputFloat(u8("Задержка в секундах"), binder_delay, 0.1, 1.0, 2); imgui.SameLine(); imgui.TextDisabled('(?)')
			imgui.Hint('maxdelaybinder', u8('Не больше 60 секунд!'))
			imgui.PopItemWidth()
			if binder_delay.v < 1 then
				binder_delay.v = 1
			elseif binder_delay.v > 60 then
				binder_delay.v = 60
			end

			imgui.TextWrapped(u8("Вы можете использовать локальные теги для своих биндов!"))
			imgui.SameLine(); imgui.TextDisabled(u8'(Подробнее)')
			if imgui.IsItemClicked() then
				imgui.OpenPopup(u8("Локальные Теги"))
			end
			taginfo()
			imgui.InputTextMultiline("##EditMultiline", text_binder, imgui.ImVec2(-1, 250))
			imgui.Text(u8'Название бинда (обязательно):'); imgui.SameLine()
			imgui.PushItemWidth(150)
			imgui.InputText("##binder_name", binder_name)
			imgui.PopItemWidth()
			if #binder_name.v > 0 and #text_binder.v > 0 then
				imgui.SameLine()
				if imgui.MainButton(u8("Сохранить"), imgui.ImVec2(-1, 20)) then
					if not EditOldBind then
						refresh_text = text_binder.v:gsub("\n", "~")
						table.insert(cfg.Binds_Name, binder_name.v)
						table.insert(cfg.Binds_Action, refresh_text)
						table.insert(cfg.Binds_Deleay, binder_delay.v * 1000)
						if inicfg.save(cfg, 'Bank_Config.ini') then
							addBankMessage(string.format('Бинд {M}«%s»{W} успешно добавлен!', u8:decode(binder_name.v)))
							binder_name.v, text_binder.v = '', ''
						end
						binder_open = false
						imgui.CloseCurrentPopup()
					else
						refresh_text = text_binder.v:gsub("\n", "~")
						table.insert(cfg.Binds_Name, getpos, binder_name.v)
						table.insert(cfg.Binds_Action, getpos, refresh_text)
						table.insert(cfg.Binds_Deleay, getpos, binder_delay.v * 1000)
						table.remove(cfg.Binds_Name, getpos + 1)
						table.remove(cfg.Binds_Action, getpos + 1)
						table.remove(cfg.Binds_Deleay, getpos + 1)
						if inicfg.save(cfg, 'Bank_Config.ini') then
							addBankMessage(string.format('Бинд {M}«%s»{W} успешно отредактирован!', u8:decode(binder_name.v)))
							binder_name.v, text_binder.v = '', ''
						end
						EditOldBind = false
						binder_open = false
						imgui.CloseCurrentPopup()
					end
				end
			else
				imgui.SameLine()
				imgui.DisableButton(u8("Сохранить"), imgui.ImVec2(-1, 20))
				imgui.Hint('errgrafsbinder', u8'Заполнены не все пункты!')
			end
			if imgui.Button(u8("Закрыть"), imgui.ImVec2(-1, 0)) then
				if not EditOldBind then
					if #text_binder.v == 0 then
						binder_open = false
						imgui.CloseCurrentPopup()
						binder_name.v, text_binder.v = '', ''
					else
						imgui.OpenPopup(u8("Подтвердите##AcceptCloseBinderEdit"))
					end
				else
					EditOldBind = false
					binder_open = false
					imgui.CloseCurrentPopup()
					binder_name.v, text_binder.v = '', ''
				end
			end
			if imgui.BeginPopupModal(u8("Подтвердите##AcceptCloseBinderEdit"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
				imgui.BeginChild("##AcceptCloseBinderEdit", imgui.ImVec2(300, 80), false)
				imgui.CenterTextColoredRGB('Вы уже начали что-то писать в бинде\nСохранить как черновик?')
				if imgui.MainButton(u8'Сохранить##accept', imgui.ImVec2(145, 20)) then
					imgui.CloseCurrentPopup()
					savedatamlt = true
				end
				imgui.SameLine()
				if imgui.MainButton(u8'Не сохранять##accept', imgui.ImVec2(145, 20)) then
					imgui.CloseCurrentPopup()
					nonsavedatamlt = true
				end
				if imgui.Button(u8'Вернуться назад##accept', imgui.ImVec2(-1, 20)) then
					imgui.CloseCurrentPopup()
				end
				imgui.EndChild()
				imgui.EndPopup()
			end
			if savedatamlt then 
				savedatamlt = false
				binder_open = false
				imgui.CloseCurrentPopup()
			elseif nonsavedatamlt then 
				nonsavedatamlt = false
				binder_open = false
				imgui.CloseCurrentPopup()
				binder_name.v, text_binder.v = '', ''
			end
			imgui.EndChild()
		imgui.EndPopup()
	end
end

function set_style(c)
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2

	style.WindowRounding = 10.0
	style.FrameRounding = 5.0
	style.ChildWindowRounding = 5.0
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)

	colors[clr.Text]                   = ImVec4(c['T'].x, c['T'].y, c['T'].z, 1.00);
	colors[clr.TextDisabled]           = ImVec4(c['T'].x, c['T'].y, c['T'].z, 0.50);
	colors[clr.WindowBg]               = ImVec4(c['B'].x, c['B'].y, c['B'].z, 0.95);
	colors[clr.ChildWindowBg]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.05);
	colors[clr.PopupBg]                = ImVec4(c['B'].x, c['B'].y, c['B'].z, 0.90);
	colors[clr.Border]                 = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.FrameBg]                = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.20);
	colors[clr.FrameBgHovered]         = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.50);
	colors[clr.FrameBgActive]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.TitleBg]                = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.TitleBgActive]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.90);
	colors[clr.TitleBgCollapsed]       = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.ScrollbarBg]            = ImVec4(c['B'].x, c['B'].y, c['B'].z, 0.95);
	colors[clr.ScrollbarGrab]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.ScrollbarGrabHovered]   = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.90);
	colors[clr.ScrollbarGrabActive]    = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.ComboBg]                = ImVec4(c['B'].x, c['B'].y, c['B'].z, 0.90);
	colors[clr.CheckMark]              = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.SliderGrab]             = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.SliderGrabActive]       = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.Button]                 = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.90);
	colors[clr.ButtonHovered]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.ButtonActive]           = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.60);
	colors[clr.Header]                 = ImVec4(c['E'].x, c['E'].y, c['E'].z, 1.00);
	colors[clr.HeaderHovered]          = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.90);
	colors[clr.HeaderActive]           = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.80);
	colors[clr.TextSelectedBg]         = ImVec4(c['E'].x, c['E'].y, c['E'].z, 0.60);
	colors[clr.CloseButton]            = ImVec4(c['T'].x, c['T'].y, c['T'].z, 0.20);
	colors[clr.CloseButtonHovered]     = ImVec4(c['T'].x, c['T'].y, c['T'].z, 0.30);
	colors[clr.CloseButtonActive]      = ImVec4(c['T'].x, c['T'].y, c['T'].z, 0.40);
	colors[clr.ModalWindowDarkening]   = ImVec4(c['B'].x, c['B'].y, c['B'].z, 0.05)
end

set_style(SCRIPT_STYLE.colors)

function taginfo()
	if imgui.BeginPopupModal(u8("Локальные Теги"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.CenterTextColoredRGB(sc..'Нажми на нужный тег, что бы скопировать его')
		imgui.Separator()
		if imgui.Button('{select_id}', imgui.ImVec2(120, 25)) then setClipboardText('{select_id}'); addBankMessage('Тег скопирован!') end
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает ID игрока с которым взаимодействуете')
		if imgui.Button('{select_name}', imgui.ImVec2(120, 25)) then setClipboardText('{select_name}'); addBankMessage('Тег скопирован!') end
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает NickName игрока с которым взаимодействуете')
		if imgui.Button('{my_id}', imgui.ImVec2(120, 25)) then setClipboardText('{my_id}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagmyid', u8'{my_id}\n - '..select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает ваш ID')
		if imgui.Button('{my_name}', imgui.ImVec2(120, 25)) then setClipboardText('{my_name}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagmyname', u8'{my_name}\n - '..rpNick(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает ваш NickName')
		if imgui.Button('{closest_id}', imgui.ImVec2(120, 25)) then setClipboardText('{closest_id}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('taglosestid', u8'Рядом со мной стоит человек с бейджиком "{closest_id}"\n - Рядом со мной стоит человек с бейджиком "228"')
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает ID ближайшего к вам игрока')
		if imgui.Button('{closest_name}', imgui.ImVec2(120, 25)) then setClipboardText('{closest_name}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagclosestname', u8'Рядом со мной стоит {closest_name}\n - Рядом со мной стоит Jeffy_Cosmo')
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает NickName ближайшего к вам игрока')
		if imgui.Button('{time}', imgui.ImVec2(120, 25)) then setClipboardText('{time}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagtime', u8'/do На часах {time_s}\n - /do На часах '..os.date("%H:%M", os.time()))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Текущее время ( чч:мм )')
		if imgui.Button('{time_s}', imgui.ImVec2(120, 25)) then setClipboardText('{time_s}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagtimes', u8'/do На часах {time_s}\n - /do На часах '..os.date("%H:%M:%S", os.time()))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Текущее время ( чч:мм:сс )')
		if imgui.Button('{rank}', imgui.ImVec2(120, 25)) then setClipboardText('{rank}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagrank', u8('Моя должность - {rank}\n - Моя должность - '..cfg.nameRank[cfg.main.rank]))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Название вашего текущего ранга')
		if imgui.Button('{score}', imgui.ImVec2(120, 25)) then setClipboardText('{rank}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagscore', u8('Я проживаю в штате уже {score} лет\n - Я проживаю в штате уже '..sampGetPlayerScore(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))..' лет'))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Ваш игровой уровень')
		if imgui.Button('{screen}', imgui.ImVec2(120, 25)) then setClipboardText('{screen}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagscreen', u8('/giverank 123 5 {screen}\n - Отправит команду: /giverank 123 5, а затем сделает скриншот'))
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Делает скриншот')
		if imgui.Button('{sex:text1|text2}', imgui.ImVec2(120, 25)) then setClipboardText('{sex:text1|text2}'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagsex', u8'/me {sex:взял|взяла} ручку со стола\n - Если мужской пол: /me взял..\n - Если женский пол: /me взяла')
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Вернёт текст в зависимости от вашего пола')
		if imgui.Button(u8'@[ID игрока]', imgui.ImVec2(120, 25)) then setClipboardText('@[ID]'); addBankMessage('Тег скопирован!') end
		imgui.Hint('tagmention', u8'/fam @228 продаешь машину?\n - /fam Jeffy Cosmo, продаешь машину?')
		imgui.SameLine(); imgui.TextColoredRGB(mc..'Получает NickName игрока указанного ID на сервере')
		imgui.Separator()
		if imgui.Button(u8'Вернуться назад##tag', imgui.ImVec2(-1, 30)) then
			imgui.CloseCurrentPopup()
		end
		imgui.EndPopup()
	end
end

function sampGetPlayerIdOnTargetKey(key)
	local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)
	if result then
		if isKeyJustPressed(key) then
			return sampGetPlayerIdByCharHandle(ped)
		end
	end
	return false
end

function play_bind(num)
	lua_thread.create(function()
		if num ~= -1 then
			for bp in cfg.Binds_Action[num]:gmatch('[^~]+') do
				sampSendChat(u8:decode(tostring(bp)))
				wait(cfg.Binds_Deleay[num])
			end
			num = -1
		end
	end)
end

function frpbat()
	local weapon = getCurrentCharWeapon(PLAYER_PED)
	if weapon == 3 and not rp_check then 
		sampSendChat(cfg.main.rpbat_true)
		rp_check = true
	elseif weapon ~= 3 and rp_check then
		sampSendChat(cfg.main.rpbat_false)
		rp_check = false
	end
end

function getPlayerIdByNickname(name)
	for i = 0, sampGetMaxPlayerId(false) do
		if sampIsPlayerConnected(i) or i == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) then
			if sampGetPlayerNickname(i):lower() == tostring(name):lower() then return i end
		end
	end
end

function imgui.CenterTextColoredRGB(text)
	local width = imgui.GetWindowWidth()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local ImVec4 = imgui.ImVec4

	local getcolor = function(color)
		if color:sub(1, 6):upper() == 'SSSSSS' then
			local r, g, b = colors[1].x, colors[1].y, colors[1].z
			local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
			return ImVec4(r, g, b, a / 255)
		end
		local color = type(color) == 'string' and tonumber(color, 16) or color
		if type(color) ~= 'number' then return end
		local r, g, b, a = explode_argb(color)
		return imgui.ImColor(r, g, b, a):GetVec4()
	end

	local render_text = function(text_)
		for w in text_:gmatch('[^\r\n]+') do
			local textsize = w:gsub('{.-}', '')
			local text_width = imgui.CalcTextSize(u8(textsize))
			imgui.SetCursorPosX( width / 2 - text_width .x / 2 )
			local text, colors_, m = {}, {}, 1
			w = w:gsub('{(......)}', '{%1FF}')
			while w:find('{........}') do
				local n, k = w:find('{........}')
				local color = getcolor(w:sub(n + 1, k - 1))
				if color then
					text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
					colors_[#colors_ + 1] = color
					m = n
				end
				w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
			end
			if text[0] then
				for i = 0, #text do
					imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
					imgui.SameLine(nil, 0)
				end
				imgui.NewLine()
			else
				imgui.Text(u8(w))
			end
		end
	end
	render_text(text)
end

function se.onSendChat(msg)
	if msg:find('{select_id}') then
		if actionId ~= nil then
			msg = msg:gsub('{select_id}', actionId)
		else
			addBankMessage('Вы ещё не отметили игрока для тега {M}{select_id}')
			return false
		end
	end

	if msg:find('{select_name}') then
		if actionId ~= nil then
			msg = msg:gsub('{select_name}', rpNick(actionId))
			return { msg }
		else
			addBankMessage('Вы ещё не отметили игрока для тега {M}{select_name}')
			return false
		end
	end

	if msg:find('{my_id}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		msg = msg:gsub('{my_id}', tostring(id))
	end

	if msg:find('{my_name}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		msg = msg:gsub('{my_name}', rpNick(id))
	end

	if msg:find('{hello}') then
		local result = "Здравствуйте"
		local H = tonumber(os.date("%H", os.time())) + cfg.main.time_offset

		if H >= 4 and H <= 11 then
			result = "Доброе утро"
		elseif H >= 12 and H <= 16 then
			result = "Добрый день"
		elseif H >= 17 and H <= 20 then
			result = "Добрый вечер"
		elseif H >= 21 or H <= 3 then
			result = "Доброй ночи"
		end

		msg = msg:gsub('{hello}', result)
	end

	if msg:find('{closest_id}') then
		local result, id = getClosestPlayerId()
		if result then
			msg = msg:gsub('{closest_id}', tostring(id))
		else
			addBankMessage('В вашем радиусе нет игроков для применения тега {M}{closest_id}')
			return false
		end
	end

	if msg:find('{closest_name}') then
		local result, id = getClosestPlayerId()
		if result then
			msg = msg:gsub('{closest_name}', rpNick(id))
		else
			addBankMessage('В вашем радиусе нет игроков для применения тега {M}{closest_name}')
			return false
		end
	end

	if msg:find('@%d+') then
		local id = msg:match('@(%d+)')
		if id and sampIsPlayerConnected(id) then
			local nickname = rpNick(id)
			msg = msg:gsub('@%d+', nickname)
		else
			addBankMessage('Игрока с таким ID на сервере нет!')
			return false
		end
	end

	if msg:find('{time}') then
		msg = msg:gsub('{time}', os.date("%H:%M", os.time()))
	end

	if msg:find('{time_s}') then
		msg = msg:gsub('{time_s}', os.date("%H:%M:%S", os.time()))
	end

	if msg:find('{rank}') then
		msg = msg:gsub('{rank}', cfg.nameRank[cfg.main.rank])
	end

	if msg:find('{score}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		msg = msg:gsub('{score}', sampGetPlayerScore(id))
	end

	for tag in string.gmatch(msg, "{sex:[^%p]+|[^%p]+}") do
		local result = { msg:match("{sex:([^%p]+)|([^%p]+)}") }
		msg = msg:gsub(tag, result[cfg.main.sex], 1)
	end

	if msg:find('{screen}') then
		lua_thread.create(function()
			wait(0) sampSendChat('/time')
			wait(500) takeScreenshot()
		end)
		msg = msg:gsub('{screen}', '')
		if #msg <= 0 then
			return false
		end
	end

	if cfg.main.accent_status then
		if #msg > 0 and not msg:find("^[%p]+$") then
			msg = string.format('%s %s', cfg.main.accent, msg)
		end
	end

	return { msg }
end

function se.onSendCommand(cmd)
	if cmd:find('{select_id}') then
		if actionId ~= nil then
			cmd = cmd:gsub('{select_id}', actionId)
		else
			addBankMessage('Вы ещё не отметили игрока для тега {M}{select_id}')
			return false
		end
	end

	if cmd:find('{select_name}') then
		if actionId ~= nil then
			cmd = cmd:gsub('{select_name}', rpNick(actionId))
		else
			addBankMessage('Вы ещё не отметили игрока для тега {M}{select_name}')
			return false
		end
	end

	if cmd:find('{my_id}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		cmd = cmd:gsub('{my_id}', tostring(id))
	end

	if cmd:find('{my_name}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		cmd = cmd:gsub('{my_name}', rpNick(id))
	end

	if cmd:find('{hello}') then
		local result = "Здравствуйте"
		local H = tonumber(os.date("%H", os.time()))

		if H >= 4 and H <= 11 then
			result = "Доброе утро"
		elseif H >= 12 and H <= 16 then
			result = "Добрый день"
		elseif H >= 17 and H <= 20 then
			result = "Добрый вечер"
		elseif H >= 21 or H <= 3 then
			result = "Доброй ночи"
		end

		cmd = cmd:gsub('{hello}', result)
	end

	if cmd:find('{closest_id}') then
		local result, id = getClosestPlayerId()
		if result then
			cmd = cmd:gsub('{closest_id}', tostring(id))
		else
			addBankMessage('В вашем радиусе нет игроков для применения тега {M}{closest_id}')
			return false
		end
	end

	if cmd:find('{closest_name}') then
		local result, id = getClosestPlayerId()
		if result then
			cmd = cmd:gsub('{closest_name}', rpNick(id))
		else
			addBankMessage('В вашем радиусе нет игроков для применения тега {M}{closest_name}')
			return false
		end
	end

	if cmd:find('@%d+') then
		local id = cmd:match('@(%d+)')
		if id and sampIsPlayerConnected(id) then
			local nickname = rpNick(id)
			cmd = cmd:gsub('@%d+', nickname)
		else
			addBankMessage('Игрока с таким ID на сервере нет!')
			return false
		end
	end

	if cmd:find('{time}') then
		cmd = cmd:gsub('{time}', os.date("%H:%M", os.time()))
	end

	if cmd:find('{time_s}') then
		cmd = cmd:gsub('{time_s}', os.date("%H:%M:%S", os.time()))
	end

	if cmd:find('{rank}') then
		cmd = cmd:gsub('{rank}', cfg.nameRank[cfg.main.rank])
	end

	if cmd:find('{score}') then
		local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
		cmd = cmd:gsub('{score}', sampGetPlayerScore(id))
	end

	for tag in string.gmatch(cmd, "{sex:[^%p]+|[^%p]+}") do
		local result = { cmd:match("{sex:([^%p]+)|([^%p]+)}") }
		cmd = cmd:gsub(tag, result[cfg.main.sex], 1)
	end

	if cmd:find('{screen}') then
		lua_thread.create(function()
			wait(0) sampSendChat('/time')
			wait(500) takeScreenshot()
		end)
		cmd = cmd:gsub('{screen}', '')
	end

	if cfg.main.accent_status then
		local text = cmd:match('^/[cs] (.+)')
		if text ~= nil then
			cmd = cmd:gsub(text, string.format('%s %s', cfg.main.accent, text))
		end
	end

	if cmd:match('^/jobprogress %d+$') then
		local id = cmd:match('/jobprogress (%d+)$')
		local result, dist = getDistBetweenPlayers(id)
		if result and dist < 5 then
			sampAddChatMessage('[Информация] {FFFFFF}Вы показали свою {4EB857}трудовую успеваемость{FFFFFF} игроку '..rpNick(id)..'!', 0x4EB857)
		end
	end

	if cmd:match('^/premium %d+ %d+ %d+') and cfg.main.rank >= 9 then
		local rank = cmd:match('^/premium %d+ %d+ (%d+)')
		if rank then
			rank = tonumber(rank)
			if cfg.nameRank[rank] ~= nil and temp_prem ~= cfg.nameRank[rank] then
				temp_prem = cfg.nameRank[rank]
				sampSendChat('/rb Премия для сотрудников на должности ' .. temp_prem)
				sampSendChat(cmd)
				return false
			end
		end
	end

	return { cmd }
end

local bank_pickups_pos = {
	{ x = -2683, y = 807 },
	{ x = -2676, y = 807 },
	{ x = -2668, y = 807 },
	{ x = -2666, y = 805 },
	{ x = -2666, y = 799 },
	{ x = -2666, y = 792 }
}

function onSendPacket(id, bs)
	if id == 207 then -- onSendPlayerSync
		local Packet_ID = raknetBitStreamReadInt8(bs)
		local lrKey = raknetBitStreamReadInt16(bs)
		local udKey = raknetBitStreamReadInt16(bs)
		local keys = raknetBitStreamReadInt16(bs)
		local X = raknetBitStreamReadFloat(bs)
		local Y = raknetBitStreamReadFloat(bs)
		local Z = raknetBitStreamReadFloat(bs)
		local quat_w = raknetBitStreamReadFloat(bs)
		local quat_x = raknetBitStreamReadFloat(bs)
		local quat_y = raknetBitStreamReadFloat(bs)
		local quat_z = raknetBitStreamReadFloat(bs)
		local health = raknetBitStreamReadInt8(bs)
		local armour = raknetBitStreamReadInt8(bs)
		local additional_key = raknetBitStreamReadInt8(bs)
		local weapon_id = raknetBitStreamReadInt8(bs)
		local special_action = raknetBitStreamReadInt8(bs)
		local velocity_x = raknetBitStreamReadFloat(bs)
		local velocity_y = raknetBitStreamReadFloat(bs)
		local velocity_z = raknetBitStreamReadFloat(bs)
		local surfing_offsets_x = raknetBitStreamReadFloat(bs)
		local surfing_offsets_y = raknetBitStreamReadFloat(bs)
		local surfing_offsets_z = raknetBitStreamReadFloat(bs)
		local surfing_vehicle_id = raknetBitStreamReadInt16(bs)
		local animation_id = raknetBitStreamReadInt16(bs)
		local animation_flags = raknetBitStreamReadInt16(bs)

		if additional_key == 128 and getActiveInterior() ~= 0 then -- Pressed N
			local pX, pY, pZ = getCharCoordinates(PLAYER_PED)
			for id = 0, 4095 do
				local pickup = sampGetPickupHandleBySampId(id)
				if pickup ~= 0 then
					local x, y, z = getPickupCoordinates(pickup)
					for i, pos in ipairs(bank_pickups_pos) do
						if pos.x == math.modf(x) and pos.y == math.modf(y) then
							if getDistanceBetweenCoords2d(pX, pY, pos.x, pos.y) <= 3 then
								sampSendPickedUpPickup(id)
								return
							end
						end
					end
				end
			end
		end
	end
end

function se.onSetSpawnInfo(team, skin, _, pos, rot, weapons, ammo)
	if CONNECTED_TO_ARIZONA then
		CONNECTED_TO_ARIZONA = false
		local x = math.modf(pos.x)
		local y = math.modf(pos.y)
		local z = math.modf(pos.z)

		if x == -2674 and y == 819 and z == 1500 then
			if cfg.main.auto_uniform and not isUniformWearing() then
				local p = unform_pickup_pos
				local timer = os.clock()

				lua_thread.create(function ()	
					repeat 
						if os.clock() - timer >= 5.00 then
							log("Не удалось автоматически надеть форму, вышло время ожидания")
							return
						end
						wait(0)
					until isAnyPickupAtCoords(p[1], p[2], p[3])

					for id = 0, 4095 do
						local pickup = sampGetPickupHandleBySampId(id)
						if pickup ~= 0 then 
							local x, y, z = getPickupCoordinates(pickup)
							if x == p[1] and y == p[2] and z == p[3] then
								await["uniform"] = os.clock()
								sampSendPickedUpPickup(id)
								break
							end
						end
					end
				end)
			end

			if cfg.main.auto_stick then
				local p = stick_pickup_pos
				local timer = os.clock()

				lua_thread.create(function ()	
					repeat 
						if os.clock() - timer >= 5.00 then
							log("Не удалось автоматически взять дубинку, вышло время ожидания")
							return
						end
						wait(0)
					until isAnyPickupAtCoords(p[1], p[2], p[3])

					for id = 0, 4095 do
						local pickup = sampGetPickupHandleBySampId(id)
						if pickup ~= 0 then 
							local x, y, z = getPickupCoordinates(pickup)
							if x == p[1] and y == p[2] and z == p[3] then
								sampSendPickedUpPickup(id)
								break
							end
						end
					end
				end)
			end
		end
	end
end

function getClosestPlayerId()
	local temp = {}
	local tPeds = getAllChars()
	local me = {getCharCoordinates(PLAYER_PED)}
	for i, ped in ipairs(tPeds) do 
		local result, id = sampGetPlayerIdByCharHandle(ped)
		if ped ~= PLAYER_PED and result then
			local pl = {getCharCoordinates(ped)}
			local dist = getDistanceBetweenCoords3d(me[1], me[2], me[3], pl[1], pl[2], pl[3])
			temp[#temp + 1] = { dist, id }
		end
	end
	if #temp > 0 then
		table.sort(temp, function(a, b) return a[1] < b[1] end)
		return true, temp[1][2]
	end
	return false
end

function get_timer(time)
	return string.format("%s:%s:%s", string.format("%s%s", (tonumber(os.date("%H", time)) < tonumber(os.date("%H", 0)) and 24 + tonumber(os.date("%H", time)) - tonumber(os.date("%H", 0)) or tonumber(os.date("%H", time)) - tonumber(os.date("%H", 0))) < 10 and 0 or "", tonumber(os.date("%H", time)) < tonumber(os.date("%H", 0)) and 24 + tonumber(os.date("%H", time)) - tonumber(os.date("%H", 0)) or tonumber(os.date("%H", time)) - tonumber(os.date("%H", 0))), os.date("%M", time), os.date("%S", time))
end

function getDistBetweenPlayers(playerId)
	if playerId == nil then return false end
	local result, ped = sampGetCharHandleBySampPlayerId(playerId)
	if result then
		local me = {getCharCoordinates(PLAYER_PED)}
		local pl = {getCharCoordinates(ped)}
		local dist = getDistanceBetweenCoords3d(me[1], me[2], me[3], pl[1], pl[2], pl[3])
		return true, dist
	end
	return false
end

function setMarker(type, x, y, z, radius, color)
	deleteCheckpoint(marker)
	removeBlip(checkpoint)
	checkpoint = addBlipForCoord(x, y, z)
	marker = createCheckpoint(type, x, y, z, 1, 1, 1, radius)
	changeBlipColour(checkpoint, color)
	lua_thread.create(function()
	repeat
		wait(0)
		local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
		until getDistanceBetweenCoords3d(x, y, z, x1, y1, z1) < radius or not doesBlipExist(checkpoint)
		deleteCheckpoint(marker)
		removeBlip(checkpoint)
		addOneOffSound(0, 0, 0, 1149)
	end)
end

function imgui.TextColoredRGB(text)
	local style = imgui.GetStyle()
	local colors = style.Colors
	local ImVec4 = imgui.ImVec4

	local getcolor = function(color)
		if color:sub(1, 6):upper() == 'SSSSSS' then
			local r, g, b = colors[1].x, colors[1].y, colors[1].z
			local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
			return ImVec4(r, g, b, a / 255)
		end
		local color = type(color) == 'string' and tonumber(color, 16) or color
		if type(color) ~= 'number' then return end
		local r, g, b, a = explode_argb(color)
		return imgui.ImColor(r, g, b, a):GetVec4()
	end

	local render_text = function(text_)
		for w in text_:gmatch('[^\r\n]+') do
			local text, colors_, m = {}, {}, 1
			w = w:gsub('{(......)}', '{%1FF}')
			while w:find('{........}') do
				local n, k = w:find('{........}')
				local color = getcolor(w:sub(n + 1, k - 1))
				if color then
					text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
					colors_[#colors_ + 1] = color
					m = n
				end
				w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
			end
			if text[0] then
				for i = 0, #text do

					imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
					imgui.SameLine(nil, 0)
				end
				imgui.NewLine()
			else imgui.Text(u8(w)) end
		end
	end

	render_text(text)
end

function Spinner(radius, thickness, color)
    local style = imgui.GetStyle()
    local pos = imgui.GetCursorScreenPos()
    local size = imgui.ImVec2(radius * 2, (radius + style.FramePadding.y) * 2)
    
    imgui.Dummy(imgui.ImVec2(size.x + style.ItemSpacing.x, size.y))

    local DrawList = imgui.GetWindowDrawList()
    DrawList:PathClear()
    
    local num_segments = 30
    local start = math.abs(math.sin(imgui.GetTime() * 1.8) * (num_segments - 5))
    
    local a_min = 3.14 * 2.0 * start / num_segments
    local a_max = 3.14 * 2.0 * (num_segments - 3) / num_segments

    local centre = imgui.ImVec2(pos.x + radius, pos.y + radius + style.FramePadding.y)
    
    for i = 0, num_segments do
        local a = a_min + (i / num_segments) * (a_max - a_min)
        DrawList:PathLineTo(imgui.ImVec2(centre.x + math.cos(a + imgui.GetTime() * 8) * radius, centre.y + math.sin(a + imgui.GetTime() * 8) * radius))
    end

    DrawList:PathStroke(color, false, thickness)
    return true
end

Button_ORIGINAL = imgui.Button
function imgui.Button(label, size, duration)
   	duration = duration or {
        1.0, -- Длительность переходов между hovered / idle
        0.3  -- Длительность анимации после нажатия
    }

    local cols = {
        default = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.Button]),
        hovered = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]),
        active  = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])
    }

    if not FBUTPOOL then FBUTPOOL = {} end
    if not FBUTPOOL[label] then
        FBUTPOOL[label] = {
            color = cols.default,
            clicked = { nil, nil },
            hovered = {
                cur = false,
                old = false,
                clock = nil,
            }
        }
    end

    if FBUTPOOL[label]['clicked'][1] and FBUTPOOL[label]['clicked'][2] then
        if os.clock() - FBUTPOOL[label]['clicked'][1] <= duration[2] then
            FBUTPOOL[label]['color'] = bringVec4To(
                FBUTPOOL[label]['color'],
                cols.active,
                FBUTPOOL[label]['clicked'][1],
                duration[2]
            )
            goto no_hovered
        end

        if os.clock() - FBUTPOOL[label]['clicked'][2] <= duration[2] then
            FBUTPOOL[label]['color'] = bringVec4To(
                FBUTPOOL[label]['color'],
                FBUTPOOL[label]['hovered']['cur'] and cols.hovered or cols.default,
                FBUTPOOL[label]['clicked'][2],
                duration[2]
            )
            goto no_hovered
        end
    end

    if FBUTPOOL[label]['hovered']['clock'] ~= nil then
        if os.clock() - FBUTPOOL[label]['hovered']['clock'] <= duration[1] then
            FBUTPOOL[label]['color'] = bringVec4To(
                FBUTPOOL[label]['color'],
                FBUTPOOL[label]['hovered']['cur'] and cols.hovered or cols.default,
                FBUTPOOL[label]['hovered']['clock'],
                duration[1]
            )
        else
            FBUTPOOL[label]['color'] = FBUTPOOL[label]['hovered']['cur'] and cols.hovered or cols.default
        end
    end

    ::no_hovered::

    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(FBUTPOOL[label]['color']))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(FBUTPOOL[label]['color']))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(FBUTPOOL[label]['color']))
    local result = Button_ORIGINAL(label, size or imgui.ImVec2(0, 0))
    imgui.PopStyleColor(4)

    if result then
        FBUTPOOL[label]['clicked'] = {
            os.clock(),
            os.clock() + duration[2]
        }
    end

    FBUTPOOL[label]['hovered']['cur'] = imgui.IsItemHovered()
    if FBUTPOOL[label]['hovered']['old'] ~= FBUTPOOL[label]['hovered']['cur'] then
        FBUTPOOL[label]['hovered']['old'] = FBUTPOOL[label]['hovered']['cur']
        FBUTPOOL[label]['hovered']['clock'] = os.clock()
    end

    return result
end

function imgui.MainButton(...)
	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.30, 0.80, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.30, 0.80, 0.90))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.30, 0.80, 0.80))
	local button = imgui.Button(...)
	imgui.PopStyleColor(3)
	return button
end

function imgui.RedButton(text, size)
	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.00, 0.00, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.40, 0.00, 0.00, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.00, 0.00, 1.00))
		local button = imgui.Button(text, size)
	imgui.PopStyleColor(3)
	return button
end

function imgui.GreenButton(text, size)
	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.50, 0.00, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.40, 0.00, 1.00))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.30, 0.00, 1.00))
		local button = imgui.Button(text, size)
	imgui.PopStyleColor(3)
	return button
end

function imgui.DisableButton(text, size)
	imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.0, 0.0, 0.0, 0.2))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.0, 0.0, 0.0, 0.2))
	imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.0, 0.0, 0.0, 0.2))
		local button = Button_ORIGINAL(text, size)
	imgui.PopStyleColor(3)
	return button
end

local orig_collheader = imgui.CollapsingHeader
function imgui.CollapsingHeader( ... )
	imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 1.0, 1.0))
	local result = orig_collheader(...)
	imgui.PopStyleColor()
	return result
end

function imgui.CloseButton(rad)
	local pos = imgui.GetCursorScreenPos()
	local poss = imgui.GetCursorPos()
	local a, b, c, d = pos.x - rad, pos.x + rad, pos.y - rad, pos.y + rad
	local e, f = poss.x - rad, poss.y - rad
	local DL = imgui.GetWindowDrawList()
	imgui.SetCursorPos(imgui.ImVec2(e, f))
	local result = imgui.InvisibleButton('##CLOSE_BUTTON', imgui.ImVec2(rad * 2, rad * 2))
	DL:AddLine(imgui.ImVec2(a, d), imgui.ImVec2(b, c), 0xFF666666, 3)
	DL:AddLine(imgui.ImVec2(b, d), imgui.ImVec2(a, c), 0xFF666666, 3)
	return result
end

function stringToLower(s)
  for i = 192, 223 do
    s = s:gsub(_G.string.char(i), _G.string.char(i + 32))
  end
  s = s:gsub(_G.string.char(168), _G.string.char(184))
  return s:lower()
end

function stringToUpper(s)
  for i = 224, 255 do
    s = s:gsub(_G.string.char(i), _G.string.char(i - 32))
  end
  s = s:gsub(_G.string.char(184), _G.string.char(168))
  return s:upper()
end

function imgui.CenterText(text, color)
	color = color or imgui.GetStyle().Colors[imgui.Col.Text]
	local width = imgui.GetWindowWidth()
	for line in text:gmatch('[^\n]+') do
		local lenght = imgui.CalcTextSize(line).x
		imgui.SetCursorPosX((width - lenght) / 2)
		imgui.TextColored(color, line)
	end
end

function join_rgb(r, g, b)
	return bit.bor(bit.bor(b, bit.lshift(g, 8)), bit.lshift(r, 16))
end

function explode_argb(argb)
	local a = bit.band(bit.rshift(argb, 24), 0xFF)
	local r = bit.band(bit.rshift(argb, 16), 0xFF)
	local g = bit.band(bit.rshift(argb, 8), 0xFF)
	local b = bit.band(argb, 0xFF)
	return a, r, g, b
end

function join_argb(a, r, g, b)
  local argb = b  -- b
  argb = bit.bor(argb, bit.lshift(g, 8))  -- g
  argb = bit.bor(argb, bit.lshift(r, 16)) -- r
  argb = bit.bor(argb, bit.lshift(a, 24)) -- a
  return argb
end

function sampSetChatInputCursor(start, finish)
	local finish = finish or start
	local start, finish = tonumber(start), tonumber(finish)
	local chatInfoPtr = sampGetInputInfoPtr()
	local chatBoxInfo = getStructElement(chatInfoPtr, 0x8, 4)
	memory.setint8(chatBoxInfo + 0x11E, start)
	memory.setint8(chatBoxInfo + 0x119, finish)
	return true
end

function checkServer(address)
	local servers = {
		["Phoenix"] 	= "185.169.134.3",
		["Tucson"] 		= "185.169.134.4",
		["Scottdale"] 	= "185.169.134.43",
		["Chandler"] 	= "185.169.134.44", 
		["Brainburg"] 	= "185.169.134.45",
		["Saint Rose"] 	= "185.169.134.5",
		["Mesa"] 		= "185.169.134.59",
		["Red Rock"] 	= "185.169.134.61",
		["Yuma"] 		= "185.169.134.107",
		["Surprise"] 	= "185.169.134.109",
		["Prescott"] 	= "185.169.134.166",
		["Glendale"] 	= "185.169.134.171",
		["Kingman"] 	= "185.169.134.172",
		["Winslow"] 	= "185.169.134.173",
		["Payson"] 		= "185.169.134.174",
		["Gilbert"] 	= "80.66.82.191",
		["Show-Low"] 	= "80.66.82.190",
		["Casa Grande"] = "80.66.82.188",
		["Page"] 		= "80.66.82.168",
		["Sun City"]	= "80.66.82.159"
	}
	for name, ip in pairs(servers) do
		if address == ip then
			log("Проверка на сервер: {33AA33}Успешно [ ".. name .. " ]", "Подготовка")
			return true
		end
	end
	log("Проверка на сервер: {FF1010}Неудачно [ " .. address .. " ]", "Подготовка")
	return false
end

function sumFormat(sum)
	sum = tostring(sum)
    if sum and string.len(sum) > 3 then
        local b, e = ('%d'):format(sum):gsub('^%-', '')
        local c = b:reverse():gsub('%d%d%d', '%1.')
        local d = c:reverse():gsub('^%.', '')
        return (e == 1 and '-' or '')..d
    end
    return sum
end

function getNumberOfKassa()
	local p = {
		[1] = {x = -2665.1, y = 792.4, z = 1500.9},
		[2] = {x = -2665.1, y = 799.3, z = 1500.9},
		[3] = {x = -2665.1, y = 805.8, z = 1500.9},
		[4] = {x = -2668.9, y = 808.9, z = 1500.9},
		[5] = {x = -2676.3, y = 808.9, z = 1500.9},
		[6] = {x = -2683.8, y = 808.9, z = 1500.9}
	}
	for i = 1, 6 do
		local x, y, z = getCharCoordinates(PLAYER_PED)
		local dist = getDistanceBetweenCoords3d(x, y, z, p[i].x, p[i].y, p[i].z)
		if dist <= 3 then
			return true, i
		end
	end
	return false
end

function imgui.Repository(nameScript, nameLua, discription, cmds, d_Link, bh_Link)
	if imgui.Button(u8(nameScript), imgui.ImVec2(280, 30)) then 
		if not doesFileExist(getWorkingDirectory()..'\\'..nameLua) then
			downloadUrlToFile(d_Link, getWorkingDirectory()..'\\'..nameLua, function (id, status, p1, p2)
				if status == dlstatus.STATUSEX_ENDDOWNLOAD then
					addBankMessage(string.format("Скрипт %s загружен! Подключаю..", nameScript))
					addBankMessage(string.format("Команда активации: {M}%s", cmds))
					script.load(getWorkingDirectory()..'\\'..nameLua)
				end
			end)
		else
			addBankMessage('У вас уже установлен этот скрипт!')
			imgui.OpenPopup(u8"Удалить скрипт?##repository"..nameScript)
		end
	end
	imgui.Hint('repositoryact'..nameScript, u8(discription..'\n\nКоманда активации: '..cmds))
	imgui.SameLine()
	if bh_Link then
		if imgui.Button(fa.ICON_FA_LINK..'##'..nameScript, imgui.ImVec2(-1, 30)) then os.execute('explorer '..bh_Link) end
		imgui.Hint('repositorylink'..nameScript, u8'Полная тема скрипта на blast.hk')
	else
		imgui.DisableButton(fa.ICON_FA_BAN, imgui.ImVec2(-1, 30))
		imgui.Hint('repositorynolink'..nameScript, u8'Этого скрипта ещё нет на blast.hk')
	end

	if imgui.BeginPopupModal(u8"Удалить скрипт?##repository"..nameScript, _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.CenterTextColoredRGB(sc .. nameScript .. '\nУ вас уже установлен скрипт\nВы хотите удалить его?')

		if imgui.RedButton(u8'Удалить##repository', imgui.ImVec2(150, 30)) then
			local script = script.find(nameLua)
			if script then script:unload() end
			os.remove(getWorkingDirectory()..'\\'..nameLua)
			addBankMessage('Скрипт удалён!')
			imgui.CloseCurrentPopup()
		end
		imgui.SameLine()
		if imgui.Button(u8'Отменить##repository', imgui.ImVec2(150, 30)) then 
			imgui.CloseCurrentPopup()
		end
		imgui.EndPopup()
	end
end

function autoupdate(json_url)
	local dlstatus = require('moonloader').download_status
	local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
	if doesFileExist(json) then os.remove(json) end
	log('Начало проверки обновления', "Подготовка")
	downloadUrlToFile(json_url, json,
		function(id, status, p1, p2)
			if status == dlstatus.STATUSEX_ENDDOWNLOAD then
			if doesFileExist(json) then
				local f = io.open(json, 'r')
				if f then
					local info = decodeJson(f:read('*a'))
					updatelink = info.updateurl
					updateversion = info.latest
					f:close()
					os.remove(json)
					if updateversion ~= thisScript().version then
						lua_thread.create(function()
							local dlstatus = require('moonloader').download_status
							local color = -1
							log('Найдено обновление: '..thisScript().version..' -> '..updateversion..'! Загрузка..', "Обновление")
							wait(250)
							downloadUrlToFile(updatelink, thisScript().path,
								function(id3, status1, p13, p23)
									if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
									elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
										log('Загрузка окончена. Скрипт обновлен на версию '..mc..updateversion, "Обновление")
										goupdatestatus = true

										local v1 = updateversion:match('^(%d+)')
										local v2 = thisScript().version:match('^(%d+)')
										if v1 ~= v2 then
											cfg.main.infoupdate = true
										end

										reload(false)
									end
									if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
										if goupdatestatus == nil then
											log('Скрипт не смог обновится на версию '..updateversion, "Ошибка")
											update = false
										end
									end
								end
							)   
						end)
					else
						update = false
						log('Версии совпадают. Обновлений нет', "Подготовка")
						addBankMessage('Обновлений не найдено')
					end
				end
			else
				log('Не удалось получить JSON таблицу', "Ошибка")
				addBankMessage('Обновление не удалось')
				update = false
			end
		end
	end)
	while update ~= false do wait(100) end
end

function takeAutoScreen()
	if autoF8.v then
		hook_time = true
		sampSendChat('/time')
	end
end

function isPlayerOnBlacklist(player)
	for _, nick in ipairs(cfg.blacklist) do
		if nick == player then
			return true
		end
	end
	return false
end

function se.onDisplayGameText(style, time, text)
	if text:find('Played') and style == 1 and time == 4000 then
		local H1 = tonumber(os.date("%H", os.time()))
		local H2 = tonumber(string.match(text, "~w~(%d+):%d+~n~"))
		if H1 and H2 then
			cfg.main.time_offset = H2 - H1
		end

		if hook_time then
			hook_time = false
			lua_thread.create(function()
				wait(500)
				takeScreenshot()
			end)
		end
	end
end

function unload(show_error)
	lua_thread.create(function()
		noErrorDialog = not show_error
		wait(100)
		thisScript():unload()
	end)
end

function reload(show_error)
	lua_thread.create(function()
		noErrorDialog = not show_error
		wait(100)
		thisScript():reload()
	end)
end

function takeScreenshot()
	local base = getModuleHandle("samp.dll")
	local vSAMP = getGameGlobal(707) <= 21 and "R1" or "R3"
	local offset = { ["R1"] = 0x70FC0, ["R3"] = 0x74EB0 }
	ffi.cast("void (__cdecl *)(void)", base + offset[vSAMP])()
end

function addBankMessage(message, color)
	message = message:gsub('{M}', mc)
	message = message:gsub('{W}', wc)
	message = message:gsub('{S}', sc)
	sampAddChatMessage(tag .. message, color or mcx)
end

function imgui.CenterText(text, color)
	color = color or imgui.GetStyle().Colors[imgui.Col.Text]
	local width = imgui.GetWindowWidth()
	for line in text:gmatch('[^\n]+') do
		local lenght = imgui.CalcTextSize(line).x
		imgui.SetCursorPosX((width - lenght) / 2)
		imgui.TextColored(color, line)
	end
end

function Window_Info_Update()
	if infoupdate.alpha > 0.00 then 
		local xx, yy = getScreenResolution()
		imgui.SetNextWindowSize(imgui.ImVec2(xx / 1.5, yy / 1.5), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(xx / 2, yy / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.Begin(u8'##CHANGELOG', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar)
		
		imgui.SetCursorPos(imgui.ImVec2(10, 10))
		imgui.BeginGroup()
		imgui.PushFont(font[35])
		imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.ButtonHovered], fa.ICON_FA_NEWSPAPER .. u8' Список изменений')
		imgui.PopFont()
		imgui.SetCursorPos(imgui.ImVec2( imgui.GetWindowWidth() - 30, 26 ))
		if imgui.CloseButton(7) then
			infoupdate:switch()
		end
		imgui.EndGroup()
		imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
		imgui.Separator()
		imgui.PopStyleVar()

		local p = imgui.GetCursorScreenPos()
		local DL = imgui.GetWindowDrawList()
		local offset = 40

		local col_bg_line = black_theme.v and 0xFF404040 or 0xFFCC9000
		DL:AddLine(imgui.ImVec2(p.x + offset, p.y), imgui.ImVec2(p.x + offset, p.y + imgui.GetScrollMaxY() + imgui.GetWindowHeight()), col_bg_line, 10);

		imgui.SetCursorPosY(80)
		imgui.PushFont(font[15])
		imgui.BeginGroup()
			for i = #changelog, 1, -1 do
				local pos = imgui.GetCursorPos()
				local cl = changelog[i]
				local isLast = i == #changelog
				imgui.SetCursorPosX(offset + 30)
				imgui.BeginGroup()
					imgui.PushFont(font[20])
					local p2 = imgui.GetCursorScreenPos()
					local circle_color = black_theme.v and 0xFF707070 or 0xFFEEEEEE
					if cl.date == nil and isLast then -- is Beta
						circle_color = 0xFF0090FF
					elseif isLast then
						circle_color = 0xFFFF5000
					end
					local radius = isLast and 12 or 10
					DL:AddCircleFilled(imgui.ImVec2(p.x + offset + 1, p2.y + 10), radius, col_bg_line, 32)
					DL:AddCircleFilled(imgui.ImVec2(p.x + offset + 1, p2.y + 10), radius - 3, circle_color, 32)
					if cl.date ~= nil then
						imgui.TextColoredRGB('{0070FF}Версия ' .. cl.version)
						imgui.SameLine()
						imgui.TextColoredRGB('|  {5F99C2}' .. getTimeAfter(cl.date))
						imgui.PushFont(font[11])
						imgui.Hint('dateupdate'..i, u8(os.date('От %d.%m.%Y', cl.date)))
						imgui.PopFont()
					else
						imgui.TextColoredRGB('{FF9000}Версия ' .. cl.version .. '-Beta')
					end
					imgui.PopFont()
					if cl.comment ~= "" then
						imgui.TextColored(imgui.ImVec4(0.4, 0.5, 0.7, 1.0), fa.ICON_FA_COMMENT .. ' ' .. u8(cl.comment))
					end
					for n, line in ipairs(cl.log) do
						if type(line) == 'table' then
							imgui.TextColoredRGB(' - ' .. line.title)
							local pp = imgui.GetCursorPos()
							local ss = imgui.CalcTextSize(u8(' - ' .. line.title))
							imgui.SetCursorPos( imgui.ImVec2(pp.x + ss.x + 10, pp.y - ss.y - 2) )
							imgui.PushFont(font[11])
							imgui.TextColored(imgui.ImVec4(0.4, 0.5, 0.7, 1.0), line.show and fa.ICON_FA_MINUS_CIRCLE or fa.ICON_FA_PLUS_CIRCLE)
							if imgui.IsItemClicked() then
								changelog[i].log[n].show = not changelog[i].log[n].show  
							end
							imgui.PopFont()
							if line.show then
								imgui.PushStyleColor(imgui.Col.Text, imgui.GetStyle().Colors[imgui.Col.TextDisabled])
								for _, dop in ipairs(line.more) do
									imgui.SetCursorPosX(offset + 55)
									imgui.TextWrapped(u8(dop))
								end
								imgui.PopStyleColor()
							end
						else
							imgui.TextWrapped(u8(' - ' .. line))
						end
					end
					if #cl.patches.info > 0 then
						imgui.TextColored(imgui.ImVec4(0.5, 0.6, 0.8, 1.0), u8(' >> Патчи ').. (cl.patches.show and fa.ICON_FA_MINUS_CIRCLE or fa.ICON_FA_PLUS_CIRCLE))
						if imgui.IsItemClicked() then 
							changelog[i].patches.show = not changelog[i].patches.show
						end
						if cl.patches.show then
							imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.4, 0.5, 0.7, 1.0))
							for p, line in ipairs(cl.patches.info) do
								imgui.SetCursorPosX(offset + 45)
								imgui.TextWrapped(u8(p .. ') ' .. line))
							end
							imgui.PopStyleColor()
						end
					end
				imgui.EndGroup()
				imgui.Spacing()
			end
		imgui.EndGroup()
		imgui.PopFont()

		imgui.End()
	end
end

function bringVec4To(from, dest, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (dest.x - from.x) / 100),
            from.y + (count * (dest.y - from.y) / 100),
            from.z + (count * (dest.z - from.z) / 100),
            from.w + (count * (dest.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and dest or from, false
end

function plural(n, forms) 
	n = math.abs(n) % 100
	if n % 10 == 1 and n ~= 11 then
		return forms[1]
	elseif 2 <= n % 10 and n % 10 <= 4 and (n < 10 or n >= 20) then
		return forms[2]
	end
	return forms[3]
end

function sync(x, y, z, alt)
	local M = allocateMemory(68)
	local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
	sampStorePlayerOnfootData(id, M)
	setStructFloatElement(M, 6, x, false)
	setStructFloatElement(M, 10, y, false)
	setStructFloatElement(M, 14, z, false)
	sampSendOnfootData(M)

	if alt then
		setStructElement(M, 4, 2, 1024, false)
		sampSendOnfootData(M)
	end

	freeMemory(M)
end

function getTimeAfter(unix)
	local interval = os.time() - unix
	if interval < 86400 then -- 1 day
		return "Менее суток назад"
	elseif interval < 604800 then -- 1 week
		local days = math.floor(interval / 86400)
		local text = plural(days, {'день', 'дня', 'дней'})
		return ('%s %s назад'):format(days, text)
	elseif interval < 2592000 then -- 1 month
		local weeks = math.floor(interval / 604800)
		local text = plural(weeks, {'неделя', 'недели', 'недель'})
		return ('%s %s назад'):format(weeks, text)
	elseif interval < 31536000 then -- 1 year
		local months = math.floor(interval / 2592000)
		local text = plural(months, {'месяц', 'месяца', 'месяцев'})
		return ('%s %s назад'):format(months, text)
	else -- 1+ years
		local years = math.floor(interval / 31536000)
		local text = plural(years, {'год', 'года', 'лет'})
		return ('%s %s назад'):format(years, text)
	end
end

function log(text, tag)
	local output = string.format("%s[%s]: %s%s", sc, (tag or "Info"), wc, text)
	local result = pcall(sampfuncsLog, output)
	if not result then print(output) end
end

function helpCommands()
	if imgui.BeginPopupModal(u8("Все команды скрипта"), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) then
		imgui.PushFont(font[20])
		imgui.CenterTextColoredRGB(mc..'Все доступные команды и сочетания клавиш')
		imgui.PopFont()
		imgui.Spacing()
		imgui.TextColoredRGB(sc..'Команды в чате:')
		imgui.SetCursorPosX(20)
		imgui.BeginGroup()
			imgui.TextColoredRGB(mc..'/bank{SSSSSS} - Основное меню скрипта (либо "BB" как чит-код)')
			imgui.TextColoredRGB(mc..'/ustav{SSSSSS} - Устав ЦБ в отдельном окне')
			imgui.TextColoredRGB(mc..'/ro [text]{SSSSSS} - РП чат объявлений')
			imgui.TextColoredRGB(mc..'/rbo [text]{SSSSSS} - НонРП чат объявлений')
			imgui.TextColoredRGB(mc..'/uninvite [id] [причина]{SSSSSS} - Увольнение сотрудника с РП отыгровками (9+ ранг)')
			imgui.TextColoredRGB(mc..'/giverank [id] [ранг]{SSSSSS} - Выдача ранга сотруднику с РП отыгровкой (9+ ранг)')
			imgui.TextColoredRGB(mc..'/fwarn [id] [причина]{SSSSSS} - Выдача выговору сотруднику с РП отыгровкой (9+ ранг)')
			imgui.TextColoredRGB(mc..'/blacklist [id] [причина]{SSSSSS} - Занесение в ЧС Банка с РП отыгровкой (9+ ранг)')
			imgui.TextColoredRGB(mc..'/unfwarn [id]{SSSSSS} - Снятие выговора сотруднику с РП отыгровкой (9+ ранг)')
			imgui.TextColoredRGB(mc..'/kip{SSSSSS} - Сменить позицию панели информации на кассе')
			imgui.TextColoredRGB(mc..'/getprize{SSSSSS} - Проверить пикап с ларцами орг. на расстоянии')
		imgui.EndGroup()
		imgui.Spacing()
		imgui.TextColoredRGB(sc..'Сочетания клавиш:')
		imgui.SetCursorPosX(20)
		imgui.BeginGroup()
			imgui.TextColoredRGB(mc..'ПКМ + Q{SSSSSS} - Меню взаимодействия с клиентом')
			imgui.TextColoredRGB(mc..'ПКМ + G{SSSSSS} - Выгнать из банка с причиной ' .. cfg.main.expelReason)
			imgui.TextColoredRGB(mc..'ПКМ + R{SSSSSS} - Объявить цель для тега {select_id}/{select_name}')
		imgui.EndGroup()
		imgui.Spacing()
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 150) / 2)
		if imgui.Button(u8'Закрыть##команды', imgui.ImVec2(150, 20)) then 
			imgui.CloseCurrentPopup()
		end 
		imgui.EndPopup()
	end
end

function checkData()
	local dir = getWorkingDirectory() .. '\\BHelper'
	if not doesDirectoryExist(dir) then
		if createDirectory(dir) then
			log(string.format('Создана директория %s', dir), "Подготовка")
		end
	end

	log('Проверка наличия лекций..', "Подготовка")
	if not doesFileExist(lect_path) then
		lections = lections_default
		local file = io.open(lect_path, "w")
		file:write(encodeJson(lections))
		file:close()
		log('Файл лекций не найден, создан файл', "Подготовка")
	else
		local file = io.open(lect_path, "r")
		lections = decodeJson(file:read('*a'))
		file:close()
	end

	local files = {
		['Устав ЦБ.txt'] = charter_default,
		['Кредитование.txt'] = lending_default,
		['Кадровая система.txt'] = HRsystem_default,
		['Система повышения.txt'] = Promotion_default
	}
	for name, text in pairs(files) do 
		if not doesFileExist(dir .. '\\' .. name) then
			log(string.format('Создан файл «%s»', name), "Подготовка")
			local file = io.open(dir .. '\\' .. name, "w")
			file:write(text)
			file:close()
		end
	end
	files = nil
	return true
end

function imgui.ToggleButton(str_id, bool)
	local rBool = false

	if LastActiveTime == nil then
		LastActiveTime = {}
	end
	if LastActive == nil then
		LastActive = {}
	end

	local function ImSaturate(f)
		return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
	end
	
	local p = imgui.GetCursorScreenPos()
	local draw_list = imgui.GetWindowDrawList()

	local height = imgui.GetTextLineHeightWithSpacing()
	local width = height * 1.55
	local radius = height * 0.50
	local ANIM_SPEED = 0.15
	local butPos = imgui.GetCursorPos()

	if imgui.InvisibleButton(str_id, imgui.ImVec2(width, height)) then
		bool.v = not bool.v
		rBool = true
		LastActiveTime[tostring(str_id)] = os.clock()
		LastActive[tostring(str_id)] = true
	end

	imgui.SetCursorPos(imgui.ImVec2(butPos.x + width + 8, butPos.y + 2.5))
	imgui.Text( str_id:gsub('##.+', '') )

	local t = bool.v and 1.0 or 0.0

	if LastActive[tostring(str_id)] then
		local time = os.clock() - LastActiveTime[tostring(str_id)]
		if time <= ANIM_SPEED then
			local t_anim = ImSaturate(time / ANIM_SPEED)
			t = bool.v and t_anim or 1.0 - t_anim
		else
			LastActive[tostring(str_id)] = false
		end
	end

	local col_cr, col_bg
	if bool.v then
		local bAct = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
		col_cr = imgui.GetColorU32(imgui.ImVec4(bAct.x, bAct.y, bAct.z, 1.00))
		col_bg = imgui.GetColorU32(imgui.ImVec4(bAct.x, bAct.y, bAct.z, 0.50))
	else
		col_cr = imgui.GetColorU32(imgui.ImVec4(0.5, 0.5, 0.5, 1.00))
		col_bg = imgui.GetColorU32(imgui.ImVec4(0.5, 0.5, 0.5, 0.50))
	end

	draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y + (height / 6)), imgui.ImVec2(p.x + width - 1.0, p.y + (height - (height / 6))), col_bg, 5.0)
	draw_list:AddCircleFilled(imgui.ImVec2(p.x + radius + t * (width - radius * 2.0), p.y + radius), radius - 0.75, col_cr)

	return rBool
end

changelog = {
	[26] = {
		version = '26',
		comment = '',
		date = os.time({day = '24', month = '4', year = '2022'}),
		log = {
			{
				title = "Обновлено меню взаимодействия с клиентом",
				show = true,
				more = {
					"а) Почти все банковские услуги понижены до 3 ранга",
					"б) С 4 ранга доступна кнопка выдачи депозита до 10 миллионов (2 процента идёт сотруднику банка)"
				}
			},
			"Улучшена стабильность и исправлены некоторые проблемы",
			"Убрана зависимость от SAMP.lua версии 3.0 и выше"
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[25] = {
		version = '25',
		comment = '',
		date = os.time({day = '26', month = '3', year = '2022'}),
		log = {
			"В причинах отказа о приеме в организацию добавлена кнопка «Нет прививки от коронавируса»",
			"Исправлено ложное срабатывание авто-формы. Теперь срабатывает только когда зашли на сервер",
			"Теперь что-бы остановить проигрывающуюся отыгровку достаточно нажать «Backspace»",
			"Если нажать правой кнопкой мыши по услуге (/bankmenu), то она выполнится без отыгровки",
			"Через один/два часа (в зависимости от ранга) после получения ларца орг. вам придет уведомление, что пора получать новый",
			"В настройки добавлена кнопка «Ручное обновление», для тех, у кого по каким-то причинам не работает система автообновления.",
			"Отыгровка приветствия (Через ПКМ + Q) теперь пишется в зависимости от времени на сервере, а не по вашему местному времени. Рекомендуется ввести /time что-бы откалибровать время",
			"Раздел «Повышения» переименован в «Меню сотрудника». Теперь в нём можно не только повысить сотрудника, но и посмотреть его успеваемость, выдать выговор, уволить и так далее..",
			"Настройка времени задержки отыгровок теперь сохраняется как положено",
			"Немного изменён внешний вид раздела настроек",
			"Изменены некоторые цвета интерфейса",
			"Добавлена функция «Авто-дубинка», аналогичная авто-форме",
			"Изменено меню квестов у бота"
		},
		patches = {
			show = false,
			info = {
				"Вырезаны формы автозаполнения (!пост, !лекция, !треня) из за ненадобности, а так же они приводили некоторых пользователей к крашам",
				"Исправлены некоторые моменты, которые приводили к крашам",
				"Исправления и улучшения"
			}
		}
	},
	[24] = {
		version = '24',
		comment = '',
		date = os.time({day = '20', month = '3', year = '2022'}),
		log = {
			"Новая функция «Авто-форма». При заходе на сервер, вы заспавнитесь сразу в рабочей форме.\nВключить можно в общих настройках",
			"Изменена отыгровка для /expel, в связи с тем что команда теперь доступна с 5 ранга",
			"Изменен метод поиска в окне устава (/ustav)",
			"Убрана функция изменения цвета своего ника в чате организации",
			"Команды /ro и /rbo теперь доступны любому",
			"Добавлены анимации плавного открытия и закрытия всех окон",
			"Обновлены ссылки на разработчика в информации о скрипте. Пишите если есть предложения или знаете какой-то баг :)"
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[23] = {
		version = '23',
		comment = 'С днём защитника отечества! Версия подстать празднику :D',
		date = os.time({day = '23', month = '2', year = '2022'}),
		log = {
			"В меню взаимодействия (ПКМ + Q) добавлен новый пункт \"Дополнительный счёт\"",
			{
				title = "Улучшена статистика \"Баланса фракций\"",
				show = true,
				more = {
					"а) Сортировка от самой богатой фракции, к самой бедной",
					"б) Суммы разделяются точками",
					"в) Убрана лишняя информация"
				}
			},
			"Радиус взаимодействия c кассой (N) увеличен до 3 метров (Теперь её можно открыть с обоих сторон перегородки)",
			{
				title = "Изменены некоторые стандартные отыгровки",
				show = true,
				more = {
					"а) Отыгровка приветствия",
					"б) Отыгровка оформления карты",
					"в) Отыгровка восстановления PIN-кода"
				}
			},
			"Улучшена логика работы тегов и теперь их можно использовать сразу несколько в одной строке",
			"Небольшие переработки в интерфейсе взаимодействия с клиентом (ПКМ + Q)",
			"Счётчики действий на кассе обнуляются, когда уходишь с поста (Раньше суммировались)",
			"Во всём интерфейсе установлен новый шрифт",
			"В общих настройках добавлен пункт для автоматического ввода PIN-кода",
			"Функция авто-скриншота на лаунчере теперь работает (А точнее совместима с R3)",
			"Добавлена поддержка сервера Sun City (20)"
		},
		patches = {
			show = false,
			info = {
				"В связи с тем, что у многих стоит старая версия SAMP.lua, то скрипт крашился при подключении к серверу.\nТеперь в случае если версия ниже требуемой, то вам будет предоставлена инструкция по обновлению на последнюю",
				"Исправлено неверное автоматическое определение пола, если на вас надет кастомный скин",
				"Исправлена ошибка с отыгровками, когда после завершения одной, не удавалось начать другую",
				"Повышен критерий должности для команды /expel (с 5+ ранга)",
				"Добавлены авто-отыгровки, когда при собеседовании в организацию вам показывают документы"
			}
		}
	},
	[22] = {
		version = '22',
		comment = '',
		date = os.time({day = '16', month = '2', year = '2022'}),
		log = {
			"Добавлена кнопка для выдачи VIP-Карты в меню взаимодействия",
			"Исправлена работа счётчика действий в табличке на кассе",
			"Добавлена команда /getprize для получения ларца организации прямо не выходя из-за кассы",
			"Немного изменена команда /premium, в чате должно писать должность которой была выдана премия",
			"Прочие исправления косвенно влияющие на работу скрипта"
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[21] = {
		version = '21',
		comment = '',
		date = os.time({day = '9', month = '1', year = '2022'}),
		log = {
			"Добавлена поддержка сервера Page (19)",
		},
		patches = {
			show = false,
			info = {
				"Исправление ошибок"
			}
		}
	},
	[20] = {
		version = '20',
		comment = '',
		date = os.time({day = '11', month = '11', year = '2021'}),
		log = {
			"Добавлена поддержка сервера Casa-Grande (18)",
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[19] = {
		version = '19',
		comment = '',
		date = os.time({day = '25', month = '7', year = '2021'}),
		log = {
			'В связи вводом "новых технологий" античита Аризоны переписана система отправки сообщений. Все баги связанные с неотправкой или пропуском сообщений, а так же команд должны исчезнуть',
			'Задержку между вашими сообщениями в отыгровках можно отрегулировать в Настройки -> Настройки отыгровок/акцента (по умолчанию 2.5 секунды)',
			'Добавлена кнопка «Удалить Bank-Helper» в Настройки -> О скрипте',
			'Убраны все оставшиеся зависимости (fontAwesome и загрузка текстовых файлов)',
			'Добавлена возможность редактировать «Единую систему повышений»',
			'Небольшие (косметические) изменения во внешнем виде скрипта'
		},
		patches = {
			show = false,
			info = {
				'Исправления и улучшения',
				'Поддержка сервера Show-Low (17)'
			}
		}
	},
	[18] = {
		version = '18',
		comment = '',
		date = os.time({day = '25', month = '5', year = '2021'}),
		log = {
			'Строка о выдаче премий переделана. Теперь там пишется ранг, получивший деньги.',
			'Немного переделаны сообщения от банка в чате. Так же теперь их можно полностью отключить в настройках',
			'Поиск в уставе немного улучшен. Искомые слова выделяются красным цветом'
		},
		patches = {
			show = false,
			info = {
				'Исправлены некоторые грамматические ошибки',
				'Оптимизация и улучшения'
			}
		}
	},
	[17] = {
		version = '17',
		comment = '',
		date = os.time({day = '2', month = '5', year = '2021'}),
		log = {
			'Проведена огромная работа над рефакторингом кода скрипта, тем самым улучшив его оптимизацию',
			{
				title = 'Переработана система проведения лекций',
				show = false,
				more = {
					'а) Возможность добавлять свои лекции прямо не выходя из игры',
					'б) При первом запуске скрипта, все лекции уже занесены в память, и их не нужно скачивать',
					'в) Возможность остановить воспроизведение лекции в любой момент',
					'г) Возможность выбрать чат, в который будет читаться лекция (Обычный, /r и /rb)',
					'д) Возможность редактировать лекции',
					'е) Убрана зависимость от библиотеки "LuaFileSystem"'
				}
			},
			'Новый дизайн окна списка изменений (changelog\'а)',
			'Главное меню скрипта потерпело небольшие изменения',
			'Убраны все цветовые темы скрипта за исключением "Тёмной" и "Светлой"',
			'Немного изменён профиль информации о себе в главном меню',
			'Переписана система чёрного списка фракции. Теперь список один, и не подразделяется на жёлтый и красный.',
			'Убрана зависимость от внешних изображений для скрипта',
			'Убрана зависимость от Notify.lua',
			'Исправлено неверное отображение "приличности" скина',
			'Теперь вы можете удалить скрипт, скачанный из репозитория, просто нажав на него и подтвердив удаление',
			'Теперь в статистике на кассе считается реальный заработок (от депозитов, выдачи кард и т.д)',
			'Вырезан логгер действий руководителя. Взамен ему вы можете скачать из репозитория более удобный логгер',
			'Вырезана функция /uval из-за ненадобности',
			'Новая функция Чат-Калькулятор. Просто введите в поле ввода пример и под ним появится ответ.',
			'При вводе пин-кода в банке вам больше не придётся нажимать еще раз N, что бы открыть само меню',
		},
		patches = {
			show = false,
			info = {
				'Фикс багов у команд /fwarn и /blacklist',
				'Добавлена поддержка нового сервера "Gilbert"'
			}
		}
	},
	[16] = {
		version = '16',
		comment = '',
		date = os.time({day = '3', month = '1', year = '2021'}),
		log = {
			'Добавлена поддержка 15-го сервера (Payson)',
			'Убрана зависимость некоторых библиотек для работы скрипта'
		},
		patches = {
			show = false,
			info = {
				'Исправлен краш скрипта при вставании на любой из постов'
			}
		}
	},
	[15] = {
		version = '15',
		comment = '',
		date = os.time({day = '20', month = '11', year = '2020'}),
		log = {
			'Убран "Цветной ввод", в связи с вводом его аналога в лаунчер от Аризоны',
			'Исправлен баг, когда все скины были "не приличными"',
			'Немного переделана система проверки на сервер при запуске скрипта',
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[14] = {
		version = '14',
		comment = '',
		date = os.time({day = '7', month = '11', year = '2020'}),
		log = {
			'Добавлена поддержка 14-го сервера Аризоны (Символично, не правда-ли?)',
			'Более подробное логирование возникших в скрипте проблем',
		},
		patches = {
			show = false,
			info = {
				'Хот-фикс мелких недочётов'
			}
		}
	},
	[13] = {
		version = '13',
		comment = '',
		date = os.time({day = '16', month = '10', year = '2020'}),
		log = {
			'Когда рядом с вами один сотрудник ТК-шит другого дубинкой, выводится варнинг об этом в чат (Доступно с 5 ранга)',
			'Вырезана проверка на рабочую форму (цвет ника) при открытии ПКМ + Q',
			'В меню планирования GOV-волны, можно изменить тег организации в /d чат',
			'Желто-Чёрные "Знаки вопроса" изменены на новый объект',
			'Немного переделаны подсказки',
			'Вырезан диалог информирующий о правильном вводе PIN-кода вашей банковской карты'
		},
		patches = {
			show = false,
			info = {
				'Обновлены скрипты в репозитории на актуальные версии + добавлен новый скрипт'
			}
		}
	},
	[12] = {
		version = '12',
		comment = '',
		date = os.time({day = '3', month = '9', year = '2020'}),
		log = {
			'Новые уведомления',
			'Подсказки при наведении на них появляются плавно',
			'Команды /unfwarn, /fwarn теперь доступны только с 9 ранга',
			'Исправлены баги инвентаря, которые вызывал скрипт. Теперь он как и прежде нормально работает и не зависает'
		},
		patches = {
			show = false,
			info = {
				'Фикс бага с подгрузкой недостающих библиотек'
			}
		}
	},
	[11] = {
		version = '11',
		comment = '',
		date = os.time({day = '12', month = '8', year = '2020'}),
		log = {
			'Теперь, когда показываешь /jobprogress игроку, в чат пишется об этом (по стандарту вообще ничего не происходило как будто, и не понятно, показал ли ты документ или нет :/)',
			'Теперь панель информации на кассе можно выключить в настройках',
			'Ники в отыгровках теперь отображаются без нижнего подчёркивания'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[10] = {
		version = '10',
		comment = '',
		date = os.time({day = '25', month = '7', year = '2020'}),
		log = {
			{
				title = 'Продолжена работа над оптимизацией скрипта',
				show = false,
				more = {
					'а) Полностью переписана система дозагрузки файлов и библиотек! Проблемы при установке скрипта практически свелись к нулю',
					'б) Немного изменена система обновления скрипта',
					'в) Внутренняя оптимизация скрипта (кода)'
				}
			},
			'Теперь текст GOV-волны из меню планирования сохраняется после перезахода',
			'Пользователи с фамилией Cosmo теперь могут вручную выбрать цвет ника в чате организации',
			'Исправлен баг с ненажатием кнопок в разделе "Репозиторий"',
			'В /bank - Настройки - Общие настройки добавлена функция "Цветной ввод"',
			'Прочие мелкие изменения'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[9] = {
		version = '9',
		comment = '',
		date = os.time({day = '11', month = '7', year = '2020'}),
		log = {
			{
				title = 'Теперь если вы имеете фамилию Cosmo (например: Bob_Cosmo), у вас будут небольшие привилегии',
				show = false,
				more = {
					'а) Ваш ник в чате организации выделяется особым цветом!',
					'б) С любого ранга доступны команды /ro, /rbo',
					'P.S. Функции будут дополнятся..'
				}
			},
			{
				title = 'С текущей версии убраны несколько функций',
				show = false,
				more = {
					'Members на экране',
					'Таймер онлайна в основном меню скрипта, на его месте теперь отображается дата вашего последнего повышения',
					'Меню /premium',
				}
			},
			'Проведена огромная работа по внутренней оптимизации скрипта',
			'Но не стоит расстраиваться! Все эти функции перенесены в новый раздел в настройках - "Репозиторий". Там все эти функции в виде отдельных скриптов сделанных лично автором этого скрипта. Все скрипты из раздела "Репозиторий" сделаны исключительно мной, и гораздо лучше тех, что были изначально в этом скрипте',
			'Теперь в меню взаимодействия (ПКМ + Q) есть пункт выгнать из банка, так как много кто это просил, и не всем удобно делать это через ПКМ + G',
			'В настройках скрипта можно указать причину, с которой будет выгоняться нарушитель (По умолчанию Н.П.Б)',
			'Убран авто-скриншот /expel',
			'Добавлена новая цветовая тема скрипта - "Мягкий красный"',
			'Окно устава организации стало намного удобнее и появилась возможность копировать от туда текст',
			'Теперь скрипт будет запускаться только, если вы на проекте Arizona RP',
			'Очень много мелких исправлений'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[8] = {
		version = '8',
		comment = '',
		date = os.time({day = '27', month = '6', year = '2020'}),
		log = {
			'Данные из панели с информацией на кассе теперь сохраняются после перезахода, и обновляются, когда наступает новый день',
			'Скрипт отныне не будет работать, если вы не состоите в банке',
			'Переписана функция получения ранга скриптом',
			'Переписана система подсчёта сотрудников для /premium',
			'Название рангов теперь берётся из /members, что бы они обновились под ваш сервер, просто откройте меню /members, скрипт сам всё сделает за вас',
			'Немного улучшен загрузчик файлов, теперь при первом запуске скрипта, у вас не будет миллион сообщений в чат и флуд диалогом',
			'Добавлен бинд /time на клавишу F9, выключить можно в настройках',
			'Изменена система кредитов: Максимальная сумма теперь 300.000$ (Системно), Скорее всего на форуме вашего сервера изменилась система кредитования, рекомендуется обновить её, либо удалить файл Кредитование.txt в папке /moonloader/BHelper',
			'Фикс некоторых сообщений от скрипта в чате, а так же сообщения об обновлениях будут выводится в консоль sampfuncs, что бы не мешало лишний раз',
			'Фикс бага Аризоны, когда у 1-4 рангов при нажатии Альт в любом месте, выходило сообщение "Пост у кассы доступен с 5-го ранга"',
			'Переделаны многие отыгровки',
			'Немного модернизировано меню /premium, теперь там есть предварительный подсчёт выделяемой премии на одного сотрудника',
			'Задержка в биндах теперь отображается нормально когда редактируешь его',
			'Тег @id теперь возвращает только имя игрока, без его фамилии. Например: "@343, где вы находитесь?" - "Jeffy, где вы находитесь?"',
			'Переделаны цветовые схемы скрипта, теперь фиолетовая и серая тема, более красивые и приятные, чем были ранее'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[7] = {
		version = '7',
		comment = '',
		date = os.time({day = '20', month = '6', year = '2020'}),
		log = {
			'Добавлена панель информации, когда стоите на кассе (Отключить можно в /bank - Настройки - Общие настройки)',
			'Изменить местоположение панели можно командой /kip (сохраняется после перезахода)',
			'Убран 3dText, когда занимаешь кассу, многим он просто напросто мешал. Теперь он пишется в панели информации (пункт выше)',
			'Теперь все действия в /bankmenu (ПКМ + Q) распределены по рангам. Например теперь первый ранг не может нажать кнопку "Выдать кредит", и хелпер не багается',
			'Исправлен краш в /premium при включенном Авто-Скриншоте',
			'Добавлена команда /unblacklist [id]',
			'Теперь тег {screen} работает без багов. Пример использования: "Сотрудники, сейчас я проведу вам тренировку {screen}" (Строка заскриниться автоматически после отправки, а {screen} не отправится в чат)',
			'Перенастроены некоторые цвета, теперь на разных темах все меню выглядят более приятнее',
			'Добавлена авто-подгрузка дополнительных библиотек (fAwesome, lfs), в случае их отсутствия',
			'Исправлен баг, когда нельзя было писать эмоции ")" "))" "(" "((" "xD" ":D" писались "с акцентом". Теперь всё работает по РП',
			'Для лидеров и заместителей теперь есть папка, в которой логируются все повышения, увольнения, выдачи наказаний и рангов. Будет полезно для оформлений отчётов следящим',
			'Добавлен чекер /members, он доступен с 5-ого ранга в разделе /bank -> Ст. Состав',
			'Добавлена новая красивая цветовая схема подходящая под основные цвета используемые в скрипте. Изменить: /bank -> Настройки -> Настройки цветов',
			'Исправлены баги с чекером, но увы, пришлось перенести его на "костыльную" систему обновления. Он будет "мигать", во время сбора информации, поэтому лучше выставить задержку в обновлении 10-15 секунд, что бы не напрягал'
		},
		patches = {
			show = false,
			info = {
				'Мелкие исправления',
				'Вновь доработан чекер members\'a',
				'Исправлены баги с командой /invite',
			}
		}
	},
	[6] = {
		version = '6',
		comment = '',
		date = os.time({day = '14', month = '6', year = '2020'}),
		log = {
			'Добавлены уведомления в углу экрана, теперь некоторые сообщения будут выводится в них',
			'Для 9-10 рангов добавлено меню планирования GOV волны. Найти его можно во вкладке "Старший состав"',
			'В этот же раздел добавлено меню выдачи премий, раньше оно было только по команде /premium',
			'Добавлен чат объявлений для лидера и заместителя. Писать в него можно командами /ro и /rbo'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[5] = {
		version = '5',
		comment = '',
		date = os.time({day = '10', month = '6', year = '2020'}),
		log = {
			'Меню выдачи премий сотрудникам (9+), для активации просто написать - /premium',
			'Поправлены некоторые отыгровки',
			'Исправлены некоторые баги',
			'Сделаны отыгровки под команды: /blacklist, /giverank',
			'В настройках скрипта можно установить галочку "Авто-Скрин". Эта функция автоматически скринит с /time все ваши повышения, увольнения, ЧС и т.п.',
			'Там же в настройках можно скачать ASI-плагин "Screenshot" от MISTER_GONWIK\'a. Он позволяет делать скриншоты без зависания',
			'Добавлен новый тег для биндера - {screen}. Можно использовать в чате/командах. Например: /giverank 228 9 {screen}, сначала отправит команду, а потом сам заскринит её с /time'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[4] = {
		version = '4',
		comment = '',
		date = os.time({day = '6', month = '6', year = '2020'}),
		log = {
			'Убрана проверка на анимацию оглушения при попытке использовать ПКМ + G (Выгнать из банка), почти всегда она работала некорректно, и вызывала дискомфорт при использовании',
			'Теперь ваш ранг в настройках скрипта настраивается автоматически.',
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[3] = {
		version = '3',
		comment = '',
		date = os.time({day = '3', month = '6', year = '2020'}),
		log = {
			'Если ваш ранг ниже 8-ого, но вам разрешено проводить собеседования, при его завершении не будет отыгрываться РП, как вы выдаёте форму и инвайтите, а отыгрывается, мол вы позвали руководителя, что бы он вас принял (напишет в рацию)',
			'Добавлен пункт в настройках "О скрипте" - Отключить автоматическое обновление, когда вы заходите в игру',
			'Новая категория в меню для старшего состава (5+ ранг) в меню /bank',
			'Добавлен ЧС правительства (5+ ранг) в категории Ст. Состав (/bank). Список с двумя категориями: "Желтый ЧС" и "Красный ЧС", в основном это сделано для лидеров и заместителей, а так же для тех, кому разрешено собеседования. При опросе человека из Чёрного скрипт вам не даст его принять, дабы избежать лишних предов от следящих в свой адрес',
			'Обновлена команда /invite (9+ ранг), добавлены отыгровки при её использовании'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[2] = {
		version = '2',
		comment = '',
		date = os.time({day = '29', month = '5', year = '2020'}),
		log = {
			'Добавлен выбор пола персонажа в "Настройках отыгровок/акцента"',
			'Фикс бага когда в причину увольнения добавлялось ненужное "{SSSSSS}"',
			'Добавлена подгрузка некоторых файлов, если вы их случайно удалили каким то образом',
			'Добавлена команда /uninvite, точнее добавлены отыгровки при её использовании'
		},
		patches = {
			show = false,
			info = {}
		}
	},
	[1] = {
		version = '1',
		comment = 'Спасибо за помощь Noa Shelby, Bruno Quinzsy, Markus Quinzsy',
		date = os.time({day = '25', month = '5', year = '2020'}),
		log = {
			'Релиз скрипта, закрытое бета-тестирование',
		},
		patches = {
			show = false,
			info = {}
		}
	},
}

charter_default = [[Глава 1. Общие положения.
1.1. Устав Центрального Банка - это внутриорганизационный регламентирующий деятельность сотрудников документ.
1.2. Устав может быть отредактирован только после того как большинство депутатов парламента проголосуют “За” принятие изменений в нём.
1.3. Устав ставится действительным только с момента публикации на официальном портале штата.
1.4. За незнание, несоблюдение устава руководство организации имеет право ввести дисциплинарное взыскание против сотрудника в виде выговора, понижения, увольнения.

Глава 2. Обязанности сотрудников.
2.1. Каждый сотрудник обязан знать и соблюдать устав организации в которой он работает.
2.2. Каждый сотрудник обязан выполнять свои должностные обязанности качественно.
2.3. Каждый сотрудник обязан соблюдать конституцию, трудовой кодекс и иные правовые акты. При несоблюдении сотрудник будет наказан в соответствии с действующим законодательством.
2.4. Каждый сотрудник обязан подходить к задаче поставленной руководством ответственно.
2.5. Каждый сотрудник обязан выполнять законные требования руководства.
2.6. Каждый сотрудник обязан быть подключён к спец.рации во время выполнения своих должностных обязанностей.
2.7. Каждый сотрудник обязан разговаривать со всеми уважительно в деловом тоне.

Глава 3. Полномочия и права сотрудников.
3.1. Сотрудники охраны имеют право применить физическую силу если руководству угрожает опасность.
3.2. Сотрудники имеют право получить любую информацию на официальном правовом портале штата.
3.3. Сотрудники Центрального Банка, а именно: Начальники отдела сбережений, Заведующие отделом сбережений, Менеджеры, Заместители Директора, Министр Финансов имеют право пользоваться рацией департамента в служебных целях.
3.4. Сотрудники правительства имеют право на личную жизнь вне рабочего времени.
3.5. Сотрудники имеют право на отпуск в соответствии с современным Трудовым Кодексом.
3.5.1. Отпуск может быть взят только один раз в месяц.
3.5.2. Охрана и сотрудники банка [2] имеют право на отпуск в течении недели (семь календарных дней).
2.5.3. Старшие сотрудники банка, Начальники отдела сбережений, Заведующие отделом сбережений, Менеджеры имеют право на отпуск в течении пяти календарных дней.
2.5.4. Директора Банка имеют право на отпуск в течении трёх дней.

Глава 4. Сотрудникам запрещается.
4.1. Сотрудникам Центрального Банка строго запрещено нарушать: Конституцию, Трудовой Кодекс, Устав Центрального Банка, Уголовный и Административный кодексы.
4.2. Сотрудникам Центрального Банка строго запрещено бездействовать при угрозе органам высшей исполнительной власти.
4.3. Сотрудникам Центрального Банка строго запрещено прогуливать рабочий день
4.3.1. Рабочий день в будние дни с 9:00 до 20:00.
4.3.2. Рабочий день в выходные с 10:00 до 19:00.
4.3.3. Обеденный перерыв с 14:00 до 15:00 ежедневно.
4.4 Сотрудникам Центрального Банка строго запрещено пользоваться имуществом организации в личных целях.
4.5. Сотрудникам Центрального Банка строго запрещено применять огнестрельное оружие.
4.5.1 Сотрудникам Центрального Банка запрещено угрожать кому либо.
4.5.2. Исключение: На основании Уголовного и Административного кодекса при наличии лицензии.
4.6. Сотрудникам Центрального Банка строго запрещено курить.
4.7. Сотрудникам Центрального Банка строго запрещено выпивать спиртные напитки.
4.7.1 Сотрудникам центрального банка запрещено употреблять наркотические вещества
4.8. Сотрудникам Центрального Банка строго запрещено выражаться нецензурно.
4.9. Сотрудникам Центрального Банка строго запрещено оспаривать законные указания руководства.
4.10. Сотрудникам Центрального Банка строго запрещено носить на себе аксессуары.
4.10.1. Исключения: Тёмные очки чёрного цвета, часы, усы.
4.11. Сотрудникам Центрального Банка строго запрещено запрещено самостоятельно менять\покидать пост.
4.12. Сотрудникам Центрального Банка строго запрещено просить и намекать на повышение.
4.13. Сотрудникам Центрального Банка строго запрещено просить и намекать на проверку отчётов.
4.14. Сотрудникам Центрального Банка строго запрещено нарушать дисциплину в строю. Отображено в уставе.
4.15. Сотрудникам Центрального Банка строго запрещено просить и намекать на выплату премии.
4.16. Сотрудникам Центрального Банка строго запрещено применять физическую силу без весомой причины.
4.17. Сотрудникам Центрального Банка строго запрещено долго спать на рабочем месте.
4.17.1. Охрана и сотрудники Банка [1-4] не более десяти минут.
4.17.2. Старшие сотрудники банка, Начальники отдела сбережений, Заведующие отделом сбережений, [5-8] не более десяти минут.
4.17.3. Заместители Директора [9] не более десяти минут.

Глава 5. Дисциплина в строю.
5.1. Время построения зависит от требований человека проводящего строй (не менее пяти минут).
5.2. В строю сотрудникам запрещено пользоваться мобильным телефоном.
5.3. В строю сотрудникам запрещено использовать любые жесты.
5.4. В строю сотрудникам запрещено вести разговоры.
5.5. В строю сотрудникам запрещено использовать рацию в строю.
5.6. В строю сотрудникам запрещено передавать что либо.
5.7. В строю сотрудник обязан внимательно слушать информацию передаваемую человеком который проводит строй.
5.8. Собирать сотрудников организации на построение имеют право сотрудники с должности Начальника Охраны и выше.
5.9. За поведение сотрудников в строю отвечает человек который проводит строй.

Глава 6. Особые положения при проведении тренировок и лекционных задач
6.1 Лекционные задачи могут выдавать исключительно сотрудники с должности Начальника охраны и выше (3+)
6.2 Тренировки могут проводить сотрудники, находящиеся на должности Начальника охраны и выше (3+)
6.3 Между лекционными задачами общий перерыв составляет 20 минут.
6.3.1 Один сотрудник Центрального Банка имеет право выдавать лекционные задачи один раз в 25 минут.
6.3 Между тренировочными мероприятиями общий перерыв составляет 30 минут.
6.3.1 Один сотрудник Центрального Банка имеет право проводить тренировочные мероприятия один раз в 35 минут.
6.4 За невыполнение данных норм управляющие лица организации ОБЯЗАНЫ отклонить дальнейший отчёт на повышение сотрудника в должности.
6.4.1 В случае игнорирования нарушений руководитель организации получает устное предупреждение.]]

HRsystem_default = [[{006AC2}Кадровая система{SSSSSS} - система отсчёта времени нахождения на 
каждом ранге. Другими словами - это ваш испытательный 
срок на вашем ранге. Раньше него вы не можете перейти
на следующий. Испытательные сроки с 1 по 9 ранг:
 
{006AC2}1 {SSSSSS}->{006AC2} 2 ранг {SSSSSS}- Отсутствует
{006AC2}2 {SSSSSS}->{006AC2} 3 ранг {SSSSSS}- 12 часов
{006AC2}3 {SSSSSS}->{006AC2} 4 ранг {SSSSSS}- 24 часа
{006AC2}4 {SSSSSS}->{006AC2} 5 ранг {SSSSSS}- 24 часа
{006AC2}5 {SSSSSS}->{006AC2} 6 ранг {SSSSSS}- 48 часов (2-е суток)
{006AC2}6 {SSSSSS}->{006AC2} 7 ранг {SSSSSS}- 72 часа (3-е суток)
{006AC2}7 {SSSSSS}->{006AC2} 8 ранг {SSSSSS}- 120 часов (5 суток)
{006AC2}8 {SSSSSS}->{006AC2} 9 ранг {SSSSSS}- 144 часа (6 суток)
{006AC2}9 {SSSSSS}->{006AC2} 10 ранг {SSSSSS}- 360 часов (15 суток)]]

Promotion_default = [[{0088C2}Система повышения для 1 - 7 рангов
C мая 2020 года - отменена. Лидер повышает на своё усмотрение, оценивая вашу работу
 
{0088C2}Менеджер [7] -> Зам. директора [8]
Проработать на данной должности 120 часов {868686}(5 дней)
1. Простоять за кассой 2 часа {868686}(скриншоты каждые 10 минут с /time)
2. Провести 30 лекций составу {868686}(КД между строчками 5 секунд; обязательно /timestamp)
3. Помочь на 15-и собеседованиях
4. Провести 5 мероприятия для состава
5. Выполнить 5 задания {868686}(РП задание; /me /do /todo минимум 10 РП отыгровок)
 
{0088C2}Зам.Директора [8] -> Директор Банка [9]
Проработать на данной должности 144 часа {868686}(6 дней)
Составить отчёт
Подготовится к беседе на пост Директора Центрального Банка
Примечание: отчёт на 9-й ранг подобный отчёту на 8-й, но с увеличенной нормой перечисленного]]

lending_default = [[От {009000}5.000${FFFFFF} до {009000}25.000${FFFFFF}:
Проживать в штате от 3-х до 5-ми лет
Иметь опрятный внешний вид
Иметь законопослушность выше 30-ти
---
От {009000}25.000${FFFFFF} до {009000}50.000${FFFFFF}:
Проживать в штате от 5-ми до 8-ти лет
Иметь опрятный внешний вид
Иметь законопослушность выше 40-ти
---
От {009000}50.000${FFFFFF} до {009000}100.000${FFFFFF}:
Проживать в штате от 8-ти до 11-ти лет
Иметь прописку в штате
Не иметь проблем с психикой.
Иметь опрятный внешний вид
Иметь законопослушность выше 50-ти
---
От {009000}75.000${FFFFFF} до {009000}100.000${FFFFFF}:
Проживать в штате от 11-ти лет
Иметь прописку в штате
Не иметь проблем с психикой
Иметь опрятный внешний вид
Иметь законопослушность выше 70-ти
---
От {009000}100.000${FFFFFF} до {009000}175.000${FFFFFF}:
Проживать в штате от 15-лет
Не иметь проблем с психикой
Иметь опрятный внешний вид
Иметь законопослушность выше 75-ти
Иметь прописку в штате
---
От {009000}175.000${FFFFFF} до {009000}300.000${FFFFFF}:
Проживать в штате от 17-лет
Не иметь проблем с психикой
Иметь опрятный внешний вид
Иметь законопослушность выше 80-ти
Иметь прописку в штате.]]

lections_default = {
	active = { bool = false, name = nil, handle = nil },
	data = {
		{
			name = "Внешний вид сотрудников",
			text = {
				"Сейчас Вы прослушаете лекцию о том, как должен выглядеть любой сотрудник Банка в рабочее время",
				"Каждый сотрудник, приходя на смену должен переодеться в рабочую форму, взять дубинку и рацию",
				"Ваша рабочая форма - это ваше лицо. Она должна быть чистая и выглаженная",
				"Так же, на вас и на вашей форме не должно быть каких либо аксессуаров, кроме часов",
				"Вы не должны выглядеть как клоун или Рождественская Елка. Строго и по дресс-коду",
				"Всем спасибо. Лекция окончена"
			}
		},
		{
			name = "Временное отлучение от дел",
			text = {
				"Сейчас я прочитаю вам лекцию на тему \"Временное отлучение от дел\"",
				"Если вы хотите отлучится по личных делам, например покушать или уехать в больницу",
				"то нужно спросить разрешения у старшего состава, или руководителей",
				"Также напоминаю, что рабочий транспорт брать в личных целях крайне запрещено!",
				"Нужно обязательно спросить разрешение, и иметь весомую причину на его использование.",
				"Всем спасибо. Лекция окончена."
			}
		},
		{
			name = "Обращение со старшими",
			text = {
				"Сейчас состоится лекция на тему \"обращение со старшими по должности\"",
				"Во-первых, к старшим по должности исключительно на \"Вы\"",
				"Во-вторых, обращаться следует по форме \"сэр\", \"мистер\", \"господин\"",
				"но ни в коем случае не \"товарищ\" или вовсе без уважения!",
				"Еще хотел бы упомянуть, что не стоит докучать начальству по поводу",
				"повышений или проверки отчетов.",
				"Руководство обязательно выполнит вашу просьбу после того, как освободится",
				"Всем спасибо за внимание, лекция окончена"
			}
		},
		{
			name = "Правила нашего банка",
			text = {
				"Сегодняшняя лекция посвящена некоторым правилам нашего банка",
				"Итак, категорически нельзя бегать по банку, это ведь вам не стадион и не манеж",
				"Покидать банк и тем более брать транспорт без разрешения запрещается",
				"За это наше руководство будет строго наказывать",
				"Нельзя использовать дубинку не по назначению и без причины",
				"Полный список правил банка выложен на официальном портале нашего штата",
				"Лекция окончена, спасибо за внимание"
			}
		},
		{
			name = "Правила поведения при теракте",
			text = {
				"Сейчас я проведу вам лекцию на тему \"Правила поведения при теракте\"",
				"Если в рабочее время, на вас напали бандиты, то первым делом, вы должны:",
				"Первое - при возможности нажать на тревожную кнопку",
				"Второе - оставаться на своих местах в случаях, если выйти нет возможности",
				"Третье - внимательно слушать указания бандитов и выполнять их",
				"Четвёртое - слушать приказы силовых структур",
				"Пятое - не подавать никаких признаков о просьбе помощи у силовых структур",
				"Так же, во время ограбления, у вас скорее всего отберут рацию и телефон",
				"Всем спасибо, лекция окончена"
			}
		},
		{
			name = "Причастность к криминалу",
			text = {
				"Сейчас я проведу вам лекцию на тему \"Причастность к криминалу\"",
				"Участились случаи содействия бандитам со стороны гос. работников",
				"Убедительная просьба: не помогайте бандитам и не контактируйте с ними ни при каких",
				"обстоятельствах. В конце концов это может для вас плохо кончится.",
				"Вы ставите под угрозу свою жизнь. Разве стоит так рисковать из-за каких-то бандитов?",
				"Спасибо за внимание, лекция окончена"
			}
		}
	}
}

fa = {
	['ICON_FA_NOTES_MEDICAL'] = "\xef\x92\x81",
 	['ICON_FA_CLOUD_SHOWERS_HEAVY'] = "\xef\x9d\x80",
 	['ICON_FA_SMS'] = "\xef\x9f\x8d",
 	['ICON_FA_COPY'] = "\xef\x83\x85",
 	['ICON_FA_CHEVRON_CIRCLE_RIGHT'] = "\xef\x84\xb8",
 	['ICON_FA_CROSSHAIRS'] = "\xef\x81\x9b",
 	['ICON_FA_BROADCAST_TOWER'] = "\xef\x94\x99",
 	['ICON_FA_EXTERNAL_LINK_SQUARE_ALT'] = "\xef\x8d\xa0",
 	['ICON_FA_SMOKING'] = "\xef\x92\x8d",
 	['ICON_FA_KISS_BEAM'] = "\xef\x96\x97",
 	['ICON_FA_CHESS_BISHOP'] = "\xef\x90\xba",
 	['ICON_FA_TV'] = "\xef\x89\xac",
 	['ICON_FA_CROP_ALT'] = "\xef\x95\xa5",
 	['ICON_FA_TH'] = "\xef\x80\x8a",
 	['ICON_FA_RECYCLE'] = "\xef\x86\xb8",
 	['ICON_FA_SMILE'] = "\xef\x84\x98",
 	['ICON_FA_FAX'] = "\xef\x86\xac",
 	['ICON_FA_DRAFTING_COMPASS'] = "\xef\x95\xa8",
 	['ICON_FA_USER_INJURED'] = "\xef\x9c\xa8",
 	['ICON_FA_SCREWDRIVER'] = "\xef\x95\x8a",
 	['ICON_FA_DHARMACHAKRA'] = "\xef\x99\x95",
 	['ICON_FA_PRINT'] = "\xef\x80\xaf",
 	['ICON_FA_BABY_CARRIAGE'] = "\xef\x9d\xbd",
 	['ICON_FA_CARET_UP'] = "\xef\x83\x98",
 	['ICON_FA_SCHOOL'] = "\xef\x95\x89",
 	['ICON_FA_SORT_NUMERIC_UP'] = "\xef\x85\xa3",
 	['ICON_FA_TRUCK_LOADING'] = "\xef\x93\x9e",
 	['ICON_FA_LIST'] = "\xef\x80\xba",
 	['ICON_FA_UPLOAD'] = "\xef\x82\x93",
 	['ICON_FA_LAPTOP_MEDICAL'] = "\xef\xa0\x92",
 	['ICON_FA_EXPAND_ARROWS_ALT'] = "\xef\x8c\x9e",
 	['ICON_FA_ADJUST'] = "\xef\x81\x82",
 	['ICON_FA_VENUS'] = "\xef\x88\xa1",
 	['ICON_FA_HEADING'] = "\xef\x87\x9c",
 	['ICON_FA_ARROW_DOWN'] = "\xef\x81\xa3",
 	['ICON_FA_BICYCLE'] = "\xef\x88\x86",
 	['ICON_FA_TIRED'] = "\xef\x97\x88",
 	['ICON_FA_AIR_FRESHENER'] = "\xef\x97\x90",
 	['ICON_FA_BACON'] = "\xef\x9f\xa5",
 	['ICON_FA_SYNC'] = "\xef\x80\xa1",
 	['ICON_FA_PAPER_PLANE'] = "\xef\x87\x98",
 	['ICON_FA_VOLLEYBALL_BALL'] = "\xef\x91\x9f",
 	['ICON_FA_RIBBON'] = "\xef\x93\x96",
 	['ICON_FA_HAND_LIZARD'] = "\xef\x89\x98",
 	['ICON_FA_CLOCK'] = "\xef\x80\x97",
 	['ICON_FA_SUN'] = "\xef\x86\x85",
 	['ICON_FA_FILE_POWERPOINT'] = "\xef\x87\x84",
 	['ICON_FA_MICROCHIP'] = "\xef\x8b\x9b",
 	['ICON_FA_TRASH_RESTORE_ALT'] = "\xef\xa0\xaa",
 	['ICON_FA_GRADUATION_CAP'] = "\xef\x86\x9d",
 	['ICON_FA_ANGLE_DOUBLE_DOWN'] = "\xef\x84\x83",
 	['ICON_FA_INFO_CIRCLE'] = "\xef\x81\x9a",
 	['ICON_FA_TAGS'] = "\xef\x80\xac",
 	['ICON_FA_FILE_ALT'] = "\xef\x85\x9c",
 	['ICON_FA_EQUALS'] = "\xef\x94\xac",
 	['ICON_FA_DIRECTIONS'] = "\xef\x97\xab",
 	['ICON_FA_FILE_INVOICE'] = "\xef\x95\xb0",
 	['ICON_FA_SEARCH'] = "\xef\x80\x82",
 	['ICON_FA_BIBLE'] = "\xef\x99\x87",
 	['ICON_FA_FLASK'] = "\xef\x83\x83",
 	['ICON_FA_CALENDAR_TIMES'] = "\xef\x89\xb3",
 	['ICON_FA_GREATER_THAN_EQUAL'] = "\xef\x94\xb2",
 	['ICON_FA_SLIDERS_H'] = "\xef\x87\x9e",
 	['ICON_FA_EYE_SLASH'] = "\xef\x81\xb0",
 	['ICON_FA_BIRTHDAY_CAKE'] = "\xef\x87\xbd",
 	['ICON_FA_FEATHER_ALT'] = "\xef\x95\xab",
 	['ICON_FA_DNA'] = "\xef\x91\xb1",
 	['ICON_FA_BASEBALL_BALL'] = "\xef\x90\xb3",
 	['ICON_FA_HOSPITAL'] = "\xef\x83\xb8",
 	['ICON_FA_COINS'] = "\xef\x94\x9e",
 	['ICON_FA_HRYVNIA'] = "\xef\x9b\xb2",
 	['ICON_FA_TEMPERATURE_HIGH'] = "\xef\x9d\xa9",
 	['ICON_FA_FONT_AWESOME_LOGO_FULL'] = "\xef\x93\xa6",
 	['ICON_FA_PASSPORT'] = "\xef\x96\xab",
 	['ICON_FA_TAG'] = "\xef\x80\xab",
 	['ICON_FA_SHOPPING_CART'] = "\xef\x81\xba",
 	['ICON_FA_AWARD'] = "\xef\x95\x99",
 	['ICON_FA_WINDOW_RESTORE'] = "\xef\x8b\x92",
 	['ICON_FA_PHONE'] = "\xef\x82\x95",
 	['ICON_FA_FLAG'] = "\xef\x80\xa4",
 	['ICON_FA_STETHOSCOPE'] = "\xef\x83\xb1",
 	['ICON_FA_DICE_D6'] = "\xef\x9b\x91",
 	['ICON_FA_OUTDENT'] = "\xef\x80\xbb",
 	['ICON_FA_LONG_ARROW_ALT_RIGHT'] = "\xef\x8c\x8b",
 	['ICON_FA_PIZZA_SLICE'] = "\xef\xa0\x98",
 	['ICON_FA_ADDRESS_CARD'] = "\xef\x8a\xbb",
 	['ICON_FA_PARAGRAPH'] = "\xef\x87\x9d",
 	['ICON_FA_MALE'] = "\xef\x86\x83",
 	['ICON_FA_HISTORY'] = "\xef\x87\x9a",
 	['ICON_FA_HAMBURGER'] = "\xef\xa0\x85",
 	['ICON_FA_SEARCH_PLUS'] = "\xef\x80\x8e",
 	['ICON_FA_FIRE_ALT'] = "\xef\x9f\xa4",
 	['ICON_FA_LIFE_RING'] = "\xef\x87\x8d",
 	['ICON_FA_SHARE'] = "\xef\x81\xa4",
 	['ICON_FA_ALIGN_JUSTIFY'] = "\xef\x80\xb9",
 	['ICON_FA_BATTERY_THREE_QUARTERS'] = "\xef\x89\x81",
 	['ICON_FA_OBJECT_UNGROUP'] = "\xef\x89\x88",
 	['ICON_FA_BRIEFCASE'] = "\xef\x82\xb1",
 	['ICON_FA_OIL_CAN'] = "\xef\x98\x93",
 	['ICON_FA_THERMOMETER_FULL'] = "\xef\x8b\x87",
 	['ICON_FA_PLANE'] = "\xef\x81\xb2",
 	['ICON_FA_HEARTBEAT'] = "\xef\x88\x9e",
 	['ICON_FA_UNLINK'] = "\xef\x84\xa7",
 	['ICON_FA_WINDOW_MAXIMIZE'] = "\xef\x8b\x90",
 	['ICON_FA_HEADPHONES'] = "\xef\x80\xa5",
 	['ICON_FA_STEP_BACKWARD'] = "\xef\x81\x88",
 	['ICON_FA_DRAGON'] = "\xef\x9b\x95",
 	['ICON_FA_MICROPHONE_SLASH'] = "\xef\x84\xb1",
 	['ICON_FA_USER_PLUS'] = "\xef\x88\xb4",
 	['ICON_FA_WRENCH'] = "\xef\x82\xad",
 	['ICON_FA_AMBULANCE'] = "\xef\x83\xb9",
 	['ICON_FA_ETHERNET'] = "\xef\x9e\x96",
 	['ICON_FA_EGG'] = "\xef\x9f\xbb",
 	['ICON_FA_WIND'] = "\xef\x9c\xae",
 	['ICON_FA_UNIVERSAL_ACCESS'] = "\xef\x8a\x9a",
 	['ICON_FA_BURN'] = "\xef\x91\xaa",
 	['ICON_FA_HAND_HOLDING_HEART'] = "\xef\x92\xbe",
 	['ICON_FA_DICE_ONE'] = "\xef\x94\xa5",
 	['ICON_FA_KEYBOARD'] = "\xef\x84\x9c",
 	['ICON_FA_CHECK_DOUBLE'] = "\xef\x95\xa0",
 	['ICON_FA_HEADPHONES_ALT'] = "\xef\x96\x8f",
 	['ICON_FA_BATTERY_HALF'] = "\xef\x89\x82",
 	['ICON_FA_PROJECT_DIAGRAM'] = "\xef\x95\x82",
 	['ICON_FA_PRAY'] = "\xef\x9a\x83",
 	['ICON_FA_GOPURAM'] = "\xef\x99\xa4",
 	['ICON_FA_GRIN_TEARS'] = "\xef\x96\x88",
 	['ICON_FA_SORT_AMOUNT_UP'] = "\xef\x85\xa1",
 	['ICON_FA_COFFEE'] = "\xef\x83\xb4",
 	['ICON_FA_TABLET_ALT'] = "\xef\x8f\xba",
 	['ICON_FA_GRIN_BEAM_SWEAT'] = "\xef\x96\x83",
 	['ICON_FA_HAND_POINT_RIGHT'] = "\xef\x82\xa4",
 	['ICON_FA_MAGIC'] = "\xef\x83\x90",
 	['ICON_FA_CHARGING_STATION'] = "\xef\x97\xa7",
 	['ICON_FA_GRIN_TONGUE'] = "\xef\x96\x89",
 	['ICON_FA_VOLUME_OFF'] = "\xef\x80\xa6",
 	['ICON_FA_SAD_TEAR'] = "\xef\x96\xb4",
 	['ICON_FA_CARET_RIGHT'] = "\xef\x83\x9a",
 	['ICON_FA_BONG'] = "\xef\x95\x9c",
 	['ICON_FA_BONE'] = "\xef\x97\x97",
 	['ICON_FA_ELLIPSIS_V'] = "\xef\x85\x82",
 	['ICON_FA_BALANCE_SCALE'] = "\xef\x89\x8e",
 	['ICON_FA_FISH'] = "\xef\x95\xb8",
 	['ICON_FA_SPIDER'] = "\xef\x9c\x97",
 	['ICON_FA_CAMPGROUND'] = "\xef\x9a\xbb",
 	['ICON_FA_CARET_SQUARE_UP'] = "\xef\x85\x91",
 	['ICON_FA_RUPEE_SIGN'] = "\xef\x85\x96",
 	['ICON_FA_ASSISTIVE_LISTENING_SYSTEMS'] = "\xef\x8a\xa2",
 	['ICON_FA_POUND_SIGN'] = "\xef\x85\x94",
 	['ICON_FA_ANKH'] = "\xef\x99\x84",
 	['ICON_FA_BATTERY_QUARTER'] = "\xef\x89\x83",
 	['ICON_FA_HAND_PEACE'] = "\xef\x89\x9b",
 	['ICON_FA_SURPRISE'] = "\xef\x97\x82",
 	['ICON_FA_FILE_PDF'] = "\xef\x87\x81",
 	['ICON_FA_VIDEO_SLASH'] = "\xef\x93\xa2",
 	['ICON_FA_SUBWAY'] = "\xef\x88\xb9",
 	['ICON_FA_HORSE'] = "\xef\x9b\xb0",
 	['ICON_FA_WINE_BOTTLE'] = "\xef\x9c\xaf",
 	['ICON_FA_BOOK_READER'] = "\xef\x97\x9a",
 	['ICON_FA_COOKIE'] = "\xef\x95\xa3",
 	['ICON_FA_MONEY_BILL'] = "\xef\x83\x96",
 	['ICON_FA_CHEVRON_DOWN'] = "\xef\x81\xb8",
 	['ICON_FA_CAR_SIDE'] = "\xef\x97\xa4",
 	['ICON_FA_FILTER'] = "\xef\x82\xb0",
 	['ICON_FA_FOLDER_OPEN'] = "\xef\x81\xbc",
 	['ICON_FA_SIGNATURE'] = "\xef\x96\xb7",
 	['ICON_FA_SNOWBOARDING'] = "\xef\x9f\x8e",
 	['ICON_FA_THUMBTACK'] = "\xef\x82\x8d",
 	['ICON_FA_DICE_TWO'] = "\xef\x94\xa8",
 	['ICON_FA_LAUGH_WINK'] = "\xef\x96\x9c",
 	['ICON_FA_BREAD_SLICE'] = "\xef\x9f\xac",
 	['ICON_FA_TEXT_HEIGHT'] = "\xef\x80\xb4",
 	['ICON_FA_VOLUME_MUTE'] = "\xef\x9a\xa9",
 	['ICON_FA_VOTE_YEA'] = "\xef\x9d\xb2",
 	['ICON_FA_QRCODE'] = "\xef\x80\xa9",
 	['ICON_FA_MERCURY'] = "\xef\x88\xa3",
 	['ICON_FA_USER_ASTRONAUT'] = "\xef\x93\xbb",
 	['ICON_FA_SORT_AMOUNT_DOWN'] = "\xef\x85\xa0",
 	['ICON_FA_SORT_DOWN'] = "\xef\x83\x9d",
 	['ICON_FA_COMPACT_DISC'] = "\xef\x94\x9f",
 	['ICON_FA_PERCENTAGE'] = "\xef\x95\x81",
 	['ICON_FA_COMMENT_MEDICAL'] = "\xef\x9f\xb5",
 	['ICON_FA_STORE'] = "\xef\x95\x8e",
 	['ICON_FA_COMMENT_DOTS'] = "\xef\x92\xad",
 	['ICON_FA_SMILE_WINK'] = "\xef\x93\x9a",
 	['ICON_FA_HOTEL'] = "\xef\x96\x94",
 	['ICON_FA_PEPPER_HOT'] = "\xef\xa0\x96",
 	['ICON_FA_USER_EDIT'] = "\xef\x93\xbf",
 	['ICON_FA_DUMPSTER_FIRE'] = "\xef\x9e\x94",
 	['ICON_FA_CLOUD_SUN_RAIN'] = "\xef\x9d\x83",
 	['ICON_FA_GLOBE_ASIA'] = "\xef\x95\xbe",
 	['ICON_FA_VIAL'] = "\xef\x92\x92",
 	['ICON_FA_STROOPWAFEL'] = "\xef\x95\x91",
 	['ICON_FA_DATABASE'] = "\xef\x87\x80",
 	['ICON_FA_TREE'] = "\xef\x86\xbb",
 	['ICON_FA_SHOWER'] = "\xef\x8b\x8c",
 	['ICON_FA_DRUM_STEELPAN'] = "\xef\x95\xaa",
 	['ICON_FA_FILE_UPLOAD'] = "\xef\x95\xb4",
 	['ICON_FA_MEDKIT'] = "\xef\x83\xba",
 	['ICON_FA_MINUS'] = "\xef\x81\xa8",
 	['ICON_FA_SHEKEL_SIGN'] = "\xef\x88\x8b",
 	['ICON_FA_BELL_SLASH'] = "\xef\x87\xb6",
 	['ICON_FA_MAIL_BULK'] = "\xef\x99\xb4",
 	['ICON_FA_MOUNTAIN'] = "\xef\x9b\xbc",
 	['ICON_FA_COUCH'] = "\xef\x92\xb8",
 	['ICON_FA_CHESS'] = "\xef\x90\xb9",
 	['ICON_FA_FILE_EXPORT'] = "\xef\x95\xae",
 	['ICON_FA_SIGN_LANGUAGE'] = "\xef\x8a\xa7",
 	['ICON_FA_SNOWFLAKE'] = "\xef\x8b\x9c",
 	['ICON_FA_PLAY'] = "\xef\x81\x8b",
 	['ICON_FA_HEADSET'] = "\xef\x96\x90",
 	['ICON_FA_SQUARE_ROOT_ALT'] = "\xef\x9a\x98",
 	['ICON_FA_CHART_BAR'] = "\xef\x82\x80",
 	['ICON_FA_WAVE_SQUARE'] = "\xef\xa0\xbe",
 	['ICON_FA_CHART_AREA'] = "\xef\x87\xbe",
 	['ICON_FA_EURO_SIGN'] = "\xef\x85\x93",
 	['ICON_FA_CHESS_KING'] = "\xef\x90\xbf",
 	['ICON_FA_MOBILE'] = "\xef\x84\x8b",
 	['ICON_FA_BOX_OPEN'] = "\xef\x92\x9e",
 	['ICON_FA_DOG'] = "\xef\x9b\x93",
 	['ICON_FA_FUTBOL'] = "\xef\x87\xa3",
 	['ICON_FA_LIRA_SIGN'] = "\xef\x86\x95",
 	['ICON_FA_LIGHTBULB'] = "\xef\x83\xab",
 	['ICON_FA_BOMB'] = "\xef\x87\xa2",
 	['ICON_FA_MITTEN'] = "\xef\x9e\xb5",
 	['ICON_FA_TRUCK_MONSTER'] = "\xef\x98\xbb",
 	['ICON_FA_ARROWS_ALT_H'] = "\xef\x8c\xb7",
 	['ICON_FA_CHESS_ROOK'] = "\xef\x91\x87",
 	['ICON_FA_FIRE_EXTINGUISHER'] = "\xef\x84\xb4",
 	['ICON_FA_BOOKMARK'] = "\xef\x80\xae",
 	['ICON_FA_ARROWS_ALT_V'] = "\xef\x8c\xb8",
 	['ICON_FA_ICICLES'] = "\xef\x9e\xad",
 	['ICON_FA_FONT'] = "\xef\x80\xb1",
 	['ICON_FA_CAMERA_RETRO'] = "\xef\x82\x83",
 	['ICON_FA_BLENDER'] = "\xef\x94\x97",
 	['ICON_FA_THUMBS_DOWN'] = "\xef\x85\xa5",
 	['ICON_FA_GAMEPAD'] = "\xef\x84\x9b",
 	['ICON_FA_COPYRIGHT'] = "\xef\x87\xb9",
 	['ICON_FA_JEDI'] = "\xef\x99\xa9",
 	['ICON_FA_HOCKEY_PUCK'] = "\xef\x91\x93",
 	['ICON_FA_STOP_CIRCLE'] = "\xef\x8a\x8d",
 	['ICON_FA_BEZIER_CURVE'] = "\xef\x95\x9b",
 	['ICON_FA_FOLDER'] = "\xef\x81\xbb",
 	['ICON_FA_RSS'] = "\xef\x82\x9e",
 	['ICON_FA_COLUMNS'] = "\xef\x83\x9b",
 	['ICON_FA_GLASS_CHEERS'] = "\xef\x9e\x9f",
 	['ICON_FA_GRIN_WINK'] = "\xef\x96\x8c",
 	['ICON_FA_STOP'] = "\xef\x81\x8d",
 	['ICON_FA_MONEY_CHECK_ALT'] = "\xef\x94\xbd",
 	['ICON_FA_COMPASS'] = "\xef\x85\x8e",
 	['ICON_FA_TOOLBOX'] = "\xef\x95\x92",
 	['ICON_FA_LIST_OL'] = "\xef\x83\x8b",
 	['ICON_FA_WINE_GLASS'] = "\xef\x93\xa3",
 	['ICON_FA_HORSE_HEAD'] = "\xef\x9e\xab",
 	['ICON_FA_USER_ALT_SLASH'] = "\xef\x93\xba",
 	['ICON_FA_USER_TAG'] = "\xef\x94\x87",
 	['ICON_FA_MICROSCOPE'] = "\xef\x98\x90",
 	['ICON_FA_BRUSH'] = "\xef\x95\x9d",
 	['ICON_FA_BAN'] = "\xef\x81\x9e",
 	['ICON_FA_BARS'] = "\xef\x83\x89",
 	['ICON_FA_CAR_CRASH'] = "\xef\x97\xa1",
 	['ICON_FA_ARROW_ALT_CIRCLE_DOWN'] = "\xef\x8d\x98",
 	['ICON_FA_MONEY_BILL_ALT'] = "\xef\x8f\x91",
 	['ICON_FA_JOURNAL_WHILLS'] = "\xef\x99\xaa",
 	['ICON_FA_CHALKBOARD_TEACHER'] = "\xef\x94\x9c",
 	['ICON_FA_PORTRAIT'] = "\xef\x8f\xa0",
 	['ICON_FA_HAMMER'] = "\xef\x9b\xa3",
 	['ICON_FA_RETWEET'] = "\xef\x81\xb9",
 	['ICON_FA_HOURGLASS'] = "\xef\x89\x94",
 	['ICON_FA_HAND_PAPER'] = "\xef\x89\x96",
 	['ICON_FA_SUBSCRIPT'] = "\xef\x84\xac",
 	['ICON_FA_DONATE'] = "\xef\x92\xb9",
 	['ICON_FA_GLASS_MARTINI_ALT'] = "\xef\x95\xbb",
 	['ICON_FA_CODE_BRANCH'] = "\xef\x84\xa6",
 	['ICON_FA_NOT_EQUAL'] = "\xef\x94\xbe",
 	['ICON_FA_MEH'] = "\xef\x84\x9a",
 	['ICON_FA_LIST_ALT'] = "\xef\x80\xa2",
 	['ICON_FA_USER_COG'] = "\xef\x93\xbe",
 	['ICON_FA_PRESCRIPTION'] = "\xef\x96\xb1",
 	['ICON_FA_TABLET'] = "\xef\x84\x8a",
 	['ICON_FA_PENCIL_RULER'] = "\xef\x96\xae",
 	['ICON_FA_CREDIT_CARD'] = "\xef\x82\x9d",
 	['ICON_FA_ARCHWAY'] = "\xef\x95\x97",
 	['ICON_FA_HARD_HAT'] = "\xef\xa0\x87",
 	['ICON_FA_MAP_MARKER_ALT'] = "\xef\x8f\x85",
 	['ICON_FA_COG'] = "\xef\x80\x93",
 	['ICON_FA_HANUKIAH'] = "\xef\x9b\xa6",
 	['ICON_FA_SHUTTLE_VAN'] = "\xef\x96\xb6",
 	['ICON_FA_MONEY_CHECK'] = "\xef\x94\xbc",
 	['ICON_FA_BELL'] = "\xef\x83\xb3",
 	['ICON_FA_CALENDAR_DAY'] = "\xef\x9e\x83",
 	['ICON_FA_TINT_SLASH'] = "\xef\x97\x87",
 	['ICON_FA_PLANE_DEPARTURE'] = "\xef\x96\xb0",
 	['ICON_FA_USER_CHECK'] = "\xef\x93\xbc",
 	['ICON_FA_CHURCH'] = "\xef\x94\x9d",
 	['ICON_FA_SEARCH_MINUS'] = "\xef\x80\x90",
 	['ICON_FA_PALLET'] = "\xef\x92\x82",
 	['ICON_FA_TINT'] = "\xef\x81\x83",
 	['ICON_FA_STAMP'] = "\xef\x96\xbf",
 	['ICON_FA_KAABA'] = "\xef\x99\xab",
 	['ICON_FA_ALIGN_RIGHT'] = "\xef\x80\xb8",
 	['ICON_FA_QUOTE_RIGHT'] = "\xef\x84\x8e",
 	['ICON_FA_BEER'] = "\xef\x83\xbc",
 	['ICON_FA_GRIN_ALT'] = "\xef\x96\x81",
 	['ICON_FA_SORT_NUMERIC_DOWN'] = "\xef\x85\xa2",
 	['ICON_FA_FIRE'] = "\xef\x81\xad",
 	['ICON_FA_FAST_FORWARD'] = "\xef\x81\x90",
 	['ICON_FA_MAP_MARKED_ALT'] = "\xef\x96\xa0",
 	['ICON_FA_PENCIL_ALT'] = "\xef\x8c\x83",
 	['ICON_FA_USERS_COG'] = "\xef\x94\x89",
 	['ICON_FA_CARET_SQUARE_DOWN'] = "\xef\x85\x90",
 	['ICON_FA_CRUTCH'] = "\xef\x9f\xb7",
 	['ICON_FA_OBJECT_GROUP'] = "\xef\x89\x87",
 	['ICON_FA_ANCHOR'] = "\xef\x84\xbd",
 	['ICON_FA_HAND_POINT_LEFT'] = "\xef\x82\xa5",
 	['ICON_FA_USER_TIMES'] = "\xef\x88\xb5",
 	['ICON_FA_CALCULATOR'] = "\xef\x87\xac",
 	['ICON_FA_DIZZY'] = "\xef\x95\xa7",
 	['ICON_FA_KISS_WINK_HEART'] = "\xef\x96\x98",
 	['ICON_FA_FILE_MEDICAL'] = "\xef\x91\xb7",
 	['ICON_FA_SWIMMING_POOL'] = "\xef\x97\x85",
 	['ICON_FA_WEIGHT_HANGING'] = "\xef\x97\x8d",
 	['ICON_FA_VR_CARDBOARD'] = "\xef\x9c\xa9",
 	['ICON_FA_FAST_BACKWARD'] = "\xef\x81\x89",
 	['ICON_FA_SATELLITE'] = "\xef\x9e\xbf",
 	['ICON_FA_USER'] = "\xef\x80\x87",
 	['ICON_FA_MINUS_CIRCLE'] = "\xef\x81\x96",
 	['ICON_FA_CHESS_PAWN'] = "\xef\x91\x83",
 	['ICON_FA_CALENDAR_MINUS'] = "\xef\x89\xb2",
 	['ICON_FA_CHESS_BOARD'] = "\xef\x90\xbc",
 	['ICON_FA_LANDMARK'] = "\xef\x99\xaf",
 	['ICON_FA_SWATCHBOOK'] = "\xef\x97\x83",
 	['ICON_FA_HOTDOG'] = "\xef\xa0\x8f",
 	['ICON_FA_SNOWMAN'] = "\xef\x9f\x90",
 	['ICON_FA_LAPTOP'] = "\xef\x84\x89",
 	['ICON_FA_TORAH'] = "\xef\x9a\xa0",
 	['ICON_FA_FROWN_OPEN'] = "\xef\x95\xba",
 	['ICON_FA_USER_LOCK'] = "\xef\x94\x82",
 	['ICON_FA_AD'] = "\xef\x99\x81",
 	['ICON_FA_USER_CIRCLE'] = "\xef\x8a\xbd",
 	['ICON_FA_DIVIDE'] = "\xef\x94\xa9",
 	['ICON_FA_HANDSHAKE'] = "\xef\x8a\xb5",
 	['ICON_FA_CUT'] = "\xef\x83\x84",
 	['ICON_FA_HIKING'] = "\xef\x9b\xac",
 	['ICON_FA_STREET_VIEW'] = "\xef\x88\x9d",
 	['ICON_FA_GREATER_THAN'] = "\xef\x94\xb1",
 	['ICON_FA_PASTAFARIANISM'] = "\xef\x99\xbb",
 	['ICON_FA_MINUS_SQUARE'] = "\xef\x85\x86",
 	['ICON_FA_SAVE'] = "\xef\x83\x87",
 	['ICON_FA_COMMENT_DOLLAR'] = "\xef\x99\x91",
 	['ICON_FA_TRASH_ALT'] = "\xef\x8b\xad",
 	['ICON_FA_PUZZLE_PIECE'] = "\xef\x84\xae",
 	['ICON_FA_MENORAH'] = "\xef\x99\xb6",
 	['ICON_FA_CLOUD_SUN'] = "\xef\x9b\x84",
 	['ICON_FA_USER_FRIENDS'] = "\xef\x94\x80",
 	['ICON_FA_FILE_MEDICAL_ALT'] = "\xef\x91\xb8",
 	['ICON_FA_ARROW_LEFT'] = "\xef\x81\xa0",
 	['ICON_FA_BOXES'] = "\xef\x91\xa8",
 	['ICON_FA_THERMOMETER_EMPTY'] = "\xef\x8b\x8b",
 	['ICON_FA_EXCLAMATION_TRIANGLE'] = "\xef\x81\xb1",
 	['ICON_FA_GIFT'] = "\xef\x81\xab",
 	['ICON_FA_COGS'] = "\xef\x82\x85",
 	['ICON_FA_SIGNAL'] = "\xef\x80\x92",
 	['ICON_FA_SHAPES'] = "\xef\x98\x9f",
 	['ICON_FA_CLOUD_RAIN'] = "\xef\x9c\xbd",
 	['ICON_FA_ELLIPSIS_H'] = "\xef\x85\x81",
 	['ICON_FA_LESS_THAN_EQUAL'] = "\xef\x94\xb7",
 	['ICON_FA_CHEVRON_CIRCLE_LEFT'] = "\xef\x84\xb7",
 	['ICON_FA_MORTAR_PESTLE'] = "\xef\x96\xa7",
 	['ICON_FA_SITEMAP'] = "\xef\x83\xa8",
 	['ICON_FA_BUS_ALT'] = "\xef\x95\x9e",
 	['ICON_FA_ID_BADGE'] = "\xef\x8b\x81",
 	['ICON_FA_FIST_RAISED'] = "\xef\x9b\x9e",
 	['ICON_FA_BATTERY_FULL'] = "\xef\x89\x80",
 	['ICON_FA_CROWN'] = "\xef\x94\xa1",
 	['ICON_FA_EXCHANGE_ALT'] = "\xef\x8d\xa2",
 	['ICON_FA_SOCKS'] = "\xef\x9a\x96",
 	['ICON_FA_CASH_REGISTER'] = "\xef\x9e\x88",
 	['ICON_FA_REDO'] = "\xef\x80\x9e",
 	['ICON_FA_EXCLAMATION_CIRCLE'] = "\xef\x81\xaa",
 	['ICON_FA_COMMENTS'] = "\xef\x82\x86",
 	['ICON_FA_BRIEFCASE_MEDICAL'] = "\xef\x91\xa9",
 	['ICON_FA_CARET_SQUARE_RIGHT'] = "\xef\x85\x92",
 	['ICON_FA_PEN'] = "\xef\x8c\x84",
 	['ICON_FA_BACKSPACE'] = "\xef\x95\x9a",
 	['ICON_FA_SLASH'] = "\xef\x9c\x95",
 	['ICON_FA_HOT_TUB'] = "\xef\x96\x93",
 	['ICON_FA_SUITCASE_ROLLING'] = "\xef\x97\x81",
 	['ICON_FA_BATTERY_EMPTY'] = "\xef\x89\x84",
 	['ICON_FA_GLOBE_AFRICA'] = "\xef\x95\xbc",
 	['ICON_FA_SLEIGH'] = "\xef\x9f\x8c",
 	['ICON_FA_BOLT'] = "\xef\x83\xa7",
 	['ICON_FA_THERMOMETER_QUARTER'] = "\xef\x8b\x8a",
 	['ICON_FA_EYE'] = "\xef\x81\xae",
 	['ICON_FA_TROPHY'] = "\xef\x82\x91",
 	['ICON_FA_BRAILLE'] = "\xef\x8a\xa1",
 	['ICON_FA_PLUS'] = "\xef\x81\xa7",
 	['ICON_FA_LIST_UL'] = "\xef\x83\x8a",
 	['ICON_FA_SMOKING_BAN'] = "\xef\x95\x8d",
 	['ICON_FA_BATH'] = "\xef\x8b\x8d",
 	['ICON_FA_VOLUME_DOWN'] = "\xef\x80\xa7",
 	['ICON_FA_QUESTION_CIRCLE'] = "\xef\x81\x99",
 	['ICON_FA_FILE_CODE'] = "\xef\x87\x89",
 	['ICON_FA_GAVEL'] = "\xef\x83\xa3",
 	['ICON_FA_CANDY_CANE'] = "\xef\x9e\x86",
 	['ICON_FA_NETWORK_WIRED'] = "\xef\x9b\xbf",
 	['ICON_FA_CARET_SQUARE_LEFT'] = "\xef\x86\x91",
 	['ICON_FA_PLANE_ARRIVAL'] = "\xef\x96\xaf",
 	['ICON_FA_SHARE_SQUARE'] = "\xef\x85\x8d",
 	['ICON_FA_MEDAL'] = "\xef\x96\xa2",
 	['ICON_FA_THERMOMETER_HALF'] = "\xef\x8b\x89",
 	['ICON_FA_QUESTION'] = "\xef\x84\xa8",
 	['ICON_FA_CAR_BATTERY'] = "\xef\x97\x9f",
 	['ICON_FA_DOOR_CLOSED'] = "\xef\x94\xaa",
 	['ICON_FA_LEAF'] = "\xef\x81\xac",
 	['ICON_FA_USER_MINUS'] = "\xef\x94\x83",
 	['ICON_FA_MUSIC'] = "\xef\x80\x81",
 	['ICON_FA_GLOBE_EUROPE'] = "\xef\x9e\xa2",
 	['ICON_FA_HOUSE_DAMAGE'] = "\xef\x9b\xb1",
 	['ICON_FA_CHEVRON_RIGHT'] = "\xef\x81\x94",
 	['ICON_FA_GRIP_HORIZONTAL'] = "\xef\x96\x8d",
 	['ICON_FA_DICE_FOUR'] = "\xef\x94\xa4",
 	['ICON_FA_DEAF'] = "\xef\x8a\xa4",
 	['ICON_FA_REGISTERED'] = "\xef\x89\x9d",
 	['ICON_FA_WINDOW_CLOSE'] = "\xef\x90\x90",
 	['ICON_FA_LINK'] = "\xef\x83\x81",
 	['ICON_FA_YEN_SIGN'] = "\xef\x85\x97",
 	['ICON_FA_ATOM'] = "\xef\x97\x92",
 	['ICON_FA_LESS_THAN'] = "\xef\x94\xb6",
 	['ICON_FA_OTTER'] = "\xef\x9c\x80",
 	['ICON_FA_INFO'] = "\xef\x84\xa9",
 	['ICON_FA_MARS_DOUBLE'] = "\xef\x88\xa7",
 	['ICON_FA_CLIPBOARD_CHECK'] = "\xef\x91\xac",
 	['ICON_FA_SKULL'] = "\xef\x95\x8c",
 	['ICON_FA_GRIP_LINES'] = "\xef\x9e\xa4",
 	['ICON_FA_HOSPITAL_SYMBOL'] = "\xef\x91\xbe",
 	['ICON_FA_X_RAY'] = "\xef\x92\x97",
 	['ICON_FA_ARROW_UP'] = "\xef\x81\xa2",
 	['ICON_FA_MONEY_BILL_WAVE'] = "\xef\x94\xba",
 	['ICON_FA_DOT_CIRCLE'] = "\xef\x86\x92",
 	['ICON_FA_PAUSE_CIRCLE'] = "\xef\x8a\x8b",
 	['ICON_FA_IMAGES'] = "\xef\x8c\x82",
 	['ICON_FA_STAR_HALF'] = "\xef\x82\x89",
 	['ICON_FA_SPLOTCH'] = "\xef\x96\xbc",
 	['ICON_FA_STAR_HALF_ALT'] = "\xef\x97\x80",
 	['ICON_FA_SHIP'] = "\xef\x88\x9a",
 	['ICON_FA_BOOK_DEAD'] = "\xef\x9a\xb7",
 	['ICON_FA_CHECK'] = "\xef\x80\x8c",
 	['ICON_FA_RAINBOW'] = "\xef\x9d\x9b",
 	['ICON_FA_POWER_OFF'] = "\xef\x80\x91",
 	['ICON_FA_LEMON'] = "\xef\x82\x94",
 	['ICON_FA_GLOBE_AMERICAS'] = "\xef\x95\xbd",
 	['ICON_FA_PEACE'] = "\xef\x99\xbc",
 	['ICON_FA_THERMOMETER_THREE_QUARTERS'] = "\xef\x8b\x88",
 	['ICON_FA_WAREHOUSE'] = "\xef\x92\x94",
 	['ICON_FA_TRANSGENDER'] = "\xef\x88\xa4",
 	['ICON_FA_PLUS_SQUARE'] = "\xef\x83\xbe",
 	['ICON_FA_BULLSEYE'] = "\xef\x85\x80",
 	['ICON_FA_COOKIE_BITE'] = "\xef\x95\xa4",
 	['ICON_FA_USERS'] = "\xef\x83\x80",
 	['ICON_FA_TRANSGENDER_ALT'] = "\xef\x88\xa5",
 	['ICON_FA_ASTERISK'] = "\xef\x81\xa9",
 	['ICON_FA_STAR_OF_DAVID'] = "\xef\x9a\x9a",
 	['ICON_FA_PLUS_CIRCLE'] = "\xef\x81\x95",
 	['ICON_FA_CART_ARROW_DOWN'] = "\xef\x88\x98",
 	['ICON_FA_FLUSHED'] = "\xef\x95\xb9",
 	['ICON_FA_STORE_ALT'] = "\xef\x95\x8f",
 	['ICON_FA_PEOPLE_CARRY'] = "\xef\x93\x8e",
 	['ICON_FA_LONG_ARROW_ALT_DOWN'] = "\xef\x8c\x89",
 	['ICON_FA_SAD_CRY'] = "\xef\x96\xb3",
 	['ICON_FA_DIGITAL_TACHOGRAPH'] = "\xef\x95\xa6",
 	['ICON_FA_FILE_EXCEL'] = "\xef\x87\x83",
 	['ICON_FA_TEETH'] = "\xef\x98\xae",
 	['ICON_FA_HAND_SCISSORS'] = "\xef\x89\x97",
 	['ICON_FA_FILE_INVOICE_DOLLAR'] = "\xef\x95\xb1",
 	['ICON_FA_STEP_FORWARD'] = "\xef\x81\x91",
 	['ICON_FA_BACKWARD'] = "\xef\x81\x8a",
 	['ICON_FA_SCROLL'] = "\xef\x9c\x8e",
 	['ICON_FA_IGLOO'] = "\xef\x9e\xae",
 	['ICON_FA_CODE'] = "\xef\x84\xa1",
 	['ICON_FA_TRAM'] = "\xef\x9f\x9a",
 	['ICON_FA_TORII_GATE'] = "\xef\x9a\xa1",
 	['ICON_FA_SKIING'] = "\xef\x9f\x89",
 	['ICON_FA_CHAIR'] = "\xef\x9b\x80",
 	['ICON_FA_DUMBBELL'] = "\xef\x91\x8b",
 	['ICON_FA_ANGLE_DOUBLE_UP'] = "\xef\x84\x82",
 	['ICON_FA_ANGLE_DOUBLE_LEFT'] = "\xef\x84\x80",
 	['ICON_FA_MOSQUE'] = "\xef\x99\xb8",
 	['ICON_FA_COMMENTS_DOLLAR'] = "\xef\x99\x93",
 	['ICON_FA_FILE_PRESCRIPTION'] = "\xef\x95\xb2",
 	['ICON_FA_ANGLE_LEFT'] = "\xef\x84\x84",
 	['ICON_FA_ATLAS'] = "\xef\x95\x98",
 	['ICON_FA_PIGGY_BANK'] = "\xef\x93\x93",
 	['ICON_FA_DOLLY_FLATBED'] = "\xef\x91\xb4",
 	['ICON_FA_RANDOM'] = "\xef\x81\xb4",
 	['ICON_FA_PEN_ALT'] = "\xef\x8c\x85",
 	['ICON_FA_PRAYING_HANDS'] = "\xef\x9a\x84",
 	['ICON_FA_VOLUME_UP'] = "\xef\x80\xa8",
 	['ICON_FA_CLIPBOARD_LIST'] = "\xef\x91\xad",
 	['ICON_FA_GRIN_STARS'] = "\xef\x96\x87",
 	['ICON_FA_FOLDER_MINUS'] = "\xef\x99\x9d",
 	['ICON_FA_DEMOCRAT'] = "\xef\x9d\x87",
 	['ICON_FA_MAGNET'] = "\xef\x81\xb6",
 	['ICON_FA_VIHARA'] = "\xef\x9a\xa7",
 	['ICON_FA_GRIMACE'] = "\xef\x95\xbf",
 	['ICON_FA_CHECK_CIRCLE'] = "\xef\x81\x98",
 	['ICON_FA_SEARCH_DOLLAR'] = "\xef\x9a\x88",
 	['ICON_FA_LONG_ARROW_ALT_LEFT'] = "\xef\x8c\x8a",
 	['ICON_FA_CROW'] = "\xef\x94\xa0",
 	['ICON_FA_EYE_DROPPER'] = "\xef\x87\xbb",
 	['ICON_FA_CROP'] = "\xef\x84\xa5",
 	['ICON_FA_SIGN'] = "\xef\x93\x99",
 	['ICON_FA_ARROW_CIRCLE_DOWN'] = "\xef\x82\xab",
 	['ICON_FA_VIDEO'] = "\xef\x80\xbd",
 	['ICON_FA_DOWNLOAD'] = "\xef\x80\x99",
 	['ICON_FA_BOLD'] = "\xef\x80\xb2",
 	['ICON_FA_CARET_DOWN'] = "\xef\x83\x97",
 	['ICON_FA_CHEVRON_LEFT'] = "\xef\x81\x93",
 	['ICON_FA_HAMSA'] = "\xef\x99\xa5",
 	['ICON_FA_CART_PLUS'] = "\xef\x88\x97",
 	['ICON_FA_CLIPBOARD'] = "\xef\x8c\xa8",
 	['ICON_FA_SHOE_PRINTS'] = "\xef\x95\x8b",
 	['ICON_FA_PHONE_SLASH'] = "\xef\x8f\x9d",
 	['ICON_FA_REPLY'] = "\xef\x8f\xa5",
 	['ICON_FA_HOURGLASS_HALF'] = "\xef\x89\x92",
 	['ICON_FA_LONG_ARROW_ALT_UP'] = "\xef\x8c\x8c",
 	['ICON_FA_CHESS_KNIGHT'] = "\xef\x91\x81",
 	['ICON_FA_BARCODE'] = "\xef\x80\xaa",
 	['ICON_FA_DRAW_POLYGON'] = "\xef\x97\xae",
 	['ICON_FA_WATER'] = "\xef\x9d\xb3",
 	['ICON_FA_PAUSE'] = "\xef\x81\x8c",
 	['ICON_FA_WINE_GLASS_ALT'] = "\xef\x97\x8e",
 	['ICON_FA_GLASS_WHISKEY'] = "\xef\x9e\xa0",
 	['ICON_FA_BOX'] = "\xef\x91\xa6",
 	['ICON_FA_DIAGNOSES'] = "\xef\x91\xb0",
 	['ICON_FA_FILE_IMAGE'] = "\xef\x87\x85",
 	['ICON_FA_ARROW_CIRCLE_RIGHT'] = "\xef\x82\xa9",
 	['ICON_FA_TASKS'] = "\xef\x82\xae",
 	['ICON_FA_VECTOR_SQUARE'] = "\xef\x97\x8b",
 	['ICON_FA_QUOTE_LEFT'] = "\xef\x84\x8d",
 	['ICON_FA_MOBILE_ALT'] = "\xef\x8f\x8d",
 	['ICON_FA_USER_SHIELD'] = "\xef\x94\x85",
 	['ICON_FA_BLOG'] = "\xef\x9e\x81",
 	['ICON_FA_MARKER'] = "\xef\x96\xa1",
 	['ICON_FA_USER_TIE'] = "\xef\x94\x88",
 	['ICON_FA_TOOLS'] = "\xef\x9f\x99",
 	['ICON_FA_CLOUD'] = "\xef\x83\x82",
 	['ICON_FA_HAND_HOLDING_USD'] = "\xef\x93\x80",
 	['ICON_FA_CERTIFICATE'] = "\xef\x82\xa3",
 	['ICON_FA_CLOUD_DOWNLOAD_ALT'] = "\xef\x8e\x81",
 	['ICON_FA_ANGRY'] = "\xef\x95\x96",
 	['ICON_FA_FROG'] = "\xef\x94\xae",
 	['ICON_FA_CAMERA'] = "\xef\x80\xb0",
 	['ICON_FA_DICE_THREE'] = "\xef\x94\xa7",
 	['ICON_FA_MEMORY'] = "\xef\x94\xb8",
 	['ICON_FA_PEN_SQUARE'] = "\xef\x85\x8b",
 	['ICON_FA_SORT'] = "\xef\x83\x9c",
 	['ICON_FA_PLUG'] = "\xef\x87\xa6",
 	['ICON_FA_MOUSE_POINTER'] = "\xef\x89\x85",
 	['ICON_FA_ENVELOPE'] = "\xef\x83\xa0",
 	['ICON_FA_LAYER_GROUP'] = "\xef\x97\xbd",
 	['ICON_FA_TRAIN'] = "\xef\x88\xb8",
 	['ICON_FA_BULLHORN'] = "\xef\x82\xa1",
 	['ICON_FA_BABY'] = "\xef\x9d\xbc",
 	['ICON_FA_CONCIERGE_BELL'] = "\xef\x95\xa2",
 	['ICON_FA_CIRCLE'] = "\xef\x84\x91",
 	['ICON_FA_I_CURSOR'] = "\xef\x89\x86",
 	['ICON_FA_CAR'] = "\xef\x86\xb9",
 	['ICON_FA_CAT'] = "\xef\x9a\xbe",
 	['ICON_FA_WALLET'] = "\xef\x95\x95",
 	['ICON_FA_BOOK_MEDICAL'] = "\xef\x9f\xa6",
 	['ICON_FA_H_SQUARE'] = "\xef\x83\xbd",
 	['ICON_FA_HEART'] = "\xef\x80\x84",
 	['ICON_FA_LOCK_OPEN'] = "\xef\x8f\x81",
 	['ICON_FA_STREAM'] = "\xef\x95\x90",
 	['ICON_FA_LOCK'] = "\xef\x80\xa3",
 	['ICON_FA_CARROT'] = "\xef\x9e\x87",
 	['ICON_FA_SMILE_BEAM'] = "\xef\x96\xb8",
 	['ICON_FA_USER_NURSE'] = "\xef\xa0\xaf",
 	['ICON_FA_MICROPHONE_ALT'] = "\xef\x8f\x89",
 	['ICON_FA_SPA'] = "\xef\x96\xbb",
 	['ICON_FA_CHEVRON_CIRCLE_DOWN'] = "\xef\x84\xba",
 	['ICON_FA_FOLDER_PLUS'] = "\xef\x99\x9e",
 	['ICON_FA_CLOUD_MEATBALL'] = "\xef\x9c\xbb",
 	['ICON_FA_BOOK_OPEN'] = "\xef\x94\x98",
 	['ICON_FA_MAP'] = "\xef\x89\xb9",
 	['ICON_FA_COCKTAIL'] = "\xef\x95\xa1",
 	['ICON_FA_CLONE'] = "\xef\x89\x8d",
 	['ICON_FA_ID_CARD_ALT'] = "\xef\x91\xbf",
 	['ICON_FA_CHECK_SQUARE'] = "\xef\x85\x8a",
 	['ICON_FA_CHART_LINE'] = "\xef\x88\x81",
 	['ICON_FA_FILE_ARCHIVE'] = "\xef\x87\x86",
 	['ICON_FA_DOVE'] = "\xef\x92\xba",
 	['ICON_FA_MARS_STROKE'] = "\xef\x88\xa9",
 	['ICON_FA_ENVELOPE_OPEN'] = "\xef\x8a\xb6",
 	['ICON_FA_WHEELCHAIR'] = "\xef\x86\x93",
 	['ICON_FA_ROBOT'] = "\xef\x95\x84",
 	['ICON_FA_UNDO_ALT'] = "\xef\x8b\xaa",
 	['ICON_FA_TICKET_ALT'] = "\xef\x8f\xbf",
 	['ICON_FA_TRUCK'] = "\xef\x83\x91",
 	['ICON_FA_WON_SIGN'] = "\xef\x85\x99",
 	['ICON_FA_SUPERSCRIPT'] = "\xef\x84\xab",
 	['ICON_FA_TTY'] = "\xef\x87\xa4",
 	['ICON_FA_USER_MD'] = "\xef\x83\xb0",
 	['ICON_FA_ALIGN_LEFT'] = "\xef\x80\xb6",
 	['ICON_FA_TABLETS'] = "\xef\x92\x90",
 	['ICON_FA_MOTORCYCLE'] = "\xef\x88\x9c",
 	['ICON_FA_ANGLE_UP'] = "\xef\x84\x86",
 	['ICON_FA_BROOM'] = "\xef\x94\x9a",
 	['ICON_FA_TOILET_PAPER'] = "\xef\x9c\x9e",
 	['ICON_FA_DICE_D20'] = "\xef\x9b\x8f",
 	['ICON_FA_LEVEL_DOWN_ALT'] = "\xef\x8e\xbe",
 	['ICON_FA_PAPERCLIP'] = "\xef\x83\x86",
 	['ICON_FA_USER_CLOCK'] = "\xef\x93\xbd",
 	['ICON_FA_SORT_ALPHA_UP'] = "\xef\x85\x9e",
 	['ICON_FA_AUDIO_DESCRIPTION'] = "\xef\x8a\x9e",
 	['ICON_FA_FILE_CSV'] = "\xef\x9b\x9d",
 	['ICON_FA_FILE_DOWNLOAD'] = "\xef\x95\xad",
 	['ICON_FA_SYNC_ALT'] = "\xef\x8b\xb1",
 	['ICON_FA_KISS'] = "\xef\x96\x96",
 	['ICON_FA_HANDS'] = "\xef\x93\x82",
 	['ICON_FA_REPUBLICAN'] = "\xef\x9d\x9e",
 	['ICON_FA_EDIT'] = "\xef\x81\x84",
 	['ICON_FA_UNIVERSITY'] = "\xef\x86\x9c",
 	['ICON_FA_KHANDA'] = "\xef\x99\xad",
 	['ICON_FA_GLASSES'] = "\xef\x94\xb0",
 	['ICON_FA_SQUARE'] = "\xef\x83\x88",
 	['ICON_FA_GRIN_SQUINT'] = "\xef\x96\x85",
 	['ICON_FA_GLOBE'] = "\xef\x82\xac",
 	['ICON_FA_RECEIPT'] = "\xef\x95\x83",
 	['ICON_FA_STRIKETHROUGH'] = "\xef\x83\x8c",
 	['ICON_FA_UNLOCK'] = "\xef\x82\x9c",
 	['ICON_FA_DICE_SIX'] = "\xef\x94\xa6",
 	['ICON_FA_GRIP_VERTICAL'] = "\xef\x96\x8e",
 	['ICON_FA_PILLS'] = "\xef\x92\x84",
 	['ICON_FA_EXCLAMATION'] = "\xef\x84\xaa",
 	['ICON_FA_PERSON_BOOTH'] = "\xef\x9d\x96",
 	['ICON_FA_CALENDAR_PLUS'] = "\xef\x89\xb1",
 	['ICON_FA_SMOG'] = "\xef\x9d\x9f",
 	['ICON_FA_LOCATION_ARROW'] = "\xef\x84\xa4",
 	['ICON_FA_UMBRELLA'] = "\xef\x83\xa9",
 	['ICON_FA_QURAN'] = "\xef\x9a\x87",
 	['ICON_FA_UNDO'] = "\xef\x83\xa2",
 	['ICON_FA_DUMPSTER'] = "\xef\x9e\x93",
 	['ICON_FA_FUNNEL_DOLLAR'] = "\xef\x99\xa2",
 	['ICON_FA_INDENT'] = "\xef\x80\xbc",
 	['ICON_FA_LANGUAGE'] = "\xef\x86\xab",
 	['ICON_FA_ARROW_ALT_CIRCLE_UP'] = "\xef\x8d\x9b",
 	['ICON_FA_ROUTE'] = "\xef\x93\x97",
 	['ICON_FA_USER_ALT'] = "\xef\x90\x86",
 	['ICON_FA_TIMES'] = "\xef\x80\x8d",
 	['ICON_FA_CLINIC_MEDICAL'] = "\xef\x9f\xb2",
 	['ICON_FA_LEVEL_UP_ALT'] = "\xef\x8e\xbf",
 	['ICON_FA_BLIND'] = "\xef\x8a\x9d",
 	['ICON_FA_CHEESE'] = "\xef\x9f\xaf",
 	['ICON_FA_PHONE_SQUARE'] = "\xef\x82\x98",
 	['ICON_FA_SHOPPING_BASKET'] = "\xef\x8a\x91",
 	['ICON_FA_ICE_CREAM'] = "\xef\xa0\x90",
 	['ICON_FA_RING'] = "\xef\x9c\x8b",
 	['ICON_FA_CITY'] = "\xef\x99\x8f",
 	['ICON_FA_TEXT_WIDTH'] = "\xef\x80\xb5",
 	['ICON_FA_RSS_SQUARE'] = "\xef\x85\x83",
 	['ICON_FA_PAINT_BRUSH'] = "\xef\x87\xbc",
 	['ICON_FA_PARACHUTE_BOX'] = "\xef\x93\x8d",
 	['ICON_FA_SIM_CARD'] = "\xef\x9f\x84",
 	['ICON_FA_CLOUD_UPLOAD_ALT'] = "\xef\x8e\x82",
 	['ICON_FA_SORT_UP'] = "\xef\x83\x9e",
 	['ICON_FA_SIGN_OUT_ALT'] = "\xef\x8b\xb5",
 	['ICON_FA_USER_NINJA'] = "\xef\x94\x84",
 	['ICON_FA_SIGN_IN_ALT'] = "\xef\x8b\xb6",
 	['ICON_FA_MUG_HOT'] = "\xef\x9e\xb6",
 	['ICON_FA_SHARE_ALT'] = "\xef\x87\xa0",
 	['ICON_FA_CALENDAR_CHECK'] = "\xef\x89\xb4",
 	['ICON_FA_PEN_FANCY'] = "\xef\x96\xac",
 	['ICON_FA_BIOHAZARD'] = "\xef\x9e\x80",
 	['ICON_FA_BED'] = "\xef\x88\xb6",
 	['ICON_FA_FILE_SIGNATURE'] = "\xef\x95\xb3",
 	['ICON_FA_TOGGLE_OFF'] = "\xef\x88\x84",
 	['ICON_FA_TRAFFIC_LIGHT'] = "\xef\x98\xb7",
 	['ICON_FA_TRACTOR'] = "\xef\x9c\xa2",
 	['ICON_FA_MEH_ROLLING_EYES'] = "\xef\x96\xa5",
 	['ICON_FA_COMMENT_ALT'] = "\xef\x89\xba",
 	['ICON_FA_RULER_HORIZONTAL'] = "\xef\x95\x87",
 	['ICON_FA_PAINT_ROLLER'] = "\xef\x96\xaa",
 	['ICON_FA_HAT_WIZARD'] = "\xef\x9b\xa8",
 	['ICON_FA_CALENDAR'] = "\xef\x84\xb3",
 	['ICON_FA_MICROPHONE'] = "\xef\x84\xb0",
 	['ICON_FA_FOOTBALL_BALL'] = "\xef\x91\x8e",
 	['ICON_FA_ALLERGIES'] = "\xef\x91\xa1",
 	['ICON_FA_ID_CARD'] = "\xef\x8b\x82",
 	['ICON_FA_REDO_ALT'] = "\xef\x8b\xb9",
 	['ICON_FA_PLAY_CIRCLE'] = "\xef\x85\x84",
 	['ICON_FA_THERMOMETER'] = "\xef\x92\x91",
 	['ICON_FA_DOLLAR_SIGN'] = "\xef\x85\x95",
 	['ICON_FA_DUNGEON'] = "\xef\x9b\x99",
 	['ICON_FA_COMPRESS'] = "\xef\x81\xa6",
 	['ICON_FA_SEARCH_LOCATION'] = "\xef\x9a\x89",
 	['ICON_FA_BLENDER_PHONE'] = "\xef\x9a\xb6",
 	['ICON_FA_ANGLE_RIGHT'] = "\xef\x84\x85",
 	['ICON_FA_CHESS_QUEEN'] = "\xef\x91\x85",
 	['ICON_FA_PAGER'] = "\xef\xa0\x95",
 	['ICON_FA_MEH_BLANK'] = "\xef\x96\xa4",
 	['ICON_FA_EJECT'] = "\xef\x81\x92",
 	['ICON_FA_HOURGLASS_END'] = "\xef\x89\x93",
 	['ICON_FA_TOOTH'] = "\xef\x97\x89",
 	['ICON_FA_BUSINESS_TIME'] = "\xef\x99\x8a",
 	['ICON_FA_PLACE_OF_WORSHIP'] = "\xef\x99\xbf",
 	['ICON_FA_MOON'] = "\xef\x86\x86",
 	['ICON_FA_GRIN_TONGUE_SQUINT'] = "\xef\x96\x8a",
 	['ICON_FA_WALKING'] = "\xef\x95\x94",
 	['ICON_FA_SHIPPING_FAST'] = "\xef\x92\x8b",
 	['ICON_FA_CARET_LEFT'] = "\xef\x83\x99",
 	['ICON_FA_DICE'] = "\xef\x94\xa2",
 	['ICON_FA_RUBLE_SIGN'] = "\xef\x85\x98",
 	['ICON_FA_RULER_VERTICAL'] = "\xef\x95\x88",
 	['ICON_FA_HAND_POINTER'] = "\xef\x89\x9a",
 	['ICON_FA_TAPE'] = "\xef\x93\x9b",
 	['ICON_FA_SHOPPING_BAG'] = "\xef\x8a\x90",
 	['ICON_FA_SKIING_NORDIC'] = "\xef\x9f\x8a",
 	['ICON_FA_HIPPO'] = "\xef\x9b\xad",
 	['ICON_FA_CUBE'] = "\xef\x86\xb2",
 	['ICON_FA_CAPSULES'] = "\xef\x91\xab",
 	['ICON_FA_KIWI_BIRD'] = "\xef\x94\xb5",
 	['ICON_FA_CHEVRON_CIRCLE_UP'] = "\xef\x84\xb9",
 	['ICON_FA_MARS_STROKE_V'] = "\xef\x88\xaa",
 	['ICON_FA_POO_STORM'] = "\xef\x9d\x9a",
 	['ICON_FA_JOINT'] = "\xef\x96\x95",
 	['ICON_FA_MARS_STROKE_H'] = "\xef\x88\xab",
 	['ICON_FA_ADDRESS_BOOK'] = "\xef\x8a\xb9",
 	['ICON_FA_PROCEDURES'] = "\xef\x92\x87",
 	['ICON_FA_GEM'] = "\xef\x8e\xa5",
 	['ICON_FA_RULER_COMBINED'] = "\xef\x95\x86",
 	['ICON_FA_BRAIN'] = "\xef\x97\x9c",
 	['ICON_FA_STAR_AND_CRESCENT'] = "\xef\x9a\x99",
 	['ICON_FA_FIGHTER_JET'] = "\xef\x83\xbb",
 	['ICON_FA_SPACE_SHUTTLE'] = "\xef\x86\x97",
 	['ICON_FA_MAP_PIN'] = "\xef\x89\xb6",
 	['ICON_FA_ALIGN_CENTER'] = "\xef\x80\xb7",
 	['ICON_FA_SORT_ALPHA_DOWN'] = "\xef\x85\x9d",
 	['ICON_FA_PARKING'] = "\xef\x95\x80",
 	['ICON_FA_MAP_SIGNS'] = "\xef\x89\xb7",
 	['ICON_FA_PALETTE'] = "\xef\x94\xbf",
 	['ICON_FA_GLASS_MARTINI'] = "\xef\x80\x80",
 	['ICON_FA_TIMES_CIRCLE'] = "\xef\x81\x97",
 	['ICON_FA_MONUMENT'] = "\xef\x96\xa6",
 	['ICON_FA_GUITAR'] = "\xef\x9e\xa6",
 	['ICON_FA_GRIN_BEAM'] = "\xef\x96\x82",
 	['ICON_FA_KEY'] = "\xef\x82\x84",
 	['ICON_FA_TH_LIST'] = "\xef\x80\x8b",
 	['ICON_FA_SHARE_ALT_SQUARE'] = "\xef\x87\xa1",
 	['ICON_FA_DRUM'] = "\xef\x95\xa9",
 	['ICON_FA_FILE_CONTRACT'] = "\xef\x95\xac",
 	['ICON_FA_RESTROOM'] = "\xef\x9e\xbd",
 	['ICON_FA_UNLOCK_ALT'] = "\xef\x84\xbe",
 	['ICON_FA_MICROPHONE_ALT_SLASH'] = "\xef\x94\xb9",
 	['ICON_FA_USER_SECRET'] = "\xef\x88\x9b",
 	['ICON_FA_ARROW_RIGHT'] = "\xef\x81\xa1",
 	['ICON_FA_FILE_VIDEO'] = "\xef\x87\x88",
 	['ICON_FA_ARROW_ALT_CIRCLE_RIGHT'] = "\xef\x8d\x9a",
 	['ICON_FA_COMMENT'] = "\xef\x81\xb5",
 	['ICON_FA_CALENDAR_WEEK'] = "\xef\x9e\x84",
 	['ICON_FA_USER_GRADUATE'] = "\xef\x94\x81",
 	['ICON_FA_HAND_MIDDLE_FINGER'] = "\xef\xa0\x86",
 	['ICON_FA_POO'] = "\xef\x8b\xbe",
 	['ICON_FA_GRIP_LINES_VERTICAL'] = "\xef\x9e\xa5",
 	['ICON_FA_TABLE'] = "\xef\x83\x8e",
 	['ICON_FA_POLL'] = "\xef\x9a\x81",
 	['ICON_FA_CAR_ALT'] = "\xef\x97\x9e",
 	['ICON_FA_THUMBS_UP'] = "\xef\x85\xa4",
 	['ICON_FA_TRADEMARK'] = "\xef\x89\x9c",
 	['ICON_FA_CLOUD_MOON'] = "\xef\x9b\x83",
 	['ICON_FA_VIALS'] = "\xef\x92\x93",
 	['ICON_FA_FIRST_AID'] = "\xef\x91\xb9",
 	['ICON_FA_ERASER'] = "\xef\x84\xad",
 	['ICON_FA_MARS'] = "\xef\x88\xa2",
 	['ICON_FA_STAR_OF_LIFE'] = "\xef\x98\xa1",
 	['ICON_FA_FEATHER'] = "\xef\x94\xad",
 	['ICON_FA_SQUARE_FULL'] = "\xef\x91\x9c",
 	['ICON_FA_DOLLY'] = "\xef\x91\xb2",
 	['ICON_FA_HOURGLASS_START'] = "\xef\x89\x91",
 	['ICON_FA_GRIN_HEARTS'] = "\xef\x96\x84",
 	['ICON_FA_CUBES'] = "\xef\x86\xb3",
 	['ICON_FA_HASHTAG'] = "\xef\x8a\x92",
 	['ICON_FA_SEEDLING'] = "\xef\x93\x98",
 	['ICON_FA_HAYKAL'] = "\xef\x99\xa6",
 	['ICON_FA_TSHIRT'] = "\xef\x95\x93",
 	['ICON_FA_LAUGH_SQUINT'] = "\xef\x96\x9b",
 	['ICON_FA_HDD'] = "\xef\x82\xa0",
 	['ICON_FA_NEWSPAPER'] = "\xef\x87\xaa",
 	['ICON_FA_HOSPITAL_ALT'] = "\xef\x91\xbd",
 	['ICON_FA_USER_SLASH'] = "\xef\x94\x86",
 	['ICON_FA_FILE_WORD'] = "\xef\x87\x82",
 	['ICON_FA_ENVELOPE_SQUARE'] = "\xef\x86\x99",
 	['ICON_FA_GENDERLESS'] = "\xef\x88\xad",
 	['ICON_FA_DICE_FIVE'] = "\xef\x94\xa3",
 	['ICON_FA_SYNAGOGUE'] = "\xef\x9a\x9b",
 	['ICON_FA_PAW'] = "\xef\x86\xb0",
 	['ICON_FA_RADIATION'] = "\xef\x9e\xb9",
 	['ICON_FA_CROSS'] = "\xef\x99\x94",
 	['ICON_FA_ARCHIVE'] = "\xef\x86\x87",
 	['ICON_FA_PHONE_VOLUME'] = "\xef\x8a\xa0",
 	['ICON_FA_SOLAR_PANEL'] = "\xef\x96\xba",
 	['ICON_FA_INFINITY'] = "\xef\x94\xb4",
 	['ICON_FA_HAND_POINT_DOWN'] = "\xef\x82\xa7",
 	['ICON_FA_MAP_MARKER'] = "\xef\x81\x81",
 	['ICON_FA_CALENDAR_ALT'] = "\xef\x81\xb3",
 	['ICON_FA_AMERICAN_SIGN_LANGUAGE_INTERPRETING'] = "\xef\x8a\xa3",
 	['ICON_FA_BINOCULARS'] = "\xef\x87\xa5",
 	['ICON_FA_STICKY_NOTE'] = "\xef\x89\x89",
 	['ICON_FA_RUNNING'] = "\xef\x9c\x8c",
 	['ICON_FA_PEN_NIB'] = "\xef\x96\xad",
 	['ICON_FA_MAP_MARKED'] = "\xef\x96\x9f",
 	['ICON_FA_EXPAND'] = "\xef\x81\xa5",
 	['ICON_FA_TRUCK_PICKUP'] = "\xef\x98\xbc",
 	['ICON_FA_HOLLY_BERRY'] = "\xef\x9e\xaa",
 	['ICON_FA_PRESCRIPTION_BOTTLE'] = "\xef\x92\x85",
 	['ICON_FA_LAPTOP_CODE'] = "\xef\x97\xbc",
 	['ICON_FA_GOLF_BALL'] = "\xef\x91\x90",
 	['ICON_FA_SKULL_CROSSBONES'] = "\xef\x9c\x94",
 	['ICON_FA_TAXI'] = "\xef\x86\xba",
 	['ICON_FA_ROCKET'] = "\xef\x84\xb5",
 	['ICON_FA_YIN_YANG'] = "\xef\x9a\xad",
 	['ICON_FA_FINGERPRINT'] = "\xef\x95\xb7",
 	['ICON_FA_ARROWS_ALT'] = "\xef\x82\xb2",
 	['ICON_FA_UNDERLINE'] = "\xef\x83\x8d",
 	['ICON_FA_ARROW_CIRCLE_UP'] = "\xef\x82\xaa",
 	['ICON_FA_BASKETBALL_BALL'] = "\xef\x90\xb4",
 	['ICON_FA_DESKTOP'] = "\xef\x84\x88",
 	['ICON_FA_SPINNER'] = "\xef\x84\x90",
 	['ICON_FA_TOGGLE_ON'] = "\xef\x88\x85",
 	['ICON_FA_STOPWATCH'] = "\xef\x8b\xb2",
 	['ICON_FA_ARROW_ALT_CIRCLE_LEFT'] = "\xef\x8d\x99",
 	['ICON_FA_GAS_PUMP'] = "\xef\x94\xaf",
 	['ICON_FA_EXTERNAL_LINK_ALT'] = "\xef\x8d\x9d",
 	['ICON_FA_FROWN'] = "\xef\x84\x99",
 	['ICON_FA_RULER'] = "\xef\x95\x85",
 	['ICON_FA_FLAG_USA'] = "\xef\x9d\x8d",
 	['ICON_FA_GRIN'] = "\xef\x96\x80",
 	['ICON_FA_THEATER_MASKS'] = "\xef\x98\xb0",
 	['ICON_FA_ARROW_CIRCLE_LEFT'] = "\xef\x82\xa8",
 	['ICON_FA_HIGHLIGHTER'] = "\xef\x96\x91",
 	['ICON_FA_POLL_H'] = "\xef\x9a\x82",
 	['ICON_FA_SERVER'] = "\xef\x88\xb3",
 	['ICON_FA_TRASH_RESTORE'] = "\xef\xa0\xa9",
 	['ICON_FA_SPRAY_CAN'] = "\xef\x96\xbd",
 	['ICON_FA_BOWLING_BALL'] = "\xef\x90\xb6",
 	['ICON_FA_LAUGH'] = "\xef\x96\x99",
 	['ICON_FA_TERMINAL'] = "\xef\x84\xa0",
 	['ICON_FA_WINDOW_MINIMIZE'] = "\xef\x8b\x91",
 	['ICON_FA_HOME'] = "\xef\x80\x95",
 	['ICON_FA_UTENSIL_SPOON'] = "\xef\x8b\xa5",
 	['ICON_FA_QUIDDITCH'] = "\xef\x91\x98",
 	['ICON_FA_APPLE_ALT'] = "\xef\x97\x91",
 	['ICON_FA_UMBRELLA_BEACH'] = "\xef\x97\x8a",
 	['ICON_FA_CANNABIS'] = "\xef\x95\x9f",
 	['ICON_FA_LAUGH_BEAM'] = "\xef\x96\x9a",
 	['ICON_FA_TEETH_OPEN'] = "\xef\x98\xaf",
 	['ICON_FA_DRUMSTICK_BITE'] = "\xef\x9b\x97",
 	['ICON_FA_CHART_PIE'] = "\xef\x88\x80",
 	['ICON_FA_SD_CARD'] = "\xef\x9f\x82",
 	['ICON_FA_HANDS_HELPING'] = "\xef\x93\x84",
 	['ICON_FA_PASTE'] = "\xef\x83\xaa",
 	['ICON_FA_OM'] = "\xef\x99\xb9",
 	['ICON_FA_LUGGAGE_CART'] = "\xef\x96\x9d",
 	['ICON_FA_INDUSTRY'] = "\xef\x89\xb5",
 	['ICON_FA_SWIMMER'] = "\xef\x97\x84",
 	['ICON_FA_RADIATION_ALT'] = "\xef\x9e\xba",
 	['ICON_FA_COMPRESS_ARROWS_ALT'] = "\xef\x9e\x8c",
 	['ICON_FA_ROAD'] = "\xef\x80\x98",
 	['ICON_FA_IMAGE'] = "\xef\x80\xbe",
 	['ICON_FA_CHILD'] = "\xef\x86\xae",
 	['ICON_FA_ANGLE_DOUBLE_RIGHT'] = "\xef\x84\x81",
 	['ICON_FA_CLOUD_MOON_RAIN'] = "\xef\x9c\xbc",
 	['ICON_FA_DOOR_OPEN'] = "\xef\x94\xab",
 	['ICON_FA_GRIN_TONGUE_WINK'] = "\xef\x96\x8b",
 	['ICON_FA_REPLY_ALL'] = "\xef\x84\xa2",
 	['ICON_FA_TEMPERATURE_LOW'] = "\xef\x9d\xab",
 	['ICON_FA_INBOX'] = "\xef\x80\x9c",
 	['ICON_FA_FEMALE'] = "\xef\x86\x82",
 	['ICON_FA_SYRINGE'] = "\xef\x92\x8e",
 	['ICON_FA_CIRCLE_NOTCH'] = "\xef\x87\x8e",
 	['ICON_FA_WEIGHT'] = "\xef\x92\x96",
 	['ICON_FA_SNOWPLOW'] = "\xef\x9f\x92",
 	['ICON_FA_TABLE_TENNIS'] = "\xef\x91\x9d",
 	['ICON_FA_LOW_VISION'] = "\xef\x8a\xa8",
 	['ICON_FA_FILE_IMPORT'] = "\xef\x95\xaf",
 	['ICON_FA_ITALIC'] = "\xef\x80\xb3",
 	['ICON_FA_CLOSED_CAPTIONING'] = "\xef\x88\x8a",
 	['ICON_FA_CHALKBOARD'] = "\xef\x94\x9b",
 	['ICON_FA_BUILDING'] = "\xef\x86\xad",
 	['ICON_FA_TACHOMETER_ALT'] = "\xef\x8f\xbd",
 	['ICON_FA_BUS'] = "\xef\x88\x87",
 	['ICON_FA_ANGLE_DOWN'] = "\xef\x84\x87",
 	['ICON_FA_HAND_ROCK'] = "\xef\x89\x95",
 	['ICON_FA_FORWARD'] = "\xef\x81\x8e",
 	['ICON_FA_HELICOPTER'] = "\xef\x94\xb3",
 	['ICON_FA_PODCAST'] = "\xef\x8b\x8e",
 	['ICON_FA_TRUCK_MOVING'] = "\xef\x93\x9f",
 	['ICON_FA_BUG'] = "\xef\x86\x88",
 	['ICON_FA_SHIELD_ALT'] = "\xef\x8f\xad",
 	['ICON_FA_FILL_DRIP'] = "\xef\x95\xb6",
 	['ICON_FA_COMMENT_SLASH'] = "\xef\x92\xb3",
 	['ICON_FA_SUITCASE'] = "\xef\x83\xb2",
 	['ICON_FA_SKATING'] = "\xef\x9f\x85",
 	['ICON_FA_TOILET'] = "\xef\x9f\x98",
 	['ICON_FA_ENVELOPE_OPEN_TEXT'] = "\xef\x99\x98",
 	['ICON_FA_HAND_HOLDING'] = "\xef\x92\xbd",
 	['ICON_FA_VENUS_MARS'] = "\xef\x88\xa8",
 	['ICON_FA_HEART_BROKEN'] = "\xef\x9e\xa9",
 	['ICON_FA_UTENSILS'] = "\xef\x8b\xa7",
 	['ICON_FA_TH_LARGE'] = "\xef\x80\x89",
 	['ICON_FA_AT'] = "\xef\x87\xba",
 	['ICON_FA_FILE'] = "\xef\x85\x9b",
 	['ICON_FA_TENGE'] = "\xef\x9f\x97",
 	['ICON_FA_FLAG_CHECKERED'] = "\xef\x84\x9e",
 	['ICON_FA_FILM'] = "\xef\x80\x88",
 	['ICON_FA_FILL'] = "\xef\x95\xb5",
 	['ICON_FA_GRIN_SQUINT_TEARS'] = "\xef\x96\x86",
 	['ICON_FA_PERCENT'] = "\xef\x8a\x95",
 	['ICON_FA_BOOK'] = "\xef\x80\xad",
 	['ICON_FA_METEOR'] = "\xef\x9d\x93",
 	['ICON_FA_TRASH'] = "\xef\x87\xb8",
 	['ICON_FA_FILE_AUDIO'] = "\xef\x87\x87",
 	['ICON_FA_SATELLITE_DISH'] = "\xef\x9f\x80",
 	['ICON_FA_POOP'] = "\xef\x98\x99",
 	['ICON_FA_STAR'] = "\xef\x80\x85",
 	['ICON_FA_GIFTS'] = "\xef\x9e\x9c",
 	['ICON_FA_GHOST'] = "\xef\x9b\xa2",
 	['ICON_FA_PRESCRIPTION_BOTTLE_ALT'] = "\xef\x92\x86",
 	['ICON_FA_MONEY_BILL_WAVE_ALT'] = "\xef\x94\xbb",
 	['ICON_FA_NEUTER'] = "\xef\x88\xac",
 	['ICON_FA_BAND_AID'] = "\xef\x91\xa2",
 	['ICON_FA_WIFI'] = "\xef\x87\xab",
 	['ICON_FA_MASK'] = "\xef\x9b\xba",
 	['ICON_FA_VENUS_DOUBLE'] = "\xef\x88\xa6",
 	['ICON_FA_CHEVRON_UP'] = "\xef\x81\xb7",
 	['ICON_FA_HAND_SPOCK'] = "\xef\x89\x99",
 	['ICON_FA_HAND_POINT_UP'] = "\xea\x9b\xb0"
}

setmetatable(fa, {
	__call = function(t, v)
		if (type(v) == 'string') then
			return t['ICON_'..v:upper()] or '?'
		end
		return '?'
	end
})

fa_base = "7])#######aIaUI'/###[),##0rC$#Q6>##T@;*>6v0P5t[ZD*?@'o/fY;99A<H$$m*m<-s?^01iZn42r^>h>Q.>>#CEnB4aNV=B-<+F-NhFJ(*;jl&6b(*Hlme+MSm[D*1c5&5#-0%J$n0i@0g@J1H/<P]U-d<BsbU^>Rq.>-Q@pV-TT$=(>O($%;U^C-FqEn/<_[FHOES($LduH2@Wfi'N3JuB?@DJSm3SY,ZqEn/]J[^I6A#F#84S>-8Mfn0+>00F(1>/.wxu=l/ul[$L$S+HZ?`'TSQRrmF+=G2I/FC2())m&l(wM,odPir0P5##OV8,j@nU=Nw$>5vr#um#`??&M]em##]obkLYX-##:Zh3v;7YY#iOc)MenY8N]Q7fM/[AVm5Rq#$[aP+#OCDX-/Mi63-CkV74iWh#Jj/]tZ4ZV$*9nJ;sM$=(h^QcMEY0=#l?*1#6Y0Z$PSltQZr)oCM-m.L/047I(*Sj1E.nx=BbcA#x[k&#ZWc%XF4'?-&25##u<X]Yk2*#vOxe+M5L@6/eXj)#&sPXN=x>W-vodx',v%/L=x5##vLXS7@6EW%c$V=u2]#x'/dU_&F####o^^C-rp9)MUv-tL/sG&PNll-M+xSfLgXEY.bHgf(G&l?-v4T;-(g6'Q/dY1N7CYcMh;?>#jMxV%jIhk4dvGl=OtG&#M(K&#r-@da%_A`a[si9D:Qt-$H)###:rT;-HpNCON;#gL46n]OwLDiLE^e*N8PZY#d,PY#H09kO&0>F%lG.+M/(#GMr=6##K%pxusWWjMl<]0#%)&Fe_bO_/tNJ2L3Ip-6A^4m'sJU_8G,>##)*-xKt*dGMSLT_-gtx&$Q97I-9wvuPp`Z.q;Txp7kMF&#jZqw0tr[fLe[@`aNN/.v/#@`&U#SRN+T0<-=hPhL=SN>.lV(?#wUb&#(HqhL><+;.rY12'*P,:VCKs9)*^FW/WFblA%?eA#B3f;--%9gLjsJfL%%HtM3jBK-:M#<-9t/OMI7$##nWs-$)2(F.vU'^#)MgGM'07#%[q6W%jjE_/P-<p^05J'.ZRtGM&<x,vXRwA-;UfZ$S@+?.)V>W-YX<wT06b2(av-K<=5v5M6t&/L'n]j-p0N2rQ0gw'iiAdO(L>gLIHqI8uhF&#FSk9VW$s;-5@P)N?b>;-@]Ewp/R,,)n4t;MGxS,Mi[@`aSW&.$H,>uu2F(&O1OJJ.)PUV$4?7^#,.m<-Y;5]))t3Q801O2(gxpP8BXO&#^a*s7c^'^#[@:dMcqs.LPGa-Z2d_-QwaQd+g1k?%2)[w'g$_-6EYZ2r3gDE-7t.>-WEnR8Oc4?.O8F0&gXk9`jPF;-IW1RWq`hQanDdpKg]<Z%34cA#Sjf;-S1NU/$2YY#D,>>#L-ZF%Un7ppVKDiLmM+kLRV.R&7<l>[eoaZ%JZeGMr5kf-S:ek=BsL_]vTJX-3s3kO+WW&mY57#%gTs;-wPvD-xh/k$a^eHMBm^g-#'LKEDqQm8SR&:)>liEIed-Audr+_J(hJ2LLF/.?w`%/Lw(>##e^f8.`_Y@t'sOk4CC_,M&g@Q-XHO,%)c'^#AC1:2Q,^:)aZcQj;](##bX^&#.&Uw0i/968-I1_AM+gxu:D1_AWWd9MwIO&#;h:ENcg$R8$lF&#l,kp729@k=2V/&vt:T;-64^gLhFblA:Xep0#?x,vN@ek=H)###Fm(P-kU)>M_hI'Mlr2+9$.53D7+lo7qALk++V>x'%fJ_/mXuQs%]p%O?8CP8(qS:)w2-Wo/hDB%Ddx58,0nw'l8N_&5BK/6x:HW-ShNW8OC?>#7Rp@O)tg`M0*u48>1I2L:+MFR.5s9)al,Q8*772L=+L,M7e0&v#&v5&K,j&#JYWZO&w7^.?BbxuN,.>%m3A=-w3ukL&`YdMrPoV%,B+3;(b0_-0<?xKiYLO9m,V?%SCZY#G^*-M=$'$.g+'p7c<m:VAEUx9?^oX#HHj>Re,-e%%76gLDcdi9=(1^#-;8F-vF5s-pKWk8*>=KN%<x,vpBm]%#/=R*uZE_Ai,FaN?/P)'7EtM9s@.kX2+@68R7>3D$(^fLa+p+MIAT;-O)oJM97GcMqJ6##fxaS7G09kOk&nxu.#P[&-vMcsrw2<-fV2F&wCh&v#(^fLJ<T;-(=8K'`isR<51(^#KuGp7`8T9VDv4uu$iVk+]trq7L)72Lu7AK*1X1I&'Z-`&r#K9rY=e_S[VT=ucL,X&+H0<-S%[=.1rbCs/Wi-Hg3Y>-K+I2LfX=R*cNx4pKDX-?OdmdFd;EnN?94P:Eq=_Jx)s%l4-i&#(q,tLHpLtLFn;J:ic^d421p0%bb%3Mxc^98nw'#vTtj89Sjb&#K%')N:W8o'%rd29gA,'$1TvD-,?jB%*QhofZUJF.swM9ri%h58fhF?IK%qXu;vEgLGX@`aW#)W7rIF-ZVR#.6NKAbNwS)qL/,YS7mgSs-uT<$O2Dx,vMoIfLK8QwLGBh<.:nV:vos:DtUG+kLMUqm8CL@K<W7+n-Y$#F@3V5@I4(m<-nXZL-B?$q&a_%3M#1#,M89go%YT8R*8GBR3T98'dxJpS%Be`-QC._GM^;S>-:Ml`%jD4;-xcS=uuuVqKO:Zu#L%pxuq&%(;#,Uw0M4p&#IM%/LHCMwpr/=KjW3<k9xma-Z>:v?.dt*_M=aO8&(a/R3<$@(stTE3M(`#tM[D6L-(+*n%M*a58>sl2rEh`=-h>ts7i?2F7MrbKs<&gD8`LTpT>$NJ:$g^d4SsF?-hRiqN&epx:hb$l+)nbp'aNA[#CIIs-J-`B8C<Pn*#]B#$2is-$c+?>#(ok&#RQ&v#Fle&,7N3T[El)Ng#+###p>J@qb<1/q&<[0q3a<1q?)k1q2eo5qYD@8q'cB:qW$<<qkZ8=q$6,>q3al>qEAi?qgRXAqPdsDqpiPFq*V`GqO'(fqv)IKq4)tLqGMTMqgR2Oqw3/Pq4q4QqCEuQqYDISqv7bTqiaJXq0ZlYq8s:ZqSFO]qle'^q7?E`qYD#bqliYbq0i.dqS3C+rga$gq,sjhqTF)kq#:AlqKdUnq(ogqqPn;sqx5>uq1g1vqBG.wqV.4xq$@$$r-XH$rEj8&rdic'r,Vr(r7%S)rH[O*rX?_Frr5n,rQ4m/rIi<5rt1k5rETJ9rqpv?r=?W@rMpJArf%2Cr'V%DrI*:Fr`Q-cr#ZWHrS(dJrx?]Lr.e=Mr8-lMr@E:NrJjqNrV2IOrdc<Pru7'Qr+cgQrBU)SrP*jSreafTrvAcUr0#`VrC`eWro3$Zr1w2[r?Ej[rZJG^rt=`_rQ>3dr>fwsrYL'urvEHvr0'EwrK&pxr[PY#sm+M$swI%%s+iR%s8==&sR^QCs%s8*s=S5+sQ.),s#_F.s9EL/sGj-0sUDw0sciW1ssIT2s/%H3s?O24sJ$s4sVBJ5scg+6suM17sCf*9sZXB:si'$;s/'N<s;E&=sPJY>sbc(?sj%M?suO7@s1++As=UkAsTN6CsfvmCs-sAEs?S>FsS@MGsl9oHs;K_JsHvHKs_iaLspCTMs1C)OsG*/Psh)YQsvSCRs4G[SsFxNTsVF0Usf'-Vs#k;Ws6?&XsA^SXsN8GYs^](ZslC.[s<['^sK*_^sVH6_snVs`s25pas=YPbsW']ds-KhfsVJ<hsdu&is;hiksbsOmsuYUns>f<psNPuusE8a@t^iH,tK<]1tD*>>#ZtX.qfHC/q*Hn0q8sW1qD;02q9'>6q_V[8q+oT:qZf-C8u#Qm81al>qB;`?qYFFAqA^jDqhiPFq%>;GqEXFeqj#@Kq/gNLqEABMq[L)OqrwiOq/XfPqB?lQqOdLRqno3TqeN/XqQtv.%W.PZqdRb]qs-U^q@Wj`qfP5bqpulbq>O4eqW9:fqms?gq:)'iq^k`kq,e+mqRvqnq<7?rqd),uq'HYuq9/`vqGS@wqaDJH8fCV)bL870g3C%EYBKq)rNnk*rbQh+r2Mg.rk9J1rnsv.%c8V?Xm@$EY:d9Lru]6;8&hcY@#t#LB1s7bDGR)UHWdtKKil2bM&1(XP4<sNSs99T%diC'a=nW<cYrE-hnErZk@hlZtc^%RRSCN$XnA<k]+PP*`A6^9dX]R0g5iq;-MC8G&,O&EY#WB-s$pH;8V5ua=rEt3A-N2ICp?wDYt3:5sbg+6spAu6s@Se8satv.%;&$EYOrmI8B_7+k0j^6n<]V0pRH)[tdD]9v,Cjh'q>tDYn;'HsrrH;8q0AZ5wUpMs=O;OsWa+Qsm5lQs&mhRs=SnSsO4kTsZRBUsk3?Vs-'WWs;K8XsEjfXsTDYYsbi:ZsppKM8U.YEt'.WL'6$5+)Bm-%+1)uDY)L6msqG:ns>f<ps/C8G&2&3/tU)h+vFNG/(F?5/(A0#/(=w].(7eA.(.Fj-('4N-(x'<-(o_d,(f@6,([(h+(S`9+(MS'+(=TR)(*6%)(#*i((nT(((c<Y'(_0G'(P[]&(LOJ&(HC8&(C1s%(>%a%(6c;%(2V)%(iQww'Bq$w'7ehv'2RLv'kRxt'd4Jt'T``s'>#Zr':mGr'*$0q'tmsp'mTNp'Sb6o'I7Ln'<cbm'.D4m'b,;k'JnJi'7_/i'-:Nh'$(3h'i(_f'WlBf'QSte'E5Fe',*`c'vmCc'mNlb'd6Gb'Vb]a'<>Q_'a^*]'iF]X'c4AX'X]OQ'ZplN'PK5N'Ct82').3L'n@$K'LAOI'BmeH'o$#F'MuDD';c)D'5PdC'0DQC',8?C'#pgB's]KB'f2bA'`&OA'Wd*A'QQe@'I37@'C'%@';eU?'7XC?'r48='US;<'LAv;'Aa#;'/<B:''$t9'C]F6'5P46'0>o5'+2]5''&J5'#p75'rP`4'i>D4'e224'^pc3'RHpm&1431'i:h/'WSb.'DZ@-')$D,'rTc+'j<>+'_tf*'YbJ*'L7a)'E%E)'@o2)'6PZ('2DH(',2-('q2X&'_j*&'OEI%'@X:$'0:c#'*(G#'i:8x&e.&x&axiw&VS2w&NAmv&E#?v&4HKu&%U3t&j0Rs&][hr&K+uq&3&Ap&xcro&k2)o&Y^>n&O?gm&9Ual&%Y6k&nFqj&h.Lj&WYbi&J/xh&E#fh&?gIh&06Vg&)$;g&%n(g&sTYf&oHGf&]O&e&G%<d&?cmc&9PQc&vP'b&nDka&h2Oa&BeC_&mx`[&]`;[&FNKY&p*@W&`hqV&Q+lU&kha5&#A_N&sB5J&3G8A&c5l.#4.`$#EUwI.5f($#sIkA#)_6B(I8YY#0%,DN6&l4S0,u4Sap$)**WP#$D]-83E<1R3M7)##mAk-$)rm-$i[)##9`###5Q&##7S###[i'##)]lS.Te68%o(.m/nnQS%Gvmo%>(.m/t*35&H3NP&TvhP/f<jl&xD/2'TPP6'3NJM'-Vfi'RYlS.0b+/(%ZlS.VjFJ(wYlS.qrbf(/VjfLDhTnJ*'+1:c/Fk4'$G&#6w+_JE0e;#+c:kFgCm##=SUw0t9/%#:2>_/O_9*#(.t9)tsY6#Q=,.#AZCwK,/A8#qPk-$Si63#-=t9)(^M7#OU$lLE^_sLGreQ-`Kx>-`WkV.QG###]3S>-GaDE-K3u,/Ak%##T?o-$$h*##_Yl-$TmvV.Z>js.urgo.DQP8.x'-5/(K[8/op8gL2`XjL-qwJr#WajL[ikjL$I=?Q$^jjL*0;'>%dsjL#LP',ii*'cgR.eEihPEn(H#kk)?66#:ZO9`F@59#dr:-m'kB5#6[x(#?tt9)Sg]0#Ue$##>a2hL[P)7#_$o92V)9#MJ(q=#[XVw0V[_E[x/-_JNX59#'#V9V4r5kO0MtQNno)kb^%.F%M?E/#g<o929+6kOsSf;#Ot73#)jbmL<=[3#dncjLY1RA-hvR#/Z](##q5l-$at)##R?&n.R:%##mtfN-I^Y%0uE&##>O*##'m+G-;:7I-=Wvp/is+##>E'##`U^C-YKo/0jk%##hg+##QJwA-1;C`.$<###:`CH-ZqdT-+T]F-i7X?1,P)##eN+##B9'##J_Nb.C7*##p2>o.*:&##Rp-A-.<8F-BZ@Q-`j5d.C+*##+$jE-4T]F-5Y`=-EeF?-w<D].`x$##PMXR--+Yg.`v'##4M.U.e,(##5A;=-](LS-*kw:0/.&##$`%##-hk-$BOA5BR*B5BS3^PB*k'mB36C2CUUo2CIb4JC:WjfLg/AqLLN0woc(IqLK)DF$d.RqL.=SqLh_/.,e4[qL1A]qLL3PF-f:eqL/C=_ng@nqLOMoqLDSxqLkX+rLDN6l3iL*rLfa4rL;_4rLXe=rLa0rR`meNrL;wXrLM#YrLe'crLuD=SVpwjrLw3urL14urLX4G;Lr-'sLD?1sL<o3T)t99sLkMo;:a1]m*%_(R<akh--kpN=#LRE5#:(9R*o=w4#,iAgL]DtJ-Bo,D-C%v[.wG$##.Mdl./u*##b#u_.,i*##[A;=-.3RA-BV^C-sseQ-7_BK-%UHt.Ot+##-Nm-$M7)##JMn-$bK#HNaHB`Ng(.m/0R^%O[Y#AOHD*j0xd>]OrlYxOVuu=P?f8^P$1VuP%PP8.O<r:Qb$_YQNF#vQ1E%vQ7]=;RC7c;RWa3SROV]VRQburRJ[LsR5sj4S-PP8.:&0PSnrooS:0woSba[5Ts6g1T1'slTbva2URZ(JUWVjfL8-?wLE,?wLjBX3PF+PwL,DDeR*(2@C-QW-?GC4R3tw$_]II4R3n9^-?<%u^fNl9kOG+s92K-G5#gg>*#Mr3kX^6+_SCH2+#tZS4#3%:kOA&,F.bG=_8%$vE@0$w:#Ov<0#*h6wgk3H9rZ?Lk4?ERk+;w:R*d].7#E;&F7$A4kXucL&#2/IwK0r3(#[F4kXf#e-6tNH9rHoE-d?k#:)-uK-ZGX@kF;AOwBC)k;#uY7hL=3S>-(MWU-#3^Z.%<%##/ron.^8*##;[lS.>%###Qs.>-(2s2/E9)##3Dk-$RD:>dmBSYdi=rudlJ1;eZn3;eX''We4dBoeWVjfLM_Qj%u@H&MRSR&MBDL[-&-eE[=ur&#=JSk+EMc0#AjX-H.A'F7aYo0,KAwE@hj04#8a$:)nnD_/%+q,#)tL-Z#cXtL:s3<#Xeb9Mt88wgQSwE@1ca6#a5+lL*tL:##;p/#IoSk+2+A-mfE*REu#w^f=,-_SqFl--R9M-ZmsAkFW8/:#F5%:)cbPwBtOl--]$4F%t,c3#C`>w^uMY-Hj>%:)r,BkF,&%5#hAu924NO##xxkERKoDwT1'^w0l,dw'l,dw'anr-$??<kOp8dw'x^J2#<=?0#Q9QwBo6W1#TGdw'AqL,#S@kgLa]BK-Q`Y%0U,+##6w)##dRZL-+j?*0Tv*##_:(##cF)e.:o###o;.:0ofF>#iN@>#%qn-$EpF>#oZ@>#6Al-$wfB>#0In20+4D>#I5B>#%Zk-$F(D>#65l-$RLD>#/sk-$I&G>#vXC>#5)l-$Aen-$8WF>#G<oY-)q/F%,&q-$GdS5']SpP'elpP'7F@Q'^^oi'VJ>m'Zp8gL6'2hL[etaac$:hL>.;hL]3DhL`4DhLE9MhLTqNnS$E;no;f3=?F2Lk+:BO1#h(F-Z#Zr7#hPGoLR.SN1#7@>#6rC>#Qi>>#$tj-$^do-$jt&a+Ls(a+^VD&,?V[A,[nOB,T:]Y,hAxu,-?)?-bSXV-C,<v-mn9w-(i98.`pTS.bPP8..%qo.W7#9/j6QP/jgmS/Je1p/mx8p/Flt50fF220Hr0m08MTm0wd./1alO21%-]N1elIJ1Tvef13D,j1b)F/2mRhJ2Sa&g2?+D,3u&bG3v(_G3v/'d3i_)d3dsOE4kg>A4wqY]4;>$a4bmb&5&%vx4(h]A5pYh^5g5VY5,Aru51=S>6,6uY6+74v6-?:v6.A7v6-R'<7VnNS7xVjfLOUNmLvZ2Z[J`#*5/vRp]d>eg<A_imLs[dB$BermLW_gB-Dq.nLGnlgjl#B*Y$INtAu7Ads`Wgt8Pxgh3<I@&cLQFOMOMWJiKEonL<NpnLjT#oL:C*7qMQ+oLBb5oL=c5oL3h>oLDnGoL[N#PVT.CP2]ui+PJ#e].kxuE7i1W9VTx$kk)G4_A;8Ok+l?j9;eO:_8?RB-dX37kO`fa-6n@%&#6Tp92/E[9##Pa*#e*R1#[=ujt';:0#hK/F%m-P7#S<Rw9J(h--p8S.#$3&REGR+kb]lD5#>h^9MAqE2#B1dQj)3i8#vKLwB@T_w'R'*=#L*=-mfG2R3Mj=kFF$e9D)'D8#W&m^ohCdQjn_86#'m1qLGreQ-EufN-0LWU-nmmt.&,@>#>[k-$4?F>#POA>#L5`T.6P@>#KufN-$.OJ-geF?-xp-A-JbDE-2-Zd.5BC>#n.[a.M->>#Yh?*0J'G>#TAD>#?^Me.IsC>#mZ@Q-:2^Z.dfD>#lGuG-Ts:T.EXF>#wxhH-Vu')0lj>>#1hB>#/g'S-Yn7^.:(F>#]bDE-D&kB-V6T;-8)LS-I@&n.&-?>#_N#<-au')00E?>#SZC>#N96L-rY`=-qaO_.c)D>#Vgi*/f+A>#n*l-$W8=5TvZIQTTE5MT7PPiT77mlTl072Uo=LMU9PliUmC-/V?oLJV4XnJV51IcV6rmGW-A*DWKUecWSnecWFS6dWc_&AX+[]`XNx)&YvF@AY(x3BYJ->YYH5YuY./@>ZWm1?ZfH:VZ`PUrZjH>;[TcRV[$.pr[Y)78]'BMS]p>np]2:j1^'C/M^tVjfLRnx#MNu+$M4$5$M'g*tac&F$M>7P$M9;Y$M%Bc$MVAc$MiB5CLhDt$M)gI[`iJ'%M1Z1%M^rU[ikV9%M#Bqtsl]B%MnJ*ujmcK%MuQcOmS(<]Doo^%MKx_%Mjusu3pug%MG0r%M@6%&MM5%&M4,'vN_#Gv*E*:kFUp;R*P>U9`1%Vw9,Ip^oj0w=#;7/kbBY:-vI@3F%gd04#-jDgLUo-A-D/;x.n5E>#cOl-$('F>#>K,[.%R?>#j5S>-<'kB-qaCH-Gf&V-l5S>-*aNb.>9@>#dPYO-X^AN-[xR#/EE@>#V]k-$nKE>#2rDq/fDA>#wuA>#X-NM-vH6x/6ZE>#H7C>#j*m<-(Nx>-gt:T.UYF>#DIau.vZD>#G^j-$n?E>#[Q@>#0DrP-Aeg0/4,B>#nik-$$eE>#?DB>#wvfN-+V]F-i&v[.dOC>#/hRU.SsE>#+>8F-95N;6]4_Y#v&]Y#NXZY#gI_Y#f?[Y#sd[Y#9b`Y#JG.f2QLZY##mbY#UTaY#j3[Y#<5l-$:c_Y#c:/70cmaY#i%_Y#qsj-$AabY#j#bY#s;bY#-<[61o'[Y#'TbY#)V_Y#0$v[.QrYY#G@;=-]#Us.A=`Y#Yfl-$RU`Y#hSHt.<%`Y#4Bk-$Yhb#-eQF;-ZlwY-LF9v-q^:v-3XY;.)WeW.Yu^S.A3?5/U6;T/KEvl/-wv50^M;20UIL21sJJ21>xYN19&of1K.4,2C&K/2pi9K2uAkc2.WjfLhJhkLl4)rAo%]ea1P#lL_06Y%CFYXn&;v@-4c>lL%:9YI+b.Ye91;MM8%dlL(<32Mu;]0#Qg6R*>5[6#pj0R3DS*7#Ls8w^t5s:#Y8;*#2J$&#Z'%REY_i9;8+M=#-w-.#uQ2kLv/QD-a7po3n']Y#HbaY#cV_Y#'L]Y#'J`Y#ln,D-tCsM-$gG<-tVU10MYZY#TnaY#v5T;-PR[I-6Y`=-fqdT-HeF?-375O-375O-xn,D-9OYO-fX?T-]&wX.vabY#IGuG-cJ8r/k4[Y#m<bY#%qon.DgYY#b2jq/T?^Y#Ee]Y#.,NM-+vre.S3^Y#(QZL-gp-A-j(LS-VZ@Q-Yq9W.;2`Y#76T;-YLx>-wJwA-@]AN-jYKk.WsYY#aeF?-@IvD-LZjfLPJ*a.t3'sLsA1sLt@1sLmHf;:M'3H$,IE-ZA`[-?Q@R9`O'MwBKS#_]kdA_/=TD8#rtl/#3.ggL?R*4#2h5_A[wjQaemC-dV<MwB1q,7#6#H_&kp*=#PM[EeT0/1#S[nEIltPk+1X96#:m0F%hEkQarHi--([GwK^4$_]ddMwB(HB_/';t^f7^n,#FfdpLxN(:#K%aw'.)u=#&(iER8bk5#M+aw'TWK&#%cP-Qull2#&fP-Qn<v:#0Yn^o,uV-H)A;3#_9:R*r%I_&8t0_JgbEk=.c?kFHF4R35:W-HtduE@bs'&#w21_JEcZw00Hj;#(aHwKpOk8#Op<0#xn]EeepX%#6k4R3(-vE@-Z3N?uSs[tAW4s$Q7FD*+i?8%_]B.*#mqB#:;gF4gr*V/)%x[-dsR(sZZ1F*;N;E*SiuE(_i(G`(ok(N89uL([r/F*J33O0%4n0#J&###;w;##@D8@-Zg>A4R#QA#dZ'u$xh$lLHLB(4&P%`&'$fF47`Gn$H9Bq%rbm(5lb%wu+.DT.NP_(a>^pO0XPcr.Ru7?$C?F&NWt`V$Bl>##+#jE-R#S33^?O&#swbI)[(Ls-b3NZ6&TN/M-$xh%b0D.3tVSF4PDRv$9DhR%bV.H)#wY#5bWuAJ10l3(D1LCEp,97;7[rX-7+l3+60c01^Fm8JV97>%G,2i1.e&##xuF:v`FY>#])ChLpDPA#RF`v52,h.*dMYx6#UvA2v6hI&4S=(1BqNHEB097/9FO$0HcQJ&H:5qJI$FQ/&G&t%3Xfi'guqc2SCb`*FbwD4O.#,M%ECK*pY?C#@T/<7Rg;E4hG(v#It_p79(dN'uMP;-L`IX(u,K+E9>_tQL@bh(;v?5/>x];)w?ts8@]UtQlE_^#g3n0#J)###h^YfLQ*88%>u###WEC]41-A.*[*'u$ZVd8/wHeF4Rp;+3JO?IML5Wa4L@/[uC*3G<0/wJ;#1G$pB5$f4D[r%,=d)J<q@JfL'nCdMY*CB#(@$(#P%T*#+b.-#[G_/#6.92#mp@.*dZ'u$d<7f39OnA,(DQF%^]d8/ZGc3FYFuw5?3lD#YRlDNk<`eMg7H<-,Zh&Q^[<7Snbw^M'Qfn0%FXN'O3^m&mc?%b':vV%/rkA#o=2=-dudYPZ&6/(7AbaND,8fPQ09k0hTb6&@JVN'dD[H)0*4Q'^56.Ouj1oeSHAb.?-Bf$%$0w&P?am]Y<(&P]me(#'/###[,=##)9li'r)#,2c6%##=g8gW<#DP-fVIm-n_O]'^Pr`3u^i%O<I9]$hg7dM(j(B##]&bngkbP95kr8&0O-EN-Lnl/;F1B#'3+HVDh5J$pus$OLA9(Oe4$##AMor3tD-(#chc+#M)1/#8@T2#`:XI);3a>Mf#lI)xIWx'u^0`P4m-K)5B/J-97dDN<O^=%'q6s.l4c;%[b5s.F+LsRURv?&3fuS.G^*t$E5^gLFr,)O,v_>$jtTDNZqa>N39_6&]^+Z-EL9r))fHQ'^wHd'b.Rx-+BB4MA>^;-&58b-#2R[')7P:)`[Ep%sb]U)Y&UF%Ju+2_jx,V)7ZS.-SUH.-q3n0#YU4?.RpH+#ekP]4%p9q7?iK/)v?a<-V0Y[$t7ufM,j(B#w_&`&[Vd8/s/'/-8T+BObm)'8gb.5^'fkA#?`c8.^@e6&g*eYm2a8(O0HM28iSX]YKprA#`f?p-L00`&w?<rNR]?9O0&KV-%f1p.PPViKZn#qr#UZd3w0`.3SiY1M-FcI)S(Ls-22'9%mTgU%L=Zd)5*j<%oQl)*E`j)*/bY,M.R@T.&`X]u&,Xw9L)>>#@#]H#::3jLA3gO9xP)<%&Y@C#B2()A^YY$&g7BB+SST$&gm5r%Idax']lFT*+0Q_/<]F#$3C=N0tcZ(#b,>>#Qc^KMS,+Z6xck-$b-YD#Xc1p.QNCD3#a4OO[M3e2n`aI)q.rv-0S<+3CL0$5*Zk-$DhNYdfAm302XHr<OC;+G*gkC/4>w_uxn,*(q01H)jxkZ-KwURWx=ho.%A<RW(eQIR^)2n&V;*nO%;D<MXi68%:I:`sd/020ao%XLrVPA#vkh8.T>%&4#,]]4:*YA#T35N'fL0+*I5^+4(xkj1Mnpr6=fOZIwE)h)sG&(5'MQaG$T-@-VgY/(B?l/(e_>NB6:)_.Ru_;$WbPRAf]V8&mh%T%MES+.pj8bQE4C90vJDu$U/QV%d+P?,r2949WY'X/D-;g(U0SW$#>1@-o37m/(AP##Sj6o#PcnC9P-sG<Hx6V8['Yvej:Vm9BH*X&SOqkLu*5[$r(kJiC_39%P>^;-%m5<-<bcHM+#1sNB429.?3w`aCF0I$bf69%>/TgLkhB.&8bfCMs_>;-xt4R*H'mTM:lA,M<Rrt-b+SfLppt&#%/5##Kg$S#*TC7#Ni8*#fVU:%fZX,2FsHd)lh)Q/X985/e;<Z5[q'E#1n>V/CV>c4Zp?A4PD,c4NIV@,*<7.M(=L+*P?T:%19aB%Q/$w#iW4T%?>Ns%h6ss-xdos$ge3p%(f`M0@3Es%aq7Y-[[U4+_HSs$M]%12sGCI$=OX<%df;o&me&m&mv^d2d#u=$<0Qu%wp<U.EE[h,G/L=QuHA<$ZL+N16VP/2:oYH0Ylc=l^?0GVC_:wg[0`.3kcpd4-c7C#x)Qv$pUev7<Nw,*]nr?#HXX/2I(_GNp*Ar8C,>)4O>2N0HwwS%Ep99%&^FgL?K)?%9b330^DKv#J%.W$SY@U)Rv^;$I6Xx#URHt-A5CW$if(?#A?^lS7v/6&+og--gxAmACb39%Lw#C/ujpY$B6sY#ceFv,,rjpfxA2R:;:@W$15n0#mrQS%;L:`s99=8%@%$##<IcI)PEZd3s19f3h<7f3xaok67#WF3JW&EfQ+;mQ-pBs$85u;-0LvQ894.<$tj>U)NOW8Y-@6Z$e`4eZV/rn&U0r(#xfo=#l'^E#qFX&#@]&*#eM:u$Pg8KMl0k?#/?Tv-u$:C4%[-H)RJ))3>'IH3'xr?#0%mW-Q7oBJ$s,x6eBOU2gf@d)^sOA#G.c>%lXGf&&LPB$Tb]#c/wD#PNrF*$w#[iLrJP6)3Oi>#_]2w$`v+F%^c<^494@s$88BkL+(MT.5$APBPFl97b572(9'DF*5uh;$X$U41=CIW$b6Cj$g4&x$jgtG2%`X&#nc<L<n,9%#,WH(#r$(,)gEW@,KkD,;q4n#6o:gF4s4hTp)4L+*:,l*./';3;,aBW$KI=+3e'SN'F.tp%-#Xt$1G53'hn')3kEFc2SQ^6&w9$O0V3pD&usG0(BWtH;(r9B#O&Z#Yq`OkL9s8%YnnK%OpK+kL7B%o'1v=*E)?r<1vLX&#R3n0#;`/E#eS@%#grgo.Y7fT%;opr6VHL,3]qe8%-9xb4cJ*#5Z?/[u&QQV%YeL0(B'gQ&jZ`Ih/N2&G6#2]e)f/U)F*;LL84Sh$HwsT%Ol;Z7&5n0#Wf68%DBW>#w05;65=/F,STlD#FWeL2G27C#-d%H)*)TF4KjE.3oi&f)ORIw#LE%gLxPPA#r83i2L<DB#+Iw8%#f?I$b*?JCTNKN:Wgd*,.G`;$QmT#$61bN1rYj&H(^j*-q/H=$FV?`a0VU02Txb;-^pJ;D*YffL7nJs$]uwL(&Wnx8]0U40=NbV$,5YY#BOes-$bFoL43l(.*^_U8WxBwK/jx<%x3vr-=2K+4stC.3e*H#$`,@[01B[B#a%NT/><WL)2RtEcC]cd$`2c^,;mvK%?a%*Nl/AqLW5+5Cnv^d2uvM'O-%>K.7V0X'3@CB#G=vP2Lw(kbi@Ig)[LR#M(#DHMF.43.6FHgL.Pmu>U'Vl-h6b@'u7Y/MxLL<.*c68%LNhg1Y3=&#(WH(#X=#+#9jO59O#tY-Ec;m/`c%H)+,Bf34r#<-/^bK&OOOa&s]3pu%]r%,[.PwLNT;rZVDG@P5b`b;%f(c%i+7X1O$H]uP9mA#aKC@-x:`5/P:-n&.#wIOq%3/%`ahR#1V)edcoi,<lRP)4#+ct(.N8f39`p>,8#juLiIr-M5`CJ)mMmd?Y3iS0JgBbaBC0I$29g?7^8a5:3MoQ04R%##,V1vu<4>>#bf0'#8Enb48tFA#hCh8.[GUv-h,U-%],u6/F^PH*nfjI)+x4gL*ajD#[21q'u@D>7^+Uu6*q10(vgEu-r)YA#M5dNDS<^;%LXAe(:B*H*RkuN'm%<X(%<lA#Ydo[#E?pm&4qno;;sAg2fB?eMxAs?#>xQ<-/::#<Ai,12;1TV6orX>h/G>N'V%Le*CWld*.rIrUkVHhM07Rt7E-'6&qNn8Eqq*=$OP4T'KGVN'^YJFG^R*s-pn8<7m?lJ(HwfqLFn$##w%5##eKKJ(m(8C4t(4I)1OTfL.'vl$JTjZ,bM%pCNqpkC`?'n&H/xA(L1vV'+<UN'8O^-6nV@JL&*V;.<*UI*]*'u$`S6C#P;Bf3c:pr6*)4r0?3Z(+^Z#r%[%te)5^#K)4<D`AHnA308koW$RKXX$o#pW$M%Z##B[X/15b/E#<6i$#3DW)#I%vG-ke:d-EA9tS4_tD#qcl@0xg;E4$mi`3fGBhP$-U:%>]x20<g,s8ki8H)]:LW-,0ai2O&RH)UI9t%Duh;$l=ol'l>qq%MW^U%_)&GePB(U%-*EQK^n-w$QNbX$=PAX/BR0Z$eLEAbKAWu$Ls$-)0Yn21XC^p&REFX$a2?xQ[Oft%YfY=l1k4GV-l68%=wfi'M,@D*nBIP/NO$##Tn.i)sv@+4q#G:.sTIg)Cnxw'O+]w'LLT;.^8gG3;fG<-IYlS.%[_5L5=^;-(=R20pS&pA$l]^7=QOh#d#MX(40*gagT=mLgf%N1DaoH-:Z=2L.EG&#a3n0#I2>>#'SI*.9E&,NXs%(#8pm(#HJa)#C@+F3ss5k(PQgq%(/Xi(vTw0#8(Q_+08pr-2H[.MkZ8@#4pD9`o)pk&r8w%+OB@vnF%7%-u%Re%qPW?%.UCJ)<4,0hpE7d'RCe20^Cs%,NLwhe7J`$'Wb9U)GQcofIrI&,IIH]%3vC`app,D-E*KK'CrU%6c7)i:1e)[$$d(T/ITR12PH+IHkJn^NCs+G-GFJb-O?xHH*e.D+vhItL&c+XLL#&hLuKB,.ei]VM3DdwLwH3p+%WC%M2Ko<:jfO?.qcc&#ccGlL=IC:%Fm+l9c9G)4A?3b$[g^A=Q,/(m9W07/Q0A0uO7A`a;:3p%HjfI_93dr//cRN'ib>/h<BPD3&;>Yu:l*.)F`Q9%vJcT%VdPN'86$X7F&`6&]fRs$^0SNM^q6>#;7?C+7),##:aqR#fXL7#B6_c)w7%P(&OJ@#4'6caInS^)o?/[uov&##;3TT.nd0'#<A8D:Hr7_6nM6.%1ReLM>fYA#1T6&4_wl)4Ytg;.xf5qp@M-r+3q'H2Xf?%b%iA=%*7u.)Qd14'N'DT7ho<vL%AjR#$3vN'FS,##0X3D%:/X<hgf69%uQwJVB#>_/7C)YPG&E(M'S0LV7$:<.H%vu#GpYm/`EX&#N,>>#V&/n$I'b8.+V'v5?eB#-#a-n/0Zc8/m[x_#U-US-/]Kp6C+T2'xl6w'PD@<?x%l[9#'D6COI;h3&aHG2RbUe-/GgJ)x;HN'l*%X-c%Yh,UEI<MBoR(#'&dT%N^>G2'&H9%H7<T.TN><.>$Ma'A23,)%#2bRK<KR//-8S[C_39%1o/I$bO&oS:`[@'FEt-$x[xt%Ovuan/p<s%<'v3+a:sV7-9.'4Oe/3'$3tOS8q#v#lFZ=lJ`2GV3pFLW9&P^,4e?HbPd/O9&`Y-3nh)Q/))TF4]X1N(Wg<n02w[c;dh%W$W_F^MI;U@/w''%%*O/5M4jf=-0:9Vg%<Id3Tq'H2b1SfLreqA46mg5B9h4',R2;j1`v&##$&>uusB;mLmE4jL(rXI)Xq)v#o$oRN=dVEeYnQ420;6W-s+.`&X#juL2N@%blmk6sq3n0#09j9DbUVmL/Ei'#Apgd'_`c<Q?+x9.F1A.b)T()3=vP5&`m,P26KihLT$IF<h4J'J(`(0MPAm<MSs.'5_0V_#_hET%4Se<$9%BQ&qh]%'E=t*&AnEs-H@=WOS?UkL3k#P0CGH:%#%'a<Rv:xNFG.2.XH#.S[q1=Q#mXCP7`Uh$TekD#ZRfOVFPg.*T9@+4$Ml)>Itqd-Eq7K<2UkUIfnpA#d6xI-EQYO-A'uZ-Ah87akT9b<TLO]ux7'7.U1Qm8DB*X&*Gwe%OI_r069EYP_V(i:^.^G3kRb;?QGGH3EUET%^@F,MCYk[tv=LMUU=T]u-N,W-YO3`&_MLW$tv@jLI7-##v(uv.N46>#MmV&#xU8g%kgjxK2G^f+bWAJN'`>X&#6MG)2Q8c$%i@W@;:@W$h[^;-:TRJ&kw5B#Bl;m/V*1I$#Sg%OHkY^.>a.K<l+AQ-krsv%*XNW-#/EdFIPcd$Kgk&6^NT`&o9KjD8(u48<DVG[hL`<-V0Eq76%Z^$[Uup71472L`=1E&RGY##l5At#dZcf?%.CA7;tCa'Pb[68pV%?n.=']$@slxPj`f@%'V0T76VkA#ms7Y-lXZe$C<o'/00sc<d^mA#n%H<-xv><-hTuP(u8Z;%Ra%jL@<+;.(PUV$P@Wm/Iqn%#42<)#ku0[%&tFA#1t8Y_[Q*aN]*3+(u$PvepeEwA?`KB%;xgl8Z`-U.uWET%+P^;-1cD21@2sM'BiHT%WGhT%7g-J879%D&5l7afbBNZ6Xt[%-UsB:%CL,a+C5b;%FsrA#XeS#NDWY,M^&*gZn)5s%n2w%+CF*<-'9i=%gW-x.14xC#k[r%,3GE/%[VYt-pF(J#n0De2Da,8/S'JwuS)?R&cV(##VWj-$S/5##_-ki']Flr-M#_B#6=F7/R',V/2Mo+M7m4<'FPM[-Qx_JDZVx]%IXTY%QA_$7A:cc-`VNk+(rT<nW18>-#lhl/$&>uuf5wK#5K[`%NN-i1t:gF4?DXI)C=[s$G9*Y6xA?3'R0k3Gak$t-DVi:%Dai>?`&5u-d.9+Gd_i'+`@/Y.Su)$#%Wpk&SJ###W,,h3AI1a4;X^:/YC1Df'ZoAD?PhR;-,MT.O&%xSw@hL2:aqR#F_U7#U?O&#W,1#$kC/r/F.@x6p(b.3Z1IA-3I+U%MDRv$0#bqebO7[-PvSb-Gdu9%x9Xp%.SN/20.$68ceqUAi-^j:eu'=/60Yj3P=DmLUxQ[-q]Xj1f####Y9-5.SE;mL<r@p&ucQ]4;NHD*P=.s$>`Aa#fXcI)iHX,25q'E#PaGx#,+sG;80*I-BEQJ(3wC,@jL`k@;ru>#e1b>Ye])<%;'Xn/)s7p&.OmZ$$n]f$-OJ@#U@Rs$:lnrm(po%FoeKGj9Y.R34MYO%lu7p&+(lO1^4;Zu[Z)m/+P7gU>uQUpbp4X$eJ?%b5#k(#eR/&v+6wK#4N7%#*PEb3YZTC,HX1E>,7YI)]6&W70?h#c6Ocm'OMl)3B3d('MFPE't7sILaYgm]b6JfL<S?uuw4>>#t4=&#%]#`8st[Qs&Yhp&i2/&(DA,s-1LixL1X[6/O[rw&=::wLHBn9M^L@%bfv<2URduS.tZYY#/Sk;0EXI%#`/[d31+9XUVCA`&kQ,n&*OQL-k(;T.RRD8&r@gOMg3FnOP1$##?'e3_Z,v:d.D###$tB:%,^NjL`9-J*R3;c*aO/f2d`?g'F_[d'Q%/GV@[ugL29TC/schR#WvB-MKv)oA@BT:^-q?K)6J)T./rU%63heq.Dh+%,0E9I$'9PF%Gx<#-d#G<-(u3G%L3VhLeBr]$Rk4GV<h+t0[F$m%9UaW-Wn&dtM/i#8LJ8'f0ik(N0(f)*A+dW-%Y7B-mBp08bm0B#AB)4'fXlGMNGTd'tA3I)Yq)Z6W_d5/V&>)4wli#-o:gF4o9i^o2vao7*5(B#qZ'*82wj-?,$x588=%`A2F$L>^*`B8rw'B#Q7Q>8kUbA#jqOd2%2PuuR$?V#9C)4#Mqn%#&xs'Q'PgF4k&B.*%T0<7Vb7%-dqh8.ZO84'nMM-)r=SfLqJk=Gw%CU[p.YT[[maV7++2.MwXYC5qXo0(4n*)#$),##%@mV#:#Q3#h+FcMS4W*%^S*5A/mY<.^GB:%H(@8%6.5I$=8`$'9VT2g,CWt(Boat(>wZ;%M;3;;I_P,M]P7C#)=iGMOcJ@#?tBC-Lilt8nDT;.Fj^W-I;va?AGUv-;`tw5%L$&%Xfb[?%55dN%'2$5575+%GZt;-e]MX-,gF?@B#b'O7OxX-sc``3Ew^*@>n2?HDE,n&Xn,*N#68DA'NgpT)xMe.<de12c.O$%mNXA#(PP8.;cJD*T,YD4$vsB#xmWZ%esbp%1bHgL3QN#P;5sE-V@]+Npe+O'AV[w'+$t;-`i_p2pt_qQ996Df#[2n&<,$6SR6g*%rtV[&9n^q)a4T(N_XNE*L0;.Mmpsw&,m?8@7?@m09s$f?GZaJM8*[x6K]B.*Ynn8%Q6FA#>52T.x?7f3m^2M%g^CsARqOp%bw8Q&cGiK(sYRh(7M/$5-nVD+x^]a+[JX+Nwg2]7Tj#;%PHT6&]Z>3'bClZ,R9,n&O;%1(u8X?6=vkZ-lPwTM#BKm'9>-^ZoK>a=>rcG*]7PgL1Y<78@^JQ(*bis-;tV)+UQ,n&lVjfL48.#8;8T;.S=8*+O*Lo&cjsa*Qr2d*TZ4S2;j6o#:WL7#F[P+#Ksgo.AB83/`7.[#RBcZ.$S7C#e_'0%h+]]4EDb_$'TID*@b1*Ne/=,N+@j?#xo<F7w)iw0$>;u7a[?C#NLlZ,/4$o1T^WN94=[iLn^DKC%%bN0O+s;&8XA30q-2kLFb.q.w:+.)aA[q)KRVL3rk?.NBFo/R>`3B-%0IA-4X,28H.]5'rM>5&,N6C#f:&A$%&3D##Mj/%47^jN*/65/=,1F%k(HP/7C/Q/u4?6/s`T(,$ctA#-b&O=Q,Guu`BmV#+%Q3#.,BP8pSY8/IiK`$rgGj'WCQD%Ow%],>WQD*^eWAb70PD3]W^:%Ok-K#ijuN'1YClIDT?)*q)VK*(&dY'f>QN'6]6IMV>$##w]c%b@nW/)O%h`$:(Rs-V6w+DU95H3Ec7C#JO&b-?[>[B<$eiL%Nw1KNc^Z$lmj+`g(N-d@?b<'26Nb$1QQJ(B>q8.]::8.jNjiUa&U,*mscXOpG?>#^l>xkqVKJVKS8s.6>[m/iE(E#:*YA#2UZ&%$)Zx6Y&UESl;b7Q5ls;&g6k20Y:G>#</4&#e0Nt_`)mD#`uJF*?ljj1w-@x6r49f3k24`sE#W)'<l503av-d)Ji__,&n/i3N`cY#5D6mSLl[<?sV(P0SmdN'qR,81)pB*+7;>r'w,RwBJ/###7fZX$()PV-CnCP8bw9hL)JXD#*jc5/#mqB#DK)f<[TC_&Tt;8.C9iU@u)wY690x:.r3_=%iZQ8/QG1O+$T'i)oD($'c()n/]S7p&:/ugLYIhu&`/#r)vo@u(QvJ3,ox:mXv;fGMNQqkLl3,1:aYMqMWeR/:Igk;f?,B.*8(oGt_SfF4k>a$',*9WNmpQ=l<&?eZw'`caIvoq)#JB`NT&=+Nu#<Zui_9`M)1'_-2%Ee+pWlA>b`J7h-L-]%=oaj0Lk*.)6j64'I)u<Qs)u1qdlhk+-/4'#vXL7#VNvaNC.vh%j>#:;1RvcMMuWB-wX15/7C@wuUVc)M5c6lL^8QA#B.i?#+#K+*x3vr-;'B8%*f@C#kK(E#<)m8.;j:9/DgKs-$Pd4Cv]Zo'c^R1&E'XX$#Hg.$d<<6/@o(v#MMUhLfQFp%9MvO+_eE9%pOU_Ggqhs-6NG#>BouN'+>t%%1=`9.-v31<x>j63<p+Kjc9W$#WN./&f#J32;ZNH*PJ))3?[^:/8dEv$Tp$H2).N`+r11^%tDlT%u6G^$rfQ.%GrD'MND$8/-gbQ&kJw8%,_?^4r%.GV6U/2'5]3>5gB%##)a0i)>G[Z$7d#K):M<r9WfK$&1W8f3*^B.*Q'UfL&+YI)WZ-l1x-,Q'W8wl$xFl/M#4P>%]M<C'MD6`aq+S5'EccYugp$-)Ef[a3Y2Pb+YS_V.EMiUm%M:j(clNE*B_gF*r$%=-qm2=)/N2tL;Pq2);;Zp%;;^:'-waU.kM?W.ZN7K)`SAiL,Df312.7T.I,Guu6Zqn#?DZ)%w$UU@L[2w$hHff1HdqA$#J)W-)vJ*[xJ))3N)b.3R?BSSG<@g+4^N&+T_Ep%R8P:K^fU_%pK3g#dLR42M6V,)lCx/<pkts$&=Ck1^c&'+]Ygw67?HN'?VHt$<Z.70njFc%/IVV-JJEI)olo5AWhG,*v>^)4b_pfLBnF/*,smh2s0tNGSH#s.<[-0)t#ut$)7rs-q6#,3S4642OC<P<n/.n&vt%8/?R%=-Pl%Q0IHh6&&5>##YG`Qj5@KJ(laAJ1_tu,*mm*C2BS7C#1m+c4Uq@.*s4^+4LKk;-_ux^$;D,c4#[2U/F`J&$Do8H@Ax/,,NwZS^@f;)>C,h+>M>l(5gT:m&mYmr%lOs/(_JbT13v?F%A8?<>(X+?-6>Z50GT6n&m+81(<QV6NVU>#vh>*L#k(b+.#%AnL>bob40<Tv-&9K(/qd&],L7X6D.VMB#G7[=7kiE.3.Y8a#ae_F*1Qj;%GL]f.vBo8%:S,<-HThV%KARI2T=)?#]pva3fm3vSbhfM'#)hP/uD''%Gq*T%3$*l]VF[2LbxTi)cI%8'kD9U'T@LC42^,p%G0%'5/9F20bn%oL?;&A,O@^>.=Mju.JXVv#%Csb%p*YK(beAe*sc?D,;*'5)up/W$-'g&5j^Ck'RM8'#uVo9v[v.nL,$3$#gYFb$A39Z-a8t1);NkR8w5R_#L@i%,$$W`+hGI$5Kgu/E'VOa*GNp@#HMS[uBO$Y'E#5uu)f8X7e8KM0VB')3)_Aj0Ph<Y$S$<8.[Q.U/g3YD#STCD3[t9a#AQND#Qd+<8xxkb$*mcp%>Tat0auiW%n^W>-cAGb%-<9j0irH>#uLK58F`OI#N'gU/MvW9%reLm&b=-`%rQ&AZ7%Vv#Sb4$ph0axFCWMs%Qli^obY3>5e%m%==s&##qTQ;@GF5s.:ZY=-=TwhLEJGA#0@%lLxBhl%^CE(&Ux]X<_j0B#NP+q&Nr62LKb-C#MXx[uoMII2Z8Z;%I4*Y$m?5/(Cr0%,3op'8Dag;-YMH<-a',s/_f<J2C_39%fBP)3&,###W&X>#2m-,)(Aju5;8q2:#U,<.WS[]4Dav]1j2+Z6?-YD#'r@8%R9S,X24v<-mu)LA&+o:/ZDhR%NgeZ,XocM9w>#^,G:Mw&/Qu$'8_W>-#<s]Fh/GoLPUn`,+Fn$0ee0H)e4dq&UZA,;$RD3(Xtiw&KmL_&cGwfL=;KT$)Esc<Gnu&#$,GuuEg7&%,MCL3;;Uv-l1Ve$>$:a#?W8f3g&sDS:M3u7wJc>#YFc$,Y'0GV-d/9)afhV$1Q8.**M[oL^p+O/O4>>#cs0hL$bb)#^>UHOD5B.*dsUO']`*Z%2hn,33Z$E3&.Hv$N-+V.T>%&4ch1i%SS<+3wc``3o@cvL%[fHDPU7s$42CW$ai$.MC0F7/=l=CH:MsnL#$g8%vEU=%]TAW$W8te)6^9s$>Oe8%HsUE3-;S/1$$6,6u[5_$hFw8%iPEe3/hD[$+,>>#dGiu5&$329hM/R.xLbI)dw7j9%?Pd3w0`.39F3V('b_J<PZ);;G5Cs-tdtl96w>K)[(Ls-Em9C-s8=R1(Duu#JA22Ku1TV-%jCF,[hj=.Fe75/'(#[$i<s;-+q)'%Fp4AFPX9to]wOF33.hVCUquJCCeE9%$$6K`OT5R&>o6O&?+A['WicYu1e#hL%g-X.Sg$9%tUU51h<Jj0QS5R&8cmAk<=B_-:o[%'#wcC/W3Fp.)eA`a@;H3bA39Z-N&B.*IVI@>8D(a4Ml5<-=[X8&<uSfL0REZ#IF%[ui^82'D:.s$_rH[-EGAhLmN@&,s]RN'ULQ_%<i:?#ucIw#Qm0j($[e9.>tmG*t7Bb*Qq,@-E]cV'UdPN'vBQk(9T%RNN5YY#O*[0#9Q_r?87H?&bpf@#4E$N0%]r%,o<5E#HLHRAjS/W7RlIfL;bql8_-ki'65`Kcd@i?#ZVd8/MPsD#=XEs-80kH;F%JI*gEW@,W-gP:Y0WZub7b9%/ChB#$HMZumOD)+QJ@b@r'.%,]@M-)$-9I$O(#e)kT1)*G1rKGLLKfLxKYGM3/,GM4jTn$60tKGv[e<-jMvWHmik?K-lh8./`&H>sPA3/<)]L(>(8K+X<JW$fuPW-.)&W)9;`p%c<Fc2G]cN)W<JW$+4xJM,S3+&vd(:)=FR]c6u/I$e^b8.?$X`<.Ynof0>i`&CeAJ1@@KV6qa%##jL:hPI]ms-_5L&=O2v<.C3lD#TMrB##>:8.T[rX-P[eQ2sTb4:eJcd3,5^+4nc4%?SnMw$(5IC#f]r%,p]-6MYGm;%W'<)%q3c#%4Ju:$)JZ+%'I(X9iE<*>r0P4::-Cq%c0FwT/X1B>hJZ@-CUws$N=9mA.)Zp%(k.T.N>%+M%eB6C=01lL_j49%ZgGN'tr$;%QJ-<-Yx<'%2lh8.$O]s$CQ?[$)i<N0i?85/w?uD#^JleDt>Sj0n@6##JMt0(stvp.r[bQ'a0TN'ZA$-2UgZ3D4i4',#36/(Gbv]+lVQN'7^0R'75?9%-'=J2fLVb$q27),)Yqr$2)qCam@@]bL3DP8:*<VQrk#Jh>kM]F4_lS/'U-9/x3YD#G1E&&+9LT.bf^I*31ai-f85F%6[X,2h<2-*Zj:9/xO&Y(;-(kbE(6j1g4#,'5nK6/35-J*:wW]Fc+Bw6Y?&s$Wc]Y,xjFAb@&7##Lghg(FL*T%NN5R&-Pc>#N'k5&=^OQ'LR*T%R]pN,D6'7/jvj-$8Ol'.fCLW-x9mc*&%w5/'D(w,wVv3'fZ1K(r.1W-hC:<-x?))+&(*6/Z:[s$TDOgM;JRv$u6I)*g8JIMS3xo%]/[ROOCH>#D:R8%MBGN'[5rg([^Gn&M$Km&FBcj'A-Kq%@e<t$=$FR/^,HR&VK^6&?'7$$&;+s6u$-K)&*(<-U@.-))Qh6&w-%t-A=@8%An&U%w][L()0fa+rt$=-c/H50)Nh6&u'rs-0td--bI3T%i+SH)uQj6/_#qS/iO]I2ssuJ(t'ADXmj/6'M*Tm&i>@:MX_2k'#^p3+_M4oNX5YY#Xic=l_B0GVb6ai07-CG)SaUX%HV>c4>;gF4@]^F*#BPI;ak*H;lYWI)@FNg>Ab:k1,GcY#qja6/Nuo-(Dr$W$AMU@6K<@i(#UEM#=X2588e](+1lh;$aNZH3G<7cMh'X5&cBh41FdwX&lR:l2vxm]Jf2_B#ZWL7#1,>>#j_@T%*#*D#muU4&J'=?#p>Kt8>VCXQmN$$$T'DeM->?uu=v5tL_S`'#iYl]#(_Aj0qkSH$<8Uv-#$U;7EwBsH;36p0iZI*+#n^6&ru3]#Hnn@#IIhH24J]9&J=D?#K/*Z5ePT<-,*QN'k=OG2^cd_#Pba6&bqStHDYp0M$ZiS@A1Tg2Hqco7a)L-%)J+gLuEM5%d2Cv-wHeF4n[>l1D4NT/4sD<?vp;Q/]aQ)*Ui?<.Qtl)44HvA4f<xl/TvrM2+i9K2o*<ZuHsRa+4uvT.=KxP'^KC9MGG,`WZhiZ#fEph7Z%O.)+T-['v`@P1A9S.*Z2Wo&@inE+@dG5&5uUs-Z0^r8Ugeq/8Ds209YgF*<@tW%x_JfLHIH##hZ(304pm(#2sgo.59U9VFR8t-;*qCGf_;h)4(XD#u?lD#f=E@GNwkA#sA^7(=:W?G'?GdNnqnL*83=P<WYnDGRZ)W%X+2%%3FwX-*Bp>GTH_#v4Thn#Bpq7#_=vi6B6OA#Op-)*dPvv$a]Q_#k<85/_MSC4+xPs6EZ;O+.l_[,LdVI3$gwF3($Us%=1I8%C,598b#]P1@*>k0BT(<-B'`v#)1A.E:fqV$6L&m&;,AH#:mCn'ouX$6c;NW/g[W#.#6o;Q#(6e#C()?#(dQ%$4Sc>#e4'-#QlRfL_$/o#1>484;,>>#c0/%#CY@C#k%AA4-PsD#dVm'&tGg@#j,ZIqiO*a*g;(;(LR?>@:mc9%pb@@#Mm8ba9q;IDvFA=%:g7V@VAWK(-gxfL*'V)&-F]f1QPFb3)5^+4T@vr-#Cs?#rH%x,Xk2Q/S42t-m-_U@U1Ql1>f)q744@<$nCHp.aCsY$wbYM90:vi9M<C^u(h_#'/U;N9]jRF1+(Ss.LTK>$r%ko7NeLH-H'gZ$-n35/YvTt-Z[B(G54&,53XkD#&v(1Gg5x6KaV:<-/a0_,G&H7,^'.%,A<QkCV1XA7YjuN'0/VP0(9g->w(L^#ZA)4#/MDp.6KIV6uk4WS$<d.<sBZ;%1rtA#bJ<qM.IL,3BSd),kCpJ)?)baN,JG8.YhNt&w_9^#p[V*I?#;`)[]qf[E#P>?Ws99.?'HL2bu4_J[gPEnHHc%bxH<8%p/Yc2]/j@?,tcG*3qa)4nPHN:O$pG3=CY;)W*J'//[v)49s'H2[AU8I;r/6&0a_bSNB9;ejJ%U.&.[Y9.HZp/tLw5&Seq@IB?xu-rp58MYn,Ge2=_#$i81b8cCh'#g_/E#^)V$#h^''#4<eM(]>Cv-7H?>BjJYA#Px-<-YD-t$DJ:W-(U%ktB(?V-n^@EH)F46B=[l.),J`wGMm;voCB?#%uPws$%2D,%Uw3GN2.(585P^N*3u`'#&jKS.hlWI)HXX/2wLrB#I5CI;Ho:T/?D,c4M_OT%o%AA4gEW@,C3':%>%4+3Gx%B-W<'q%,?%,,_Vrg(Hr`U%&@7a+IT-caF@1H2W5i0(DJ+ME#1f*;DJ/**_lf4(;Xc2(rM0`5.'Sa+N4m)49nP7&GgKA+$:YZ8qdn6%ml;]b_*%##&$:u$eZ/I$)LA8%dZ/I$Jp/KMA*61%tg;E4Nqu8/[#[]41Ngs-)9jhLGn3^,Mkk7eq<#3'7'iG)-Z^w#M:0O1[pG/(2@F=$4#vT%^iOM,IpoCOOOl_1??xP'P8:[-`o#u:BHGK1tAO/2fYAF-v:uk%uc7JL-qHQUjD(u$l69u$2RWJ1*v-Q0:]d8/b1TV6>QS<_@2'J3#r[s$(J,W-(4GN+xlmI%psV]+RSc?#Y^cN'ug%E+fB></;L^m&&ejmL19a%,&WKpRZ+b1BYAVT%)QD0(Dlgas1E,k0r+NW%9$+U.=q8q%_FQ3'V;il0o+^B+W]jAH42Y?M4U20C[6tNL*)7A4b3%##bXNT/7Dd-.tpN]Fs2Z;%mt7a4-OWh#1Jh;-cjlO'%WNU0mM?tRWlx#,n^kT%da0I$mBc?.a(cq/kK>n&M*92'%GM`+DlRBQtqgB+m5xD##msa*V/DL1_o0>Z=l(v#AV<W%?9>k0n%Sh(U<<r75(%2h_uS'#&2P:vfK#/L<c.KEA%x*38j?A4,Bbh#7k=A#Ynn8%r-ji0Fkkj1Q^v)4fnL+*7Ag;-ipXd85qfcNqBo5/</i#$&]Bp7>ElA#pl^d%E5rp/x:Hs-#V9p7OCG&#tUB#$fH.KEDOB(4dI+gLc#[x6x$V%6.e_F*1Uf6a&Lj?#ILZHd]]d8/1/w*&Jf0wgHV%<(=PR#8ekL/)9vTUAQeit.Io9s-;va.3&@3Q/cmZ.<ZL:a4859UJ/0(<-nM.)*w%AA491^?fQ+;mQcacH&VVGj^3r8Q&u3lGM$/K;-9`><-$*Zl0x$0/:UQp6&@:Kd)5bd;%l:]>-thF?-LPvL'91BQ<Oo5J*6`p>,4O1x5e*$aNEJ0BA=tJjGCr5#Y%bsM%A$1P:NxcG*QOm_o[OGKds*gPScR0T(3nAEY#f<mJTv:T/&Cs?#Y*l;':,52@KBPgHhHw##B;eS##*Y6#5rC$#Oe[%#q&U'#6pm(#b,>>#cS))3Ua*c42tB:%`im8/9(ro.s[Sq)vu&f)j+DE4D#/H)[`OjL4>xD*22ur-#K=c44;8N0Sh_F*NUW`<IuW_5j(`f_:B1R#YVh9.@adOo-KQ4*AS;%&OS>v#p*t7MLuBKM.VpVMQxiFV[>+D#09f+>itY>-+5Ge@bO%@@0jD1;e@o0#t'0^-&9+jL?v%mK2?%j:]IVPKLN%(#%2Puu:g-o#Dv$8#;?<jL2+;u$a_QP/#Zc8/i?85/%IuD#iapi'XAc;-c;q-%l-Mxt$hI],-HhB)g7vKh%R``+F+av#mVom8*&DZu:3vN'DBT]=uY9A,+QgB)hq;hh'gb`+OkA2'nXgW&u>>YuwI+Z-F9([KKGY##'63a3/N7%#,WH(#enl+#D%(,)tfrk'+,;h$Glf`*[0x;QY/L&=c=0Ce%kw2&$?_EEkF7'P.(VJ:D:@<$25ofLm+]D*u7@<$.%D/:KFjW@V5do/*_7P%8hvU7,#=a&R*'=$3sf6(1;TkLRno<$+[#B$en(C&5j,XC)DofLGCMX-qmi3=7-mwf5YaD#1p9c`AV?`a3S###&r/l'OZ'u$b3NZ6Rg;E4P/mG(d6&U+C0+K_K[%@#rK2K_9?l3'xi_m&*QiZ,4U9g1[,=##-^-,)vsai0OB;W@#&'Z-*]<B-4Lb,%piB.*#(>U%m_j=.:r'ga^ia1BsRB.&ElZp%8]+]uNlQb<]#/=)r3E0Gcn3R/jt]V2jcO,iC1Df<AH31)KJ@I2d.$##$,Y:v;4>>#w=a`>3FlD46/[0>fO)d34D)W-Okm$IeDA+47OJs-g7+gL%8Ig)JH^@#CG0H)0P_Nk[%'I,7&$9%V3=MCK:lgLL0W=-YZ+Z-L[t05o&M0(57w7*wNvek$HxK#kA@g:8(R^5lQ%##at)3Vs+Ef%13>m/*NQ_#3wlR04=hc*ZM6:.a=@8%:AMQ/tS39/oc6MTW<d@-.)34'Gr?=-Lx?uQaeEZ@QcMU8%s3d2lkMW-+SOq,J639'bv3V7,m2O4sKhQ9;SS5'C;$[-L:/R3X7+WBsnLJ)7LD@,b4k0(HCA>.v3T*@c>2K1;^U7#>=#+#N`aI);RZ)cAAg.*6D>8.B.i?#l=*N0i.<9/jq'E#*VmLMNxc<-Q+)X-&:H90QDL[-eQZ*7hY#d3LY%9.o;d31lqkd?:mi,)1xqv#M'S@#I5,j)@ekX$<Usl&n,0+EZ?W8&_g)B#X;rsLbj^VKs:(X%lcZr%37(x5k2S$9O/mX$EWUg(_/20(Z+K>-v-RmL*O$##1^-/L6Yxx+$N08%]2Cv->;gF4kJ1I$n]B.*LP1I$<eYI)5lei1i?^_u%i4J4p[,61cOi@,g/4o$&[-)4.5G22/5Mv#j95X.Pa%k(%5YY#.)Q%b^ZF`adnho.6kS,*gGD]$8l7pg70mkK=Vxi)UU<9/DcGg)JNj1^5>M^uZ]<-*dLPN':uvAMkOqM^Fs(T7me%N::X?eSf-ChjmcQN'%,r[%#'?F&]++,M$0t=c`VAT/4MR]4Q)QH*i:Ls-^mh;?2vxc3Le/H*JA=a*m^49./)b.3m=Y;L4tQA%n3;CX>HoO9%Xt:%rbm(5$21W-$uMm/k$'k0%Y&m*>Ikp%<7p.)dg#30FDTT%7]82+C^8F.4n&Z-V(I]-2r8U)qEbp%8*uZ-EE++%/)mqpkt@`aKVMJ(sp&/1JE+4MuAlg$0A0+*>G0+*8U6D'QIV@,ZDsI3X]OS7+eYIqSQ^6&LW&%Y+%0ON%+P+JEom5&EH;O+s$/A&v`L[*v&loLvwO_NT5&@%EcKB%<#R,2SBb%bUe$##+lm=7No^I*QkU,Mx]YA#O7%s$@OPn*%n;ga=%=+3N;PR*KCAm0M=@6g;1*Z-RjjU7f/.)*6[NE*(P7)&H2,j^xd8n/R^-G3a'JYMAVa]1a<=nKmXRv-,P3/`i7wK>T@4a&[ggQ&GJZe3v12O0';lgh.1wF+WX<**nY.^11qll$_k4GVM8w%+KF$##a(]L(oFIT.l/^I*Sv_x$i?Q12Z4.f;7EY)4Qc#bEnQhr&k&RQ4t'Tu.$hU;$%74n&W+or69Qrbrg3Xs-Aj`uLkW2E4bLofL20JHDJ%p.CS84m'bZT'F&0@$$vcS=ukm:GM+VN]$Qa5F<8#tY-x,0W-NtY$(9CcsH<uv4a6f8;6ciM<%*A^;-R;.39wt2D['F5gL?xJ%#,pm(#,<L4&9:.m2%xbI)PEZd3Hqtw-hI;]P8^Z.qfe+Z-ntan3WvBf$[/Zv-nCY.:i;CW-2,3)#sBV,#0e53#$2QA#vkh8.'d0<72nL+*G&9f3fINi*Oe&>.E_Jp.1[ih)Wp'Pk3E>MtTxTgM2cj=.1@%lL6VXD#QNCD34Z#K)?1u3+ru.&4NDn;%*e75/KjE.3^W&Q';u7i$s,+T'we9f)HCRs$Bb<T%M_wS%Y%ffLu:xD*xKUV&b=q*85,OKVK99U%6iLZ#wuPb%QuE0(f&&]%`O39%J?5N'k>ik'SW#R&[gFT%vdln&`<49%EXns$?eNT%;R*9%:i.R3Xfc>#m'&[:t,6De5Y8U&&UA[0;'OZ#mUdL-=t$'49MlJ(X_R<$=@es$Ljq,)Ua^6&s3^*@^.m##sL'^#dRas-QcGf='C29//W8f3(O<<:1J@e%U9ki0bl@d)o2u]#[3rhL7@,gL.S7C#t0qg%(91#$1xvD4JP-98KIo/1]kjp%P1`[#Khsx-/Ktp'Y6]j08:@<$=kH68oS)4'Hm=E$LY9h3%s`t.JTOV.ITG3'@-J>-;#mC&5Z$v$PbW]-D%p+MGt]@#u?1hLT^l=$bO/n&VRaO:Gj*FNsjk5&[oNi(9kOLs.S%(#h4_,bnRY42GSR2.wRUA?$O1S*@Zc8/Ee:N;PY7Q-.<bN.9>'32=xi8Ax;mxF?1/ZnHs*b$,V4gL++Wh-9p9s7T%*KVew,?8o:Af-[W(n/E@%%#Uqn%#C=_](^.j=.JJl-$+EPF%:Q(q.av0XV,6=I$G7fT.dPqvA)0#)Ns,/o#:WL7#:aLj0b$(,)>V&E#S4r?#-@d;%21)t-p)K#G29@b4No^I*:IF<%T8X>-2YlS.I@S+4:>pV-Menb%o(np%/]=B+?Vmp%pd/F%dZSM3`j?QM;&j0(U?Lw-@v'<NNbRO&e>C[-at.F%^]Tt%rp5%?'/###gQ,/LuHTWorBJ;8kWnm0abLs-'J1gM]m--&GNCD36N.)*w209p=9g,2/A@<.]b2D%mp'H2eBj4LDYm4(.+CJ)?Z*%,+=D0C/ARq/Jg4',a6&+%a:d91_5u;->*.'5`#u-$fkS&,j@;[0668.GdtNQ/dDD-G)Yqr$tCF&#SdT3LFZCG)^CPV-upai0Pgcn/)87<.K5^+4TCKK%OPMx-MF?lL.5#]#bj*.)sGB@MQQ.U7Ng^r.p-.32peAC#6A76/`us.LrF4cMWCPS7H<7o[)Ro*/&$)ed6]aOD-n2&l&BFjLs@88%`3>>5/1NP&WkQX-nl&-2RRA2'i)^*%o;Y'&G^v%+;Oc'&AI%[^OY.R3Y#2R3Xx7R3Sk4#H-q'B#wLp@Ofn5HP>wJ%#b^hR#3B8F-*vv*&[:;(/hB9dOmD8F-NV_@-NP1%H@]r^QW`U@-_(<..kF#m8ZA,'$l221(9Uw9.0^k-$7;?t-H23L?G.(B#Qrn+MPL$##2u_vuQfdC#_:cK.rjP]4Jc`6&3N:u$'1R0u.u:Qpmi-9Ihi_8IJ*pi''ndENh[Zk,S5Tq).[a[&R1TgLM?PcM8/&GV,Ih4=`$E15L,>>#g4Hxka(o9MbfMg;sikA#[XlG-_ur&.F=[iL>9Ht0QYr.L'8NY5Zg>A4_jIa3wHeF40U%],vq-x6FN$>%CLD8.9j`]$SUpZR>P'B%a.+Q'vc4:$Y?/[ufH6;%nsRg#t:'f)X;%1(Tn[w#6J:E*su$5J;GBJ)J'.%,1^]K#e6f@#/i_;$<^r%,ajJv#C>&d#Qn<t$D'0q%Bj:SCP7XX?r,@-)Ur?0)cT)<@L+2$#jHZ'#B;eS#4ZL7#P6cu>SPE$6urGA#_j#`,%+di9Xg:E4nGUv-C:.5)=BFQd3Er/193]5BRtaM#nqis9aS2W%?2@Q:gCQq0CA(b$oj.P%_43n&pPrB#T>vc7L/H50Q>S'R/Ke;%D(YNjBN4D<hC(a4^_Z)%G40K%7][Ks7[@q.V)ZA#tA?h4gN$`4NNg@#Rr;mJ]V*E*`qDm/7ijp%o3dr%W(Mp.R6pZ$1b:O+I9k*%l$x8%,mhw'w;h$'K`8gLwAC:%SSU@-wxtkLco/gLTIG,M%EUU%un%jL4+e##$,P:v)-nl8SI'&+=oOg1vU`v#?]d8/S-Tv-=V&E#JAWD#&ur?#iovN'E5;N'oTxf1_c3t$Lt@8%F2juL;riB#gX;Zutxcn&VpN9%)L[W$wHP'At.72L3Iwm'H3%29;R^`*xF3R/skY)4u3YD#DnFR/gEW@,J_j=.u+[pio+O_$bDRvp3ci?'be#nAnEq2:D<%td]:,HMPX_vd:SAeaCJG.-t,qhN4.x2N4Gau.BExo'iQGx'[L9l'C3IL2BUR'OWk,L/$&P:vUQMmL]'j'#6sgo.?ljj17@[s$vZhk1IYbJM:X7U.kHuD#bLC%%lESA#oiE.3jg'u$a%NT/IV/)*a^D.3&iYS7Rc/B+W/v=$:i_;$LQYN'mRlv,o30m&V;Jf3S7V?#7Us5)<@G)QnH,L(>DQ[-tTJW$e&(Y$BkWp%9d<9%EMIm0@U<T%P<K6&$Q#w-+,)X._Qt5&i38B&/fDB32`;aI83Ee-?,a4']H,n&VAEa*URJN0U'+&#5vv(#q*07JoFlD4,f-TKt:Rv$n5Q-5>4bF3$%Im%kofF43ZWI)S/G:.2Y7%-#mjTDSQ^6&8gYn(kemaND9nK)bDVO'Dda6&==K%57dfxA'lg58r3kSn7qW`<&0X>-Ot4_-gn'<.NJdSdCk(B#C.ugLbPwv$MeF?--qx(3&&>uuEuRH#GtC$#tD-(#G@-lL+Ds?#EP5d$^NeF42%Jh)KFn8%kb>d3s.<9/1X+W-hX[?TR5^+49];QVT,MK(80`g(8GX6;&_Pt.]ZJq.>FG6*';IN'2-f5/v]/B+b2?V%J;)kDHS$03+oH>#CQqwQ&CT88tvkZ-0oYkO3[YfLQ*88%2Q,>>5#pSU1,7a3kY$T.A5B>,NE>[$hc``3_raO'V2BC/gJ^.*Z+hkL.mYhL9^YA#Z%AA4w3pTV%tFA#pkhc$1bg34PFNT/D377;sA.hsb2vN'-jHl:?v5iTlP/N2E%4j1#?dn&L1ID,E2&#,'QmV%.[DW%T,41)I7'?-1W6caLDS/;IDTh5o,6-V+;&P1(fk.)*pS[%T80/)>tmG*U)_A=<n86&XiM[$QX1R'1u?8%@c1v#;RZ(+dL)Z#C1)?#dHfN0$f4p@sAU'#)n-58nW%##L]]iL`Zh586I3j1xH&N-o)MP-V]Rm-)Cl3+l^D.3]AsS/hO)W->6ap'pn>Z,8tR:.kHuD#eERs6j5S[,Z0;U:aXg]4jYt87B%2v#X=lv,9-&'5/rXgLI3/X%(R:Z%[^P`#kbfi13AH>#sZBq%D7;?#_Ski(gt(>95AhW&ZtG*&l_bgLe'2hLdonPJ:6ZV/(0]fLvDl5&71%[#d>aN5&6Ri1m2ZBGE,Ur.WYE^-@UdTiRkddb^SDs%Gp?D*D1$##a#fF4Rq@.*b&%d)_=pL(jAqB#Z]B.*(5)U%YYFJ)`(6ca?rHJ)_**%,_'3I$E%X>-E-?d25MmH->n7>#`7blAm9+7,p;(C&IkH`#9JQ%bR9F`aSb`i0[03u-qVkL)x5N,u-o7C#OJ,G4%v.&4JHH?.dcQ_#lsOA#*w9%4k1&*&n%sILL'bp%Fs$L(vO(2)ZHI^5#NVk'PcTa+qwsm&8t-L,$8D?#;?sR8@=`Y&li*.)#qf/1PS)U8Mc>##vPW@t06ea$u8w%+JC$##nlMq%e^(6/t_g/)lZD.3rQ.0)_x;9/:%x[-jFn8%JS4'5pkK`N$Us-4&VcjLN2xE+/kA[uYv0q%7MuY#.A%W$ic^)5LFXN'L=ht/Rn62LMJ)^u8Uh:%bivr%A`]&#%k1iO>j@iLU>J(#P%T*#;mk.#_0eX-29-/E]pUNtp,_20_R(f)G[=%$S=AUL2,%E3<?HK+;Z7.MqJA+49)c.-+Q?*&,'IH3mPk<:_Hm(N?S;dc4+IF5$RUo7[d^6&Y*g#GHfT>&3Es#P6O&n/n7de$E5/q&%/w'&[xi5/bJ%H)w-,gL7KuD3.Evn&OnSN'<kuN'8V`6&1oB;-fNPh#A$Pp.X;d+>'avt()iEh>#,F$OtKHN;J/72L&4/T.mnl+#2sbi2(_V<hR]wp;)X)B%fU]W.,-PY%`%,)N26pW;W'Ucje8=W%ACm.MB>'*'RNYV$G>r/1A4i$#dWt&#.I?D*k0bq%mEjv@C/.a3&8/8@FWC5iQc,`%J)TF4JYC&,^'.%,f@wmatPi0(=cOo76F(C&$9;s%k)59%.w9H2s.rC&S=LP8CMO]ucNk<)=4=;2ZQd&#S(4GM;JxK#<*<O:]%U^#^0D.3,(Sb/a+x;%+QsI3Gb:T/=Fk=.U;1a4Z7Tq)rMx--dEcF3hN%pALLje*@/ue)p)MU83'1H21O_X%o%KN2&gwe)_sqI2DR'f)9=X&'/Y,Y&.YnS%i3G/(iHkhW5Up>(&I4_J3Et$M41^%#t8q'#Z*N$Sa5Hj'LW1]$^p*P(xi_s$x)8f35jic)J=Y5A@@^v-[5MG)64CB#S9>F+3hxFY`&6/(Sh;mLr;du%P,kp%lJCPMdqblAckGn*MA7Q0SQ^6&=pXe$wnIaLZwV9+'j59%Lmr>P>$A@@_9W$#ACPkiTFw[-@xq8.reX;.Ldf,DWX=veRq]:/dWku$%OJ@#$T`%GXH0<-M]U4&o9jxFH*.%,aeo&,s<9a<ds&oN>(e7<6J$Z$]Up@>:LjV7e0^['@rQ<-Z8L)Pae6##[<XA#/r@-#cvK'#X`/n$/grk'Z&PA#k%3+P#oW2Kg+Yn*C6ev$+Z;xNA=a5/A*Pv#oNhhL8YdF%t2-aNhEx8%W225gA+(h$O)Tp&%eQIMW&xIM8,+E*-c.pAsCRq$WL.RNKJxQN0MJfLn,-M;^^lS/*K#a4E26oAcKWv6.e_F*-?VhGdh:?$A:rv#jRwqMO_gLQ*pV;$XQ.?nHugX#C[N1#au:eklx#H.>9EE4.P'<&^@i?#0OjBSw5<#Vf0tF._+w`a&<K?PWpDv#nKhhL[Lb+.k3]uG]HwAIXt%s$JXY)QBjAvP<#U^$9#4(8M6U'#<_R%#-U2W#1M;78FKX>-pUZq7X.6:;OBo9;RY8'fIAlq7Tt8m_aU?>#&E1;?9Wol/c$kB-,`9=)wR2=-/_2uMZUdF%+`JcMTe8jM%<dQ)8B0=-A[aC(H/5##&5ww$2i18.I06H2D)aF30k'u$ZVd8/u3YD#0`7+%B^QJ(hH>/(.+CJ)Fcn<&%<(d%C&:@M0QIlf$bA`a*JS+M<-VR'upNh#ZhCJ)?Z*%,91C;-lBR'd+1'/LQ7FD*j*io.%NYn8/B(a4h@9=9^eB#$;<<`#ur)6/VdDA+I0vip:9wS'M^_nulJCh$phtILdNl/(NgAE+N'KQ&Yer?#DS4Q#SB'g-2FLFl#7GcMCX@`aL*8m'Qa_.4C2_S%3ZqD&oXp.)=9.IMMt@QMD9QwL1)I;@r(U^#9DH%b`dQT-u#$`-qUq@Iwg^C-f(@A-V@^;-J$LOM2]ea$E&3>5&_'E<QPl(Hx:Rv$lZE.DcJw1,JowJ12]v7A0LPN'^]/B+rx7[KNCmca:M[w'ql]0q1Da6&<CW6/v>rY(hoU7AK4N*Icc1<-[1dPO8xSfL2=FJ-:J+/%:(lA#waFVMhsJfLK[d##kw5Z>^iE#-4AhW$a-CG)PEZd3=Jsr?)F<.+OEZd3<%P:@t>pV.>CG&#..LB#_g4',i.(0MQ19ooxIO]uEB2=-?%mW-F=%+%jDIbMEXF`W#MO]uIFf>-t'^GM>Z-j>QgkA#m%mW--0oO9u?M4Bv:u5T996DfFl*$MVB2Df7xXJC.Y4_f*<*s^JgXD<b(;=KEU^C4h]p$n)c7C#^oJF*35K_836:>>(f>C+t4de$U_Es$^@U8.nUX5&d9fJ1jNAF-X--h%hOsRS>F@W$)VnQ0)Cv;%N6^@QT%oM&#&[-*Zj:9/ql4Z,%A[=Rb,wF%m<oJ1?fo8%xCiDF'[4$dG-9U%R53K(W5L'#IVE#-8ZP,*>>`H*axrB#n&]F4bS0dMtuFZM-6L>(jXo0([IHp7AEiBo4g^>-JedEM[SQ:vrtAJL@4JJ(rQwd$-C')3wkh8.ai?<.fmf*%9)'J3JQfS+2aoDN^DRxkew,?8GKDU@o7g.Mae6v&Sq$iL.4i5/;<hF*8vCPM][blA+=$-,?KIiL+sBSOSSna3+_Xv-*BpNMVQ02'u^6'#<qt.L*_Rc;J@>=7qneu>K:H]F&]+DNV(e+VpU&(QK9AG;Ej,K)T-xe*=J0EWWs%sZ9Z:@-?F0v.Tr=V-4lxI,f,#]uhhOg$RZpSROg7o[/f@1,uS7p&GmNh#wKnBA/&o]u5j=A#+[OV(4g4&>'a3KU$O<;$A]H%b=PZ%bX-]f1Z1*;?TOU[,)2rh1o83oA5Q[_#8#wA4&_D.3m&p8%mFc/M&q*Q/f?ng)^0Xn/h#,J*E%B(49S,<-uTtr.6(j3&>tNh#[brF(u@D>7^(Lu6*q10(vgEu-qf@l'Ko'W-sW-J2veH<.g3A<.be(t6bFT_4b>hZ-bX7<.c%jP0CDlY#S_`mLl_XL%LXAe(83[,*nVo+'sXkE*UN#n&vIb'$f%GBOu[V/:#@pa#6agW$rtRO9,FG'$IGeB4#:oO93[lB$%2Puu[-Zr#@$Q3#mABjCD55d3(6qWfP;$^=>MGH3LR(f)2Pw_:$mXPTBo1]$sK/?#]/)ZupluN'iL=:&CS;_ZBJ(@MW;4/MOQF&#wYs[tj)%)NH)UP&jNai0OLvP/u$:C4a?T:%YV)w$e8v5/a&ID*v_tcMKu;9/Fi@m/*.qX6j)K.$?<P)3atep%X@x;Qi:Jt%AWW#&'HAcNR1_KMbiTm(`2Afhfsf*%68Fq&05qDNp`ub%l,PT%*Bdp%g7KgLDer=-#p5X$)b`S79VAA+S_$##e+h.*cK0#$Ynn8%hu+G4QPd'&EJ(d3bp%gL&E6N')?WL)1uSfLx-RdN/k8G3VXlJ2k<O=$>sq+,aO3TIv_Sq)ss3`%YNW&FN`cY#7o1k'dw=40pgiB>_Q>n&.Po#>7;QmSeS?;%6U6L,mu9B%j`ja*q74hLXl;d%[^8xtAj0p%R`mi'Zg>A4QtfM';1TV6:]d8/O(Ec`:e4Ea+_QG*hn)8&YVo*'#/b1Bc]sA+8XBN1pQCp0$&###BaO8%#oW]4rroO(>j(:%2Y;e$3-)B=BWxi)o&[)48(]%-Jtr?#,NtM&rHjm/vh=:&f-grLX_VaOiR@66]82o&;2L]&>-]u-U.0vLZ*]S%ooOX(lfFPRMbdgL^7#w5RcBK-xs(64guC`aBLgr6ccp(<83LG)=Fn8%e^/I$ro=Z,3lWx$j+]]4`LTfL#(B.*=?a<%9C[x6uU>c4?>jt(q@:P%+;v;-lS[#%O:6h,_pC4'jFt+3Y/nD*5>'32u_^'+Mej/1WXc@5#aH;%Zx+C+@h*R/gUIq%ZS<E*pY2Gs@WjD#Jc&X%5)f-)8:*T%c9&30gK$1261?,*x%6N0QE5-2U8^;Q9]1v#]f&b*qt0j(^sE/2llXs%>^iUM-)[]47qQ(#&2P:v;'W>#R:FD*<@,87_tu,*g?FW-'KL_&PS<+3[<+J*/Tk;-1R9J+Tq]:/lD$X.0d(T/,$ea$96.)*pEFG291k31T'*O1euiW%BPZO0TfAX%Lw/<RH&BP%/cc.:97Ep.Ag'9%ib^-6IlssLbe(HM;nhS05e_cjnKS:.'w&9%fF.K)w3P,Mf2D:%=WZ`*`k*5Jd/020Tb$##>R(f)ffS>,sE9V%nH:a#$p%&4nGUv-;l&^$WP[]4d(p>%%XXJ8KKds.Hk%0:h_:w,%rp+*C=;@,`v_,)bEjv#>?xa5+eur/*u*^7Ne:J)Snj5&S996&-Dao&bV%l'vrI-)R^=?-s+aq/23$A0=ESB5wX15/%&>uu'Dt$MPL5&#+kP]4>YqH'=tuX?XebkO38OI)K-kT%,/CHMf[^vLw[q@633iS05hoT%Y%vW-8bWF%)okA#7Ab7/4.%##cq0hL7C8#Mefd##ZE=VH'mB#$kwr;-<_>_$c=g>2[x):8W2'6AEuLQ'2PRN'jHg01O-e<&J1)Zu8^P3'q<9C-r5Dx.Y*vu,<sI(H*Z,5&nP2tT+nV@,E%o-dAE/(OH[@C#s2lc%ex[]4Z*Mi%L)ZA#pXfC#-njp%h*<I$vHt9%BXw<$n/Yp%jGi9.Wfn_-n-PT8&>'i<[M`#R#Y>;-jpgp.B8%<$kC-U;`8h'&%V9&G+a_c$3uQD%IZNx'OJJ'#%&>uu<4>>#bvdk@r*@#6YqXR-1T@ORJks.Lrn-#(tHb20qF24#Rke%#k>>U(>>Cv-X7Yd3p>E.F#^Ps.V8xb46o1JQ,slIU_e`W'@OJM'^<Q_'^3jm<mfnlP;'dgLYl'0MXD7+3J(nm<g####$&>uu&b/E#],JnLDsq_,$*oq$O.,Q'Z)YA#.Oof1p:gF4>04W-D9n--+V65/??-I2=4Tq)&c(gLQ?CV%i%?87bj]s$lhF`#di`o&JPee2Xw7@#7CN5&Rvb#-<d#<.(JOM(Ptl)4hb?U7Ln+',D$Rg)h(@w-^Vn-)'a&1V*+H_+Qdk:.dbR<$2r-s$,d-I2%5so&+4iw,llNI)0l_;$1VVQ&R<]I*?Qi?BMfAL(H[8m&&cG29U8p^fB5o^fh'hlAP.QT&`-%##h&1W$XEW@,IUvLMWBo8%&p._'ff%&4;JjD#;n$gLE7_F*V[J['VSTw<rTF+5v,`v>lvN4B&l<(5wJ69%0o#68@rlx%@Ver/R;e1Mk^w$&UmXpBDN%1,G=^v-We't/]%EW-(dWC$4f=M23>###u]x9vhcaL#fYt&#oPUV$O7%s$Q0lNDcV8f32Pr_,J<Ie-Gj6XL`jo;-M_t0(@CJH*q%K+*p(5$g)wk#'V^pm&`@)+%`Qhr/3sCY$RjMqM0jHeOI)Lx$>>.;%0c&1(^rA'+VLSuc[?cDO31IlL*-R_'$1mC+FZ]Eelco2LXup<%Z,uB,N7QP/Hu.d<JR=6'NO$##J'KIEb^Gs.(PZQ<WU$lL(DGA#&1d]8&+(f):3d('RX&T.ETAZu-5`T.>P+q&be6#5/h=A#+,K=u.+CJ)aZ=01t*6K)6v-n&UJ5s-+MJfLJLQuu9dqR#xb''#FPj)#l-(*Q)f@C#bTIg)PxRR&SGg+4cU*X$hHff1tU>c4:jE.3RB%f32]Fki`S-C#AZET%Ypom/lJQR&+VRD&()V>$fQKu$R-9q%PAeh(4X?>649/&,<IC;&:7Lh$WN'P#Tqvc$J6X]#e/2g(dOhasSQ^6&$h5Y%Ir6s$Y)mn&Ngh,)MW7_+W4#2(`DqdOW_6##;j6o#;WL7#[J#lLud0`$uaGj'p;Tv-C7fF<s[,<.T>%&4DIse$f]DD3agabNM>A)tf@P5(FJLs$]5mR&-o=u%VsWID>.Vv#xsqK(u&+3Ct.X8&Y[0W$SeP,3`?BKD*H1d2Q67HDptT-3/6dr%QbE9%CrgB%b[nV8pTk9<M+=x>:Z@&,U69<-g>cn%VCgsH9`?_u^I2H)JwET%S#IT%UB9:%XWgoi'S7MN?_'jCPO4v-36gb*6>Q<-]Vc%&Wv)4s4ktuHfp45TGrh;-w.;N<[eTbA,f@W-F('d6GJrl-ClYY^wR'$IPSbA#MPJ&#iq-.t97(p7=,<IdXjvwHjb3&B)pGp79qF&#d^x8.*n]%b(B,W-$NbT'lS:u$o9OA#NVpeG[-]f$('PA#T3IdbP?%u6_'eDO3Fj?#=,2'#`=8T%c[es$'jGT%%J3T%,D(P2Ngma3pQlr/nJg&,kFw8%4s;F=VYgF.f>#[Pn;*@#d:+.)k'&t'0'Gp'@=8)aigoW$Q4*p/A'vx4P_P:&]k;m/I>31%(m5(/?v')?x1^:^AR4s%/n35/M8IF#<B/Q%_L5l0uT^:/jBFA#a&SF4o2WE'U/;9.9]vG*_q30P+0QW2t7oL(ma/fF--0O&%X4))XjkJ)I19d2AM%lEl@j6Ep,97;`S39/E-KjM+xmXlK^)dExn;R*qRZbHg,&:/W####.Sl##A_fX#/On@@nwLS.S8(W-,fD`%8G?9%iT)U0EjX?6AQ>s-F;d]MWjg_MF*vhLFcAGM[*pwu@$8P#(g^C-'8f^$,2%#>cb0^#YV#<-Qcn]-t`*&Bl*8gFbEW$#dpB'#NdeM(W?_)3-5^+4FE#w-[5MG)7TID*X>buPtX2u7*^K41V5do/o>c8%KQM`$rYND>?s2uL+'*aK;b9jC.)[dDFDq<146A=%Kc,d$]f7T&oFtV&`o+B]j>3vQK?j&HSjsn8pWjv6XN(02fW/_S+oRr88#vcE%GPS.f^5c*k,h-%4x3m&TwHDEmPjmfMc*T@LR%a+1qS/)NKN>&U;JB#B4;Zus>g:`.T7$5)/K;-JYFo$DBG`a)9li'ZY[`*Y.Db*tMCt-'w_c@iM1AlI>)i'iR3m&sZ2e&^p,n&9.egLj#AHD99jeGeKXm'jHEM0RCh$$fX_[,BB(E#Ze75/54+g$)0g;-8ZLp2lTZv#DRIfNhRJ]$o^.H)#&m'&hN^:%U1,B#@YUlLG@,gLT[9A$)@5gLQD*^4DW4?--wTp9IH:E#]/4&#e,>>#>BNZ6VE/[#^^VI&8)9f3,_/$0SZeF4a^D.3INqh$6qU>?eGo/1Rq@.*=@[s$,c?X-N?p`&2/'N2]jhG)=,P',f_q329Grc%L97W$Fq3t$Ke]Z$;wCJ)^P*T%`R%W$C]/E#'n'n&G_GE*e3-q&I>dF<0qc;/E,g6(uccF%lV1T%+P(Z#HXnP)T?g5/`SW**jA'%MWNvu#SVQ9.*Ter6jV:K)t+`^#Ca#Q/lnGl1:7%s$;8;-*&_<c4<Rk.)en'm907=j0^.5N'xEjW$6qun&D6greLGh/)>>8;MwToS%(DB58%l3&'q&g*%^L`<->@dP(9_6.MOPfm0V_tPA'HU^uLjIT%^J3T%2isPA^ZHJVDd=m'?vvD-;h,w$tL3N0O[lm'&%1x5O.Hf*KdgW-l[&f?dialAF@;Z@#X+j*X'`gLpaLL3ICT_4wuUE%E`^G7)-OBO8tJfLTe-##Zw>V#]A)4#8sgo.YMMv>-Q#w-gc``3F)2HEASjv6Kf^I*1X+na&I'1X3F@6/mpvD*#?JIM/D2#$KD,G4ggWZ#dFnf;u?hY$L$S@#oVg*%[Md_FN61>$7Fsl&W][L($vbBO7u$s$pu>j#:,-(&1jb`%@$eg)):.t-fInS%wNBW$v10+*YS%p&e<o>#^-A/1]U2m/sio>,a8?r%bY%-)m?=t$]:eC@[b6lLTkUC,W7(5%s^ei9v/,d3pZ]?M%8>k--;Koi$GrB##@.lLp;_B#o4;Zu8-eT.t75$,l&o12W&?;%ordr%T$F9%>+/n&TDDW$Y(sw&5vgW$jdPo9&fQT.Hw<=$PdlN'Zp6R*lY*]$*####wo=:vf.hB#%Xs)#$2QA#@=@8%<Z'W$ekvr-dC5872nL+*s<RF4h:AC#Jj:9/S02e&^T&],:7%s$x'()7k-vG*_Jr3(ARbs%ZTXp%,x;Z#`v96&?a39'(Yk'.E>0p7W*eP+8mO,i([A[-o)/71'DiY$bPMs%Rsu3'hDD8&G4on9J3Ns%fh<W8YU$lLJ;e,*hFVC,elqB#HU&H*@[JwoXq@+%W5]SDt_mL-VO`X-&#`w0Hc``3as@v5v_8]$F@'-%4^I`$,na8%n<fS/5d1n&HYLB><4V?#d]alAx^&n/Z/.b#rVRw#O+H&4kB%a+K%Ja+iXXq&f34kO?JZ=l4s1GVlw5kOHr/l'X/Of-#)mb%u0]?TTT`LLR32oA=f'W/g3YD#TZLD3%&AA4iMBB%cq%c5ReeP)jbaaEBMl-$D3qR)#HfZ5/Aw8%Q?m]4[N(k'gf1?#meK5S+q*q.=VY8.I&XT@=G.a+N@nM0(jN9%%p.<.4BBP8R/72L7E360Ue$##@xqhPxAqB#+(Y;.Z2#d31mK)46BBG.%:*Q/Oi@T.>U^:/4'9mV9RFI%NIoa3NW.f3p,-a3eoa,=-hd[.mJS2L;,p7.;J4gL`cbjLT>F[$URRE<h:7LSeoDp/Qk$w$YfY=lhrDwK:ap(<%Ibr?ES4GDGf98.e)Gs-BGKp7j1T;.Oe7>g?kTP']Kwb4=W9K-g.Pp7Y36Z$h@Xt(w9uD#Hu(H*Wj:9/%Fo8%Vm*H*RtLI3v&2.2J&w>%,<D?>=j7?5;t-b4XTR60+`VN9,>.n&h<CwKE-_9&cG$S)eLo9&av4Y'd7jw$oJ?I2^db#'[ru>#FGoY,Z).gLDMuY#auIJLfQ8w#*>cY#Kan@%P*[Kuf)qp%.L5s-<0)-MWS8`$7OVc>'x,Z$Bma_4Ube12>BwH-dB#n&E+fN43BDo&_a]>-Y2vM0guC`aNA<A+]C8RJ`7H%/R@Df'#nb6&@JVN'OJB]Vf]<9%q9vx4HvfI_4FCB#1=E6J?cw9)NPUV$9DH%b@a?B,,)r%4N%+g?bY=a$tP)X%_J))3o]>)4t3S#Pf']s&i_gi#s(ZJQ3dUc%O9^m&oGg;-%d><-/ek_0%vF:vrchR#[;_hL9xH+#WkP]4KSr[G%R'N(EcpNO4)]L(XEW@,Hnr?#On)b*qZSW-[34HX$V@C#u'*W-RvOd$lY_:%FCIs*B-(q.Z8Z;%^Qj-$xYB)5C_39%:,_)NNq<O#X;Mo&wWlB$#t-iLb?UA$h^J<$=I?nANSka$N$1H)(i@m/<ofv%T^^6&nQuHOQGac#wY371Q3'q%%57GV$X*R28*WrQYh%=HZ67m0PPh^@b=2,`t[uWQfBXjNO>io-[l-ImxIPN%=r(?#dbpLmH&pXubWp8.WWt&#XjAa*g9k<-*FKX+AZ0<-':H%(2JDq7b7jV7UkoV7NwiJ2*xZ`%oqLs%*S>s-X:4gLC3>cM58H5&EIoPhmHec$wc&V-(,(lLI7-##R94<-%QrS-Y'x_)gs&wYHC0oQE#mIY-:-##,;C'OR6<#4%vF:va^4Q#85=&#@>N)#x,>>#9+H]%fsJS8jl1E4V6xI*i[rX-`C,cGfo+G4NKO]FZCZ;%@idX-qXh+c^LJw>IH:;&mJlq.V@%[#KB5n&0Cg9&#+P2(WjPn&oW3K(c1Ua*dF_^4Cdmd2U1^,3Z7.s$Q<4X$r%oV6,UZV@kxKp&sl(jr1[_%OFa8%#'b?T-&;sP-^-RZ,E@L+*MS'L&3=Es-1QiBQ[iF#-fjG&,J=NU.Y:HT%3gP,%(&gf`W-Ucs=_Rp7=-R#67fMR8qN,qrH####%qfx=6AXm')%_l8U3+OB&Q-C#x,$E3?DXI)jG:u$,r_P/f3si0>x;9/:Dw[6#=[x6tU>c42Pr_,PnSN'ep=4M'gT_,hVnH)UZUD-q'n:.C%.<$L3pm&jTJN0??YG2OwFX$x1&(4ZdYN'qO5(+?-9wGj'12qZg$GZTm'B#Q+v>%9u9/)2u4I)18Oi(b%G;-l;ffh8dge;Rg3_5A@e>QO2L*#>[fv$rZH;^b]oF4[Pl@MHmkj11lsx$<D,G4;^A*[&-U:%sNWh#D(H03mPPA#]q.[#`&+hc[2dNbk$J@#dV.kXGenx,C1@W$%G#O2#?0V.?;A'fkR[<$c*3:.n&A;-bKS@#7MnguDi1Q'8&,huoRAs5>_/n/:VffLtbm/(Ve]2'iu7P'dLhWhN7QG*PA_,+um4X$%/5##>WU7#6ZL7#/xG9i$v1T.1n9u$DPt-Z1>2=.Vq'E#I>WD#+mE.3A^#L4t'Tu.MD>n&>V:<-*bhr&g`d_#iwvp.i?#3'jDt$Mm^2E4Y_+h($W.B0klNaaWD7L(>wR)?q-q=9oh*iC7AZ,*>RNkFHA,%,Yv1O'0JRN'h=G$,XOF4N6dA.,<Ga+M`8_6&SKG8.vx7L($YRT.Y>$(#q)#@&2grk'W#:u$a1[s$O`sfLv<<9/jHSP/J5ZA#)w[a$ttr?#eW^:/vu/+*/0.a39i;6&`w,j'qAH@$',q3Cc@uV-<leq.Pq(0CFY/u(Jeu3;%*AF#YTF+5LuubN%2lgMsGq6&Q7^q2P('+#S(Ba<?t3xu$T)W#QaR%##J<j1o:gF4iT&],:@i?#D+p_4/e5N'19o495=k8E^_iv##&IxQ@DIW$Y5?[79@>0E%#>/(,<9K4efV[#+gUP0af3eFc-w##^Wt&#3NAX-m_dd$KXGd&?ZH#>Jm(I3nXQ@)hGq?'KQNHD)/K;-fVQk*%%?;-#qP-),iem&qqbgLUXB=%mp'H2EoYY#q>>g$ML187iH%##8_Aj08/^<%kj'u$&C&s$cZ`2%L`E<%PEZd3r3NZ6:]d8/$%*<6gr*V/;va.3XKwb4aIcI)&sMF3H*u(3Pb>d3Fg:4'YeCv%;A<B4M4ua*lANE4d5qq%^e$8':P8$5fkr=-&&).2UrJ-)?$u>8nL3h(WQ7>6,x`a4Pe4n&HtZ1Mwe[D,s5)4'Xavl1X80:)riB2)R5am1*(0W(l(<:gI:w[-mi:O(G1R8%`M.)*wc``3sI@#'p;la%g?Bj'KAl<'8MTgL&Fg0'x/$EP=FL584dA,3:dPp.b>'32'r2xnUY<:M%02F=9xB^#`[[oIqU=J*OCr?#*f@C#a%NT/F.@x6Z&PA#^hi?#&6mj0a]B.*[Z*G40MsO'FN4W-R&)C&$s[I)*)TF4ZM)h'rIBp78rFs6%sR[#1c'j(ogTM')`xfLC_39%.CYb%A+ou.['aT+dSvO:S.Y@$M)B88lTZ#%;hg2'VQOp%&':R&9XL[,ZrTS.&Pki(VQ49%t:1<-ou29)'uO`4=*<U:7B]_+VG?%-ITv70BX8v$Q]8@R^aq,3^ki?#Yq)Z6W_d5/*EY=7?@*c%4^ZW%%6MG)v<_hLU`1E3J29f3W2-;HYSZPJlosd2sfM^40qRp&l?6tL[]NUMPmbTBLMaL%_bix&$B5b@'CaZ#2Jvb%OS.n&cRTU)^M9GNE#Qt;wYc##%)###1^-/LXhwI3`-%##$tB:%t4Iv$p5g<$_TIg)E(-xLZ=jI3fl&gL&ZOF3V52#$57_F*ZS`)3pGUv-.j8`#]NWe3QbIP%f-E98'xax-.*4>-,sr200IRt-GPZ98*^:9%hR:-4Ym(k'gS%c3b3xs$@M$<.`NN'/j4@o/&*k-$t+`r.holhLoWfs$C&)q/fAOj9S9BeX[?W$#0?WD>P6w5/7,m]#tcMD3O59f3Z2Cv-^G.)*C35N'%fn$$W?ng)Lov[-mf+`>95'kLLdYj'Up:K(Z,CEFT?.q/F/YL:Mp(0(8JWfLlni0*L-5/(8?)(vew%g';:@W$JgE)+SQ^6&wSDK(lO3t$=C<p%l,$&4[Obq)q3n0#ah+/(KLb.q1,ED*^[[A5Tv0b%e:jXJ=[%WA.sT#$2ocCHfS&J3+`OF3?irS%AsGA#>iC%6tl0n%j,CoITtIW$hIc>#3vc7&i?Fc2&/s#5g+IM0^Sa1B?.PS7uqbgLkrv/(.E`G#(38Yumr10(xsF3b$wA@Mk@]H)CG###R3n0#$=*L#vLb&#rxMd%stB:%_Y?C#[%'f)l4K+*x3vr-Z?85/OJ,G41UZd3*G[%-1_lI)QNv)44Ux[#`lrZuU8v$cV^1O'OONT%n%;?#]b%@#3o]h(jngF*=#:$G)AfWQsG)w$S)X]%7RlE*Xgp6&aC,n&cK50(nCKf)Ojg40)I^i+O4s@Gnr,eQw.xfLnc(^#2X_pLkaW$#aO>+#kkP]4Hh'E#)?#0N92:Z-ss1h(1cm5/,X8[#nh^F*UuOv,uB7w^DcK+*lx3V/3&>c47qQd3jtuM(ZD3+0.Dsu5A?(E#H;o^$Fe75/$kn=%M9ST&ZWDigSQ^6&b>4##6iE0(BAhr&he,r%BX39%Fts5&RK^6&Bn/Q&kl*I)HJC;&iorS&>w-o[Tvd`*#IXN'hi-s$Jerv#CYl-$^3D_#3/1<-*.cK/U6)1LBHb8.BIs;(.TQh#)Zwd)W*'q%81[8%wLCt%JEPN'NNYN'n&0I$E?4;&5ta@&T((c'q#^8%pg3#-;_P>Y3;###sO7<-vq6m%hx,AF^I1hLMYYA#1T6&4(tcf%CoWt(e?lD#L8dG*B.=Z6:]d8/5a5g);Vq]9:4RxkdD24'lXZe$QLAq%dUl3`lHx_)kA0K2T4p?LtWY>-xUkA#;RWNMixSfL]=T$.p9Ft;NSDs%]m5<-iR47/@[59%FCsJNkAPS7KORS%9DH%bu:#s-03k%=WRjZ6mU.>>/H&##jLB@%L$FW-x%,NF:K[L,9_B7J3*gG3A7^0%Me#'=kE@`&]&&*'m+Ep.7%SN'D($Y0:-Dr&H&F>H,+B+EiH&+.=,]H)c_o:dSQ^6&Ef>SRp)l?-9Hg;-9r9s.0-/n&q<.S*>Oc&#T.=GMj]xK#@Oc##_qbf(Hpi]$QUcI)bf4O%Eff`*VhAW-rsL0ESV5Z0EjX?6kE9QAavl3'%H^e$t$(-)Y8`oC4whr?ejrP0,l<n/.aDL'rJ,$G$m.T%Zf/6Ad5qq%0bx##(DluuW-Zr#$`V4#R'+&#)WH(#Cb5A4od=<-Y(co$;Q:u$`S6C#ZktD#vt@T%VQ,G4pxJ+*hWTM'5P[]4CIFg1,I_Y,<RIw#:hW&7&&rI;Yb3.+nCV,+lciO'f$+T%1am<29Vgb*qMUu$E,jI)Ha*L)fw$],E3oh(G&%r%fXpb*x/;?/8LZ(+6^ATAISF[$[u*M(<C??,#fLd4]Uh<-(pqY$Vu<8&?fg'+7G3^4#&k^4+;=M(]@g;MgrV7#'R-iLx7),).gY7%0gt?#*e75/wHeF4*eHd)T$Y%$1awip$h[d'5pp#*5$;M(?qhtaqv0XV@ZXs$IN@l'C&SHDY-8='JT@b*.n>b#lk7Yuw?CC8#lhl/*&>uuW4>>#/EvT1ld0'#(?$(#8pm(#KaS%@6S]F-C=(D.x<7f3[(a5/(0Z&4?Dt/M@9.$$``Ca4nE'Y$D^jD#Gm%1Cjt9RDgd'R)m[C1Cdv#O*#89sCWq(@>wJ,W-Z$&+%,_$/&vNT7&DBHa3D0h)3v4a1++SN1+]6/W$-Q,cE,In59[<I60V`K._+FnqT7fiQ9,u''##mS=ump%_]*i##,[x->>Qt+M;IrY,*Bt`+lJ[=j16HSP/ZI(eZV7#`44,p/3L;]n$$,h.*B.i?#O$/F.7MbI)_2qB#^s'hl;)C9r9)TF4QNNjLXNTN*O>gq%EGjg(-v-n&f'Zu%E[9t%PhZ(%ad+'&i6kt$bZ=9%-J8.,;v`g(L3bP&Px1w#g79&(9^NoAE2Bu&EI0H)^$-7&rRqs-NJ&I&KSM(=39'n/npg#.SN7d),@g,;4#Tq'`Bxs$gx=?,.r%-+Yj/BFL&3&+ZljA+7/Co0-?cT%<f`Q&9%BQ&[vc01OB0u$1>cuu$8YY#Q*[0#FVs)#*n@-#mp@.*,x>m03^(l-?]<X]JopcNaMOZ6^H'>.sw>L/xx[]4x(dlLDZYA#BauS/Pf_l/7m7Z5F%8&4x.3T%xGSF4nGUv-[YWI)*>ND#&iv8%6C3p%qre-)q(J-)X##+%3Fc**I17s$n%f;6kRl_+L9N*.#SiZukh,##dG.P'Y>l@5C'0Q&U(1s-e$8@#N^[h(bYR1(nIs9)p65/(SmGr%Fvfe*6lJ-)x*?h>nr24'_GnI2ulWa*ln9n'+C36/](o*3/K7L(.O1v#^_-X--K*R1#5'F*9oUv#&&###hLfQ*0r7(#I]&*#=sgo.IR@p7;eYD4pf4a*S+D<-(fq-4'Z#t$7MN=(-tx>*2O_Xq5KA&,,kJj0j,24'$xPR&ptdYuT<+.)1PwC#Ub<5&cc>w#qL3=(@<]8.L9r/)/XDI0_@9K2bPQ>>$8E'oNE8a+taJV/FV<Z8F/96]YNo^fJ^8xtjvUcMki(,2T$t,*kiic)=>dp.o]d8/CtSI$LY)C&gS))3pM.)*V5+KMIqYF#nh(k'->=p%Ixmp%3@Fx'S<G(-AH0E<[URs$Oc:s$K*EAFH6Gj'O`im&M5xW&:1gX%%<Ld2g:os?]=2W'_wH,$J^XVHO+O9@Y11hPq41L&r2w%+F7$##b1e8.;JjD#Ktt20YAOZ6rKdG*1/2(&9N9@Mbi/F68SBj_wp))3#X'+%F?Bs1LH]X->:@m/O@ul0ZQXn2iod/:Eo;Q/guC`a5Ljl&^b-5/[;t+;sg%##i5``3NsC:%^wn8%#q<c4&p;F3xt.T.)$fF4IJ.^0HYMT/Zc7C#dI+gL)Oj?#a^D.3JU@lL5R(E4iSp.*D.Y)4^FP.)=MiR^/l-s$X8)o&bK`C$]qjT%WwZqNpEGT%6aJ>,E+Mv#VR.s$x02@,lK>N'ZJ'Q(,K?7&>p[@%f]<9%<D[m0i_nL(U@Tl'ROx[>e>mj'3AG>#PP,%&8x`C&j2KU.'e#R&-co_4X0X6/:mxM)e%Ns%u=%6&ZugYu0N%@#Ppe,MLNj$#S>c^?_0-w-laA7/GMrB#*=Z;%1Rmv$?l0x5V0q4.]<7.M<n'E#VF;8.InB40(e-)*L*+p%'*Ke$wU[[#S'o8%VNF5&m)w`*>Q-d)`(89&Ob)v#+1i_?o&k%vYJ`-,c[np%o:2SA:R5#YOUDw&O`mp%0*%<$^`h%%(KgppaKj$#(qC>RYQ^C4EoLm'RUO*e:sj;%NY:xMn%e12M.OF0rCw8%vC-p.)tf*%7pR;6T_^v-NB==$X5NVp[:d6%&4^E#+f<t$lU+C&W6EW-FP5W-;kj']X+T8@ZJ)<%U1lr-f$fa40k'u$rf_:8.<Z;%vV:X-`+/hct`J>,L+b(4u?lD#LooA$f(;k'&XdN%f]<9%MJE/Or,Hr/GQkV$4+@W$Of(?#kcR1(Qd<p[HX:X6^dOgLUrgE@WtH_uFO@_#KOx:d;:@W$p[/Q&.X?]OJgm##>*q@1Q,>>#oDsI36N.)*0Yw/($9Qv$a&SF4ca<+N&t>g)irQ2iicSC8Z$s-ET,HS/g@oW%o>mW%EqHM9absPBa&8db-LZ$,V5do/aT-I-14n-$NSKX@D)jW%b0EM0K#5D<+jMWA@$NJ:)Fgv->;gF4:&55(pv@+49n/I$c?RF4O;em0m+B+4Ia6.$>IHg)YflS.U,_oI1?U)0AYKq%n8qq%5vY=&obmV7e5X+3ZXR[#BS,)Oa2YX$7Yv5&>p[^uKsW9%Ym5R&Hxi/873L[0C*oB/'>g&OgpX>-_%as'x]P&#:>N)#)nJ@)tB7f3'>:8.x5MG)7#K+*`R6Z,q:Bf3V-vgLGF^_4+7Z;%sUjAdNQ/W7x^e&,&6KV.cr`8&ei[H)dv#;%7pW=&i`S^+lYaa*0*5W8HmE`u&&js$<(0$5`?Ss$1n^u$;&^M)Z8Do&aNs@&F+=',^PKB+&_gZH>_tk%#PMT.Eke%#+wdU&,ov<-4$R$<^XXKlHLr)5,@i*8KK0?d9^a^4a?/A&1S>s-qN888G%)d*ap0q.3WgQ&+Zgb.3736/,tC0(]1p8'A?:D3v^YlAv:38/xC^+4ckPcMN17<.[7%s$nM.)*%MfI2t?(E#m$8>-fqR:.xUKF*8MYGMTE`hLw<]s$YtTw0i^1*#M=]S)w.%q/;RI@#k%ko7je8E#_uvC#kkoA$>Gg;-OgGhL5ZKT8v$%Nq?P1v#DV=jLYvrc)eR/a#hLjD#-2kT#jVxV%6F9/D1(cA#PkY&#5IthU-RF6'SVW]+l<IP/,8MT.GlE<%GTXA^(`*w$YJ=c4ei1a4PGHb%R=]4VlX,Y)T$HM(%dm(5;$bD+OHe$,F;)=-KD$$>p/D)+vedfVxRM&5HPCi,U^i'#$),##H5[S#'h46#X?#h1na&],[YVO':]d8/^J8c=]k%SqO8x/3>U^:/Q4xC#^)-'=/OR]81AZcDOZeh(YI%xS(aul(-dhN'm9Xh>W'-BQ'e%r)Q/`K(W_uNB2gxkEwmT9(+MuNFY,Guu6N_n#Bv$8#:,>>#$V`v#a9h'>4h%?5D@=<%)c7C#EwWI'3C>b#Uwca7BM^9$fulXlU%B2'Ox7K(7j/Y&a$,i;H2Z'=UEf8%V``w$#fsH?YrQS%;RU%tWHno.Ab]w'.lh8.9t1=/MPsD##7'l:Fu[4;;kkD#X5ZA#C@ILMW^DU%,t@=%luF;Dt*4?#Oj_,)v2X2MRO$N:E0>T%%U]p%dF<4:nkgv$9BET'UdPN'](.s$VAI2RNO_hL@haV$h%`pENG/H)%]w`&T+@79=Nov#DLaC&]67HDsuQx-xjJ]=kK?/;M3Q:RGTG)4M+CO(]fMw'1jic)(g'hLKk@`a]kjp%RA>I$O.A`&F7lA#5tq]7,'?'A,KjV7u0<^O7F/j-<#OZSB8xiL$fXI)gBwmA;8<Z6:]d8/L`d8.J2:9%:MpPA&LT?-ew,?8%%;?#?I0g-45W0Y;(BoMu6t@Aewx##I/]j%deZi99g&##XEW@,$0[_;(<5b@Eff`*xlpmAeAM3r@Vd8/txgG3d5=k%Golw9[;_ZP+V#_$#IwYMj`>4M`hYOM.k-AOTg7o[O@rn*Z/dofgSdofL9DC&qnd;-<1v<-X^@fM#*+RO`)pU.$,>>#Z8`=%l=$##<WZ[$GD,c4@<Tv-<)'J3ubx:/uTER*nf)T/[sB:%'1clAbGNf<3'2L+IxCT.Cm=iC+xc<-k%BgL]2eTMh)C6&XgGb%P?%<&cY=kL9KihLf&E*'x'GC7/LVs-g`Af3a,MT9%PRv$k)_:%?;Rv$@7;X-WM@['p&SF46:[9KZ,E8*&enY#OS^F*`rH[->#dG*KE@[';-ekER[w,(iwa9%L@Yn*=F1dM5:2=-4eBM;.f8a#:WL7#Y3=&#$?$(#DJa)#t,>>#lLbI)_i&f)>&Yj)$8b.3.V&E#@mqB#(LT:/26MG)E]JD*:q'E#0VtT@gLM-*`M.)**e75/CMN:I,(G3barg._+4x8%nMnGZF3TS1#6.H)qd,i;`DDo&:t6c*uNgq%U?BU%#ZY8.4fXw53Iq^u`t$;%e'Nm/&:Bq%QnuB8v#2K(JW+>J'=/k(^VA^+>]5c*LC,w.,)ag(n2t-$$p#:;G3.iLc3)A.6]v7/:CE&57:^?.&>uu#[:rs-JdsjLlW;i/EI3Q/jYMT/*:Qv$?fh*%]1#`4amd)*mt'E#f/s0,]'*?#d,;mQTsaK+h/)T/[dr3;e[@<.^+r7/ohQ^,88%s.J:/dsQJrb,qL4T%CMt[5oti1)acC$-o%.#>?vXg3Zcun(U/Le;3=k@$L`?Y@0J###@NoV$3>jOKU3Wm/?H4.#p.e0#Jk>3#%Qo5#v0tD#vu.l'p;Tv-Y@u)4;[#;/1Hjh)GI)=-3(Qo$c-YD#%<3d&2cC26[Wt/6^DWp^1xYT%b:.w#9M-t$J#3Q&6MjP&o:x`*+`2@PonF,kBS3;?dFsq823rZ%XpT2'Q=r;.rC[<$?rl29Rk=vc9cK/&Xev)NnZACS2NgL:J6@'lr%.GVJMSY,>:KV6kC[3D`Zbg$'*p*%-6TrK:hkD#StN^,l9/$7x>^;.1Pr_,<2B.*D.Y)4)QO1)LET@#4h69%siuYuDg#nAKUaJ1Q-92'U[`?#%kAF*x(3=(*o-$&*bYIq5v9[0iV3E#qlB=%e,l>'/B;C'-9G01&r3t.n0MA5A<d31(7*KVRtH9I1Hf'/<#.GVtxxj-g/vq9Ved##NAYHN@(B.*Bi@6/BkY)4Rp0g*%M.<-k$b30+gB.*chq2)G.[-HW?X-;ovU1;U$%e-2AEU)90,pA)9rBPZ8Z;%4`,Y@U],[&;S^ZR*E;$B8@Y&#.*h<LB`/E#cG.%#d^''#>DW)#rF7D?Spl)4nb+`#$17e-YTm%RN+QDObg#9SwE?I3QZoA,nO*`#*>G$,v9`H*/Ijm/6^K3(@e4n&*EV?#6Np;-vRggL0oS+M6[t.LXOoUd6emG*LdPN'B:MZu#/R$tK9^m&.P%pAl/xq/pO+q&&8Yuu[-Zr#UG]5#_LXR--kN?3^nr?#AJ:?-aY?C#H=[x6-@QM95&,d3_w%>-xtu=6_uIPJZc.T&sQD+iuf$t-jMxCmdh[u.OY;B#BwIu-%O4jMHg*W#3%:-M7lS9C@dOQ'@t;D5cda$0quAuI>?b7/NpwF41Q*jLEQ-+#s%8d2Q6F`aQiou,<@,87'n>PAC<CdFEgN1)w4Kt?%.2m;l3Lq@;.g;K6a&;Q.+1/)KMYe$PsKW$:h.ZPV7ugPQN3$P28YCjQ6dA#WNmA#&90C-r:0C-nd,`-EQ+r;Z;H(&feg;)XsIb7#]tA#rs4C&xRX&#^Xd8`scc&#Zs*VJENYD4s4ck%7ZWI)pxJ+*$DXI)Ag<H*BS7C#W=[x6/8d8/X`WO'[&eD'V6JZ6F4p$5JNVk'0f:?#j5u&rL'bp%P^V_XJ4+X(rNh('_iF7'li*.)QYVZ>:lig*@7<5&g[^`NPQ]R0Vp(O'&VZa+h_4X?]GDdaQ7FD*]`[`*0PNK:LF[b4sJ))3GG(v#V4i?#BKc8/ri#j&5Y79%fkn9%>-h(*f-W@#]*>F)gMb03j,59%gp$-)Ob%[uoklbun;)D+BSV<-:<@u%EnK(G&Fv;%0E3jLZlfF4abL+*r*UfLg6lj1u:Rv$lsOA#s9uD#fE5T%D<#Z#N:7w#DTlN'9#2T/VN/E+Ks?)*,M(v#`f<I)0QeG=)]V?-&3g._QtgfQpof;$Psp>$.c_V$kgtG2Rd8e*P(U8.2oh;$6F*9%33TA=G02</#AJfL7hmi9RAn^5jK%##,R(f)b^Nb.3>XQ'lF?h-NZ[r^%=_F*w<7f3?E#6/:*YA#:I%K:GRT/)q#5@Mmg^n)Nl,##^?3O;h]rO'rQmK)dWkF5mwsl&mX.[#ObAm&lp34<?PhR;K)Wg(>:%<$q=e3DW,El)-;0F*k;g._BrQ)>EQGn&`#ai23o4o&rA(?'jQ9)3O0ZiEJGbY$B'0q%>jajLaVI1g?f'+*?`be)8+1GD88x*bQ+18.dR&E#s6Aj04k_a4GR6JCna#K)F5)c<8a%J3_KR9)ot3A-%mf45KDZ9%o(/H)Xf1+%hn/+,b*-p/tm?P1-e+-57=]>-^a%jLPo/gL;rJfLVqQuu;m6o#:WL7#c,_'#L[fI2(wX20KGM>$KD,G4=R]w'[@i?#</7T%DP=^4Z8fG#$C9Z7LjlN'@=I<$jm>4*LxTi<Rx^T7=IET%BDvs.t)9_OY?)#5V)ja#DUns$WXXY5.xY_+];9&4bjGN'iu3i(drUc+%?-w$[JIwKZdU`3W)Xf:#$&##^Mqv-?V6<.GTN/MTEZ)4u3YD#%2P,MF>B.*BxF)4)gB.*Z5>H3JMeC#k]>_/qcB.*ZNYXRqw@`aWkJU/<OqF*;+lgL#+6$,awV2MlO+I)V=DmL`Vii1<KqQ&Wf.cVnxV8&JQi.PU*'B-qv7d<i1KVMw?CJ)?SQX(YxOS7nFG$,D6eg)3ik&#%/5##$xg^#O*[0#m4n=HGxL*4O-YD#KnWq.gdeiLMW[x6E:H>#/7;Zu&O&n/j4s@$4BVcua^M2'?>>mLc0W?#U3v11-SKv#4DFbQKKoYG)Laf1#p=:v[PkA#BUl##2BN/M'0V:%fZX,2vx(u$d<7f3V&QA#-0ihL:?7@%G.<9/2,h.*Qts9%x@bW6c1eQkt/+M&X._guW$r>#gVYtA1u98I0#4HVn9Ac5nIU*8rs.P%MUeZT-^n<$/Yg%O$Oq%'kNmAORa^nJiLcS1>,B.*IcnF6aOZ`%AQg8.W#[]4+KbG3em.Z5'epq%ZTXp%pQ]p%xj%pAEBAK:)T<**X-&3Mfj#C-Ba9e;]pZIMa,CB#u>CsHDD6X1NhRg:b;q<1m'jmLfp,C-$lJfLt-gfLUhZY#:+[0#A@%%#A,>>#j2(T.+dfF4jR9k$[e_/);X^:/$aaI)QS1n<kxhha^904Lp$v3;YD]1;[Qnh2FvB0GdDRh#g=FU);_7>#q72a4SNvVfH@k,Po]_C%oj]e6lsQ]uB7A'.Ux[+M)FBJL2Kqx4U)t+;1gn+D.m+=%2]jj1pC,c4-7Aj069%J&#&Vv-F.@x6=J))35NCD3)dM''7$g8%a/`)3wW=Z-2MBdk:t'E#-+7x,T13QhbQV,D)S(KC`&PA#QbS1;Pup-4003n'm^va3*2X*4[iqI*;UG:&JeE9%Rw=ZGv8Yp%+0w8'88C[u>@n?$bY/t%C@'U%-GLW-;CP%;;'ev$Od?120kFK1<qf2'gH]J1fe./1Q(-.4-^R'AAk,;/Q0XN0exBf3`1UR'EbE9%[rAb*C8l>%h)pa%vFxtH#jMo&5E(:8S.V#0+`pd#qOO/29L2X:v+`3=uMKx,sw;;$][u2V.%S(#VC,+#eONn%*vU,;cpC(&/ijwA/2?X$@;gF44tFA#B(p6iNXE]-&[Qn*JL_$/ut0+*IAM.2%FXN'QE>N'Us14'$19ba1we5'-lfq)l^S$M(Po.)>A@I2DsH-)rCxFMZs5/(9[_B#w^Ta<BE6c&IATu@&.t>-ie1XM^Cww-'.uJ2&xf-6(CHr@GEH9M^;^;-I>;X-ggS&ZQO?>#^)V$#(4#Q:ZJvG*?,dNb4??j0n^?d)fG=c4Ze75/O_LB#@^r%,p]-6M.H'2-p%/v$=(2v#e2(?7BPDv#iE=n,qxrY$iUo+MFYxG=W?C,)+n,tLTRr$^`^Pu+At?g)dc4Z,E3Xx#@^8F4L_`;$5KB5SiibK&J&3>5klVb3C'pB&DFWAF'SK/)xTJ68^5M.3)VFb3Ql#r-f@79%rBGN'_DRf<;Vk2_gqD+5iAUHM8r<P*Ur(?#s)P]uV^FgLF$GE&TT.JM;k#u%:5$:57>D?#Jk*R/=sf@#[ou##43x-a)eA`aX%eu>j,KZ-N&B.*_02BmD%<9/aS2C&Lc7C#i?uD#R+OLsJxq_,t05GMGe*Q/>9`PiPhkD##jO%tK-[COnS$9.s/cA#p;ka(=X.x,@*9q%s]RN'R1Ub$>:wo%s2hN'#8H;H2>h2(K>MBoSuKs%n<]T%S`4j($[e9.<eH,*v:Bb*_@H>#wYRH);Nlu>UQp6&D@RW$>KNmf,_I6j((Nm/tfsC&q3n0#H)###f,eT-@7sd19OnA,p:Rv$C:H:7?pUSkOVJq&%>/X%)^dI%Gdc2L_YF<6RS(E%8c:J:7Hn2Lw05;6a-YEeBQCD3VT'T.HIYQ'meMI.*H)w$DtJm/KG>c4;lm=7G-5[$gYoGM=xcG*oIQp.-)b.3$pvC#7NQ51SQ^6&CjMH2N[@:.*Ks@??fo/16QbN9ss4O0<K<T'+<UN'X9GO0G(;Zu2We5&b*p$.up10(;GUG+*8=M(nqWN0mPX9';$/$PDD'0MxK@0)%L/X$[1cM?t7?5/3xH]%'I'Ab6M7A4_1IY>*)YlDi`r]$kWK$6P-g:/OJ,G401mo7xfG,*OKFs-sw4gLnPs?#L2JD*ZYPs-FL.lLtAng)]U(f)h=%'MI>a.3IO'TRsn+D#S:&E+8qU<)D*3)+t(AZ5u_uT'fmP7&xIG$,f.B^+uqUm(t=%w#w0O+3xT#f*)l:e347aV$F'pM'S@;Z#WYx>,)XM#PnE,N1(fk.)pSBm(?SCw,#sEI)7+Os%Bqa9%BC.W$7'D7'#+rW-CnK5oO'[ca4m&9]:O*t$:r:v#M.7s$Q[Rs$ROIs$x(^r-P-m&mBB_*#,s=x8>*m,*Cid8/64LT/a%K+*X+(5%R>Ua4#cx:/bwPl$`J))3pe2J'KwJr80SgJ)fUwG*:t*<oZW2E4*)vP9F$?g)vIDn<f3R>#EgBG;[rBR1jfVo&>0g6&ItD61QkI>#r@G.)Be:&5SQ^6&ZvHPT4gYp%<D#V'n4<<%I*_q)9E/g)M8Co/D@xN'`Qf8%N+AC#j+vw-U1RR9hde,;kr2x-oU-##%b$M;4UD%6B0^30,0mj']*JI4LhR>#eu.P'nT8n/dNl/(f3E6/n?^6&=2&_4+N[f)>k>F#fa:L;vM(&=AUwS%sHIE=WXtJ2R,U'#Q5b;6<G?`adhLS.d9%##'Bic)0Zc8/OM>c4tf`O'9mE$S]<p:/+dfF41tB:%2$Bp.Rp;+3H0$$.Vf-]-^u*O4:MlxFuoY>hR9OZ%FcC(,W4Qd67JHI4t'Tu.5gu$,%[s6/qh(%,d224'O>[tHLldo/-g5',kL7<$b8[-)2Z'Z-m5-;%?lv&M3w2E44h#nAdEFT%lnD<'Atoc2CJ###$&5uu^>tY#(*52'+F?']H1^=%&Y@C#'BshLcxV[,vl1T/&Cs?#HF#<.kK(E#=rgA4X]OS7dBC0%L$EHA=GjG)r34?$ZwLiLB*)i2&+O=$(Ck>$4J.EFT,HS/[IiD1OCuf_R+op%k4HgD?Qlp%q=46&0f$%/<55',T$p&G78'?-;1UV-Q=#B#Zr/Tr:`7C#Jva.3@/H9%WwM;7;E-n&S&bjL3HfT.ap8]Iu90:8pHCE#kLlX&x0vhL:6)V&5v4)>1+Vk+ht7hGG/5##(7$C#%,[0#[9F&#tYTC,lHI/2PeUS'*T&J3:=h@%wN4#'DvY'=FiK<0Vi[<.:VIs$_t`q;0BL$'087W$'e0Q0R#TWIE>)S(Ll?%b`6;(#%)###Z<D;-v'pu5gB%##9[:4.*pXjLkRU%6.bL+*e/ob46B@^$)J+gLE,@U6.DH5/61[s$[rL;$S4iK*D@E5&Yi(?#UtDv#Vp5X$.UMT'/8op0#AE/2M#.-)j`rk'MIIW$#Y)Z#u$`<h^+ws-$shu7/c#QUt2E.3/Vqs7X0kDYqUcT'4W_s8'Lo+/*P+q&%kNh#/n7T&xt/v7<0M&l5;U`<jA;%U,iGqT(c@C#[HSP/MB-a<qO`H*[5ZA#a&ID*nQ#O-1wHq$d;<@-D;J1(elf#,[]*.)w-C-Msh)K([0OT%ev6H)B2%>8cd/Zha?*$6M[l2(M4+O4nVSv$lWe3FBoWX(*2b**j'H9@oGBZ-N]du>',GQ:^'19&K[vU77jvU7)oc8/5kGA[;;Uv-3C.q._R(f))dWd=mSpS8?36%-uuNE*pK$123#wR&#;L@6n1l&H*hlh8GQA=%3[vc*15_e*%x+&>6?@+#+bA9.^?O&#6bD^Q323ae._`>&4D#k2Jpk;.BS7C#VhnJ)P#Lp.PV&K20gYKlvO%Q/6SQ9%sMHe2UH9Q/pUIs$3v*32O=,B#kpK)NqN5v.Y1vV-T0XR/w2>x#tNeA,M?VB#DS%`$oD-I2u>>T.$R>j'o6-a$MpBW$q&*x-?*-j'wCN/2YZ0r.%aL#$e>ojL5'wu#9DH%b'_A`a<wv.:c&al86lSU`142eM4lC)3$'8vnolqe;Ud0^#8=q4.OGqs7n9rP0`D@M._AY/>a^4t-DwU%8?ZtkkQ9o=-1>'32>6]x,GW(1.8H-s8#=[>620_1&oS:NL%+ei02>X'm-i@C#gu.l'kSng<cM8f3kM6-+5e'E#MSX$%aN*97Ck3X$^TBq%YKOT%X+/%>Yc798TnLj(`r+?,S,rK(ZP$q.1Ww[%58?X1&6mr%pK*:.2we+>4Z6=.bK'U%%DYt(+*7b3'NkA#j._'#9kP]4vbLs-@J,G4=6))-=:,HMMI:u$c^p#A#x9+*mq<W-X*.eQhlvo/JFw8%,3%iL_4QY%p&Ts$/(XX(/1102HZ%12FqV/>7=fB,Rt@W$p5Ea*8T4C/E9eIMwxZr%0T%?6?]$##%####;@dV#Fk9'##sgo.O7%s$Ut;8.^WQl$vEo8%Q4@E4Di^F*J1F(=2BcD4)][Y1iCrp%2g8b**76$,FwaeHE]@['sH4X$Gs*J-8tVe.x)pn/a)p$M;EGO-D'V=1%&>uu&HbA#*6i$#-fT%%/SK3Dx?Q&%QwM;7Y,f#/ap8]IG/cj2C.xE3wF'''wG,*<;we+>V:hDNm4oiL,nd##Dqbf(>83/%/+6ZIcXE#.TxJoLIt5/(jjm`F&^F&>t4n0#`cT-QtlIfL;AW$#c0;8Aq5h#?-B&##vF?(FXt*B,e0e5/xA@m'+.`B#Ps)9'W_`?#<$`5/13vN'n#GOMOho%[)`>;-gPBX:xcK>?u5)i#FgJ;*xg'30fXL7#r&U'#_4SspO5g4,B%r?@.*k9`AeXD#OnO`#Wljp%n#Pg$m$kC&Ac3#+Shqq.D7u;-9,lC/YgjJ2F#Nq/?0<S0.+CJ)u9jfoS`Fo$N,J-Z9M'eZS:G-Z1'Ea*nE0q.[5ZA#+SXTW.6[q&]d^Q&@T_Q&*'YK12cO]uqS<M-8F:-NL#3#RJ?6##'4-_#%,[0#U&U'#w_Tj2i8vW%xAOZ6nf(LNTV_*<mJc)4=^,7g;P2Q/Na59%RiuYuo[dM&6>;9%6sGp.Pu0eaKW7p_[W49%ijO_&X<^G%mX.W-iA3L#`XI%#1a9RBXLVH*.39Z-Vq'E#xpKD&0&d<-^U$6%joA=<HkEv#T@53%H,=g3^XLea7ZWR'p_`A&@2M[-?)mA#U2QP/G0lP&G^NC5.EC_&@GmYDB*xP'tK=v-JFKfLKUQ##<o>.QiX,87F4[HRH4vr-[5MG)RJ))3e)gAIul+r*P'#TRM8th'ju+b$&R:<dJcR&,AEOh#W-P`ML/6O-F/;P-B3J*HL'Pw$ChlPNSed##AEEjLJ&7g)7,B+4qiB.*Vr$B&wM't:6bkD#q'(]$G?._#dBkA#T-P2(/7r13<-DJ)RF(%,%kHlfNp@;-:D]5Lr>2O'+<UN'at+',H>0%,]C1tL9/gfL/^e(.$Zr*gb:Z)4#u`2(._#G-,TDo-YEkmFeNO?TJ2uo7FeO&#?fvN-0sJv[G7)62$&###''nl8S1fc)l>,<.6KHT%7`d5/)$fF4W69u$J(3.5epBd2p;6&4Z;^F*PsYV%3TgF%Lnw[#`h/e?C=V?#DsNT%sg:E*98cHa<PZ%blQ%##bkh8.aHXXA#6ili@GUv-2;XQ'j6Im%Mtu-&W-6gLOnkD#vcMD36TID*OIo.*@f68%Wg_p&WcS`$M&nD*=f]h(_N..MD6F7/1YuY#bn#&OTjexO%Ok'G)/$$Gb(@W$Zx_v#kf[h(;_1ENioHx-*5xfL?_3S8uNbxuW#Ls-v(@V8pn]G3/pLs-v#L2:^APd3>uv9.7Yvh-]L^8MHTx>-*6K'&@aH&40NSj%Fw(B#QBcgLRasIL,e@p&<lG<-7:^gLk]e(':q[?#'mGV'Xkw'&YK$YO33P,OrU'*'%t0n&>?<0:&ICr&k@qP%;`/E#D(U'#ckP]4NVC)4@HDqp5BGO-%=7BO1AsI3uE97&Q5%&4YS2N0NCPS7jpSs$5.,gLlX>;-C%Zca.oO]un8t30Y#LT7SQ^6&&NU['dbck+f6k=1iLsV7*TDX-&Qv92BdD2:HhG&#)G330Nke%#q@Rv$EX;r7vHFm'FUI$Tu9J@#s:MZu`a_51x;UN'H%w5&8)2['bdh9MtM_6&`+6SBf$o5&9)Gda<G?`a=`WlAmc5g)nk-q$nUFb3vg;hLc?i8.83kn%/M0+*pGLp.P^r%,UH)p:WW-12>/pc>Z@b1BsvgS/uN)%,DO%(#&7ZZ$9JQ%b:Ze9D#<[`*9]R]4v0J3b3cLs-9p&+4GU@lLCM^I*p&PA#%5E<%H@%Y0@9x:.(e*G4rfpG3J0xgW5Et6/k>Xa*BKk87jAqB#BR.@#$,97;#rk.)81gH):=p/La^k._.3[)49nQZ$F-BQ&Eg^40*rk6(C_39%a6We$%f]W%Tv:T.4)=.+%Lav5Dme&GoLR[-*:U=6]t)D+%8-/*_WxKQ.XZg)BH/9&i4b**F0Su-bhHf:du.t%ZTXp%/mg30EuW>-&;%T.5Q=(j':*/1%&>uug5wK#dxK'#Z)?T%0<(u$b]e`*P,Jq.H^Rl1ttV<f88``31m@d)OnSN'`f0-4'G7F%$R<vMWN;a4TEPd2sxs`>0,ub'UdPN'Kw_h(af<C&=tZw'/e1J<ZC%q.HLGD>NYB4;^&+J-iON]0%*Qv$S,]+4ewOLUG4_2'&'N7'p;`g&awA3LoL3X.ea&v-MH=dXsRQh-4IFZ.k'L,3l5MG)=J,1MF;;GDwAQ40DkuN'fHnrfb0,</*N_6&1WF<QD:>)#vwVp7i]a7Ok4P<MH,^_J)'=##bovA7iDPA#f'Nm'C8D'oB4vr-gc``3:ur;-RDGS./;gF4Xv]G3(`If394IH'(-1H2CbE9%<)V0(:>LJ)?aJvP,/lxF/hhdM%d-s(Ke8Q&Ht<9%sYrH,la*%,6lA=%VT5W-PMUe$nrOJM*R)%,(?<C#7DQ%bR?b%b[w$##/uSkX,Jo+MddVe.Bo6x,Y1Po$$tFA#Pbfv6ROr_,=qh&OGtq1TOq[W$m`w1(gYBu$Osus-EBniL+uKb*.x_5/Lw*t$*b1hL(^p@#6kGR&W<;@G]HkT%hmT/)NUupoH]Dd*?9T'M_])w$trF,ikj5c*M3fS(<),##[*Zr#tXM4#h?$)*K/B+4nEZd3tTM`NQ$lj1FHuD#wgAI$7dav$g7+gLI'E[*'f0F*(6CW-@^r%,r6q)'B7wS%2e8:+ri,$GV,;O'Zx&a<w0vG*s>k-$hg4',:rsG)lG%1(K-1p&u<G^$@i)h'40niLLAc(Nn41E#?`''#<H7f3fWfs7O14kOD:n=7G->x'nKx[-@GO.)X4H>#+Vfx&2EUN'=Tga%Qw<x#5(o]*^=D?#D_Ku$3;nY61$i?%_fJ^+:E-E3u?mG*XaY3'@?H`*R5PkFet;##1gx+;5oXfCS`mHH>;gF4S)ZA#`q>C&.*YA#)v8+4/]<9/K(+^,=gc-2NY8a#iT&],HaLG)#XD.3kHr;?J]B.*MiGuu#/8#.UCw4(ppnL(2w?s&xMnL(p'I5/g86E3TmBU%%N)#57(MZ#hZUK(G6Gj'_8m;%KH'#$p+0F*4LnXlCi/l'cH7L(Re080<+Ns$Rk5Z%&`7T%DGNl$X)$V%rQik%PYMN'N;/^+7eaS%o22h(PuP##u_^>$]U9a3g4h'#4dZ(#,sgo.]nr?#_2qB#LHAC%m#fF4X*Nb$Qmx6*/oGg)mc:.$fahR#k/iO'?0,0LKQf;-J*;2%*l0#v62r;?MvUpfkog`NXDkT[R;$Q/a@0F*<x+,0Je:p/GoA,M`4wvAwXt&#wfS=uSp(]$tU$##1ZaRNjQ7C#TOnE4[j:9/Bo6x,qVu_P%*oC#ikRIM8NQ6%+GbS7Z=1w,U=Nq.MZjT'68RV%JHfVnv8YOMB(c5&nu]?,m?@@)#TIh(j:hh$9x-W-Y;x32&T+L#Gf[%#LQK,.HM<MKS_EX]C0lD#wAOZ67RfC#24vr-VMi=.+^p8.8oc,*4vg8.u$:C4'm[u%4/Wm/C`Lv#4u?8%4&CW$f^l>>==rZ#1_VB49f:?#V^0#$jWWZ#WrcY#iH+U%V*p8%H*XP&F+&j0EONT%FY^p7;;alAZw%j0&j=q$(0DJqgLFq&^CwQ&kI%K)1el>>kmweM<cl>#3GAjKc*dkKP0E]F5?_n'ML$##3mqB#)^B.*lTm+#1^07/?29f3lc_T.V*fI*sd1g%H(C>,4r0f)nl8Dfo/>Q$5vl,E<wCk'[#QN')Q6N'I&AKqVvbQ/1rT[QjM.c#*RwV'.FXN',80e=F*,_J_WZ`*)7Tp.nd0'#dA&Kk/aKS%k9p7&m_3m&u5+%,J@cm[JK=<-)HTk04P,>#kpHJ)i5/%,&lM/:3F@&,nb*Q&ZJjeFm>,&#nh%nLVh<$S(EGA#eTeLCo=-Z$Q.<*gF@xC#;O>v&:Cuq&*<jW^A3Ac;)PP0&+eH<6qR[>62]5W-mPfLC<`,W.xPfLCgI(&P,m<u1E-GY>Zl0B#PYL7#]I%a41]^_nFnqwLRNK*'1i_K-X:G%M5DK)8Fev`43_Pm*VecTW@ixt%YNbp%?3PT%'6p*%g-ZZ_S9Cs2YH+F7oEUpB#4&v7T83T/2Mo+M,9o6%SXnY?IPW,E:`FgLd'Yx%a7e/U(.3-,#e<72l;/3/:DHT%?bN-Z=?'MWi&^%#sDFf*=ufQ/Rq@.*YZ*G49<ED#2`.P'gIF:&e)g#G(V[%'bmPV%/qYIqbgxH;uUI&cJeuN'&O1A4ZWL7#=4i$#xjP]4coTi),VW/2_w`f4>0.b4$sUv-/J*+33QM(G$Vk**M&I)*a+h+>7I6&'N`Gf**2?v#A)/W$M7a'M,-8]IJ_o:/*Zco/,&=#v5m6o#0/]^.bQk&#e9cK.O7%s$PLX^=e0g,3P9rI3UspG;qmj/25q'E#0k^208$5n&e7MZuL[?-dZ?99%B,d2T+=aW>.'EVn34l]u:`]j0=_V6T0fr[&r]HN'@%SN'KdAq$Dqp(G@dPW-):KU)R>K0MNjX>-5?f#5&&>uuEb/E#$b($#Kke%#Ql>x6v+RJ(6Ou)4>&oL(6/QA#lMVO'EEPJ(oQ2#P/ZaaaHGTp%IYjZ5+>Mm&guv_uEOP5&2@t.L91*L#E0nS%SbqXM5os.L[<1_A_k;##O%fc)7pWgL5VkD##j$30J[29/QT=*%rNSb%=ZVI/7V<Y+^A_8%jFCE+/#q7/Jbe<-Rf%a&>MF$>j5P.><SY2&%;s]$f_LgCB,nw'PFj8.6/^p%xR)aNB1cc-jEIu0T_d##-V>K&7]udMTT2;?,e./?IG:;$lics-Xt:oAF`vU7NGws]-EF:.:fcs-x:]8@U0?v$mT;^447T[-S;V/2/-97;jd^d3W5[O'[S96]7wmC#TK7q-N,mA#)kT1;9QY>-rNXvQ``0HMi3Sr#]M;4#.jd(#_O>+#rqXI)]?A8%x&9Z-^5^e*PQHQ/cI_Y,h#CD36hWs-3^3a*?#?<-f(H<-=OfT%G*<T'Q?F]#PO;Zu=okx#^KPN'?H:KE`pX=$d#b#=`IYC+9UC<&YYw'N%2CoMZ)?%NN[nG(SV&e&kr3i(v#PgLR95a&]S;S&#FNB++N'9RJWD]8TgRjk5r5<-*U&,2%,Y:vsiqR#]d/*#l,>>#*InG3j)^c$.a_$'OHad*:'?<-O:V9.xx[]4Be_$'&8_G3Td*gL7g(e20l)?#829E<=m,T%7F<5&jQ*NjnmdNBh*/30@qoi'k;^;-r*pJ2p:qN*dXo/Ld(J9&<PRW$,m8,MXJ;I2,W`0#%sS=uT^^xbAQ=8%f^]f$G1L;0_XDE%;7?QUDkF<%rxI?ppUG6s)bVa4Uk5e@Flo>85Cs%,uioNO<I>F-FxlYu?a-t-I7;?#SoA(M_XDZ@Kkkv-bqsUOV'G`W#LFc2TnV?#XqUV$NrKdMr7U*#QJce>JoT,N3;jINc)vw$U=tD#`1[s$KRPQ'hbK+*4LugLT?Gc,sO,G4fh_F*,PsD#ZD.&4^A%DZ?H=GJL+=mQiC.2YEn$SVA_wf)i7EC=>XjP&]R+7:?@R8%/owr%;..s$ST(g(GQ1g(G*Ft$>bNp%T#juLT)oGZQK<#.`D&pL=+xRV.`#Z%9&ef;D*X9%I$J[#DIiZ#NAct7dj5N'cN=g1D(kw$Cqa9%j8s22+;G##7NUR#fXL7#A@%%#+]&*#Q=h8.J]J0Y=V'f)6@L+*2`&02ickMCC12H*L@[s$YKM9/<iXI)`9K:%ja;2/JPo=%`)5I>Vrgd4sJ))3e$ng#TS)2KZ3eK#ef(Q&((%T.*n)D+,Fe(%Hp-H)>pfY#46A88eoMo&'P3O'-itW6cu7p&oaE;$x])mf$aTabB:m7&>d`G#<;Nu.-rBi%ORBh5;/Q;$e7VdEO80q%kkQ2PJ%SN'@L?N<:lUV$3Qqx4QYr.L7_JM'#pQ]4kN%##w-;a43@q_4pP[M.gW3c4@_TK1<muX$GMrB#[7%s$%A:$^V#aHk8htD#i48C#H7=01H.Zr%'%gxX:_LR'.AH<%Yw/GVHs7(s6PHT.i7ED#/fLv#TCnS%lI3p%MoUv#>7C_,pFw8%poj*47l-v$kkc(+.ceZA&guXf.#U(,&EKT%.wq;$lWe],7TP#>5p_:%2'k8%[>cuu/dqR#m'.8#xVH(#enl+#j17C#;(]%-GPl%MARUv-58xD*G^E.3X1E1)c^5N'%e75/Ab#V/k%AA4Yt=X(9]j=(=osx'Hxe^7s/s;&#t3?#T+V?#GYY>-jCsl&P']S%u:e8%u;rv#?7Rs$]IVS%w17W$=>3O1C[Ep%(fNW%bq26/lT'6&Lp-H)LIes$TcC&ZwkYT%^4%w#3;-t$>g2Q&/DN5&TbZ>#]^b2(3u?s$VMP2(bu^x$`kDJ4NUup%gW4K1*%GT%7r%>.0&]w'#T/B+97+9%2>###]3n0#u6wK#e:go%GB#,2Q6BZ$D%fu>Eq^`*da0<-=;G)%QjE9'%L`p$ikhDNBKaYP=X,41$)Tu.lMTE+wOk.),lYW-(s%iUGTWX(7+Lk+d0uc.jF9Gjpd[ca+okA#;+?D-psP<-9c3=-G3u?-t=58.)&>uu*IhA4ouv(#V+^*#=*]-#ux(u$*W8f3`APIDlcl8/Jgj/MbKJw#/7xM0HjE.3V.@x6g?%lL)3Xs7+1t89JlBgM5IlD#R]jj1GZU&$qSID*kh2Q/[?Ib*)>'32ES?S'_HgwQo8te)U^Zq&fc<**4(q+*A;vmLxj0J++i)M-;Q,W-cov<(>R']7=fuY#E_nW$0X/YuQLD%.ewZ=.oLR[-:Nx9&M0S=DxdoE++*>K1?JSR0@KKr.RFX+3fq.1M2H5kM-U:)FGEGSfABw_#.WZdF^gcR&6`c>##wBi>^Nb0>O:$##x]s[tsD%)Ngo$)3.V$;HPV'##./`)3$rh8.+e5N'^4mp8IlS<7tO,G4O4n8%f;Gb%5cK+*kA1C&58Ib.@Z5<.RM7Q/?RT:/p'8[#sY4j1EpX?-s,e#5*Zkv6tU>c4*c7C#[`JD*eL*T/*.=x-WqaN00H+G4$rUs-+K3jLPgtK3J29f38qs>-KVi:%`2V0(%3oE+/B7N'j`Zj',UEN9Qw.[#o67t-je7@#<eN9%RLOn0>..W$(A+**a,20(S6=9%bQjxF_pEs%hS(@-95ja-*`X$Bfs?L5js<[9)dT@#viQE3p%j4'+.MW-6&%W?QM-j:kbEZ#c)2K(TC2Z#P9p2'<RA2']>7d)*cKp7gmg6&`;rk'qi:U%^2^5'Z8Y?-.WZD-E2N:/kf%l'tLJfLW$euu7m6o#Dv$8#ouv(#Pb^=8?07s.%Ib5/k%AA4+R6.MiUnJ;^p>aP:o)G`?>k]%XEFT%5jlYuqVkp%t2%w#*@vV%9EC[-;%Ow9s5mr%lc=s%t4lW%1FA#,'c[)&vKi%$8A6`aSH'Ab?I,879g&##5rU%6#?rU@kwCc%nv;O+Nc7C#-@XA#l5MG)je&N0#c<9/2,h.*w7+gLCD9M)#or?#MYnan>7cR*]W)c%4Zkv6Uq9:@S4hSK]v>R&p3Pe$TeENTki7@#^[r1-W]/b*qv>k'J[k0(I=xK:[F3p%Yg#3'K6#R&x`8m(Rdjb3Ev+:&>3VC$ASN5&TC'QAWq[b%m]=I#_.4i(k9bt$]vC0(*UrS&C,uU&jiEa*D)@s?.on%'Ok<=$(KJkLF7_L2mrr8&?tOJ(/7l**Qb+O'*liq1E=YjBmPea*=F3p%43nmMO]>C/aHtWUZ####tVo9v%b/E#i4h'#8sgo.Zk[s$NI3u$'78s$ghh8.NU^fLP(NT/>'Y4WHSg.*W9%J3=^(WHs>cD4//EJ%e]]+4HrCZ#FtBd2X4Nv#T/7H)L8wh(q3k**?Si;([f7G6:wqO+U3Gr/p,=pN=R<G+I]V9/nfRH)io.P't)Sh&so]r0)7bX$$NWN2JU/3'o%:v#-;t-)'4Rk*j=b(43@r4`[8Nf<j%fH)nM@-)uq5C+(f-thY'sr$wloXu'2w.L]:5;-%E#,2]1eu>VB')3)RA7/lZ*G4L@Gm'mt+gL>1,c4N2'J3Lax9.081`5[uXb$uVW#/[::P%qEOA#B.i?#3GO,M#8T;-s]h@-ML+U%/'PA#n*3P]uX/A$5;[o&DXwW$Wsi8&P@?$&?Lb^7%(lQ'L9Bq%UYC6)<o8gL^WG`WB_jp%U3]W$xf.p&:K&M)&Mcu%B,h1*3Cuw5YFs4L+4>l$k&-S&,4`J:;[aP&]'N?#ql/&vhH5</.gGxk^3sMMRkXT%,%cgL*:S5/MQ10(L,vB=:Sp,;Iq(f)UWo%#e6IKWj/g%#oPUV$B]ET%HV>c4rcMD3QElc2&V'f)^K]s$kp/[#Dfn$$i.<9/N^?d)&i^F*a8,x6NSHt.?_#V/4&N*G@D$406HkE*XDrO'L41k(>Aq8.ZR4U%-3.L(6=mi9ZL<p%=)1Q9a4kE*#YTF*:@QM9]t=/(.+CJ)QG%P'gX/r%W8[d)o]0b*5B&^+%2>t6KNGN'w.2>$;llY#w7a+3M^53'F3T6&-BXF+Y(]fL99,,M0*A`absNP/An_l8Gf98.J1=/%m+ARj'%x[-So<NN3_lL%%*8f3&7&s$]JUv-RvNQ`ZJOl]dj,n&?S[&,&T^[M.AjV7t]vn&%U39/*oSU/,wFO0mbhw,U2Bm]Zr=;-NP+q&hj5?&m?m<M&>UkLM2oiL1wZd38#Fu-^45_+YEBQ&.####bJW[]eQW$#f&U'#Hc/*#rAxM(KZb-Xek-@C.B@m0xkB*[*)rx=_P[`&:'+W-R:Y0PxdAx^bc9KM;uJl%LRgi#B#L=Qen%pAZ^Hv-M&@I/+xET%d#_HOEY@Q-XWGiXjhjc<Hi$iL_R[b4B-Tv-$d(T/?;Rv$r);mQ4$*D#Ec0f3Y7]G]jSd@-hmxn/`cO;-Jlb[RRC_kL;nO4:_Mud+S:w8%#XQc*lKfW-4Vx<9sA(-%&0n;^A;gI*/auWKOq]:/&/V[eW(Ul%$O&9.O5+%,ok%<-(&U_.MT*r7U55%P]At>-qqFgL])E'8p&c&#lCKp7;Uot%Uuou,0AR]4`r1A=L>v1KY?Pd3KjdJ(x1l4%1[U:@Ke6pgqVZI%p#[)*s<RF4g_158VL-_#bN]@uDOII2ZRA-dBO)%,;FD#e7xc<-E1^s4:ZWT%G6`Z#iPhU%&^UU%^98@#Y-81(e/E^uoB-_u@^r%,I7)F(uCL^4?J5n&`;6V%Jh.%#&2P:v:q2##L`if(DqCP8KSae)ig'u$gfUv-?D,c4Jva.3OBRF4lbkw$m]q5/blWI)kL&l:w8&+.?H.)*O*r-4oM-C-DwWrAx$nY#6r_v#q8co/vC=gLfuMw$bK&r.*Z3E4@7?C+cCblA$A&+4vPxL2tu4'5G@372`$0q%A:7<$8I&(MbuX'k:O3p%H3KQ&%_v,*.Nds.`;7qndD24'^Ei_]w.lr-u+@PO#`8PbB68;QDTXD#)iRXN't,)OP*7qR#kYV-Iot6NLJf6N1A<I2eJJp/^,HTaq2h2DL_EN-9`AN-.;<jZN_)_].Ibd]i#<A+_Bgw[X@*11;If79j)m8/TJes.+h<782RY2(C-Uk$Bg(rBv_#.#`G_/#w`/A=K6Q,*R5hW$#ADs-q*5E=n6YR*4e3iMZFeY'iP#d3(CtPSF*nd*a@mjKX4V9/D15Q'_(4I)su3@]Z)E.3]@wP/;Mx_4NNg@#D8'dM=^@S'L9Bq%r]SSSpCndbBDOJMHj.FQWdRIM%xdiMr;pNM3#29//UFM$EFR<$M/I-)e+Kb*_eU@,Z8Z;%h@(i)3#BB+.Fi`+,$a*.g.7eHqHwdDY;u`4KhL50m((@KjShG*nJXX(u]a_&4Y:F.]+X'Av*ufLWrugLu3x0)tGMK(ajJ[uamjp%9nUe3Ing6&T/L<.1GG##t+Sg1;^U7#6I5+#[34]-[+X5ATa0rC:[kD#f5)c<?-Yn*DrU%6o:gF4Uq_;6mb7%-^frk'&VW/2al+c4#c<9/jBFA#nXQ@))&BV-t&0f$iq@@#ZfrQN<0</M;/h30q>ZV%6V@Z$ELeW$sd/+%>POI)2:_T7j>$40Xi5C/1BTe$g>3vQmY:C&8ip/`'0lT%m5UY$aYT5'j#%+%WK*L)OoU,`KmHK1Y&U'##=M,#P4Ls-VL$b[+EB3k9^U:%^h)Q/XdLL.qSID*`#SU/#qVa4>U^:/@=@8%.NA.*HEe;%4CMX-Nh0R3LRM8.uiWI)&V'f)$%?v$ULBl)nLND#/*i$%r%.[']+,N'bB4g1Cp8G=[x`[$BnEt$TQC80,7nY#W:C[9fYu>#$>w21csiE4p>FX00g?['7mXv#H,:V4t'Tu.>+H(+=Vb31Dr<j$H90U%%C*^6#i&&=%(Yw$H[@<$A4A60@k,&4xq)v#^GOgEHf_;$d]H+<%I_41ZRu9:d]6]#Vmt=$[G>cEc.UiLHU2E4FWmC[.lF?%A7es-j?%lLn>GA#af^h&:M3&'PBL4Kh+wJV93)$>qx8;-qp>%.Ft^`*M*VX-b><r7#t@pALm3/M9]sfL(Mvu#-BTs-N[3X?3hTN(jAqB#6Gl/MaP&J3>)V:%/LL*35xrB#ANCD3U+BJ)u'nof,SSfLmai/<X`+t&hC5Y#RwC`)a^U/2fl+G-P-=;&9j-n&wbCH-R-%*.jbuc*ERsp.2.92#7[bZ.<_XD#BY0f)<Lp+M[AsI3O//:&U-J%(`/0i)p0Q=93KBxZL:/GVOcSBf1uRpAlN&N0lpXPSi=^u,edNw$q/Biu%]r%,[.PwLU41u&fatG2,?a?S.ecgL=IG,MX/'<T#rJfLXtHuu5dqR#VYL7#Etgo.R4r?#S,>D<i^a/2@T/o8'x)?otS1ES$0Q.<#XNj1l&B8%=EJ,M=htD#L(=V/rl?m/lHSP/k%AA4@Gp;-3Wvp/BG#v,R[<9/eF;=-oMq8%-GAHFKB@:7jqH2M-j?lLJD/l'u7M_&jdj?#rv)E*qd8x,OgGj'9^Q0%@ws9%Zh;Z#DqNt$-(-:7n_&Q&MmhG)Z5Z;%wlc'&a=.W$Xg^[#-ZqV%Q%@8%j^l/(vZrD+6fL;$'=)N9Fva?%5P(Z#m^Wu-_Pgt:Uoh;$D@es$P9OE4B0gQ&R*49%5C)EumET_-TYp9;%DF,MN'q2'H4>1DS]/^+fFGC+:uL;$$4;j9fj^79ft50)ekjp%@mIeMtFZ.<F^p8%g/Bq&_)C:%aatT%mV<hYeE:,)XHMhLdw(hLKai,)J6;iLX#Hd.0i-s$um#`-m_.S<Z.D.N)gXpTRu?>#8A6`aN_4Vd7`###Gtn8%E^os7/Z4K1JC[x6.-[.09Tr>?(i9E*q>cp%ANnT.*p2GV,/eX.&qi0&)o=E*jc*??:^<b7YX$##%&>uu1LDO#exK'#s$(,)ig'u$^#:u$BKc8/>NQ_#OJ,G4BY9+*xQ:a#ZcPW-2))C&8a^/)CSwULv=N/%vA>E(w0a?#1t$<&U2*e)ft@[#aXSM',YCv#+=Z;%5kQ_#m#Uw-^1),+SQ^6&YILk+f&4dAYN`r&:&Dk'A)4?,>EsSA(jgi#^[D'6LQ9U%<;MYP)YfN..E3</#uoJ1>J>>#IOxUd.N4J_wS4-v@@@7]tj(E4i@=<%Q^n)3wHeF4%v)D#rPR]8nqis9gxiW%6T(T9Aj=JCZ3QR0&eH*Nef`S&H+i._.c&3D*Y?gLTg0N0vv1qB&V*R0e,_6&&VgQ&UY_uGX@Jt%Y7PV-@q$292g#f;a%:B#?S<+3o1(D.#Co8%cR,'Zt%,G4[m5%-5O-29<n0B#S9Bq%(P%pA-]kA#`Mou%3Y79%fkn9%8-X`<XZ.%,54S$l_,EK$_-$Y?.pp/)Ph%%#s7TN*pA#&#_,>>#J+$b[-BqB#6iZx6Kf^I*j$%c*[jPj0p*D.3`s-)*s9uD#8x%-*]::8.']is$V2huG,+7>@wi7?5B-PJ(^kR9:jB:=%WFf?NuZSN0V7ep8adAJ-cwYP1`Tlp%8P=>9e%iE%BTdS&*w`A5qV`I2%/5##JaqR#FYL7#vD-(#htC5%x]V(G''6K)%m8+*W&Qs-MIBmA?^4K1=^ZC#vH=GJQrko&kB0n&ju>b+Y5mr%m_ur-^m;m/d?&n/;-/>JbqR_H4SD_&FI#w-u.er%(@>gLZI`RB%TET%w6@$#)@?_#vcS=uMl<GMjsXc2;kjH#U=gBHpSYA#kV3a*<]x;-aEbn21ndA%q8T@#<thZ,'luN'4,eS&EHoUd9c0'59Yhu&NqK-)N]gu&=%)n&VIa6&QP,nA96a*.k#w('m79+0BvGd.gFYF'mDTC/q4>>#BiZ.Mg9_;.wN:tLjc6lLGIfm04hnQ/l5MG)%(cI)eF8g:)4vG*lH&iGN8G#?U6O@Ta@5p/g-fYd4*Ih,tNd'#+f68%;L:`sWBRS.#+&32TW(E#G`wv$7QCD37(]%-Gq[s$nEZd3jYo.C#v7V%Ko2:8%eJ>#:&(N2e(/t%;0$6DVek._L@&30&cH>#vgYTBJXHh,w2)^Qdu*(mYe6##koCG2J3`l8p^%##4I*r$^Vd8/OM>c4]c?#6/X<j0J29f3;jE.3jpB:%&NC%IG[^C4B4vr-KSY,3/J.3W+`kbbSD(_,P`ZP0RGMP06*K7/HoN/2jwDm/,EsA+6u([,TO^Z+wOk.)Xjh;$3Xl>#1I.A6;bFU%m>5m/[LoQ035R?$OiVP0>pp7/L1Cf)?E)n'<9&A,L>C;.d%GS0xj*H$Jd-d)Hr@QMsOPk%W<AqKUU$lL27((%sUFb3UDjc)P=8u.LC<t-mEC+=N;d;%6oL#=b9*?#3B/[uE]r%,BDQ[-i'=%'./Wt(0RO7,V5do/w0=E?9/:%0SROA>Pn''#E4bm-YN:R3'EC_&eWjn8bh]&,Uk_4NBrJfLY*euu8a$o#;WL7#Ie[%#mj9'#?_o;%)QGp.K5ZA#+Js9)Xq'E#J<k-$<X8[#D2+E*.W<fq'[8^Fr'CR'N6nS'n&tj0Ngt#'TC^U@;=XE&Mw(X._KjV78wgt%&;AgLjgXZ-LMV_&Z$hC*iF36JmvR/M^dFR2_heT.UCT&#`P0,.iw9hLlnneMCK/)*obQP//p^I*r5]guGWG0(nh.VmN+q4L(uqd-s`v9)h65/(wI620KpAU)vc,U;/Q4)b3O)qifgw_8oQXA#j*'I?jHuD#)QHN:?FuD4&Kn^NVU)R>&L(^Gkhr62pJ-pSc[&n&to69IrccrHSu=p/<I+Z-V]mHHi?%).C2E[&]m#n&I/N*IS),##fhp:#dC)4#njP]4>Hi/YM3YD#ANVx1K>VZ>F>2Z>#HCh1/ZjgCTC#hL(mPA#j:;$#$)>>#3bhR#:PwA-8xKW3sSGA#?sGA#mIYkOD'k/Q<xhH-ZIwA-5.uD5]rgo.7u[%-Ie%s$`Ld5/OwAv-t-iI3x.X'8Y`:v#R#fZ,cU3n&K''$.n'cgL';TSNofB(M0Hv<Mkq4:.Vq'E#V)ZA#lAqB#ulqB#c9$)Q/$FA+s`/L>dgZ&#R^_Eewrnu5WiU/:5UlS/J-3:'-AsgER1p#ICu;9/SFSV%JPW)3Rld6&fUgQ&B2t_.fGG$G4aWfMY9BSSf[e3WZ9qi;uQbA#)rEp.jpB'#5.3.+=bXD#+gB.*_]B.*p+kv>*H+0j7nCJ)I(^:/Zx%P^hVnH)4()m]4toc2jd0cV.+CJ)`f+%,NgAE+gpMk+'O%1CWd$H)Zs/ppPRQ>#s[X]+_G>d3jL-29?X<)u0reC#D`;B%t,1c%HUD78K9mAQJi1e$lc-`a//d%bHjB.M8=>)4caoW-CdX^9:&MJH#w&CI,OHc*hjks-%eDd*FPZ&FJ63D#d,;mQ_7F#:Uj=vGW'3)%/TEt&413AFP[jJM/g=,Mp2?j'm'4[9AJb?'S=@<.m-mm'JNXA#X?lD#r3lD#C5e6Mb.ilOPg2YR:@-D-0$=7%aZ/i)8@'E#Ze75/kh:8.x5MG)lF?`-*r&o=vT@f=dcf+49U$]8n4])*3ZWI)DGoX%rwiY?=#J&#?CAm/<G?`avSU`3`7$0b@Vd8/e@)W-hiR<]*$AX-K)'J39T5W-ac-1*L7<9/>Q8S[dFBJ)ns[872mjp%QuSS7@PT>&)[[T.9HB:%=WRGrosC0(4ES/L33Da3Z8Z;%]I=7Gu1OS7w+e<(ShZJrO>qW.V8Fn.>5Z,%QnIs-CT+T8K_PH3>)V:%8rPv,uwF$-%@'E#o(6]6'jN4B#3U>??'Xr0oMqp%mU/^b%#]P'j;A+'=SaS&@63W%?IUk+*HG$G'Dbo7Rw)0r_$)>Pd<ai0c*U-M(2]k86<9Z-]U:p7(6^;.e?qp&m=D?#Z?_a<7)'Y&8iNE&p`c[Ji3;TNure`*&HhH2T&4d<9W&F.@Z$I2-*c6&G&0E@-^xK#5#x%#$sgo.D`SQ_cYfF4dD$SLRDG1:W5YD4#_-R'O%%a43<wf)D:AT%*^59%Of^p7R$R)E/S7x*TI640nQl$GC_39%N_/F.H/5##><hLRCJtC8<&H,*@/)pRAsPsMc(_kNLO+J-D@7I-rHbJ-xa7m%d>2E#<7>##5f1$#KXI%#A,>>#R`?<.ae&>.@uGg)4$:u$rdK#$]Y9<7es]s$6l75@C1079(f:6L.=$UCPNl>#c98(Om=KP8cmm'M^`O[VKb5@-'PuY#:S)]bgIE)uU+ffLeM?>#6;6`a[E<kF`o###-xHq$d3YD#vIa$sw^Mh)Z]B.*$9]_%]_;@&)#X)>j_ox$U4,J&8]Rn&1DIT%hRFA#uXS]$I.)Zu9aDYM/Nu$MYjV7#lUcmh@wvM9R/p*@[q'E#NNg@#XNI:0^(Ki%kLs%$MHf6<6?3XCQ<3X&W)sH&(jD#5U7u?,?4Q91$),##;j6o#&_U7#pKOH8H0.O=gc``3?;Rv$Hs=`%vabW-:,hUR[lsJ2Vw(Ka>a7V#x,:g<SQ^6&<V4n0dWDJ)[GMiL$qoZ7#WR&#L5ZI5f5wK#PZI%#YH?D*lK7f3bR(f)QUe8%6F&krUlB>Z`VYu-YQ&#GDTN2'RN7Y6q40J)[x):8Yai>?`&5u-'O=_3oo)*M$M):8B/pcag[4_ADOs`dS?r`fL]l`%lm]c;M+p,3l5MG)00tV$0=rkLnxlhLVUa8Ab^,g)Dg#K)'m_OT+qQKD4HNf<ru`Q&%W5s-E2Wa*pPFm0pg=KV93dr/dO(<-JX1p/JA+$$9DH%bbEq^fnv?D*qAJaH7(kf%u8nt/>p<P(iw37/C:uw5pCf`*Xrj9.?m1,'vL>K+++?V-w:+.)%1##5XUoUd6c68%Mn6`#%,[0#n2h'#7pm(#Qi8*#<sgo.&Sg[%l-YD#N<Tv-Y@u)4;T#)<a%,oJ&sl2rC,O1))87<.K5^+4,<8q*(Pm&4?iHT%.Ru/(/`Cv#@t4j'F*'U%bNKFagL#Xn4HNf<=jRi+CaZv._51hLlxE^47=.[#6FN5&i8j+l0@E]&r=Mp+)0Xa+mICZ@g7+WB1nPX%R2Puu.BLn#n-78#0WajL#o=c4SaJ$MxX(Y$R4r?#xK75/+utA#-Pt7:%6J.*T=)?#LAQb<I(B=$oDc$G5Ai+VBKhG)@<*l]Vg>7&ZvUH,0mc9%,[3ID;(G?%F.eoL]J)W%Ge2'OSSjA+VF8Yc`MMo&>Zwm.AAWK(nQ3a*[Rp?L<Mfo7?&72LV$s;-th>Q1Z5C<-FArq-9`]U%D,P:vWv<##?7:;-n1S_48tFA#ocWI)]_d5/s/hf1'i&$Ru<lY%0tSc3fFs_,A8od)=Ln8%f&/F4tMFT[r;^lSD#-b<pGc40i^iB>_Q>n&cP>B,Irl>#LOT6&rr`R85Ht2('5a.qHXVp@]3=&#C9OA#^$Jw#0ljj1#.@x6G%AA4XV+s6.iMB#2k:[,91&),je&h;=.sV$O+n`aY2Vg(/>CS[Xa6a*81ei=M*cT%4FIWAS-2Q&>xCZ#%BGYuH6cqEruK6;B['5'#u;Q83Ss9).)4I)Ui[C#iXk1('0BZuJEV?#.Aaa,nFt1BHIh7'h*.5/>X(58oUix=hSm*3jpB:%5Yb?//W8f3PwugL2LXF3ui``3E9rk1Lknh*o'/V8ww(t.[q[P/`Cr?#_C3H*K29f3klBC%=Dn;%#ww;77QSc/,ig19g2LB#d9Bq%U'kp%2J(v#9Nr.)QBER8=END#@PC;$Jdhg(JYl:.fv?E*Btu3'[-xW$Q>+.-e7'JI(&Fk'@>5pDvbZ6'Y<=A#@6>3'IUV72F-:]$=r:Z#FJY/_un+M(ph(@,G@,hLDl$AkDec&#SoIfL31YS70^g'&H*#,2WkQX-<k6K)eHE$@3UkD#T2s<.K)'J3TEW@,LKdd3w:Pk%qU.F4pDSS7u1,;Q.iBJ)tf0I$A5m'&S[A(Mf_UU'<N)H&J=D?#7Ji?#K85#06VXhL4s2-,aM:&5`Adofab$LEV_d##L38R5l1Fa*kk]01Ne4D#+,h+>5cY'4o[Vp$V76c4V.gJV12c&>;'u-4GG)qL+#j0(M#N&#bRe8.(*V$#01jt-Px/YIYJ6Z&=sLX8K4am/ew*<8GN*A'_CwW-c#tG.Xriq2V2PuuMOTU#>ni4#^d0'#]S#)<_Zdv$%kBB#31=n/:N.)*c#)T&<B<b$.CEw&TkV?#U,AU.qmlS&)d@^$0IEw&TeM?#J+AU.%5YY##QKS%.rdl/BBGxQ)[7#LLHE/2o>,W-aTK=Lg7aQ&.:UdMkv9Q&r-)w,`'tfMeqhTMBU47Mlv0Q&bBTn&:=OX(T`4JCXok,2j^''#urgo.$uh8./&>c4(cm5/gt_F*3kDE4$xn8%i.q.*6)MT/WFF<%(ffx$Z,u874w#8)U6U9ChXD@,hPxF4*Y0/)G??D:.G42(s[Mc+L^;A+1o'f)km7],ulEY/CaC'-@hI&,vksd+BEX^,R$m8/Fv[.M7_Cj(aQJQ8)kOe$$0;*#<CCgC:WZ?$<tfi'SVW]+q9x'0b$(,)8bCE4+V)..-uxfLnSB]$J(-xLlM8j-^kp6*2:;H*Mo_D4);IW-mF9q#:Z1iD4pU]=Rb9:<^QF?#a>Jq3Nu`v1EXt@7nMdt(7m,]M>2Y?M<>1M^x.C71pxbTBwNO,<,vNWS-m8d=E<:>(`QlDM>l;i-nxxgkhgJ%#epkm8,h4%P3D3x'7*;mQ8')HE(f>C+?m0W$8)V_&7In;-Ze7u-/;`PMwIN5G2*$Z$5ep/1]nl+#h`-0#ClP]4:.`p$WMq8.t-YD#wXnp._R(f)fwpU@fG[m0s&X:.(=vn_@5gI*1<GT.*EY=7IdD.&=3M^>_UeA,#B(]76WgoLvQX:.cXd4%p.5k:VF39%/:FT%+41hLnLOa*nx:?#1i:910ue<(8%DT.Ia39%h)Tg1@feGVl1A2+T^^u$Pi5lLrx_u$tINMK49HN'J6Eb.X%db.2x[p%uc=v#/g/,N&2.Q/V.`v#;S69%Z5Ms7hj'NMOL2V$L1Nq2omP7&vf8UDY-;s)'=5#%8m3fMA&fS':%:i<`/Bb.MO/#1:oLJ:xrP<.Vh$##QM>c4]ci:%2h'u$_/_:%^#YA#V?(E#jpB:%49Q.<nBO<oJT$Y%XdZN';Bw8'v<<6/`2pY#:fCZ#F;5fa]ZajLjVdYu+tR=%P9U+.Od>3'bdpQ&>edY6ds7N1CrFJC4)UQ(?XLq@XT>qVwLO&#/Xsn%<?uM0E@%%#Uqn%#(%Dd*^HZT%ne,87Xp[i9i%6D<#1fu>3<?PACGo+DSRH]Fd^x7ItiQiKQlRfL24%E3kq?lL59MhLI]XjL?ePhLWeH1Mw?`8.C@.lL-,7&4VnLhL#xSfL)P5W-Jc-F%e>Bb.(N_$'-WC_&u>.F%Q%j_&u5w92=J[w'f;'F.(`Vw0gZmS/6cKZ$q5(r.9vcG*5LCB#eXrh7hk7L#%`kA#N^c8.$K6E#Q2^q)]T9Z7.IMX-fV:U)^-UfL@RM=-Rmcs-=&4GMAiqwMKiW^-vk*R<[QHb%?K_'/^.'7*f)*C&9iu05gpH]u8M<kFssw9),LSh,1]Nh#Ps_t:pc[O^3[uD45dkP93hYH3vxPA#]nr?#*mJL,8vUG%;ccYu*GlD3V*KN'w3pauXb3,)V@oW%6)2H2'=)W%2=W3&=*niLx</W$0M5W$O:m-N?Gp;-OC-qTR$+4#$?$(#DkP]4;JjD#q3q+MhPK^$*H8f3MV&E#tt[:.@Cr?#Lkc<.n[Ex-0S<+3svEYPxa^/)FkWp%)WKTRN?C%b3VJ?5_2Q7&B35j'BCn8%Q^,n&8D*T^toeh%`8iJ(r<A9%P_`;$[whhattGG*e%O&+s)gW$bdOt$%M3DW[MTp&3uR;O?tJfL3CUP8BOQJVn'q`$mvx(<.:Qv$@qoXHN7)H*5:dVJC$gG3N2au2P1@Y6=Fr+*Ukjp%Xr^U[BF&spq_B`$lqS-29=w]6QeLR'NRUZ$p'-e<,f><-=>=J-lh#]%p^?D*mT%##JEZd3aIcI)OHlD<Js]G3lo-W-5wetJ.0&],hcWI3dv>t$huc-3W%V%6,R(f)%cK+*eh3n/+Q-i1`rH[-+5WN&^8;J%[XK1gZZx>,U,[)*C01,)revP/O88#,eFvY#cT+T%SF%W$S9k5&XKxnL&J4j1>.leZV-]S%8x_;$',Kv#I09U%D1M?#cq*T%jIB+*JIIW$V@Z>#^*@788a,<.4fju5=6M`$&,KF*,h,V/jW/<-jkem/nB7f39`p>,3>$u'#`2D%#-FZuav_v%sGYp%_<9a<(#h>?u)ShC^EHJV_+#C#/MnS[..Pn:c.Is*]Q(01>0Yp%Pn(9'AChT7Kq:m&8eI4VivJ%#Pnl+#`,1R)0,.E&_'(]$Agk;-WIM;$qAGA#bBKQC>Vd8/.'ui,=ZKI3]kuN'voQN'dDNa*(;XS7?$[w'u+poSgk72L=7BI$++:B#E/)Zu*6x:.wP]X%1-92L534Q'n0hHMFMu$MVtb7MImN4Y#YkA#gvG<-q>#P&RUZ##EL7%#v,>>#8q2-*xn65/YYMT/ZntD#+ri?#l<3Q/V0O;QPSd>>JBj;7b$MkLhY>@P?EKO0:E9J'+g*J3Of(iMr@AL()bQ'M2+0I,VkAm&b[GG*Vh/Q&bO#,*&9>F%0=$Z$]'`B#Y8cOU9xlYu/&;T.Oh<#(OI5s-ot,JMR`T#,bq.W$0#8F%^FIs$HjvD-rrBdNmFt1Bt4,MVO%fc)t#BJ1Hw(588<.J3jAqB#jBFA#5d(h$G2h*%S*@K)^:q8.J1&N0s4^+4ET:u$O3rhL`Kj?#q^D.3'1YX(8FxpA4>M0(xd&n/NcSs67$iB+h,kb1OG=GJe3'+*d;_U%<='Q&gJ3E*_3sMM:F[m/wi*.)]j,n&T]Ss6(E_41&@Zr@PWuAJ3-kE*dM?;%2/%V%Ut@<$v8YkMiW/%#q+wi$#+[0#<:r$#vGs(EFO7U/Z^<c4ubLs-?vX>hbKG8.%2)s45_Cfs4HNf<ZNk^,UHNx/gi;'#&&>uulcaL#/HqhL5R](#t'lI)I*5N'5J@A4kon:/u?g?.E2&]$[d^5/xH:a#lQiKCBco>GlHuD#[Z*G4=9cu>`Ul?,`*GO4n`&QAmlR;6qOa(=l:hs-F8km1VTLiUDHV5.liIv5LC0m&?xqJ'1>#G$SF8Q0X0J[#xt.&GEZ-)*YMbI)L?'32LI)@,2Dko7mGV&1Aesl&#Gn>#d(o,&]3n0#?*nW&aw?##Z=tM(E##YuflES7%####Ep*'%jm95&j6IP/rR5:/9k_a4lT&],Fp?d)xj-??-dEj1:?mcM_aud3bn8CG<00>7]-_e*PB830o4G&%vUSx$'4%B,+Dor64HNf<(flJ)$di21G>K3O-IDD+%J_/DL56T/b5[A.X[ucW+7S'5$Zqr$>.f:d1pKc`rCRl(h6el/@RGS7iB?S'ZV6C#l+]]4BY)C&2#>c4HYMT/cVYD4*V7-*XHhx$.^NjL+#f)*dh3^Oa%NT/7$l]#k;ic)J@<=.?J$d1d+.X-7Vsv8ObrVA-nT99+G9M2[Z:K2CO[LMj*1q/&M&$RC45I<Jlhr@vww-+tM-1;Rl.C#;u.T,[pV-2fvDG-&GhlBk*OD/1R?^+gl]Q'<WuL>W1<5&W_QC+7k6$?p*Ou-xu?C#gMRWA_Gc>#O`#1##.vV%nFQIaQ6F`aJ')58k=2A=5T;MBUkDYGPNEa*S-'U.Jva.3U>un%b&]krV1Va%7^fDNgXB%5:(p.)b%t]+w<Gl'vT/^+#&X.)isu/(3oGs-wdl/C8rJe$f*wcM/'x&FQ.ge$m`U4)aqgI)#3XI)hmT/)H@CMqdD24'/CP/_48F2_R7u8NU`k9'%b2@9$u`e$cf;`&QuV_&lI`e$D*be$q3n0#%ej-$Yl&/L8Aqo%M,@D*j6IP/4MR]4i`Db3QvQJ(oNv)4v;l5/b@.@#o6Lq@c+T%oRSrE3ntSK+PA-H+?BEoAY&4##D3vN';$MDFA'[C#-Q(^u%>,A#$Q$caO4PS7jF$.$265=1ue`e$Gj:`&sSu8.<G?`aG$pl(?x###9&Y:.1Pr_,xgmg):5gb4GD]=%m5/3%5o-YuWVZ`&xr0DjL4&]$]f4e#]a7a3H+w`afbUW-=W#$(q%*b)pE/%#0U#l$b,rE@/(*20n6Ha$xL+$%h3YD#g3C(4(:ff$b+BqBi3T)=FR-A0k4EO:=>Ad<30I1g>OGb%GuqO9$=l%l'rQJV]0IJr$ute)V+T['/Rf'&C3[['Ct[kXC&.GVYu8>,tJJ`Ep)7#6:<Gm/)7RP/cx#J*_?]0W;Npk&%tDJ)`(6caYZa#565l-$)i'B#UmTbE;>^K2.+CJ)_gX>-?j4Z-)7&Xf+^xK#Cb($#I$(,)^M;Qh:k1e3)qRF4e7+w$c<VR>f1=VED74J4PkB`aYr6;ASxSd55W'54XQ`nD#.w.:Wx'm9p]iB,x;#,2_tu,*q%LxnIo9KM-okD#HjE.3iJ=c49#mG*2Ba'%q4=V/@Dn;%Kn*]#K60R/n-9#.K^^582pbm1JgC2'dr8[5`&lo/a4oD=I/x1(TETm&WkQg+/%1I&#>GkL-5U(2Fi7[-cBk$QtUM.0XSmu@xNA30-ts/'$j8>,RP)KEo]fF4oBWR8ctcG*ZgkW-`0f:p&8]=/s;0M)bDVO'YNWa*5jpW-vE;&I7inI%Xv]'/F%[*jY2ZV%%73N&bKIW%9DH%b)A)<--pYD/DVs)#b=ZYS$J*((]R%<-d:K0%Ov=f*g[]39TG;<Bd)RH&7;`]YcT7HM(vugLAqTJDGt'XQb:U1T06OQ84@28]4=1^u7#FT%.:,LOJ4$##l8aQ.huC`a=p9n'<(ku5]>t+;_l#/4c>E[]00xP/BP,G416]+4+g^I*w%)C&4'PA#B.i?#W?ng)3'p8%VOrQVGx?NWsJUh$Cn<Q8<vKd2^xih'L9Bq%qd0f3C4G%XMnAm&:1,`4E3H890tLR'h0]<$^o&B+xE>(l[4CB+3,gKufEj;-fs]V/%u`p%',%cV7iYcaqxOs%ERMt:vQO4:TUp#,O&IH)<_H,*#g@)*c%g#,W9fW$a'(:@aH-v$+f)Nr-RcGM;=CA;Wk8A$8A6`aSBb%bK$do7c]Tc;w'$u69Oo$$Q<b8.3qwX-APO#5CO[8%4oR:/+xI`,X#:u$CT(T/BAIv$j-ST%cF9C4vXp_4OiaF3NKY8/wwVv#lSEQ1l*qP'8L<9%UllY#6fGlL46a<-7YcY#n3'h;xG/mKp9%a+r5sHM%Ls?#D:oUdaWE^4qli1L6Dp[tw8=.'/:*T%FL&h1J5RQ:@ELt8$F9Q&M'96&K$F9%+rqD5ZOV@,U;n-)Iq<G+Js&x$OHGN']r&J)wp4:(iTH1g.m;Q/&5>##4?Ln#'XL7#ncZ(#0sgo.ZktD#]Mx_4+u@`,[M.)*`X65/_$/n'Z_QP/Jj:9/$i)]&4M'+*i+h.*MMIW%b@u)4/oq;$6x&^-p1Rs$gL&a#=&OU*]k.T%8knl8HV3[$cM5a?C_39%lrY/CIed3%=HJ._V5do/9eFL$GHLG)it9n),`hV$D2Zm&?Gq30*.vi9?*KW$s[&>.I-49%j5w)*tM]S.`h#D-Q'[x-Wb$29_a0^#gQ<f/$]&*#MCe8/Ok&T.g3C(4q>gc$,B2%.w=rB##3qH%(uH)OUGC@-w9=g$Y'q+MsbwAMTP^V2o,:F%DLZs%XshfL%DKYc#K4a=4d@UJ&_33L4>,##)emH-DY5<-$]5<-]:fb/dX(%,d-FT%+`kA#U1f:.aI$v#KAVj0Eke%#Z,>>#%i:8.6%8H*:O1x5FGZ<->#m.+Kf`oIxN4P=/*1T9Rx0#?##Ln(,qQBHN.cp7;*LB#PYL7#ccGlLHZER3V*fI*V?(E#+)TF4TMrB#L@Gm'Jw-m0Z%Np.SrU%6+E^q`ufnP'W<eO%e1E^#)H+/*Aljp%:tWN0wBM>P$bHS'jpMWMDhwx4HvfI_SQ^6&p4b;$._HN'4CRm/hEu/(,FXN'>%gN-H8t>&`_/2'*m:D3xWtm/(ctM(WFuw5v7T;-IjDx$j^:9&tr%K1'5c$,V5OL)VDSS7/%/B-cwrO)XNkr.p@,%,CFRb%ERUo7`AY<-cY(]$dWL7#+&>uuSE;mLtD^%#$K6(#T1g*#O#(/#bcgh(Dr-<-x7EC*^m@T*^A`993[NK*0aR5'DYG>u's$-)&964'Ym@wuGl:W$oFHJVD^t2(^J%H)575+%%hMl+pk<6)rr_G%=r(?#ZEm'=MTb]u1)dgLfF;v#@YHTOVGtA+ZWsC/>j(N0<G?`aMu08.-HKe;R$$Z$8]];.[#>H33xWD#A'lg$mhM`%>m_pL)]5W-+TMR*&k8n%93w]%N.c58bN9dOb^&%#m8q'#2Lct(nv@+4L2'NKej2<%0EN1)`?@I-tFuG-/$h5:RuVoa?S39/od;PKYmd?$*SrJUYDhT7Ij(kDi1nvABX?X.EC$F'It,_$p?p2'0YrvAV$&%#jR#t&o?%29xJ]QhNBeq7BdwY6`uWv%9;Q=-?)?I'[T?g%8E5fZWY29/(4Iq$mQD(;wDt>dSQu/([+FcMnEt$%j@0;6d9%##A<V:)?OHg)),$<-'e5W%e[>p@8$HK)1Yi=.4^k-$AR]p%9uA`7_w8F%&%LL2V'IdM]LklA5OL^uD?x.L?4:9%IG70<OOq29f'k>-t4%D&[Jp0#g/oejaH0GVAE(,)h0IP/hSm*3l5MG)`>bJ-B4K0%]qL+*a]Q_#cI_Y,vD(T./@EZ@&-E;6$i4',F`(9%%wR]%ch:r=[?f8%3ab,255fm1XR<j$*ZP*YE$Nlg[VVs%#9<=%5V2I$(lYN%rsH&m,4t.L[<VV-Tb$##MR[GEBRt,Od;E.3l:9o0:u?F%J8=`>9#q?-/x34'CvH-)$U-TIJTuof(5G)mA=GS78YN-)6kCZ%q/B.$+@6b*h1q,;EYbm'rMq%4`GM]$0t%gL)I&J34.Qk%>2J90s9;GDK=$W%'4I3;Z67E.NFblA)[<AcUv90:cN`dai(`%b0r+87>2*LjrB>&>u7vS/T(4j$Q#[]4V)ZA#^IcI)+&-^&LDZY>(g0^#(Ko*H4FC.&n6JT%wIUG)rwE=$a([p%o4&6*(BWK;-RZd3ELhm1RE11&)a$6M6wQTQg55b%hh2m/%hM^4pgx/1$YkxuKJhw-ltCP8Ll?N:#=FV?'wTLc/cLs-9Ah882m]G3xAA)NBH,oGq[C_&d]tfM3I%m%($+qi,tFA#o+Bf30d%H)efUa4c*Ig)j^GnW]TF+5OmL5/Gr2mfVS[^NunS+MP7r(,L0CG)8)He.=x2I#3F@m/J[r%,/<E0C2Gj4[_hrr$Gr@N0QKb&#8pm(#1*iSCLE,H3c4B>,/BWp@jfpJ)HVgd'OYi=.DAHx0e4eG*&iAN0.FAa%l,GT%rLCkL9&c#-Af(T.Wljp%IGYr$[LB^[e<@],Tn#W.[;^;-K-l?-tFRq$[Bxo%:bj_,xG>8/]wjq.ZGXs6(#_3&fw[p%RA5N)0;;Z7]Z-@5cg'W.)d5t7)CxY-Sxfh5Y2Puu4Thn#Bpq7#+DW)#/#5J*qX8KO:q'E#[q'E#WHMe&gVp.*+Um--;p>F%=Ud--H>v]#@[%$6&pvi7NE)8/[<9W$'YpP8dh1D+re/Q&>n5P1$G4AuCm>l0gq*O:W8Qv$(%tX(bfqA5J4,gL#rm>#_,9@^9f,Q85w#98k-N`+otIu-i3%LM;>(pR43_&,xd$gLbIG,MY:Ds-#A]$5keuH?Q2###',Y:vB5QtL%u7T&bbLS.QX$##?e_F*.39Z-,joF40R(f)x,Tv-Y@cd3&%`l8K>Z;%R_=g1<^mD@6fUv#P/#W$4/KkLHYmD6joG',2VuY#n>09.`qcN%#N93MABC8M[O-##_q8s$u_doBxD8h;UiLC,CX6DE$9<=%I<.Z$i&1w--ec,M)rJfLt35GMK)I>#el9'#N`aI)^8v;%PEZd3%X3c4+[C<?$^Gx6&CcO.QN0b?SHb9%7f9x$@IRs$k:T,MY>.l19&x:Z[`_@uPBnH)m1Lq1Ji4R*c$9@Qnfqu$]3M_#Fw>lfj6Vl]QDw%+q2E(8xCdv$ax;9///EQ/4x)?#.1Cs-7#n,sf.r$-UxBiq=ee6/UdZ[RbkB)NP5(?-^p2*MZ<7Z$V^ZK<^)NO@nm&%#bd0'#HJa)#qLV/s]Rhp$?eNs-G0rb=P//sTmkSN1Lq2mf%vQ.2ZlQX76/&U0QS2;?kqR2L;'?gL`o/q->I)2q=rk7@LcbA#=Bnpg1_YgLf_c&#4N=4%0V-W-5TN-ZOU5s.gf(*4<C9u.c:o<?fZHh,[UBd2*-+c4so^I*-4NT%nQJT%(W5G%Z`1?#t.Ca<KUMZuIYLhLoMPA#CHFL:8qqZ^G8Qq`[1Q<-1HKT%Ol*.)&*D=/RW:p&8mcM9@*:'#SI'&+wJu(31E_n/iL0+*J29f3`:A;%l4$dN%5,G4`4n8%%]v7/8JsILU'LG+j0tNG/l+CAZ<,QV/'=u-j#:^#CU7w#I?e*.Sa.C#&DFN13f-JG(&/$vF2_W.X?pf*_oDq/IdKE<?=.W$gKA0'dkfi'vM:D3KG'##W6+W-/d9o8Gb_5MQ0_5'AvQJ(]w(*4IgNa*),7bEP(6g)2p@^$bYDD3FK4d3;cK@%jZAsnQHGN'n@de$-`061ZLklAiPpK28Yg^%$-IT%&51hLej%HDG3[['eZ*%,o2FV7<MR&,pio--BsRa*I]_W-seh7(?kDf:'7LB#APuKd3?niLPLKv$8%'.$#]Z2(>jGPMapt&#%)5uu1jdfL32ED*svAJ1%ro,37ZWI)?7%s$-E6C#9#K+*cO%:.H#p.*p:`a4sncD4$PkGM0L/g410bs$I6:di%q7L&s$s8%#i7Z7,GHs$YM:t$68wW$stIm&7xMm&Q0r;$kar8]#QQA4e:a%$o,Hd/iaQOEkt8N'mGuP&<;=5&<FooSm=W`#88###A@%_S3*=##.gHG)dhLS.FW8G;s0)=.@Oi8.d.<9/lxw:/YBEDHVfN$5g&sDS:M3u7wJc>#YFc$,EqTM+wOk.)k))T.APsGZ>]e9.G9(sLJc,s-<UZ`E#04m'O:p&#v9L]$-cq9MAV>c406kbHoJYA#G/Mp.^`,29ssl?KVfCv#@Ya`#F%jx&i(ItA.FKrfan*P&xsA<$Lj$AQ+WH6/&YJg>(lKfLAsJfL#.'/La?KJ(4hKfLhJfm0&Z>g$SjTv-iUYV-PR(f)Av5BZv*t,<K)tY-sqRJ3$Vx=-p:PS7i#bD+`^qR#$%:?-%O(?%0'mTMA2oiL4>J-)p864'YZR<_)lE9/Y*D?/CIXqI_CI'&TIRU..)34'Y@L-)]BF$'?]>M9hs'MN3XYQ'dL0+*`I[?T+BqB#&Os?#k[K+*B&H[G:Bav6_T^:/kX,?%K@'E#x.<9/o?d_$mRRmUBeXD#@pTv-3mDF3`QDm$&r4D#q[xAJJ9S>+Zn-:7gnm5/S^c/(W(^b*EeE9%?$+r.6,M6&?tgq)l?L,)W'Km&*Zn(sdD24'@+Ve$eirl0x1D?#9mKT7f,oiLnMoGZ(B.E+sV`,)F-'6&&E@:0?4i?#O$96&=ZRp*[7IW$4<:4'-ujnL3T/*+&4`87g_vu#7>6`a?c;]bU[)20Tb$##RjDE4iq_F*f,/J36xHs-+K3jLW_m=7]?d8/-UbVpBLB(46F_2`/-vF#->,P(`h[[#:A^.G11Yj;;REEEeI3T%0$s?>Z'O=$<sA42^*kp%T&*&+pK'u.+7)3920oMVY/SY%1cn/(k4/L(Qk*d4)SGB?`HP/2P$uZ-G>oNOQ&>uu'_s)#tXt&#eM:u$cfPw&(TIT%B4vr-9O1x5A?(E#nP.&4)pGQS;2Q.UC_39%)DjP0=,][#>j0*<cnDxH].h#&1/^Z,h6Fq%ElZp%3&sO'/DuNFQTI[%u&=7%O'>]bnSmx4l?;U/BP,G4;#[]4Bl$],Etqd-teUXM/tf'FoC,G*6_^Q&RW*`+]3R(%E*?fV'oMoGX6dI)Vp,n&ir/+*QR*)%6hSrNd'N7#-mk.#SD6C#3=QT9)@_F*jpB:%JS+<3GMrB#8I%x,[YRD*[sHd)K,ir?n_@://W8f3$F(E#mX1x5k%9f3B/6u7HC<v6B02iL&X@IM^Kf$&.$@h(d`O;-`dLg(WD.1(?6:,)==Is$8QvA4Rk%[#;k6Z$.$RP+,2#q7OE+6'd<6C'tMMB'(?GG2kXKb*d*0:%NaLg(87@s$,DcY#@`(Z#Bqoi'R#QR&>kq>$3KaM,_2VN'SPmPhj]vj'HouY#fW/<-_o3_$dWL7#`J6(#V]^88K?dTimJ:sf_x4h<ox[/(sX)-8IOadatBG'Gwgw:1s%tM`(`wu1%,[0#5oA*#2qL+*W]nw>bUW/2hE;funPGA#mxG=7Bhx<(GV/)*uYk*.Ws1;?'$a*.rnpr6hu_oIZP=_/or8f3Mk[r%ik;w#KbD@&ihbt?G6^2'diVW%Wa+A#>@67&Dg:v#o-]p%C@1B+,lOn*mS63'?>.s?CaBm0Z1gm&x7R@'/[P-)DC7pED'9q%1@LB+<3`<))='4'u$$p/=WKw-9@P/(UN0S/DIIs$12I$#*FH_#4)U(anC@]b3+GS7Rd(=%1jic)Sv$.$#`d5/p98E4x<7f3x?'o/4(7]6fM:u$9(m<-jd=?-=K6*MoWXD#iq_F*O@hA4[;M0(TPK:DJp9a<6N^a<?YY?6S&K0M:9nG*,^vG*v4Jh(XH;21<'^6&V.qT7.Qp7/0g@/2/o^u$d9r/)cpYP0ttfu.RUX',p3jS(6C#OK^mG7&kJUe=ffM7#a?1-/lAqB#s7v_F^mY#>rJUv-lQ:a#CFE:.W3YD#;ZfF4NwE:.`f^I*.(#V/D25##>hWp%q4GN'xJM-)j689%a3+g1?iR),%GFG2?-p/=wOA8%1)a>7?x&:%#%@Z#6l@$6qa<h#(kA9%np2R'X7Rh#(BlLF%KafL=i'%>^[T&#jOB%%oQ=8%L;<A+L7-AFWndt-=6k;-+c>W-_G6ZAPdCa#X0^M'8Ah;.=V&E#lHSP/@Cr?#$dl8/-INh#&5K+*FgTw0_rWEeGk@5/u@)a4d:2=-BtXW%XOSI*Oq@8%bD6C#3'9',/N>A#pu7T%4<)Q&QvZ)*rH<208q`R8E0GN'<XJ2'A(%w#tJ(:%vqAx$5*0t$wnw8%pdAw#KQl3'Eg$h(3G10*c@>Z,7ox5'Nt39%9V(0($h@a+eCH>uOLk]+ef2S&LBpj*uP[T%M4ox&WHUG)dPh3C[-fw@A1DZ#a-4Q)kw;k)i5h>$JitV-J^ok9)`KU@WQ>/(G>-.+lKU5'%0^R/boKB%GxAmA63ng)lbU<-_='49^c&'+/####&0l:?CbxS8@x_RL0H/(%l<fNM20Ed*;#hs-u`Cu7qtfG3F?1h$k=@8%&(XD#I>WD#3pT%6Y@#c*hGis-CK4f*Hi;T.J&D^#--T_/'_gq%%aYp%s$0T%GG42(4WU#$^l.P'6r$s$8VlY#tU+U&=mqE%GPq?-ppndDQHGN'Qk1c*:TF+5sve1&fw[p%;ogI=lnh+=MPGF+2>kE*O9'u$BtAm&b>Ib#qGt[,KsuM0;bC;$h=l(5%pRfLF$[Y#0TxI_TEb%bTX)20dR&E#*Leq$AN:u$aU)Q/45``3MV&E#N)b.35(+T%`cQP/.8rv-Jm]P<8xVn8A#c+`%%v29IIaL'=i1Z#,Pqs-iIxs$'?Id)xpl@$otj>$u&%:(hc[)*OK9u$][%@#.n@a+>:VJ:b+B+*ERa*,Mbh#?3E[h(V$v&4:WL7#x8q'#Lc/*#;2B.*,39Z-?;k(vAcd8/u3YD#7n6gL5IUv-1]WF3:.%Q/o$l@$?DXI)`v3j1_`*v%j7l<M(9cOoGD_J'be#nA_)XN1gTF+59b2oALsr)F(f>C+2L#TM-FD<-?npw'h6Ie-]/fiL;V>W-;rSn3vKK+,G12X-UW/I$xltXZmC+=(&7L^>rCF*GW['^#Z]vs-1c:J:Cb%_63`Vx-,q6H3kbm5/w3dS7j%89%[cWp@SFph7(aIk0t71%6fO]'Axljp%F6_'AC(S'&)v2P0Q%tp^PI?>#]Mb&#rWUX%GCuM(_J(N=oxIY%8=ap.LH7g)8W]t:X2SVM_Gq0MXO6LMsYcA#j*dTMH,0C%FUc]u<_a18QTK?d$*o._9kfi'u2#,2'4SW-rAXg=Z46e4Xb4V/D3Tv-L#[)*w0`.3`Hj?#e/ob47L]s$7*;mQ#6$2)(f>C+IDGj'B^_K(%_sq.<bNt$r,?g`FO.W$j4':&-MiDFmY-W-Cf_w05eTq%Cnjp%]A<a*LOes$W$E`%vl)B40-vn&;Sr&0&&>uu29wK#Uq#-.bepY?5v`'mjifF4?DXI),g.(>e<?`c-RZd3xLGN%;ccYuMJg9Mk;%Ec4HNf<wiJfF2;uZM5$oU.Ou,?8Ym2]$I)5uuwng9Dr.+)*wgj;-U^U)&h#sAR6?f5/kL4I)?]d8//UX,2Q0^u.[SOl(-=Vs?643v#>73.+vZ2($4Sc>#d4n8%e0M?#^&'58mEUa#N%QZ#;c1?#BWC%0Jg4',2b'T%F7KU@QoU@#=#>J_r]`Y5V];MKX8#:8SI2f#dENZ#)7E9'M=DmLdMdo/j79p7.2r508f3>5ZvFm8:>Fa?]Qo)<&,>)4cUP/+Y)E.3[6g,;_nls.dU<9/<ko6a:h^7)GbR[#qn]_#pqP[-Ng>o/>D34':VN-)v3&[uF#5[&UeQs0aFFGMGMUB)NMZp%.VN/2SO>gLMwO/2_uQ[-?eK-)b9=6)[#J1CZP,sePMM8Ir>=KNCip9vhaKs-?KNjLMuPA#iHX,2si:9/d/Z%-b-ikL0NC(4g_(f)Unn8%/U&s$ZVd8/Qo5Z#Rg53'0fb(/nAGb%QB0Or7rMDFs]Zn&oU:AFw=Q=lb-A<$[;Vo&.J^V-prA'+<VH),6P>(OIa3I)Bm-h()j/tu^8e.M%]bA#5>Q%bab@`aA($##BR(f)04vr-SrU%6378C#+<>x6Tp1T%2$:u$)jKb(qkcj%Rtld3'cw<$kWi4%,`tS7:#oL([r/F*3Gjf4:'r;$r[Pp4)MtrLF[FD<s.vG*VAPkk:+Js-Z=D2MNkXI)t;Nq-r_-thdc``365QhJNw1IN@XM@6m@Q,*b3Ltu%*3G<_n4W_G)572b*'d+dVRE3tL?7&P?NM<aU@`aoLCj17X,+-*4Lw%YY7^,9SMi4`Ej?#us`a4]qIW-P'WNt<jH.26Ys#-a'%],6m8c$Zb.W-l$9]AEJp.*dh%H>N3$-3W8`I2)-*?%J<5N'#fhe*HD*s%LvC*3Un7C+1(pq/r](=QRAOt&OqcgL7oh&PwQDJ)j150LRIrO)=/fL2eLBq%EA`v>;?l%lEfKB%Ed.S'Qvw*NemCo0IX.'5WrxL(/,VPMTd-n&>$CL3HKEV7dD24'Y#pR.sERv,YPxfL,`HL2Jj./&=/D`aE,W]+f4q'd>`<:)>J/l'ZY?C#c4W/1SZg@#9$v3;63Xa4Z1We$GM>P(b:*B#lnr>P9#Ox%YNbp%v4RT%UV=Z-vI_IMeFI2L-*a*.]Gdp%(b=K1Gsu##l$il%d^?D*+KbG3XsH^6$FH(+@CR9.Q.1+*I7/N0Rp;+3,g^I*fLrM:1.*D#N-h+>vdFK&j9K6&e:X/qi_b@XrN]$Tqd>3'AXQ']uk-F.jJoA8$7u:&>+40(%BO%,=d)J<lb?5/#(/;Nh'5L#u3<)#]=#+#jsgo.^q[s$9$tg**c<9/SP,G4[^<c42Dm++ZZ=n8=N[kX.;XI)WY<MEP[(A21m(u$t'7x,HT^:%`xJ+*2-&W6cdcK+K;aa*Vc*M(*''Z-i[,C+MjY7&HEt=$1bl3+gX%W$cP`.2^#*a*M/jA+K^8',/PPxYVU,N:Y.T'+>oNT%tUeS%5IW5&9JG>#ER@<$iY`K(CFIW$1D7s$cC)Z#f1>Z,8:w8%O)H;%F+M;$fnVv#Nex0Ui=UkLJKdo/)Me3F%xhK&#`Tp7Pr;Q/-]:Z#Uk%<$77e8%:N'$-;fCv#'G:;$8;-`ahuC`aF5sx+w8#,2[>G<-ix*%8VASI*,xr?#V0^u.^nr?#l%AA4mV:a%T9:-<4Y(?#UZ-38(D,x6g^+f68SG>#u3/N0GQ2<%S1q8KvdKh;(e_;&wh.'0fOYHO>[aT%xi9s.kmS5/ObI_S*R8T.bKb&#26T1=:=K-)#XXC&6h'u$eHeF4hlwU/VM/)*-Qdm@Flo>8$^v/E/J[V8o)lP9Dhs`<rTF+55:x),hTsl/wceD*R2u$Mn*EZ@llDC,.+CJ)o.:6(O/Bb.4wWC?o$*%,P@QP/IH1U%.:e+ml.jR#L0`$#-sgo.(ZX58%xqa4B=Yd3d/Z%-8PEo=t(9f3W4:+*kY*E*t-ji0VS0<75Rt9)hX587E:t;]Klm/;D`qd'n9UI)_^,nA2,97;5AiQ&8PC;$Y<&W$KT#n&(9HI4SC&e%4@>i;+rZ`<r##g1^i2@$s_C%,b.t3;L`+2(#I5n&t,Bs$t7=s6K*X9%dPUV$bQ]W-VqpB[4%co7=l5g)hRv.'mYKI*:^]KW,ixu%qi(Q8f@u`4P7@m85+t>-VH-j89XbQ'Y]R5'7@j#lJO^?-wO_t@(f>C+Qfl-$5&h8.pK[k'42Qp.VYe-)'2h$0v>Sd<oLR[-XHB_/FeY4K+JD=-V>uk%:vC`aIv?D*NO$##L8lG395ikb0YbL%-82jT[r^b*$2@<-lnpL(26,W-8&2_J'Mho.xJw]mggdd3=EW.3YiVD3j$+XA<i3^4>,NF3Ls(B#%e>w79)h)3p@%kas(MC,-W9;.W.t3;)Txs&rTL-).K+-V(jvR0.+CJ)(da_$LceC,V?D3(34YgL5Mc70m-54'<T[W&afin#)4TC/LXI%#Q]>lLbY(f)OIR8%*c7C#xE(E#aoOs6rqmp8%Gm;%dcq8gO'(x$c)`h(AL(N(jW1f<j$bQ&9eTA$k5>7;Xl*?-D916&GM9<6+AG>#hAEU.$_*-*GZ-d)Sg2:%EI^lo6p?;/bu2:/;,##9NG1p7j]kA#TSN1?PaM'68dLD3Z'GK.j,-a3$-NZ$mNv)4;AJ*3kPU&5J:?O2]KVX,@J#v,xrKL:me._6B0DG-N%r-4J`psZR:ov$8*1:@n,hN(lTai0d9%##f2NGu?<<Z6uqU%6u.`:%tf``3B-Tv-%EgR/T>%&4HjE.3lYWI)tN%x,Ew.i&B.=+3,g^I*Zq36&W3dr%[EDO'Qx9U@BXw8%LEPN'g=Y#6I<J1M^Qt*,p'3r79S'N(>65U2-aIgLI++G<F?&49MKpQ&YDVO'Q+K>.,GDI$Pb7',7B8N2I0Y[$G&>uuiA3L##;4gLhVB)&:Hg9.gb^=%MZ=W->A=61a2wL29>JE-5lT`$X7.)<=v<_$)Wwb#1co(5V$###//]^.4E3L#H(ix$/TIcM9LI'6FKe>%wLN,<AFA=%$l2Q/@Dn;%YDm;%%VKF*=`<K1'dWI3mZ8x,rrdI243M3;cV/J3a=@8%vfB,3Z)fY%;]Pt3u'^:/v4gv7$7O?#6Rap%boWE*DxbfCYF1%,lhMW-OY1Z#6F3T%oDa=.b]io&PX%@#fInZ$Vk/7/XIrFEuC[l9e'`<LOIoR9Yov98ok$G*/r-W$lDuA#Y/96&-LEs-Z7ofL/?/=-)q0q%=EA>.(L`D+w3n0#]8P:vgQ,/Lg>KM0UZ%2923$5AoUi&J]#2]$DlE<%nO'E3>;gF4,7$`4:*YA#OCr?#gBWq.TL,r&wa*G4Di^F*f-pU/tT%],)Aee20Zc8/Ckc054R7lLG/%E3hWas:hj]s$q;rZ#=:n8%JnP[-fB?5N2QNJMpU>;-.3[)4G--v$J'O9%xkn^=)I9PQ*6bY)Z^x,;#moA%0HB>:j)Dk$QN7)$`K/s$c;sB8)=NZ#nXaT/6)w5/V@.w#(+NZutV4r.4,mA#5?7s&r./P'ZEuI%+f18E%8-/*gq1d*4Xks-a$go7L7dPLhGgi0M*do7*Xbr?o.&c3QvQJ(RWgf1Mnpr6&mnijaZMi/C7.[#a4n8%SEx;-5wm5.a]?+<3M:a4`3I]OB`rU%Ra1rAY*xM-kh`s$>e&m&:^1i1J=t.L:wHC#pW`YP@X39%u*TmA#%:J)E;xfLeYq@Qw+35&DxEX(<_@],OVn'4Dx:?#PMR21V(>Z,XLZP/H52^#,OAk=0r%W$ZlD@$+_BJ%R1w`a&lF@5a$*D+/'.s$Nmxg2?v>V#[Gx+4X<)9/^V%V%2LD=-MRr*%,/7Ks1C=)#Ut/o%KEx;-gVm9%H0oA,uwWD#8%EG%Z;tbN>r5Q8.4AW$Lv(B#mV$0)RubF'?FSxG(f>C+9vGT%iEMc%4&?[GXNXU(>Uh,D.+CJ)ZMpZum)PN9oW+>-dD24'9dSpA_+i/)3so:DI-pW7TC1IVj*[5L&5n0#R)###Cg`S7,NLJ(^c[`*s:p)3eQ=g1IUFb3Xcf)*dZ'u$[e8EF7Q9T7q+gY,d;v3'e?)Q&ObHXJ;K'E<7h3I)nL3GVCRMZuMSKU%X4*p%IXD%&4F=@$s=Id%`c`W%?39A=M[wo%qx8;-p5kl<fEQO(+>3>5-gNcD:j&##Px;9/*Me$6t(V:%k[K+*,LYQ'n8a1FP`@f2$tB:%x3vr-sMYx6B.<9/j5m92@6]I*s`x:/Ab#V/e9_=%bgGj'*o&02]56N',OTfLERv0)F.@x6vxPA#1W$E3FO<w#Be/m&X.VZ#>C*p%Ph+k'K'=p%^BA<$hBtP&>u4R*>&Qb%Zu:?#Oa>j'S7bN.&lepIhhvE=_,Is$VC7w#u+8%$n*ST%*2ffL*?'v-#`SxA`4NP&Cr<S&$H:11L-;?YKwZs0'5/?5F9ej'1IwM0e0a20&*)Y$VN0dO1V^duS<rZ#=(Is$q/;W$7E+q&uj;5(xOXM(5d5K)F@^Y#3x[W-/];p`N^m8Jex,pS]vqJY7NT30&1PN08Kth:th.L_gkpGJ$^CE4[w7j0[(#$GNN=6'D1$##heoD=a_,g)@EEjN`ew[-VKnnA7./@#''nU7np*VhlG6/(e&[guN@6W(btiZuQvMZo'O8Z7qx8;-6sf(%#j.,)sJU`373i.3BQ]4VbYfF4I0>M*w-h%%qa0;(#GrB#&fqkLUenO(M/6<.0;+02+9o),H>0%,E:Ev##65x#TX?s6O5+%,Rx$4&NP+b7XDpY-KM<?8HXr%,SHCE#)C@G;PjZC#]H8[u@l58/jp1E#arVh1rB8_S<uds-%Pj4:,WeA,4f=(.KXcGM6b'E#QE`M%?8#W:E4jU%GW-a3YPjc)oNv)4Nb6&%T#JlfDc4E4)FJ$G[dNdM_'0cVjm@.GM$w%Fb^J#GLliNp>Nds.J/2*)N%TC>tLVI3pmew##3:9%&D.1CIpL7#Y]W-ZnG?`a=-GJ(k?el/6Ynx4o)].*Roax$o:%?7sn,Z,sq-x67k.u-6L7lL_E/[#>ft$%B#MT/=9Nw$Os*W6P`HJ#EDTrLPC->#`i@;/@EWhLZq/GVUiK'+K-wZVk1k3GQGZH2':Vo0F7OF+5<,A#9(^:/j@E<+sowL(xS*C4YRla*w&Mk'3P-:8x;sv%1+@p.A=mc*aDDS/-)'J3@m@d)G]is-+r+gLd>2Dfd5[M0lC:K<axI+5;%d%?^XkA#IGb7/KD9E-rCbpL8WMf<M?TT.d8wK#ovie$@q@.*ilWI)CJ;(=k@^v-?ArB#Sh5<.6Ou)4_;?kM_[8%>E7Q@-1tim;CqtP&vBJ/1)>P>#Vr`_&'mt#J]wV?#e/wS/SOXO'Thi?#jsx1(,BQq(UPwS%ipvSDnh/[6[DVk'hnYg)1SD2:XclQ'7####%&>uuxw#-.0atf*n2GX-s<,wpbf)T/#S*w$m3kt>I,)H*]_hA?dOv;%3.5GMa&V]$tPTB%=r(?#PDs%,2+M/:E3?_$sZr%,_qD/:L)hA=<:.6/R*vA+6Q[JCadkA#thI:.SUxR#G1F',wWfj0w2fvPV_+O40m.l'wYw8%:lOgL+/7aNVAa$#.x#&%'qw.:tj%##e&DQ/TekD#lESP/mhv;-54em%gE(E#qYj/<Fv*0&.X^:/-AEUI+8cR*pW=4Mui<`)8'lq%R#VO'j%O**SJJ&(:$+vM&BSYM^pGcIufWX(d#sx+swoV/aLV*O5h&1_i(-Q'U2jI6IJ(8oj#`]P?Qe]GIEWX(cv;a*KG_s-qexnJ=r:%GG+UiW^[s3QU't.LNgSa+lXZe$3aj4`Q#^k9E/ge$GIGR*n[-UN[1PS7X7/cV5BUYZ@Z*#HIEWX(^Zv%+95c&O1J4+(?pKA&(pj]XMl,QW+PCK-EkZL-qx8;-Xc/s&HX'3)u#9,REl7S@gTX&#[O.S<j%3r%9asDPfG`#(K6JvRY`@Q-V`f48FBwf;Mqge$SFm]O,rJfL-^A;Q?.Z?D_0jrV8Frp70VHT0D'CT&wR::nG9vG*,(jtK+/3f%$Is58%s1?%WnonMg^_%OAVY_$JYPa*sp#<->%(8'$K9V4t'Tu.-vCp.,k*.)dmfe$:a;U)1Fh[m$WbA>jqbKjj+J-)cRrs-MZO59^0@#6S*4c%Px?W-Q8E'H47p.,mFgJ):Tlg$5>;6/W(f],A%,&8e*#]ol.j7#UEX&#gOQt0.uv9.)^B.*-QQA4=Z9,-A.PG-RAjf%%*@?Q$B,%,39][uQ]&$0hFh)NhVnH)UNSV1W..E,>X=Q#a:71(0Ott('Rug(_x:voW[$##%)###k-A`a.Gii'/G&4;8U$&%I<FW-<x5H49+lo7vo?>Qot2<-OBTgLRM-##;j6o#to^%M)O?>#R4r?#7bj-$7]?5/$;Ls-ak4D#:Os?#JC[x6[UiS%T6EigNT</MHY&<R-=U99h3;?%M+)?#T2vR&#Y150P*u31iP$8Rm@051HVPF+T4@s$9BnH):O/m&,Vp84?PMs-[qU/)Ne__#Ylc=l]<0GVHqco7r6[c;N4Fm'P1O.F/lrB#Z:8C#L@Gm'*IH:7KPSIM&(B.*W*6h%^3hfLq'B.*L4Y#5G5@80OlMNT1mJ-)Z6RAIPd^q%o12;.p>AN/KbhJ),a54MviH_uPVx&,)naP2g>751Q3vN'PYEPA+Xn9.W]2Z>_@X9%DjY11grse)j)Qr%tJ)O'48q0MMp8E+:&;C69-pr.Aw0R3iq.%#nbT[%A>FS7'?s8KI[fC#l5MG)*c7C#gc[:/0%eX-/rU%6C3Uq)>/-T.4(7]6;3]Y-dKqE#4G[&4W<X`<^ck=&v0,.2F$<H*rxP=ltxBR+T@Gd3`JqK)n'a;$ERe<$XQj8^VXXA>Q-$S-+x@/1/Y0F*eUPK+JQ$caPVW8&@:FdVC0%u6#,E:/3%BAXhZFP8BI6_#crr4#b[P+#vlUf:=.9v-Q5*Z>mfNX]#vPA#B.i?#+K;<%p>?A4(ibF3Je1T/97Xg;0?i9/%&AA43aZ]4@Dn;%1n8W-cFj$'&'PA#+l1B4F]8a#?4Yj1:/hS.DZ`m1iZha#mqXZ.Al:Z#<R3t$cD`0(KXJ60m$Je4-MjT/XP@h(qkbgL*PAx$K55T8@T6O$^]HW.:L?K)G]7Y.=/%?$&Etq.]gLf%9qEU80JWT/To032/'T2^T-2-M&x(hLebAs$4lrNTp%Wo&4#49%5r-s$f_e0>Z,)9/JlW6'2nM@,2i+6'2[Z_+n3n0#LpoXuNc@JLj)DD*Hcq8.[Xd5/SJeNk%<JLa*vg@#a1F9%kg?'+EnNp%HRMI'Eb*X$?,um%uYDK(K:x9)5P9'+#WCqLKvRiLS'BD6%)###ajF`aEoa`*KF$##QOG87%`JD*]sFA#gu<<9Zc0d4:il>#QY/^+wa7I*qE*e'TRnW$ZB?8bSQ^6&qgWe$a<r($It<t$_hnW$uTR1(j9Ed$gr@5'e_^)lgjmg1%&P:vi>*L#``''#f1)mL%qX/2iFU%6w(ZA#D?_H%,-I7_NaWR8/0`T/F:S_#hsB:%ia@gLu4-J*ooq6&;'hA#euiW%*p?j[C_39%MJYe$:`e5Mb%tBK>lNL`s8^;.&aIO+ekcE*DC*wG9]am&1nk@A(BX2M^cwH`lMa=.5q+N'UH49%j5w)*[3n0#O6oO9MlTN(i?*20oq_f:Dm7$nmcE.3T``)3qGUv-[YWI)v:-x6h?%lLw:f)*P(.qBeYxU947GF%)tRkL/K]X-ZZAG;fPDO'KG]iLeUblA_`:N<)l/g1@X:Q(=Kp7/Y]*I)gns,<EeL&lkfWrZsBb2i59[g).Bg;.MOTfL0AvJCb'@['w-bKX2#%&4%8o]47x;m86J5qV6^WI)''p8%t>tZ#(L%g:)m@O;[349%QBGN'/Q[IM6(b31sX0K26^;V9DGeg1W-ZO'I[Ep%Q<OU($j11'e)tL#N;fv5C_39%<3mA4-H_s-j_*j3()$',sM?I2=uLU'OF@s$8U>^XK8v##$&>uu=?%C8=CNp^G+ws.gc``3#-Xd*/+/<-9g80%(Fa&)jaBD3Y-&<-%a/0%7B0ZeH38G;eP6dbdmA%#+kP]4'(1o<I>KUD^m9U.+eff11xS0%lPV3'TY/^+#H<ga$^%N8paOq&t3ts8ktuZ,-fT58Q3F9.(AP##;W8a#%,[0#Www%#hQk&#m,>>#^`WI)1heX-wf``3h6#ZKi>lX$o.OF3*.?Z$3&IF<O[P8/>=@#P9['/LCOIW$muiILdDDO'0DXS7Mia1BR,:L#W#xd#PEIN':Wb.$ES/a#N9'U%_b,jBn.7],r%o5'LRFHVPshl/k)pg+C_ws$.svV?66,HNw[w%4Ncme`1QN9`ZPC5)QQjL):2Gf*9)?<-*1Zt&PrU%6378C#Al$],34p_4]sHd)<r-J',gRf<j7m%&Q+=[$Xe39%[GWa*CmtN0DeX<%0iJh(]i&b*/l+b*$Zhp.vc*I)$taUKE4W9/GSNNM,%Os%V9l204Fe>#S$<Z#UXcr^AG,L#8/4&#v,_'#<,3)#e,>>#t(4I)x,Tv-aGUv-)S5W-n4F=]jYE.3ont[$UB:a#Dp@)*7F;8.<j8W6mvj?#W;f+4:WPA#Y0tq%E:Is$`4*/s>#c1)+2r_&FJ+%ta2Qn&-BJ],0F7E+_]%12KrblA#Y>v,t/PA#,Z:c%)TB%MAwB2'@^n)*,(9h(Q>N5C4<R-)pkaOopd8V.JTF+5:sLc5WWxw#Hg&w#;8:pp-6Rr#'SuTacUKL%.1U]uj8TdR=N@%bUp)?7>8#L#xZu##bWt&#<>N)#F4Xc2%M4I):2Cv-gx[B7Cb7w@FHbr.<2h[6X:Z$0<4cA#$9.h%</a9)QrbF'VSA.&ElZp%+F2W%v_Nh#+q=b%e,GT%XiLT%.9[M0f/Yp%]t79%;$U+MetN'kWXml%6L=U%FJr;?5LTJD'l0B#Nq'H2m0qQa[+l+DG]'n'qneu>K:H]FP#$:.SB:a#7Brg1;@'E##5NT/dxrB#+3KYG*o@U/`7%s$'Y0f)PJ))3>Q=r7jA@`&OdFH3.+llAZJQ*n`m=<QN*F9%$Y]t%Rp5;%?e8m&Q)rK(C%@j(XwD=-eS^W$?aGa<.%%m/#uMT%=72?#Fg@F%?Kh?'l-`k%Wgcj'PF@w#>1.<$<[E9%0N]'/aO%@#M<V8*(-:U%FPnh#s)mG2$&###OZ>YcuI@D3l>,<.;PZT%nH'R):;Uv-27eq$`C3(&,w)a4:N.)*8mB@0Kc>_B.KH-mJTjx%amT6&sLj$'6ZGwe&i'B#pMn,MOD5f*&,@3qoxU<-eH/x&Va,3'2kJWQ,rJfLaBnuu-HUn#ED[8#U'+&#v2h'#l$(,)jRHM97c;w$^tn8%;Ve]49em;^/LMq'_'6(Q`cEc<<5Wk'II3LDdv2k'CPl.)_cQb<a_*g5/e)C(Iowe+sYT&,?./N0)%hm:<g2'MG=?C+:Hg;-OGg;-Jo2g:[4_B#0C)4#TEX&#ONB5)4&_->Vf]gSgPj.3)_Aj0$F&P@JU9+0rxppAC_39%.w9H2dD24'P`e2Nq-f:5gB59%vS4Z-(oJ$K5Uwu#k%CkFJ;<JLRgXkMfTQnA%g3^,qoYb%cXcI)S(Ls-X7Yd3o0`.3ln5E4B/K;-_ajJ1M8;6&5sIB+WQ96&kS,F%DZ&KMfag$Njw3'MWN`iLSmR.MEk1HM^2XR%HgU`3JEUn/.T/i)?w<u-[Q5<%`J))3[PYs';Wk;--M2i/fSEl7Y$FtAD<w<(qLYGMJb>n*U626/O2kV7kH3,NF#b'Oin;;$6)L(aj:@]bsop;-GO>W%=aiY%&Ur<%@p*P(X5ZA#I[*.NFH3R87,nY6aY0L&;RqB#aK[h(7_B]$BxlLMQn@^PM5E/q>tWJ1F)Up%V>`8&710O1]j/.$.(lA#mZDX-&#^jVDMc)%F####/YEf%+jOV-(N#,2>:KV6Z8t+;8<.J3Fmf(%oPMKEK+Xj.t<7f3`us/%[o[:/vu/+*q?$>%q2xb4HpJY(-h'u$c3rI3VHX>-wi*.)%f)EI[hR[-)Qk.)8H%_u]^vG*t70F*bvJsA@0i0O&hR@)[SU@-g#Kg1Iq?I2SEx7/u^5/(6w<mL2%iT7AZ3F*cVj`FTt]5j'Ym_F:5$@0%0,%#xooXuw>),Me1W]4@8d,*(C@G;8;mpM>Q(V%Rq_F*YRr8%G65R&DNI%%b[MB6BqW9%c's(,Bta9%R[?lL5r:T.bA;>$CX,hL9[=89L-mA#9D#W-lxm34Q54'+i9%C%94@s$]G-LMK(%%-E;nS%#%0#(rRn92<;w/1:WL7#8%T*#w1M:%Z,,d$VEW@,*]4N(#6MG)o0ow@_&aa4fFuw5?3lD#0:WKV9i14'1do$5GI`.Nv=DSIdD24'k)0s$S,.?&s#1C0wKP>#Mv.>-YkV=-GS3^-9/4c7WXC*[slRfL;-La#OSj)#bq7o8mwkL:McO)StE6^#sjwI-wCg;-/@15N'xSfL9bwuLU=u]%lQ8/$31wQNeaqR#:WL7#4kP]4ROuM%?v]iL1OUv-S9`$Y1EqpRY6kV74=JT'm`-aPdO(D&hvv%+&jca4e<%##05Hf*p.<ZG0f/[6?-YD#UsZ]4-[w9.0=8<-(UNJ'dVG5V%fo-)s[g@%H7Z_%;'?gLuTe_'j#BmAml-['=S^U%0tC]$6qL-)eZv*lXx?%bc4o+M.j:T7Fp]W7t<HxO9nBm/`E'7&?0T]t3jXkL2UZIqY#mV7QPfd2CXI%#BE^:%'W6C#iHq=%cAUVKEq4D#nZ&'7CR5R&6t3u6:6#^&7=1V&EQ^O0hG=0(ta#p^%_*mLEO`X-Km/q'6X'/LDZ=8%S%PV-Wk$##^EZd3UDjc)%P,W-upJ3kvnn8%P'(02uw-x6Ofk1)MK0.;0=Tk1`i4c42.$faNgSa+TIr-$:T&a+UP?nCpGFe3u[.),Kv?I2i/[03_a<M27QO',6L$H3JK2E4Xf2rm'-(<-k)'://c@<$n0P0LdRL<-;*n68THEh)d6KQ&n`%[#^S[#%hG?`a*gu(3^'%##V5/.M'M]s$h)iO'85Z(&5:Jm/#T0<7ZQlj1mF^/&l,Mg1<TGT*)Rfw#3VL;$iWB=8cho-<=@wo%@$Z-3*T39/>WZ`Mn'A`ahVDs77Q7-)u.@W$S)7>%Kog58g3-v?JI[$M2^VS@WOx*+p##,2nW%##O;gF4NIqhLsT+<30Zc8/mEnb4SiWI)fwbF3J$vI<HqcG*u-AT.Te_F*Xo[Q-Umhh.BS7C#;wHm16'PA#T0e)*`Y[p%GqQvLtU-C#<XA_u+IWxJbVLV.SGL/33,]p%-De21dXd>#:t=/(?*uf(l@FM(?3cJ(3O[Q/YbYp%p6Z]4P9e9SGwFk.IDg[6pwbO-=t8F%E#-'&Pc.j1rro@#1l-s$e1K'+j=+gLYhZY#.)Q%b[PC`aq>:D3u1)T.@f)T/3YafL3u7C#x9%J3;aGx#OV>c4,Vg>5;JjD#DfWF3nsfX-vJrr?DF9=%<g]],tKOh#Klaw$D,BE++`7@#V2c,Mq$&-)#Lhv%Kof_1S&iK(ae)@#JGP&%uM+1#^#@s?'@Gk'j]O>#bqO-)h;GBc,PC;$EkJ##NM7+M=FetLJDE$#dWt&#[JsI3.)`m/Q_v,*:2Cv-:A-L-h6%;7BKc8/chq2)=F82'tt1]tPh`?uj.HR&>Y.@#N2ep.l6/W-P-Wh,w_`?#rKxH(MqP0L]Y]u,$wYIq2jW(#&5>##[*Zr#p@)4#Q3=&#f$(,)PxeA=ZH)c<Lia.b+Eu@7`umB=&;G4KRhkA#=VV=-wIg;-_5[UM;M>s-a.hDN2,L8OsAL-%d=#RNnB3eQeFNP&<?.S[-C)##JI3Q/cSafL>;2)3vbLs-dreA4jS[]4Ze75/s?id*U@Ua*>VggL&RJq.`M.)*Bx4b@wcE_&EIg#(=wOw9r.7.-3wtkO8FiHQ9>F_1IR?wLw1K;-cmbo$lwrY#hq.W$VSS#,5'ct$@IRs$7Vp;-14;t-iS+JMQ>b+NQF6hMLqq`Nb6]Y-SD#C/g;&Z$I.roS[>(5pcU+p8)T.5^wXtA#d]H$^7%<s$qsRf-_o$:jK`/kXO0XT.(?$(#85*Y$:^KN9fNc)4#&AA4Aa1q.ekj=.NkLx5;60[6+FYI)RJ))3[J64&M%VDN?*ht%>qCJ)'-9G3CTH=L/;64'-7K-):m^snG%v7(C_39%IghA4fwXg1W5+%,W>Fx%(l2sf_?L-)-fs/Os[?>#8GQ%bj%D`aLcDV?=IXQ'%e75/BTX`</(*Z6x*e(dC&]iLu]O`#RjCv#rRwW$bIvQ8X@Xm'w`Lm&Fjs@$;Ze97jEt?#D]<t$NpLv#Ubjp%>e?A/8F7<$u7xfLoWAw#x@)D+f3n0#L,###%qQP8Mb6<%Qg<J:0l&Y%'::>?(/K02X4K+*h)iO'a-eERa=s;7@9Gj'nc'k1E%AA4'&sD3oHF;.9t_F*;qZv$xh$lLnK;BmV5do/-H1q%l1XE*YKuJ(v#I)*eb,G*G*tP&8wYj'UOe8%bD-V%btQt-T&2K(O6b9%>g1q%5QWm/%)fv5d5qq%1K?PJ>C)s[CGu?08p8'+b/nU&[NdE*86xg:Dc$-+;?K<$P6'q%U>qS'[Owo%1]1v#8voA,'7-01AG+<6dSv7&aPYY#r)gs-]i`,<aCtY-K<#Q/+d%H)MDD)3eK+W-]9KsBQ%`r.*qjxFdB49%^$]p%xFKP8(f>C+>Pd),K0LG)WEOV.kQo&,K']u-ZEDZ<O3X6)xil&#w=_[IWSo/1AS<+3?_#V/mh1.3HK7l1%e75/Tl4Z,Kh%s$::tD#DMn;%SK0#$N)b.3m9T01d7r?#`xJ+*m$Cx$rO3#.BA$vLPPwtLifQ>#4cY>#)nj`<ncC_&Y'jV$MTZ#YG_Rs$rt*^#1x?s$I^$d)-QUs$4=3T%/v^s$5(V?#7='L5tq>0Fi6I;'Xh%[#>=@s$Edd`*aXbGMk5up%=;P/(%A%$$eF+gLtAF&+/WE9%[(SfL&hF9%e:+,M<0Cq%(CEJ1%&>uu'b/E#[GX&#tG)%A?q0a#PDRv$R8o-#Ygc[$3ctM(3SAk0f/Yp%0==I%BTF+52kis%<`5##AR`X-5e[e$iO?(%THcHV93dr/?w2u$Sd7dubk5=N28[;%;&O0P]aqR#sCO&#h6fT%,t$)*b[18.J')58nW%##6HvA4WQl8/Pab^,HmNv68Fn8%eSU7/v3q_4hEFg1x-lI)[(KF*J,>D%nGo>Se;1u$lb3W-vW=E,EIpr6gZsZ#*h'm&`DZ5&[D6C#;x[w'Y70O1KTJG;iqO,Mi3SO&@Blj'gM%F0gu`B#@fIVUs)k>-#qP-)f[7'3I>U?-G_i[,s?Hg)5`K>,*Zjs)pPu^,>>EX(Mq8X$wcL6&VpcN'u>f&43,2G+J,97;N8oReNPbi('>cuu6W_R#nw$8#d,_'#u:w0#NqXF3Ls6N'[KA8%Vq'E#*3=L#nB9u$%O]s$RXp+M+)>c4V(.x6gNR1Mex;9/bvY11Q94Q/Jc7C#3v+G4TD#W-^t%F.,uME4e/ob4:'PA#--6^,9bnBn.2o#/E35N'kpj2MTJ]n1vrS5B%/AL(rtat$:Q16&nlH3'9:7<$RHO5&6+ov$'UvO(ka]@#4xUZ#7XA2'J<%$,YvGr%X$&w#1Y(Z#9(rv#J17W$wh+gL(lWk'JvZ)*PLE5&j>H7&oSVk'^s9u$3rhv#4sqV%_.%w#7x-W$3>oe4SM6S/n%p/LZRd5/VsS#G3>G>#6>'^%`Dvv$dDlB&A@rT.+PC;$[l?x-dL4gLTnDv#Vu[fLl@xD*c8.L(o`ed)C5/F-hqT4.hqTdMp'>X$TD.l'-+3eH.BH7&q]r0(_#Cu$cV4%$LhXVdb3dr/.Eg%#%2Puu$l:p.%,[0#U[P7AR7902i_Z=7='(]$@>8N+gJHd+20p[uv;3RS5$2<)Ebvu6:W<**b@D#7,Gp;-MmG-2:$Wa+dm]r.FfFB++U*[u<ssq2F####dRUL&S5R]4#U^o@'dT8%e?EJ:9bo=%jvBu$7btD#9RJw#nEZd3*^B.*c^7b'NEC;gOINT/'TID*ujDE4(65x6#u>,'ZgDB#rj*.)n*<I$xFoA4UUB?5W>2m&(:l,M^)A=-K,+i,7'C0c]#AiL0YtU0UbdO(gv<A%REeL,mRh9Nh/p03ii@n&_#@I<_Hg6&T'Tu.iSI>Ors5/(R=S*+_<2W/BMGn(^ME?OcCZY#D$feaYTb%b:xju5K(_8.s^v)4.tBiD^wJ,3h'of$4c^F*/LaMk.uf^$:&'f)lh)Q/xVY8/VMi=.DW(ejTxAc3p$Xp%eP)N0,0BR/OHgQ&H+ZLMA8_j0GO*bj]c,##)33oA9_vH3e8iOTY/?v$-S>s-^G:hL0ZFkL_n8g1fDj*4La5AuHK3-*:l.':<[idaguC`aG2W]+2.co7kusY-_RVH3<H7g)jAqB#GIpv-Ut;8.r0'oSfj&E#Mc%[u9#V<-:$Wa+9(Tu.oxBvdhVnH)[XQ@)uRI(MD5`O-MR#7*3Qwf;Su?)E8l(e3Vpw.:'[BS@<;?E,eLb@8TnV78c)1@K*p)^=-F5s..%n;-t9Ee*xcm20*vUv-[5MG)^*>X(q&e8/lD;[A5k+SnEGG],.3-;gVXiG+wOk.)TrL-)XYJVM-;Y+H1+lA#o.km-_&+5(K99U%AA]'8%CHr@5$XW-t7rgXd'Iuu;m6o#<WL7#Nsgo.Zk[s$L$e,*0g5F%g4NT/Ilo^f4n&s$hoCa4+)i;.ST,T.]q[P/B_kY$(ZRD*fEGH2%[*G49BL>$Je$u6q1'J3Q&5-4Ppd)*.@sp%f2mp%>.R8%3`1v#2=*bRAAr#$hBxT%^bAm&fkrB6,8I21#X/w#6MP>#pSD`-ge.<$FC<p%wwqW-O+N?#h1Ca##EO',lLX,)oIfL(9`l>#=?DZ%=FOS&9XWp%AdeiL)(qN(ru@A.8l-s$:7E5&k7Z>#S2J6'F<Y/(>0$_-k5l405]_V$ah?9.4qkdX'rQ.1;4>>#NH.%#K,>>#^YLW-t`ur'iD(Y$Z7A%'7N.)*[(Ls-,(*9%l<5H)63'9%d23Z5H(-H))#0;Gn.E[$Z2@rSgToJ1fRKQ$q$:hLo;ojLW?VhLL2L#G`8=sQ-xOK1Q)%VSfO=U&/'7?/R::xt&e_S7Q7FD*PU$##kX6w&wg;E4,MhkL:^=.)806T%OrXF3;X^:/vBo8%1CI>#&*$V%DcnL(r&)n&`W0V(O_9raD;.D6Phq/)%>l(5IFl6'lJ#7([$FT%sS7KYxI&p&rSLlfYG`l).eLf<b&)l0Z/5##+LQ_#O*[0#fpB'#C9OA#o#D</:7(&(kxRD=?4$HF=ae8@CXVs%91wAMnO>V-*.UB#>570>j9;-)NZew'?OG]u-S+01'>cuu5HUn#F&.8#A;Y4/@>N)#cO/$pk6#j'ZY?C#0e/.$5W8f3MPsD#d/Z%-1deiLil7gW^u9)(ec?S%sYV,)[BhW/,MRk044G**A'^M'+>X2(XErP0K:;X-_iEMj0g4ZMU3$c0[UGE*sbp/)Nm$d)IA$k0ASVQ&_M0q'9S&:)B<*/M'R7@)+gDAPa&<;R7'<dMmvm>#bMb&#,WH(#;>]./7QCD3C+-F>KS.i.`<3:.R(+f/jEaf:&V?(jUNsca#J/9a/[g34Z<K;`Q)###;w;##R@b`*d57;^%1qb*3E:N0)^B.*[KPJ(QeDd*BiI6/SrU%6[P'o8EL@q/vh=:&ko,J'DbfCM)1K9&$=LdM<r@QMQ90O05A?6)1/G>#Ph3$MM7-##T#4)#+;###qk&/L>xii'f*IP/@L,87u<'8@sITqTbdm;^5'RK)8o[Z6/xrB#jQ-+WDRw7tG9P5rEVpu@+(1B#$wIl%_0aVnB&Z#>U&;,%+h49%3q'HMRG1@-^p7f0dD24'DsH-)YLX,M>*Aw@Kpcq;UWjJ2Bl?2ME^$TMrKUp&<O*20*JE@./;ZA#R8-,2EHuD#h'Gj'*RPQ'Kq@8%]9VcD<dLa4;ZIl1AB]u-RIqhL/=2DfhYsf1F@2K(h3r%,7=3T%*Ej+NmaAW$(h/k3u'^:/6c6;%wj2^OnWfd;D'3v6E*7?$<iu>#TMLw-^6rxL1FZd3^#e.N=+As$^BIa3&5>##9^$o#:WL7#lOj)#;sgo.P@i?#ma<c4#0Tv-a7%s$T>%&4$fNT/kK(E#Hi^F*i'Wl%&xn8%x3uJ2>Sf)*KG>c4BA^Y,jvw9KSbqJ#,T*?#Pp<c4_n/J;maN.3VwoS%'4Dj9b@;v#Zg0q%@g*t&E)kr&3'EI38O=?.WCT*-Z)qu$?/s.)w;4ID#LGT%X?ST((2bA-u*j@#lYrY59'Rv$K*9U%#PRtH]W.'5]IU+*[PJ<?`=m12Jbn<$rn`2rn4Xv%%*p(<:E-)*]3B:%3p4o$.Wub%n=q,N-TP8/)<>x6Mf^I*KjE.3oi&f)$q')3FH7l1XN]s$CY@C#OY`;7BUU+AX&s7[4]pH)$nnlLdrxf3;7Ha3,gfG=)QXc4NJEp%::R8%Xscp)5h3d$>XEp%:1*I+DWq/5<)aE,K>2@-ZkuN'aL;[#9mu8.jdQ9IA9?kC0.[k,vq%[#)KT8%xshT0.JYa+WKXt$SJ=gLgNJW$?O@E+(#6_F-XH_#ZA)4#DR@%#nvK'#53/T_cvd12X[L#5de=+3WF;8.[=@8%-2rv-jL0+*6-8u6tSH*MJ9L+*=3UxL%xlse7=Y%5So$j)lu7v$,DK'+,CQH-3@Zd3.NS^50.<G+Aiu>#Zfqea+A;I$oA-G,E<46/+S89&d5`G)j5;4'o#;v#AY29/t`1%,#P89&K[))+i:gl8$)tY-.FHv$L;cr$c35N'^kc*v$M>c4jA5##k]01=:]pYC]PG;7DmoDE]:<`#Mr$r8PR781&=MNFdYwe2drU;$s,un%Q4jw-jr]l1RxP##]B1d2g5wK#J6i$#jpB'#*Ur,#_)fLCl]u)4/rU%6&-i$%i.Gg&O5)T/qw2aE85Im0JG-^=O=Sj0;#K+*%Q3.3w0`.37(XD#;X^:/7=V@,ZDsI3[/Cf'#nb6&@JVN'OJB]V6k8W-[?Gb%mXkL%ik'R'`8Qv$Lt]m&C_39%XQb=$MwjP&:LwS%Cw/m&[0_q)`xgLC'DLB#T#J0:[DNa*KpX#5;BCg(s-hN(&Hcp%Xs1O'*UE?#GURs$EI7q.LBt5&^ZsO9+F@ktGK>G2;?#0)VMrB#Sd,6/lNXA#8JEuRu$^[%+thv%ZTXp%*iET%F`*X$/jAf.8M3H)8ZEf/DDBmA+t8A=q2f%$9DH%b.tA`aBa?D*Vh$##<kY)4$YvNF1v.l'8BNZ64'tN0/,-J*8O1x5f_gb*v_ngL_.Vv-kCs.Lf]<9%Tdf*'U$1H)jGD:%nO;9%4i+`%@XHaN:$;?#d8,8.)qB%MGR/N-kH6&18>?aNSQ^6&cRWN'Q@R2LxI^l8Dvlca;fcERa6cf(/c`#S@]Rb6B[kD#e2p_OawTN(u3YD#A]IrL*sZ.qf$o5&H'^GtNv-tLp3/f./Gl;d1jKk$d&$6&:[&NLHvfI_0XkcNkk*pAtH-B#q-ugLXsJfLIZI%bf=hERfCjl&lNEM0Fq(58vp%##akY)4_c#E8hBTBH`L6m%U9Fp.:[Yca.?Ox^Hn3X-'%:gaaG%#%:D`p%Qj#WSZONmUR(It$c&B_?W39%'q&<A+&Zu(3;m&##2UOg8U#?g)tQQ?gP^,,2ZP0'd1VFd0=0BC)6C/q.<:6V%`VB3a,de`*<P;R8Qfv??K99U%jN2W#l8ig(Sv*q_sf-V%2L5R**I.hLx(9r0;Fhl83#[#6^G9G;PN^U.+cQP/t)'d'cYDD39*4R%+B-N0WI;8.)^B.*c47V8q2bsSSS4t&9p'Z-TSJ4;@n#0)=$_Q&:FD=-?M>s-/<[iLX@wT2hw7>-S(pc$`/X#&$iCK&#aT%MGO:j(3Lc&>eh&K2a_cgLY:mZ,-H5F%eCas-<9HN'I=O/L>vf##'/###'n$p7rXW]4ST%29sg%##h7LP8Jom;%nOBBH)TPA#w0`.3ljEZ3*>`:%@xbI)<X_a4(Ox*ju-,0LI]_W-^eHHF#<Y=$;$D?Yh:sqAH4>C9K-x8%Q.8;%d/)S&s9Iq$dU%T.%F-G#=V6u'dBlj',mAKM[1dAWc73o%>7J89pX?-3Ze75/[7%s$?Ja+M_PSF44A3S9,n/s7MQo;-L#`a%Jm^,(p&I0YSHRX)?;1W$Id1E%.r4b#Yh6##:d-o#A,78#a^''#,x%6M9e'E#(ql[$F)b.3V_=V/lLbI)&Y@C#hi%6/,J64&x>Uc<B+v%,F2/n&Q>VZ>M3dr%9P616?JP_+r<.V'?3,)MPkX:,9#tc<JasS&Kj8p&KaWs%kSx0ME1Yi(r9r:',>Mq%_C;mL*#*$#OA#1MaF`hLdXv)4#L(E#.1v^#jV3E4*$u9%^qA3L9*_r._n-U7W7#uVXkvuu:m6o#=d_7#^2h'#lNi,##:K2#LfB.*[q[s$qaVa4Ap+c4'W$@')fZP/9gH['a`$w-1+m<-8?T01ofY^,H,wD*c/VO'Mj%jL0vmX.x=XI)GsYh1FE#w-`S6C#w<C]$;'r-M_N8f3V%A['@@[P/oU65/JXV8.7L>w.[hi?#rW0bIZ$UfLiKxI*m;](sgr+v,Tm,R&]YRD*DQul&?*Bq%EbaP&wKH(+S=7[#T[iZ#oAru5.>.s$M:WP&(ZhV%VQG>#'vlU;CTu>#SK53'-DG>#%#'1(M-'Q&Wjlf(K996&CLaP&BU<9%Z6s;$X?Bm&].jp/[EWD5<[*t$<C`?#AUH+-=bRwdr)8MFhNIdDO9SH#xo/4;9x1?#1h`j9N3cA#G8JO;KBP/(;xo90DmI-)f(_w6^qDI-J**D5+JBZ56e1@%GK6Y%Ch4/(+lYc4$Q(Z#T-J[#@v(21SNKq%'?MK(-`hV$Hb9H)KQCK(omTq%Al8G=RX*t$cZehCrD7/(kL$##$&5uu0(YS7Gt^`*c<i>5fvUO';]d8/(`d5/[j:9/ccor6M&SF4Qa5>'mRWD#<Af^7k6f8B(0+A/Eue[#l/VG)qYh&G6@Dk'AR39%[1><00((G3?0iS0,+B6&kfWQ&(]Y?6ohl$G1QO&#9A[-d*)2'#wiKS.eEls%.cLs-MsjOBg^gJ)mXbv-w#;o05'+[&S]_O)+WS0&rQ6mQf')p<3RpQ0>So0(FM1hLQ0rP0F6UPNALI&Mq92Df9Ib'/*Ia>-]3u?-`x3_$a#//&67IP/[j4<-_*%*.7X+0;3Gdv$.)b.3RIqGMqXmoNw:+.)Qv13'/])a,./V#$l;Ud2nkBU)/i6.4M+UKM6*r6$vjau-j>qq%r9$eM7pQ63vc+:vBXu>#PZI%#?,>>#p&VF=[4E<%(9lA#&:5G=lGKkh]?f@#RoFh:1AMC#D4QthhUJn$IY$F(X#vG2g%to7um5,EV`bZ$u3YD#jMS1t[Bs?#+x$m/lf/+*[m5%-$VGs-:tUhL5c@C#B4vr-SSH,*^OWH*3%I=7sO,G4.SNh#cc``3J`,#BHdMm$rx>)4amdA4xd89%-'>)6Sj5V%9.7s$Mh39%aAxfLZd=9%m@sw$A%Pg1Rp_k'6LdG*TbNT%SN0U%Mhe<$+GcY#IL39%E$^2'6x_v#0i_;$Boh;$*(_p7D;wn9k,@G=Q3Xp%<ol>#:CR<$aOwK>w$Km&;%2v#P5nd)tCkE*qox>,csGn&e)o?9gCDv#P[&Q&mw*L);fP>#6:7w#;XW5&dF8a&X><PAMFfv.fY]+4+V9O.)E6C#>r>dMfQXD#'em3+^Z862gFH=7+(vW-AhJe$rsHd)nY?C#^7^F*rRoPDnPGA#n&PA#b(1H4dl+G4K7X-?(O]s$MT$H)1(`s/GJ-j:Q9Bq%8xJ)*Ra#R&Tg9#$9OEp%3(7W$97r?#5rL;$fd1g%f(r;$>I[W$c`ro&_YNa*WmQr%E$pi'vOF2(EF`?#a*/@#0`Lv#bErc)MNL,)BtNX$hhi8.'824'3]9_#QxUv#@UN5&^L=gLeSYA#]woE@-1Q&ObsZC#Bwjp%D/ul9l90q%C'kp%q'7=-dC(w,'<P,2>F%<$L_]j'8:Fw$Os,v$ZvGV%w9WpB21x(#paWv%5nGi;P,*Z6UDDMsO2&n$qaD.3Z3f.*IKf;-(LMiLg/E.3p:H_/`'Fp.e$Aj0`Q3QLL4`e$.J_G3&l2W-*kWw9[H,T%w`6@#1`hV$B*KQ&'#?%-dPK,$+XU,)GmQD*>On8%<1Is$::e8%CmGm&2oUv#,P(v#0f$s$9@7w#B=2v#`_/m&:1`Z#A=;v#HbwW$DR@W$Z5R>%)Ye]#+wa)<9f:Z#`l79&bi'L('&OB#g2lp%kq0dM7pRk*==7w#:(Dv#CXA2'<II[#<@.s$>O&m&](SfLdIKC-qx8;-QEh9&'b_c)bOPV-rZ*20,gYc2@@KV6^At+;(nop.OlXI)Rs'g4o0Jr8I^Sq)C56g)jbLm8Tv=R*6)TF4$/h;-Fo`Y$wtC0)M6#3'.7?C+C.^(4$wl'G=8%a+A#_/)JUi0,6R*61pL/FMcwd1M;]#WMn>].0i1`i#Crk-MPO8d%[)FjLQ&;'#JSTd'drILc<-F1W-]EJ%#wRF4i@=<%Cx;9/`xJ+*l-qA#g0Te>2RFqA<`82'#E6<2:ou>#ePtJ-^ISrL<H</1xZ't%PdCk'9Lws$wK[a.[Kb&#3Hls1l&e)*e/ob43fNT/TQE#PL+.URoteo':bNt$t5,+%-.0A'F,;&T;XnX-m?kp%.JO]um)x_9$J2H*2S3>5S/]X.gj-H)Z%AA46N.)*#5NT/ed3j1)IWM-Pd$Y%MX8<.>_N5&l5:q%6ccY#Q$=]']eAQ&7a&cNb4-3'9&Rg1s=I;%R`j**R:Mv#R_`aO#P=**GlcYu/kmQ5c3EQ/(PUV$A7xUd5>d%bKJ8>,<Lco7a8Vq)#Ov)4L)b.3$DXI)lH@lL'UMs-<)'J32K@d)VF%BP4@Zp5`xJ+*EU;',YlLZ#<NLQ&)*;mQOK`$7Q(@bYum+[$m9)/)xK<v#lO1=6F6=1DQfcw.8.%X-r)6Im/7d]O3NE?PYX9`$AhsT.dd0'#SA/,&/T[)*C:H:7RbNT/`Cr?#2<^5U.8PmB_wCT/h$5N'Fvb?-/mbo$n%&N'.9OZ#]&r0(O@)Z#gJ9fDAgD*3T*+X$Pagq%Hp)a*V3+=$.Yp58x.?%-e22g(-j8q'T*cJ(>lL;$mYW48>;p<R[#Lq%6JlY#KnI[#(h(hLFfv.:?Em,*xGYc2Bm<Z$X$A$Ta@AC#HK7l1K&ID*0YX?gV:AC#UrF(fDGtC#D-0a<bL:W-UC3T%^H/Z-;QBa<28L>?M_12_94%P1hgXG2h?Wm/_Fns$cW]n/hn3X$dX`X-WqiX_Y'sr$8A6`a>SZ%bEj?D*9%0;6s0br?F]tr-CV>c4aIcI)dT')3ETG#>J^CE4R.q.*I&lp8>K)<%KfSD*KSQ,*cPWb0S^pf1JKOA#scP1M>=])*.SsD#(Oo8%bHNh#_]<+3OJ%h$EN:0(1%TP'>N`qMQiu^,n.WiKDndK)>bn?%Z:#G*vJ`INKF39%>SE5&rBLG)B]e[#F([8%JcW$5RH$G*UAeD*p@NZ#heiY7)a0W$Rc([,IBmD-e>KK1:Ie8%KYAT)AukM(/#7`&/MY&%Hq*]#rp,a3Mj(*M^25a$_44GM9%,'.[o)?#/SeO*MT>j'pIZ.'@$^f1t4G&dg*P=?gs..*;#K+*lS[]4[o[_#&Cs?#U6]<-Z_V=-Wf_w-BA$vLn9da$IT^u$OoFv,Oi1?#II;v#]N8[#/RrN9l#^<-aqi=-$&I=.6u$s$H8o>5@xqv#j0As$I$J[#j9`)+5r_V$liX;-HW8ppD=wXN@HN>P9Xsr$A=+Vda/k._Ej?D*J?@M93Zr.CFfUu7gnS]$vbLs-i.<9/8-U:%p&PA#02ur-[t'E#Ird5/stC.31IqhLXe?m8Ta3j1ZsY]'4V*Htm+xD*?.YZ%aJ-_#wv:50MFD?#>A&bGJ.dY#^o6.H_am`*b:#G*(-&?Pt3R=9UARH)kp`pTLnfRPST*r7K'ZcaL+w5/4Tt^,cNA3M`*LA=amtA5h6SlLd+3S(HGlY#J>IPCaV>W->XJ^ZlXGlp?<-h1'&>uu+/sW#N)+&#iid3:K(Zg)%HvA4kYMu$`x;9/q):H*<5.i1<.FU..=_Y,=EOV.GO=j1bH?.3md8x,VxG=7K`KVQ%+O8:NH<j9:w.t%bq%N0j:urT%O^T%`;G>#4(%<$3>bE*Qb7@#G(Z>#6cP>#@Rr?#$j7O<:NOI)DJas%PdCk'`nHT.?1PI)tv>4DAneJ&P`U>#/JHd+'/Kb*(ETW$H_*9%Dt8Q&%####Bg($6lR.>>7kb5T']1)3Q't'3)TR12p'Qv,G#[)*mX_a4Hqn9K-.+D#qY2P-[HEG)g>b29cfM<%NvIq-b-9q%A)c;-C&&m-1L1<&9'u89)Q2W%N3hW/HJ>d$#PoD3OWt&#FPj)#,$###0k'u$q'^:/+Z6lB05dG*-1Es-@63r7mGA4;84ofRUFF1%Hx8$(dO+o3sKRI-r03g*b*>N'hVnH)Ee9V-^Pdgb5p:H2>;f8/o6u5:cx>*(Ib0.t9hbD#aIcI)<xNb3I3f;-gCR.1n4xD*U<RF4k:8C#tq7>'gJKYhQ:43':a,vA5v$s$PZLqSut.#']XNp%p#&eGsWq2Bc3EQ/h=+w$Bnxi'V4+gLn3dA#El7-#Q3=&#<Ja)#'b.-##<V:@W8Q$(Jm=H$9IXD#wKTpAdD24'a>^;-gi'?G`.gj,O<mh5^jdJ$k*Ek,j.0#vc]2aGhOg9rcg8b*Q'(6/TekD#P^(%Q5A4SQ5rd*Oh#f)B=U,?_o[PUr:ikA#l&3vR-?^uGxe9N(0xFS7%QgW-gW5*np0mo7j'xP'Es3^%;t@.*CFu$%hj)9/x<j?#_Y_o%0W7C'g;M0(;';hLCqOu+EAg;-JW5L1W8k/$J-t9%5@*,5I;w'&`4`BS;KM-)'7kV7ELY8/<M,W-,J<X(<'0PScG[p%O;Cf>'k0hM-)l'IZMXm'3O?M9am+rMNfsNX5Mp&]6ZAc$Uc(d3WxZg)I5^+4(UH1%97(dMcB#fa>RFa+a#AiLvUoYM,)2hLs1N*M]AKu.&^r%,2O)%,.>T7J0tu?^ih3>'Q=4J2j<,LU+2r_&DkDZS8.r)4oUn92oK-bWqVuAJl*_)Ma?G0.4K'%Mu]j$#S6_c)6?i,)?b%?5aKA8%$c<9/%ZP^,[bQP/iq_F*<Nb)+-=q2(M=)rAg`P>#9;#j'OfED(p8cP9E$6/(/qvN(*OLk+(OJs$#Xu6*b%?lY=LG&#>&lY%9DH%b<G?`a^hHP/PW[i9+$?PAWw`uG<Wd`*)MT<-e$>44<$+r.sJ))3*0=L##BqB#1N?.%qYA/&C)ZA#n2J;o3J;/s;4dW-8qJ4rH@NfUvbj<%EQl/(pYC(&W7^;)u%O-)8MsILNgSa+9a5_FV<Vh$=HY,%Bu:U4t'Tu.qZ;-*Bm:Q&wL/W7h[l<M=.Pu+bkP7_7Ib8R2%PS73jIs.#$4K3KT1E#g4h'#XI5+#CaX.#p:w0#c->>#Y[iik7tH]%DE+<-:pYsH6'$Z$I7'L(B(XD#`w[s-V%I^PX;0(O1^GA#BjfI*(/rv-g]]P`[t]:/+O@IGv2`X/vOj0(C_39%u^f;-evA'&>-niLnH5rd$7I],0$,T%$;?H3OVF+5<C];2t$[gu6W4gLQIO.+rDea*ea^W-C5G@9:0G(&0hF(&cejO='=2'5;gB)O$rJfL`<R##;j6o#fXL7#W-4&#Ii8*#v,>>#ak6^]w'LF*.kR0#9JeA43-Tv-mvdOKgX3j1&(9q)pDPA#qYOj11&))3xr<Z%rn'02t^3O66NXm/8gKe$Vnhl.H=_YS$60PfbF]w'4rpf)D(i5/[@.1('B>5M*<jJ#=7SN'Ysu3'jbqJ#1*#<8H?Z51aESjkT?9-%K:I+5c<Yx>-LFT%[@JU/Qmav6N)TT&$(s5&:Kx-$(*g#GQB9q%C]+d(R5r%4`o$0:NBGd3?29f3E5Ov$?kIq$:sPF%'8Zx6B7A.%M86g:^9L'YG']t-G(7s$p%]L(avSe$LFt#-/8k.)LJUiWk,1h$58oO'eM.-)@L82'OPs&+@RaP&OY8B+Cq]M'B,FxY^xU/).^v&')*6qV5c)t-FaqL;AP)0ZUiY1MA%D8.<f-<-ND&$2[3rZ#<&D^#H-,3'Uas?SL>q&$[uo'+FAl_/%mp;-_OW/'jPbafS7[w07u9j(.Zk584)6@d0No._[[-5/IgSc;/H&##hP`;?JBav6R+h.*AP>s-nhpb*b0tp.FV7C#DMD(=^vcG*m:B^#RqvMVY9j?#.`6<-lHem%FRM8.bF+O4tD^@#CDRh(E$[D*Kgcn&WUDv#[okxYZ9F1DQ+;mQ]2Rd)@xkHV(f>C+kSu;.l:x1(=oHN(cB+=$:WR/&p]q6&j,(q%:]G>#_)?7&`K][#t^Zk(btw[#M6ZE*J6:,)CxhV$=H;G#8p*;0wTw31q0D8.@V`0>*)U:[liN**N9tT%<`mX-rPn0#IO3T.VN0q%CA(X'nv?D*?HcLs^OF+3Bhp:/:5Rv$7QCD3Yn^h1@Gp@%4fcYu(+D?#IZXu7o7Z;%$Okm/Q/%>%wVvA45>w#'9e]f1aGUFINNG#>)8FA[8vO%&<6Tv-khp`NaPXD#H.ZkOd$92'G9gp.()ta*t<5Y(]eAQ&uh4gLw=B>,/sg2(/(UkXwZIf=.wIX-KwwQ/d>dn&*UK;IWEd:`w$cWR.0hp*NrMVRL'wB=PZquZe)S2io&^%#`5ct7iKC^#12=a*=efp7Hfa)>ssW?#M*TQ&e_ns$H3:,).hsq.i;+.)WHHiR#p5Y%iXFgLYdOp%Up>7&WGY$0Gw:lK1mJdt_*w##xUs)#k[P+#`'C,&FL?K)55%&4_R(f)M0$?>n/G)4B,l%9#Qic)20/$n;Y[&4Iv'J'wwU<-@o1I$5)J-)mkjp%%ht1>vtblAuVdnA9ScqAeSFHVQ<B(MwRwC)9xvo%ZTXp%d[(%,3(>gL(ru8.O3jxF->>^%I'l%l$:>R*;3IL2'/###%b_S7EvTP&`U18.757T%'rB:%Cx;9/v1=^4m&L:%A7^V6Oxg.*OV>c4UJ^.*_=@`,V5MG)B4r?#)Sgq:X`*X$M4xD%s$&T%8r:ZuDXiD+vClA#iU39%oQ2#PdQRh3IiVs$Utl_Pm8wqnkYL;$2fQ4&QHXn/6QvS^)N)n#/5BAtA@`Z#'=F&#dPbDNNo&%#p&U'#mqbf(8X=@TSO$ZY%^L(.;tV)+s&+M-O-:w-Ld+hWUojdAXt2$##Km<7Pg5N'W_d5/D:.##&7Js-q>W&+[WOT%%Ov5;.1$^Gp[%@#E2buPD4H@LQ,-v&[d^Q&p#Ap&mE:iU(u%b4EHPn&`>kl8HGPe-g%hY&Uk1H2s+eT.Su###%vF:v?FY>#B[u##Qqn%#k$(,)(&;9/sJ))3R2B.*+mLT/u0Cx$a1tj$&ZZ.Ogqg)l]0f(%c,Ur(8,9>&&'k72o(kg(OEp6D+-<2'i2?a3OFIw#&nAW$X*<?#>O#12?Iwo%AGhj0A4r0(A%S,V13C;(IBSn0XPF]$iTk,2iFSX%-m3t.k4rv#b'4p%K&Nd@]B=m'b-[bU<gSSU6&6X$X5um8nQG7_d2Rm'DT:D3_:2<-g%vV$*:`sJ]b9mA=?G)4p$&Y-?]u3F]>]d3+B;,)uF(s-O<P0LRJ]nN^d&$0&Z29/&9lt$5#qf$P1'R-PS*>(C>:fDx*LB#m-78#eCGc*euDH;n;5H3l$U/)_PW]$qY=O2u>kxFC_39%KMYe$1P_w,C?XA#9]`Q&[P]X%&^,T%v-#6<a=/8@$@#v5:sst&_BE)j_Ebp.%5YY##^+3).YV'#N7q8.KjE.3an@8%KKBp.j*'u$+m27:VmVa4k=8C#gSv9%U&/ICG0nm&IwEX$p4[U2l=1M):L<9%l*D?#aX.V8%f%b/U*VH%9+e>QHOx?6*(+>-I$O9%*b24B)C@bN#K?>#H*V$#$:7I-PvDG#%u'f)D+Rs-a,)(=5/^G3nk5a30r/GV8D.cVdD24'O?L-)gNi&5RxY<-pFMX-F>D_&(H:C&U([0);WSa+9f3A-GEH9MI]sfLE/34',>###h^YfLIU;;$>(1H2K_R%#n2h'#HVs)#'%(,)PvHj'/h_F*:27C#7qj?#l+]]4dBXA#u3Cx$>R(f)Tk0,&W2))3wT;m$M]WF3>TYp.U-X:._aEQEiGQj'c;qi'$j4'%i_rZ#@]*7M%E/cVNgSa+D$Xp%+p`/1`$v3;ZDF]1UXQ>#xbq_%BE'_,PxZwJomgjCF%SC#CODZuGNf-6aBbr.DRJN'&/K;-fY&v.$jSr)QQW>n_0*?#]ZI%#+^*87p*5gL^>LZHZh>w-jUKF*jx+G4rg*bRr1AH<VC0Z$FL9p@D1`BS0L][#qoo]$+)Fs@2cMcBL+B->N;R'4Z2>C+Xh%[#=F$p[_ImP/v4[m^ARtVf^nH>#V#x%#]$(,)1h5N'jZiYPX.it6PTH-&'Eg_S@B+a*'#Z,(8:RH)Jg4',+7>q@>n&6&WB=Y'$-mK5iNj?#FUj^SW+4p@PI'gLL_CJ)3Rg#(LB'Q&(c^58n<g'/S0CwKK,5uuhg(,MW4DhLFwl&#;kP]4CekO:Q9d;%c/v[$mq@8%='J,3CDZK)jX@8%:q'E#`0`v$8;f`*l2e&4]/np%U3dr%:9Ts$9fCZ#fEg+2Z)_6EOB$$c,S1[ESa:,)]3IF.^dK=1KNev$B6^DCS[7v?Ycq@-c.1lLc<`-Mb&mK1O>]iL<n][#a68x&RBuMCAc*mLu9Ss$80eu%:2%AbaE]f1Q3Z*l-2vT%8,PZ6gH7lLmXu]#_HGd2m#:u$'pus.8EtxFC_39%JMYe$@?Q3'^9jv#8D=7'#9tv#1MR',F>D9/<?Kf'9`rq%mbF3'G2VZ#&c5Q8LQGQ&Ce3p%'kG?,3^_Q&6,Z5&a0v^#8GQ%bQxMcV1Q+g29X-T/j=Gd=Z-<iMmVE.3[Z*G4an@8%;7Is$R2u`O#VAs7+8nS%[..<$xG`-%u<5B$c`9DjaI:k1B2M11tQ^0(/]'xTs1qh=S&iG)*.Gd3Mu3=$FwJA=r=;v#a9n,*j9###%&>uu1aaL#CxK'#%sgo.atr?#P94eHIe75/Zb(9Jm0>)4oBKj0[/*E*[5ZA#%+Zg)I;wM0VC1u&]ggQ&M?[gLQA1*<d4P_J9n2'5Q>DlM$7tXcbj*.)#3C@'IHuq2*ti@%=r(?#lii#5UXB]$7+oU.CD@C+Hu@3'>k]f1NdWf:G4De$sOoxA@`)T/7Mm8.g<7f3##lRJpu9HkevkCPciVQ0VJ;)8%:Bq%gTEkLnwVu7D8:WLhZlr/Jg4',94bh<u*hb*i@4N0?lu>#mH+@8Chx>M05+A)1x;F%:_XAG,6:h*p_=n/n)^:/g@@/$uFkV&_r8mAFY$3q99=8%MDW]+QmA3khZbK)PEZd3dc%H);5Tw$J29f3DMn;%`QDOBLQD-*Zj:9/Z%FF3Ju>t&x)%w8OxcF+wOk.)b,XX$V7U6(&Y'@%A(e;-6^5W%)9Fb.&mtXZG-9U%=ux[>+G04L7c=>,nN*2005r%4]$%##UmFlVdcTg-[2he$(Ov)4')'J3=s(Y$l9Mj(;X^:/ZO@a4'Xwq7@T7U/M)D^#o-24'YTF+5_I:&4wi*.)GD0;*8wJuAjM6',TI?ofQIFF%dN,p<r-qK(0(gn/?`(0MT;ojLmYGwPa7@#M_Pdo/T[i8q3F_'#tJW@tP`%/L:,NV6Y#B,3*56R'XQJw#v;Tv-Xngx$S9V9/kon:/`Ld5/6B1C&&'p]#sOsD#Z/QA#cl4Z,l1pb4*xV]F?C[8%+#6w-gh=?..-:Y$dk93'X=gMB6%#[5KT(g(6>h(,N)34'M-Xk)P.d>#>$^Q&js*39kxmo%U0]8%NA3I)wq1)+<WTJNO.u)svH<Q/KD8^+pbBN(Fr_C,`I,D#jhtM(`GvR&,_IE+M^Bt-t8bmBi*dG*X*bT.s:Rv$ugpv$)2K+*.7UC4AvM%.i>k4<eG?0)d2/'+7bqC.RT<N1HFL2'Ps2/)vYFRUpJ26T$$^N0M`uS.deRv#?+J3'd;###fN,/LNrIG)x)'/125V`3B@0;6h>3Ka>JqW$te?x6@f%&4;#fh([hi?#ZVd8/3eit6VHL,3#*$E3R`%>.8$<8.FRoU/YS1I$%',F%=$G&:Q=Ha3dZbG2Xwiu%Qfm[b']3D#C12?#iZrZu,@.D&prB7)wu[T(Og)6S_JFU(YXn*EY/?v$M1`e$NNcA#2Vqn#V/%-)w1058MNPj'k6V)vOl$SVJVj3GdmG<-%(IM0%,Y:vHh8E#irZiLb??>#eVT16T:Ls-[J7&40Pr_,jh^F*'[U&$F.<9/CP,G4.15ZG8o:Z##=Gj'NMl[nuCum'iQ/R/Cual0CjO',xr2^ud<)D+Wa%[%XoPu-Wu,##EEe#6t4L.=1?-v.N6>j'mZ%'5m,CV.o++J,+#H_FV54W6+mg+*os$crU,9v#COqr-ggN^,:7%s$B.i?#QNNjL1uQgD#2YD4hBf;-un7T%[gxFiY3Ev6IcLv#.Qc++8T@H3oi.h(YfiT/%Qrh1L%+0(R3b1'QG+m'eAtD+'N::%9;H%-n.0c3-n8s$/m=F+V@.d+fN=g$I2>>#M]:E3U?O&#(K6(#HVs)#ibY+#omE:.=p0W->vq?[+fj/%mX)<-iLh5%vK'H;HSP8/Jn@C[ULc97O;64'xSO-r(f>C+x_5'5CM5>#Nnbr/8Z%123D3JUm&DAPpWvf;@Z*#H0(LB#<UG<'91+rLZF?C+rRa&l4*S5'agmxuYLN>.Q5RJ(iP^G38Mo:&xfc;-4W%:.%/5##)<$N0C7>##eH?D*Q4qb*?N_<-u^<b$jlOjL)N&],X,U:%[5MG)82dA#TglHZ+%W9`TrZT8a2?r%25jl0RJ<e)lb7Z7Gwlx4'AuKP/q.'5jbml/Tj:11@48j0QSDP0o#`K(RnU$v7m6o#WWL7#gd0'#C9OA#7)S^.HXX/2c5h-%+*>9/&,JA4X)e]40V_w,UkH>#P52k'i6`G)o[O,Mo=>N'i,K+E;Dq9RI,/t%Bf,cG;?J.*L)d>#n7OQ'BT]**_YRB$BfG;Dpf%d)Pr$IMpH$=$e;?xbFX02+m`V6/v>$(#k`Hh*dvk9.TekD##w;gL*mL-%UITY]''Bf$%>i;-[.A;%2tFA#xGY`<.+CJ)d4u;-l5a+l10M-Mh#6/(5>*]>NE8X[9UdnA/MIC#T0T$lkmt9%-ba3&b1tJiSQu/(sQae$`0bOM6>(i<-HlT.IXI%#Fn2#&`WJO9h-ge$[j*#&97WAF4wFT8-RZd3M4k7hqwQd$x%x6**[SFOK#=a*`tI<-G'f33v2h'#4dZ(#N`aI)&)A_4,#$f*6Gr20Q[tD#x'cJ(&A7Ks2OXD#rTsR8Bo`#5sEk=.KZv,&LoEF#-w?aNdD24'R/gV$x>865w`34'.(k*EhVnH)?<9Z70_Gr%r@kT#;;mp%75m119#c+`o[sIL93dr/H2Cw-i5:pLBPoH)$D]5L&(LfLt-gfL*G)^#cE+.#Atu+#bkP]43#,G4d/Z%-e:PK3q`Cu$$d(T/B4vr-'($Z$nK/<-equ-M8'xU.gc``3a*#O-YP>s-gBX_PNXsX.vCZd$q[OL%6o<0(1M.4Cwt_s-R]_s$.A9G*+(('+1:))+]T_xXC_39%ee39/>6K;-$q@n$=8jk'eAVk'lEFG%##v]uJZ%12%,nF%Pe8R&D)+**06*-*B:D;$B4tc)dCgF*]N49%t:1<-6F:C&u,vN'5DT;-swvi2AR[Y#YfY=lGS2GVm)j(EQMEB.5)Oi/cx;9/?;gF4^ts20gc``39`p>,VMNs)[@[s$?=]/;3RA%qB<h7&u#Mf<#^eM.$X9baBZt2(jEgbaM`S?-$(A;m93dr/:?Bp.dD24'+wmx'Tr'p$D,8-#%2Puu.BLn#t-78#[9F&#M>.l'R)LB#k%AA4[^<c4lT&],VpB:%d9L]$?]d8/`-4q%K%v>u@Y:a3wO::%G)sB4q1-Yu?SPJ(HG[3D:;.'7/S9,7olsb3(-s</njSn/^^'LD*VQ<-pL2='VwDO<FN4u-Tl4Z,[PTG.h_<9/*r#j1$qk_$677<$T8[<%0wA&=69&1=7^I*7gOeW$J-fw#hPh'#$,Guu0dqR#e:I8#[ulW-Ah'[Ko*TM'BO=j1-Wgf1%OG,MEYd8/9/^n$<-+mLZ_YA#2P,G4/[/I$B'PA#kYKq.]0#3'H?#7&A:VZ#&]:%,cmT#$[0J[#v2Op@&:cm'JSl>-i@j2'Y=Y?,2f370.%clAS]ZT82V0T&G[<9%5[[h(($:3'AkhA5jN7-3i[#Y%.X,B$A$'U%_r98.joH(#'&>uujD3L#F[u##R'+&#h$(,)eDK-Qpqi?#+=tD#(+Ap.+o@8%ZbwZTP*.0)lH8j9=)Wm/XB4J*T+DW$wIcw9#ggx,2je6'933`+maCa#fAMh+Ss>;%:YG>u?n.T%gr$C6J8j%$WGg%6*Z(a63kHE$L*C8hxQ;[%]TVs@wstOS,E3/MKVY8.`D#6#nvLH20WH(#@2<)#e0;,#>*'u$.gw:&SY^5B87>d3^wxR9#4w#6,R(f)E[nLMkxId)/##jL;+b'4TmwiL1Q/(%^,,W-nH;wg/@.lL6]6##dDI-)[XD<'+]de$FC]pA8IvH-uQj-$_nb>-DV5W-)d_v1&kY>-b,Ok4;T&pAa$rn3BPRKWgBn>#U#x%#mrgo..39Z-a8t1)I>WD#/sYD/4Bic)IYpkLgEL:@3W4K1GS+?,^?#k*>bc'$,:>#%uri112=uY%R%*Ab(f>C+%3c405fUS.^>i0(w&Nk+oBbt$BQ+P9le'^#^$Q;&h4$##t:.a,0$$E3LERb*$RYU.VU6K%D?jp$X0[FNLWqB#eNS+##p=:vA2QtLRX%(#p1DMMN@rB#*%'^=*XsT'Pej=.Vq'E#]urR8w(Z,*Z>tR8r_21):JeC#m[cN'.H[p%iuP=lQiB(G&>0q%sTC6&jGW#,5N#ZGq>hd2Gc&Z$78M+Llu;s%Yk=NX<<.g)Ubsq%w<RH)%TZR&t,)-)Du'@07u5H-%5YY#/UVGaik4kX(:iWJ%:L+*^q[s$aqi;-Ill8.3v+G4D#1O+I[lS/]J0u(^,ZA#Efu>#.M_+*F*^m&oi'6(q+S5'^aZp0<G<X(W^,S/M^j)+TPC$-lue-):YL;$v*JT%Y%Is$8Hs8.s9>n04nD;&x.SZ5F-?n0F>w;%JTPN'l'wp.<]l>#%4q/)=pBn'^3J%#odV8v<k)'M]A*$#r&U'#A>N)#_C,+#t@)p$0Bic)0Zc8/0/q.*Mq[s$(8-W-*9*hYS?,I*.._C4B_x:/Hc*w$b8Rv-xmA3kN=tD#$8^F*pD2)3;nHv$cLLl%8J%em6tfR/*a>_/H%d,*:Tf1&hF>C+Kqgr,x/KA,?naa.82-w-P]<$5'M'J%ZLaP&t4[$$-Gc>#g)e)*MO5j(,#9;-]1i5/pY%12_M3*MpEjZ#l4o)*(6eiLuhDv#.T;a-#bP'A0,W1;7Xd:&*RF;$2Ar_&R@B1pXM*i(EbS8SX'tl&90i)N]Iw8%R[hXMm5KnL`P):8'kG11U9S@#QI6n&U)$r%qx8;-*.K0%Of6D<N8mv$5Zcg$G<Tv-(t6l182Cv-L35N'D,7W%Cb#V/;JjD#HjE.3nfjI)D8v[-#2J&4/m-r8W=N`#Feh,)F6nc*Zr:Z#A_<9%t[2T%a@4,Mf)=Q/FNa-*T^X;.k&lX$H-VB#JR39%4o$s$F2DW-ZT[w#oVhU%Kw?G*G?^2'1Y1v#=C[W$e[C%,5mRd)OBaI-#^7l'KHnv$GEP/(#@P>?q<)-a=J?`aBgZ`*^SYKl05Dm/:oU@,f9*Q/b5i1.M2FjLMZ.:.=@[s$Vt+9.G1clArbm(5p#i2'MFe^&.qZaNw1@N'mIamJ(Pws$LpM`NM4Tj0Y])T%-:.<$]noi'*IK0(;U*9%x5=i&].Us-4(.<$OtM20%)###&e_S7v3Us.14^`*:1>T.a%NT/)`uS.GWRl1$`uS.>;gF4]l:p.?Hwh204pTV#&'f)RQFv-2Jo+M`(Fb3*^B.*Nw7>-L*(V%6LOA#jPe)*_*JQ008<<%xcUP0(sYo/`g+]#l_.s$=Cqk+-3'_,]em5/S(W9/&jQv$hi_^#0eWm/%8GE+HGZP0WM^=%ug7*+6sRh(ug49%*kdg)=`D^M,j3r0:mCSI>IUf)r34T%WfLj(#VJfLu3pfLT_?>#0-[0#.dZ(#p<M,#CRHV-;fS&$Rq@.*pD2<%.HL.(H.,Q'eL0+*#Uu/%mPi^,c6I>#HM/o8hQkxu<RSZ$2Bdn&nRl_+L9N*.&f.[uEfBPq3sc9%NQ:g(=[9h(dS<E*C7[s$.0Zmo:]II2;kq7'v$kB-)l.T%ObUb*:gd;%F_6_+0H9?-)e;.3WAX9[/r6s$]D-Z$l_4gLiIci(Wn7<$/AP>#SoIfLNU6##s758.HWs+;lCmE(hjhRJvP=@R(kV@,l`ma&)T8f3RV?p%0BGA#KO)Z&Te]CMlsOo7u2os%ElZp%NQ,W-Y3pZfNC-##l]v/(575+%*t$K<dbLI5;)ge*[V.9.Ih=U%/jRx0;-:'#'&P:vgPEL#fxK'#YY$0#FqG3#h)^s$B00a<1F3j1@T%f&)dY`<+nBn';L7[#>.e8%dI+gL_B]s$UZ'@01B6N'%e75/7fHMMdr=c4s0_fLg6[q$s0=H*0[7x,2*,d2)R/[#OHOA#Dl+s6dgp:/W[3U2$-`;.AZnU0',wv$eC5Z,-9..ML`$#QY%C8.D-#j'.N7%%vahv%hg]8%,QF?#;=R<$C24W6<bPvGVfO;-mS:B#*0T2'<C.[#h0%x,IX3p%>vZD*ggo[#57.[#;hAm&[a06&a-Js$Mn<T%eMr0((k3e)HFR8%Dhw8%_?t2'9YlY#>:VZ#G_<9%3S(v#W00u$F)w)*`]Wp%c`9>Z.?[?$1uhv#C=%[#PEDB#Ix+4(tBw.Qwpg(5gX'R'qAd<2G%Dv#t<Y/(K#eD*k^s2M_dxX%Kqn8%tH:g(7%'p&l;:l0ChN9%0Sl>#Nsg>$e4te)G:'p&Yu=e#<[<9%J[.w#V%]fL6pj;$TtpC4K9kX$Y_aT%))#]%SF@s$1Mc>#+jK[0*;JfLIOQ##Yg=W-3#H:p0FF)#hHYs%_:jQ/wHeF4MPsD#kVg;-9Sdp%4PWD#lU/V%>T1p/Fq'H2p,f;6)dS^+;_;W-7Ta?,jv^1KV5do/+bC=/jf[_?:^eQ//4br/V.am/cIAj0eMv4*-dds(/XHaNQ,u;-PY&;%H>uu#KoZp..bY+#vTO`mno<?%wlWI)*BLcd-fZx6;,hf1T&5d3j`G.DhtL*4+gB.*D%o:/`iY1M0UGm'&%1x5G#[)*le4D#)(u/1HS?%bC_39%LHt9%A1X+3K6NH*rxP=lu._n+S@Gd3[Q53'lK49%S9Bq%DlL5/h.d8%H^dgL1EfW&=L[S%RMshLYw`v#lSPW-GXE_&>S2P0HJ7j1vPK_,*,2%Gp6ar.X'*u3,aiK(CH>R&;%fE+Ax>Q8ug$sAlO&]$OF$c$5/-T%*/5##:d-o#:WL7#Yd0'#/;SC',c7%-5@AC#nBFA#Dj0I$QxWD#rYDD3D+p_4.@sp%2;v7&j/^,2U[c>>XZ+>'gDvV%iBo+iiL*I-OJZs$(s$W$u)qa<TP'H4/A>##7l5g&Y>nx4Vpw.:w0+;?2:'XLQIcI)@f)T/2Bq-%13w)4HjE.3IG1I$'o2M2xraI)#os[$URoU/j1e8/u3YD#[I,gL&+ip$ZHFs->d7Z?d^'^#sf^58s9_B#_Nds.HlpNg3J,W-Ki`C&=?5A#,x;Q/iGg+(#1JB#F$;B#1Paj'BNV^qfR@%bp[>mUdAHN'Jns$'Wc4E4FXwmL^6Tu.MD4m'/LYj'$7+;.2M,NB$6-)OiYr=:#ET)EdjBn'$sQ]4TW%29a0Vd*Vd,6/atr?#I2bd*,IZ,M;Hjd*OZ6k04g/+*s<RF4JC@X-n#,W-s8c'&43`u5+__V&P?^Q&Gp0I$-d-MN1$VdMh$&s$td@E+a*)p*GsnV&5PafLFYN#.,-neM#f(eMfT>*&%Hp7/%ht9%^][L(Moteuw;<a'P2P:v9wV>#I>QM'*@.K2?=#7ArqP,*[1=n-O;$+%p)Hp.mxG=70XB>(oQ,n&#UnW$del8.9G>uu<__$'1d%('m[cwLTnCj&5+)X-<MN[')gVw$]rte#oZs*%gH:g(aW@)E)o_P/Tg'M:g[pTT`.7L,ET*)#$),##1-1n#fXL7#Ksgo.ig'u$-E6C#4LRI-;)`x0GQR12Fp?d)nM.)*VrHh,Y]+:/OJ,G4)2/E34tFA#W2a[.94^gLEG9f32Pr_,YTx[#wZ=42R'`^>.Y1Z#.(pxX.0wo%A^j`#RwI>6qQwV-x+rZ#EeaT%`%#?,(XXp%k)k-$Y/YB,x[s9)i.iZ#Z(ma5QWIb4$?Ld2+?QD#VJ9X:Sfe7MTr'7'fJ8A?6#w/(Og`n'r7>f#LXn<$7]1Z#cSG/*8-LJ%=t:vY-+L=6m$jV$$Oh0,r?w%F<sk;-a&Wm.*2<)#BlWU%P9kB6A/i1.-CTfLrI$X$='A.*KOg;.21C9rL9cO:S(>)48km;%:UZQsmJ))3#1<:.Lk*.)+V0T7jGPb%h21q%cmXp%#[)%,RV=V-dFBJ)`9T1;eILFGJ]wd%bfLT%OAj#la4+wp/L$D&LYFJ):)*b0_Pi0EpY:P<blD2:JIF&#72nj0aQ?(#EVs)#q2f.*Q?Jm'eSkwn%SWj$c]DD3T#Yj&,j1<-PN9o/Dmng)'@n=7_MG959#mrHZs.Jh&R^Lp?gwW&R9Bq%AhT15,7.I-Sg%T%wVoo'#+A%ba_0C*'*S*+,A>;-?B1g(`<%L&)(lq&MRTQAD:;?#0O#]>5pPL2o0&?7&k.?&W:Lt6)(Z(+T_5(H+].(#)wmc*xih,;1+6u8tqDi-2?$%ls2uA#N;^_k0u.u.IoN/2jt;m/-N8^+5u([,?/`_kSd.a+%hNRm<jSa+Fj'_,xD[#%hj6o#A^U7#AXI%#6(cOKtK`t.lAqB#`I>87@S))3w/uq(&#.i$/Aj0E)LLA4A#<**+4pg(IkdDE`uw-)BeK-)h[l<M7`U[M[_Xt(wV*I)K/?Q&'n:+rfFe--O,Guu9dqR#sYL7#XPco.B.i?#R$&$&#`d5/8tJ#'*VnTglPl]#Ff8^$.hGj'Ytu3%L^B#$sfC(&%aYp%AskgL]*8s$*sg7*Suq;$M`7f2VVwW$hfCv#v$^p%vatT<fi?['P$=)<67]:.3oUv#==Y&#wps72jdW$#l&U'#N%T*#1$S-#`tJ9;T>gG3f*B7&ruV>GO%dG*:uh^#1>l(5dF`2MDp`v%%aYp%[2JiL1Xnm/j=9a<-P3j1McAGMCXv<-1-r[-`0Nq;*7Wq;p%@k=VvruL<k0W.Y[3VR`;^;-I39k02IYp%-Z=J*MW?J?7slG*J3G9Rc1L)RVrJfL9bhp7Ze-$?Qe`uG4bZuPH9Y<%0f)<-=&M-%23<#YeO&%>r0^G3]p*b*akeW-49`B'DT1p/E0p[uFNi&5&=@^?qn5]%S.72Lp?G_/]F`2Mniw#8>BS#IR:Yp7pbkA#4A;A.NgSa+X+4W[:[r%,KUVv@MZ3r7wZ((&uv>)O$cdERt4M?-8vYOMdq7Y-htOk4BwwX-BDD(&M6eL,q3n0#Xn)vu4N_n#hXL7#Qj9'#L+^*#)Oi,#pkP]4^bm5/2a=Z,ih^F*mq:p$1#>c4B7.1Mct1>6>-Tv-.@le)`ni?#(&MT/v0UC4_TO^,C*TM'8.sY$jN$>%5pf.*oIs:/wY4Z,jT@lLSG3^4b@b)<(Oo8%7vf.*-L0j(U9Qr@KQ66'k1L8.BIn;-^je-DPU/E+5*8],>AY>#eMHh#U&;0(T'lf(afY>#:5Xt$JG6^=KX]I4lL^>,75xqM*mD,)#`A`=%N^0M*.Z7$==0Y%Oqk019ISH)@JiL1F9A9.WgOp89vcR/qms;$Dl$W$lqH>#%9VO'L8IL(?X39%_/Q;%lxgm]l'(T&L;MT]sr<&+O0kC4Z/hu$B+a01R)mO0Pd9W$Qhi?#wT1hL._n##'/###fK#/Li]cf1BLgr6jK%##I$Jw#J.qkL2K6N'>%NT/f3rI3]Y#W-FukaGCHxY-u;Fwn9@RhG#KLm&<:UT7pDqq%k1Cw%nhe),M@wi0gFYF'NKw?,e&9',2$-F&?E3D#[7tI)leQ5/)mhu$Ca.51O(R8/Vi+/M$xS5'wwU<-Hh.Y-:#EO47kAf$T7_,MG$8(#5RE1#>mp:#1dU)-rV)]$EV7C#k8Ea*nSI0:+e<#-j-pJ1q:@<.w+m]#[*'u$GBSCO49Hv$SZLX%T[s)FWTY8/<F9_-OM$_dci=c4PW+<-ge*Y$ms-)*UA,c.61rnBJ79Q?'`/T%BbsQ/,aGT8*#cR8/cgL(C_39%IKnS[mj4>';#Jo:Xx?%b-[wF#auq;$;@@W$;aOU&[d^Q&E*'q%ZTXp%mbkcM^wi;$-8foTlc>$0Jg4',-?7<$G7wa/iTn%leM_K):04^,Ng4^,8Sue<KLD<'b67HD91IsAF1v7$4nhrZLAVH-xt+0.tn$lLMjMNQ=$&W$V>Bp7$ALX:,9U/129wK#Pqm(#Lc/*#.QLA&gI4.;t.G)4]e?a$`J))3R`:E%`LoU/$E?d;geiMi-+x_#[/aa#o:@m/okjp%Z;24'6xIn$MY=7'??w$V5A;',N5sA#`Mp;-Pi%J0CXeW$Yobm1m]YF%,qPX7&,i?',XHaND@(gaNbB%bAO]d;SFh'#&2>>#P05##Gke%#$/ON.[D]C4uqr;-gSw]'#tRF4-E6C#*s*Q':7%s$[1t//X*fI*<;2-OHi6<.vu/+*CR[1MD:1lUE62W)bDVO'M]r%,p]-6M'b6j%g+E`#WWBY$i;Gb%p^:K(++2N9N+n)auT[=%cIlZ,O4#m'LBl/(oC^84(7?e66dj6f93n%ld@as-uN)%,nb%U%(?7<$(u*e%f+te);X=I%aX6T.c2iS0gbb,MvQ?uu&_/E#]Mb&#ApVF&39=Q8=VP8/F[h>51Qpv-iL0+*Zu.&45sI9&TC^mAf]V8&ua4C&C(Sj:DSw59Duti(j6taa#8poSx7poSu00%68:ZL<0aHY[`hc@57#;p/'$.ekN97I-d`Nb.t+3)#0Spn*h-MRJ?au]osKbO:G$.m0>LHt&dr2]-vu/+*x]]I&T#B+E?$(^u4s'H2C+%P)9XRQ/VJKJ'[14t?>(U4(gj=[0tF[p%/q:iOI_5rdNPbi(@p2a*v,2t-_M51Mb_p88mqcG*%5RQ/PJ))3?4;W-jjJ<-3lK`$'b)*4#$Cu$/kwX-s8:uA>;,f*N^g<6s.s^uomQb<]#/=)l8=@,AlfQNp(U@ksRB.&(M3_T2/`O--1<M2.+1/)`S[e2p'[>-_%vO0`Yu<Qdou##'R7p&nt2P1L?%29'b^o@W-AVH2O$>Pcq]%XcXQ9pX=3R)g$n/Ch,Cn)#B5r+.2?Z-K]&xc5Nw_#bBR-)QrbF'wHjm/J-t9%L4ie$FKx;QR#e%+A,/t-;'dgLK;*qMLd/sQg^BO0<'^6&;dQ-)r=SfLdaf@%7<9a<rN$3:SQ^6&(47I??-Bf$DBmY(9viY(f><ZOC7CP8ikh&lr%.GV6Wgx=(hMp$qf)T/N9Q)4$R:a#?W8f39ESP/-K?C#l[E$6/bL+*kon:/91FK;8>hR'[&PA#oi&f)04vr-+Os?#aIZR]`w0H2Z5OKS:/;J3fKOZ#Z5$v$72pF*^gm`*v/Pp%Nr-W$Fk*=$H&7h(J-t9%`MDo&;w%>-c62Y6APsGZA/#Y%@EL,)D[^l:UI*p.kp9Y$BC<T%DH7_8iU3p%G*Xp%FX7@#KiqTRg_vu#YfY=l+Ik^oW$4D<5Z&##LDQEn.<TAR)%=%$pPCp.w<7f3w1T9rlOtu5cTl$+-3Q>-);/CNBDNT/*)TF4'gc^,%tUhL_^k]>Ab:k1Q,iO',=sxCU&Vg(U$^m&dQsv#Oj5;%?e8m&iM>g*hOjr?NFV;$`)nH3v1fk*4IPHPQ5%F#bw'0+Ji:v#aEZH3oB8>#DO%@#f^>N'FkA2'947s$Vd2b7vxk.-bM&'+K7A_#MT;6&@fXI3Yq@(6xns.LhbH+E3_gJ)e$OK:<,v-3X4H>#bj*.)[-54'dH&CO:%PS7eXl%lo$m%lYU.[BT`($#;j6o#<qR33-Ur,#EH4.#^;L/#$;w0#-RT]90,m<.o/*E*R4r?#&Y@C#4va#fdl4c4PeP,M]HZd3E<(C&x_2W--o4orY9&-;*b`h)97#`4V)ZA#^nr?#PJt/MP`k/M^m=c4:e,`-&(>=(0f.O=ED,dl[h?lLqOqkL@@o8%99Zm/1^bQ%OZ1K(baxW$C0X=$qs0-2pF39%Rx:?#HwfW$O-X=$blDW%e5JjL'kd&5^Vc3'@;=#/3&3k'@v'T7,?%%%v^sv#(@X7/@;+.)kE4GOXh_T7pwP`klW),Rb]uKG<m1u$ZV.^,`4YG-+afF-fYV=-gx-*.kX(5OW^vB$N##@RU[6##JGmi'pmAJ1;b`FcKfPd$/lh8.iR=aGh>GA#2lHs-RroG=bwA[6wdv,*(0Z&4a-)*4lX9_Q??6^$U>M>$x-ikL%DLU[K>-9./heGVu?(Q911:E:n=X7g_KQnAUP(q(rUBJ)%Z(?#mv#V%meG$,%E&-<JTLTnr9L-MS;^;-a4JT%&wtu'lt/%,lfogSC;d7&#)/b9a5Z3'4t)%,?Khc)K-'q%<xCT.5x4U&N/gh=aHj$#ggvX/@a*P(h/D#-XCSa<uQbA#4$n<&2CNsA&BXa(:+PS7J3d'$5NF)YX7K&#iEA)4aoqg<$.[^9b?R&/wS'T7opHwBYxvP/I$Xt$(dl5&5SI.-0+_)N^_$##wc+:vd8wK#MH.%#r/(pLMuj?#rirO'%e75/Yj:9/5IL,39=V/:6+3v6h%an&.6U[',qb5/oi&f)7u529UR$9.'Y0f)PJ))3J7wJ71C&9.KB+k^Y3S@#9SVk'3=(?At_R#)QO:0)sW5R&xDlK16iqV$7:4o&,Tn1(X0lF5.J=<6U0)-e:bum'B,9$.[R;p*(rTe2SQu/(PNTq%]T^2'7%iV$%63t&&pH*&q63-vr@H]FVMW^H%DrB#UW=L#e.qkL@)/jOgPA+4oTIg)2c_[cV*CL3?$0iDR)_'[8+?W-/o_<J10ng)aQv8/x)Qv$0[FQ/%u`p%N<cC-r,Jd<%O(?%AF#-Mu;Uq%)PG8..h_v%76b2(caNh#Ev]kL-9Yp%65u;-G(-$&fw[p%ZOqvAYCU$.=L>HMLkFrLRXXp%;WjUI7=0TT'Gg;-c=*'/Tj)`[weV0G_ZY^-A*dH&iF,87kN%##2DXI)rxc8.?D,c4XxZj9.XN-vq(2I3mERF4>NQ_#[Cr?#>vq?[]_h=u#Kc-5(2f$&.RZU7(pd7&$N,f$L^9[u.Evq&x]d*3(tl]6(f>C+&1s8%9JnF69r/3'jVAnft7]1(mORsZ*36vZAa):MM[%ELkHt9%;/_e$5b0R3uNf%#P6<-$*c@(#praUFh_a/2io5CF'tC*4QBg;.Vq'E#LxB*[Bxa#-o(b.3HOBpRrhZP/k$->%:IMH**/<^4J`qR/'u)X$;bqw%YOhF$DLes$e^5T%Q-n`E=wJ6&:m=w&#_.Y0QO96AhE'>$o<_H)PXNX.t(NL1/n2L)5bHd3j`1^#;Wgu$#4da*c^W`%=wn`?Yso>GX8Q^=%74A#eElK(4)U='4f]>%')v<KIdh)3oL`C,I<Go/e?pQ014n0#_b+/(l(VG2kpLcMgToR'7Ah;.W4GH3wWdd3L/0J3xlH3btf^I*jpB:%/K3FN$4_F*'%(k$1I@1MfU>s-B7rkL*CXb3$N'i),2'J3/&wX.axJ+*Bi8,MvAUv-CR6.MRH8f3NfS8/^QxD48V:KM4MO?/aE^:%v%_kLAc&a#47/4=R0aqKT$UA$(`*70>4/?$8uLv#p3G>%b&io0D=mY#,>P>#pax8%kX[S%QJ%p&^@(w,/f_;$eRWe-4GQ]#2[NZ#R*+t$pmE?#8=RW$>^Vv%,:aV$`jfB?T55'6TU.W$6i*n0OiR8%2`:v#tM<q0<=@W$F@Nq8+^9@#C]+]-<.i?#QOmY#BXR@#RflYut9D;$qVpR*0T_s-)w1?%AQH3'*SW8&<@IW$tvRc*2oh;$P$;oALF-C+g3DP8PQbA#jO@p.7>)4#.bkUI*p'N(5X5bus,'Z-*@le)$DXI)CY@C#U<RF45Dh8.ox;9/xE(E#q$ie3Q(m<-L+2t-RWWjLx?o8%/vVm/a[2Q/`T)i2I2K+4A;Bf3jHIf3'sUv-SOcd33C3Q/Jn?g)_q@8%0=R20@]WF3G'B8%[C?n;tBjJNjcv>#_)X?';`nnCwkB>,QEoS%IaGr%J&Fv%n(ffLS>$$$fw3x#K;j]+Rggq%Up10(QerZ#6PC;$D1;v#C`c>#?_*T%r=w<(&MX,Me'3?#)5G>#.<xB/YYQt1'--;%Kuhv#1OmM9c([h's>+'(oObi(6cG>#Q4wS%<X^g2<'p[#?=cG-=6v%.%`]fLZS[r%ZK5j'g;QV%o1ta*cPVs%?_?A/<i$s$dqtgL6ng#GuwsRMO5pfLiv,j'V6@%$OpK#$n%=**fY.5'i+#?,9Q5na/4,i()GY##:d-o#&XL7#R9F&#9>N)#s<M,#W[U@,wb<<%s:gF4w0`.39N+J*Wg'u$]T'Q/;JjD#uT^:/H%xA,&'ihL#I8fN-&QA#05-J*m#YA#X?lD#Xe75/?[+A'#eWM0Gqg_*>lVL'Gcg<-$&wN'Og#R&@#Q7&Zw=0L.HI%%iYj?Q>S0'%8MjlA0/6a<_gs-$<`=mA3ij-$lsR`Endce<^+1l2;3OD<I=qF$k9wi&p.E`#prdJ(F5j2(CT-)*j<U-M$*TJ1$f0^#PE,h1EvDA+LBXt$AC`V$lh+gL;F%T.,11O+]3:G+-Muu#,s5`aGi?`a^E]rHLJ'##Jn@8%Q/G12#V]C4]R(f)j::8.UD.&4qXr4)3[p=%_WM9/FWeL2JIF<%)CxZ43#>c48-U:%iL0+*Jr*V/c2hf18S]C>i%vG*wk<h>n18@>Gj>g)4'n3+P`(W-uV[*7:`ZA#V7LF*l@AC#X;s359Suv,gQ^a<)*c5&IbE9%:4%<$4]>C+qS_B#QNPN'p^O,2NJdT%>,''+Mm(q%s&g7/@X2kLfRWI+*KUu$P`,&6L/N&+-g?V%OCsK;2HYx#K3^f+K$=t$8-cY$blA^+4frxG@E=Z6r<mK)^*^6&>.Vv#QSJ#,jv(4'iM.h(pxmr%dwums@?rJ)Iigp7p?36L^t/6&Wwfq/ua/M)i^CK(M2p],$:'q%FBq=%$mmE3M<7o'iX6T.uo^O9YJk@$<OEp%2BSL(95A-)1jmn&?]4I)C&iN0[d0'#[,>>#oQR`E]Ux>I>)0i)k]:.$k&/L,0)h;-/k;U'GMHO&m6'Q/*uIm&?pOsA3N93(s(Oo7g+wTI.DF]u?l:u%>PtE$ddXp%d%JT&0QoY#[u&1#4q'H2o(TmA_47<-PK5[$>k_iBM:eB5W59G;_4ND#'o2VA?7<Z637#`4hJPR'T;Qv$BS7C#Lq[P/05Hf*9gPT.^9ki04nw6/@TIg)Y,O/MGA=/MmJUv-`I8n07XAnVBjSW7$cO-)A:f60WT49%s-320+?i,)?I/2'mtWaao5<oAer=;-rbfCMKAx8'Whw7/fCm-N*#E.Ns,/=)[#Dg(,T6r%t^su-W^l3'c/]jL<U;4+/)J-)/xJsA>'00)b*+'#kw2N3['w##S'+&#T>gkLq`_*#*[%-#V5C/#>&(,)#9+CQX;;Z;g-r(&'7Xx-O63TA7eJI&@X5+#-ej#*dL@<-#xQi&Dm_@Q'h_v%4Ebe$em>`&J;o.)d7(<-vK$H25C39%6ji#5ox*K%;ccYu/ac8.JU4'5H5_/)'oDF%'cO-)6l+G-#K1d-solf$8m24'd8-n&.TI-)0w_lgMi=p/s]MqL&ZL).Ir_gM$,J-)nYiV[51@@@-dxK#B[u##)c/*#37_c)=^_V%i]Z8/OJ,G4;#K+*$DXI),7Vp@m4T;.Vms/2Q`J>,]w_5Ol)(h$E4qY,6U`X-G#VDnDhUP82n5>?NtFT%pR35MYjL/)ScLg*PKY/(aO*C&OF':)1VrS%.1>0LusbA#PB'%MR=j8,>p`o0L^v&4>$('-U150L[w;mL^6iT7V&*<%_k26/kQ#x'E6.C#&=:g(6k.=-DI>:&2HU]4&,Y:v<4>>#L$M$#f@*1#ri:9/#&AA4+)Hs-OmaR8ui>w-Zu*V//,-J*sGp%@)=Gm'VAqB#jOPv$iH`.M>$&],D&HP0TMrB#Je75/WWS`E=9d;%As_E315-J*q%K+*$%I=79QW@,J-f<$Zs7Z$`w5R*1&*D#S>;v#vXO,M7pI)$k<S(6qA?S/LUWP&.bPU&vrD8&C9E-*5m)S0OZ?R&6FjP&P%I@-NgAE+b<P/(Y@1<-.+CJ)U696&qh;m/[08E+rMh-2q%V@GECrV$-_v,*(o'f)n<151KnI<$_a)*4lNAx#OLSrL7[0/Lf@1_.5j*.)]Svv$eeBn'`j?e)k>m/:9nT1;fVTI*6i:Z#pK.x,]'^:/TDvV%=g4',Pm-H)cwd5/lQsU.8x&9&;kSp%Z-8s$Fh39%Tsl3'FX&m&HFwS%D+D$#&-Wb$P&D`aw27VZ.F)##uWTM'WK]s$Dfn$$Hc*w$'QCD3QVsG2+K)w$(_Jw#nEZd3J)TF4r3]Y-ArZh*.-f5/8V?x6EHuD#q%K+*2BAL,bpvA#&i<:2)TID*w-ikLghkj1KC5d2kY*E*/7$`4>;gF4?DXI)Kw^-692pb4ZG$1G_I.[#m)%XL;U%],xfN#$cmgv$JMQF%gH),DW^Lg(+4$g)a#q6&1Y:v#442<-]juN'0<8*+SgL0(]iJ'+Kf*=(498=-mJux#Eg?d)_Jwd)(&fh(3+[8%R2MO'Z2n)*Nk&6&SlAF*bWkT%APv92>KA=%9(,M(fT2E4,VY_+AKQR&G=T;.XK%Q0@T=_/&vn1(`m)(&.@S[#?Res$]3FT%3uN]'L9Bq%Od++%'1pQW'CPj'dGnH)Nt<t$KhU&5p[G$,4eA@#4(=N1+=oT%ZX9T&]a1k'We.W$Vn<T%CbWT%0Gc>#81.W$q0%A,J3cJ(dY*e)kwn4(uEeX-76:^#La^r.1#/1((fZp.*,M_&8aU^#Vf)]-d/V0(W?q*%j@rV$pV$;%DC*T%&TWjL`HgV-(_V78aWOQ'Kv$)*N.CdQHl.a3G=UF*Gco=%g0LC4n=.[#E1#`4BA$vL`P8S[Tn-R*D(e#HAb'$1)bVLL%N.4+m=&3DfN.=00^J$.*<ls-I4/E3K7,709k^s$&7wK#I[u##g>$(#t(&N055%&4F?uD#;)pb*(:Km8eDY)4q3q+MH&=G4w[U@,FX2`%Y^J#G0@Ep%cO6D%dH<E(Y(Tu.xrxt%'7FH;<oeJ(KxZp%BFMm&tc7ea6iH4&w6?`K<bfxG<pjt&<fIN'jU(]$=BG`a%`UL&XEi_Xob'Y?[Zu`48*/NB2(]@>/:LB#U]r%,Z4u<MV^r::YT7k;8+ZW-j5C@lU#(^ue#]p%g#BI$Y5<gLZHx`<Tm?['2%VG[%[Bb,=-K.E@f5g)mZN7%vrhG*HxkA#:V-[KSW%pA*GI*[c/5##:aqR#hXL7#Rj9'#lGc8/+gB.*mcD<%.x+gL^J+U%o<SP/=V&E#;(]%-Zt@`,:Cr?#l:b]+/[2E48fd:.)sPC+3_gF*3k&@-7$wk([8$S/Jx5g)Bu5v&^@;mL6Q3E4k=%HFKv=u-d2gk9q$k>$M<q02kB3Y-.T'w#VGG[0j1%AbI/1A=jF>M9:**XCD#c58+d&K2BMnu><0XB,+S<+3wc``3Hlcd$xDKL=m2(-%j>X/2(4$b[Q`E+3hjAb.Wh)v#P%/:/D/P/(NY[s?[uC8%Xk3t$9]Dq%a>$5J^-x<$0$-02;'MhL3<<T'4uJm&NL)?#TZ,##@Z+_/Gg?C#X7H?&Qi%)=jJ<d&OJ&B+7xgC+4ljp%mq$wPWedZ&sF4:&mii?'Q)qa<7/Bh;72D_&P@[s$i#o@,)WDu$Y&P@@)c7(#%ujx@V4Io'mqPv,e)qD3,/6J*??@12cgp:/r-i&2?GRv$^^D.3O29f33GZ59+d-^5?kXt(n@n8/[j;i12D=]#;b3=$*>G>#(YSfL)G3g(@j2&+oS7v5`4:32Wee8%1b$'51f)v#2.Rs$c(/aZ1@gVICY(Z#^H9m&^`*M(CdH)*b;gsAurhV$=H4+58rcYuvf0k$=+o4ri&^%#)NUpL]$cI)[(Ls-tg0Z6gtHw^TR(f)N0D.3HJgkLAU7C#-T,=49Bic)YsHd)04vr-YmLT/k%AA4urOq_)f@C#g<7f3bd,eU%4_F*-e,`-sx:[0wiWI)hfNi(xu$9.DJ_/>EJ>?6Cv<h(gpu/(RH'U%@@@s$QdTY$ow9R'a&mn&Xb-E3JEB:%]@Y/Cq/c01?]xAJV97>%9AnV/Y$8]I?K@l'a^5/(DO%@#Ek8Q&67wS%BtJ2'?KJp&?q:8*#BG2rXeQ>#SI'&+xA>G2SYjv%3^a.3jpB:%Cx;9/^)B1CDqGg)If2JU=9l(7GHpS%i[,=&bDVO'Fhu,e4mP$-G?=v#@+6)4XS>Q'E[*t$'n?#v6m6o#;7Q26Nqn%#(dZ(#j&k?#kCh8.d.<9/$s%&4aaAi)F3Os-o0,M;O#gG37h.Y-1W:Z[0;nW%&Ea-0)%QC+BO(7'gttx>/F74'_A3T%p29ba$*ZcaL[brLe4U0Mqc4i,$^o-)hfL2:w`jYVQhS5'VdU0(?k'Q/?&5)g6IBw>?4_9V_WZ`*,Rx;-%/X_$m/e`*q?tQ/k%AA4[Z*G43v_20jAqB#X::8.O2l-$nekD#u3YD#332,)Bm)`#O0ug1*W<**AOTk1Be$^OkmO5&cn8^bg2O2(.PG81,m+*=%K<D>^<#?cq7I,*YuYZmvh=:&$rFr)'UVXM#dX*E*P@3'tMIY%fM?`a#&3>5j79p7W+v<.+dfF4abL+*.f&K2Yre.%u@Qf*-H;V%s$px=jZoj0>:oDSI%Qq&<bW9%vxh#K'maDWi5v]4<u$<$[-ts83+[8%me/A$F6u$.W71s-Oq/Q&MZW>h1>^2'[8a)[Iw4Y#a$#M;sDEX.Sx6W$aK:m&%q:$%F[,hYV*SS%4;Q%bh#G`aaF5;-s^*20)Q#,25Dr%4`';H*lAqB#k)i/<Rr(>7Rg;E4xZ*G4STCD3&ur?#6I3Q/B;aF3hU]=%Vl%E3gF&>.a]MB#f#5**<rOV&Q_+JE92*'4>^_s-m6A=-3@V+4gM/i1,Dpn/Y-DS*t'`K)u?QU.Yop6A<DniN'4ZV-d]LD?;-r&57->j-#58d;qD9Zd??(,)x0KfL)L%^0lM8f3YhV@,06;hL?&qR/>0%.M0]<<%t=&:)lE(E#$F`a4-2(kLY@+jLH.pc$F(XD#mxG=7.6#F4(GR<$(8HZ#C@fB/'sYxm=#VT1,-joAbT/1:N.2v#h8#A#ks+S/d32>Pe5(btW/U^u_U`T%oHHV#iE/W$bsoj'&ZQH,$MQ5/j<'5J^9x9(LPu]#TemY#0cT`NX?OP&RNEW6*AP##HF.%#Uqn%#ghc+#&7D,#Qsgo.gH->%/(`'%L1e8/[<W1)19xb4rn?X-P^?d)51Q,MkdQLM&u+G4h:AC#o-)bns_?LM7?HZ%EUW:.r6MH*wxgI*(KSm(i0$.)ZG9',bjK(k-J<9)ib#V#j-n4$dD(#$<YZD,Gq3t$9W5t$:%lA#wP8r/gnn21VhS^-Q0PD3;$O.-+i84'-7K-)Zo?`a*fA7-tn-rS$if1BD[.W$;klh2C0#3'D9_d2?Cd<-d^j:/M(A],l]KlLtiUh$X2>>#qqm(#HJa)#7<RF44h'u$qS%?Gs-tY-2e[w5o]d8/+:OA#P/NF3s:j=.%`Bg,XZ24'.0Yp%hF%<-x?U`$`E?@-Xx;c<J&:QV8C.=)[?L-)#_j;-;>1@-o$Dp.Z8Z;%cS&1,iiY2MLI$##%)5uuidcfLdd(X7Z&x.:_tu,*Y&#_FY=T;..'I(&l4NT/jr%&4)%[LMj[m=7*Eg8.$MbI)$67s.0d/[$GG2^#QKG>#[T+IH(0xcMXqZ1Mg'qY?9Tq8IN1R8%G>fv#p>T&&#:A%b:1G>#RST@2>@.<$tN,tOtYG=$lp0d28'iG)Txt5(>vlY>[wf*%9UikLS<@U7t_Ph#]5YY#uY8xt^FOcMbBAJ1m(8C4t(4I)xH2>&j9+0NCPZA##XIh&o:SW?ZkuN':1[`<*aWE*@OTk1];;o&Kn+A'.eF^&D37o[NYRW?+VRD&IW4d.m`sJsse]S##*Y6#9(V$#`IpU@WwG,*nX)W-=A6F%2x5a*7=xs-BA$vLZ&DZ+wOk.)Abm(5'Y_.Gj=<4^j7*;nT%[0)3=Pf<21k3G>ldZMY&:539JQ%b)qx@bsJU`3_J9G;J,?PJF;d;%bW,H2(^d;%Jtr?#Owkj1EHuD#NRI6/qpvD*RRT@>ubPb[;41o**axT%/u>V#$Jj=Gf7A9&6F,b#@62S&vPjA+'KFb+'woW$k'ar.8D.cV.0Sa+v8t//hg#0(K.D.$WWZ^7(7a9%L:nS%Bi:x%N^g:%'3X?#mCO_$doVl*;+p<--hq`$:u)T.H-4&#-x^4.vS'Q;w$dG*L0(r.gl@d)=Bbn2hf]+4.vOv,w@pV-r]$%lVqUE43>km'#i<<%9M8#%)aM#RioID*QHGN')eHU:S)cG8-O49%>;1<-80Dj9L8ffL$RaWB+YPs-?lmgN@[;+;j)B;IbgmA#G7K$.5mi`DDgZ`,A4L/)Ikjp%k37=-uImv#k-oS%h'&j0`=G)NWkoQ0_vqm7?K[*Nr=,h%>`Wucgk18.)_.*(B23,)MH_5:6IB$-Jtr?#@5%E3+0n9Dg1u<M[Upkp2pA'+7VI6021.Q/P`OsutM]2&i(Cl%7-Mn:UWpq%%t*MMAHqau5fPnFquv_#p@)4#2pm(#T%T*#EK0#$`)t>n@cd8/Ft#E3t`3v%pUFb3qEZd3lw*7/O]&E#+%G,M]&cn%Dp>Q/-:wX-/^%L(OK,<-9*J-)SI)T+4Pk.)N6.'5dCD(,BbNf<di*O'L9Bq%-2%Q/aTJ7/vZ-5f/U_?Q_<M0(td@E+DsH-)C6#(5;7SS/+aZ^7B?l(5cdDg<VBYN0xo=:vU%7S#(HqhLuQw9g4-W@,[M8f3ckY)4DPP8.F69u$k:v297'&#.k%AA4l/^I*DYr-4j:?O213IL2J*r_$2k&U`Oig87W3k5&X-r(E./OS7O8X1;ONM<LThA+g%SP[uf@V%GBS4&GBVIa+)%C+*]</<-N,Zd.&8E)#woH[$D4vr->;gF4mYUe$n]B.*LP1I$^x]_4'r[s$XjDE4+87<.U:>dM0@;H*W$5N'dL0+*pabP07DC00HHGA#vxr11w6)D+,au8%mWES(9[FU%9X':%EH8P<N:;Z#7_/*F'Xg$-)ncr/)RE?#3h-'58-'7/wJLB#$=P^$cO7W$<6#9%>gga<OS82'T#R90Lw`E[L,###fN,/LBtK^,dxl%=UTPt-4i$lL@`h)0&=_F*?7%s$M<Fn%d::gk'+p+M_Xqv-S,Jf3ldtG*^QM.0>m<87pKcr/uRki%NS;B#AemD4nU5C+F_8]=`dKq%3S@w#NAHT%NXK2'^Q#[$gEH??FFLd2iK9q%F]n>8Wma)+DClY%+ZPS/M--%-93dr/.7[>#Y'ff1]JE8&iFD;$aaYj'pAa+7<M`]?L#;4'gaNp1T*7G*BQ#T%W[$##,&P:vHjS(MTBR##HXI%#kd0'#8,3)#_=#+#TkP]4[S+jLSde5/nM#lLdGo5/d[1f)h;-$$9`Z=7x4V:%vl+G4cW1T%@6MG),qI5/-@XA#WO`v#&ur?#%S7C#ZB4J*jGv;%VH4Q/%wNQ$0Vu>#'Iec;mS1v#nYfYGf6BPSs(oV6cq-wp0D$<K0]u>#'I2c#rJKPS,P1v#C,Io#LZOVHBg_;$+US9CF&D=*?oGlLu#:1$<fS<n.eD78/GP>#^7E;$>Y6p%s/Qf%G,LA#uTd--'V75J.+a8%65+e#RT%fh.?VG#n:958V^&T%a*xf[&,###M0F`aPAUP&>7><.:E-)*:5sr9PfAuI6sUNt?9&ktt,HT.Y@u)4(Ue;$dcf;$jMjo]=[ooS4D1n%Yr?U%/r9A=S,18I]0<v5CW_tQLO]YcjfOa$0d[=FO^=;HsW[W$eB('#0n;%$YOI%b?L+DWvSU`3`-%##Iw%kVA&Ls$N]WF3b?xu-n$I1MHtE.3c?XA#Ov:u$PDRv$+G[C#I_89%jlwGVRkK(,2Pk.):M.GVYd72L:lo(4@@rv#^fx&GL*kp%#nB.j=Ojp.T.-%-Jlm92SxcD+2Hd9SY`J^+C-#N'=5C[0hYuu#586`aj%D`aw[BP8mT%##qT/<7dc)[K2VKF*KSD_&mEOA#`V?PJ&M:a4^NOf*kdCW-eE:ethtP,*]nr?#_2qB#CI;8.$`^F*85^F*9Men&gDqV(<aUv'W^w`%(fYiKl_2v#R':M'5n.k9hh%T1Eka;$OkW;$0Ux6&1%,j'_Icv,A*EV7O_Iw#T9XX$WAT:%`r&m&NlS60q-F<8mTc/2.F>N'aFg'+/NBK4a+F5&ukW@$QFH$&Xc]#,UG<E*tjTu$Ed.@#7]###$&###=98v#i]cf1@8d,*.R,gL1`Cu$?ArB#uWqhL5mMs-Xngx$/W8f3stC.3;@'E#G#vgl+AF.3=*AZ3QtwH+(7IA,E6PY>hU7<$LL:F*v[+i(lDQn&&*Bn/s:'k1E*hE#?g6R(g?:>?0ckQ'jo8'+;h3u-nbp'+Pge?$eK_^>,]lE*_:1hPQ:4a<f38N0tD-(#_[P+#Ist.#44B2#bQD4#]lP]4MFn8%x3vr-kZ*G4[`JD**^e`*R+AT.N)b.3sV/Cm'TS.GAK.IM`V@C#@IwD41uSfL$1<9/Z3f.*7MYS.4?3-*F/E4;x?lBA&RmRA8du_FFRDT/_4pL(nMTG.B&>c4<gg/)?<@IM8T*NL9Yl>#Clta$3S(v#MbEt$Bb[s$ZdtP&,V6p.RxXv,$_^p%k7>O2E#r&4?s&q%=pY^=OY+Z,dI@w#)cP>#juZw'mg7_8]L<9%[%7s$C-h8/]mK2'/.B$R:k:F&QWu/(67^H)M1I2Lv/Ke$Zkx2'$:ugL;]Yn0ekg`NKqhGDRC$(%9SlYuku1Z>o*72LB6wC#YXes$o5$E3`b-T.J4e8%#pY3'B9T011.9k13O=.%pL]=%L&h8/@5CW$fnllR8s't#]9rk%GNln&nRMT%^`%h(1ol##;Y9+'4CAJ10j3GD5-wbNNFU#$*GXV9Ss@a$f*eF>FCF+3GQR12_V8f3&cDo%wiWI),`>`.kGGA#%U[1MdxCT.e/ob4HcqlL*bn5/jB@1,s$i^%xZr%,mKn0#mkjp%gNo/1s4O**D*kT%txC(&o[x/(c,$N'+5-F%4P<qI7M#?)K4AU%2+hJ)f`rM1Z8Z;%_aU1(Sn@@#j.w<(Z(dWI*Vf_4&]vP/Ppc'&X_)D+^s#6&[%h##(&>uug5wK#Dh1$#_69s$kf98.hl_8%=V0f)MCr?#a',V/HS/)*P)(a49mcG*SSTa#`;E.3NY8a#]'%Ur+W8f3$t0<.]Xfm0TvPs-lY3a*Rkjp.[*'u$mHux'#.=G2wd]6aAIf<(S=6>#taFT%r,vN'l)_Q&%=m_+;bfM'.]Cv#tae=-rqQ9.dB49%I$:?-=gNJM+n7o[kMYb%MYl;-M@`9.0s48R6DSj0OL;R/)U8Z7<?Q.<Dq3t$+k]n/5`U;$4lL;$ueXi(D99U%d0Xp%SPC#GQVRV[Lmt;-'`q0%^feGV6Yuu#2Z4f_j:@]bh*.5/p(/x.4[lm'ZY?C#L8-+%Jeu8/)$fF4Hv5-(9_iCHd;Mo&oJ_Q&e_*X$8boj0Ysp:%p)*B+wOk.)Hp.T%^j-o#+<]IqPdUg(t'uq&hN/W$DBUH2QHKU%?=[S%K]3(M_65)3%2Puu:g-o#,XL7#fd0'#9veeM^f'E#g]vc%vBSP/V)ZA#9`x_47WnD*^t[s$,m+c4F2&v5Ku,Z&^p,n&4?/E+F%V52tW,F+`v^Q&Xb3(3/x.*);b/%#2@Wl&Mm&T&I[rX-FQxB/K&DL10ogd3&'hQ&l1N@$bB&r.`5YQ%3_+/(S8NM%`kfi'Y+pu,LIe22_T=SI7qv:Qh<YxX@L[(aoh>fhjc;F3Ai:8.6PL,N2IXD#FkYF%H*`hLClP<-`?S>-H-aB%]d6=.wHeF4r%`W-wO]E-@Jhv-+Kwa-N)G-;TK&<7dCXI)^mOv-C+%+OOCRURau?X.DR(<-e`/,Mk#0nL%MJE-B(mYu(o0^#$hgL.xS&B+Ww3t$GWeO]*r0B#C[*t$;ExP'UB;X-Nwv--D+QQ8k;wuQVgA,3Je:B#<M)aI9%6s-ZIo=B0k@&GvbSq)&19ba;%mca*8[w'3H6R&Xa96&tv:0(M4t>-q<qDNopB[Q#'_m&Z24CO`_3nL&`$##&&>uu<4>>#H*V$#mCS-<jt7J3w-;a4MV&E#YiWI)P3j;7d>qi',bZv,`,b/2DpCEMdQ>V->cxX[:_.D%Fer65T@Nuf)3(B-$aoH-;L1hL&j,t$9?6X7qUZt-Kh9G&ga_sd`WOv-t`U[MIwr<-'>cuu9^hR#F[pD337p*#7I?D*1h5N';f)T/CI?S'#34k1Nnpr6Z&PA#b>q:%tCBv-DcVe.IIV@,^Kxf$t^v)4.#jQ0S)ZA#K;gF4PNwV@t$7,=AsYx#G+`;$MTuJ(x[0T71PY>#Ko`]-qnn7n`:%97tv9H2e%bI)$%,.)[f0#&e_c;-:&i-2^S*T@V5do/m6Y44LG`?#e;*qeA$5/(64.<$$B3W%bBAj0HS?%bS=<2ql8#oLU@9`=dD24'9/83'UjgR)T`KkLbI<mLvGdo/p;7Mj>hX)#k,>>#M%p+M,(w*&3CQv$+nTb,C>%m-5I8X'aD&J3lk*H*g3gA=-L6_#N,]l'Sk39%EFVj9%q;Q/coAu%%aYp%ekAe4UQp6&ffwH)p6+9%@J.['L9Bq%c+(x,[3L-)8Pg34b^^p%<`qK*vXW0cr?.<0%kuN'PNGj'bE,j'IJpc$x5(6/&XL7#D[=oL69YI)B4r?#+o[_#<=YI)hk(,ARns/2_V8f3bP>s-^J$ZGTMWZ6m('J3XO_]?44)-*M&e)*LV<IdF^c5&mLka*GDQ'=A^Zp.3rF]#-6ns&EIM;$ovPJ(J-t9%LJ,B,pUv-4PWl>#Fe[s$w23[gp02%%HnA2'c-<6/jIMJ1H=G'fEbrU7WF,n&M+^m&dh3508_J2'`gZn*8'Id3qmT1;KZPR&[:1<-w9w2M,xX@t-Nsi9R:FD*i+;-m''PA#6bIb1k/OH*1pTv-eP))3cje&m_ILp$/<3E412eF<%To/1wa_U#7F39%NL=_R-,NsR8iC;$2boQ&5O=Wm+m9/'Zj#n&N%lZ,Ou69%=llx55.jY#$cM^4O(1a76HcJ_$<3X&_mgQ&xMLsdbhq]lq63j3j4SeN$&###0W$/Lu4er?l>,<.SZZd2YiWI)RJ))3Z3f.*`69u$[Yt03Bx;9/b-GK.u3YD#ic:E43+gm0C>^'/Jf@C#kK(E#ol^,3C^EFN_6kxF_T*:MeS&T,>vc#>FqjT%XEB:%V4P?,#m5:.&]5G*4+BPTdLt+3PZ+?-_0aY$f.n92ahNp%09_e*O3k5&n`R1(<*59%>^KpR@RHc*=@G&#0n;%$kS+##<rw.L[=PV-NO$##04cHZZ@[s$O+ENrk]0)2SP,G4tC,G4DMn;%xNh`NW0mo7AK8%-eS##-YJWo&@6g7/'^H6)FZ.L<`ekp%BG#W->LjC&;xuU:C(C5'NA8L(Z*'o<lFiIr6O830itnNOL,Y:vi>*L##*ChL3jVV$:tUhL^3Z[-d.<9/pk4D#]x8l'P,/J3T.m;$Sr6%bC:`;$SAV8&&*FiCCnnr'CX*9%LUw8%*.LB#N]kH;.HQ#@&bidai%6D<#1fu>Kt#??I3V?[LF3]-pf>W-@]S:)s)9W-OmprK;UuV&cCK,3Qe5H3_)7&4R6e--6J&/L)Qu-523Ko%M#J1gI6?KDC_39%^jJ3MPV:@MLs$F#JiuYu:D-b7Ph++Bj/am/Y`$5&WFA`&fNl/(PTjs%7`n`u_A9g%b5Q%bhuC`aRW@M9rd%##uqRT%A;aF3H<x;-i/=0&.d%H)px'F.7%G,M$(<9/7ja_$hx+G4]p5%-xdm--Q,Bf3/G>c4F`x_4P?L-)LhhU@AsI-)$mI4;.<7F%s`#[@qEd0)@&RJ2vVuo/a%h7TX-J@#AYS?5QHGN'e:T'+PX3Z'>C.=)[p.'59X54'sUO>Q+p/gLG_?C+MiMP0BiR_#D'x]%Pvs9)gP7w>EY6),^5>##)@?_#O*[0#EXI%#Rqbf(`&Iv-*Rlf%[>Rv$D(^C4-9]+4O&<+36@O;RR>]>hV]ROVlJ]Ni/nfI_ofY`5>hhN=RIhc=RV8'7=C^5'<kY6'nvtM*EFZi9P:hB#0YL7#?L7%#W'cH50-8x,?15jBVZPs.X*r-M+V@C#R9Pp.ikkj1niF0=L@<9/h?=g1EK(E#QuSfL_eVS.V5do/4qZB+cUU<-Nj*.)<OC>,2&Wm/C,fH)FJ@n&g.Fa*E<,n&W6fl)qRbm'o=J9&[tjP&8u@n9'[+A#pRCp0(#O=,keL@,9kl0L(<_s-/gi[.ks.hCVjv`*rxN7'oJo`$V>dV%_MHV%(#od)dt-lLVn[m-M]s^fl,<A+ers22+%Kk$o*'u$6Ou)4[+`Z-<)]L(:ap*%1lh8.75^+4Bsfe<4D,##N`RM1Ws;u/[75S-kZFU%lOs^u5N=D#eqZb<2p4N)59b7/q#FB,p.k+*.J6>#,_Fg1qi;'#&,5uuPE'Aba4X;.C5Vm/Vapi'cQ+,2C$mN`&@o79`ZlS/G2-<-=14J%Iej:8<OP8/3L$C#=kCv#FRwW$WCd2'*4$?$,@.JQs[qJ-kBX/>re;Z#h&#b%3<*Q+wOk.)It&T.>[<t$lfH=.4kX;$30o5'AU=BQ_p-Z(UqT1;UH/^5h5mj'v*AW;(lX&#Gq1oA9LUV&)Jl>#k%AA4a2.l'*0^]=?26q%OFrZ##Ge2032GJ&_^0q%:uq*%H>uu#38i20NB%%#m@*1#mjk<8viYA#R4r?#PCr?#m)t<:CI;8.s59m87UlS/t5Uj9*RYd389v;%Z8v?KT<SP/Xqaj0YNwb4`jp_,#TCD3pc&gLCJs?#;jgO9]FKdmo-_n'@%<9/UTpx#L?'m&EXRs$SKf[#/Yl>#(YP3'D_,12vR39%8bRg:;T=f4T-X_&>1#W6DjHN'%WQa3'H?:9stOu%TB9q%le'9&W:P$,$hk9%;B<Z6$g3(4Y:)39UNcvGI.Rs$E@es$C=)v#:32_Ahg)&+m:@W$l&9hGE=fBJ.%5w$TYs`'J<,3'3vdp%5ljp%_2<g,(4w]6C1';I$YIq.92g2Bs9a*.`SpU'C9Ka<Nl'L;,vd/(p%tE*,$sL)oT_V%Yp9<$><>A:<+iV$/oq;$-;e8%.=:B+/5###)55uu&e_S7Ve##,ts&/1>40;6D#Dm/hB/[#dsUO'mhB`$o)n>%%wb$eme)+(tfB.*0Zc8/5+V:7(tai(^tET%IhI[uv?%w#97@s$,AP>#twAq%7n7K:-@+&Y1v:HK:WS@)(e8?ZL?*D+Wwap%ivPR&T9'U%rOF.lw`@j#8N(SV5S&LQtIes.$WQXfwn&/L_Rq<%J*e%Fi)u4J+V-^P,nw*3sgD2/'H5<.9][KsWBo8%k,*M%8,g&?Uqb''k3-NK+$@L*pVPA#V9@+4JxohEobp>,7C8F,K)Oc4a*Ig)8vAh3xMI.<hVnH)eWL-)>H<`+6Dh:'?@e8%SrOv,GU7W$VE9q%uj1k'NNCg(U0Ss$='n;%9^A+.EPP$,-9dg()rMlCYb3X$W9#3'XW)32*LSkCAq/.GY68d323R'As$J@#3#[E3#4:r&A=49<i/l7'HU-%,oqX,MNiev$TW96&sYU#v*8x#/r<t,BwedIM/;s203`($#Pe[%#lj9'#a,>>#7btD#n,Y:.CiLs-?D,c4@DXI)W76J*Ql`$'M2d8/[4i8.uiB.*DomJ:?L(KCq[=+3v(tt?B=Us/DQ)@8(B87;##>Yu?'vNB8BPL)T0CG)'g;4'E:,J<_(Z7(9TnT0h>;@.A#iZ.<V(i)ucY%$v;6&4.$-Ak90V80ag3*,HA)9L='oK);-=Y-(7l0(8bb?.xAxK#)?U5%u1Y0&AS7C#Ree8._2qB#=f-N(MUI*R.X^:/x1gb*]%)<-xj?i$'[bt$=t?8'$SK/))pw6/_Jes.[Ul(NHwb9)RubF']gYn&-RRY6jJ24'/4K-)?;XGNgkA44_rL5&>4:;-kt&8@73i.3m#:u$X^%iLc?5H3gESP/-$Ff-pv3kOn=e8/MUgZ-NP,G4@Dn;%@-'T.dOhY,^hSV/4)V:%?1[s$-FlT`#>rB#3FS*/Ka.Z5WXTx$W=(<-Q)*E*E42?#)WSZPC_39%1_QC#>(f[#_1tE*ZCL<-5]c>#nUC_%2hOp%FaAF4Utb,2o+1U'ZO_s-[+G$,.+CJ)+i>ca9;Ht7.n9Q&`Dig(=HO-;?Y$9.dljE*Q[Ep%#IUN(J4Si1lqNf4*-l5&5?$3'2)do/*3g%#A)sG2H,78#^3=&#I2.l'X`D<%qs_0%9`Z=7%`JD*5-i]$Y?>V/3(W1']ggQ&VVP$,sIa1)BfFhUR<#K;[2vR&OdpOJq$,8IwmmJ;7A,I-px>)4M5Pm'd;[gL0x;Zu7qXJD<SF&#CM-T.R0;,#lu)J%M+3Q/&tB:%jCh8.qMg`%VdVa40e#;/.t`.3h3UC4jAqB#ef6<.?=Vs-ZFq8.*W8f33lt;9@r8Z5`'ikLZLG8.%J:',$6nn9l;Vg(Mh*T%uAP9%XA%h(47;X-DG%@'*6I/V`+Ow$u*qf)o?u`30M@q/JTc]#>O?)4:vKZ-V8G>##mFo$,qT&,i:8R3lk@w#bEK2'*7wMM*e(q<1Bed)5H+u%Z+2$-u3B6&&ZK&,DuEs%;Gd'ZfTNmL_;^%#KoA*#*b.-#U3>s'bDdc2C=rkL;/E.3sZQp-:b%njnkkj1D4NT/Q]4R*vn@8%[YWI)apd)*'4h0,*d0<7`m(AXwesD#HYt/2fPXV-v0d%5TL52(_fiakZq%j0w+Is$XO:@,urQ$$wAR3'I2jA+Z_p,3fp?T.9%`;$b5q#$=1K('@v<o$h@O/2ho.21R@ml/[q[p.K%.<$n-1,)<tJj0nr3c#?*#j'jfIi1k`ah%&'OZ#'4Qv$(F0F&I;G##G_Oj0l&U'#S7p*#mp@.*f<Jp7`fHZ$lT&],@,h;-+$+,Na9j?#&kw]OSttD#%H3'5Cc@%bDOOk0>v,m&jTR&,0#TDX63o5'733FN@$+r.2VOS7j;a-69+O01;p?d)C1M@,C;wE3?()t-49*'OC'f:.j/G&##(Qv$BOq@IfTE$#hpB'#JoA*#hb5A4fL^Dl']7C#MPsD#iPcD4X:Z<-ojE?P,rVu7<e/9]v+bS79%`;$)V>W--/.A';X0A'`l^1P1lN+Px3&v7A.#*=WdA#G^(ffLRqVv#E?UiqW0i$5*P(vu;m6o#&_U7#-oA*#&Ur,#ZG_/#J%^H+r[`V$lJ@d)0xJ=%fpQ11t:*x-^No8%%7gx$diw^$he7W$oB^@-wmDB%sABS8,IJ2)1G8fL4fu>#t:iZ#<d#9%;4bP&HR&?$PSZ/;H/5u%1QA&,Z<8PB60B7/$P#C+glCQC$Rg%'hOj304%=`#O-S[#61`4Fw_JF+nlaA+e6(p&0F;D+m'A%uE_aS8JQ_s-#as[tn;@DNq1`c2&-ViB0[v:Q_tu,*aU)Q/?7mg)l/Y)<B'D9/&_<c4Jc7C#-X>j0m#:u$QaD.36pdA4r>R,2],Qv$_Z-H);cJD*wg,V/Y&'^XA2I&465k3(Bb+2Kbc%5';+.<$4i_;$v%.cVAH63'npcj'-h>F#?e/m&;Fe8%0eO5&D<5j'v0OT8MZ$o#HgY7&7IWP&@JlY#f:Nu.SIrV$k%G;*f8eS#j9gvJ#CQF'UdGN'BeEp%[]u[0Y,aC.mObi(pAVfL(iI9.?BHtLg-lJ('*.].Z=.s$lbffLZ6<Z#QIV;$;:`Z#QGR1(Nal5pTS]p%)D'i<wOO&#Hk+w$)B62't;Yc2+n^o@K.h%FG;'##js:t%(VFb3J^D.35qB:%bD6C#NSGx6K[vLMg?j?#`htX(T?ng)K9;8*MsHA4oQW@,bF]fLD1h%%_kL'()Ic(7$2<,)a'49%Tx:?#<<@H3Lq_b=.nSM3EqXt.?O5F%DN`'>V@Rm/lURW$bsdD466DI2W5Sh2qs`N(fU&Y.xfAa';^A_%?fh;-%vtg0AuU;$SXQ@)72^kLj?*?#9OM:m/XQg)VvC,)GH]49YFI`>F/Bm(Ft/6&,u9X6f,c;HKNkA#D)>593=`qSajuj'Yj,r%u@fP'Ax$W$_(:@/s<T6&ML2MM2C%q.7xq;$1emdb9iD'#;8E)#n,>>#^7^F*jpB:%?@i?#AKA_%:G>c4S#,H3Di^F*RuDe-v6(f<BZuS/Z,LW.3Yr_,d0]T%RS7C#K)'J3moGuutWo<$jH0=8:AD(=)Hac-?;P>#ViZ;$8YC;$:q4v#?lE@;95k0E_Z`:3qe>C+c9xS%@O<p%7i1?#d]4pL&LJ<$+eemL_E+Y-4=<N2+/058*2.w#r;GA#5D>YuMEw]-+gq_datFX?dJf?$?UWp%-GY##F$sqKa<w##@>N)#$=M,#KI?D*8^ZjDY13C=af,g)=Wk;-OE:-/doJK2xSFe-2Fh^#u3YD#$WMV?L@Ib4[.5I)QNv)4-<Tv-M):I$WHSP/Vl6g)ir;J8B6fY-ENx*m@2oiLj^pZ5-?>40SQ9q%ZWk]#234Q'Dv7iLe(4[?V5do/3V$%M+M34'I@%s$eEO=$8964':OclA3*Nb$1irf[=(;?#[,q8/*t+`6P=HlL#<Cq%3`H>#;8ip.e;s7/)rI9gYEKB-_=ClLicfh(t:8l'jlP-)&_#x%6N+##m09j0Q6F`a2wRc;%ro,3TlCs-c3q+MJf4c4)O`t(ZU&T.hZ*G4HU`91b2Hj'D7S/:$pH#6xGR7As7eC#j1%<$68[s$(r9x5?*G/(Kt`mLMNLnJi@R[-dTP3'`ZXt$H^&o8`gG/($(cn0N_Hu6?d)B4>w,mSD%T2BT5_SI(YBp77Xg$-BxO**(fBf)9YwTI?;G#-u#.L(_1R[-6j)#5<es6/&DJfLZ'@##[*Zr#``V4#(8E)#)->>#'TMV?_hc8/mi12WIR^C4+P-AP.D;&PCttl&bmfx%ZTXp%:;DwSo41mTC;#UMm+^j2=1]b%h(sb,W*xq$&N`)3Jrn-%/mWCQC_39%=Yb_&KorQMO-=IHWA=<H/M@6/3eWC$3^+MM)r6u:`u#E*VYr$'M&N-)&du'&.LvA5f:,Z$M:hEkGS2GVNrkr-^xhx=pLF9r+bQ;@<$$Z$rp;t)0)0A%M+]OToE%9*Z^A.*dsUO'%c7C#vs'Q91P3Z6(COUIA`Zp.Y@H;-MW1?8Nt'duh^L;$TC[S%Pg0>$A'bX$F&*a*F]u>#@hMs*lj^p%EBAx,'O49%T83aa0gv5/]8HN'=r(?#;gp;8d[B_#HvD&+F<t=$ANUG)HY(Z#C%M;$ZiXtZG`d'&S%rR/oQ'd2%n;Y9&Cd;%0*)t-jkn,;1xW3LIDmi'r)#,2kN%##--l,OQ8#s'Jr>a*<:as-5(Xg;8%^G3_5,W-:T`LLB2eg#P)I9M<aG;-*,MHGAv^C6E_o]64*;s/V+mC+Yobm1^ok#/8<H+<oc%pAI$M(&#q<]IQ75R0ElCZ@=EK88>qcca&VNJ%#06s7lPkX]q1Fa*/xFE3+gB.*n4^+4=Z8f39`p>,SiWI))OF)<bJ]manuCSIN<XW-gc3eHW=rKGPg*32Ng4',o<:h(:ppj(Q9Bq%KZj1M&Sd3)(f>C+'$;-3&4@g2F.:$g[2v92EKhba.+CJ)E4hZ-IQIl'=dtm'rkcN%:W5^=@WJ2`5VIeMor0h$nS2GVnZai0/h7E5CbXD#EaoA,7iv[-90c5/<DtM(p-_fL/4(f)NNXA#>)P]FL;h^#bj*.)sGB@MBjSW7N1D?#:G***sTAe$?uu>#-c%[uOW@g:g5>b%T<FT%fe+9%HVLHMTVY8..:9U%wpLY7U4c#%P^U,)u3/9%S>AjKTs>V%f)vW%i+O$%8vaS7'7*/1S6KeOmOVE/&Ql8/KNE/MV<j?#b2;]$DV>c4Bl$],+.`5/dbL+*]**>P;IK>cXv1)3=Ce8%KFs50?tOh#Lb)h)BRes$,DKB+k>ZG,0x_5/jYg^+I(2&Pe=f21Fr8e*t=ns$S..<$/E7iLmo?3'U4u;-7iC;$IF*p%ZN#V%-I2W%wxG`/r+`c`ArJfLY*euu8dqR#iXL7#@R@%#0>N)#-$jP%0)K+*YCh8.Fe75/YcJD*FMbI)KH09.G,;u$<`o/1BkY)4RWgf1-R$v,VxG=7)j)M8H>'32*;]W$]GeH)q5cp%2>2s1qttq&ZxSw5i'))+2P#N'#w?JV;4lQ'jFoP'RIqZ/&v=;-<C712eFUh/daXT%Dqh^+#&bI3xM/W604'6&CWB?-a@W8&%](w,%Sc$,oYUY$*hM`+<ABe=>`:%MG3A(#J]&*#ogwX-PP,G4jTC0%3jic)a(3:g5bgx$nxY`%n+]]4*kH)4mYo_>N#b>-a6<b$U%6+v5$Hq&`.?C%mp'H2t,+jLc)vV-g7pfL(F?_+Get.LhGi7@uS?T.]MAC+eW+A#o5IrA]PwS@Z8Z;%ENo*5<#PY-Y:Bp&O?,3';bEN0q/Y=$Vt/H+^2SVM-gq@-.2=i%TDluu001n#*kh7#BL7%#U;x-#>->>#D)MT/S&Du$,H#g1`V&J3Di^F*g&fTi@)CR'3eUa4m#:u$i.<9/i2c'&2MbI)0uY<-'Dg;-$-UW.<E6C#/rY<-LfG<-Fb0)M1,V:%iL0+*s9uD#/Y<9/FV'f)(LE33-qYF#7xBJ)&VXY/GLNrR-tkP&O'Ft$b<Sv3OQgQ&,&2X.@b2M)D3pM'EW4336`xH)O;bG4(f,(+N9Ts$7?oE+E&Fn'C4rZ#PpJx,6MHb%mM+N9#J*A-<@R<$G`u4gV5do/Eda=&oo7L(U4)ZuxWP42CBQT0nulT8UqOe<W<dS-s7@W$r$D`+V:^r%7.i?#xkT'+x(8p&52Wm/WN%PBdZ?V%F=[s$?eFt$wVAj2Ij-H)'E6_-NV=I)fZkG2LZ$v$'VBh4hF$##&&>uu1:G>#Y;F&#K1g*#$2QA#W?+W-=rf;gF:=+3FH7l1Juk/MU#qS/*_Aj0LNv)4]m3j12Urt-9e-AOSY'gMKqml5eJ+<6`GhX'voQN'SWAY%]>7L(.@Y/%Z8Z;%t8[@BCe<9%+*`['`o$^=l(%<$%500C$[;v%q2CgsSQ^6&i^r%,b,DO'oYZ*3%'s4%_pw5&uh]gO8=ns$$vdqAOg.A%wr7Z51;e8%X^t5&Y&kca(7ni0Evv%+Zt$##&ctM(cei;-NA9j%w=PjL/TIp.(tN*c,nIm%^CE(&x2$I%CZ59%no'HMKvX`<=cOo7^+6LM^4eTM^N&@#Pd1*MDJ^ZN;-)WdnYtJ2YGfJPg][`*A-GTR9Ww[-u?lD#m>:Z-Q(DK-YE4g$6D`p%`7xR8urKATf,pXuG8-m&]Err-$6BJ14Ar%4L3DP8:E-)*$i5m8cp_E4jhtD#aGUv-u4E=(w%AA4P)V:%i@+w$&mm]4<i&E#_YUa4Xbx:/QRPn*,l[s$8q,[+&:G%XOW,7&]tJm&Br6t$NQgq%&=>gL3(f;%w;gr.kmNRUec@1(f*/2-G:j1-Ww`xL`WL+=rRx9&^*av#ji-s$93)>I(>W/(0q^u$x:;S&Le*=$9LLB+-D*f2Lpnr6jLN`u)?qj(LH:&45F60)]11h16Xg^'Utw8%4>###6?9-m[n;##&,jB,ML$##Jn@8%6f4$ghg$H)B(c_$9hv1)e/ob4s=pr6R+h.*#R+,2cx=c4nRMM0Gc4i(JiXV&ja0d2sx3=$4VrQ3E*Bm&*[B`=xGrg*o<,W%7q<B,nkc,*B@.0)Q/.n&kv'd2#PNp%>1@8%k_&Q&D9M/)pbu?,xD2W%)mxc*N&mD/-,Y:vjtRfLs/W'#T=#+#3b.-#hxQ0#JwP3#Itgo.l5MG))HG'ZaB3mLoMXD#4;Q`%-a(Q/BsMF340_:%m2Gt-*F,gL'%2x5i_T%%0FY=?GE<=(+WA+44x8KmEvNbNPPrB#x.TF*lf-F%_#q?9n5jG-`YhV$=fYYu/r@@#^Tcn&>mZp%4>,##1xRpA8nI[#Ff,p%qoN0t]W49%J2VC&W#fta`eV=-qVh<.hV?g%5p(d*dvaJ2+$%79:AtA%O^U,)@,1W$xVvQ86Y/W79pJcNq^:-OIp)F&k3.d*l#><-9XEB/oxET%<32mN``[iNak$##'&>uu54>>#NN7%#9Pj)#+e?S@VRN/2enRAeG(<9/cH1P:JiE#-JR3Y$nnr?#$rh8.rsI,M//)69U?d;%ppj3&[xvY'Z_7%-Z:WN'$*olBSJN&+]]*b-+=/$l]lH4(T3N&+h`I*-e,_6&fUgQ&]PC(&W3;O+gv,mB@r*cNU&l?-'i2=-eQ]b-(g8UDJ93UDuu[fLVcCaN8,%##'/5uuH,A58xNWS%?-,/(*xBP8Gf98.]e?']A.Ip.qP/J3BO9]$Vq'E#GqA8%&U2QA$Wt1<(vJTA]Oo/1unDZ#2fClBLtn@#-Y?eKjF'PKjLip%LE9m&b8%DaC_39%d*49%RiuYu:X5W-?:':)j4)Z#HV=;-n)h^%4n.1#g1KmA96ebl*@i*8j.ge$HX'44]2oiLds78%ro$4Lv6[V$H;sx+2x+87%b#5AC>tv$aDsI3Z)i1.1Xp+MXa9x$'M<9/a1[s$W?iwg$K@d)jq(%IG5;P-%9@Y%jx=c4H),J*Zj:9/I)MT/[YWI)JI]C#:;.Y6OAgN+^;-n&X0n`*#]15/`E9Q&=)>HNM$8>4@7oLlkCPd3SQev8]XC/)X5dN'<W8<77rWF3kG2;?(1_Tr.kms6j>`fLn%,.)oTex,N@)w&F;Re4(6B4tSQ/pA=cV#A''Y72Y@ZkgAo.;%](K`$QpKR/'`UNt$i''#QYr.L2Cp*-S_j=.?Dh.$Sggs-3?-/EP;,H34tFA#RGHs-X[sMMK`f@%mp'H2_bh&lkIA=%6xmo%8%KgL2kAGMe^&l9DN=_/q3n0#f*axFiSXFbCOgr6#07JCbdXoIiB?S'X5MG)e[EgX6[XD#[q'E#Vsg*%WV#+Hk[Zx6l])]$Jn=Q/P&Du$N`0i)+Ye+>(I1N(:tu;._OgfL6?Dk?0+Y^&(br8.mGUv-jUKF*P7sv'/u]G3i6$h(?hl>YdD24'us9q%d__<-<(Is$G:rZ#Y-'m&G;>^$W>?v$A47<$gEIA,(@dK)OXN-):R84'ik:((bn'hL$nVL)QNv`4hI*A-,Ug@4iv,n&YFP/&i@9f)_G(;$_5dR&7`[-)I4D<'cg,3'^P<E*CZ;E-7cb$/En8W$j5EtCRNrhLl'#X$]V*i(ORD)BJVl0LN?;B#oe#nA8/ST%)85$,hX(712E_H2NtaT%<kAQ&n.e_#$voXugd(,Mwt8>5L'do7iu7#%>lm=7uNi8.Ff@C#WG<g1a&PA#aY?C#kHuD#,^4Y@d5Gb%>>%Q/YG+G4C(=V/h^Np@(m`iK-Rke%Ha1k'n?W?#T.TH)T*Ls/nN2-*H4Vv#-Rev#nOb**D(1+*M$vR&*:RE*UddI)@YJ1(Dw_<)5=)8Gg+e9%vM#T%aKOp%7H@U/e<mj1Fuqs$?(p6*W1V8%NhNp%#?'v/%B.<$:kxS%CB)$?^oqs$xRYi9<EVk15D$##$&P:v_@P>#*6i$#9,>>#vU`v#x&9Z-FkRP/aS&J3,<xX-'$d-)r%wf(=k>.qdNfw#*$ik'I*2]O(2ED#<aMZuKk.P'[-&@#BldU7=W;r7&bbmB(I;VQ1mc'=#16Z$C$L5Wx8tV$g(]]4jwRu-g7+gLpeXI)SSjTB:q'E#sJ))34G5s-nM#lLdDe:&O*GXptq0+*]wt#-XsFA#d&g*%do@A4d'DeMruqv-/ugt6K%Vv-O;em0rT81_C5hw0PR(f)BA$vLPgtA#X/6G#HH'#$Sju/(Fu_v#kIvl/I3bX$SmP7&8%iV$u-l3+/TiS&];6?$UrX;-8.%w#m0L-Mh81q%W0]8%Yrv[bUfu>%r3Y4K+7l4'KEgq%%xFq&l/hQ&7Dt**cmB:%k&bZMxKKh=`AM;$o_W-?cjXp%D1Q>#BRj5&Jb[8%TbNT%S09U%7IWP&=CIs$BREp%;I<p%c&9I$k*gm&Y&h>$9L&t$aCofL/hD<%ZbsXc;_F[$o.JT&lU^B+qSrK(>fY##%/5##0#od#D<F&#Mf.)=b8^G3DWBn8^]HG$+xQxkIPv29?+o?R0=LmXrVcxuqv5V#kxc;-niHI%#f]3ir[=.)naeDN7r@QMQLkB-vbKhOO;^gLZQZY#0gtF`^(D+b,s:D3:E-)*M7%s$b(^F*MFn8%dZ/I$+^Q_#[C[x6&rU5/Hi^F*rY5lL:/^I*sj>T%RJ64&js4T%Q5-X$v@oH)I4D;$sVph=:v^7/Se@s$J59M)>m9w#&1U^+^>4A<P[45T7>s20g[/m&%#^_4_Cr;$3k%*+eVwLEd7d>#gDVO'g<#N'LI]s$douYuJ^8R3O,GuuY'Qr#vXM4#/f2i-kaL3X._E@&e0f$7Kq@8%kE>V/2Of@#G*vV-hj3X$A<rS.&1U?/b]`V2-3#6B7=D&/@Iwn$@akgDv>v;%hnfAQhMbh+M7$##(8P:vN?'Ab[=`rH8B&W7QRsF,eGse3aIcI)QbADZcZ]s$^tn8%?@i?#4/)(&aOu)48Zkv6pI>c4Zj:9/)u6lLbP,D/#r[s$*r+gL@.8C#SP,G4er)T/1_v)4u<7f39Aw]-aZ3[9fWR$9MsgKlk2d=pK(_gM+Yf`*L5*E*SR7w#;:R8%GH6u%Q1mY#]1^F*xhnB5SL+wlLpH)*S^nb4;Wxt%B-gQ&E0tp%.ZHa3n(`v#GM)H*omd.MR.N`?DwPm8BP_=%:rH8%^xWE*L7`?#UQ'Q&I-u[$;.I8%_%ka*Qh<t$1XV#PMma_5[fS#,=_W9%oc[H)QP3.)04*v#<R[W$Vq@:.-8###TYDm/Eu;]b4MR]4q4*j$R4vr-'2h8.lwkj1:7%s$qSID*l#:u$6I5ZGgc``3NY&E#8-U:%a?Bu$;X^:/abI@#f/1h1'eQ4(4b$c*'XW?#?CR<$9%ax-$Qeh(@P.1(00Swdn/hH2+&7;%#4vN'#jdS)qG-3'TCD)+8R/m&q858/3Pl7(^26'=Ucr(69#Z5&:WI)*iIHlLBMoH)$,Guuf#q,d:d7iL_38s$w?S8%/[iUN/o.$$)%x[-moGuu5/i?#L'(m&$p9I$mo=jLr]&&?Kq%@#]#A@#De`w$CqBFZ%N$LcjdrEK@0lf(dQJ%#+Sl##[*Zr#ZA)4#4f1$#FF.%#hd0'#dcGlL3rih)b]DD3?IE:.upw,*TLB(43$L:%r50i)jAqB#G+Fj1SBo8%_`7&4%CFA#pW;E4ml2T%O`PS7e^HQKWA`,BJTd)G*9fB85@g`W9qmH-<.OS9w`04LYUh?'cCM+5WU&_Kp?r?LWcYQ+642e6r19h(Or@@#Y<=;.9-x,vN0GO''m>554H&w/%2Puu1dqR#5.$&MMLpo8BwiX.R4r?#%Zkv6Z)YA#WmkxFY8W`[lK?JCT$f0:,,]R'JYv<'18i<H.^4u%%aYp%r+'M)@3LPC9t%5La+:B%fQ&%#X7'0%(<jk(g6(:)i?uD#S$]I*7PYS.x3vr-g5Wm$eBm;&qHRF4TMrB##_5g(W@<5&Kh.[#7)bfM>hO7Me?xS%#-YU%So$:81`T$5mS4'5`EjxF.+CJ)&tn*+<IK=%r$?,*LDh*%0F6Z$p.e[']RDZ@H1IlLE;J-)$i4',X=Er4A=+VdP[LYPI2<A+u2#,2'.Pd3lHuD#(1]5/%5K+*QQA#GFlP,*twO<%F]hv-iBuD#qd8x,@hR@#;EW($D'rE4Ku?)a+v6s$jrjx$9u$P)Bq3',9'CT.q_`p%:[Xw$Vmd=/SlD1LPfX;-xQu5&P@k2'fM1#$nPL$'p.SN10p?7&81KE-[+J/L1<Y<UQ5###3Ya.qR;UwTH6^f1BLgr65oI-*`ni?#@,<+3U4/+/uid8/X<0CS]5d8/+gB.*b,Qv$a&SF4H;*x'V2Q`,fhNt$el_V$FDxA(Y>tjLc9V2:-'Vg%Gsu5&fRJx$(9'_,htgfQtHo(TV&`pEe<+.)4vZL.,$=Z#lsNmL&kv:&.2i2'K-x<$ej+B&Ebf?$,v43)I;r63RiAT#%#ukLQ`$]-D,%hcNAP##[j6o#D%a5/[pB'#ME2;9)%_>$wil/)-h7e*H[sp.Vq'E#EK'nj&LdRA]eld3]L?Z,W5MG)>L+Z6`w[t1?1b:/OYDB#?t6^4+IGn&M<CH2)[_r&iuiw$NAYf*?,,uur?Ma3w-vn&QE>N'@%SN']xJ'+2r<D#WCjJNR.5%t_'<@&]67HDgkd<*I$]w#HB99%'dLQ/-:3e)%$UN'-w*Q':6Sh#5hO]#6>uu#8A6`a<G?`aRK`l8lQ%##m@ie$7DXI)G$5N'[KA8%G`#gLcI^I*3h;E4$jVD3Z,#d3NAQ#6C#ORUYEtQ)XIF<%n=+E*1S>$&L&b=&KX*t$P6[DEd1P_+Xh%[#Wh-c$K;<E*1q/30X&Ox%NI/3'5TKa<.E28&A0CH2YW9%kQa.F#(jMt8w&np%#E.60(`8p&Gnv`EJbA2'<B@iL^U%c$B=*T%G<^q%5ZV6MOX>:&-Bd',b=Gx%51k99F9`Q:Qa>=4,<Cn#<^U7#q]Q(#xPUV$L@[s$EwsHX]sv)4+gB.*-<Tv-5x>K)qIRW>w-Kw6gPwh2$X'H2]q.[#hDXj1378C#YR^k$HKRC#d+I8%Y[8q([h<X$u0;,),)d=414GB$U&?v$u8[@B9uU;$R,$5Jc58F%41]8%e*&G5B_39%RnEv']7Y;-Z.bL5QgX;Hmt#1/mVa]+e_>e6=x@Q/3iCv#TsEK#Cs]A$fs?G=X1l;-Z8:sH'/###fK#/LG262'Ij_c)R8N&#>Tg0'w3C(4kR2.N?IPS7NgAE+dpo7/u,u3Lxe9B##/g[u`o[U.0;`TVN,CM9<]*l=8/pu,q^EM018r%4i`Db3WVJD*6BOr$5ewLMT4^:/o<b]#Q(7]6=RH=04(XD#aBfX-%FT'JA[e5/Yu/qM9+?l7Y#V<-Ye'IVk_AW7$&5>#jxc<-LKn*.<LB@M#Rqh7rwAW7Y#44'IrYW-M5.F%GW'%#xVW@tsubcalqU<%d*el/O/5D<3-59.=R(f)5]B,Me3TF4qG,J*Zk[s$Fe75/:N.)*mg8x,/O@q.iE(E#iD9F.otr?#NjeqJfb[F469ZlJV5do/*ECq%f7LB%jU4gL_V-_u5beW$lbXQ'@6vR&bSkW6U-QV@c5qq%1j*.)-?Rf)5*J>#FV>C+EDh[#e1@`a>MA),ZJg#&dYmr%QHGN'M3pM'2_2n8@nvm8F#UT%o[i/)Gxm&Me^<1)S/[]-]'w<:[TbO))li$#%)5uuDt95AvD,W.xX;-mRdo;-W(FN.`ovs.Sx<g14qVa4c9OA#axJ+*jeTfL)u[;5G`TF*qd8x,RWTM'%e75/4Ob,2R)LB#K^Hk%1Cb9%2PSL(TRrs$e<,Zcdi)Y$r[Aw#U#N4+-Q5iTFSuY#j7od)V'HJ2&RCr&^JMo&'in8%NF-1)5dU?[lIE`u)]B:%k(tP$SU7W$14BL*Vw,q&:06U9J=)?#NP`;$A^?d)0HO>-@xWF3uO>c*X5vr%:YS?5XI;$#E->j0'_A`aX-]f1_Vp(<5R[,3>c,B?fifF4MK?I2q)`vHnw]G3QVCn'k(TF4h:=V/j:2mLOjs?#gmTD3;*YA#cE'>.Of&>%.,eQMF(9X)#Q5]ujjuN';RF`#a'jm/Iv2T%@MJ-)Ls[<&7/n@>w0np.sHaQ/&H4f*@&t**XV:Y--:@=-+rnW$kq*eW.sUP0Thi?#>1<5&&&Wm/bmpU%pPwt-nWHW%R55Yuk&17&WPGp+e9uM0r/5##[*Zr#F1Qn=Mils.O@i?#g/8fPkc8f3dE/<7AJ:r.27F,%*a[D*TmCSCkAsQ.vqGg);4Ha3_TIg)U78C#Tke]#nMp@u9njp%>b8Q&P<pm&M?pm&]tO-)lu<.)Mtvc*R>K[6CWp7/weOU%CV_W7/xaE44U=B,kNl/(LK#R&Gks5&SET6&HZBC+go&F*G>.21fv3V7<RxpA9KIL2-t339s4pr-Sf[+M,tJfLm`/%#o2IPDpBkKPJV*w$a%NT/l1f]4v+6f*x+7Z-]#:7LHft/MIskD<dEDH*V?(E#fii^omo#f*Y7vc*FC9N0,GcY#^5qu$]AXb*%Q,=-$Km1/U>[h(G/mank99U%Jx_Z#;M#<-BF:h2APsGZ<WE%$FpHd)C[^l:n?X49M['N(,p&UDrR$Y%Oljp%&kkp%M+IT%R_a;$=fDpR/^[`*s#_m/?jh7#pnA*#asIa-jTs?#^4K+*1j]iL,ei8.c%*9/ZktD#0[7x,*1ip.$s%&4(G-jF6UiX-2Vo6*ln@8%Na*<%$h'u$+N[8/jtu1%.bk$>eAr:%O]3t?^/%-)L^CK(SOVZuAcx<$SE==$flvv$CEG3'w$rN(c#$v$d8Uu$U6Df)TPwS%7Sv2T+a`?>0ebi$?a.3%c*Ba,7WbiC`/6Z$L'HZ%?ctcMl``g(KKcj'C[n8%ecE&+QlOe)&YF[5[QbT%+2iU%TBM^+?F0O1fm9Y$)TRV6R]I?pe>P:v=3sY#:cmx=9mr.CY-&;H*i+DN:E-)*JREK)w=XI)wi$i$@4vr-A:G<q79w)45Ulj1Nnpr6*o[w'lU'v5mna8.b+^C4ox>d3&?JIM633M2d;Qp%v+h.*R>1IXqYb*ETNYD4p@%b4>U^:/uiWI)?:0u(]hHuucq^DNQ>)W%/R(3(f0,4'Eow?$`U)W$.fUv#TNtx#@-G/(u6lu%$6Mf<VLlgL+F5gL*/ru$hfP=lQHGN'4>_e$8.0i#<L1hL[3/<$:61V%FN2w$k+3D#;[A2'[9Lk1LUkT%8oC<7#e5n&lF<T%@I7W$RpB>$8:*p%ZhH>#q7p^+2>l(5>>Wo&KxG>#kkjp%U*sZ#22TKM5YfRnZ>u`4$wiG<@EJb.aqWt$ge.u-*9,>>FjYca=p9n'Y+pu,4EZlAO%[oV(H;f<,@)'mq#iLju+M8Iohl8/ujb59SMl)4#,]]4I9C)&/N.)*T9@+4#&AA463_^=L+LB#TRoU/QIHu@l4dK)D`.S)bDVO'u=/T%r@6T.H9tX$./%60us`m1>;u98*@v$,x[BJ)/CLE<b*4t.^b/.*i02H*^%g;J'I*%,Sc5>#j*C2:6JAj#uw&r2*W92)o.v98'H-o/en*Q)5A,%,g`M3'#7US0cYm-*vweA#cpoMV<ggo/9/K;-VB=g$,4wK#,B%%#C,>>#26MG)<=_hLS,+Z6xck-$'C9u.Sb^;.OL@6/[60n&w2HlL^HW?#M5;Zu*EV?#MCi9.ZKx;mL(72L-PNh#=c[m/fXL7#$K6(#`&xY/1P'f)[/*E*Xs^5/=E6C#vL6Y@sE-Z$%uU5%>4vr-le.b%PMu<-?EY=$mkUC(#t+o/4$u9%=r(?#/g(T.4C8H2?pdY5sVtI=&9(;Ql6w*3=QBq'XN8k9,PG1)A-n,DDO`d*SQu/(q#1UgXnduu:g-o#Dv$8#?,KkL.,u)#swbI)[(Ls-STnj5wx2T/HcTF*XQpR/D&;9/[`JD*R4r?#R`>lLuG:u$rO8U)j,wD*X8M&=Clp58ei)'4x:MWH^E<EE-N^5L9rQO(n#HB=^.2M:WxqV$^023;@R*p%)u#(+F=&H%IAw'4jjPgHhVnH)9hdZ,FHZgLpR,L2dX,b78tt[&vba%$N)6b+Pt]M'mXgW&'/R8%jHZi(^RJD=Fl39)*Ik3T5:wx-dp]uG'uK^#AQ=8%dK+<-vDu%&?v:u$w.gg6<nVs-ax;9/A<3E4<TIg)qv@+4m^=?-0YDu$Hw*F+wOk.)G<n8%.4O-)nxrIL<VfX[fN&m&54[s$`;bYuCM/##pNqvAV0([-V`q921pr4'u(cY@R3^CMV@nM0oT5t$^<<h#YbEQMfX>;-C::tUH/5##7'd1%vfou,)Whr?IeK/)6*0<-kq(p$1=mg3-_]?M/*NS0*rp/))g.Z5i.i%,92ao0o6j'Ph6MRNHIf'9]8H]u0CtY/EPJ^HF4&q/8mKNMmoQ:v'n$p7gJ,/1&-&##sIR8%]?[Ku<p3M2[C[x64EHj0P4n8%K05N'gM:u$^$:v--twP''`uS.HXX/2H>69/IQ:a#v?$gLf^YHjmu%P'W17W.[RQT.ir;*,L)%1(c%%`,_-'6&'-O^,K9K7/tB=9%J$f@#ATv501o;*,vG5s.:d^F.xV<**jS%h(]?.E3j?[=-IPa'4+h1h(NZhG)7i^^+`ZS@#B8dT%MT+',b096&tpn&,a`AB+Al=.)BqEJiUDcm'mZ102SvK8/B-^Q&/kHeMLwQ,*h-[X-x1-<-5Lco.lP?(#t1T<9#j7d)Fr%eO3XkD#dMi-%Tr-W-9E/lB4Eu]u<-PY%`%,)NOHu#+r@[=-;Q4K2C_R=lNPbi($),##;j6o#LvgK-ELI6/5Hrc)Xl;g;dhk,21]R_#oe+D#<gj::KOhf)t4Ex'pr[1(:.E`ax$SD,Z.6>#dD24'<6cj'A-cJEGr,LENF?>##[u##Z<J)45Pk$%`._Y,*#?s.jFf_#BODZu/r@@##g0guCN#V%Jw6XM6=^h$5<GO%&>uu#l-f5/J0`$#pn.nLi(&],&r:=:hP))3tlI&4]Lp+M3aoA,xck-$t?&t-B3+.DwTW/2-mDThfV8f3=Ha.3<&/k;[Ob1B8iC;$0kIa5t@Sk$Hke8%om%p$tg`S$NC].*-8,##Z$W?#5.jY#Kmjp%<hV>#QVGt&B@j8%KE0Y$#6vfL*+`p.nRVYl]nKdk@-jf:3e&K2/Z,F<)/?v$$?[d&7Hf0E^3NZ#Z5qu$Kf4HP&4^QEli%d)CXKP:`VM(SA6#q.WWt&#l^s.beca2%*c7%-$>`:%@=.s$9[q^#[cJD*Jk=V/3@1B#8V1]twm5g1OxmD*;x(Z#_Di7)exSt98JdkCr8,CFIsU6&$#;Z#;T=?#Fak;.Oa82^4P3GsQan;%lqu'8?vIj+onZSJU)bs%3j5##veg>$RH-obe4mT8&n<^,L/e`*(UC>-stT%%^0R((S7l0/PRR),v$;/:[,p=-0N,f*5_GX-3,mF<DprB6bgb1'QG+m'eAtD+'Q::%2Q4f*HBHX-BSo34@tae$5@)$nJ6Y[$$4wK#Dh1$#WL@79$%t$Q0a*(GhX_C#%KCm4OCNl<]8RBoLGY##5k>1%#9W]+$B#,2DX,87%ro,3FHaB%''SN<fj'd%$De8/wS))3m#:u$t89o8wD?v$6FLB#@^r%,p]-6Mjf8S[td@E+XSu7/iq1D+=*MPKg9/m'Lg*T'.bJN-7c+a<3pT(,oOl/(NgAE+9lwGV9DD:89x0c3nl'S-KGg;-9Gg;-eJo/0ZaqR#r`U7#vP4W3[hi?#BKc8/b3NZ6#@n=7*J*+3j_&w6rF,G4a3FA#d]uD4Ces*O42?%-c@T>,Z&PA#WSnc3[t+.2g/$n&ZE]w#?O[W$eKp6&eNJ@#x=Fe)eT+T%]i@T&8<BoLDGNO'Q<4h:ST5j'iHb8R@;@T.5`u>#]=u;-fQa])r4KJ)p9(<-FFI8%6F3T%fasv#:5YY#xbLP/QYr.LYC18.E9QZ-OM>c4bkD,;KH1a4;B5P3/HS_%3ipquYHd70EfKB%x3a:8eU`A&Z']&6^JK+GL&S&G3*gsT;43<-6mmu5+&>uui>*L#@Oc##.Pj)#s6D,#n([0#)kKS.V*4T.2R(f)#C1.ViSje3ET3.3e/ob4p@i?#LYmG*PdkR%QiCH34tFA#3&lTU7UkD#.4SN9,teA,fKER%nGO<gGC'Y%V-Ba<rTF+55:x),H>0%,E7Ev##6,x#v*f1(iF`p%wbK/)FVN-)p)mn&(R+q&YmAK2dDsA+n5k-$tvrc<NqGb%A5Hn<1mMf<B`8C#,x'/)@ECE#<C<5&5v#A#c-49%`pL-)Aj*.);x34'htYLMR&'VMY7>OOa^_u$M'm=6'>cuu8a$o#>d_7#&Vs)#o$),#EK0#$Ynn8%[wwT%<PsD#S#wA4QMn;%?@i?#4_Dw$Zu/+*OV>c4Ct8i#F6C]$dC587:d8x,Tapi'*o&02is.T$DwoM'+CBF&NiN/2GValA6ZOY-f0,3'lH[=-m&*a*9TgJ)H[U^uku[[#Iw0F3j'@qNUH$>YU8`0(do`8&-(@Q'Ne@t-27it%XIhb$KwAm&uAB?-4s#f$Q$Z;)s==-)Ln,D-.dY1N[[$##EJ4;-/k4GVP(fc)k(x,Z&@VP%[R(f)iUdP/Z@i?#2<kxFJ59(O4]6C#E=?G#4V/##V'r0(RwJ/+&MRV%fve+>oflYu%Y<N%2hget4##L#Tsn%#rpB'#FkP]4cc``3mS,lLClUC,1.+FP2XCN(2)^g6-.u`'H;NG)RJ))3,5?m%DBqg1C+->#Jc.GV=Ik`uXS9$+;@t<-`?Pd&:q+Y[$j^`<=^.^uV+>uuh(#3Vp7od)w@gE[Q5YY#O*[0#Ke[%##i&$f6DOgnC.t'4q4&N0L59f35jic)BLR1M</:Z-AIX205HSF4%]v7/vi`oCTWej<C_39%nL5r$gD74'XeO-)/>OS7EmPY>C#;9/Xg;A+,cJ^DLT03(tv9H2']sJjvOI0;(vcERb`M7#jJ6(#=AgI*$3Tv-<)'J3%D+^4;2QA#%@3Q/%GYjLRb^C4/W8f3FB1C&E(RA#6^-LEg5i0E7k#Y-T(bf2;ltI)T%H1M<2nA4jIXp/1VXI)At*]#7FN5&jA2e/KDs80R*rJ)&k_O1F6^7/Q3QM(8/3%.9QkB,Y4+,MKwnT.BE',HTRH>#K6i$#:.+5rl`),)q%K+*B4r?#][_a4BA4gL^0Js$Q%V)4pnKCQ5#Mw'I(^-@,CP?#vx%?5gnt(AMBlj'+R8:;Xa8.$6%D?#+<+.)nE8NMHj6TM(XA`a)Xcg?GOiZ#pi_o<rfUm&;rcf:jURI#7SlY#AE_w-Z><UMfoBT;(7q#$9DH%bwLYS.KVou,2dLL.bdK#$E9+W-Y[x$lgYPH3g@AC#TP<^4ZisT%nx[]4sJ))38$Ai)f-W@#]*>F)>g>T%xD59%7s.?5B>Is?kx9DjC_39%a6We$3Y79%fkn9%>QT]=R9DC+t_Xd)s2Gp.NJXa$JT2Elpu24'/drtgoW+RF9A(>V<fs.L*Ah;-=.T'0.XPbuv]r%,@*%L-/_Gl$gahR#H$M$#*8E)#4_s]dKO^C4ZoI&=GwN^,V5MG)f1JK+m%Jd)a&SF4Lg3874W=d*g`Ku-99(04CK2q%O-d7&6xl#YSjY/(575+%Mt902ms=h#76Gu-7tY.<?1h7;7Icg(Nk`;$b?gq%DXfQOSrS)*6pN/2.=a$#$),##[*Zr#EB)4#UPUV$oNv)4qD%X//_$a$LSLs-ob*o9#]gJ)dQU,2S.+$(hK(l'tljp%j&)l'_wp?-OAIS@Bx,r%ZTXp%:vGg)a6WROXhrr$i*FK:m'(m9cG0b*NY;q.3Y7%-wdu2E,qZ,*%,6b*pol<-7+oi$X?Y70TMS-)[u5V'_njm&_uK-4dD24'eIS.Ep,97;`S39/^'IxO_o^It[CHg-6KMK('-j609HNK(Nug^%-cPw9qtf34qRZbH#?e8/2D<`&^Zv%+Oi_Q/MXI%#^3=&#$)nQ/q'(]$aLoU/)F)<%qg*H*vRkA#j2$x%*E(9LidN9MwI,W-#j1rB#xSfL5J<mLEO`X-&5n0#]c###;vY=H$OCW-'b.-#hxQ0#R9v3#=PC7#(hg:#j1PY#S?XA#>V&E#s2*c69%uL<MKs,>fB+g$mk@<-gTS>-O2w.%ng2i:@X5mqap'%Q=^&ZPQ[S>-IWS>-c59wPh+T-;#C5F[=.'/Q%0xx'$+x1qv,,<-a>QW-uKuV)u*Y>-f&N(&4$`;)$DsU<hdrJ6c9a:)D@q%l+<)KUUAS_UKIt/O5UtsR,b-]O:js.LDP[)8qmJr)#E[&#T:v&6wSJ_8S=gG3mE?J,OQ+R8[/*EGEK*c'/Bi;.,Tmk*mbM:8aKgPqomY18EPqSgX6]Y-0e6ns0xU<-#c%t7K2rC&eT.c74(P]uCh,d.*&N-))Laf1%,Y:v<:G>#_Sk&#IC3D<IMN/2T-kY$qT/<7p;Tv-xg;E4I@u)4PP,G4*??A4dM%#%JBha6<PWP&.47q.J6_m&(A.Q0-NA)=i.m<-/b`m$n6g['4Y;69`VDU2r,E:2JvOBde9nuu:m6o#>d_7#d8q'#PC,+#pkP]4#^jBJ78X)[]Es?#=J)Z[YB/[#hj49.*Ptu5OBL#-lIHh-T4cHZDE*jLNuU1.scP1MuHs?#to^O9rPld3+g^I*3mWI)Xg`_&3vIa<g/r[#CNa1)*>s'4h5rc)#x.$PJ_wS%(pKj&)HLH2D$0U%/S7[#&O<_,7gPA##6%<$CrsT%,nP#%>@.@#3v5T%q$YQ'c$Ku.tBFT%]NWv51*$,CHOph(QW^Q&bS<I)5>1b$)x2BO>@.<$46fT&S-'6&-v^TRVU>a,aAhW$l;IW$CuZDEm&hD3DR=,)HL-%,0WY]#WCtnMr,9x&elIfLF:-##2qh%%x7$##2DXI)C7.[#Hjq%4o'UfLJ2E.31MJU)'TID*,K5n%J]M-(D[@8%G^Lnu'CRW$KxF/(eg+p%gK'43mUeW$>1f/(i4RqLs)6/(OZ<9%dC`n'R]&Q&L<OLD,wWZ#A_r2Mow[n9/v6C#EQR12:GUv-cD6C#6`BH#;>Uv-Bhi&/,14D#OU*K)`]H0cp9X`<#$=v#nZ3#-HaZZ$PEX5&tpds&UH;w#W<P7J#0Aue44@<$nFZ5/[f5#-5f:v#/`Rw#_Q$)'>vi)3fXL7#Oww%#*^Q(#_[P+#d/NjNjWrB#:HF:.K)'J3ntqa*P#Wv-kLre;$%H,*2WR&46CF<%itn[#bj*.)h)S[V?NRw%$bNh#+sZmM0]g;-?sOs%6l>9'YOXlAZf0E#ZjJZ$r@7Z7t];/D#Tpxc>HIAGXQaJ2v<m%liGsB#NUHU7w:+.)Dt+6M$3oiLNtvu#8;-`aixC`arriu5M,1W-;nq?%9XXD#(l@W$S*61%eW]c;M0k#-o:gF4$C_p&Fn3Q/>kS@#7YHpi?d&a+P$$&4E'bX$2;,>u3')9.Rs(?#9.<T..oBB-E(/?&<LN(,wYQt.JXVv#%Csb%M0N0Mxi%6M[HXVR*J.&#%#pXuq/kr$ABq%4pL2A=Hx6V8&t/02gFU%6A($lL=,B.*0i4j+J.Dg*%P@<-e_94.VuH79F8^;.fb<u$HI;8.]AqB#55D:5S$]I*56=W[9?Ba<49t`<o/LH2Z8Z;%1$50.*?b.Nfd*30SF39%P1rV$4++A#pBo2LS#DO'ARDX:*d1Uo8RWp%SQpQ&8]uY#?pCKC>U_4.vt<K;=fG,*nmO324Q=u-gc``3?oV2(?ss%lbA+ok5GgJ)?;1W$HV.[ucmjp%F5PX7'T&'#(DluuUtr*%'jou,<@,87#$&##U`@Q-kp]C%Rg&ZPncWn'&5(/-VBZ^$wxDEM/_Dd%7F(lK>o*hW'F5gLDX:@MH46>#P.r<-%sc5&Yk*0:.#@g#]Z49%?f^p7[^kA#EUg_-WP46m_srv%9Kio-$nU3m::jMr*rJfLP$of$Q0dxXnAq%4@Of&Qce4f%Ln/<-[J1&&%tFA#u3q`$.`d5/[RUa4k=8C#GV3;?X0d&Qgs5/(Sl(<-Tx497CqW5&DW2B45kP31B[E5&J90q%,e]W$*NQn&VUpmATUDq7uX(C&2dO;-W^J#G3Eld2rS5x6D.Rs$PF.W$=LX;/3D;pLJaD0(pK]pTn)[p-%8AZROqoZ$m^af:pF>)4EuXGEZ/5<-J;Ej$p(q#Zx_QiT6up,M'.1P8+;3(pK5###-I#K1Y3=&#9i8*#rNi,#VIK^H7XlI)rC>Z,cCke)'Z1T/))TF4RSw;%M[lS/>8ckBoFv;%E;4a*B4/<-&Bon$;)b.3S^%n$G6D,3HWlj'VNhG3rjuN'g9e1MdHG-96#.T%)s5v&Rsp:%t'pa#YYsA+VvDm1br8m$a.wM'Ll1W$hXwW$Y'Y2'N2:9%>BAN0^NhG)p:4Q'tr-m0>koH)o*<I$_uOq#A0gm&+*1q%ZpIfhF0g2'8Js%MVLhm$wgj*%;L/W$S:3W$&,###qk&/L%V&)*h*.5/VIbK1?DXI)<b,l1o:gF4%*=dX[W-8b)^dT6]0H`u&)pG2^&a6&U9;$>v=-:8pHCE#1sCp.=KW)>vJZh#uCs-2-edk(RjvRM*I2XMdUAZ$uqR3Lf)q%4N8mv$+W&J3^FC,M&(YI)_C:s-Lp:9/_9%=(KpqD3#8o]4oO/K:s<iac4K'm('u'n':,@S^<bfM'AvelNrN&S'7F39%81eS%x]+c40i[4CYT,=$vS^PSIf?g'd3#$c6l:v#mL1-4HLAr8+WC_&ii(Z#d+Oe)h7^b*W1`;$%5YY#U`c=l8U&NL`<AJ12FkI*C5v[-upVa4stC.3_M%d)8K3jLfd@C#@Dn;%pbW;7Bl;d%OOf@#.TqM1hYdAu4;vN'w&,d5CtF40RxG$,T=aX.=6sOBX8R/(]10/)].wD*>6mN>6Y/p&X#,P9X5P;->8]H)s:G$,&>^r0E/TX-qh#v,$cj73&&>uug5wK#B[u##JXI%#3C]lJT_^/)X(wbYXTZ)4E2.?8`Z2^[3Ne20rUdB8.Uh(W7xg*%iu[capVN'#/V1vu<`fX#SO6,?U:vqX+A*/%]Y/fF-M1q>1aZ`6=gvJ1esgfQ]3]=Ep,97;:tp6*#ASY8b2vN'hu[fLh<2Dfqd%Y-ow)UD)Au^]Uv),M^#e##pvK'#Li8*#6b#L%wDcp.0Zc8/e[pcP03<b$1.Ha*RY9b*45XT%JBGq%$oD#lC_39%[`Rf<g#q7/p1blA/dT%FV5do/0mab*J+(6/DEhT7bG)*M>ZHN'f5u;->*.'53D7X14no7/*Qi3GgwS&,&,d`?0kNladD24'FSlk-YpJI$#+[0#/DW)#=E,+F%t(9/_.i?#T)7r<mr4c4'c^F*=k_VCZE'd%R>'?n$V@C#SQ0OO#wP3'O#U_6'V;q`UI@u-G$3d*(6^Q&fn3XU?65C&ITOIAVOUI6;H9;.tE49%R$@H)b6<v#%ocnAT+GZ,B_sl&xO3^-5De['$(lKj2ERr#%,[0#>bf/._V5lLC8L*#L*:PMxLGA#,39Z-XU@p76U5s.BK9W-v@wb%eB,hs=#FFNZt2.NkDK88k&1^#n-T_/k3Ls6CsV)33U-_#2iuYu.:9U%*X3I$qH<aE2?tM(9<^;-OmL5/d$-32qof$?$Tw,XZ,sa4>k49%XZh-6Q?ZhEkVL$'RSHT%&I*3Ld[sY.0tKT%:[jfLG`):8OPk.)QY(6VRO?>#C[u##;v8kLM+M#$S,m]#mD&2B<^bA#`IR'&QpTv-1]WF3b1&i$`Ut.LFNgDP?NtQ/:ZRo7oCs20#e%[uuf$e2a@f9CZ;Z;%=1EO#Ng4',#o;Z7W-A@#&150LYVHU7M696&$lj)##r^^#9JQ%bt36kOdaO`<T-ip@flgJ)4DNH;O)uI#6XXD#*Ptu588ne/h>.H)`5qB#BVYq)7jE.3MF^(/_V0T7QuD6h4Xnm/?Cx/(=@Y]uC_./2n8H01<BPm&9x?8%6*O)<Z7QWIsHeH)Dqws$f/fv$(dl5&#oHJVVrCr&V(xs$er)6/KkEp%:]uY#>:%<$K<f>?X3n0#]:LcD[1dg)Qw[rHb$M9i+;Ls-ZCu)4$,JA47T7)*sKqA#`=kN.Ff@C#%2-W-do&tqWEW@,1GWEedc``31Kmd2[00u$Q-Sw#j^LG)+=RP/mg6b@%L8[#qQpE@i?(E#'csk'Wvk.H$Mr[#tcme29r:ING4tu5;T@]csLN2Kh.4I)ut>C+V99U%N>h7'`-a6/:wx2'])CSIQJ%p&7R&m&GlGW-<6O7<#KeA#3>k>$J@8rLr6=xbeakT%N.iK(^F:Mqsf9s*8E24'-=P>#6SG>#_.`V$dQF=$U1mV$<4Yc-)O+CJ#,8f?Neq(#IV4;-]KiV-BT=8%8^gx=ce&DW..BPAWq[U/KHuD#oAic)nX65/HTGg1&'Nb$JBRIM51#,M4xke)1%I=7[o9HN/CYcM?-_M's2GG2^2B.*QEk7/x3vr-`(v4SasDE4g48C#?;gF4lpFp.baGj'd6f=1_^ft-;va.3<r^l8:O.K:ns3',n+=rnYHgM'B:V?#MnWT%S-cm'.#A;6B_RW$[FQP/c?4,2F'bp%fx7X%NZ9^#C[3T%H;6j:<LR>#;Q.[#9OXe%7^^b%,uIT%@IPd28o$v$@Se*3eJY;$Lt<9%`a27*13269(f>C+V%lWMteB(Ms;eo//_UZ%=USM'dKbG2E#At6t*93',&s-aBKTO0>4r;$NMK>#Lfo;Mm5Cq%7Z2uLpv[DEdO=,M6:Ev#b#&[>TXlU&:=E5&),m+%*?V0(r2Px#_J4t&M?;qMgHYJ(@RlA#^Z<F.2k)YPJu]&#2ZC4D<Ux(#Asgo.O29f3H7Gm':D-Q)F%V%6qd6.MJ17%-ROr_,b^4g$l%ws.e1[s$CY@C#`I_hPmNv+DRR39%kTEY-.wYIF:Hv[HM/2$>@,:#&Gr;q%,,%T%D4#NBP/e%+_p='&WWT6&h`75')j1pL9]>#uNFw8%h*7],]gpw'p[/r%+<4]%%jwE7)<q5&XWlmur5'U%YjuN'F2w`aa+JfL'w$aNBBe##P-4&#v2h'#;iFJ(AGXI)n.f`*b3Xs-Uvn]OhJ6H3J]d8/f:]lJtB5s.dW^;.9f@C#-Q?g1Huc3)aYAS'L9Bq%[?]_OSJEYP95K-)]w*W-lY^g*$Ca;$38Fp%5Vc>#Q8+D'Hk*R<vcjE*LA4Im(w<>#1rJU)-Pr),(P=l$7[(iL1EA<$J/A32vq^@%JB#,2#=FV?Ci^a*w[[9@P9YD4rnm;-Mc>W-V7%'n,BF:.DYvP/jAqB#b$g:/6qj8.*175/;7s5/q3vN',GRQMT[HLM[19VMAhYhL2FDX-M<$hc@=E<'be#nA/4:)lN*wU01k:P'Jhq.)IPu<Qr0WPKinbP9'#-v?Cv&vHX2YD4`lH#6LW@_8oK#F+UhDm5n:Sl3pI.*/>pT/)=,Vm&#.m+D<&Wg;#$&##N,3V9B>6X$On/H*T)PT8d2Z;%^:w;-kF'%%vo/+*5i(7sQ$a8.Q`m),i99YcqxO-(MHkQ/_71[gl<Pj'<x14'QXq(E-F3t_qX`e$V0(]NZvS@#/c`?#_[iX-hKqMr'>*s%BLmTi.A,_+W@,3'Kd2UMj]GOMv0-C+18,S.#]in%4=('#$p=:vMn$vTpAT%#%pm(#L8=c4RkY)4wnUNts4wS/I>WD#KU%],uR/K%o]qSg;OLp7698N0e-ji0,ue;%OXM_VlDuu#ai6A*8ZFQ1rSg^+.bq.)>A@I2C_39%'+W:M=>#L#H+VtQ57%@#>RkdV,apD#*]E`WMt'Y.Ci<`-a:.0)MpLN''Zk-$x15C+#l''d#(se._,_'#rJ7'&`>S,MZS/[##ZWI)'M>s-k]Te*lfu8.+:RP/$kpJ1Vq'E#+/rv-`Ld5/A*Gb%oBFA#nY?C#hfn2.1ChhL.GOn-eKEe-LS<+3_4I,*A[7`%sVFe-FJ8X1ZXfC#pnSh#^A7d2jpsV$_7l;-NL0&v)Lf&G9-xmsfR`INtWNq&bTKq%DhwW$:/bjLat(n'G0T6&P)`0(V`>k,Ox+@BlI`e$kAq8%CURW$9EKW7eR@].<K)Y.=,0=Z:5pF-xc(-%@`/E#e(U'#BVs)#v<_F*rcA7.B5^e*pOSW-muH['+W8f32'OS;#'i#?4^FJ*J29f3B4vr-iL0+*B]SA$>T?)*917W$H>:W$cI.W$[)KFEr-NPC%O(?%Mac:/)XCK2>Obr/x?mu%aVl8%ud?.MjlKNgdD24'^kY>#EB0Y$fP)Q/m<Yp%o`(c%&ZE9/R];9%93dr/E7i;-t@jf%t)p(<c@iQaLjTv-68wjDCxdX$e:el&U$Js-KqL)Ni@GA#@>X6MiG8f3-5%N0D.Y)4mN5/(wVLhLxl8W$iv./hUx.<?Z8Z;%qmj;$5]]i(iZSv%+74i$S*sZu+)Uu$c8$3'/hgK(5_v?LP)S=)@k5I6k5qp%9dI-d:W2]$:=wS%Bli$'UaYp%.Za5&$SFi(.S[GVV/%-)G-AJQNne+%;1,/LEvTP&Av[xOTfh.UE6*##6Z9q`p3YD#.U4x#+2pb4C7r?#s@Z&3&,]]4$4D.3(.75/-d%H)w+9TTmu%H)[VW/2U=As?.03Z6V=PjLpid8/#&AA4'(^j4Xb6lL*dfF46N.)*GI3n%RKEe-LIcI)_4I,*LHtJ)N2(@-g/9p8d$jF5n(&H)hCXI)2Wgf1`t-eQ=29f3uchU8EG1a4GoP0P8J[&4HjE.3((%],3GpY&Xe39%-T0TRLF`;$WvgU%6WWC$58HA#]I%OZv(*k'kp0U%&[r%,YK>N'vtB/3*a#t-:_Wa*m#;N0M,>)<f?<w,i'HAO+DQ$,&bA30.bWX*5D?D,:^V<%m6]p%1-p=>H$5N'MQc3'Q;Ek'c2M_#LXn<$7]1Z#3dHV%)BCq%7Anr%pAU6&Q2%L(VX:d-*#?mqo='[8fl^$-QWIb4WshG)`.BJ)@,&'.&cPc*8>Z^42>ZV$9DH%b'_A`aMu08.@'[i95Z&##[']s-uHvc*->N^=LJQv$IWOI>I*8/l#>,G4aWgf1CBuD#2saI)h@F,MbtHg),T[Uhcl*&+o,hv5e%a:/9>LW7.M34';324'bv3V7c*s;$OJfxOX_k>-PeTq)(uM.33_#F#cUKj(x'D/:cFS/L*4;/:.ikA#eJ1e4h[tI/#nE<',150Li#QK+s*&@#P,2BQ*euP9Tel3+deu0,;2=7's'amL?@Cb*h;@<$w.@W$xBf8%WN^%'YWf'd1m+L#U#x%#$%(,)MD,c4_v1t%0+Ap.h?7f3845t]Pu;9/*/P/C6U)A-XqE<8$Xu#%rF)1D.xVm/3iCv#r_jo9F$,/aU1wS%xMTW$`1<88i4FD#WYL;$K$/a%7VlY#Qq):/2YuY#NY7):CKE;R15da4E5P/_NP2'#&2P:vfK#/LOuIG)YYl%=i_m,3n;MG)4Le;-9++_0$IuD#,*8f3A[7e*EuNdD:j?#6w.G@n_/E.3Fm'^d$V@C#>G*T%cJ))3_ZD.3ewIr.j-D[,5Ydr.x6Vd*vp$W$[Wfs$t$Wm/=CIW$$)=cOH9tX$N>uT8YDhT7K1IH+$q8v-xJBv#38k9/$)dxk&=*p+0](Z#fM4[$ttMm/?Les$dIm<G5%.m0D..W-,(XLsgW&%#^Re+O'7]8@G6?thxsRF4/Y<9/hp?d)k5;,)sA&9/>]v7/2lpK;A7O%$okb:&t-iiS5(q7/3TE$v%tV%,blcM9q]I1(Sd>aPMgH##IZhR#+ZL7#v'8+/fY$0#1]R<]CAP^,[YVO'V:Ls-u,5)<`nE#-j,E2<Y7)4FRYIq%D7;?#XoNe)+3I12_Q^U%WD<W/axA.&WTsAFb`dl9?8Eq01].mMwrJfL42IN'pEr4'Hcnw7*48<$0FIWAj4`B++Qb;$*DokUIt+v-)`^l8R@_'#`ano.05r%4Tp<J:)2=Z%PCs8.4g/+**^Z/1s<RF4iFo$$:q&s$*Oxf$LSQF%].RF%:iVLDfUHh,t2#cEv8t(5:[k6&k>l(5mS4'5XVwH)=08O9-RZd3Br'`$`lo.)d<Awu$]v7/@W9I$siIfL/,NU/iweo'2kLf<i(hT&oMDO'6=B02*gE9/lQgo/28R?$g@`/)rcVX(t@$##4O/2'?VXo[s_131.3ZlA2Z;'f,Bic)=ljj1FQ:a#niCgC32Zg);Mx_4C>lb$K:uD4v7H)4:)u'%:;g+4+vL&MMT6N'Toje)51t`#sc``3W*Q8/5U8J3vuUC,(gTv-F1DYPo_w,?LZpY#GL/@-?RTT%qp&m(RXwW$^;&^+3Ox`*(#s#5/q5V%<F.<$cfIL(6ou>#tRq0,=r(D5G6Q3''O;78fiBK#)P,5247as-p8HQ/sSRl'[mdD*%kUj0.KF=-uFOM(S9#T%RvuR&p[,(+*9#A#<eWT%rJpFE`jP/EWO+=HlqC/#56j%$326`an1D`aTk%/1^'%##=pTv-$3^c;.0xb45IL,3`69u$]4bF3cvrI3@$,uHnoL*494#i(@ogh(ZL389dl$9.ljCK(*Kcq%SZw-)CGA*49>7>#.Y`vu.UHU7$j-$.Qi1e1XbP'4k&vN'KCk>-2C#VVr=u9'W_`?#iWaWAWU02BJqa8'*4?M98<.J3NVd8/9&^F*+2pb4bf)T/KB4J*JTDJ)>mj;%V8x/M>FB(4]1&9.vB17JZn+MBPt*9%QguN'M4n8%f,4+Nutu3%EhwS%Q3ZLgJ7Bv-cJC27PaFW6>+bw$7Hs%,Ekv&OQ*kp%H@Z5Lb`w4$V+ofL[f9v/q9R90<I,2('.mw/PgXV-_QJl<,G(v#rg@Q-0=>T5w=N)#&%(,)DtJs$]::8.@S7C#W=[x6imQGe,%x[-P3FA#kR1oK91Hv$UcOO%DII>##cnw#%ieRn4]c>#>OnS%^A^ppl_)G+*xq%,kwg$5MP.[-/;+.)Qc,##X5&:-G%lgL4ovY#xk9'+WC'6AD8oB4RA>MCZdIH3<Y_.G/<UX'u(Tu.Z-d(NtgH>#BVr,#KaX.#C%r_,ed0Q/`M.)*vkh8.c6AW-=[@3kJUCp@jRP8/2nAp.I>WD#Zef=fY+-e'NaQI<1nP,*:C^j'<$ol%UdYn&B9a`+;R3N0a45_+9nL0(V'&nLl8$n&=:Mt-T^ihLastT%ZAc2(MpAf-%5v10Jg4',u3vN')h`O%&wr#POKihLl/$3'ow3B-OZN$PsjVK(Cpf+.DI&O=3b('>L.i;-A*l<%I#D`aSRt1B8d&##486J*P3FA#j::8.r_7H+nVfF4b4^d)frYq7A4'etkgj?#cMAF4+87<.#qtu'fe^-Ms>v-0UQ^q%;&68/>w+0.X*Q/CF0&9AZ#Zj'A&ev.iwBh2o`%P'vl*#,#,q`jD8*1%+u*L>%:`s%(O-*NOEVM82NL2:SbRf$s92hL)Z4e)GvS>#GXZM9VwW3L42:D<xf;]X5VGi^'8n[$7N>g:rW/+,qeWLDA$DT/lNXA#9MIx731T;.B<@t?nQ^I=<pfP+wOk.)%abI)Sv$h()J&(4-,3'49W0j(FMZK)p,Uq%Td(0(Ig]5'SNfY-%s_$'l7=Ji%5SgDQHGN'Kx7_-%SK^$GMf>L['a=L1/2g)Wke/)'PT3O]=M$#=Pe&,&0A>#*ok&#tY6A4/(1B#mwFcM01L^#)=PuY1:h#$7pM+r2C-?$0U)/:3LHZ$P)8S[4Udv$@IiV$8$&9&s4mrH9-AT&f>Nig>Zt2(LpC,)?d9N(_gTD3@mTj(WZ*&F?p,g)C)7;[@#H,*jo)Tf'5>>#_YE-ZRAl-$.(1B#QAl%=<UL^#x4`+V1:h#$k%Ko[2C-?$kuMG)3LHZ$(0DMB4Udv$(G^+i8$&9&D62#,9-AT&L'5DW>Zt2(7E1Po?d9N(W_dP/@mTj(<%O>5C2Qg))nCDN@#H,*r%Dcb+/G]FcgXoIT1PcDH]4GDcM8;-YqTiB+D-F%'QNk+G&RX(Wrv7IQe`uGBB2)F>NE)#k^T%J$'4RDCKlmBxlndFh:3s78M`iFKU&##1[l>-/q8O=#%?b74bf'&f3/U;Q>qHH]&m639ai?-12kaGbZr`=@'`qLt`b,NfCFE-uEa#0-K6(#/9q'#++M%/:?Rh2)EOe-*/;Tbra0bIt#$CJXYnx4<=:p/t;Qo/T0f-#_/:/#^4%I-.<C[-GFst_xI$##>0rk11(4A-b]q]&H3iVC7;ZhFrGlfM%;ts7IAW5_^[-lLdj1e$^Lco7]AlJauKxR98N1U1LgOs-c/RqLJLG&#DTGs-/RWjLRLG&#$'6-.8#krL%mFrLn9v.#ZZO.#0]AN-D[AN-6oSN-cdF?-Rk'W.Hgb.#SqX?-QY`=-]eF?-TLx>-G,_j%cv-PD0:rVC@rLG-=C=GH>_V.G.gcdG*M#hF5xLVC2]HKF6-giF)QtnDHGKfLj.lrL/lFrL+>4)#K)B;-?</F-(v^A8i^<j1v.8R*bsTt1R3//G/C%121%fFHbFOg$FEwgF9T6E5T%co7X'$EP4%co7%C+KN5NV>8&5=)UG/5##vO'#vGgdIM4i#W-J&)=(o24##);P>#,Gc>#0Su>#4`1?#8lC?#<xU?#@.i?#D:%@#HF7@#LRI@#P_[@#Tkn@#Xw*A#]-=A#a9OA#eEbA#iQtA#m^0B#qjBB#uvTB##-hB#'9$C#+E6C#/QHC#3^ZC#7jmC#;v)D#?,<D#C8ND#GDaD#KPsD#O]/E#SiAE#WuSE#[+gE#`7#F#dC5F#hOGF#l[YF#phlF#tt(G#x*;G#1#M$#w'`?#(=VG#,IiG#0U%H#4b7H#8nIH#<$]H#@0oH#D<+I#HH=I#LTOI#PabI#TmtI#X#1J#]/CJ#a;UJ#eGhJ#iS$K#m`6K#qlHK#uxZK##/nK#';*L#+G<L#/SNL#3`aL#7lsL#;x/M#?.BM#C:TM#GFgM#KR#N#O_5N#SkGN#WwYN#[-mN#`9)O#dE;O#hQMO#l^`O#pjrO#tv.P#x,AP#&9SP#*EfP#.QxP#2^4Q#6jFQ#:vXQ#>,lQ#B8(R#FD:R#JPLR#N]_R#RiqR#Vu-S#Z+@S#_7RS#cCeS#gOwS#k[3T#ohET#stWT#oPtA##1tT#'=0U#+IBU#/UTU#3bgU#7n#V#;$6V#?0HV#C<ZV#GHmV#KT)W#Oa;W#SmMW#W#aW#[/sW#`;/X#dGAX#hSSX#l`fX#plxX#tx4Y#x.GY#'>YY#*GlY#.S(Z#2`:Z#6lLZ#:x_Z#>.rZ#B:.[#FF@[#JRR[#N_e[#Rkw[#Vw3]#Z-F]#_9X]#cEk]#gQ'^#k^9^#ojK^#sv^^#w,q^#,k/i#'?6_#+KH_#/WZ_#3dm_#7p)`#;&<`#:kj1#,2N`#C>a`#GJs`#KV/a#OcAa#SoSa#W%ga#[1#b#`=5b#dIGb#hUYb#lblb#pn(c#t$;c#x0Mc#&=`c#*Irc#.U.d#2b@d#6nRd#:$fd#>0xd#B<4e#FHFe#JTXe#Nake#Rm'f#V#:f#Z/Lf#_;_f#a5:/#<xAi#gS-g#k`?g#olQg#sxdg#w.wg#%;3h#)GEh#ZgLZ#/Yah#3fsh#7r/i#;(Bi#?4Ti#C@gi#GL#j#KX5j#OeGj#SqYj#W'mj#[3)k#`?;k#dKMk#hW`k#ldrk#pp.l#t&Al#x2Sl#&?fl#*Kxl#.W4m#2dFm#6pXm#:&lm#>2(n#B>:n#FJLn#JV_n#Ncqn#Ro-o#V%@o#Z1Ro#_=eo#cIwo#gU3p#kbEp#onWp#s$kp#w0'q#%=9q#)IKq#-U^q#1bpq#5n,r#9$?r#=0Qr#A<dr#EHvr#IT2s#MaDs#QmVs#U#js#Y/&t#^;8t#bGJt#fS]t#j`ot#nl+u#rx=u#v.Pu#$;cu#)Juu#,S1v#0`Cv#4lUv#8xhv#<.%w#@:7w#DFIw#HR[w#L_nw#Pk*x#Tw<x#X-Ox#]9bx#aEtx#eQ0#$i^B#$mjT#$qvg#$u,$$$#96$$'EH$$+QZ$$/^m$$3j)%$7v;%$;,N%$?8a%$CDs%$GP/&$K]A&$OiS&$Suf&$W+#'$[75'$$@U3$bIP'$fUc'$jbu'$nn1($o_G+#b+M($x6`($&Cr($*O.)$.[@)$2hR)$6te)$:*x)$>64*$BBF*$FNX*$JZk*$Ng'+$Rs9+$V)L+$Z5_+$_Aq+$cM-,$gY?,$kfQ,$ord,$s(w,$w43-$%AE-$)MW-$-Yj-$1f&.$5r8.$9(K.$=4^.$A@p.$EL,/$IX>/$MeP/$Qqc/$U'v/$Y320$^?D0$bKV0$fWi0$jd%1$np71$r&J1$v2]1$$?o1$(K+2$,W=2$0dO2$4pb2$8&u2$<213$@>C3$DJU3$HVh3$Lc$4$Po64$T%I4$X1[4$]=n4$aI*5$eU<5$ibN5$mna5$q$t5$u006$#=B6$'IT6$+Ug6$/b#7$3n57$7$H7$;0Z7$?<m7$CH)8$GT;8$KaM8$Om`8$S#s8$W//9$[;A9$`GS9$dSf9$h`x9$ll4:$pxF:$t.Y:$x:l:$&G(;$+V:;$.`L;$2l_;$6xq;$:..<$>:@<$BFR<$FRe<$J_w<$Nk3=$RwE=$V-X=$Z9k=$_E'>$cQ9>$g^K>$kj^>$ovp>$s,-?$w8??$%EQ?$)Qd?$-^v?$1j2@$5vD@$9,W@$=8j@$AD&A$EP8A$I]JA$Mi]A$QuoA$U+,B$Ui&*#L?GB$[%B*#.OcB$f[uB$jh1C$ntCC$r*VC$v6iC$$C%D$(O7D$,[ID$0h[D$4tnD$8*+E$<6=E$@BOE$DNbE$HZtE$Lg0F$PsBF$T)UF$X5hF$]A$G$aM6G$eYHG$ifZG$mrmG$q(*H$u4<H$#ANH$'MaH$+YsH$/f/I$3rAI$7(TI$;4gI$?@#J$CL5J$GXGJ$KeYJ$OqlJ$S')K$W3;K$[?MK$`K`K$dWrK$hd.L$lp@L$p&SL$t2fL$x>xL$&K4M$*WFM$.dXM$2pkM$6&(N$:2:N$>>LN$BJ_N$FVqN$Jc-O$No?O$R%RO$V1eO$Z=wO$_I3P$cUEP$gbWP$knjP$o$'Q$s09Q$w<KQ$%I^Q$)UpQ$6^wH'wo(*H=VT=B75?LFu<tbHjBO'%%QcdG])cGD]eDAHqRA>B-X0,Hf/#gCoD6`%D?;eEo&8UC_4CC%JmMhDtv/jBksaNEt*$1F7vXdMwBP'G/S/#'Auk,23r*cH*%AiFJGRV1fKk'%+^,LFWQsiBgvXGDkQFb$q2JuBuwRiFUaf/C:J6lE9<j[$xVpgFxrBVCoF/vGwd0_%HaO_.=CRFHPP-X.jW76D&R9[1%,QhFufMA&@xnbH+WAb@4sLC&sBn<:3vh_&9`q(%/j#hFVK&NB]S3F%vU=>Bj[j-$#daMBvA$`%MJF+Fh/(c$3/?LFcNM<Bus.>Bl-vLFoG9)4d,1dD$6'oDl=UVCP?$LDm&4RD1nU_&88/:C73SgL;?*LF3g@qC3qCC&+>pKF%j`]&Gge]GW;T5'EEv,E?GqoD5K8,M4S0^FIw1qL2e.dDK1#H2m4/:CgG(dDjH7UCmU,-G2Tgc.cdW2Baj-]-a=)_S(p[9C,7,wGE;@V1agaNE(-+;Cl[(*HM/Z<-Qc[F3foM=BtDo=BvZ+F$@lV.GsQ7fGV29p&jJ8%'.A0%'$ST3Emx7#'v@I'IWw;be9;7%'N@VU&>=4,H:%VeGe8Zw&G&K1O0TnoDBmO4+^Z,mB_0:<.)xbVCgtk6<dYBT&&p>hF_.D;&1+S+Hu^nmDo^WMB_p&3BDOkCI3g@qC2nCC&D7$W%J/kYH^ekV.2%jMFqVO%6gaoJC1NKKFc(vgF.dFVC,)2LCxHM=B%gpoDQtd@$$8rEHZ8d<B^MBnDdNSJC8$JgLBaL$HxVKSD.W4@6*e2=Bv#fUCgoM=BgsojBpYpKF3;RV1l]?)%JB]'.408gL3ulUC$,I&Fk/xUCRa6H+1>5/Gx6Z,Mvd-ZG/8uVC(7,wG1c`.G:vCU1$i3GHlq>lEki`]&XdNN1,gpKF%ZUqLCi(RB<h]3FE+2eG4CDVC'6l+$rS6H$&G`*Hr[JkF6q]vG&-7u1kp*rC)nIbHtv@>B%$/gLXd.SD3C4/GpE;9ChOT0Fw.<#G8m6t_dYpO14TJ>BwFxVH&3JuBpLrdGv:7FH)s[5C*Bx+HWAV9Cp3vlE/Y7fGf,fTC/BfqCq]CEH.aRqL-ZP'G4ieFH>D+7DDiZBO)XcUC@]HBO9>5/GKr%ktA?K&ZYCUp$#lw92H@BY(Db`u(c$vIP)I)[%uqGkEa9b'%6mpKFi@S;H,l.+HfL^kE#W)&&r2JUCmS(*H2h#X$^Qf6B)ooVH7ln+Hlq>LFdY#kErd=b$VH2R37OnaHorugF1ia#Gx42eGx.v-GsH%'I?T6H+f6_MBrrQD%61=GHcownM;2=lE5BffG'8iEH8=4cHrb=WH#g1eG-)[MCW2`p.]NFb$nmNnDsKbfGr/Z@&)HxUC@]umDj&^jB&MiEHF$kCI)eCC&[:b4N,XcUC9#YdM943f1jh>lE=lI+H'$8fG(%9I$Zs[;%QfpZHp+mKF0#vhF*[rfL3VIc$n_(g%%NaMB%gZD%/ZXVCk5Q`%0pldGndM=Bn$)*Hs]HaE&>.FHu2jXB#xOVC?rP:C>hI:.8cR+H.OpNC(L$pD%T(*HrmqpL;=6jBpQ.UC/Jh0,C_7FH[ds2Bx7(51gWiTCaV`9Cx+s]&1iWnLZFPUCogH=.lY(HDIw%Q8BP0H4kgd3Bv#fUCG1qYHOsFp7Rk8Y(i$<m'k%lYH$N*Y.2%jMFWs@/Mi$VdM`%7A-2xcW-Yc6.-X;k<%w(HPE(Nq(%:9e7MvZ>>Bmlt?Hi+/YBi&$@&C=oFH,Kcw9)7bw969x.G$ExUCiO'HOnc5vGa9Lw-.J[rL<)^&$f^BC%jmnUCbB9_%%Q4ZBv,+;CfPM=B.YcQDhg[UChN9_%25v1Ft5kjE_ue:Cj+CVCQ1=W1lu%Y'Q0<w8_hI5B3llw.m?ViFD:j*.XWjdGjseQD$C6lEkpbF$&p>hF/'/?&FsTcH4ln+H(Av-G4nTcHJ*7B4cr.>B%s%#'SavAJ=ZR'Gf<iTC22%7MtENhF;8H'O&><j$$gIZR&^AhC<v1U14VqoD-)$pDjCTEnS]@rL0FI8)Ei1Q88dgJ)]D=^G&>.FHMt`X-(8hi5=$kCIDm9wg1(EA&=V+^4=CRFHp3vlE7(F$Jeu5kE2l[+H@<$LDQGKvH1Bx+HntMW-ph6q0cDI^$LRfBJD;34N;jg#G2IPC&.UHSDcf3$N/F?jB'*s=B_D6R8R`SU)2InERE7BY(=wbr(v48nj6n*bHP>O$HmMv@&<oVMF<G76/ok>lE=N<SM%,HZG)k%UC0R)W%$VL9MX`LcH6?E:)Xl@rLsonq.dL^kEnw8I$+'bm'B=4GH@T@&GP=i3O?iNx';e+;(C<2)FelL<&7mj^O;A5/GB_[6//ToUC<b_QMjWPLN;>5/GuV$N0Td5/G+nIbH@WESM1X2gCo2kjEjk8I$CZTcHsX%iFj^a2Bv#XnDe3WMBdmi#.)bcUCmG#0CmQSvI/x%9In29kEe^nmDu+$oDpQW9r8Kx.GUOPBoF9OGH#TVt'#KOp72_i8&8Q<e?G=hoD15D-D&s$bH?qh>5a5Q`%r/X7DrH7UCg3[^Imn#pDwY>LFFqR3Ox5]*$q;$H$og`TCCM8s6v%CVC%d'kEPEM<BpY=>B(>J;HiTB_%js@>BFK&&8p:O'G^)PgC6d1U16W+;C57ip.uviTC-t:C&NHkCI0cDiFJ5koM50w0FKk;p&F7xKuE[f5B+dYhFMGKvHqJ5hF,p?mB4L:qLY3,UC>OpQWLdsp'3,0iFo&Z[&v)4VCa=GrL4K%C%21=GH0A3E%+@16M9(ZvG$2^Z.I<$LDWqef$3CRFH[@cp7wU?T.gnY1Fhk3bH+g>lE3/$&JhR>LF-8vlEoVUG$2&C8DxZeBIR#Lw/oIfqC[ZM<B^LViLqC?NBOTs[8(xM[$4,)*HvBB$J7e&eGmQ0eQWT3$pYWjdG,j;='++4GHv7w#J+aNNEYhd90u2adGg'=h3$6IoDZMJeEk,$@&+0o6D<Q7bF+T'ENqdwC%^,HmL)gfaHx($kE%k`9C:eQ'G48vLFnAQ[&%3tNEj^Y%0lDZ%&$i3GHX3>k-3ku'&QURfGF$c3C'H(G$.#v-G'xOVCFIMVC(MiEH7M@rLIb#p13BffG:SeV15MeBI'W:qLeU^TCuw4sH5C4,HihcdGq]kUC6onfGj<2'o?u08Dl^rTC:K7`&BqhjEVZdt12Rn;-nUH.N3tLdMUt:eML%lC.q>v<'Zg`_&uf8/PrE%(%61OGH5mOdM-YcUC=</gL0>iVC9%>na[7_8&NPB?H(5M*HR5`9Co<>P4uOAvG)3]>BmZD<B9A2eGP65bHD`HFN-ERSD/:)N1lo`Nk;kn+H[j$KDgY`t'rhRL,<V3x'81D.G6f3'FvxlU:fl2PC4MRU17Fo+H+]a^FdEDtBIwAeG1SJY'L2kYHUn1e2*FqoDC.=W10mXVChquhFwK(O=9AKKF7vN$HegeUC*t3cH<6[i$<SA>BLY6'Of/OJ-@R`9.esT$&AEAt%kj[:C@DJuB&[u'&4`,-Gb=<'dxmluBmv,bRGl=HM6*%oD+-+;Cbi4#Hf?:@-o6*3&LcWoM8'2VCOnIe#g(A-;5`R&G1ffY'HHD)F?6@]'<+$1Fg]BD4c?DtBoC;LF:U=GH.AR&F=&S'G2Hf,M,TeoDpA:,$/erS&YDd20=CRFHw6`aHbr%?ew7mvGS)b4NPs4-;c0xPB0AZBO:&FPEmYuGD*c.FH@#Hn8*SO6B,vssB(rw+H$p$rL9rd3B+dYhFb5Jt9:h5gDX`7-;&t)u/p^$NBx>^kErfl4B<`r*H2gkVCFe/F%?M9oDD&O$H?#YVC3l`5B'g^oDTGX</fXi69BraN1*jXVC3dFVCkTHt.Rvc<BFG6thQsA9&N.+W1NZerL11/HDv1D*Hia[UCR:.b%;S4VCdp79C':.hYF<ngF=_C%'(JcdGVDre$_g^20&S(U1^HR6Dp<Gb%Y1@4(-s1eG(BoUCGGRV1-8$lEq'i68WtZx0(#kjES)Rx0X's;-fbPX60+xFH)DHSD7J2eG`XCEHst@iFkS(*H2+3pDL-4wg<I[^I370@JAD2X-9kqw'L93.-PCM*H4aFVCgfitB&weQD$i]vG42:sC?DNf16spKFD/rU1;V;iF-0I@'6'5WHThdN1ox;&&4,)*H<,MT.1<&NFJcGhL02rCIp/fQDtF+7DNm1cHQVV=-5%mW-Uhkw0-g`9C>W,<-)2kr0b`V=BnfMA&vm@uB:h_0>(B(C&%ej-$Ui$0)*ZX7D8.Rq$cveM1Y:TDFV^;dExtgS)q+>^G&>.FHN'&u-iIb*<=*`n<?mW*[0;'oDrWi=B5EFHMBV`X-Pg_%'Y3w'OvdXo$*86s)fGL,*CN,OOR3D8*)>Y?Hv,a=B=C%oDWe<kLLYfLC,o/L:ruOn*5<'_Ij5KKFCfi'/*+$kEF6iQMP[shF)bdt(@ost(j2A,MrT2,Dq=waE&g9kEeSbt(8>[['Y(+SMuoshF9d7bFvl7Y'v^i,M_v+h:U</bIbmfBdjY:f;f&I['(&x;SAVblEi;__%?=4GH*27FHq'Q-G14gvGr>9kEka[8&^oXGM[b>>B6mJB$+m@#/%*bNED&#4+8d0,HxRg6W*A0gLA)MVCkV@>%?6W8&OTPj0tG^NBkW)XB58rU1/$4m'@6dGE??@x'(.mgF4s>LFQ_08/YS@UCEsFHM4u(RB-5QhF10.%'5ocdGxs__&`mTt1^5*HEv&4RDX+]:.0PiMFn1pAG'EpKFc:L_GvA$`%x8sXBo]#lEv6;iFVqds%xD+rCNn2T&[SD3kk@S'Gq&?%&-3/:CtGxuBT0U8g<S5bH'x=<HdjeUCCrpKF(J+v'7&$lEPhCLcX']Nk@S'8DnSm`%ej[:C*K.:Cq&0`I%G5s-]['F<Jo,P1og3nDXNkF$1o;MFa7,-G3NfUCfK$Tg[m(]$?fEx'JIr*HoP0nDu42iFs&:,$]<xa$O]Ld-3@^e$J9@kEld`TCH4ml$7@e2(rOlNXb,bN1ox;&&.xn+H#CkJ-2caJ%AZ4m'Q>b#H1TpgF1sW)uBKbr.-'oFH1wWeZ>%b7MN5xc$+j#lE7_=fG.)MQ/AXnFH+G0O*=C=[97B=fGk9`9CpgH=.vRXnDi,V,2(o<GH%R)iF#HX7D4a=gG:kTNCcAZWB2x*,HO9C9&,X)pD$*A,M&bT$Hx0ddG+u3cH$YX8Im&4RDBI0W1#mMa%E44W1,gpKFpqY1F.]eFHC_nFH7<7%'E#N=BhQ/jB)3fQDl'vLFc^+F$(#lVCoic8.w2J:CVjbj(kj[:C^O.q.*-d<Bfs*u]9[it-S,^HPa?1sLXeec$rI5#H<i&gLV^8.G'xZ6'tg.>B.:OGH%i&_Sto#$G*>HlE%pN<B6]/B&wsn6D8jE<Bv=&ZGl2pgF#%SiFPpNW%q?`9Cv%,s/lF+7D'(&2FsC6.33mpOEnk,-G'ebfG?mhU19_16M),`dM/^&iFqmmt.s4/:C=^[Ht*XPgLd?/U1wo(*H^ol]8`;14+RJk#H=SvLFc+`V:_7FmBksaNEC<2dEO3j[8%2=mB2<+HMM%^9C<vFHM,^8eGpv[:C4*r$'PFr;-a0]/MF4TZ.3r*cHJ8VT.)dT4E'/h`$@6wcMO'crLuVOnM*`>>B9a,<-&>9_-iFkEIqlD<B1rrp.3g@qCJSgu(8D+7Dj#'NBqT#)/g)9NBO]uZ%u/nNBvE;9C%o<GHVTkCI-3&gL<#X1FZ/)=BxMpgFn%Jq(]W*N167lpLc[e]Gk9IbHgEbb$#&?LFv4vgFq?vsB=i1nDb<&jB,p?d$?N.EFXJitBo$9I$CtCnDM/29.-)e`%Lm%aF/lfb%F6O_I;U%:.-KFVCa=$@H$?,0CLfRV1+oR+H%3+HM&+xaFn#_(%&TJ>BqD>gCr]TSDf/#gCu)U_%7A[V1<cD.G`SM=B8GM*H6M[rL@W/eG9d)=B;d[%'3Nn*74G=UCwM#hF5A2eG#k3CI0]umDpYHaEI5FSMbWwaN]+EU/jRT0F=b?T)0.I68t%4m'lShp.JU%'I9>tx'BqhjE;j8:)#T@UCR9?:2QPUk+-n.iFT#:[/i:kjE,&YVC6Mo/1.p>LFkx0VCx>pKFqH7UC/hViFvoUEH*92=BwJ00Ff]DtB,uwFHm:/YB?pCp.2)2eG,kWe$LBwgFvS>LF-g0eM.HNhF>.JjFw.ocEwNNxH.DqoDZaK(%'ZPhF(iovG+ieBI;9`qL>]mvG8m1U13/?LF.Y8vGHT%rL>[da$>iE<B)X9GHt/_$&>vZ<_8Z9GHu#00F5Ce20?LtCIh59kEsoc3=E'0`I$:LSD%#[D%Aw?7M?B,gL6ELgEddN2B:Rg%JbxeuB3rw#Jk*mlE_aN2B(-+;CSjusB)<s=BZjSNB'KJUCF$paHvd+F$vYX7DssNcHiT&NBYZ$IHnSM<Bo0ZWBVBM@[0Z*hFxjeUCblIuB#-omDq:vgFbD#F7@S1U1;%Ia$8YtnDg1vgFRK*N1;anrLQ&TiFi[D[%&l0nDu5A>B=+?>BqJb7D%E0SDqp/@J6&Z0C'vqEH:vCU1v1rp$#=%eGA^4-MFjL$H$39kEoD;]&mcJ,MX$sgC6e:qLVDcFH$dUEH:<#W0/q:HMA2(_I?=4GH>n#gDflQN9w)ZgD62CoD.s0IMOxP<-cS?X$Au/:)M]C<-D-Xn/+^,LF6LofGNh67:Dp^>$MavcE/uU5/;c^oD2E@qL3V/eG3/?LFk2'D4m#>gC6>LSD^)YgC@%jMF@S4VCfQ$C@([-hc01HkE2E1U1ri^oD'Z9*N%i'`$Hxk)N9geoDfX@eGj6vsBl*,F%>A],M]:[A-2(DT.e#00F?L.6/K4uVC3p=HM%C>UC4I+,HI#=#H%KD$TECGR*WNnM1fO`iL4o=g.DSA>BUJ5HMm@W:/2ZX7D?m'IM]oG<-05IA-Iq.:.3mpOEj*q'&m)<&GF?,5&R,:[0$0p98W%oP'W7h,M9QP,M29MVCuoTnDaIxe>tdM<%GreV1uW+b$6O'NCoI`hF0N<?$4(x+H)>^;-GHHaMde#Y9GGZZ$#ZB8Du6^e$I^8p&:$'IZsvZt1=KkbHfH76D%pN<BeJQ,>P';q:E4=2Cd6Dv$t4oG2`V`9Ch%e&F+:+RBvSpOEs-ST%A@?lE$HX7D?l0WC&f%iF/ToUC+V3'F0QA>BC72VC2KfUC.WlpLR6U0MKW/eGq$)*HRALh,,u0VC1,k<Bvi2E%AKiDFGDRH;E#F^G2)2eG0R1[B@'f6B=xn'I0#(eMrwoTC5#Ni-5t(O=TEpm/dP;9CJEg%J3CRm/&QcdG*kIbHbr?a.A`KKFx:jf%(].Q/e#00F(C?lEnS-<-pM9kEl:s=B%IHlE(0fQD-*AfG9wFnBlI8vG,&D.GDQE^%CqhjEt&@G?UvM*e$X@X%D+s.G-TOVC$f]>BpMZQBu8_C%:5$1FW-P[MOMv50JU;iFx_moDJr<EY#5Q;Htg`9C&b;iFg$V<?)=eM1rWpmBuOhVC2(8fG;Fn;-F+WY$>7'=BnCRw9].@h*pt8S3ntUeG9DFVC(NpKFfvs2B+?fUCA6e?$+PZ1FhwuLFPa9hPVBDVClf1eG_i.>BfpAjBW+i;-`aX&=8I;s%:OOmB(WKSD5Oem/uNrTCa/)=BV,GG-N`Ul/48vLFn'VeGvTh'&,P50CFZ3sLVh-%Jto;]&o;(T.2ve:C8#)t-q7&2=c@QZ$0mX7DKm*j$Ml#hFpl2^F4OFnBh(3#G#Nq(%&H,-G5afgLNNPV1=9;eE^<Fb$,&iEHu6^e$#o3U26-G<Hh0i]$<r(*H.=G<HoKIqCH:Xw04=.FH7'g5/7rI+HdDLV:Lr;Q/w)bNEmE32B[]GKF_HjMBljeUC&t3,H)8M*HLtnoD^B&jB31GZ'K^KT.%gcdG<.d<-'&R6%x9rdGnIXHm5YcdGiKeQDo//>Bj<b$'SNVVC-glgC;_1qLa/.oD,'[`@%-4'G0]J>'1VmLFsBTU;%?W,D@@ofG`8cGDr;8>BTARQD]8:)EeJ`X':=ofG7mqU1.T^kEtf_DET[G<B_G)=B`9t^%ui.T%FicdGg>S=B3F+RBx/_C%)/2iFfH'(%:(AJGpMZ]Fq`o=B(hrpCmd2=B1G)2F`Dd<BmUJ$GG(pG2Sr:U1E4o+Hj):G$1&$lE-(rP/-l2#G(D+?'7e5gDTbW0M'onc$*06h-+tCTLet6q$;DI@';2JuB'>ZhF$+]iFuO+v'TU]6BEm3_GNreV1wkkV(ajr]GM[X(06;FVC#?pKF^coZ$`?(4Ct5/:C2<&NFnGb7Dx7S;H4m]8&BTDhD-2t<B$P=sHtYcdG0KX1<FBT*F%-C_%L;.V1)0X7D>Vvt$NQ.SD[pFq:nR?T.^';9C`r/0F2MViFo<]*$b2$d$e^nmDpi#kED#)U13JvLF=*001-g?`%eHiTCm1^L24F@Q/0u(hFhC%eG-P#GF($OcH7GqoD,C+RBn#(C%(mX7Dj'lF?9<Mj9&V/^&01=GH8&omDf3=b$+cR+Hhm%=B+,2eGd4KKF$O2=B`#&=BP04pD+-+;CgIBOEhaXb$+P`.Gp=MhF%NZw&9F4,HLTcs-fZ76Dk_IeG@,:oDW/S=BxrZ&F@7fFHjor='8FBDIHErqL'xXrL?WlFHwDHD%=VmLF#Jcw$1AViF*1GwG28$lEl>*$51gpgFqA6)%*$/:C&4><H#*fUCAip=Bp8W:/$FvsBpu-8;9i5gDIjwrLnYrsHSD&qL[omgF(46?$,-]:C*;^;-Z<J3%ah+?.#klUCh?H<BLgBq7580tq@[Pj;vxSr-DlLO+rdb5/<]>UCPu^5NlcUcH$V)F4c7T0Fum.>Bsu>kE980[HlGH&F:';qLJ9Q-.LN7rLRdlFHu$AiFR&;GH$NqC%A='SB1%KZG&ZfYBi$Q<Bwk%2F)+c<HT9Qq2GGnrLHQwKDlVrt'cr=fE3=PsHD&2U1iwwa$+BXVC^BD<B:,5-Mk]X,1sN76D^DtmD,M<?JuI*QBrEZwAM@O2C/Ol1N-ErVC+<SgLB*:$JuLBEFSNM<BA4oFH`(l#H;CDVC?ZerLXvQb<fNh0,f-]V1nov`%0cD.GEZS5'jcpO1vMFVCnhTSD$QxUCnVKnD(P/#'[9Fp.eQ%UCEs(U1/gnSD&B]UCeer2%LtnfGs2$@&,Av-G?r>LFCud'O32dT%j^M,D-6A>BpM=UCC%fV1(8$PEk`CHD:=0%J5`1eG,&;HD3pOVCNThV%v1:dDk2'kEkS(dD+J;iFuT7FHs,$D%E5DU1#,<&&pZ3nD'>ZhF0'D(&ome_G8CffG#WQ%&'BXVC/S7FH(*D(&Nh1nD$DJvG$pN<Bv=SvG1(^b%+bDPE0.LEFp_DPEwGX7DI)R#5Kk7fGZBO'%'-=nDj+&vG..#wG0dxYB'N_lLHOP,Mw6T=B$=5F%>CvhFjrW<UnGb'%[2V,2&b;iF&]J;Hm#6`%vMFVCps.[$e5#hFp.mgFHlnhW&3INBl';9CDl'oDUN8jBurL*Hgu#kEsjitBwf^m_=w*R/uvNcHkWBC%Z:OOCaQf*$app$&hQrXB-'8UC4V[q$/p.:C1d1U1,8-W-p>E*[>7'=B/8jF5?x1,HjMlGD0v,hF8/jEIWC&qLCC,Y'v#9W-mQE9rpV0c$r$,R<*x0VC152eG$ZQt.-?0@J.f-LYT@-thN4MU1q6s;-Qe5-MN+f^$M9ofG)x09IRmJt9DrMw$oGtnDfdANBAq1qLiRhjE+tLC&>FvLF&*i_&a,$&J_WofCbD(dD-rI+H2,VqL8'?D-vX1h&7$sS&Vx^?HJ*+pDji%>'-))iFF7XjC)'W=BYmmJXIKMm$C/j#>OTgJ)m-I-M.:Uq@#[at(mWvV^Q6`eMRFd-&b,-<-.T9kE3YcQDa&?%&+nitBlmnmDd#&=BBCwgF;1K%J<(ZW-S]:w^1[%iF(NZw&#B#hFF($edVqDmEbIcdGv`KKFgn_aHhPZD%$8vB82`DA&E44W1=(x+HdU#(=v`(Z[0'MHMBD#/G$)qkEFB:hG<1D*HG:)*H:MYn*/a)=BorAqV.;h;-E_VX-Sc)F.$V=UCS0'IQ;i,ZHA7S[Pclq@-H'J:.&sGPE&lCvHL,xrL[ErP-oc[m-01;N;5Co6M&QXaE7D`*H(a-F.XHBuA#<adGERF,Hmw$q$ZHap&<cD.Grv&<-6@iT.-^,-GqsOg$`m`>$O8O>H>74r$+6[L2TqxV%w2xS&8Kr3=g9`Y9rtdh,v>[0Y-9^e$6XZ;%C0hNCA$###$)>>#SlRfL0ecgL4KihL2UR6/e<H;#X:OGM9]sfLtwSfL$;5ci1jAFM$_['Vqr)##G1Z'V&2@AtvbapF"
sf_bold = "7])#######k[-$='/###I),##d-LhLiHI##:RdL<wv6:d.Y9d2U*El]?GxF>reY*b)kwrmR8T9&fHJf=2EO$9#,LL2sH:;$[[n42rpc;]E,>>#f8V>6l%lj;x$4CI)TZ`*0PUV$6PV=BC'84U^fIfLGqO41U1XGH+XI1&>.KlSAV+41xIk7D7(88UFqj4S8Vus/9.0%J/?4D[$2M>6pVG29/?K0FqPYT*&+8>,rb4JCV,d<B9p0m;((l?-BS<^-TT$=(*ruf&=(m<-f&g<6<_[FHkT67aT6YY#LhFJ(D&2eGBw$SkAXYippWbG1e1JuBMW7+kWcp%kqLD21LJ[^IfY$g#(,>>#d?U&6+>00FcUc-Vs`cipB`+/(<%S+Hu;S>`eEluu3(Ih2jcFVC[Cb/1v%0PS;A:@-u9BoL5V$##3NeMYodPirDIm##FZC5g)<*QMW3@_BMe46ukt3]%Y;Mt-^.=GM9(lO16,_%=-b:ZY:f,i^rf[R*Qqkh#.v66M3SGs-uMkGM/45GMSn)$#G4>;R7kZ$$Pk7G`,V:;$,aMSeq+55T,+U^#$fv_#l;Mt-[CFcMgMG&#@5h'&wWj-$(#LB>jVA+#*oI`tU,K_/?<Qoe9sh+V?q$?$FMlwLqVG&#5+D$#V8,HMUcg._^-0gM8,&,rqx1'#/@g.$E<x+;8uT;-]]gTS:,=<#id#3#EBT;-Ow:EN'$&<-H^MqLt]32gEAS0$L?eE[+(YT8MiKS.gf:SI&f9#v#/4]uYQ#-MecT._[[*]bxjpuZJe,F%'Xn#M6go#M/Gr1NlJu=$=+*/M@9jJ:UUT/$#0loL._pV-#B);).jKP/5tASI-x,Z$K,a0WT38W$kNI:$%9-_J4x,Z$=&c<Ng+-h-3(]w'JosY-fu,WIxI'58J%$?$ulQnTcS;g(b>I>YT8_7$qeq/#U/Q8.]jvx+-@v;%J)cTSvb*mJ/JL.$KN1R3NnRp&nEE5SHrODsulB.$V1s4#@978#&a?(#sCZtL7>J(#OOV,#t81/#SP24#0pkgLOWZ)M9k@(#'Q#lL)mGoL]R#.#ruR+MEF@&MQX?##;TP##$8N'MY_YgL+)_=#m_v;#)[lQWNMNJq4XF2K,b,gLSJ0T.5MQp%)o6d;E47mS4Rexk*S#GikZXm&^SMg(NLw92M#tjL#^@3#um''#R5T*#nsb.#%#]%##be#M0uhP/MKcf(xt:J:n0GAP%x,Z$_eF?-7&v[.ijf*%xXlS.FQ[`$xTrt-Fw>tL/CTD$b[f]$2?vv$m)r_$EESx$)e^o/^JAE%<lUc%Lm7^.PEe@%^@;=-;YlS.?8[[%_.r5/pPfx$aBM2ME$,-4A98G;roMfL[Vh@b1:.20p[4;6Ggd-6aB287;Wp92Qk^-HRT%?$u_SLr.B@;#u0T.$*L+sHN-40$n%Tk+0x,Z$5#oq.2$O`<A>H_&.jB^#Lpd.M(fU`j_6Q0$,>hQj#?V%X*[SoI>wdw'[`9F$9Iu&#pu1$#P.D9.wMdo@3@OQBGS*GMe^ZCs9_TJDSIniLpR),W3ls-$.d^_/xv4F%twqxL)br9NGImwL;^.iLgDmQ#H^8I$IW`QMO0_lNhT.DES^J.$@CKsLgbGI#F_qtMb)LM'[M4DER0SS%K1TiB.%$?$LFmjWPdp5#[m4:$$Hq'#krpV-BiU9`di?^5+8]iB=PIa+fGCfUhkF59]^$#QN3I21CL]PB2[DW%=Pr%4HiB^#h$/SS<X_P8Zcw`*@e:#v6P[8#4'5p.@O'5Av*N/$Gtc+#.`P8._<GG)>%$?$i'jbNe0v.#4:f1$cNo(<97Q8.?S7A4nrOpSGWKVmN@m-$Vj[87SP`lo&6piT+].,V;B91VPE/AkM'?s6Gd,8n[ChrQDQ+,`?gC#Z'ltS7fA3?Q-s*Dsk1po[fP6se82nrd&JODFlkSs7]%r]=R9R9SGeFg(#a.5f&uxD*6+ss@Dq85Jcc*W6pm2sRI/d-?uYE^#2H(xL0_KA$_K:.$lsKk=PDm92uw?0#rLs'MCMS0#>//5#qT-(#$86L-if1p.8K52'#JEwKE`l%F#8T;-Rs:T.`xGv$?M#<-Q[lS.69PB$GO#<-h7T;-D96L-g8Bc.p:Bu$#5`T.Xn,Z$YK9o/#o<&%SKmC%.m7^.*j`w$;@;=-oYlS.G,Y#%%BRm/vs`[$b`)%$Ve<C4cCp*#mYl##A2rvu:QIwuP9M$#<h-iL$Lx>-WE(tLR]+8MS(<ZYg@R&b$up>$I'B`&,s*9#CV,+#7o;<#rWq'#&/`xLlfD7#OQAvLDMJ87IR1GDm)do@cO6SR,]9GD%']._lE$#,qT$#,`Ux4A<T*#H(IV8&3X5,EQhfcNbLfS8-x<2CV>:&5s;4&>j??/;`/EvQ_>IcM>fW>-6NgJ)@`w],B5#sI4aG,*omrc<5jcG*h-_M:pv7)=GbL50q)SD=mZ;,<OT&g2'AD8AcU+p8q-#6/rsZ(#Q>t9#T)O9#2p($#QN$(#q2###lht&#fWg2#K/w(#'njjLMj@iL0,D'#>gG<-^>EY.HQ6C#%M#<-K6T;-3;2X-&60F%uRm-$amo-$n=m-$qFm-$i.m-$5@n-$STYJUGvV`NK;#.$:%B*#XYlS.;*.8#RZlS.69s<#bZlS.+xA*#[e6#5FOr$#pWA=#24T*#^J]5#+N`,#'Vi,#3PPH28$<ci,#VlJ'####VX$##7o8gLTX[&Mf<V+$<UC=MkL'B+OG#.$(4nJV'O'8@QO*3LTSi.L#rj.L/:LB#fwK+$_HwqL9x.qLQPwtL&MDpLq@Td#lN.d#4F/*%O]#9M-(.m/Ko8*#ES5+#>TP8.;](>GPE<j12m1_JV6(&PZKCAPT-c`OIPuoJMuCpJf1_._TQ<j1Qc1F%[8=8[B4.F%:Mc-Qggg.U19k1T+96>5RI5igM8F>HJgUPg%2-F%e'VF$>O*]%k74e#0I/&$@D7D$+RPF#0Zu'$#T[`$m1(pLe61x$^#Y>%L]]A$H,iC$B&Ed$hEcB$i)s[$Hx8kL_mUa#?GH_#-&E`#6Gt]#XlT^#x(q^#wjSa#`)xU.[@k]#lT3N0-o;%$_C-,$=@BsLng%K#F3)mLd2>]#'KP>.:akXlkbg36O<2,#E<uoL^;-6#N6),#(nk&#3`9:#h54h+@?=<-+R%K+0FEWAf-n6%]BjjLax;G%v%mlLgaamL8wB&$sU:v#FcqpL#xSfL[1^)$fb.1$r#?tLft,wL&[2xLWuWuLM@w/$w5GB$+TWjL?/Le$Ceb2$7E=gL#9N($#7)mLPS<,#Waa1#((W'M&V>W-Rp4F%&jp-$rJp-$f/5.$/2[qLYu87NsmMxLZ12X-%5-F%UUt9))cF]ui5Ok4#M@_8@E&:)wJYw0Pp&vH&lhiU)DF&#v[9#v[&>uuDY`=-E6T;-qgG<-46T;-*;t;Mfc']X#C]`XDmu^]<8mxM#^#f_Gv=R*%_2R3pnH:NK9#kM:xoFMh0S:N'RYO-dX`=-k6T;-j6T;-aj-2McDT;-7B;=-<g`=-_N#<-J19s$w(12UCFt-$5]$KV2O)##6ZlO-/1I20G0*##Bn)##VSp-$G####%c.3DkV5;HlxOPTHse]G-PNh#'EC_&R)###C/.8#qV/=#@>niLKJN,#gSf?$wUI>#[qt3;1sl-$1]Nh#U*Se4i/K;-$8;t-q*skL*xcW-0N51#dGx<(mCBO;9SEC&siBb.E'skLl1r.;$0>1#l1?1#kXRF%a:[b%pxit8Q>ER<m5l'6[2#H3aa+2MhVAO;^f?#6i)B;-ki&gLUnFSM/4i*NPx$`,59'G.;i39/>@5F%#Wgw^do>1#E,fJ;f.;t-rBflL]shtLQZ1H-Q&ChM*SHhMq+]:.JPON;0<I/;L+LS->X?T-$-C<.%]mc4.vi6<Bni0MRT=Z-6=0@'infERHa6p8k7WM-9r?a.9)t3;`L#hLG0=,NN:Qs-S?'/Npj0KMJ*cn0(<%/O.2&F-+cGhL0m8O;ih=n0ilHw-L:.6/*1pJ;3vpcN2&KgLukj]-?gc_8SfX'86b[1M#`OI)L@h%'cY'Y(>Jkq0KGMU%`DhtC^cLnL]x23;ewPhLp5KnL2^Ps-uiUnLRbQLMf%bq0)Hg,=^?sIN152iL+;Sr8[NVq2W;cmL#<TnL0K[e42F=R<or`t82%*a4j*=7/ZU9L;u,UnL;6us8J(LS-$Lx>-;IViLRKQM;7]1F.kgSe4Tx`3=w@v`4gOT8/ipLp8_NJnLSi?2M>Ns3;](-OO.#s<LiruH3UHt'6;;jt8l6bq8u=e*.FBflLi;TnL*Sxr8v'u<1PTEwKln4O4VVF$K]b6$pYNk'6vRL).]e@lLN9us8K<cKlDgLb.^vJ0Yb9+R<rj+XCJ?xER.?[J;5;2ns[d[m0)+/&6W.h&8e/e[':C@k,_iUnLo1O0;ijUq;,[V*@DRm^o('I/;axAgL<m$I/o[(;&N?AlLSpj'6FF>n0cW&UMN.Hc4VGZh-2XeTiFBflL;,elL3(id4cI:32]jTnLYght8+O?p-<p.Lcm$>p8K3'njVMLnL5*UE#fNi63Xwg+ME7-##JW[(#0D$o%+Vl##*#5>#5]:vu+c($#,SGs-gRXgLV'<$#.SGs-k_kgL_EN$#.mx=#ok'hLZ?a$#2SGs-sw9hLc^s$#1go=#w-LhL_W/%#4Ag;-9YGs-&:_hLn&K%#4af=#*FqhLdv]%#:SGs-.R-iLl>p%#7Z]=#2_?iLh8,&#>SGs-6kQiLjD>&#F4@m/c6Xxu=BO&#BSGs->-wiLn]c&#J4@m/kN'#v@Zt&#FSGs-FEEjLru1'#Lx_5/sgK#vsrJKMu1M'#Px(t-O^jjLw=`'#R4@m/&*q#vG;q'#NSGs-Wv8kL%V.(#V4@m/.B?$vJS?(#RSGs-`8^kL)oR(#TSGs-dDpkL17f(#K6&=#hP,lL-1x(#XSGs-l]>lL5O4)#N0s<#piPlL1IF)#ZAg;-bYGs-uuclL@nb)#Q*j<##,vlL6ht)#aSGs-'82mL>01*#T$a<#+DDmL:*C*#eSGs-/PVmL<6U*#m4@m/[r]&v]3g*#iSGs-7i%nL@N$+#q4@m/d4,'v`K5+#mSGs-?+JnLDgH+#u4@m/lLP'vcdY+#oAg;-wYGs-HConLO/w+##5@m/ueu'vg,2,#uSGs-P[=oLMGE,#'5@m/'(D(vjDV,##TGs-XtboLQ`j,#%TGs-]*uoLY('-#iU)<#a61pLUx8-#)TGs-eBCpL^@K-#lOv;#iNUpLY:^-#-TGs-mZhpL3@xQMc_#.#oIm;#rg$qL_X5.#1TGs-vs6qLgwG.#rCd;#$*IqLcqY.#5TGs-(6[qLe'm.#=5@m/TWb*v&%(/#9TGs-0N*rLi?;/#A5@m/]p0+v)=L/#=TGs-8gNrLmW`/#E5@m/e2U+v,Uq/#?Bg;-IZGs-A)trLxv70#I5@m/nJ$,v0tH0#ETGs-IABsLv8]0#M5@m/vcH,v36n0#ITGs-QYgsL$Q+1#KTGs-Uf#tL,p=1#0v,;#Yr5tL(jO1#OTGs-^(HtL02c1#3p#;#b4ZtL,,u1#STGs-f@mtL[19VM5P:2#6jp:#kL)uL1JL2#WTGs-oX;uL9i_2#9dg:#seMuL5cq2#[TGs-wq`uL7o-3#d5@m/M=g.vEl>3#`TGs-)4/vL;1R3#h5@m/UU5/vH.d3#dTGs-1LSvL?Iw3#l5@m/^nY/vKF24#hTGs-9exvLqZMXMDhN4#vYwm/g0)0vOe`4#lTGs-B'GwLH*t4#t5@m/oHM0vR'/5#pTGs-J?lwLLBB5#rTGs-NK(xLTaT5#M?0:#RW:xLPZg5#vTGs-VdLxLX#$6#P9':#Zp_xLTs56#$UGs-_&rxLV)H6#$Cg;-7HwM0^&Y6#T3t9#f87#MZAm6#/6@m/<Z=2va>(7#+UGs-nP[#M_Y;7#-UGs-r]n#MgxM7#Z'b9#vi*$Mcr`7#1UGs-$v<$Mk:s7#^wW9#(,O$Mg4/8#5UGs-,8b$MoRA8#aqN9#0Dt$MkLS8#7Cg;-E[Gs-5P0%M$ro8#dkE9#9]B%Mpk+9#=UGs-=iT%Mx3>9#ge<9#Aug%Mt-P9#AUGs-E+$&Mv9c9#I6@m/rL*5vv6t9#EUGs-MCH&M$R1:#M6@m/$fN5v#OB:#IUGs-U[m&M(kU:#KUGs-Yh)'M.-i:#rRw8#Z[Gs-_t;'M33.;#U6@m/5@B6v*0?;#QUGs-g6a'M1KR;#SUGs-kBs'M9je;#xFe8#oN/(M5dw;#WUGs-sZA(M=,4<#%A[8#wgS(M9&F<#[UGs-%tf(MADX<#(;R8#)*#)M=>k<#`UGs--65)MmC/bMFc0=#+5I8#2BG)MB]B=#dUGs-6NY)MJ%U=#./@8#:Zl)MFug=#hUGs->g(*MH+$>#p6@m/k2/9v?(5>#%35d2:XI%#?1Q$&*;###7:Rs$bdj-$1]Nh#+]bGM:xocM2L>gL)uls-gR4gL*;^;-.GNfLd3Js$.oYW-]N3L#,.$Z$U9_.$W.iv#vL'^#(rB^#[CbcM_]_lL7ekp%Ua[;%Arb_&:fA:)*&5W%egE1#Pm8u(i9fnNf3$253m).$j`#UM'b31#oA[_SFQ&9&@O3T%v.,w$;(.s$h[=gL*OP,M?lu8.;r1Z#9-as%=@IW$HQEs%L&l?-)L&N-RpI/M$aUQ&BRw8%CFRW$8oU;$H-'q%hn9dMHIo>-$[D^%NQew'F[CW8(RcGM/[(dM+b1dMpEo8%]Hn0#:$wv$91Is$M/tw9SZS2`3AAF-w1TV-[vo*%w(ffL&CYcM)DMt-X+x+MdgAKN3k5pLpCu`NagoF-V2oJMla><-4d>PMHEh9&OcU;$xe^>$G&i5LU9f8%pZ2Z$7(gGM9h.u-dOXGM1H5gLKWbH8)V@_Sp))bRQ/L[0'AxfLA/gfLLc^<MHNJW$>=[8%r]]6E==Lk+u)iNXIg9[0*46Z$^:%4=f:IW$Bhjp%>@Rs$=.%<$T_umsKt]6Ed6gQ&/x$m/GqAm&E_ET%j6K$.tUKp70C>+%2M*dtD';IMcD:p7c;vV%LT:Z@2:M9.4(7W$kC,Z$/5F#$&4H?$;RNp%_7ofLGsMv#^dj-$GJ4$g;wvV%#og>$lkG=&,CZ;%]mV#$W?n0#ge/Q&6uUv#?R3T%hL=,MOwi;$lNp$.^7xfLh[)Z#FWE]'U>>k,abNT%rE$*NRq9K-VQI*.iUO,MU%s;$/[^h#-ub&#Qo[fLtt]+Mx?c(NF@H>#<.k-$+pmw'vdSe$[pI['E&>uuwObxu?1Oh#4iWh#rle+M6&LhMRKp018@RW$3JlY#/AP>#,UEj0Fq&6&*;###:Lw8%NnR<-T[_68<wSe$#Ln0#ZN3T^;^uk-0eJQC%Ag;-ad'h$W17W$kRB%%JVk,M9lF58J)q>$'?SF.DHFs-vU^58d8*=C^bNT%%:;s%8@c'&@Oq0,vxJ,M+2Wf%UG(9T,FWM-?EiM%<xf:)C_V8&xs3%pS]Ov$?<Or.EU*9%AH9-m_.iv#AX39%h_O,MbW=9%I[ds%=bsp%=9WW%?Fes$N^.C84Xd;%9b.u-mwt,M`cF9%Z#0(/<kJm&0>3T^09)38mFI%'wZ@ZnlOdxPMbH29xYU4+S>:X-uH-1,KmKp.=n86&d1QY:Qev;%gqg`NPM:[-K2+03nnG=&u:ma5[GL[-AfF?I,_:)NksWV$5mt;-2DNfLJF5gLT<f8%T_Kk.;@[s$)rql/AXET%:Cn8%fsZT-j#Fs7Go-@'F<Jb.Z2Fs%/t2b$[ijpB&@,gLXv^2'jgNh#e[ns$KkNT%$0m%.unc29eCZt1&`h58G,Y3FE?n;%d#Ke$,UL$B)=d;%0rP<-`?qS-nP8n.=FRs$+DNfLi]k5&&+6Z$%(Pn*X.r;$`'+(M>e(HM@XlGMjlA,Mnx#l.3cCv#ODL[-i8g*%V4e8%Q/k<:Z@e8%C+hsJ(q;b$_2i^oMRqw'KDY>#bQNW%G'BQ&[SL@-@uC^9O4?v$Qtd8&.&6t$T#5W-c2Gb%r9w0#vaAI$F&>uu1r8gL((#GMM_qm8S3,F%>LY&#tadL,0Tiw0uik05=[u&#4La5&w;&%9b<-$$Fwjp%c==gL,$#L'3)I['Wat/:_Z;s%$r>v$%4)W%#M&K%ZR<T%s5JKE)[(dMES,W-h5,F%;MZ9.2%R8%G@1Z[`gkp%fx0LMZvZ>Rj*wm%4,Q=-SfkO%:;hBfXEE&O?uaB-N%(29>nTdO=er=-aJ+kL,^Xp%,XJj-j8,F%.f1T&XMg9;e%;Z#Iqs5&ALes$Bh/Q&>'e;%?u4G-K&h8/FeNT%qhFgLl>lT%CXET%>$p2'HUw8%r;$B*VeNg:'@S3MuGY1'@fg587:?X1[Cn8%bO=gL'*_)M2cAGM:A6:(9P#m8mv`8&$?q)M#2K;-4f8,M%a+p7HJl'&///CSD?*W%:I(AOfs`;$0SafLF$ZhLodZq(SPc;-'8pr-b@xfL_?o8%PgO<-5V/GM6J]s$=:.<$kkC[$BOes$A[Wp%BR[W$/OH?$9I<T%jeOgLWBf8%i_FgL*RcGMsM>gLQ[xs$E$96&6bZ;%FEeZ$5]uY#jtXgLl<AW$#+cgLhG:q%L?B6&CFRs$#lui9KN2W%aNw0#3i/I$'nCR<)?c'&>'%gL6g_q7qvSe$dR[?Tu?n0#aUa5&8lCv#]:xfLkLfW$T0[*@Y:wS%5oqV$Zq(?$ce'HM;)&C'ZC[s$?9]>-U`h@-2rU5/;Lns$lX4gLXK+9%Uh1gLo8gV-pXW]'7]sx'D0ss%LB,3'+SHhGmn@CSFgQO)_B$p-g=YB]LH%gL7;gV-,LjpBI46>#Jd0T.%,,##Q/IY%(-92#oSY/:rA&F.5rpgLtE[Y#F'9Q&3xH8%)/,##9_/Q&RpC0(.>uu#Eq&6&7W]_%bt&6&07l%(U.*h:@EnGXu@/,&-@Z;%Xl(W-eZ3L#c*96&lX*NVv.wi$P`Cv#47(]OC-_Q&fN4=CU0xE7Fw(,%)?f8&:X6xLeN=T%Wn$W%VoTA'Q&9p&(O%T&5nnmLt&:q%(S(X%AFnS%GnNT%i'T*@/lXgLcskp%CUjP&>1^gLr`=9%%)>nEb*KQ&mh:W%.*We-%FT6&L<,3'GkWp%;7e8%R-bT%@6jAdM=Cm8E%%P+M=i29d(%@'*NTW-^@[0>a>P[R4Q8(%DIatC]-JW-thU?^H'F[(GH+<-nsSO&Xu$W$5xq;$qd<-X]Q=T%$><j$T&2(?'TM&.wOBp7i1?v$rJ>39O/Hv$7`JcM,Px8%f@ofLc,IA-01I20Bb<9%DR*T%vc]6E,SY8&'4Qv$xho6*?=g*%]es5&sq2;&Ie<9%Eb<T%;1%<$A0gQ&@O3T%W,)O'7^0R'OWPn&H_ws$8l:v#)?qjV7(vW-cT3L#Bn2I-HT<=(G*.@'T1[8%c+g>$mt$T&-5b>$,FZv$l$(-Mx:_Q&:C<p%C+1Z$>t7Y-2vXj)RLSrLL&cO1D35N'8%`v#Ew8Q&xKsT`;9p&Z&C>,M/./W$qXW]'8`sx'?kV8&+q*Q'#Y]q),cXgLZx%W$VEV5hemkT%SsAp7n3Hv$IaOZ-`jj1#(ucxOK[,-M]#8JMX3Z-MwEwu#H3Tm&4+eS%*/,##;nSm&V,iK(/>uu#1NE9'NO.f$Tfc;-q`dI%.fOgL_#Bl9RsJe$#Ow0#`hNT%sh)<-w.N+&S.%X-4[jpB7qU)N0OS_%jHgQ&f1@]-gZ3L#@YAF%31LdMi_%/M5m,t$5wrS&XtUtUe/WE,bv[I-B[cHM3%pcMR2idMGU<$'1Y0gL3v$R&Ge<9%Fq&6&Ebjp%L*BQ&t0nW_2oFgLqc63'D3pQ&J*06&GnaT%mD,F%m<pm&L096&H-^m&@NJp&#,@['uHgm&@C7<$O#Mk'/4m292ns`u8%Q<-_;I:&ahnn8Z2AjiVMh<.AFIW$SY;j02r$W$2fU;$1fLv#Oa@,M4(^fLWZ0m&'S.TR%GZhL2=_&=kT8f-9eQv$Ix05OtrQk22$VdM1u6Y%x;dERe'kp%CIIs-hL4,MFq=T%FbET%EqaT%.%?m8aBvV%4nMs%wtOn*1x0dMrWFT%nEPW/FbNT%N-06&GBnv$:uLv#4X[6/@R*9%+F(hLg]Hn&Vm>n&]oHx-eR')N6VY,MvI7+%6s'<-.]GW-w[JU)_$m$'S0h*%Qa'T.>:e8%r]Jn.FkET%ux8;-8]xb-dEn0#hq3t$=X<9%Y#&gL@q:HMpRn#NosGt$Wxh;$aLF,M_w(hLICS8%LE>3'leOgLh[/S'hijpB&*C6&a-f$TnH%W%[6j5'0FfBJJwW)<9:d;%1xY<-Brbl8QLjpBTZI+Ns)'p8r7Yn*rD8@'`oK&$LE#3'4+eS%+2,##>'#3'ILrvu0>uu#L6TQ&LrbP8@_%T&URUQ8r`.Zndh-q$H:QQ8^Q[%'^_ET%*`uDN+jGp%(xK#$BL(H-[(4@8:$]5'roJ4O>6hQ&CF,-M1*`dMKQ/0:&1,F%pLQ#Pb#6]%p?'=UD3X;Qb%VdMrecgLZ$;-Mb`)O'lDimLJ(Oj.a;`0(Uf%N1Gtjp%HeW5&N3'q%sl_$'h?T6&p=;E/HkJ2'v-ugL(-_m&s9C-Mx>?3'3so8&1*Ne-('V0(Q?TQ&R-tT%C@Is$Y/v3',in,4Nn.Y-cQn0#V(cGMhPK=T*(/W$7LGZe]n`;$f*,QL1xppQ5O?hL+]rI&5aB<-x.TV-/T*x%F$Bw7>l7p&o()+7aYxct]TFT%j,9m'o9:a3CORW$Hwsp%H''q%Fnap%PH,n&?O5hLq#ukLkpOT%Ftjp%o_FgLIecgLX)([-D7f34kK^6&FN9o/EbNT%<noM'j[sY.YSnh(5o_P/Z#r,)WT,n&Zji>$&*TkM.ix,;f]f^H,_YgLV(nMMUfIR([+`;$gO=,MTV6N'@1i;$;L*9%K0k9%2BX6'A..W$?(i;$,*a*.__8m&61[8%J&J3%.7Z;%i1Ux$@U<T%Kn3T%BnAQ&OEBq%J-BQ&b=eA-a7lk%/I`YP7?NYPIt@q.TW5n&e3f$TWOTkkab2Q'4LfBJ1>6<-/c><-t1TV-Vpo*%6:c'&KsN,MS4$##D?;iLRvnfMwwSfLg+l0MZSh[-0M;:2a&5>#F<Kq%>fCv#6MY>#3@<p%^/V0(-D###*:QQ8uX1C&3%cgLd@U5%4nV8&>fAaY00idMc8$n&'8pr-0=v29D]_$'m7-68=O7_8*YCp&8^Fw&2bDs%;b]<8B'oP'K+*t&55a;S/9/_%d&G?e9P;u$b+1<J3p^p(B;t-?594m'^0_%0#`v2(`s>R&%`Ut%L3TQ&J*^Q&RBpm&6C.U&VT5n&R9k9%qB:-Mr&up%QZ(0(UleZp5(YgL;_c54TKpQ&^pcN'SWp6&O6K6&HZCK(Y?vE79nQd%q_2<-'Z5T%xnKmC*6S?&1ki8&v)'eXXL:q7l?h>$Z@tw8uvlMrbv96&4NS_%@A>b@M4)CA+3^e$lYWqBHvoZMe?]s$_vnI-'h80NvpC#87Y4O2dJQ3''r(W%3<km'[ap6&m9f$7^T]W$I''q%AJYd$o<T6&N-9Q&A@Is$ctxr/M006&H*B6&.cYs-p'(-MQ]OT%9?ST&SZ#R&oJc'&ahWp%immp-5g-hcxoWI);F</1^/7H)ZgP3'BLI<$Pp6Y%3w-[Buf=O2':s...ugp7CFUkbfl#:&B:.W$@:7W$=Iw8%t?oT%VC*T%L^10(@R*9%LX[s$BURW$>[ET%<+.W$?(.W$.Rij9]Sd;%Cw(.MQc`g(TjI,Mw`YgLUmHm8t>QZ$<=Rs$-0jB%5;n['YA'aNi.[t.XjY3'g6f$TvBn0#h?`;%[@M<-hkwBM^x7>-,_Sj-cS*hY3[7VQ2Cq19Tw-p*'rNIbibr^P#D6>#HKp6&9BJ$&w&;O'Nhal&3R8m&([R5'$pK^ODkV=-M'c<%?'#Ra;TSaNbdkp%:#S=1#8ah#&GOGMSwi;$9oV:%W;(9.]&)O'CL%Q'))B;-=i&gLiSmN'$OYq;2]kwT8R?EN;9_Q&RHgQ&0]Wh#LbjpB3?RaN_2^,MC-,)NjX_@--/TV-]HZe6VDhT.bV7L(BJJF-.;gO2N$'Q&SNgQ&UKgQ&SaGn&(*)].O9P/(;F@6/QH,3'v?:hLu?-n&-7aM-h#%uLBSaK(_jGn&]#vj'IhnW$Y`*.)UQ>3'lvmT-Kkxv$1aub%:fSq)(@;s%(M,C-@bhp7Z?AN2l</f$F'a8&RKYw$'PkcMVn?n8eB6Z$ean0#>CIZ(GSCs-1=dm8w8<W%&uGm8Pb.4=)e*1#WEsP'iKKhP;+?dM9'2hLZ#:6&%aAqDe0B6&7*KK1L<pm&J''q%QQ53'(xOn*_.7W$I$06&Mwsp%kMeuL`s96&HX0I$S8pP'bl5Q'$=LHM#q'6&c7ofLw5x:.k==.)<5d0)b]eL(WHBq%?+`;$8kn;-VK(X%f[?p&0[aHZf*kT%0lls-s*(-MUcsfL3cYs-nRxfLNA,gLm>#9%Pn3t$;I3T%OpUK(EbET%NXIW$Ebns$-P4$gV.7W$4'N'%DY8+%HUjpBpM16&Mbap%E-0q%U?96&N6K6&`XNh>_Iw8%:(r;$9Fd<-Q/tZPr`mN'frEI)brECS9%m@K.dqLN<CK0%E####e34<QYvnfMm]gp8v==KN-*Dt/KT#7&@iCv#C0ml$#0Vk'Rw&2'4[S2'(x;M-Ll:*%oplN'EJi/WFI]v$/7)BQ?@vW-BY6]0:C(hL3'N'%'JOGMY38W$w0K&vP[R+%jd10(fGkO4ge&mSN8L<.Vm(k'gR6w.]PH+9n5rC]78[w'-eR5'la&I6.qw0#GB<bN5/Me$ukr/)mY`O'Z7`;&UacN'QKP3']s(k'UQ,n&_5M0(bJ@h(S27L(pE:51TN^Q&_puN'],2O'0J,W-4-Ee-7sEI)_#mN'`d5R&KXn8%ir@1(7C?q7en(4+/l:p&1h%T&&9&@9c;*=(57CHM(]B%%^O[s$atb'=CKc'&M;>p7)5un**Du^]M2(XQ,X7bN8BW+MfSu.;a?d;%QVl[MiHo8%.U@g:gk7p&vjEkX7H:$^EE]9MRp+W-:@.w@C$RQ8k89XU)j[h('1(-MK8_Q&pX+gLhTql1UT>3'SZ,R&WN#3'rw'dMp)2hL&SGgL''M]$MFsEI'+3n'V&VK([^,R&GE4v-ptXgL^RAL(QH#n&rb0f)>GDh)gu<i(^dp6&C@.W$aEu-$61lgLsfDJ'3_;s%DHsS&/jZ*RC0Zw061lgLTa=9%NoE<qpa,n&66u%4J9pm&Rtjp%Xd^q%E6^6&>e&6&7hb?K-'k-$.ltGMwUg_-XmR$9Yn1Z$l*ip$)bgU%D[Ep%[8.L(SNg6&HF@W$1Z,5MYIx8%,t2b$q]XGMFr;JU/vDk'oFB+*brECSbwsp%k?%@KopYn&-=3W-bNn0#fB,3'%`kA#r+TV-%o,j<>OGHM2VY8.%2G>#tCbxu&`bxuO.YW8<h7u-h:#29e2P7*?$Ab.;q$C#Dm--)KU7W$<:r;$;<W[$fiRh(EuL$#DZuN''C(hLZNXg$;OUHMMxkP8`F8p&e+ZQ8IIjt(`s2*,'<P1'Z:Rs$o9UdMN>;e$iH#n&A.c%O'rfKUI8L<.Z)M0(@QsdMnSmN'EFXh#FcA0ll$IU)b=9X12-41#d?JI61Jte)9:Pn*m]ZN'[5`0(WD7h(_2Mk'XmlN'fDr0(b#67&]MMO'aslN'YjG3',=(hLo5/1(Z2=X(8N%L(mxI1(joW**_))k'JtAQ&rSDO'Ogo>em8QE&iHgQ&=PP'A@(^U)#.`Hd:'8p&%X.aN[TFT%.7Rq76PGhOuHW/Nk?]s$;DNfLHM'%%>%DY(^Mi&=aZUOb<t;s%#D-c@nu9T&'hQ*N>63393'O[9B84gLP'<4'jH.ktk0X9%w3ugL^.e3'TQ#n&cD.L(TjcN'ueo6*%3iK(RBK6&_;.h(@G6X19:lgL'ecgL%Son0gDV0(Yvcn&RK,n&sd]/)QWkV.q*;D+BOWJ1o%BB+lY7L(Kn*X$wfAqD`0l^=@'4m'10=m'.Ag;-FE4v-;eVN9Vs4R*[DT5'QW,<-GXw8%DeNT%W-X9%@es5&ZV3e)L6TQ&Z*+t$Jw*t$81^gLd>vJ(Pe-W%]%@A-O4J7M&,TgLxMx8%8DQt1.ZWE*E[eW$Z5rg(a#D0(S<tT%Y*$P.BX<T%xn,Z$:Fd<-Q/tZPx4s0(vk5c*brECSf096&]HRE.a)Z3'6Ur1Ed,Cq%)fF&#.5QW-]JU_&4;p19fRbA#*fO&#CBr*NCePhLx+I.%8:P&#mdSb%F,>>#ncoZ$efeH)AtoM'N5Z20l++.)J+`$#ltAE#-Yp;-7]5<-N'jX-6CGR*Cv0j(/Vh;-X58n$D_*t-'_HENgN@eMiCo-)Ia>X-jWM#nDvnj%.Ake)N[GhL[SGs-0bChL/9MhL$Y>W-'^Gb%#L>U;Hq>F%TUX$0&6UdO3X2^%a%hX(cE&I65641#wM.L(fZ++7R+6c*pP.L(`)2O'`d9:%jl[L(hY%1(goEe)]IdERt?4t$t+Fe)N/#6'k%0b*PAc2(%:tH?vAVk'YUj1)$Yb.)tFg'+hJiK(P<>N')/A1(Kn_,b>7Q<-CL>-MYYM=-7GNfLS#O0(96S5'*IDs%MH/>-PDXb$6:Gb%eVxcMx9/_%0tn0#M3k'8>+VY(,[EW-nsN1#RrG:)btjp%$L*c@],&gLepfc$$E24'uj9)M0+kB-.PPS.'f^F*M%&rLQZ)k'k>Tw3]s(k'a/M0(`>MO'bvlj'PtET%K5ml0b22k'Y#2O'`&dN'-30j(AGQ4(_GR-)aMI-)h2)4'b/mN'w3lgLiqte)H#>Q'1'a`+D(=b+#(ZG*lDvn&JRIs$x[Q2(-$Fm'svNh#;v*gL4-;hL3ApV-L5]3Os5V0(u2]t(4^GF%>mBN(MTP3'U`Yn%n5[d)Rq*9%H3K6&cG)S&[Mwd)Sb*9%MI@W$ST,n&Ka_,)QnHs%xK&gN(*a0(FU*9%g8nD3_B#n&QpYn&j8vN'a/;O'D[ET%.TQh#*50Z$;Fd<-R/tZP&Sfh(*IM`+brECShB^Q&<>CUM'#b**FWCgE3f&gL2#)hLJ/ld;EK%:hD'MeMHa22%G&###9U5hLVkNq%o=-r)HOk-$^t(Z54XAm&iv#V%D$t9%.SUV$d@0f)egYf(lF^58)==I%+2FI)/BT/)Sf(e$1Eg*%d2W*,Stnf$U6S0:'l5K)xO'f)1KpJ)cnn+%*SF,M`Z=T%R,i0(qqucMi]c8...H(+F(d05&/OK$?OW'839k-$%jKX:'a@L(v,k-$%dRh(nnDs-1*nENrQ7IMRN,W-18V_&3-+1#n$bD+Y;h,b<$>X8$upN(<t.A,qx*.)fPt<:vG[h(v.Oe)?,8'.<$ihLq.'5'nL=i(tuw-)iVi0(#5XI):6%iL)W=I)V`3(4/_.A,x7=I)%v@l'Z0bp%2bmc*ilk,4:pr38Fmq$'-qnP'k$1we60M-Mh1&1(wU5t&;DI@'g*$I6W9ttAJa4v-;:Hm8XBML+)XlGM6>v5MnNfs$P>Ea*d2xR3L@%w@5Zx?&Sw*H=n@]h(<1Z8&HL_;]nrDk'2OVj9mMV8&Bva%'<t$gLip*+N,Q4W'/r`5/3FvC+1h_-M`#Bh(^/i0(d>rK(jS@h(hc@1(mP%h(V6kp%N]q3(lc@h(cJ.1(iMV0(XW.JMLx=e)k(X**rYrk'k`%L(&C(hLva6c*c;`0(>g+^,IOK_,.e.E+uiiO'Ohn8%g$_DluOJL(kf[h(vjn0#7+Ke$.h[5'JK9o/ifeh(kow-)(%q`$4Ng*%'lx-)QguN'K096&cowL(NbET%SgcN'i/6n&n_5c*Tv6H)KwJm&U?'U%x^qhL^,_Q&arlM(D.XkF#0v3'H'BQ&8_AG2fvgm&W/I-)p:xL(lrwH)e]xJ&ch*t$;Fd<-R/tZP,.:+*7-o],cxNCSp,`K(]NoM(T@P'J&0^s-(L:hL^,E$#HIl^Z/oP<-vl?&'71G&#rGF,M=5T;-?lbl8IXkxuOv.jLV4$##92WV6c+x1(R@@W$Cl1Z#?Bl/(7_r@,5]###f7OI)vZmAmBk_&O$V4.)0=#Qq#PfL(/3k2(._U-M)fG<-HRYdMxCt_$2YB+*APafLiv;4B5j;W%@Hf0:0Gb05:>%E+IWR.MOote)1`9h$LxZ'84<k-$N2aH+Kk+[$wt*%9][Ln3LQ*+N2Igk$&^H&,41c'&s_iJ)cd++7DvAA,3]F.)or*I)tX^F*mkGC+xOB+*nrw-)+cT+*%;JP'sn0J)#2FI)moRh(*VK+*>B7iLvTce)vR'J)5w[],'Mbe))2f1(_B06&L2oiLAVoL(pQ*wpxP.L(kWj;-ZC(q7MPK/)@._w'.0kM(b,lJ)FDXGM83DhL@B.eM2.VT.`p,7&&HQANtOoh(&5TV-jA>F%*M+gLt^^C-B[GhL^mXT%4L)D+G:7vPD7`68lIK/)LTe6hPevJ:ekJU)hE#n&n;.uL%/;hL9<Cm88Mr'8se2<-=vo%9P(<EGrdRa+2lbi(oo[h(ifwH)b>7L(jS@h(po*I)lueL(rleH)[E06&&-Z`--wlBA+gnh(q(o-)p:9F*1+S1)j+'F*thP_+$/oL(t:=I)*R:hLoZ[6/d>DO'gAxiL4<eG*5kZc*qD)O'UQ1K(fCi8.s1FI).O6gL>:^gLj(8h(EvtM(4J,W-BO[sATYQt.YZ(0(_F^Tr<,^B+[?tp%QaY3'r=ol'i7gB+[qET%Wk*9%XX,-0TJWa*J6gm&i/d&'(pn-)ZC,x5]);k'l>QN'_YW**vR=M(p.Fe)OkWp%L096&.n@T&GLRs$8+C#$^)X]':+H(+WY0,N^6OvL0SI*.T?&49+sJe$t&2k')@lgL,Iq%%x*#'=(K>B?WCME%hto&=OEWt(m]TL58Al?,bH=9%Jtns$21n8%2bD`+XO@%#AAHpg@Z7.M?(pcMGE`hLXTbg$4fK+*;vP,*k6F,%)vw-)G1TgL9(BgLW/c?-4,TV--H0I$<if;?MQ2W%^T_W/5QR*NwW2@,QjRiLmsweM_5bhVqeOI)mAo?93<t-$W;K6(MHnq7dYgJ)7S4g$66+1#l>D#-41c'&L*AQ83-/M)Q,U;.&P'f)r7FI)sc[d),fkI)G$i0,A.-,*27Q(+tx]#,O0TK1x[p'+'uK/)+l^F*QQEe-JJke)1(-G*D$s@,1LQ,*(M0f)nB*:.8f'f)/>D/sNbggLsMoh(^IMqM/Gke)EOE+7)sw-)7K8F.gC5gL?]=.)lHf8.EhNT%8^=dMM;C5%vxo#,0aEl=27.Q8I=10E%1q`$p[C<J8jf$&$Mnm/TW5n&TacN'csnI-.CwmL(`Ps-L*378sf.R39E=1#B3Fs-KHSk9*1=B,;@_J)YSoNOB8t**h`*.)oln-)w4Xe)tIb.)#/4e)aZTQ&T431)w==I)n+F.)x@=I)w_,(+4U+<-l]Ih(x4F.)416(+vRt.)l`[h(Z%5?,$s[h(C`%U/NOWJ1B<^30;R)D+aspU%*#BqD0tn0#og<p7WnP,*<]>W-:(9U)I$e--+,xh(BLTI$`rdt1wd^Q&[Q^Q&9;dS'tAdR&O^uj'wHI=-cDi0(u)Uq%[j9U%RPMBobqjp%9>pV-tBf$7Zx7c6ql@1(LE53'c>`0(t`)k'drAb*+4UJ)#V9F*jF[]ef;_Q&P-X9%<Fd<-S/tZP3bZ(+J5-<.brECSu>`0(U0@)N<Tqf).xMi-375R*-'k-$#Q`O')fF&#uOtA#Vpo*%F/G>#%ctxuXs+F%toRfL(M#<-B9M.M6rJfL5a?<%G,Guu]x0LM,AH*OZ13_6nkK/)ZLIW$Jx:Z#Dgq,)HQXY-8f###pngF*.Bk-$61HhLML.c8o&<.-K?IeMp,tr$6^3gL$V+.)LMU[0<>`)+ENI.M5>?q(.;6j9QkwA,WJKcN0^h@-Gu+DNKg8<Q_J'K-DKx;'YtGbY2BB4Mh,4(MiB$p-/<+1#i:]>-JMd--w*In:QQ2[%g#(Z-7l^F*t4F.)sSQr%/Cdc*)i9f)*@V@,2CZ(+u):U%<er[,x4+i(0U[X-*x^+*HN%iL=+:f)md(G+?0W)+9w<u-+lTb*a/7-)HU$,*s$Y,k]B#X(Y6an8CUm9M`Nsn8I83*,i;-n&0+)W%J^Fs-j_FgL*M>s-'cTp7%p=R*ekjp%vg3#-H@+dtRq2g:$r:c%bL=I$UlxfLajsn8.h_;]q@]h(GEx;-59/_%/Gte)AiScMefXI)-B3gLn8X+N/UxS9X[CZ[7^f],4]OI)ZQxjkD>bI)k:be)tRgb*s14i((x,(+u(F.)Y6B6&[LEL)w(4.)o.+.)&Ate)<?7iL%a4.)9<7iLjd]],x1x-)vc%l'duI?pGCqf)nf71(uiFjL1Kj)+TJfiL?6s0(^pq,)00>g:i`T-m4i^F*:#dG*6g>g)@B3I-Dt_hLpWwq$6^,g)G^8T&?w;R8E%qC,cWB6&X2Vk'%fX2(rk(@,b$FT%75T;-U+ON.ZiS^+VE&Q'XG.$8`,HK)^B96&BYZt1DPfp&]p1K(1knx,v@Fi(g^T6&.fLP/RZG3'K_w8%8+C#$^)X]'Cb`%,e1_,NR'q,.A_d68;3X#-6_1hLf(s0(MJ7w^%a.l'GEx;-#;9;-xRlo.%2G>#VdJe$oxGm8-kb_/E,Y:vnta*.?T0<-d#(d%?u?X-kdbT%O3=9%4@<T%=E]],ab[%#,t]QC>,F+N>R(aN?QrhL1LMX-1<41#MQ#RaX5tT'@U`X-nP4%9DR)D+9[D`++L3r$ikUgCPcpJ)*tjr$gW/<-N%G`N0^h@-Iu+DNE0@BO=,+JMYDtJ-95T;-O_K1(59=1#2lrn<Av3@'8N0I$<Sw],@Qo6*B^41#ej**NGGes.MhHc*,o,(+1_i%,+04Y-5L2D+[sx;6>*8],Fd9;.)'tY-:RHc*,%$,*;k;%,?<FY-9F?G*8qe=-DgTr.HemG*GESx,ucvR&>crp/:RM%,J:Jv$M@)'O`@$2&H/xfL)$pjLvMQ3'/pAr-=O9E#2<&(%1L2W%.=3TB7R`t-2KwiL1KihLOpv*&St/g)LV=,M]aJ_%(hr>n>F'k$p#)O'n%EKW?5Z5M1Ysj$.>XI)JPNfL<Kb%8bt*w7ei5d.6r#c*26:V%AcT+*tn#c*&%m_+%StI)1O;%,(M9f)`Q,n&wFte)*GbI)wRte)/fgF*++$,*<-ihLf<MJ);HkY-+Yke)(/oL(_B06&/qmG*u+fL(.AujLAJPB,PDY#-/>fh(&cFgLDZld$<3@,t9F.q.&Jt**2h5b@WudG*;)2d*T#@^4g27-)_gcN'q'r<-jmgQ&]D%1(0C_j(TKM]-mT^Q&gE'q%n%+.)`.>?,OTcj''4?c*ZL;Hkx9$c*Jd&T&mEd*4+(Y6'd8r,)<H0v-(f9J)o#-R&jZn0#3:@Q'OqET%94_>$^)X]'LBxx,q[6-Nj;DmOSRFu-$FLdkv[fh(mln-)5e1hLS9$##YpA.$&EL_&sL:gL<xc<-vlZW%)W$@'9@G&#XLo'/2(Y&#?6C@./%d<-.+@F5$Xv,*c_ns$O+DZ#J><E*b(&Q0=u###-)12#Irew'P[gU)60o0#knC)NT5's7LHAnh,:hF*?8TV-i:RX1J*r)N*'MHMf;hQ&Md8o8]'N&dDJ=jLG,u?->c.4:rqa>-f&>pR+k)D+cBrGbJ4:m8nl:$%*h;`+s[1]'?Q+1#r6Q50Dmk3+lnXe$]0*S0nlC_,8C6G*='fx,3Cr%,L?x=-3]L_%nW+B,RstY-9@np.Rd=B,<$]=-DWfE+IB]],QZ=#-<eD`+OQ+^,i`6s.M)P',Ahi`+/)7i1V-W`+4(6c*,upF*#Ik,494d<-UMfo7F@8'-+q))+?<=W'BNFm'fxVBoWj@w%[LH<DQprS&4<DR<Gd+Q'+No0#q#JZ.&OQ(+*9[k=A3H+@O1xa+;hV`+4=Z(+0JF$%<+MN;7<%eMg+s0(-f=D'?3G)+Q$$Wf#4L+*8^=1#_Q^k2$9VX/i:jp/6R2D+V#Ug)+SK'+8G%i)5C?c*9wn=-;ICj(+>JP'JjG118h;d*.1v$,9h)H*E0,O-iN/Z04t*Y-;<Fu-]#oiLA.eC+pJQ7&-pcs.14Q(+&TI12W)Bk1beOr/LtHg)hd96&&`<H4lHNR%B5Zb%Cona+2C;`+6CQc*'H^<-IF%U.tiaE*cVGn%@ks6/t8?n&er3.)<'nK)0*tq.vp5n&p^K6&$]B+*kn-t-X)`K(2kV`+e^Le$Erna+xYvn&cl<I)R$Cg*6>9+*w-qf)IeHc*<U2)+[puN'[mY3'cAi0()$8ZP:QjYPIt@q.T/:Z-L9g$T#alJ)iY2a+r@FR-dotO%.Dte);>pV-g9w0#JT_r?-LbxuJT5<--4)=-8UYHM#@H&%*a8R3BHW=(r6n0#B9o'/#4Ev%OVd40_cA^+:G5##$W(P0GY7$vJ(35&OptY-c>K)(s&BW-76o0#>N+1#VE?F%B##wnB/=fM?d7iL/oYW-;jr/<.%Mp.X8Lv-.n31#/E#+%nW5n&WDc1:V`GmUHLJ60'`w92`D=/MeoaGWYDtJ-?L33Maoav%g_`8.?'8A,-X5I$@ak-$BsBI$Uh5s.?fW#-g+L0MJ*l31i7)k)2Wx],'LTX:h#Vk1oA5^,C*Sx,L8-W.BYD50R,Uv-D<ox,aYQW.Waa-*KcU?-THf],B0j%,`5q;.Y]6w-xfa]-Q;L?-rH-L2Z)cY-]N/*++dV0(vW5r/,;l,4XoLi:HP[%'AXF&,Fn1C&J6A&,56x0#<04W-?V%%'p=Z2(D%Ar%Gr3^,%h31#51(-M0wCHM$Rda$CK8T&?,kjL.UOl:F1tx'KT@,M#?S3%;5M)+@aBs$ME.iL#A8L(jleh(23Q%.WY5`O;dSc$ok9s.8sC)+Z+ucM&RHc*jgcERWT&&,ms=0lZ'JA,20fx,>Bbu-;e;)+L&LV.@[VD+7C(hLJKN`+DbDD+9qM`+Fnr%,T;=jLO_ED+=3s)+X(860Cn;`+A4hf)ns#n&'&NB,31q+*OI%lLU'tX.s?0U/G=L+*t.,$,js6Y%n,tr7`d<#-B84gL>Z]],<?xx,YVpCOCN0_,FK+#-9r4m'u@f1(iin-)E^]],^);k'/R%],?f^F*NgaH*#LDd*'X_hL5Y6n&qYQ3'.hLhL&*o.MU*DX/,2sO'i1'+*T6$H+@f>(+'LQ,*VEa`+G3J&,`2`0(c22O'jf[h(,'8ZP:QjYPIt@q.coZW.UEg$T'8.H*MP5DOk/WP06xK+**rpF*?-ihL2&&],u/9p8dQF&##PtA#D,403=O5hL8c&gLG76>#u:#s-Pi[+Mn0d,D%]bA#O'dA#]>4)#sl-i12sHn&a#Cq%;qfm&l',n0v<O&#FVd5hW,fiLu6_`$mQ$W.<A58.?'8A,6T3gL3%dW-_iU[0Mbcs.acZs.6STV-neUsJE#fN%geb31:wlO4hfOjLAPFjL$Y>W-PeHmUG`k/M4k@u-q+:KM0a+#-QvX>-VPcq7;g3^,$Bk>hEd+1#W5Lv-[MNfLp`*;M2N/(%9i=.3%m(?-NZbu-Vi;T/K7]21ZPHW.LgkY-i(E9/c8^e*S17[-_pX>-KNAA,jYds.f@Wt.]AqV.]rd<.%w;I3f]qV.i,G',1p`0(,9;S0#j5T8$c0HOAb`=-Vj4wMApIiLCe4#-tM#p8hiEx'^dOh:S,F<q*bigC`AGb%5.lgL<n$q7LAd5Lmov3''=c31w<^A,bvsAOU)kr7;W[A,KT@,Mt$Gs%0E2?>oj,K)Bsj+NF#c?->M>s-Ss[iL?Yxo7[:Z9MGp=1#K4lNb%OYU;'R1O1Z^bY-DtEa%kH=#-9N=>-Gppr.B-&a+UM?8/J3fA,uM.L(@'8A,L*/&,A?AA,QH4#-N,($-E68&,F^oa+dbX31K9&A,K_dG*v:J?pp(r?-<[mc*_qIlL^^>V/)$HR0Qe?c*&MlZ,i0I9i]2oiL6sb>-bi(*%F;?F%D.'?-B6+#-WI]A,xa5(/=%Ld2*J5_+s`Rh(5pLL1.vVk'rXT+*Q5#f*E>`11.?vN'(3?n&3IvC+uZ/n/a]3e);H2_A3wTT%Nn)d*fi<e)/4Q(+KbLb*0w/V.[oL_,O&CV.q8M0(iY7L(krw-)bZ^Q&;F?v$^)X]'n_]Q0B-X.NRwTg-f,(hl(tRj1?I?c*6&M)+eQ<b.6we=-9S,<-r%9;-J@Ve$4J'gLx*p+M@D^c$mQs;-%=$X&H2PY#Ha7JML1>cM[xocM=8pw5BVq_,$CtT%`R%w#XIuZ,<T/F4E7$##Ilds.'h3Q8LYPs.+v5T8LPGs.CHo0#C^+1#I8_e$f:jp/;&9;->Q55&?:9I$S>ZS/Pn_p/nL860#1M`EMk*^,0V0`$)J-<-_.c%OE>BHW58Lv-Ivk-$]lqJ:0*sm1HcB,NDk0KM<35)NZ7hKMNXkR-`MNfLp`*;MVjM[%pJ#G4xfQs.Ssk#-Qw:n'oqoq/ci$w-fh0K2snS60SuWo&-ILg2XsF^,p3dD4h:3t.#xJ60bS$w-rqfm08?DS0+k`a4goZS/31iw,A1FX.*nGZ.Lb^,M=(tr$aJs8/`A4/M/gO>-n*/)<).d*7[E/49'^((&@r]5'IZFs-#7ugL*G#W-h7DR<I#PQ'NwGL2VR&O=tKj68Zi?1,-Mg^-Yb_/=1#Te$v,9<-SF#hLst'f)#cx>-`GOJMFu4p7<dwA,f@H-NZR<G<x5dU9x8VX/@aje3V;Uv-875),De%=-MH8&,V&G#-WSD50YssH*EI:N(i[^TrgA1_,JZ0V.XD(C,PaF>-HqcT3H3J],[#(?-%Ys50WS_$-G9o],BEfK2`Z+#->$c<8iXsf1<QKo81Cc315u=Q'LStfMmUX/MiHNR%M`vb%XK&E+V>_v-V;q;.U??+%Lx?W.8>8L(-;fh(xUB+*V[Uj(q_P_+Y0vD47U2D+W.Tl'0u]l'-q%&,m2Dk'J>pV-ZC/R3GYae$RB&E+l40F*#IZe3U6@C+:Zco/jXn[-[`ZS/xV7h(5cLP/p4Xe)fm,n&;F?v$^)X]'w?uN1OZ0/NRq9K-IgFw&k(7W.6(Wi-[WCwKBU;`+Qd%iLB922%mHo/:;/c_-vqJfL64KgLo&S/M18)=HkuX$0uIkxuu+lD5K1w@-+UBq%f_.w#^n$X-J>c_5G=$##II[3#@No0#?AK)N,,Q98B,'Z-w3X_&B#c;-Zuf(Nxb4n0T-h,&66+Q'?#c8pUtwb%2W<.3OU;#&Is41#NP-+%T=P#[>V?W.#l%-+[c#9868*=(;*x;-*`fQ-OD58.&*&'5GU:p/I^gW$jlOjL#=?&%]=``5.>ap/^M$w-Y<i3($IlR0u:ujLFo0W/1ULO1%G`(,hNpU/v%w8/`VLv--o=n0([1o0tO8Q0s-,r/Df-A6%`s50+8I@-BVx-)Hu^/3gfh?-_;xiL;@Cm8:>[w'[P6W.(`-6%c`f50prG(/Q51X-'LFW8HSX/M92RA-?m?*&6-f5'j:DR<@^OQ'Zd.f3I9)l4FILTTK_#-M9Q^W$VK)lMCR=8&3041#3Y'f)@jDv-mop-'%27pgSV_@-N/9;-[;Pw&v4*T%6HS+4+/r;.[5Cv-VG6<.KYd8/Yr%Q0V,u#-k_f21])UZ--&+.)R&:v-a&u>-SALv-nA4jLlxm<.um;^-Zi-@-$*ae3a8lY-^QJa++^;k'h<'Y.MKAa+&qFmLkuNm1HfXi2ha&&,=:ugLUak/M9`ds.Jh1T/qxt/Mm)98%irds.Viv8/ictfM_(+$%aEi)3T6I0)2C_J)$fpb*dCw8/lin-)G#68/^'8A,oL`C,;#U$-&UI],-,8L(-Mj0(;?%iLEm@3NCid8/u`Rh(/3o0#.vYj)1xP?,'6JF4_Yh?-@GA1(r4OI)s7XI)sV2o&BFd<-V/tZP^HUk1Y*KZ7brECSFwr%,uHRE.vOns.K4(gLT1W`+GE8E+<IG&#`fjcmRLH>#%,>>#.L)gLSh2J:g]F&#JQuQ`grkkLfCq19Ai?s&+KW&5v936/DY>##E*.^5&_L&v]LJM'2nq02ZVjfL8fafL:uP<-s[;G;>4-90VaZh2rVOk%-iqp75[&g2Ymf,3@WNI3p-j;-ZFwt$GL>s.g$cW%@Qx0#&4[lL8J26Mn=FOUBlld$pqoQ0w:@'&'Ef/jPOfQ05=b?^(%.LMY@h0MZtmLMK31O1m`51#pUg$'#xW[9[iQW8bWvn0$uOj1/HWI3v%Y$676wh2#1cN1Ls/J3BqB^-+#]P1;CY31vbWT/LKaI3E59/39qqK29a<22e^(99B3iK2JUpu.T@:+*lgxE5F(3u7OJig$DZo0#gNj;-N1ip.#.,70V5l1#Sf=,MOx29/ls]49O_((&CHMB>KBtM()@DdDluCR<Sr;H*>X7&60?C[-SAhe$#P;=-'+rq7#`b$0wQ8<-F89;-8JPS.4O2D+.:XB-Y7d<-ZJNfL21N.N^Xe/;d[I$T[C8T%Utw]691cN1n=WT/]mN-*qX/U/r-#r/m@Wp/>jfF4kt+31>6..MYOp:/g(&m0#1KY.qFjp/vS`Kcqfd8/']Jq/MWwH3x?,;/bVQW.Z;QEnl439/m*[J=$lSG2o6ZA>``Gc4Mwh3([wF31TGNfLKkFn0)Ht;-D-^o%r%r?-w',R0x'Y31wMt*.@@Ha3)=Y31K'bU.9+H(+Z<.>6N7cI)5-]A,*e^^-l^7#6OM+.)F;/1(T>h;.<]/C4wtu$,#PwA-Zf&gLcY/U/A]OI)Yu6X1;>6s.tjT;.P1e[-=7tT/)uoq/%Y^F*)YtI)1F)D+>WoZP<^&ZPIt@q.PJp+4/6h$T04#?-ix'kLcARE.6b>n0F[NT.[+8m0lh6n8wE+kML:?uuZ>1C&8o13;3.m<-2X`=-D6)iLe:?uu-0xO9Rn'B#RoRfLPu]+MP+TgL-.R:vj2rs/A0?R&u*]<$jpSn/,KR2;R_$##2f&k$`m]G3c;gG3K#9;-R)9;-di&gLt3_KMW;C.8sKjt(oeJ60#d+58,;cD4)ti2%%X`kBQf,K)$]2q8+ltv.eNEmLKDL[-l]Ue$8hRlLV**MM)Y5<-la/c$U;#1#j(`A5ZD58.>so'5*F*<-Fw/S%O<eM1hRm;-P7NM-qst8O_SS+4]D58.Z'G4:j<-N:[s&f3xDf)Nj2o4;A-pI46U570=^Sb4-_VI3Y5p'5=q_k1]Cr[6oauo92:+<8S2oL2:9751Xup'5^b/V8S)=M2P%wt7hWuO:si932o'fX7vcKI*^hL.=U2,(5_t7r7X)7m0nibl8BDc'&.Nj*4:Z=*cm:vT8B5Im0u5,P91DnM1?H&R.1h_k1^@WT.p(=I)NMfo7MJ)QL#+(J)+aFP8t>eM1Io%mSI'5[$RgmBA=WO1#&CNW-AB41#H-&&,5F#@0(GpNOn3Ub%aN_a#N97I-_Apr-v410MYL#W-R0gZ7.Eus8aZVk15tE6j[T$-3mXb31(o+319nH-35HRP1A[1g2[$7c*j9Y319w1k1#@:41;$)k18j=_5tDK120^X?6=Mh<7N-280=<iK2r.cjLk8GW8+=uN1ZxlG>)/Cb=)Vps9ZWd;/I%gh(0bIthQWjJ2@[/4&[:EC&vwaX.0W40273nh2:=n-Nf8<Z5Bj/+4Lo%q/:nr%,(g/32DfB+*Tcd8/G(HjL(<PW8W:5%5>U[t-bZK-*J;5j)794#-9)(lL;LvZ%$r&u.2b@x,`cZs.4Pv:.c-Va4Mikm1<ZWE4Cugb*6R;`+7t.A,(mi0(=XvV%^)X]'StE>79.X1NcQ0WMc>RE.NsRL2ZM?m/dov8/m$(02Jxc<-Kh;G;I^bA#aO8d;JmSJ-&)EQLJ7-##<h56qK<`IM8sk6/SFf-+5?SI*Ebfi'Fp(=8xX`=-&P5s-mT1GMh5tx+^>l'&0=Q;#x+$&M'9_O-]8'v#IaSG;NP*JqkA0m/LY_J1tiB>G173&=bxLA=nVhM'HHG/(La(g(P#`G)T;@)*?s,#>/nB8@:?_S@2/VD3Ickr-w,BJ1R85D<#=FV?N[`uGj2:PJ0+G`NnSFi^DF`+`e%FlfKw1`sx1lY#9koi'<rN>5uf'#G-x<PorO0AOIp]oR%&Pi^K*b%b#U@`j>,q:mZ$(JqBGO;-o3`S.9iE>5xpLMBO:$&Fi/LPJ<fn]4np2,DQ-tAO3Yu##1vv(#BF^2#vt'J#`S$K#^;UJ#*R#N#e?2O#ov.P#n[3T#t$bT#q=lu#'2>>#x7cu#]+pa#g_u'$aP$g#f]x9$>>>'$9+/9$m.*-$1ri8$v%SH#&gc/$aTb*$9w[d#p@uu#%AE-$?*)0$u`H,$F6YY#R9u:$*EH$$hIEh#[.@qLv@Ed?,4j]=&?XV$o2OoRp-YcMNq,s6p46)<b5xi9fPifLP:@5&o7^%t.XF;?^'l.qXC1)EtFQD<OPmi'cZsr$Cu7A4FPo+DF>s.CQ>5PSwQNlS4?o@kCxn1p^wXipb9:Jqh^6Grch&5oo#RcrY2J/h1N]._bwb-6Wv#,2)pb#5N2A5#g'3D#V7#F#6LpM#xV+Q#$bgU#LsVW#86O]#$p)`#&Bno#abCv#DLRw#U?kx#*^m$$h*3l%_u$#P[CacV.mNS[m1+5f8U8m&p#G,2ZPYD<.qgS@r$`VQ(T$5Tg8%T&<b`D+O&U;.e_bJ2'9s]5]cbSASXYPKric]PeXvuZ)Ehi_DYHv-#)Fm'>hrD+[%Am0f.:pAEWEvd`n69AV%T*i_7l9vw1P:vcYE@-8lNY5s,RrZjRA>5^GBG;2)HLVD'^xb'nw@kSe'Jq=,oY,20oW_@(2Gi/l6s$Uj)<.1pYG2YjTJMnUk^P_XADW0#ko[-vtW_`koM'r/cG2DaoW_Q0H5AIqrW_d*6JVv10j(B*A&,JtnW_v6C,35DhS8GlF&GIrqW_:nhfVj$sr[.aHJ`Af-N(K-OX_;M-X_22-X_sBsW_,rvW_RR/(M9RgV-n)l$'9kZ.M+MT;-=H`T.[2&X#4e3n/o(>uufl]=u'nL5/7cj1#'xM'M]1_=u(k]=uVrY<-MmL5/p`60#k+mAM;flx<`n?#m8)DulW.MT.%)Duls7T;-`5T;-`t:eM*ou==(2f:G&T9DlElqFlYaOxk<=49k5D/2'4<2o&Y*_B%i+,##[04g2V].H#q=<h#64Ti#k6YY#I](R<_A(;$l,$$$D]A&$-J*1#qIV0$q>o1$^bOkLU]BM^@%$,a@U3>d,rO&#*+%Q/,er(jT,4GiXR->maE]oo(KTWneh<SnBr###%<)gL1VnlfP572h1=Re$G3%Z$WYNjhRColoq;a`sxnMk+6**)s>F#f$g&%^NQCLm8'B_pTcb@D$L<-_#f]x9$QTo9$1(w,$=0*-$MbI)$YM-,$9[?,$B+(3$sri8$cs9+$*'u2$OhR)$V%I4$k7_'#.GY##=f1$#4c:?#e&U'#<vv(#FJa)#AmMY$([LA+G&PlSQ>5PSLms7Rt37SR0'8`j9ak=lG2a]++xu%FaT+8I^qQ]Fpr`fLW%RfUhhNcVEaQoeqIOlf*g%)NroX>#&2>##wfSxt4Hj=u]vRM9fY0,;wL=DNfP8;-m&dc)nrSV-*xLP/2F.205UIM04Fil/<E#)3HvY`3Zbcl8pj@J:w5x+;&Wt(<tQHP8$vlx=6]2>>9riu><+/;?ARFS@J6$2B`+->GnC1AFhu4DElUHYGd8[iBS.<Sn0X*;H'ex4J/3YlJ6g6JL<)RfL>5n+MFx+AOTw?VQXqCYPv3UrZ7=X%X-o<`WL2*&+m1V%bj9OxbeOvF`p8%Pf+aDoe#$Lucr^0Yc*8tIh;xT+i>1qFiTGV1pl=sLphi?onjCS.q^WN%k_(oIq-EJ>#H.wl&R@@5&^ldlJhRAJL`x)2KF1TA+uJZS@nqo+M_qg1g('gP&NfTJ:XL2)<V@mc;ZXMD<T4QG;G6jxFQsFVHlkx+M3ke+`'&UxkBos`*D%9&+7Bf%kVR7A=i,e%OwX;5&ZZh`*Mu%DWP`ou,qP@A+3HU]4ZOgo73_:JCalk%FB-k.U&fs@XIfqCade7`a*]lCjU8Z4oDDIrd,2=ighe&8@Yn##,Jb;G;,3ZxX5Op=Y7[5YY.Y%GV<e82':_9MpgH:Jqh^6GriBYiph>+>u*Vh;$0JYuu3([8%.VCv#/5^xtT:qS.#enP/r*vV-udN20HXScVR<g`3sK'&4=i[]4FL9;6[r%#5YEp(Wp<T`Wx#MYYxs1>Y&$mxXl9QP8N%u(EKhpr6O*QS7SB258.aerZ2#FS[6;'5]Ed<DEe7RM'k+lo.+iPS.)]58.1U*/1<-bf1Ca>D3F^^c2CNBG2AB',2V[(29nQDM9qg%/:u)]f:$KXc;*pT`<3YMY>A_'5AHnbo@DOfr?G'_lAL0CPA[iK]Fhoo(Eow`rH'XASI*h]oI0B:MK6ZUiK8gq.L6Nu1K;8NcMDYj(NFf/DNMI(>PRRcxOUt$;QXw_uPfG1JU.R1VZ2l@cV#,DfU;mxI_U`^._`k3]bj-o@be[V(a`F;c`jQg:dv&-Vd&W`4f)T)Se&Ed7e.>X.h5GxLg7f9fh6D]1gFHBrm^>_7nWWJxk[PvOok@8ip#RH%t.$e@t19Ext4Ha=u8a/##9^&Yu8aAuu=,,v#CDG;$Hl_S%V'pf(dZPG)eW5,)qwSrd+s]`EhD<>,soWY,gQKJ([<,,)_KGG)^<gf(Y$0/(^T()*Ybnl&[Z_`*gvCD*h/%&+;AJS7et,58lQ`i9hekr6[.ou5WrRY5X+4;6[:OV6:afxFk.P`E@wNiT&l8]X7hl:Z*)-MTm>g1Trr_+V.FPuYE#'M^O;b1^L&+P]K)Fl]Jpe4]-w9loeY$SnmekFrx*P+r$CL(s(UhCs'F1cr6)(s$K%%p%S[WM'UO[P&1miV6Nq,s6b5xi9=`GAF3JB29q9gS@8##g:fG=/:Z?^cVR+@8IR+;s$&E@cr4=N5&*,p=u4CjP&rDa%t14<p%,c$W$.V:v#,,Txtq5*Ds-m<`s`(XMBjVMJLWND58[a`P8m')k%+AU'#^^%/10Lto%)d7Q#pj68_ctv<_>)-M_/Yuu#r%O3_qPp?-6*rw8cX_pL)w8/1VBrP0aMjv5d7dP9B1:Q9J&0Z?#gKDO&`vI-Sf&=BbI<p.I#Pn*@f/f?#Ug5#f?_qLPW&D?94;^?I7;9.vV%d5g5a>$M%l63*WQDOaV3B--/ImL7IMX-LwIb.)6T/1Bqc2$CZ8/=FNF$9tvTs8/h'Z-O8&sa=s&saRbqY?DX4?-3RQxL34kpD@hAN-,e]j-Jve--l#4@9SjQ][/Fg5#kQR:MK[sC?C3WAL3ItCOSdOwB;J=2_-Q?>(*4VuPpmS/Ne8Z6#v-a3=b&u59XU1n<%Qi*%PH/a+4Kr9.V/:Z-s_vY?57w&/L[Le=BSgKYK7mS11O)##_0l6#xUuo.b=Hf_^>cb%8iMb%xTcf(;R35&)5###V>U'#Igr=-VEFR/67>##Y'Jj0+0d>-TXt(ME8M'#lVWjLvcG]uT?/A$3oWX$k.wiLgt?##JH:;$i4),#5(V$#68?8`x_0^#1[7:.vu*)*F$f2(^;c'&%3c'&O]d'&i52/(Et@;$GRP8.wl*)*0bV8&0bV8&'fbA#_S(a4di-e/$/]6#)3pL_ST`#$N1I$M<;-##7iJ;/S;F&#axefLJ=?/(9Oc##^Rx&$6:Gb%Jh;Q2DitM(pf/+*I5^+4nGUv-&1tD#_R(f)NCI8%R?XA#S.@x6HZU&$h=S_##F/[#)Wa>,,E(2Kln&;8lhj:8Ri>E5gF>E*;`UH4-X9f%Uf6W.YTpN0j.kp9gr&_#$j7:Zt[u$6PG(%6WMb<6@aO1)Eqd,*iH/n(9j9Z-W%b+3@EaA5bx<T/j2n)#N<(',=U?)EE&;qVE7Vf:Q>f>$TiO?$o.#^?jvu=Pn<v<-DK+Z-RbL3tOG>>#s[g>$g7g>$mn_8&C?JK2$_K#$vKEL#x9M8.;-fr$]EwS#)2oH#,B1Ru07qV_3W%duj6-RtpiJa#v>uu#Pawe--@1RNSHgx=:OW5'd)gm'd#60`#YU,.C=RqReDP(NW)08mr9H^#-+-&MOeZL-oGZI.[,lA#.Huq.7,XJ(=KqRWv?3L#M`mL-auN$%5a)RWKN:D3+j_6#?^Z6#Hc1p.vTY6#'oq-$KU5s.-CHv$f3^gLFN'cjiB=gLX6>M()2n6#QWt&#,lls-e6+gL+o`:8mx+3)5kA%#rb#q7H`=2_a'9e?plS3O8a,F%,49K8ZGmw-h?7f3twC.3m]WI)8Jh]PCX5I)c?hf2@'bU.T8QF%[]p-QC2u@&B%Gr)WKN`+#cERSP_VV$'C*W-x#Up9xxc&#mi7A_Ci`3_1>l-$[>7Q:mX2u7RGkM()Fn;-p+b$%V/7Q:s'ju7<m(?-EPOV-1'0t-nZbgLDKihLf2Z6#vDOp7k9pV.3en;-Je[r'+Ln;-.8t$%)%eX-P+5;)[6DC4Sqmw-G+X/2W%3=.F.b/2];9c;BGFfMO>b+NfdQq&Z[`X-]M.M14`uN1PYH[-wK%vP>#V:QZ4$##n1NJ%.USpB*reC#8iFD'OP8'fIH_3_q,618DGY##@@hhLDVOjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%Ma*(q@?erIh_kHYm+C6_#CIXS%dTx+2WIQlL8_::#a?G)MQ1oo@+M>s%<5D)+GbL50WGUA5h-_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd/'x5'_Ino.-LH,Mvj@iLRXVW3WK3thshvu#InWT.S;F&#Y_Uq7oT]^-QTER87,2T/1eRM9>uGg)C+uo7BZlu%Vm_>.VUqR1VjU>.VX$S14x+2(4kZg)B7ij;)DJ&.^d2O1Wi_GN+>V;(7xte)*#(1M#lx1(4I=?.F+F$8?k<n0<=pr6;E,12,;3jL4?74(4*L,b054mfiSk,2D<O(j1'Y4o`-8^Ho]c&#@lP<-G5T;-W5T;-h5T;-x5T;-26T;-B6T;-R6T;-c6T;-s6T;--7T;->@pV-n@S'A]Y_p.s`<M(X.c9DU6M50a_[5/cR@%#JKNjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%M>Uov$Tb&Vm)r'^#VFhM1O>kM1`VS50M=-j1UW3j1M4[[34W(,2Qh@J1PtR<-$[;I.xe%j0o5;4:B.dg)UU@8%Ojw]m9wtK;'7v`4iXX0;'72&5N-NE4]sk-$*u)`Y.e'allsg'-O6?n0JGCGNOxmL42gS+4UFF`#aqxb9s[it.5FNP&aUV(a5wJ02-A<jL0wU3(o_fnfNHN/2NXIm-9BVq00Ru2(WYt&#4XZ;%A-[;%FLDp7;[^-6[2=s%;'<s%gDp;-2O:C4k+?>#:+;;$+.VV-c%7>-Ql+G-ZuFc-P<pv7*=V8.vFq8.R,h5/KG>c4ghmQ8=B;uR$(Xt.G*ft-[`Ch-e]k*4I>db+Icr$'L:pa3E[^V.xxt,43AxZ.@SqW7K$Rt9(V6m%M*d+#cRXgLqku&#D:s-4+Dj^oHjv2;cGv6#J@;=-:Dim&gYjA#$]B=.UD.&4U^UD3x1f]4H*fI*AF$%5u&E=@(jwOMjjmQ#%-m;/%/q*+_HDsulHQ.'Ua_JEvBHe<v$ID4L^5o/;II/r1gR/&vNOQ/lM^]+6nFJ(PnOs7Y4+gLY+fo@i`];.t]`>-Ogd<Adw*T/HxF)4Liu00LO/u.O[p,3I1Vp.U)9c;G[8mhQBhq)ZTW`+Lxte)YTj%,9nS@#Js+tqL;G##E5*@;W?'$-8Z[xOkT9)Nu+>$M&[j$#/r+@5e;F,2lPA,MhMd6#5$%GrjHFgLHxGC5uEkl&BSqQ9h^ET'hGee<]G6R9OQE'mB<C*#5f1$#*Nm>8A_^p&2OJM'_nv&OMDZ6#OTY6#3sLi'+J:8.BIr8.MM@40;m`BkO<3Rkag`>na/Hmus&GS#;;U5%,AJ]$')Rw^87IP/oLsJj$4pfL0Cm6#E0D2%i>MJ(/@RS.f2e1;FwW>-=x-_Os@+jL-tR#Qi-+O'/fLs%Dr8k$m0m`4L^5o/BI//vW)9V*lD5#-]H-F%:&@r%68):%j,sx+=U?)EbT4T.MXI%#u/C;4hjaEc-rA,&mHj;-Q>t,'x17;.hC]=%&Gxh1<#OSn0trbnawG]O&8@08n<@BPF0O)Sd)?A4>cb4%`1]nB5FNP&,s:D3Fo%7#ir[fLO/0j0h6+gLJVOjLh*>$M5fw/;sfk&#kHXS%P`H,*'$t;-R<=r.7us6#RK4(/1kYS9Q>T;.(aYt-8r/kLq:Zt7SrNj1s`_c2+O/O9:,_>$*j:Q/$g1T/@ZPs.Aq^U%4@-E4]vtY-)p:^#iXDJ<0q$51@.ui([cHMTb>d[7HA<;POE%W#sBVu&C3&%,YLP[56o4?8@0OY-exUE4'v[Z.%g^1P=eO8&/$EP8D;=K3jKihL?^NR8MP=K3X,[]4Tx8)*%:ERj._i8v[]P68laxS8eFSq^Scv>>n1Gm0ujpv.EPFjLn*>$Mxxw>%8<?k_x4xk;La0cjG/c/(MFLq8]WeG*=@:p/g9g/)^clb>&n3Q/8bO4M<Xh583T.mKQ6V>n_jP#+nZVF=dZTR/Wit>/gAK*+Towct<liu$/N.p&on[R9:D1d4xnrW'd8H8/0nj%=no4p8q,kr$Qw'A-,&KV-hFUi9KGC#$.m1Q/5GL8.Gq[P/t9^FXVr>X75gNm1Fb=Q#/-(O=/8Dm2d8=_2l[Em1pl#=7UUNJ>O'*DHqg;&;a.9'fmq>(f2t-DNrY;b:?hW)uIKg[:q#fl^lZ]s-[k1M9XotxY+0,K:v`kA#[,4g&RI8j0,>N)#c+KM0(Duu#(-Ev$]P:&58V0j_[slx4Px-t-@;L69[gB#$Ro;H*GU8>53Bwq$h*kJsX].(#%d8KM9G=o9lS4K3Kd,t$gU=j1=NA10WQB1$xpY;/x($F+fl6)3MsO.=4u#`#2GDo9p2lu-e:@..n%CF4=TBe*beX`Wji`=8C`$9.rQ6[-A]R21vTZT:xsb9B:XLK2BG>_5br3T/=#gf3&#fZ.%Lld2WNc##QKb&#@]v8`9rYY#rTj'6)RGgLX4fo@>`#+<q(6m'=30=-W@;=-GlPt&0OW<-YrOL)SbesA*(/9]5m@H3=*t`+^',0;2nuR0Au81(UMt?6+E*m1O-um#/L&U;-`n/4Q53V&6lPci/2@i1EZ9s7LRC6AN5g],(ICsdHe1j(H2Gb+0Y'X/0iWE6C,sx+sPA)ErhK`$Faq%4?xa?RU[-lLxCm6#hYQ$>':kM(<Pb2_sP$O_km7XJbTj$#Ur+@5RLC`d@H0u4nF?>#_PX&dG2PX*(_An89hv^Zfq],9QsgQ_R?3n8(]?eOlmnVD>cS&$S,m]#9in$$#F/[#i(iX-DD--O38_8O$bkS&_X1^8Oaoh2c.8KNDY_d%)<.Z.4),##VlL>*];c;-9ZFW'?*fI*m[fC#+@B40*ba[WUEdquA*O7arj7QcG:I(:T/>985FNP&T$m+D?rH'?+sxJji5M>(#7/78*o9dO&uvU;xmO&#[Tbg$JkNs-W6ao;B'uM_*DYY#&7h+4,tgj;:Ll-&XIIs-R=(>9o(Cj_ID8>,J_ro(6Ev6#jKSn8xe`jV2g6b)o7Ef;mVm`6.l@79YikE4.UMx5$ZM''dkO3'<`0R1M`XM2<&Jw5B+T9&qTNn%GhBMs`Q&%#anI94bs?P0NYL0(h4&nfnm'hLJN<R8l<_#$+hd;@viST]M?IYk8cvl&EPE(fwpU7e$<Q7eY+;W-$%1s^2B1e;9[M#Rg*5l*Pb`K=8SZ[d`05##)`x]$3aD4#^3=&#2Rif(2I$Z$<5?T.1sdo@FCjB1K)@L('&[6#STY6#5]K[%JZXb+Gh&q@RCZ;%5bm;%=<rS_/hu,M>Q3BO;*D-M;*D-MgGv6#YreQ-1Y+(.)mQiL-RGgL]5Z6#G(?91pCa6##^Z6#OZc6#tJam$LX=j1qC,c4ndK#$hKkA#viWI)*)TF4)li?#l*M8.;6EY@mkav:4ce2&,El?49XS4(StQu6M2_oIv[r:6[<j13g/W]=nETDW;QH*G@RwY#)?.<$s0^*#YqXj0kbD4#Z9F&#@h]:`W0-NWUed##-n`r7*qw&,<?7p_/1x<(#BRh(9@RS.AO@##>30O0;Cf6#,$%Gr6.,-NH5DhLD/^$&oq$kt_NVm1&%g+M?%co7n*D)+SaOs-`nRfL1/fiLNDZ6#BZc6#I(MT.t/oO(+9)x$1rh[,^YVO'SCFPA2)'Z-WJWm$XvvM(,cmsCLp'T0R;EP:u0L79'Y@fuUT+TMVeJ:v>8]3O17o[t]:C:ALB./EkHPT%9Ml>J%QLTEg-5RC3MG,u(#]qC>U%-#Jm9SIH.5p71MwM1&A09'kRu2(,'ipfhhi;-8fG<-:;9[%`00R/Q3pL_R$WV$L$Wp7THQ'AfZc6#C?Z70HxF)46w0>.oTbAuh_s,8MB5Autqq-%WtB]4o7WDWb6ai0?=KV6b%L$MQR6##gk.j013vQ8w7ijVfO2:8T*?v$?*.C#pO@##]D-(#<Io6#?ZMs?9D:&5D<f;-$9`I2X`''#([b6#)UY6#.Da6#u0&H;E3Zg)''d6#>Ko?&@]*=(Sws5C@tHQ8??eM1`l6#6W81T.fXH(#q))].VZc6#k;(A&[51<-^uXE.bsXi=-^4AuU07,.l@No9qxkA#b)Z'.P;G##JH:;$qY/6(MW`Y,OnDr7W:s(t$e>B.Ixq+;,R[>Gd#020=Rx6#Lr.r%-^_$'M<gp.13pL_FYm5hsVZ6#LZc6#.tqFrpuQS%,G)s@a6j;-PLMX-`&Gb%bofh2$S7C#KJ=l(/90W-Km=hWKtEm)5WLD3x1f]4WruY#i>aO]=aD5u#DlUYmEXCj6T3)HS4$]B%L_gO3f8G?<P65/qiHRkfBuR#BWuP#ZG0O<7[&B8LxN69Cm6GHtMP</6wIvIe,u*#U7XcM#Za/:Sn@J1Gqx6#K:2=-OC7F%AU_%O^&;-MefNBOS@w.%8sx]?cnRfLu-gfL36Z6#g?qS-d=O3.rQ-iLK*:h$SRtt(#&JfLed2m.Y,lA#/A9N/;,XJ(kc:KXTcDg($<Q7e:ESqsenKQ9(ZYc2`MqPhlMm6#RAP##v`<;&+A`u-[Qf-<)P7vn(EZ6#pTY6#QOnPq_9AG;B7@,tUnXOoU&p58uR3<%cl+ou7`>T%Yk*>-$s?k0vU?>#Sw;;$qM(R/<4E0_Mlbp'po%s?jEap':khY?*Lap'puP`%hN,K1$A%%#K(*=_I%a3_AC?9KVhQ##;Cf6#)$%GrN`3t_C,oD_%j$O_:X=X(5O@##L::Q8T-O^,''d6#.;,i,v_YY,lp/20^.d;-/r(9.MZIG)a>^G38bd;%&o(9.8;SC#3ZpQ8@2brn%Dd<-E1#Y/(p]N2eb8g8$H%C#K%E`3[;PG`W*b+VFa$N0sk.j0=[u##h9_hLi`m6#I9F&#3r+@5uAH*N<*q&$Txdg)<?7p_/RBu(+kp%4o7rp.L3pL_&HUp9+C>,MNHJ,;gL%a+G`%a+v/,T.7),##Mq)Y0je%j0g?'3(N=lt7H<vV%JQ:v@><UM'ip')3ig'u$D%NT/UQCD3:U^:/gW3c4wBbgNCDU>G9Qdic&t?;B1R1n9X=Ea,Df.*5]:VFUtF`N,)3k:_eOv5A'8SVBWS-TI2Jd%-oIM='][bS%%,sr*FK6d2w1U>Gvmwu#w*@f_n'*)#3LPr^vqJfL:Q7IMK2^%#HhFJ(;>)HOQR?##*ht6#FEkn/ATY6#sts6#R[%:.ncqr$g/3B#<l%v#%OG59s+`p.P3pL_ImKmC/[c,MH[_p7(r<#-K.=#-Ig'T.;),##]WWB/Iww%#:PG$MTxSF%:4aK__=])G04%6/8;SC#gp8s7M#/$$HV1W#'ABp7S/ov$hALFtru^N4t>'XI'9>#>-'pl&KXPfC+&h;-3agW$X`>>#sA+_$E&u2(clMmfV#B02?tC$#([b6#14)=-6U;^%GHkDEB49*>8%,s6>l8U2L>2U2gc_K_T'.XJTVO03e:Xe)Crq;$$L/@#I5^+4^?ti0nk0:W3CQ,A2>;>#D*'U##YJDhp>K?C[h^bA([4UZ(vRE`*?Hntu/5WG2RR)#U++GMX5i58V(5;-uR7PJUAO&#:/6/;=GD)+Sn5s.ruu<-ueB4.PH^:@F9Zq9grZ+9Q5C0cKTx+;A$:Wf`FI/;o#iP0FTB=-)_CS-WMLa'x6)vqq&,=-K)#a*Q<Js72G0$-m,_6#+^Z6#XN4=-TH*c'#8'&+3rUV$:DEl_x4d'&1Wc'&9;iD<APmPhuSv6#<),##@#QT%ni$=f;^IIM>d7iLNDHofr_lo7ju;s%IdSp7O8lA#Ip'l%CoQ=-ttbv%+k9SI2a>#>$+%v#NGW]+ej^6#'^Z6#35T;-$>373gCa6#qcd6#+$%Gr3%###qw9hLH#_d%VVl2(kZ'HM9(^fL@RGgLp5Z6#U5-.+Cw8g:0`kM(qOg>$.hbD+Lf_8.nDD,)5lKB#3C0##9AYDukWt1'$jDxXKV1mqnE?5.[KtOO@o8RNJnw#Np7^[PR8Z6#Z.wNT7tQ6%DF`&O8GSn$WB0hlbZtgl9;8Z-Rg4soB..Ak$uYl]nf[Aph]6,%rwDj8$8u59>BCG)MuBl%Ha_3_;c<*e>pnD_uV$O_$Ybo79X^/)URfJjt`$i$3#fKYFe$1,_3(,)Nrko$tJlp./3pL_-&pQ(8<`-MVj8O9Q56?$*]qr$de-d$9:JqD8s'XoY5Z6#>hG-&'O*Q8L8lA#(%BK%jPYMu[$3Ece@_CC7V'^ucZR`$,vh4Rw]Y=-tLBM/gL@X-4+p#%he6##(QUV$UaD4#P3=&#8nXo$0@IKWNI?###%:<&97-of%ld.2Qr9W.([b6#6I7q.EZc6#sY-@'*SD0_*(=X(2nhLj2Mn.%0#mp.@3pL_&=XDuGZJK:j.=2_ZM4[9F,>>#)l6m',IvV%2n7p&)_'a+w:uS&tss;-Y$)M%916g)YcUg*WEZ)4uss1^_E4T.$Kn_sx+DQ&Fl/Jtd^b5/K<ZquI#e+8R)L^#u=B;?ru0WI[g#a3)keT&47x6#]r[fLY(vd$Y']V$HC]Q'm+2P;-F5gL*fm##'/*x$5ks)YA_>_$HO5GMIH-q4$Qq'u%7cQuT?oHuP[cf$e3N%XJMp2#tR0^#^+.u1$$xu#F[LcDB$M$#W.xfL**>$MqqQ##8r+@5O`U0(n)?aNPe>vG]KMFRTvTX-3Z+ND>ICp7Xw^>$2*oP'OfPK2F%U/)Gp4)Oj>cT#XLur#rUS+/@)R7e?>]IZkB5qV*h#a3JkG-Ze9(,)XN#7#3?t7%(BAs%7?B<-aG`V<`]vV%xXQ29GQ'/`_XXk)X5Z6#aAI1%%',F%,HnD_dOu^]0Vu^]Scc;-BHGO-Ix2RPLU6MTIqNW-5YaId36si<3-h-q2Jv>Ijs&nLv;W$#D^U&&IO1A.buDs%Zovm/CF1W#vaMW#AVS+/rD?A4r?,oWeg-69=9(,)C0c,FUUZ##(6mX.$),##9*m1%R2:T.CTY6#:fi3*Is=#PtP#;d)=EW-q%m5C9DSK<IhVcs788_%exnJjSiv>>qjfQa@xR%b7-^02ml9-257>##[.NdtL%1kLG#TfLG#TfL<k1HM2^nlfs)ChLbeMK(tw7X1NMhJ)=_C#$>M@&,F(4',/4rr-2cuu#J1ui_Ml>_/93]$R8r*+&G.iik8Q8w)7xi)E#Vo>e#g8/&10xp7hTbA#&(]R8BdO]u'&e2,ib;W->46hk4x+s)8QPm/+g1$#MXI%#$9_`$=^.K<Sa<r7bSo5'#Vbo7.SgJ)IsxP'jn[Q-YW=[&]f+CHuTJ),4:fEdBapV8--IH3`j)R'd6,_eEh^l'r>IErN1m`%OqHjBj6IP/x>d7egR?(#NpB'#dcv6#%4s,;gcA,32:Za3uZc6#%$%GrTAO&#$l#O()2n6#sJL@-Xlls-4l&kLi-Wpf;LVq2OP-F%fHvv]C7o:I5h,vA%bV#&fVYb+K:UQ9;It2(+f68%dDhG*va=aE>SE/25]DaEWRlcG]5Z6#72-L-'T4o$SUEhDuSQQ:.YC`jtk]Z-iw@^Z`x.lDNTWcsuv:i%Z5>##*9/A$N.B*#Qqn%#HNc;`::HHlbSm6#@AP##9J>$Mw9R##Br+@5&rm.2A*V$#*ht6#Z'+&#ZkRU.hTY6#LD2U%1jUq.C3pL_RoD8C``B$&r@?>#K_;;$sl*)*3k'N0aZc6#9tqFr%gHiLl*t,<l97r:6$.F'bCk[.>5Ru8:mOw7v>b&F:Jb,kC*s+;<$q>$l3d&Q2$t?:OF'/`wrFA[adtg$,9n,=xYnlfWMKdO#*hN4uX?Q8hlbs%,$s8.joc<-b=l?'d0F'FseB#$sJ_20],),)(g:D3/h`pK&vc&#>e[%#c]m6#(t`^%NM$-+;0q&$lut@n3WSC%:>O)[Bxw,,PJCQ8AUF&#[xl;-`0o+%:oZGcxZ7V'vn8>->A;6&EC+CJndpDR4S0-:uAD)+tqRFN=:8RnpX&k0;c%a34g-,)h%r4J=R#Z>C<X>-aa^h)meec)*cYY,(k`H_mW4<8@l@.2do*)*16?8/Osn%#.*AS8=7XM_:q`C?X3#S&sOmp7Pj'^#jw.X-b/eXqbe@X-cd9qgK0:*#O?O&#H'CT(^T95&qY%Z-qY%Z-1S7N9bYT@863Jo+B_on9B.S9_hqVJ'jD6%D7:RhchqqgCVlF&#sQf8.Se3jTncn;.mZ7:i^9EdMFh0`$`gpl&g*3q&'ABA+80CG)4eo5/Isdo@I._2:jY:OD_Hnx%nxJo23vU2'fx3:ClaBpp8AF=CiMf?RRwVf:dN`>$'rnG;T/h>$GxDY$FS?=-M%<u$2vma<fl._Q8.mRc.r'@t97Z)NI>>8n=wfi']&7WS*Ia%0Xl:;$KOho7S3V#$v`<($7d%@B;Qn[%YRO5A$LvpgL#e+#&ZV&.eru:;OH'/`'t?^#vkM*IZ-]V$QJZm/LTY6#`Ca6#4M#<-f2Vx$bgKuAd8n/,L>>>#3xuJOCe'l'nb<7/8+U/)+?4r7$+l&u$?=c;vu(]b?^/n(#o98Qi3GErMADq9S:$##@arDNhM+=_uP_3_J4<O:__Z-d7'7WCbJd6#,$%GraqL]h1e3<-H:ra%pOgfF+0Ok)^r2]-tC]=%b%cgLmX4%t;S8q#Lf0k.F<YM#ltaK8QaD<%Sf1$#4]ZF8YR9/`e0:/F4le3'<#oD_]t#qr(0,F%(0,F%q+`K_QYdEnfN9<pF3.$,'+6QJ:Ob,OEc*j$7Of29WTc3DrS5;HLobZ.TTV7[@6Pr71/-Z$V8gj)T/5##lk#?$U`D4#A@%%#X2eq$>H$O_JOlQsQG;_ZgVZ6#ATY6#ZCa6#CZc6#n`Kp7C8kM(AjkM(Yt--M.fd2&ND;M:V`dA#Nx_<-ACIY%v=X]u04Xr$073N9G_I-+U)A`._@'cFgcuRa$eIMFWpIgsY%xHF[]Q9iLnUC$U`D4#jpB'#[ojl/bS(<-C:.6/kk.j0Q$jg;8n1p/jD+dMqI@j:G-f/NX5Z6#%OA0'^>Yb+ErB2:x%M)-53o2&Q[7@@HPFjL5Bad*u%-HD`sW>-a@tv-'h`H_x4d'&Yi/4;e7hl%Y9fW-,PoDl/1ro.=,U<-X_bD)?-Ga9iWd;%I*/(`S?Gh:wn6(#Gd9SI8Y%a3CCqr--#%7#&jPT%E'rv%siZ/(W)?lf<[u##`Z_K()2n6#<oPW-SG8U)`uHjW&j$J(?Jd68rwG,*UNSm'+)B0Mm$n7Am4:q:jNl]>ebw],2evZ$'h`H_*$N^2:L+c%cKi8_9IuM(VF'AX:GHs-1&TUA:i<_5>H=G`vBK%XE#XPt57L@'p.SDWJ6n0#@9ap'E*Im8q]mx4AI?[SU[-lL(C([MhC$LMotGZG)r%9&&D^]+AO;dM6f^nf='qG2<$%GrR5=&#a4'N()2n6#vU_m8YU1E4''d6#%@U9&Ix*=(*xt2EZ_?1M,3dI<rDn21Iugo.mR4$-W'wu#p>2/(1F$Z$$8.d*=8D)+>uB3_#[aK_:o>>#Z([`3?J%a+Fle&,V<SC#0:@a*,sOp7ZmL#$:iKP)&;$+8o&e;%7`xI%]5>W-8$CdFmX-##/W]A$U`D4#hAGq;PF@&,fB,N0WCa6#bcd6#[r[fL@VelfIB(C&g+?>#UM##,M9K&F[?RF6kTI`EaJb2(?QNW:VD8n$+A-W-P-IaH+RGgLZgdh2Qr9w%#><%AEMUv-h?7f3a[S,?gY2h`&*5u-hGEq0xiRZ.-xmg3;O%r>brt%$-?YQ&Qk2l2gH1(#wxq-%(a:-mE:r+;KFe./%####m'#QDE^=)<=]npai)A32JJhpOt7f,$R&*h#P[3?M:HSvpAp23`/1X<%#A%%#jGX:_fCUNaqXEG<%d#K)aoC_/Lk`H_TbHIQnJ;?-%p^K-JCcZ%o,OIbF&G`%Gupl8]$+X-&9BU`Y^WIM&h$##pwq+;=A*gLiPcf1%W_6#rfRQ-p7ra%i1<?[uIX?%8otWS#&PMC]1k#-:-V8_;9fY-XONF%wD:UB*B#H(iZks-9x8kLo,UKM?3U6AIc]s7.Sl##1[^C-2:2=-CLMp$#&JfL808Q2xsUO'9J-W.c/L-+qc)E#ZH7g)R8u.XJe@kuCCsvAI[8_Kw7_:(B,AX6$Os]?*#.c4kA9p:.(6`#A5no#x=qARqn35DX@TU[Pd8ba_qW?^bp;&7fH3?^K:f?MRokeFS[J[WJBUk$#YHj9W<Xc2;D`6#=^Z6#K5T;-86VX%Aj:$^WAYY#(X)##5r:;$:DEl_+&gM15242_MbRF%NW]'/:=E^6GVkJMc6pfLQY2u7Cr#0)''d6#3xGL)'5)T.Uk.j0``3+.*&BkL]5Z6#ZI3u$7O@###-<JM:=Wj9J@Wt(uLdl/cA9K24oQX-,)<</Y0g`nvK'lo+^6Q:JmLh$%:'x7aNG&#>/7K1pMc##uO=B_Ac`3_/8l-$GRE0_3.[&M22%O_[pcv.I]XjLsXm6#5:r$#Qr+@5.(B3k?Ih0,_-]V$]TSS%fXd+uX5Z6#gl/ZIhE;H*''d6#&]5=&ql6G?8(,s60hXc;>Lc)4V?t(3x>P<-a?Yw$7O@##%3*jL(7Z6#mPrx$6hm;%9uFd=B>#D%GWPZ-j#LIOSqrV$H7iTAG8o%u;VG#/L8_=-JC72.WTE$M2WU=%`%%>-3ax_%Sw[D?IEe81k6ap7/jtP;A[P#/[_`58x'M#$Nj(a%;T2L;5/S`tWw1?/J;v20?3h'#w]%A_7q;-4.9:99v(N50-+&B5;U8>5[QH&#fw<39(1HH3cVer6BMU695MeA#8FN39kWp%u,9%N)mb3?-S.`o%VAPm8.^)w$85h'#:Y)C9:Y*-XU/Af&wS_598GNpB<Y7(#bQ<p7#)3Z-hx^&?;CT:d$uYl]G`iv-N*%)8B;/=%#A%%#oA%=`X$[Y#Oqa0X=?VhLa(K>IG>=2_(u?>oP-:02ncqr$R?mA#:PD=-Wgme%aGYb+Eib59Sm>KbjEx'&pfY)Y^AZ6#fZc6#n^`m$,EPb%0hF)+fl:&58bd;%qa[&Fa'v#[M]KH:T)1^#eL@W0lq@X-_@K<&rR6##)DwW$Z-%C:xptE,^o/IMA=j5C?2VoIrO`k#<)rV0V[*W-^[Oj;m5J3%fAXa$'h1$#nhpl&aO)##>M'NB>s^>$s$/<-7W&(%,B>F%XXWt1Lk`H_fe,QU6Ea'%$fe&F>8/WpEu^<0$/]6#*3pL_5u?1*Rem##xUuo._,eh25EtL#)BhBumvjT#aW2uLZ.tGukQ)OuwjWHtp#LAnYRO5AT`8nNEN:D3.7M$MtQ]f$0W(,2kGhs-D8q2:;fcs.veSh($r=+ChPF&#Lrq;-g^ob%]%;;$'TO_/'=VNt8lf+M:_OT@7J9hn:w4<-hEP$+8tWq7o/'Z-4S=n'c;F((^L`W-_-_#/P1uo7B9?v$:'uY-Eq`qKcnO5A%WPP&7hPuY2H278)VgJ)x>_v-+e#q7V@ti_Z(d6<wMRh(kP2>>4w1N;TiBb*j)Xp7S;O2(l#Fp&5ec9'_mOp7/Z;s%i4Zp7,V70sXbYU-r,36.2<v68>X,YsaDH+<d2DRs=]WJ%KZKK:oVbA#qr<Au(.^g%HYC<-l8Qw$-6R^#&tB]4M`Ls-k^Iw<,1W@$[v@;$r>MJ(DQ@##$7i$#b?Jb%-V%c%E>Zb%SO)##<@G&#WEmb%<I=h>%ECpLPu`K_JDXb$A^K=-opaS8tjBR`)]uv6.>q68Tmw+QXpmq&UQNZnWZ-:&LM6R8qjf88>*,/(-L_Y,p@Qq7@H$_uIAXa$1N7%#7Xs=_$)bw?g:Tv-Wm3DEf^.*+(k`H_=L[&M])O'%%P`K_m._q)BxxvR1I4YH>.SNM4OxxGcUa=(ZMBa*DG?K:T9-Z$$W>g$uhYY,m;Ps-*'K,;t_5s.DF[W-3Yd0NE<'`9o9QV[tQo<-Rva_&q+&T8+g/kt&AV(ak6+T.pk.j0FsIu-Tr[fLaGm6#d%.AG*kG,*88=2_K'#IYr$E0_w=oD_SUW#fxwSfL12Er9=jKG(a`v9.(3pL_c%ep'R--@(%2D<-Yvb?-s=)E/ke%j0-/wiL/.gfLemdh2.awiLia1^>]cT;.D6[Z$Q^3Tu>Y?fk4YiB#8B>f$w[[d##FVk>7#PAu&?p*#._m_#G:$##YJVDW=Q?D*eka6##*L-%&8;`dameK@UVbA#Q<,N0u#%GrAa+/(ALa5AI*4m',UV8&;WkM(N+>2_kV,F%/vZw';vPF%h;mp.73pL_#JPdlvUpw%2NBp7J//m*5/G$MEN-##Zk.j0He3=?XIiBS3H/UD*[7p&+eR5'`loM_7f>>#%ZtP';dK/)o(@-*V<SC#J#?s.n-Ap.X_Y)4s[]w'cxLI36lZ7II)YlS^^3Tu*##$E]7>[$1$E#,6mSUm$9(cVwxr,^r@O&#='$l$H==i$Jl*J-;H9,.Tx*GMY/gfLp&4a*<U1]>_P#L2eNAX-14jf1$>E4AY%`8.jBm58.[xG*YS_4=-@&04Z2Z6#1.b7`OCup7Rd8;0EqugL$6pfL09PG-q=]_'6sWSS<7?-M`70l)RZDuLEauI%g%a..Tj^-OTIm6#sb:J:A#V3X;7p&$$Hv6#HKd1%g$-B#Rs3jLeM&rmW)08m^Nw<%9<[8#C/I8#tjh?%P>Hs-k1&gOO_a#P0B'w%mj&GNt6Z6#.(90%)3,F%SUo;O/u3f-^7hFHa2OJ-Hstb$:(.W-&47FRBML<-1,9)8I#f0)jX-K#,aqmnvK'logl)SUX_$##[ms1#k4rG%l5>##e0k<8R>&1vcf6<-oJWU-(K:LKo:J'J3493iCY0I:A`F(LSD>>#1f:;$8b+g$M*hwKPH7gLRA&rmJH3dM[GmRc=6&v#0O)##_J]v,5,VH*%40JLc7c$GQJ9/`]IeF<?7?v$;h_B#;V)##??(,)-&Ii$h@)W-Q5Wt(h.?>#a[NP/V_E68B4W^6Z5Z6#W+*Y.pCa6#0M#<-q^bd8ufp*>NVIm-Rc*4;Mpa`;`D@?$;q)##O;I6DpGp%#Ge/>_;P`3_IR`BS/E,F%;?ntF%o1nWpNt'MB54V.gim6#bm^d%JEWZSD8xiL(DV'#([b6#m]M,/k)5<-#w^V%WT#;B33DhL]`gs7e#_#$psFp8Igq,+O?Cau^wj,,FV+.)EdjOB)j:5K-r:1&McOI)s<PDW+U&B==OZ[)P*e(+I.hb*%baENo>X(2)@]5#Gb2D%k5>##l_<W87[%a+-ACs%a0oJ)I/[#>rh,WIb=H+`Jkv-M9pHm8=.-hL6QZY#&tB]49F[29DlIeFbR5d=Q8uW'D4jf1&Vx8:ZtODW3Mq8%gN?L10<sL^9:_cDjM'v#CYM2iZWr?/C$i?%1*SX-2,5kOUm=c;-Qc'JY$duLg0Hmu>VZc$2T):1lD'7`3`YY#6u:;$8J^w%t_>>,H*$%J#x42(HjO_-'9>*,UQ7bQ7?VhL/_YgLP6Z6#3s-e%$QSa*o4_hLV>HNBA/tT`_QRT_3O+G/%->>#q$#wL0/p%#NEr1.7arn8qk5g).M@5&WYYY#:Pif(8W0prsWuR-LxnQ-em6u%B::X)66M]u3E1E)9mj;%]j8;)N2Puu17YY#We]s7uQCjM]Dv6#FiPp7&^Jv$>ao3)R),##x:aD#saD4#UQe5`$+[m%5O@##;?#h1<Io6#0AP##9r+@5nm^)NfPZ6#kcd6#&$%GrlX>6qHY$5&iPif(B'Am%qYL+?K=7-+hu=c44ctM(T@Ar%Ztv>#_Cf>8sSL(6qr?xQnqZ$,I%t:6V$<l2s2w[$egBq:W::&$TK?hLeNYxu+2M*M[`8%#^';]$SDKkL7AA'.b$+GM3O?^=L0=2_4e[WAB9.B(5ap8.x+OS_NAAB#]Q@##+V,<-&Gf+/T$D.3c]jNX2PFZ%@6UE#8;4q0kJif1hcSNHcgtZ9AXEn9RWs1Fx/Nr-]nVa7A+/YDDcJ&#w,a?$U0B*#U'+&#4n/n$5='^,6w%W%IQp;-YM.Q-1fG<-i260.7TD78<0=2_m+2tKB5`1.#aZIM(:nV=.XbA#W/S#$;cS_%gc4Z$Dm_WJY[-##KQUV$d`D4#Nj36`)4q^#'G:;$igpl&?`+^#u%O(=BQs6Lm`%#%xIns-kNOgLW-QJ(@f7EP6OPH3Oq;?#^?1K()9ft%?WX`<Ia-v5c8u=>QQ)Ou$79Mu+g>r#h7i.:Mkx20_:T*#6.`$#(96I$KM:;$vk.<-9K0LQ.oD3(r;g)N#+;-2m<hWqs?0t-ogtgL+MYGMY:2,)+/-N(8f>F[Y/aVnvK'lo/R[x^k91QSvijmLmX/%#VwgT(cv52'd_?p&'9A*Z8.X0(;^/KEx]v6#5),##fk.j0_i-6/Rrq0(2^[K:lSo'fI,-NWUE>=(B-6@.2Q/T>tqt]uPCY^$+kk$/E^P?_BNgspQ8xiLV,LnfuF-.2R;F&#([b6#>rY<-r=kIF^Am6#kbR+%eKBb$tq_5%Rr^a*maap7k5N)%4K;&.8Cvq7)s>U9>+lo7f&PPT@.*X-RNP/jYl>a(R>VJ8V=('#GFhfu>Jgp9Z?a$#7WQ2&f;2/(X]J#$V?Wp7D0O2(2DEw7eLO6'''d6#tr<s6,w%'._lRfLbEd6#(tqFr]Gc<-c&1h$aVuW-gnraYd?/0'bxP.Q*.Z9iZk):i^fxJasR[a9k8^Fc[x9e*.PYV-xw0A(rk6K#=5vDPC9Ia$R;Y4;tk^>,&=[V$j+w6#DcwM.Sk.j0fvl>-W7:[-O;iP*2<AX-GMrR@wC28IucU:?1fp_#F8'##='Ej9/(no%,uw6#2K#$'i+fJjDIh`.Yt@;$_uX$9,V9*nroXV-4iUP/b,XJ(]SZcVuJ79BYTRe-Qs/RjRK,>>hv%j_UqumsUgM:M_M;>-A;5`%I*Z9MS8>>#.EXS%L^TP&'&-V?gGP^$5&uOSEN'9.ucU:?,I'6/%/5##UjuLMFc&%#WH.9_C1VK*eMGl9R1)d*_[A7&*hcv-s5UhLleF.DuV'Z-.2^V-)Of5hg:Dc`EkrP8>c.K<MIZuu:Ml0.?)n+Mv@,&#pFPfLLO`c)D`6n9*:HZ$])]V$X00d*^JdD+fX?/`J85l9&_R9aHxF)4pu7i.gRlb#WiDPHi]Q_#&uKxOB[ODW/(no%YMf2Vp^jR%#vFb*';Dk9$2bWqI2>>#b:8c&O(7a4.q3L#gu=<MC7W'88Bu`OWj&w.O<7I-)3E_8c=*B#HL_P8t&LB#EB0##>CRBN)>W?#$s7P#g_=`'<)l;-$W3K(5dKq7>q1?%b8Z6#GrW^$x-M8.h8B(/bbp'cUsv6NGYDkuv#*[t]3KC/Kd0'#,,9kL0>E$#Y$62'SB3L#7_93_C`C0_^GnD_eD,F%Y9NEc1gc,2T<=8%E`ov>XM?O_$,>>#+t%v#+f68%:DEl_d`C(&3pC(&2g1(&c,eh2:otM(RS=P(:IZg)kZfJ1>E><B#Xro.IwL[tG%c$d_Z%duNw:MRwQ1q0nJB#G-5qm'q8_6#&fj^oPH0<-TS='%3PSq)4:*/4`Dd6#x#%Gr?pEv$Wfq;-_`C-+wk)F(-$Oq7Y6c59)C]f:p+BK2:?QJ(v?3L#P0_m/$ddC#e(ueuA#CoIbAJa%v]25As-7?#v$x)$2ho&$n$&]$s?1v#Z,b$3HLh/#Kn2D%$)V$#L+]A_TJGsivvO^O9cm6#<Yu##*r+@5wMZ*N[2Z6#f.B9IgxYEpwu:WQwp$0),3tlthM.cnvK'loBimT.sgd_u@ou5&Eshi'0s4SRDJ_8.[k.j0sed;-&+*a%%3c'&[-]V$9U>hLIDZ6#gcd6#+CaN&m<hD+Q_<sQt27b'#m<Aui^fg'Gj/vHKg=s'@8(W-1P#Wowuc&#8BRS.jKto%QXjfLA-Fbjs;WlArItA#+T,<-Xc,<-'lcs-c3OcMm:FPA.IF&#f;i_/-&<X(2TDb@4[Ib.lnVW-QHUW/?E`hL#n$v?TM5s.e>a`-$(>^?^HM&(i?,]-KC_#@L8pc$>1>^$'h1$#c2oi$W@4*ZXP4b$xwd;-kC0JC7-h8KcAm/(:0hd;9HgZ7[A-$$rcfh2F>eC#DctM(&>0N(=9w(WHn7Dt7MUW$q4%)$+fw)$%wq_?qWvZ$aX,+#5(V$#YS3r$xTr>n4R(`$B<Vn*W'A*`'G:;$UYRh(f#U`<G8bi__vi>$fAZ[$:FwW_w@m;-V_639Aqh0a<*og-q0mRAwJ0/`1bSoq]sdh2&64:.Tt#h/9xRJ(N+DP&>2sL:fe01l5Ras-JMB9T?e@BM;L@BMZsU)N62Q/(rmU;?LU?6m-vDs%h+#_#.,XJ(;7*G2<J;=&G;#&)7D9>,I0:]X1F#W-cgLtg-F=uHd@ti_mC<X(@SSh(v^TP&:Di5/UGX&#.edIMP>+jL,vu&#([b6#-X9d%218eDDQL;C`-]+%cMYb+p2Vd*n#p<-2uB[%L-Z'vYgdh2Tll0*<>_W-0eIlV?(<:m/Hm#>lHs(tam=-(4AJ]$a`D4#U3=&#;96I$$g&g)muAht.UQc*v5QE<DsDamOH2o_Y];8C'9P1'?^Zji#>nLK<pbb#2&*(*5+wS7XDOQ27:8Rn3KbQ8'D(69=9(,)NGF?n/#;-26Nt2(`Y2mfNHN/2gP<o8n=vV%eRr;-N)]3%]-]V$OI+Kjidv3Bm;kM(fu5m'';ft'7wQB(;)w=(itDQ8[NI1CxqYg+(4pfLn<@lf$?+ZSO`^H'*&E.%>*+ipVq>q7;w?xI=2x?t#P^^#hix7.4T&c$o=g>$Q.?-F#Hm6#*7@,;RPBj(QNRvn2KE#PqxrH6cppl&W*<a*sC;N9C_dZ$<`?<.?bHM9@ikA#9D&?&]<8<-&99g%FXk`OnLp#$tGk4Srm+49U`_KEZ<W$#mrip^N):5%.Cjs-.QED<Y19Z-:5;Q9VRH?$PRlb#XNnv7ucb]ug7?28WNQ9iZk):iLXNO9QPaQL*AQUE<d-W]hso2Jn.dNu8oW@<eS-dbdt$##q?>'v&vQk$HB%%#3rm<_38`3_pCoA..0Ed*2Eup.jTY6#3oq-$/dd6#NH8Q%TK*I-Vhe;-8H?e%7m_-;]Xjjjr6aK_8i>>#]Q@##/r(9.CU95&*ghs-vpZiLGSmV'ER#$%ep3H*n2n`*t0_)3h=S_#vODO#HRA<Bxt6cVGt*GMoFED#Y01)Q]R+PCJ[@DQZIf4C3O6[D(o%TZ);0ZbcO(S#<BcP#atP-ujVsmGhmb?9hJWQGjsk?9qx8;-u>BW$&I=&#^d0'#XUG+#/Qho7]pP]4>34b*PYUs-9x8kLow[h*6@s<-hUie$^e#I6%ECpL6nv##(lw6/opp3(oYBx7H/`p/''d6#Mb)>&_b+=(/PiI;2vQtfnA]hC%]w],N'Vp/)r4;6-O6gLe>W8_?nXt(wgut(#&JfLHb,w(>Dm<-_bKJF:Sij*/p97BoaYlpi6W5BS>*s@d6[a4r?>'vQuQk$gh1$#nVH(##([`3iBXS%7(e8.4sdo@?jt2(+w_pfDsXn*qDl;-`nmt.#a<M(^Z6R*B)hJ)HO%<-bPU@-22#LN?L>gL3D_kL/vFRKc=dF<MiWj1''d6#HJJG&_KPp.x+OS_7Yk;J*S,<-=pF(.K8#LMa2CkLD=%eMoI4T@O$mG*RXp%5Nx^Y,sq-x6`T^:/-E6C##F/[#$`^F*4hA8qCfd8/Zk_a4HZqV%P;8Y.ae_F*_cXS7?b)A?wT@V/=;<_G`wMYCmOo_#^ur=Bxt6cV%mKh<'kQ;L<VM>#CkWX<Z[HA+uH36LOubmVg<PT/jVsmG54m&$[xs[kx+H1pGSG9/e3e>Bt&5PZeLn[DJ^[I6M0@#3[q@p$aot&#^d0'#')+>`XK]T(UIhkL-lI(#ULmj)cZsMM):#gLh`,T8g4.gsTkv##RciU%hO;ppIZRC+=Ssx4S$x+2UTpY6Lk1p/48=2_;0?90%EZ6#$UY6#eoq-$A+2-4q>Yh:Qfij;;[0l:4pcjD[R-2947A=->u$'&5#%tpb-0A_7D`3_%pk-$7h:u?Vofs7/Yu##-FcWg/#5$Mb5i]$eXno%:C<PC5vK^#Yd`Y#gFr/)`X>>,#6'<-mVU@-N7Em&YXGs?ggpU@eI_>$0n2gLsfm##'+kB-#%R%&olkr-A7Is-GIhl8Oi`&Ps3iZuPlga5(X/@##=eS>Cd,98TI:69E,W]+KtxCW-5d;-b.sY$VBf<_(9nD_+/KkL.iBb*_%3<-ZOx;%a,t*.C$a*.s,=r7kY>[/Of+E$b4$##oU'<&cBrB8fKrB8JIO)u-o(9.KHif(StP8/8bd;%%fcs-:N=@?cN9u?bDv&Q*gYVHoY,<-67C#.R;?W-qXDZ7^eZM9@SZJ;a>p;-@AY9)>Q9X-tN^#RZ=6##m5Ja*5X*68#Z2Z-$h6r@ETk,47oWiKW)08m&G==.])R7efCb9/x&vG22d98%vM:D3A4:fhn'*)#4ql1%4ac'&bx(k)Y'w##Esdo@bnRfLr:/L()2n6#nxls-bd3<8&SfS8RU:N_JOZY#.9xr$,N7s.YuH,*Io<#-kR8s7T^-$]/Wh995FoO9GZ@Q0''d6#6&+_$87,oJes(NV7t)d*U4Nt-3fsjL+O];8U=Gb%v'.0C<>C#$JD2Z-f=]=?We'vHA<#?-M`A8:]+?:vq'CR0'Nc##M3=&#eSwC:dGE/2fMg;-o$Cp&ELE0_<I[&MQFD*%7O@##=jXp83c]x$:N(,2SAMJ(*'A*`G2W]+W`Rh(G-$I?6242_]iEv%IWXb+1N70:kA%/5icv6#.),##Zk.j0ngU/W8ecgLZ<0s77I2W%CN>_JCoWt(Zhtt(#&JfLoiMF&--IH3c/ca?D-Mb*,)Am*:MmW-89/QLRcZ2rec_?[Nm?]4F9bs-@Sr;;E0T;.CQ#U.>/5##LoYT'#x@J1,.e;-F^To/:=]6#ZTY6#ICNn%G[iB/^NsR8UT2W%t*En<r_YY,`5B,3,L6gL^P8k((G.?-4ViM'<h=W8oW?M(ja@C8$YG&#Rdo;-^k[X$<tx+2m`%-kH)=g&6O@##]Zevn8tuL%`U)##G302':DEl_`M1(&kuED*ga3gL*fZ##Msdo@:1A'.5?WJMMw$aN2gM0(bejj9P[vr'q^<t*v4Ik9vo(B#S&O/M:_6m8fd1^#5]X+&cDut7<6[;%T-^/:Gg@dFYf$B=^hHP/aJt+;7%uw%J$1*#^Wu2;'3ui_hL(F.XLTh(7Gq<:Y(VV$1?_L36P/4;'Mi2:onUf:)#LX/,QZ2;2bXe+Fm.OX/mUD3cjp'-(+==.&#7<.FZKv-rpZA5R3sA5h>:Z-ODOJMb1TduUbow.-]6N)BOUJ)A9CmCl$&x,fEnq7ItHt9<Y74r>eJ#Glh.5^eWK?-)#dT%C0[W&HdXr$WqA?-1FsRq:#lLWY2Z6#N9:9/:eS@#uJ$N:m:`B#-d4mu21^,h;a06.6Vx(QI'^L9x$#WoZ4T-#;t<7%SpCLsc3*$#0f1$#dcv6#?Y5<-qgOa<_,$k_&#R]4t_Sh(=X35/lXAs7q't-tFL)HGsAZ6#dTY6#uf:j0>0968FGsbN[^OvIIq$&OQWXD/=se8T/2Fa*f?KY-u@^9'@GsJ%+q(,)fBai0X3'GVfL6(#>;hm9sk[A,j47#6I^t<-QRdA%_.Ib%uU>>,-Fho7q7`p.?3pL_.vpaYHGF/MkC7j:WocG*/?=a*N^cT.ZZc6#A`0`$,EPb%]=]6#O:2=-hLMX-`&Gb%U21=-UeUF$<6/8+Cv0xPnvO]uCM;(.v+^b*kIJX-jpSpBp#e+#sk0%%_dim*Y8Un8KWUZ->ZKR/5D<6hh0$>YDjBS%ih&<.MqD8%Jrxd<Pg.4V79kC9rYOM_e>Z]'uGY/:.-42_-ExQ%JWS[?K9=W84/cq_??Js*uR8*@C$+1WM+mRcs4.=8Q[P&#+Qkr$.u-62l>p%#H;KF_@LZqASdh&5o;GJ1qpVG;#uRp&YDCpLvrA3%c_D>#pnpu,:DEl_2Cjl&734m'tDJn3dk&e*[5e38,GY##p=*#.,A8cNCecgLT]-lLT]-lLN-fiLwBfr8_%=][o=Xv%bJYb+EfOp8wZ'^#X-+<-GT2E-/5m9%.YDs@pm'hLsIhkLtiTk$M'.1,6n9,d@8X+Nqpdh2&*SX-Mx]U/(TBln+][CWM`Wt.rD?A4x`fl2k*s+;RD0m0:]q;-qrve%KFs,;$v[KWbICp7>'Ww$Cb`Y#WQ)##Et@;$hMiW.Y,lA#qE4&=<jn$$pS%m&M68lSnqCZuVqv)Y%O/@#A/Pb$37ha=1S:q8^hHP/E>XuPut=#@LV3v6i$jc*0EEZ>0?4N1]vlx4-)80;Ahe8DX?m^.bH94JXNu%nE=>GMY2J_=5&Pp8b**20._3<-D,F_$..@>#UG^]+QWJm%OPoD_18%O_qI932Q7LkLt5Z6#QkSBJ4+L4(,ris-Qr2a*FpHa<$Y2W%o@cw97Vvs-`gv_>J-,Q<rICF.b>n*JxP6;[;@CsITGDNV.)k?%iIBwR=pG]:J0sW%6nFJ(d#60`_m0H%o)QM'hI9>,lRiu7]FFgLk.fo@x)NfN]UZ##pFAA-u1w.%F9AJ:p[@.koLD;.SlQh*,d1=-Q/d'.'sZX-3u0X&xhQ##[q@p$U)]%#U7*T.anl+#PCab&0T<s^igjmL@+YL<FCBs7@o+cG^DZ6#1UY6#aoq-$.^Z6#^fG<-efG<-_W^W$ncRShEO:M<a7x>6bMIV6kk5p/VpA,3F].w-_Dvv?QhA,3mB$j:3aD5'n]Bc*=1Bt-sW2d*<R/RADNP]u'jt6F0'VJ/pH8VK&%/BfmZRqNhlk0&;i18.Pps+;M.&7#88m`%,P;=-eB=;.Dl.j0j+@m/xCa6#+^Z6#;*vHP=0q&$CErB842i5/tsdo@2`jjLh7V&&mB]/:8bQ>o8%,s6@sAqMgG4;-6N3/`n+AZ(x?RS.PuVq%06mx4QC-j1pqJ88`-/W-`&Gb%iLN)<C#L/)gH#w-Yei+=ZvJ)X$uYl]pQ0?-1pKl)au>.QMJ*0;RVJ889[g>>=PAvSjAH>>?Hv*$%:SS/fG:;$N@A]40Hj29QPW]+@eCP8El%7#Z/5##(l.j0>W>G%x-VV-lRN;7Ji.a+AYp[SLHq&$lx*87<?7p_m],F%L2aN;&@,gL@5fo@kp1d*MO/q.C3pL_j^u0jL`k/M15>QB(`9/`Jp2(X4qG,*wEk)+tN##,VtUo'$R35/h(r]5,K<gLp^o()W4p<9,#I?.]#Fb*]sUd;<bAD?E:mhkU8T10wZds?50H/2I]AY.,),##;4;S8/hBD3K5N($95roI:Mx6'VF`^dF)%I%@t?cG^[Zi9'URAGn./^$oxG]FwT'7#105##5w[K9tZUA5r'gS8(-wf;:tPGEssBm/pb/*#<Io6#C77Q/dr+@5%ld.2>7a5/c@$(#h_0HM6,'=@lu@5B?Z'<-?5%6/91>7(?Q_u9`Rq2:''d6#*G48&)n,=(JW,*,mPG&#?DhQ9,NX>-FXId3,#KM0mh.T.5[c6#8jMY$,EPb%]=]6#*;2=-BMMX-`&Gb%e$x=->mEc'hGKQ%N`LcHSwFi.X>)2NwYe%+``66/:b3:.v=ms*Cua<-.9$7.3H@0<%SuG41MX</#BkppFOm<->'iR1:RZ;#^d0'#><n%Beeo<T$F9h;[ODTL$d2;,oE@/=fiYV-IFg3ipUdY#$uYl]sJXa4LM>2#%/5##UM]]$JM(7#>]&*#.1[`3GJHK)d#60`,Sd'&.Tu'&B5d'&M@HK3a3n##<Io6#7Sl##Rr+@5e-ex-FQOP9]%#d3Wxu;-h4%6/`k<2(dsWW8eYw;qVt1DfMa8e*>p?T.QZc6#J_jR%[x9[KAYBP8j,D)+g8F/2D93W%6%2XoX9j?#w5Ks-IUI1M.V_/Db1N@$u7XI)H'5N'fL0+*KG>c4U6#O'vvvfC5)tA5#0^#6kQ&i)#)W1^E;SQ#j3SO#h#fT11/5.38Mr<7JlXQ'T0LDQZIxOCK[.)Q=%Ld2-M;6&KI?42bKh$$X%mKb>5>MZdFe[D9nH1pPdOLR&TmT8^d.L2ju$W$%#0w^V_le53MPfGKKF*#IC%f$:RZ;#>]&*#.2f08v$,p8*hYH2;Ul##KY^N('&[6#jcd6#4ck,6)9#,2q)$*NQ3q&$k+bo70RC2:YC0Z.%wJ*#=ILD.aPZ6#9cPC.FF3]-e_'v.pw6c;mStGX3k$Y%?$]5%#6S-#q+3)#32]V$Y/0_%RReBn;0q&$mbo6*.?vG2;sdo@`._'#W5RL('&[6#K0X7%:o4;6eOs/+hcYb+4<bL;WYr#7HU,s6c*KM0XQT`3a^93_fw`K_f_A&v-o(9.R2'&+7wV8&8bd;%%fcs-$2<:8?51B#Crq;$Z)9v&j'D.3PImO(k@C8.DlE<%HS:v#V%'U%b8MWB$%@cV#8&M^D/J2v.Jl%Ae'cA-WR^11h<x9.?'`e3iOe7)b&:^ut5)ip%`,Lb;#p1ZeR3xDG)(?-n9Bmu+g9c5Q(.W$^0'v#N@A]43'0T.CO>+#hWVe$Y[=/O94*-E-84m'KQ+W-mBwq1dGm6#uT+T8J9jV7Oc(<-w68_%u.Zb+[HNo9/GjV7mXjV7aWeM1YWeM1q51U.c),##I9',.(0].E&ZeM1AERqI3,C#$sM9q7E<aH,3Qhr2t2GX-@I$NVx1$##vLDs-oLrA=@/(F=`e&7#B/5##3l.j0tjpXS*#'X@K@^?fr(n6#9e0'#Vr+@5Oi732$'T*#*ht6#bu6A-+7%'(V-d(N3@,gLU5fo@rl^x7C2e#6''d6#P,sF&qB,=(xml=(^_+=(nb=p^:[pK%GX-58q*7G;#]B2_H'ktKEk&.Eu$XIbimiw2Hg'r7I=4+loXn[b9g&M2r?>'vYT1?%[@%%#a6D,#Z^:e&?[[Y#np<;$_Pmx=xDo`=nnXveg`<v8?<S/;1#f)vrS#oLb<EMMG,Dc1NKx+;?>Q]=D7T;-d^p#4.q:=gc6mv2/OL<F1H5$.:S.Da*Et%5il#H;=Q?D*$eo@b=[u##GEX&#dcv6#<Y5<->:gK%mf>>#l^CG2N5[`*82e4_<Y%O_oAf%Fg5Kv-A$u9)fm$15j_Js7Y4+gLB5fo@^HRv7K(DT/''d6#aSLA&][+=(d0l=(,Ca&&Owos-fVv??nx:T/Fw@;$'/h;-9xAgLAwRiL>6rdM^[d##+G)s@$-c;-sXio2$,Hp7/-4<%86[ouCi].4Rf(<-K`x)e%-lA#m1W@-.vY,%=0jqJ=KO]uur0R3(h9SIC:SYc/9PM'SK*AF#`Q.2FUew>qJK/)-JCV'3^nD_CY)c<p.4m']`C9(r?Ib*5UE<-wAKVK/^DG@wcl]#]q.[#;rKb*tT?T%LMrB#vgV:_qGa-O6+Q:m$Gmf1KkUiP,IVDWi;wpFi2Uw9Y^PDW33u?Kb>O7JI`e]c[r$RaSFg+M@n:$#2rC$#mH>x>drWdXt$_b*UU.<-*aQ[$@;Rs7HE]>Go%$Z$*d*0U`@+jL#@*c<7XV8&Lq*<-Dedo$EQF#Pm^?CB$thS-,mha'%2tA#?>Vv@C7(p7'@A=%n5>##Pqn%#7N##,xuED*:A@&,4fCgL>wv##Csdo@fa1xPAkk&#=Rno%L*:ZGq9kM(OM:3((k`H_urlv*rV-d*&E^m8nggJ)Ok/<-2JkxBh]ID*gQTR/:+1W#71k#+_1278@.MDFTa2+3q$r+;[Apf_Px*)*bFZ+`7(BkL,/fiLFPJqJ,X5qr2F6qrproNOZXH9iXR<X1w#df(.d_)+f`1(&BA2(&[BXS%l#N504cCh5uR)20DX;.VWe%Nkoow`*kS_s-9vI49D=Gb%aIo6#JDslAc7`D+88=2_e.V@GVU2W%*ZM$BX_k[$B)Xh<cH9Y.MDJ)*aBf[#q&()3e0nG*4ARL_*D-?$CA5MOH.q&4&>j1^#OAu^V?Z.3isp97)If4CBKsp9:cudNb2R0b>8GMZeLn[D9e-loi^(cinhVW#3>Ws>8KXeG@#lT9BT:JGxp_TK0W$(#+k85&$0WuP((*/2c*ofLuq42(>wEE%eaTP&(k`H_LU*u$2C/q`qJ5$gF@,7*l-M4B@6=2_o%D_&rs6+WAiILa.Ajb&%s6xG'uR5'*J>s%?HBp.75^+4OPTN2e$ZwLpRWD#jW'B#GoXvG_>d>@TWftut2NuJ+E^?.^vvD#Qu7luRk8Po>P_C>q[)f:.rk>IT966LLK:@u&$1hLBhvu#F8'##uhc29:(PW.<G`6#:KEU-v^Ob2P)+&#KTUK()2n6#I;G##X.cp7xJP8/rlr=.E),##4M?p7U#$vA:CHofr_lo7$HC#$aFDp7Gp;DbO*%]%)mM11>_mRc=6&v#&uKxO?Rx;%f06YYE:w22VA9s754Sd+VGBs7VJ]WCZ,ix$7##^?gYc8.nk.j0N>vM0xsqFr_e32(>5A88q#1Z-010B-/G0#,$uYl]U9I%5+N=2#Jm9SI^<R##$40,)r/>G2]Dj7[RaCH-JWZ1%2r*c<5lA,3Th9$-82e4_>`%O_/T'f$7cD0_n.O&`@CVV$Is`k+,E:-Oi,T%#;Cf6#$s[fL2nMu7EEKZ-''d6#-/t;&EZlq%'[kD<$8)e3U6Xc2d#60`ooc'&Sid'&#%VV-`X>>,,oCM)5#g&?-oYV-9@DGDHXe<-B%^L,quH+<VOh>$'w#:*#E;'Q9NTHmVAP##ujwu#<0cf(eBKuc.S-W-=V-F%fTY6#8oq-$.dd6#c;g;-(rY<-o/u?'s^f;-?)Hc%`?CG)Qdp;-Shxv$.B,F%v?c05XLn)IwF/,&`c5E(MmXb+8)M1Cp6xJNX9Ek9WV;s%>jc>GJ,-g)_moM(F.W>GwMK/)V]q=-Z-_$&N)^#@lD=B%^7+18Z*s>nE?:*#Iww%#R?#?_QtOp^kkiU8gc$d3ueJx-ov:d*90Qm8nux>e9Tq['WjK>-hh2U)c)1Y-?FY7AMqA'-DHU*#4xL$#9bS)9AD)W%Ur:T.Q52/(M4RMKfUSX%YxED**'A*`3_+/(j4MwGF>vV%^w9[0f^LX%XmKs-'sZiL$']iL)RrhLppYp%NgXb+1?2R8iDS49B5`/sM73Z'S;>>#FO;;$n>MJ(<CV5'IWFs-Q6<N9/jUB#f-XJ(4LlLg*+=M:Na_v@_4$##l^Er$1r)(9/4WVR7#L<-wZN7%)&h;-r<BR&Abdl8dB(lK]/DB8jn%r8pY)HkX`u'2NwNn815P&#O'Fc%GM]p0<g@^(Xx3-9lO('#Ij9SI;>*eFC#HA:c0O3VpD>&#xo2F&G,n=.R/4&#uFMm8R)`/)K11Kab;EtI_Od'9a+#at$<McuQ[$q2Qh%T$]M(7#Pe/>_Dl`3_V>m&QUt)$#j2$=(A1CgLfs7]%lVg;-,Y_P%s3'T.LZc6#^Lit-Y6RV8E>T*#gsH12+v?D3ET8H>e5Z6#D(Pn'gNBIEB%`*4Xf@C#vl>x6SOr_,;c&P>-$8x,QVY,M]q.[#C]R_#a`Bb$IO9F63f0X/(l,nuGb.,ewx=5QX>.rmLNfWA2DS#89?3E[on8R2ott?Ndvn2>EeoZ1,_W`+[XWQ9ktLB>kQ]NW2ax`GGCq3:e]Ii1#m=H=nJ,l9qT;lDl-$B6Gst-#%/5##Qh%T$<0B*#FPj)#.Hho7t?j<-b8=i2<Y8>5]r2MKua8w6[6]f182e4_E]7Q:.gv6#b),##<l.j0'2+f*jAYq7fL=2_-5V9V:Xt/8U26%Pjjf2D5@U];PaZ)G*bdYYqP']b*U&,2fU&au,,Bm$.Q>+#FVx+;R)(<-2Y5<-&t,W%Tld'&kdTP&_HWV$:DEl_s12(&=O@##Fke%#<Io6#VU2=-dr3RJh_]s7CHho7rdF?-/8=Z/:=]6#FTY6#LrFW?l7/9&''d6#b4A$pvYMT&au>>#E`=OOg@vu#_2CW$d`SekRem##-D(d-1[vJaT*LRb3XeP/(jw`*p89Q8#*jH*^nVUU,CkmLd;6(XT9002wfdt:8W+T84][$$+@0qBNSw5VI=DQA#)1;'P;0Q8%<SZ8o@MK*@$(*#-C,+#hV#1m@-M.&6R[Y#T7*c<@dJs7]FFgL_+fo@`L*T.1Da6#r+Ve$Vqg+MXY06(B*wh*8KRr.o3pL_PPGj3a5Z6#Ik)PcU_d##v7;h*Y=IU@dv?HFVBNYP]3+X-1Di/Emea?'isFX-NT,KE(0v]':)'58)mMSeHnu>IqUZ##41Ip7Lp5,Na]l<-#t@p2e]CX-Dgr>I3IS<$%CAp.'VFB_Xla?%+nkS9?'mwR]SGrfD&)22o3<)#wi6eO[5Z6#/?5q.-1@>#^IY9'p`6g1&oQX-aIik3m]9K#^KGau?3tXG$jDxXLkG&m>kHm8[e7pA4Wxv@L_(Q;Auqv@d5Z6#Iq<^%f=R>-Qc2q/TDa6#^^Z6#ifG<-mJmV1`liu>r3Rc;AD:q8#_wX?l$(^#7(^^-g2OZ@'oD&h%Erg2uCNH?psu981.TSes#98%=mgx=rdv&]%J`'#dcv6#wEfb%oee'&2)kQ1ZwZ##nsdo@3%###FfQsA0SP8/8bHZ$>3Wf:?<S5'Brk2_hwD0_XH]&M1)`3_PwE_&Q1`>e?:F/%;?lp.w3pL_OY6w7*UH`.uIk-Z]5Z6#^CnA-jZG[.<[c6#OLpk$+BPb%]=]6#2v1@eqsNuJG?i&(#Z]-3Xr<;PM6`ruDPaJ,KiOI)rxk+NZlG+`^V]O1tMlDSD.vl/PGYb+?4n6<HCg;.QSrmhYJhX'6IUD-J=[6%?:187oI7g:O&&B5`;iu5N9L9/'pD5(e85m:'c_FE/.tdt7Ji(a0qjn%dvl[-@bb@>DYO&#EcY)%oee'&a<O`<^_&7#c/5##B&g7.RdrmLF>+jLcMm6#Kj9'#l&Z9%j=?>#AC@a$7R?v$oxbt(IH]'/(;_'/]Kto%MJdp.dTY6#T8/ligmsmL9&.Y8mY#v&T#Iu%3lZb+lGBX895=Q'(J:;$P8A2_4x)rRacZ-HWXJM'5<IM_#h6B#rMx+;sIi8.ol68%hBo;-SaLw'V:SC#(1ro.1`d<-='rY,NPhW-A+bCQqBfr8IXW5_c7tj$T=5N`ul_OJi-$.<xP_m9cJ.;6N.Kq01/M-217u4MITq&$:hJM':-V8_P7`K_Y7T`$fj/%#]r+@5ct[fLb1cp7&%b#-wjuu,nUiJ)tJ(=-rvZ7:e2Nks(kA+%I;6t-oRo=@WEvTM*H><KjZ$V@k3(B#O$[m8;.2^#dh[f$Rd$9^n]ud$bQR(8D&/C#S_$##&_TDWl.bo71F#W-bfZw'LiRe%7?b58[NX&[:+,s68l%v#qs,9.psqFr]Gmlf^MvlfbnuM(ZH7g)-BAfhQQ^PJ*M]YYja=u>rMw&#T>-_uVc4C.^]K7`.kfb%S>=/`&ExB/Tf:;$9i7i*<oJNT1Iv6#/64n%oq,lM5^EBOUkGvGMY,:Vp]%-Fs4cr*8H,t-ciuLMa]&%#^j36`#f9^#nU7xG#%O<qdv8Jb0w(hLhe9b*CONa*X4Ib*4gXa*2hE<-6i^S4<^.iLtd7iLm^4%(([l2;emw%F2ud<-&<?a$7%EX-JOFdF6wCHMgd?##IQe5`(>YY#lZfQaY$A;$).h#$82e4_Kx4i%>juG%Vr`I(A/o<)Z9=8%%Oge%5@N9`7IW9`02&T&+0lG/s-;K#wxR6NP>W?#$s7P#YxKK-1aJc$9r&*#L&%9<a@s(t+1#%2T-=G2Z8wuY?uXY,NAK$MOL6##jk.j0KSBo/jrWM()2n6#J_Y-M:4'g%f]>>#>x@;$(k`H_XID0_+lZ&MKT_X%W,Yb+O3k=?,xE.DR2H,*SfH,*':3<-G_-A/ee%j0a+T+E5.=2_oEX-?fjN^2dHD1L61v)46otM(2DJ1LL[)s@.#9a*&_]ENi*^fLZxoC8EuT>?fxnafrjbx-Mk$:*6Q>:.k.@s.,w+Q/8#>c;=su.(dhg]uVR?AN8Rw>%A398%0?K]=2O>s-E,Na*Me`mAai_v[_989(2O$>)`g+?eaJZ6#eCa6#dujh2&43Q8_6arn,s#<-s0Zo*(dg58L6R^52K/2^0iT0PhX-Ec=e?m8gSF&#&8gv$KT95&c>b^%,1Ib*`:js-S8SYGPsR5'@cMs-b$ffLaF5gLd(^fL+RGgLxqJfL-_YgLoOta*]Ais-%7]79'RQ$$_/h^ushNpuSUb,MZuZYYku7TuOqMqgMp%@t'#J^.3r@p$SbFG/c5=:_D%LkLc6T;-#Q%&.P7$##](]q)YCjU%+(pji-Hk8(+o(6(x<Pt%6e9uHwHQK)SwC.3[B=f*arWT%0'lA#[m9FGt`Yo;%=$C>cI/lOM`IG#`Bx49=Xd31-5B'$%#eAIih81<Fbb,$[q^K-<Yjb0$$xu#%3WuP'sZiL<sugLgKux>I:u/EbVm6#>qn%#.r+@5^uc;-Y:X3.ct[fLA?rHM1YsP*>4)8E?'q7J2lv5L;t0ItU>>1:`s'r(6/loR-2wF#nbm=b%c:<%6$%8u&^nT-QaljAW=KZ-N(a6#+eQT-05T;-W;bH:7I0j(gG1g)XPs&#W>`c)g08j(@nL^#Yd`Y#f*>#-mREd%>Xd--Dqv--Th%<-'Xv&%IT=_/@CK7JYl:TLlXpw%v^^<(_[5N`J?qP'V8Mj'^Bc?KVAK:'*S,<-EcxZ$'DT/)s&<Q1tu3&+9&6<-X%lL)]pQ7e$<Q7eNlKd4G1uo7NknA,$0QW/E.xR&G,CK*^8i]$Vrc;-gaBE9gK0N(.O-583Nj/):;ko7cvD8AI2c;-cl?f:VS9mtp0/9.Y'+&#le)<-STCx$=&oD_l1ZCFWWV8&w/0<-eiNZ%#S##,:b/2'tEBP:RO[A,j*^A,XHH&#k,kv8ZAm6#;REf4Ajf^/jHKm0r.u?9gg;A+a^93_qe/,PL2oiLPqIiL]wnIMredh2rdbU.(-lA#d%(m8N3lA#QurjV6#ZM*g-8l94PF&#uKo5/pMc##ufKa8s4OM_tKQa$Xtbf(cj&Q86f9N_-MYY#.9xr$aj8Q8i$?x>xhV^6CKaB%_fhX-9H1nhKM6I8=%U:@s*8Dt;wH/*Eh43D-;7N'9p=VQoTC`NCh*(&[qBW/:(Sr%OJLe*-qWq7%Dpnfi-OW8Ujt%=nwQp7*;fAcRJ17u@.,a*mg9SIbi<q0)vcT%@,vu-<&8S8rI]^-^)HJ(?T=t*6:JQ8RWaD+J<0T%f6bq.^TY6#l?sj)n']b%T;_X-)nX^-B*;F*Mf+:=aKIK<(&?&#^d0'#xxw=`MXZY#gZ<;$x1b`*,mD<-]]B3%)334(9p$)3`U18.<Us1D_Gl)4(k`H_.9]D]3`G:Al2YNDMfZH(xiOe-=/to_46:Q=qu20(v3Pof&j;5(PX-R9s<Gb%97qx(v,il'GvgX-PHI1Cp85Aubf^5)l&SV-1/K58$R_>$PT:g1+6xu#fBai03mHrd#^@e*GS(<-LcPW-Ma6LE8t0*#RV7JRWL?##?QWjLiDm6##C-1,M@ns-E'M.N$QZ6#Bdd6#S$%GrV,iOBjCS2Fp]JB(&DZb+3u9g*6d#X-R@L@e]Z6.6eAZ6#+[c6#$V[F%1l`s@WtRP/I<Ebl%1wC/Rb?sumG]u*3<mY-20uAQje'QAh,Zb@dxp=#Qe7r7ba,8f3hkn/q(no%A.?>#@pM7)Z_D>#=u3>5H0E.Mj9MhLr8Z6#E2+WS;B9?h2dLZ1]i[2.k6fX-BDXFNTef;Sv'Utq7Mp5+0pao7_1o*+jZAJ1D'%29][&7#UPDFP[Gv6#dLem/>l.j0q(no%7JhW$,<,F%[(Th(uT95&os52'*'A*`do@D*fGqh$W[t9)M=t9)5AW]48d[;&OiD_&ZroD_;P`3_cLBpTkAa`1D&gLCW?`D+`JHU%n,5=-Bs`E-gfxF-FM#<-BFtw*]KsR8t&1i:1/Xt&)^6k*m30Q9m8lA#wcoJjq<cKjG^/,vIOfX%3Nc##n>$(#TvJB`UqZY#os<;$+.VV-+_an%,#<X(*Wb&d*PV'#<Io6#3'U'#ZQ#11E,222p?N)#*ht6#5LM=-nRrt-&m2+Ndb,l$95pnfPM?/;QpBc*4GVq.j3pL_v[$?ek0XYfXkm##d'ChLJ`@0@twiW%^L##,jIif(HRP8/iho88x1w%4pd;gLX8Y&@g46Z$v52^QUda&du'Ij)A,YHlxqtKl^URLAxo4b*<F<X-c3,Kjmkk5A)d)G;CN9wPV[%S%)5%V.HFhfuNvb4%aLco7Xmtv7:UO)#F`hU8p@>H3<?7p_k7w<(v]pP8Wn<#-,$>Q/+dd6#C$%Gr1@3j9uG690@al&#ehw=-wpB-%F5-F%3$('-aqFO'(J%L:ssD8AiheS8lHWcs:lgd8:rJfLa67##Bxq_$R`D4#xom(#QjYY,Z^p%4d#60`s%d'&<#d'&adTP&DV/G5&x+j+7Nsd*:os204dd6#E$%GrJkw[>N@[Xd`=f[YerC/u7x+s6:jG0JcEa$#X:4gLr6Z6#v2^A&_>Z6#sZc6#,6s'(hMH78/GL#$mowI+H_`78H%TCO8GL#$UG8<*=1s5/-g[%#-W'E8x:9v-<-Os-D:I<?M@ti_?Gu-X$@2t03)>$M3&@+<1oR5'ZY#fV2`<dXPbdc*d?m29.CS$R(catE<Xdu)$TdC=aom5L<o6]k8XAQ)dT06/+f[%#j-IZ9oOV8&oB5O'6$Ab*,m^p7NGc#-NLDM0=N'r7Q[&oSH0.<&Fb>n*'Gmq7_2efVA)Me(64Mp7_cqS/S&-R8[7B,3bwC@><Z=2CTlNe;xwrW%9f[%#D>N)#on&W&/+[Y#[9<;$iZ95&W/>)4nh`<-'S-m%[8%O_ILZY#dnou5VCci_0)?H=YfVSC2`=Q1@Gr5/_xK'#s,wiL7Iv6#m-M'+G&_=-K=(E'-xh-'RGhX-@7nI;^v=mB&A[K8&u)s@_@Wn)8Y74r:i*K1?2j[$/B%%#9%N9`sTVjV,b.2&][V*mgAZ6#cTY6#9F%gubc<*GxaCLjg5Z6#CI[*([]Z))5k]X-srW,GY#oO]e1GU@-:L#$pP8<*J=8j0Ae8d2iuw%+^;3VZdo_T.X/5##mPl)%U2;D3G3G2:(PP'$V80U1?94<-_G`/+(wJM0vi5W-.9q2D_6;^U<>HQ)HgU':KI`v@*W-k*cGun8&Y)w$$h[%#hiQg>.PV8&0Rc>>.2+MauDDO1rQcv.YW@c*IA']?kqP)O$uYl]+w?5^6qk0&VeY($Se8S)5gY9.W)?lfMBE/2x^,4'IWbZ00bM3,k@>J<>L.jO?38G;m+&oSsgn@%[I3]-qw]&4rtdg#Wx3===ekw$F<YM#IowM1Q`Zw-+jGF%KF'#(/.jc8(*<'6B+3jTKv'W-7mr($i`m6#KAP##b]m6##R-iL^Gv6#tg73%7[R##^<2=-de1p.4dTd+bAGb%7Ek-$Gvk-$WPl-$h+m-$x[m-$27n-$Bhn-$RBo-$cso-$sMp-$-)q-$=Yq-$b[k05.h-[B4<k-$Dmk-$TGl-$exl-$uRm-$/.n-$?_n-$O9o-$`jo-$pDp-$*vp-$:Pq-$Zs7Z$.UNb%YXr-$a0V8_hqN$>V62j_KPSY,naFK)&>uu#/0W_.-&;-(-tF:.#5Ee<u6[&,pTZJ9.R-Z$jS[Ztu(DCa,q`@5FFhfuA2j[$NR?(#P[.,)5e+/(d#60`*x/i+.t)d*]B19.1AP##=58L%DVSh(5r:;-gIw4JuS#E7m^T_04fnw'Ju?t$jrLp.$>05`uSN4BZbrS&xHOp.ol68%5Ow-HisZ`*i-iM1n^w/21P(,2g6DM%o2/S'BO=j14.Q5AHaD(=nARs?)li?#p*DY@lc@<(3BckkH$if1S5Xu9RtdU0aibv6gU9-<QMYg3tP>l9[)*&51H8@B'[nG;Hqt,$2/w;:87qQ0/G^'$XDrG>-s4`-S?K;8gHH>%23KQAC<Zv$kTnqL(;V?`EB:=%,Le;-ufn-F(:#gL]5Z6#hq3u$NGGhMR%1kLf'1kLH6Nj9IiYCF.ip5:^?U02#-gi0o:CQA&1q#$t1]6#K>T$&h[/2';6rS_&2>>#:Pif(/UIq.82e4_5Za*.&QFIb4X<N08;SC#ZHuD#a0)xHv@kM(:Ai8.FctM(r5Ra3E7kR0p8Q`k/.^B73?A&,Tm#nkMP.V'RW=&F&KM>5YPR/8PP&$$4J5>uN/j7P]Y^@%Vo:P<7xBFG,DXO4@&Xb$]k0J%s5>##2?NA`ILZY#1Ht;-A:.6/+l.j0nZbgL-RGgLcMm6#D?O&#Xg(P-R`4?-M]Im-_nV_tYl7p&H.L,d:ht7MT_X/2p0rr-r*<<-[1v<-L+(RAD+iDd1@KNK2Tut7.Sl##=sdo@8IY##)ht6#xugK-_KII-YEo>-=r,A%=1nMj:C:p7s2MB#pkgTnmFM/8wJ*<%85RSY`I<?-xv%$&+39WAen$q7,B*j1(VDp7Qlc/);`6WAv@OPA;XkA#-Xga-Qbe;-?VR<0W/5##,Kfx$=hF.#wOj)#51[`3_,'g2S=oN'UUt9)oQ1:)D=O:I)Tmv$3Y>>#'E3j$?snD_uP_3_h]K'F0776M3]VtKrca2277187)ZCH;3$weM<kEh>F&ds-$-wiL'Ud6#/tqFrY`''#Y)0(%3C#]>`:3:0ljh//0_8X-tQ6ZI?U.R(o%Vu7Y,o_#.frRnun7jT)%_l8k0'7#dtm]%sTI1CQ-.m0jhf88BMU69Hk1u7,GY##4sdo@A$M$#4)kM(Vu>$Mkuls-Zm'b=,$X>-m*cP9N%g3+r%Rq.k3pL_x?J+<0Rq#$wCx6#N'5*Z[`G597U2W%T%T3O#>BA+)$A*`nn5;-Z[L-Q*gg;-[OmA%.YDs@HAf`*rO7491r1^#Njko(JX2r7OKE(=5#P]uJ'vb/<'1K1f'+&#s$SE`dE[Y#YY%ftcGv6#T@;=-SRrt-lTXgLYA'Q(IVa5';+_`$vL^32dL6(#@4Dt*`^FT.hTY6#YKZe%bPYb+`v.=A(uQ>6i4R>6t1?<-v1v<-HrLq7i+h#$wCx6#M2_4&[*r0)(R35/n,gi0sug;-/r(9.Zu:;-;Yti_J3oHHS'j?^t`b*..D(+.#&JfLKGs,#aZ1X%S^7B>cHlA#AE&l-J:Qv)3@6ga$]$##@#sx+%'^A=(O<8%fs'oSVQ`N_'5>>#E_e[-$ZCD360E`#?$=A#s$.@%dGFJ:;XODW$$s`Eid`6Ew7XcM:rRp.ftho.S?#7#A?BO0^k.j0KG10(d?>c*5Uaa*7q>t7`Yx],S_Ia%bU8O*;kSq`/6@K<,5P]u^;'18%Ms(tsc?*Mu:@]4#QQDWQPW]+T(Zt*O.Sq7HcvU7>kr)+''d6#TdnJ&4dL=-UGdw*llN=-Iuem-#*POr_&D9P6hk[(CcruN`H-##Uc68%mb:1.hPHMNq1*Zqd2K;iN(FMcS(WI(mxk0&+O>70YCT/)0@3L#PgwiL1UD^#w#?ruo/K%m:(ivuu6S;m3[9fLs5GPpjx>H.$:;_tvCoDt_P9:#U7XcM=uxG;9-(,)52dRS3><JQvJx5(S%92(15f;)8Rj;-0-=4PRbjG#U35VYFd8<%3_(;t7`:tN/fSZn6,SX-xpf:`l@'RDQVuoJR.^'63-h-q:K298YC18.b%sJj_wuX9v>`1(R5Bb*p4S*EjVGb#VoP&):Tw(k;D-X-oP;dn=SZP)F?QdF8#@]4c_SDW?]Z2LI=)G<bXBj_BIVV$e//lBs04m'&XRT7g;7$%<J^r-.WQdFoJZ[$38(M^-dg8.&l.j0bxc;-3rrgA$M&L('&[6#him6#re[%#dO7q.@^Z6#E>G,$HcbjLAA5f*B3xa*-2Eb*a9_-;TG`p/''d6#vIu;JZ_?1MCX*lCZG:H4?'a6(0tj<-D;v&-*ZjO86dav8E:8RnmVGn8n:(69A^?D*TAm2iVq]l-.t<-v&5C-4vGZs%`7)Q8u__LL'GweMs5Z&mQjXD<`$+<-`*bAEloVcslG2E1O&U'#)H7`$+*V$#(VqN2RS'.r[JET^4Ir9.fG%&4qds;-7M#<-HuhP/R1ND#mGoX%;j(<-Gt^B#Gk%lu]kv[b^.TigI&%Su$MP>u7ItC3$PHS%qx8;-`V9g---fER)lp.CS5=&#Fe14Bf)?v$a'NRo]c#6qJYYr*+O,<QjQUd'KG3Qb96+BdaASQH2pF&#>:e8.JZ[v,:<9a4>o;emf#qdmc,g;-MY5<-/eHI1cxaM()2n6#WpB'#4:.6/lf0-2v;_hLqEtR/vL6.2r?ZajCsk2(<FpkLBtHQ8JH/B-,PXj$BM*P*IK8qfF5cq7^cj5_xBNg*Km(f8B=f,=Sid3-#x*@79hK]$%[u##Wc'udg6)^mfOor%u[e[-pQ^t8xPK[#?iL?#cOC?%X^il8HAj]+EjO1TX64oIR+$,;uI1a4hQwNFQBgx=T;xi_D+H*RsGRh(d]_?0?h1$#1rC$#hnP4O&DT/)2sp(/o$XJ(eLhFRCR,bu/uBK-_5CK-d^&-.<<EYP(x;+rs3iZu&@7?:=QF$Kh>Gs-&`MmLS:,&#Xn?u%VO)##f@[oID-=2_e]C_&?,oD_%<lfcmJ.o-UN06/HH.%#pUgp7<v#r[ten@^r#x((McU<SK;iP->SR2.J<V58R7S>e4C$U(Pr0%$?x###0bZv,ID8>,<5TrQjb&/(o$#''^*p63q2w%+B5cf*o(OW-$JBh5q@?>#g<GJ1O$ZiBvRsP_23Z6#-$#<-(Rg_-k:cW&hY8h,m)g<-1W9H8(=8K'<Fj887J5s.<FLT/[W#7#;(K0%cZos-/;3jL)dY&#aPZ6#OtNu*+%fp7Jp/E+5kFJ(t^;/`Z@wPhY5Z6#4-;x.$Da6#x_;K*^X92BxkR%%4l*O'l-2_+<asa*.Kmn8FqF59*-0N((@0-FB_lj$]9xjk`gpl&UF;m'%NT<-PdM%%Ix9-?%Tl1'gs8%&,M?W-7[tQWG=Vf:_HX5'Ag,:.XF3]-1U*ab$uYl])_jW-&[w22kn#wLGRP&#w<b+.>8o49AAX2_Y1dt7IJD21Gsdo@D<r$#*ht6#jvNM6Be'^,xv:$>kU[1ciY?R)E'wa*0)>11(KCV?09NP],tSP&ls/o%-Tw@(=iJc&]Qi_XwWV8&ar`V%4@4D#%G3]-p$eX-`]/d#7+s@$)ng^#%RYOc[g@&td+v;%t%###=Fq[/ujwu#vXBP84hh8@me-uQ;nvV%?4$w$'h`H_hYc'&i7x[>Se'^#QCu^#-+XJ(s(X+D>S[acNs*1^EbNRNTED9r[^,>>oakgLN>_Dlr;cx=0-?o)1#5$M]g8)8kZ'3_Q4D0_06N^2]]@R&&SMp7hV=AYi2Pp7gK@?94%co7xQp9V-WN9T%''j0^kSb*e^<0UeQta*aMhW-Z]<lX&E.kX5AFlXKIE#P83s+Vn)9^OQK.9%MNCV?/=3?7rkT'+[S6S/33pL_4uUV$J]u58r6c2_N1`K_ie:$^309t-hq`:8dEq#$LSlb#tEQH.=)>2#;5_D4sfu/)C5HY>lJ]4K)UO1<^8Rq&l(b`*l0;]%B5d'&$.W'Se[n<-&TG5&6U%7(9_AH8*1uve<KjuPm6SX-ffbJaFnJO($wFPP'G#&#Q3<d$L$ffL&iJ(8we'B#ka7e*;MMT.PTY6#_7Vo%;aAb*+'5kKMR9/`/BO1:,EvV%(A^,MYt)$#U?6@B8anD_pG$O_qUNX(Rd]'/H/%W]/XuM((?L#$&V5g)n0RQm^D$_#t#fnNk+$jU^ANJC*,].C$SF%Oed/`<8j./Cf>NxOp=YtuC>]1TG.%^M`,>8ndK'H*bo@#j-P($&NZ/B#3?$pSpqJ;6$uYl]vOcv$8mNfLGC?##t'D<%n5>##M+T9r[oYY#MdHl$liC0_^:.HBm'4m'E$RmA_2A%>s)wU7Me'/`u]<B#/`:;$=[Er$Gm=m8&I0.t23DhLSpr-2C6i$#'[b6#XZc6#6d5T%bleJj>v1d2s3iZuxi=t7'OeH+7F6i94)0hLOt6##]bRl%3wh7#k]Q(#51w%4H35g$;(Tvp2#5$MF@&Grncqr$%ckA#NO`iL^cbjL'AVhLUiff$p:?N)3C>=VY?d@(4KQ&=Zt$0#27;X-+vN;1=>HP3#6Z6#6dUt1)ht6#kVH(#[r+@5aSD<@UL>(FtP+Q'c#^%#hA>)4f6030r'c`Q_[FlCC28F%C'OlCuM&f+75&T<[dccA`X@6R.PkAA.EKMuSR`GuI/I0upLJu*mmCT%%-K<_Bl.$Mw3W?6a[OdEUP7@YVVL[c`t^QCL$]tuDpDoRv7YY#D1$##3H*.r7L=2LSxuW*afvi*hU;8/h],3#*x2'MWTa$#tF-<_js1F=@4`D+K?bs-XR/b*2Hba*/Ld<->q%>-YP6X.iCa6#wYIa*#Z]a*-B$L:n:6k(0=jl&d#60`O_NI`mckA#[[4f%EFLs&vaTucmJD'[eg$OMpi[Cj$Gmf15/snNx^VDWoUjfYp9`.IAuun$MP.MFbPU7;P0,S/es0WIq&r+r[MRS#U[-##UH:;$A`D4#sl`1`dqgI;nfMCXmF-uS:&A=FBAu-$Ue1g$i`=u>%/5##^PUV$^6QD-iVvv>&TfR1s8$oC=9Ha3Cm=/(;[u##%7lh2XIZV-*mKZ-(X'B#.)kT#X^n8u'Sqfud-sXcs7Ewt0R3o%$7-cDr+TV-3f#+sk$ie4uFY$+9HBH/[q@p$;1/UFC0IBPQ)+&#8@%%#,^-(bmAi_?s57??RhwA,D0Tj*w$_#>g.G4K&(?qpe83n'bW3[9k(b`*gNvv-Q4qb*p%>W%`tw@#%:]P#T[SWB'@8XY%v7e_JPxQ#+5><Ti3h.EW`SF%^:88@QV@2B<qH1pf(H1p(lGhb9jJlYfX<xDGp&w^BP)'L8hsv^CVDBLEUmY<m@dt76SJ<9gb=):GfMY$gc%6Tm#sx+t<I,;(O<8%t7q3k+EKn8Fradt.mPP&to_K_$,>>#%=SC#A9</Mclx4]%crku,HmV#n7QruoPektP5v$Cuj0B#F8'##I&(RgOG+Z$Wb@RYbM8MBt@ecV$+%v#5FNP&_]$0:K0js%''d6#^@Hd$qbb0jd][`*;L*<-ApA_%-%eX-mr2]-*W,F%O/6nt&_UVQ=*<l$oh]=uj5Msu'gFJ(N7(p%0se+M(BY>>(O<8%D_]6#i]Z6#K/o&%4Hi>%K>YY#&XiX-<Ag*.;7@=dL,vn]6c*nM0#PfG]5Z6#pu)/%0(=r%xakAu.<gQ$Kh2ot[e0-%]$&^aST_r?s7IGV/9PM's<`a*<=En8@%%<]X5Z6#aU$m%Pn6g).X<?#>o7T%u&ic)I]Ep#Z2:R#<-MK$F#oH#W]2StJ[5#,D>7<tr91?%HC$##+O;:Dox8p@KU-%$Hu(PS<qruuBT_c)hqrCa_4T,2tCa6#'^Z6#T`w&$Rg,/(H5c;-Rd,<-xc,<-_e,<-.w(9.d@0`jGMkG<0Y`U2Fl<#-hXl%l.6QV[>fh?BiZc6#v#%Gro5c;-5.MT.QTY6#lWU9MC8xiL(@,gLNJ=jLxqJfLr%LKMB@,gLZ1CkLUikjLMs@j2f2l6#[R@%#^,eh23=S_#G=T&$''l]#]qIw#5Io$$xH:a#qH7g)]BOA#[hi?#H9kX$9bfBR/R8vCYxIZNXm'B#YtX._NPo2vqv[kT?K=BC>M;>#@IlfAt85?%c6Qp7e/<QMY.]S@=0I(uAfZ,D:tCJQ29<C%niZ,D:wCJQ2<<C%7BFR-HCs<RV^$8@PR)Q/<Y]]+Il(qpR_Z##;PG$M^Xie$olec)'<cu>O$:'#Mgpl&sE^]+0$oP'7d,g)?V[A,Oh<Q8g2A%>&H-f;/5p2``Gv6#[4iX46w(hL%#TfLEP-ofbnuM(E[)P(*A0+*8J,W-GQU_&kCI8%uD>pOGM7G#']%O#d#p-$P5=rTnY(&4Fwesiqo[@ub78d&$M=%O+bfk#U<1ANFinc#C6*##'B(;?K*qoehGGJ1Bc%7#hvxjMJ]XjLOu'kL*tDp$ild8.ncqr$?[lA#O36VBa7wb<SPV8&ThYZ%f6;N_FCZY#Ngjl/S&sS/@???Gcks*,jjb,%f)Ps-ULS>8E5?Z$F)M*Msfm##&nEj33'2hLKVDqLD(WpfkG?j0#F/[#$`^F*VF3]-bQf8.X2E.3DW1T%WhHd)6otM(YvLJUZL5,@ZH$.5Itu_aMJVgEb,K9__VD?UDjt^CHBV@8[Fr_aL7dG)&^W+6&dp?Cc5(cuo<`m/0&)GAc#2)BckeQR0LGJHD<jW#9V,<#.Tr,#EG<l$#Oc##=(V$#&Awf*l$=h:kBU/`-G>>#H9ls%lrwZpO4hM<TN$51k]V,)_EL,)Pj@w%W6_X%I?@O;M3FO#(#xh$w[[d#;m'l2$7eF`%/5##Q[AN-Z^AN-(k+K.S-QM'n]k&+vj]E</'hTpB4x*&c4Ms-,/M/+dgoV.d^K#$PDJj%O`nM1i<m>$=+HTm]FF5AcOO`tp.;cGvqJfLu9ji-guj-ZN^_6#q]Z6#x4T;-,=[8`<r`:%LlZ&MqQk,%'sq[GGAkM(='k;QQ*JNQI.U4(L8?Q8-AKYA?0&,;:s,emi26*nnh5em_>LFj]sg-m31Xn&blS#$YXQ5.?@Ei*=b9b*J-*M:if$Z$iK;?$IC@b2G7Bs2[>L#$#6gf1I:OF#I=TDW:gNhPNO($$Wo'##M?NLhWH<j:4(39LKUrsb)r?##2$]5%RM(7#^d0'#gSgr*x7K=.^xK'#b`Ka*2^/w>'.btAl<=$',e^J()rE<(xX%T.AtqFrf]$qRT&d,I#^V,)UIW5&t..x-PJa[;eXcq*/,A?-$&-A%t7$##uCWDW3L/2'h6I$MK@6##wMRMjSqJ<(-&Q*EEU$9K8p9t'K=w;-@1ai-RGAU:36/_%^-O<-EC*Y$5sbL#GpP&#W[,n$c4h'#%:QF:t73j_k.AD*Dsp;-A:..'`?4c*82x0:p)d2_rEaK_*0TZ7Wd6l1)&RZ.(oQX-m?A@:YH^Dtw)*)3+3pt/(EEk8kju8/GZO;H3%Z&+>(PD-v$,l(vTtm/%/5##`H:;$H#o6%_=&5rl/&1CWr>K);6rS_>Kx>-*$oU.G0xr$Ie1p.%5'&+d(<X(2s$@'+Bo(mELk0(3MOV&WP>>#>7;;$,44(&Eoh;-ka'h$kq.[##6%#%j*s_,9<RF43+gm0a&*2goJ*qF?b<DaTTh`*#/E:;CUujO]g4U#s77fI],h6t_a6^HQTx:FeKfeu#?uu#PV'##;2I5D0YOh#bAb/2:G-##`H:;$WZ`w83D&)WW[SDWr)D,#>av%+RwKJq(D,<%[8>VH7'dT&[W,RCp(n6#>AP##=r+@5wR?.2GN7%#([b6#68Ef%xMr>(^#Yb+IZI%#x+OS_(8>>#[l1N(LXBPAxHQ?$KT95&c`TP&1EK/)EliL)V<SC#NdHd)x&lA#rf5x6H)NhL2-;hLw[s`#P4TK2Ub=Y5I:+ipV;R@-o%<%$r`D.qv^po@2lUY%aoV=5Fvf49B`p'$Nn(Gu+-+&#Q3n0#)2U,+kn9F-:TO9[=+Tk$L`r:%Jv+#Q.CA)+6k:226:r$#/ihr$1N7%#g(A;$prL<-`g1x$^;8duA*+XAdu)wATMlT+A4sG;M#tqe9_$C#4ctM(r>Ds%$ZCD3X&^G3-Q$9.c'MuP=7mYul)Pf(_d/)<MbWY>eY9?#5>2YlKXqbi$GfCNoJ6jqsh.fUf0*.$qdLfLSb-##LucR$Y@@8#(_w5`IaxjkGmTMWY'w##2sdo@DkPlL?kl_$ibO9&^Ou)3&[c6#>$%GrMhnfji.[`3DH=VHIUgJ)-R;s%wa)/`%ftA#@:e'&b:SC#tB:a#+87<.]CI8%I(>&+H.`s-riw`*cjRa*wZUT%f`H>#0'6]?x+;0Gw(OW/ip7T$@nwIJ,GW:;4+0b6cd/S1bG$-KXm<j>M^K#$;:K'7'/+w.GL`4$kIkO:-I1I,<q]kC]LkD5Zbg`61aT8'u.PY@;83QV981^HSnv0;w02&5kXu2EJ=8j0aQUV$DaD4#VAO:_u)T/'*?nD_S6Lb=>OF&#nkCs%BD'xl_QHYo@v>H(Sk<X-C31rI@u8K2$X'B#W9Dm$?Bh>$?=&YG.`QJ1m;TM#r7T6$&oi[$KU)%$OJFr$v(+GM47Hg1Y7PV-ag#7#A/5##lk.j0+#eiL:KihL^8Z6#clm5h1&2-2%gHiLD*Fbjiduc*C[upI[<pO9`tk&#$/]6#(P`C)%X'V%r+-f*x?uAO%fCA=SYTw60Q*Q1wo&W3D0jk;4(-`#p??]3hokv6V5V11AJtaGt9Q*='PTCWqxjA#t(MW@-'pl&G47KN*4pfLbd-Q8agLO)'^[`*A07Q8MABK2*YH>#vNxJNZ5UB#aP3`N_JtYu-1JX%;j5>>H.35JPFSDW$7liBw&&##Qh@J1W8Iv5w@IH*UE#7#t/o_mX5Z6#Oo?qRv.gB(0j4sLoxE$%:sx]?V4@1(Bnb_.'[b6#,Y5<-Ug;m$#&JfL0n7Q25Rlf%wFIw#a%NT/1QCD3x1f]4mg+=$X/wA.dR?tTRtno'Cx*+3[Zc=$7I;S$>$-2P>`/x%3iLZ#&ak:KsXgItEQei.VZqr$YdYgJ+?^m*bGFZ-)xG9iu)dk*1UDK-8pX0&v5U6/%'D(vC^]u*dl0N-jFmu-%n9?->`FP8K)=2CPS)Z02=<hu*h5R$&aEA@XY<jLM?dlfw't7PsZ8xPW[L=Q4oh'#$),##aFVo$hwh7#nMVak)E?I47LJw#ou53uH''?]na@QjBbPZuI.B&?[r4JOPuiRB6fia[(cgN(,SGR-iGOD*D_ND*&Zk-OHO(sATnNQL%f+;_7%#IHsD_w9,UO9i3n8F%m1O];Ya#]G'f$C#=/aFr=IODW(($29obi29$qYF>x>lH(+K9<-95WRU.IDs-o=7`,k(TF4Cb=,%$KKw#O;$4:,;V9/D1+^u1]/E#B7ff1RTIi9ogA&S6dn(s@gs?6N$a[k?JO[t$OPO3&5>##Z[.5%<lU7#kYrJ1R2]V$@sV]+d#60`TL-R(]Gv6#GKZQ:$7$c*#.&EE6AGb%YLNP&:8DW-/nH;0JsX?-FfG<-$KL@-DM#<-HAWe/Fgw1,H86,%8sx]?WWK>?RT<j1_vb?T_-X3JLx]*@:6'<-lbQ`%>[tH?IWM$BpgwN1V<SC#^`WI)bIgU@fXbA#9,Vg:22/=%F-l4o<%fj3<aqk=;dOe$lL7oLs)+]Fi)vcAiE'OS3u;(&0D^FiEu@&4Ld=.=9@Z%$[q`RLbu->uBToX@JtkU$%R?XOxctj>X@Rg$#L-=O[jG<-]&q`$'o$##@aAERuPEiKaEDB#>%R:mWXdERl9axFu8g8.Tk.j0lp4<-=GuK.CHCK(TBNp@b/0eX_M^P<CmX8(j#Gk&N;>>#>+b`*74$<?ET$9.t_e8%*bjf1%=jf1g2ZV#:>Hnt$g2otcO)<#J)6PJRhrM01u[d*T9^6#7KY,%(<nD_^GC_&tRgbG?:59:2GvX$M$.L,gc_K_X1iwe9g99(f2j3(FWks-t)ChLqPQ##c>h;-)Br@.ki=c4DVB%$x@3T^YsV7PqG@U/3uFKE4I`Kc@gP>7<kwIJA=tFMUwdU0)egS%HBNt:*#(##ktA-ddG:c`^lF,M(.%O_7F(^#e2-N0G`w&$KZ&v#YDCpLN09ZNfZsMM];d6#GY7Q-g,*U-MsO?-N&lZ-G?lb%KRab%_W95&$%:w>j/btA>7?x%Xe`Y#G3pTV%mA*[O'N^2iXH/=UUMAPC%7MTrlr(ter]K%#:RuMo<N:mGS3wp=-o7R+hhw>Ct79&cppj_TAYCFujk&#q/mi'A`Ms0Jw>b-9dk68<a7xG@`bA#pr],M[cnO(]pBFVB-m/NXkwF%L/5###QUV$Hmgw'OHR5AB)FM_pfHm/<;w&$@HCG)'Rmo$A[HP88oT7D)+bK8#=?v$qdRa*TJip.BZc6#xp0a6V[-lLP0r_,]YVO'opu&>>7-E3uAW4]g&i`*(AW:;oJ*qFhYCiP,$'vY'?+59+@&lE5r9QqZQm]JB1$##_'v=PlGgPSE5+$$PMW]+E'wJWRXH##dcv6#eX6m%pg0LNFS.Q-W]Im-V4F<q%Da6#%M#<-1X4<+$]wH;6,o@@:+,s6?C=8%&KL)+,4&T%-,X#/lg?p-0Sa'oe`OI#C?]X#?3<Q.)enV$lUYZ$$xWa$^4<q-i3bXqd]3wpi$-b:6MgvH#`Q.2q)ChLO8pO9cSk,ObQ-T-#W=g0TZc6#x#%Gr?LAMB6AvV%Lr_Q8gS+6'''d6#)sCeR$1qb*cU/<-SlRQ-d./Q-LlYlQm^$##q*7G;$4@#GnS,/1fE]KN29iHM&jBb*^Ugs-1YajL?sSe*e1Jr7>S9/``I`3=_QH&#jk$T&&YDj9)2T;.1/,q'Y_k[$8>o`*NSRp.'G3]-%=/rKQ=:J#aBf[#U_t7e=mrUEpXK3(jd;`76_GE6F8wo#RSL;ADsJ)Gt0OZuu)GIYn1cmtA_3^[_)B3M=o8>@wbwOCPqGs>eq:u.#l,&HxCZkD)uI5[*20vb905##>;`O%&A@8#l8q'#.O(,25wJM0MBE/28oan/q(no%NU?>#Rh.jLxrA%#([b6#nj=#bE_?X&qYM0E]Gv6#^nv/:Lc7p&TotGMNVf3%giVD3B4Ltq,(;d*sEwT%e6g[Q:A:u'uwjT#RL*CF<p4YU=.NZAt@Mk>'s_+4@ngoLW[-lL&dYs.UbENSk?TDWR?PcnI@l-cj/TJ[:Dr=E44.nL*uXr_dHC3Mea#lLm/5##_G:;$NbD4#Iww%#=W>>,JMLs-x6W9+Od*<-q)_)MK[Z##'Pco.eCa6#wlcm9YQF&#LUr;-.U:ao2;>NFpi<V&:5GB?N5t=$r,]a+a^93__9?KFe]m6#Kqn%#4r+@5oU64gwxQ#6:,hM:5p5Q8Tn@X-[TmuYR'YZ8ClK2tXUuO]ZP3'Hv;M-O[pe`<vVIQ$5@FD>>8YJu/$J.*W3BU;LqR^81G-p%d`*87RMkDEBkHQ0/v_6#kS7Q-(5T;-,Lb,%VY1xP>aV8&0*[9/*'A*`=K$)*[_L-Qjl*)*C2-g)>V=2_l+a-,?&]iL@&]iL.WOjLugAe*TBN(=',VjV#rJfLIJv6#x2XJ-A.g,Mg[8%#l'j;-GSX?/0tqFr$a?iL8;?of_+=bP2P^=@)u`<%2n@X-Z0fX-(='`=L5m29u?5/<M^V22uws88K>UX@i?tZuRcnD$U00^%N`)`I;ZFT9`jB9'wR;p%J4w@?sSV11Ep*A+q%'@tYPG>7XkS>DR_i3`Uxko$e+X#5/(no%xX:'d4vpk&K;Gb*n7N=-BG%Q-K19g/Cj2,)`3PJ(9,tC#h-XJ(nQ.i^TT%YPcm>A4;bZtu8AR)<2M[m0J$#7#Z*G?KE']+mb@:P%V0i9@CF0?-EPOV-KQ/ACS2Ko86[MW%>%?>#e%We$W_tt(#&JfL+MDpLv-%=(-Up,2%W1#$KG>c4+^QW(8lAbL2Gp$55q1'7c`HCu;h?8B#Gia[n&_B#Y2]?MF?WN(j'l/OP#bDQbLxHHlo1T.@kGn$ICDSa8RNl*i<pe*O7(u.$,>>#,64I$LnTDWB*&>GnmCkLP9PDW)Zxu#:n)##mv>h+wU,CCZFEB#/I<ul1J0.r$[?,<vw-#0xraFra$pQW?eai0H7$n`Ik'026Nt2(x?cof-:#cE9TK/)#nP,2Rsdo@hE03(Lme%#([b6#.r7<-W2mnC_&Iu%3O1@(N.=#-n?>#-qVg;-4fF$%%.e;-ioE?%J9:kFGV:kFN:Xt(shuu,G=T;.e9Cv>?*xfl4EOn%[`$#>`LQ9UVq[S'HO^_4V9>=$4.?V#Isp9OIB^<_;#AluXi:]LDmlWhiA+Ui:P`V0/Ak[?=dI>>-P29.lBV.:8UBg1^v&2#KbQc$$Ul##>3GE9r6]9&d#60`6iYY#*so_OKoB#$R-Xs-TlRfL0@s0(_S)mfhHFgL.ecgL0qugL?vRiL$=-c*F6sd;(3_dO6ZY:]nQ0v$6sx]?V)7*.ppZiLv6Z6#(D2n<vP/5Br.42_GEv_$F-11;FxdX/)@7+8utxx$AEjnN?eN+D$Gmf1leif1n$Ro`odhNMK$T:Zf@taDB1Vdu73WDW$e_S7;+F)G'V93WH3Y]F':*/1dIa)#58Fa$8#x%#NxWr$exKkL%,BV-6tH]%%C70u&0c^&[5Z6#46Ko%o8F1&EO,XH;tk&#$/]6#3EQa<SHF&#*#]Y%OD>>#QF_c$X9N^20s*Q'Yhib(;ctM(^j(d2/E,F5u%&-2D8HCIDww`u[H:AOrE9#.f8)K1PK[2;6uIfuD8g4NZmDZoa[oS@f<wu#A(TiBjB=gL8e(HM69Oa*Z64<Qiw@PDq9,s%G,1&&Z/*<.$cYV-_'TQ/q+?lnV(>;-hEKq.cm>A4P=>5`R2$#>x_D<%gL7%#>EMr9;=N:gUkt/2LTRx5hrvU7'5$Z$@xh.'I9f,X*S,<-Y[$i(BY6uoZ`7o@/i0j(CP#V@w6WcsfMHI)3xu=Pp%O/C,tSP&#-@4`TC?##]'Xp.N`w&$(A'cQ(OlcMVOH##TbwU(#L7m%1b/i:bO)##En%v#'h`H_(tM^2X'LRh.qOl=FUb]u&gB>=9JoDte1ZV#=_/A=;n2@$ogL7#:[u7_i,_3_-h&Dnr;IlfaY3U&%(5b@ZEkKl^EVmJil=2_/MDU2PM'.r1YdO(V9(nu*daL#$Kcf$8se@u:6n0#7h5A45^iA+>]ml&a+Ci^::^kLZRrhL#:#gL>]KL;#`V8&fEx8.6sdo@UQf;-=0xKu@ve<&9QrhL.l?_%5Nsd*#bgQ/J3pL_Mw78%ui<Z%-4n,D]<S5'hao8.ol68%>vd0GP@Xt(^IoT%09,/10J###ZdDM2?G-x6kvA8%[YWI);P<j1p:gF4>T8f3?;Rv$xIJT%:SG)4YruY#N%J>8Be4ZAjNULNt1>FhNPqB@:B5Zu6FH9KNNObZrbK7n51ZB?QtMD4R%e7(?9x]6s1u$?%r)QX08=h<O>XJ<mP1f3[FLFuJ:@q8o4vu#.EU/1ZTkl&25V`3]Ra6#>8T<&Tgu89=Nm6#h:r$#_'LS-/D2&.5WajL)1C`$E`=:0F07s08&@D3U6Xc2Q>(<-HPOO%-S;s@+-NpB;SZ>#U3g2D'+<Zuc_;'kuW,t.[aGA4Lw^&H'Z7(#Lp'T.gXH(#1H@A8%o?>#bXX&H.(SX-WfB>0:FqU#oME48?B`>$+G<g1&irl&Bq_l8qwkFr^%(<HVK9/`X-f'&91v9'Npq*#<Io6#/7p*#)s+@5sOEH=9-q&$r]Q<%'S`K_bOYp',9,/1bkui_?n/gsaJZ6#Bdd6#Z$%Gr&_;a*iQLn8xN:/`D'0gs<NZ6#sTY6#GDa6#_V>W-IYfgEcQQFuU$Uu]M+oD0x46@&#$eG0Q2iC=(t$Z$s&0W-^HV>nUi/H#'@Z>FfWF0_%Z^&M1)`3_<:E_&+RF_&+RF_&NfD_&6Z$Ht2pj,#(<M,#JASW&f+SX-vGkp'LSWh+FV+.)mfX+N#M@PJN3%K)GOX=(h,W.Co@LN)'ncb)NwHc*YXNW-LF'#(iI)/Qm&08%NlS@8d^kA#Sf.r%ICLS7qswu#?[R##SU,<-de1p.4dTd+bAGb%7Ek-$Gvk-$WPl-$h+m-$x[m-$27n-$Bhn-$RBo-$cso-$sMp-$-)q-$=Yq-$$Gda5#nOs8B1OU2qxC0_WE]&M0&`3_(rcW-(eka5=Hm6#0ConL0Jm6#r8^kLY2Z6#%F5j*nJ:b*T#_68F>>2CL@Lh,u>qZ-;7L+E(MG&#m_v;-bpiu$Acix=mt@E,HBC*#2f%j0tQj)#2`4<%&KZ4oo%lv.AN$+#@lP<-G5T;-W5T;-h5T;-x5T;-26T;-B6T;-R6T;-c6T;-s6T;--7T;-`kF58eJH/;@-LT&)*gi0s72N994SoUEsJw),9,/1mcv<:Q5q%#onA*#45T;-D5T;-T5T;-e5T;-u5T;-/6T;-?6T;-O6T;-`6T;-p6T;-*7T;-?e1p.)GS^$.UNb%YXr-$b]*QDtFxD=eOmx=T*a58vSk]>1<Nl1v),##Pl.j0o3<)#L#ffL*6c<8X^9K)*)TF4@'b8.>$s8.C2N60DUB(6Fjif<cfHF%BOGS0;<)80Re#%pa$MgN7HaA5q0$I<-R`A5q'_-<'UiH0:=gQ0`Z2SeZR2U%D=Is-]p&P8GxM;TagJ%#q1Ds-2vA&=w6_M:m?hM:o7SI%3imW-ORd9gR.q6(4l&kLu<U02cpA5:wF<?6Giou5]>*O85<$j:(ZSa*H.p,;K'Us7]vlx4$r>/`X1ZHX?OEmLn5GE:I'47oQlF,kxgL$+sWOr7As3Gs5)+f)hIJg19Dml&25V`3YPvOouLRk;KT?/;=;]C-1*)].LDa6#*w](%795(&^jHh;ve^/`jQ@>#SD@'vgtxw#DuG(+j$7q7h^[`,A&ADp3u2pLRgrE@^[4Q#)Q%90)/h*+O3C+0UL,F#=oaY+b5GP2bG+#9'2q*+'<;W/C7$/:=#j<%>l:$#Bi8*#*jRg8,JjV7_nli%LSd'&]hVQ8Rlti_=7ld=DZ's.cid(##sbZ@-^q99x+j2:j@#29Y1fV8kR2]5JjbA#d,Rq/[7Yr/^Nia4Fc>W-0AK?n.w(_*i5g],[OhF*VU3N0UGm.Ub<G##gu=U=?p=p8G)D3i(g`m$G/-K:pSmY?W/3_-b,H3i'/YO%(Okl&6Ynx4eka6#)ARB&?089KV3)+=nj^toNcbjLg@SV8)Ga&5V?t(3$h5x-;@gkL=:mI<RIMB#BVw;%kuH79/K`B#&56H%N*D5&kTYu/[<+'avHW)#]cd_u(X^u$gcYs-WgAL9m1#d3G#Zc%LxI[-K<)QLulm6#CDW)#_r+@5Bpl12ncY6:vk;,<YIp70h),##6l.j0kKY2V$]^w'h4a@-Iv@ULa^)%2i]fb*_q9k9BP:&P(Ks&?5RF)#a$PV6?9=<-Jk)m;12&Z>'=QFWkxVQhX=+)#K(%v7I_b/)s+(@I[=7]k=7`2TMmCfqTcQ.glOxT/bi820WNs[k6+es-N:#&8Id'^>B'N_?vZ>t(BU-58/tt20Ndd6#[$%Gr8t@4T7vcG*DLL[%*rVX-)Tm--#+qD_E8;L;^/SD=v+-<-1BaP4@X@>#fW<;$Xpt(<m3U$.Pj%nLb;0]:>s$q9Qbax-.<,cERWQ?$KG>c4%r.[#,);t7d)*p'aibi2/d1^#jR;J<26w12HF1j(Xo;JUdPD=87^k@Z?XMG<A]6t7Ehq<9IZ^V.%A-E56Yb</:BXQ8Obx4pC,mt7glhkD)`f@+pBi'`?[JMNfGOq4XiP8pnbWx3*9/x?b'h2`A:ddl#Ob8^5:X)^,1fC##`g:#+1EW-V#(@IB^HF#&_%o+G'LJ;UQ^U[@72^QfMd6#Y$%Gr'Cu#@smF59nZ/<-^k/o%7+[R]]b]^HY1S(#g[&*#dcv6#qY5<-u-kx36/EwKdc+'mAWOeDuoV<%jo%&4nGUv-E/q'315C78a86D6mX1s086eH3B`P29*@Q5hD6<gC0PNf2r4Q-7Bv2A-%LaZuF5VQ#DqNn%'Lkl&D-@M9T:a6#R20<&iG?w7>btg$b=pD_1eEn<68l<:<fNKE_+f(#QL[v7Ti+9B,cl.#)EQ70n[GA+9C'q/YW,A#iIxt@(jwOMJ.t3r((0:/sEN`+Q1ep8Sdoh2#,]W8PW_K*+uR(#CI$j8bPo@[Girq%DhF&=Fi^j_gx@D*;bTh(n_iX-Qcrm)ggio4'l?>#Z6<;$]fhxCJbM8.^p.55s1;tl$;F==8K+<%;#^7-ORw<-+?=7%+N,T.$3xH#,X;[2P)U`<0sGT.]dd6#hN-B*P-Fp.HDa6#](O2i%w4w729XM_;/DR3boSM%`KF0_LhnF%=2D_&Xv1R3&q_vRHI9[8oqVB>q*7G;d#60`aEf'&nhw'&fIe'&gS(EY06Z6#/K>a8%rcA#?G_<-+Rmo7bqij)ue[N:F@Jv$'3an'0-eH3TLI=79c/N:#1FW8gSf?97v^>?D:NW8_-oh*-ei)<Zolv.8n2b$HPSh(KO@##*nl+#<Io6#Iguw&Y%BY.o),##[_Z<6uCbV/A]DD3?DXI)(p#398lcA#O<$i1lg;:7jY_VURUqg2B.&n9EB1ppZWaf:C3AH>`[,Q)a>Q8/.LN`<4g)qK;*:*#[tH3851sc<'*l5/JZI%#]O3x@'-OU2)UFk=Y#Ls-CflVBn?;H*;p9D<i'(m8U6dV@nDv@-bU3Men/BnL:8IY8*G5soAC3+($lAA-lQ)#(9h,^-Ur94VG^$moQ[T$>#ZlS/R__].>Da6#b?,4W7cS&$S,m]#I[oYK7&2C05YCf:aRDs@L[s,8^ID^Qd,WfqU;Qm/)MZb+)3dv.PW0>>WYA[J'<d.<N=f4Vv5`j45s?D3x7<A4(fo9/r)fI*(L=1D>IT9&9;4lRIwlqun,#^0DASM`8YP.8C82d*7m&c$Xl=w%]X^+:bo9Zn^I:]Et8qZ-*oprg9s=#-]OhF*Cq.TK>)8`*k>,#-][6c*j;p],D*K%#Sixr0k+'3%C,./(,=RM0=cM'F&-pZ7NN4D<V<VDFi;1h$%F%q'6=+)#%eX/E`BsV7g2$[$j=4>5@M6hM0Bm6#0)2a%,&o'$i5Sp4'u?>#fbPt&Kt0&=U0?v$,EKW-P;+03%V.`,'9+`>?^(b?h&#C5c8lb+K*RH3OhoN'G:-42u):KDd=@<.e.2$#u_^>$0OFt-^EhR@0M?2_>exkTPZnw[_Am6#[15h%w#gWAvD_kL?xxqf(*vX.vZM1)[x5F1;^<;u_:p-$WeFEF>g'B#j`wc9f96Z$7W@t'6m.9GI`a+?c?CVaf-c&1pU`e*2/w,;=Z2*6&64P]iK8b4,5:2#%/5##BV]A$Ls7-#Ii8*#ZZ-586Ln`%Sid'&3+5oJk;&X%W0x+2:DEl_x@2(&s:BA+jKto%GRP8.ndTP&dssF3I3>)4YX]E+)xOV68Q@##,j`a-?DUl)g633&dPYb+wpa#Hdp4%P$'K,3YToT(shBb*h*%01cuv(#<Io6#;.`$#;9XJ-5xls-p8`d*B*ms-vjQiLY,LS%3/w%4gu6c%-O'>.nvokVQSPO)$DnF<V9Hv$tpJB&73Nn431c,<.;^)*`7Sh4BX'h4@_8,)GrkkD_pHT%lpR^8F2Kg392.e2$8t[?#F#m@qRu:6V$<l2bBRkU0PHF+o@$<:*_nK([_ho:<s['Ah,.T%v(0bG@OwY#``2>PEo'71&GvM9:6`*#;F-DEqtbYY'R,)*sG%Pf6'T02gYr-$uufJP^$w##([b6#'oq-$:jm6#.Mc##3r+@5hHFgLC:#gL=^P,2q(no%KoL4&`(EU2V=A&,U=A&,&u2j()s%('$-H#G[.sR8=`%>gvJZo&Ww2gL_id##Msdo@L(^&#LDn9MDXh0,XT;MORem##TKOV.:rC$#Ws,50V_Ds-S*Ig)X*wU74/W78hm.K:=j*^]8&mXl'T>g1Z9EhX3pXAH*sDY@Ejp88L]->@AWKs7V)jwAwGHVu:--4<8Tk9M.&@($HUfxI14'K>PQfxI3:9g>)4n0#mI-DE]9_YYjP'v#lg]f1ft$S8C@ST&c`TP&/avTVx<^*&`HXS%Cgi_X8LT5q*44dt64tmJ%5=2_r.D_&>/)q%NgXb+06m68.==x>JMjp)C)5)%7##^?P1&;%ko_K_*mm2;(OP,M,V`5M?aH##Or+@5p#:hLU/=fMlkm##mlRfLEqugLRk@iLrsdh2FF3]-qZ`C.'M0UuoJC#rq-k;.m)Ori1/9H3;MFeuc_bi$uB%%#6DW)#ra>>,'4[m%^nXLU5VP8/_cq]5W&Gs-fk'hLj7Z6#r8T;i57`T.2Da6#h<Dm$xf=I-bs*I-sZjhh:M*T^Dkw1GAFVZ@*rJfLo9Z6#cVbXZB?$k_OvCG)&xSh(6%VV-wJfp'xeYY,paai07t*W-wDdTqNBeq7xg1^#>Jjf'<l&HF*==PZi:Dc`1H)609.1GDqtbYYskLpK>wdC`3TMg%AOho7/N4m'QEea*rru8.%^Z6#1X832bVm6#FAP##Pr+@5AB+WSP_2#(sY*WSPrb48?ukA#BWw,.PR2K=Y:s(tc%9E/53MY5]71j9YPKP/ghNX8R2088U]`8&sbtLYM_X/2p0rr-+1:NK87=2_nWoh_3U2W%5xe34l(b`*m$bV(0(P4K3QlD4kt0Eui<x$7SOr_,vcQA4(HZi;'5/^7XCm>@<xnY'1'oG;@#j[JgFEO;bMVjFSAQ_$O'=n9PTe$?lplUKe,DB@sJN+6`7x#N_EDp<#h%e@qx8;-J.+n-On1wg.R2GD><+0`MR?>#Rt;;$nM&P.Y,lA#&TjAuGaWJ(Qq^EotnSl:T-Xwp$x78%xUr4JF<r$#`:<uHadTj(<?7p_cMNs./25%P9I@Q0''d6#i#=K&L++=(2.WO^d>42_pJEFl3tU3(/9D398>Gb%]=]6#=Fmx%d^?D*]'wJ2o7.P)HBeq7LMlA#aLZT%Q#L2rQbJVmL)(W-1^(dt_th^+5)bo7,Yn;%R?3L#eb+b&I*8TA@&IW&#GVc`4iQp76#7g`s0w(uw:*<-P4n5/cd0'#?lsL>t=nM1QM#<-e0';%'r8MKiZct7/Yu##Ysdo@opp3(,JOf*nKKQ8rJ_/`Vn?>#`2;</:KBd'4m:?-iQjf'l0_D=D@eC#:GD`3(w(mAnRCi^jeZ(#^h(d*n4)<-pTv1/JTY6#boq-$0jm6#D^98/hr+@5uAH*N?nf^J^Am6#xvo-;'+rIl>-J>-Fs-;9vmcs.''d6#pe<C&p)lT.$/]6#QXQ)+c[(_-N^++j`uB_,l(TF4VhL$%uT%*A#Mq#&G-9.Ew,o89nRO]ug'1A(o_^`Q?Xn/CDS5H't8`W?;w+?9KPwGXm&L-%ND#lL4wu&#hUs)#CNbaCYX?##>e[%#<]uZMlVdJ('&[6#eim6#QQk&#<Ex5'$cIG)>Vti_70mR*L7`E(t+D0_cg]&M1)`3_<W.%Y@F%60''d6#`GCA&39Jb*9tE<-7Rw8`K.$(+-CFr79e_^#KtxU#0UEjMpsZipm#s_ETt2+4`.N%vD9Nd$$bR%#7mjE_8G`3_c&k-$nU&@[%4h`$;L6A%#;`K_5fYY#,'fU.jCa6#Z2(@-W2(@-:fG<-:fG<-A?f>-c2?p/ncqr$B1?>#P*c?-b-J>-b-J>-ED6+Y8#)-2WW95&C[]d;a=;_Z:+,s6?U95&ZwCo'd)QM'#U0*+82e4_K]Ab*9W[6/GH.%#t83jLngdh2nep[%XiaF32n@X-7RJw#i>v<(nl%LX;>L#IZ`ZD[#,US.rH#H)NNs_.sS.?.sl$H5Fe`#5:ABAg5fh2R>UMd#JMWI`BFjC,%X(C>XnawI+$A_>VhWwIR]$##a.N%vP25F%iA%%#:Pj)#<O.f$Z5#++KO6<-k]8HuI>tM,N:Vg*S5`s-n/`)+T<?dMFqDpfk2A,M&ST@%vvV'8$s`,F*f@(#10X[08*'<-t1U7+LF4/2lbYY,(Y@H;A%:HOONWUi2hmc**6is-0v8kLeBm6#2@g?.Wr+@5F%i;-fGZX$#&JfLk]8p_`PDG);$?[R>1=]'eVaO++gx);N^4Auhpad.m:mq7nbP]uBa>T%$o?uu7?0W-@V-F%JGCP2b:q'#Ss-L()2n6#[AP##Dlls-os0hL`ms&Hcwjl02EGJ1S$x+2=oAg%-V_v&+^qv-8.KkLre]qf*$'*+^K%<-o2_u.nCm[P&rnv7XTv*rM`+[%O5>##m:[<$cC5)MtM#&#SRDH_<S`3_g2k-$n-U(4A89v-EY6T.Nsdo@*H=;js=/1(t5UhLwVm6#.Yu##>r+@5pCP:I:YK/)Bnd]%QrMd*p*b`*gMLY'bs4l9uPFQ'''d6#6Kgd+746X&G/>>#0K3?$k#QM'hCIt-s)ChL,34JM]5pfLCrmqpfMm6#?;G##1)F_$/2&T&Ccw8/X4:K#G<9W8Iv1^u39McuLM$j89WG&#sQ4^5wm&KN*#A38[&;Z@JVld$MYm,*nn*)*[NEp7eK;s%Cw%Q_x:/1(<AO1:r_OvI,oAv$0hWq7'w1Z-iRihhnqd)cfE0Pu%c4mubf6(/:'Ori6Eh<.]h85oK+<Q/,9rr-.%no%c=cj%9vu'&/8s9)&6c'&_V(t-#N$iL&r>JCw+?v$SBmA#fbwr7bXbA#T,3;/3%###j4B58FDG&#Rn>H&?.&v-GHn68bIRZ$:^95u1BD_.216ruv#*[tYa.%/39MY5+(&pInLTKa2(:B`-`C+E)g]r036Nd*,v=k9giBj_e(x%+Nc[)G_pHtVWb*68<M1^#m>S_'#,1TKf#q=>8ntGO(%[Y#c+/ip.q,H)ivt(3cea6#^AqrK.OL`$):Nq0];d6#/Tg8%W=i;-v=$Z&9a8e*V'=W?aEi)+q3'&+cXr;-TfG<-O3S>-NgIa*5'bs?*1H,*m<V]%C6o;-H1v<-u)2]$%o?>#L+aC=t;-f;&[P8/Z6[8&p-=m/5`($#:=]6#M.PG-e.PG-TM#<-5l)*%/t;X&'>0N(HmN4Bu,g2BvcMD3aiaF3kDsI3m(OF31)pu@?K0W7QrQY@>E'W7>`)HAC'BL1Twd0X3vbAHQ#(GZu$rtk+#S2jqq`p;rD#p1qw%6<r8TS1IBP+)5b#O<?m9UM?]64Dh]K=S$jIf4NG&D$&A=C0NWG?_6A`3_;k'</VkI;UoSP&#,wI'd*@,gLj@FJMGItj$dWTMF[5Z6##/(-'W,Yb+RNg:@$EEw$DG4;-a^93_Xp=]#YUO2(mN^30RFvr-[(:W-PuHbmYrOO%1VYV-qh8Rh3Tic#8K2A7+HtCj0M=)>Mk/$>6TrWKc+[n:d.tDI^gOEuH-JWA?bYp)epn;7>&l@?LOG7e2Y7N3Zr7BMdar5=H^gcK.;[SBo<5[7a8MY5hE]A=/Jd'&5C]f1Jr`6#:^Z6#(5T;-`U>h%(Lno.*'A*`T*K)+^Dl;-4*#O-SF;=-,kaiedCr2:W4SN2'NB8%<x4R*TloD_'XAk=#'38_SlUU+Xk`Y#:V+'#d#60`dMc'&HGd'&r_YY,@ob>$(83A'GsH>8U_d##VoN/%'kxw#HrnS/M*V@t1G97HTROT/N9GA4.1@lSOcm>-o$H]%*iDM0.su(3(AAdk)TY,20w[58T=.g))7*<-1fn:0ixaM()2n6#9N:(&(Fsr$E#-QUb$*3&?t8>-bD$t$i2*I6'2@q8>aj/2/>GJ17^fJ2-;+?%ZvTY-$I+TqRwke/wl?3ohp]5874r#$Nhd_u,SV]$WE-H<UP6db5.(58*/-k_/.35&j@Sh(.2'&+q3eq$ckN(&*(#]>&F?pg8<.>%8[K=.Y,lA#,rj8/<bWJ(vL]@82<Hd=voc&#<:r$#[glI890_R'3_NP/*'A*`1LJM'nLSh(0gXo$C8oD_3*Mk+bZ`k+j88>,AZ`k+g&#<-(En:&D]:EmZ2Z6#g>^2`=6s3,b^Eia2/G$MLa<J%g)Kt:D:fBJ3u`K_A6_W/-o(9.Q)b`*]pE/27[Z;%m9ND%v8Gp7kjL#$f=/N%Hm]#@jTa%at9<Duq:fw-bg732-81^FQPW]+:e?M9uN'7#c/5##.l.j0GwclLF>+jL4)>$M[%Z&#fr+@5oxK-2q(no%-%lA#htDm.*ht6#ccb0MG)>$M>V?LM'Em6#BMMU2o7'&+venY6?hoY6C<bs-DwclLK-Npf2e/02k-WKtb,e12.;<A4iWA<-X1v<-YAQX$K5>>#TBOwTFAd'&cFw'&?,d'&?Fe;-(o(5%G[aK_GSwDG)UY,Me>W8_q6[R]=gk;16L[g-*CdhIKObYHT/ZZ-vI>a.$g:oIbG$?-(CPh%o8:8%Da$)*KJnIqBpl12s:q-2^(U'#T1@p.rk#O(^Z6R*_Mcs-94pKMhXQ##Iv8kLqAm6#3H=7%c)`FEk9bi_fa8.6Ia7Ik#0gk&gVH+<'*>R*7KV#]lQ]G(358$(Y`:;$rPif(P_%/1sV@p(9[13(*e#q7x=Gb%]=]6#I:2=-JahATm%O$%_SVD3`Rsk-1nV.J'Mk2Cd#:nu40vF/TC[iJAJ4Aus&rZ1#/75&*gu(3hUO+rf(bMCuWZJ;pQ?/;$aE2_Sk;S(h`m6#u<#+#wr+@5Ox;a*LZIg:^<ti_N&1qBBJ>d$b;^'/>u4;6)_PHPjK1hj.nvc*aNrj9$[L.;V7C2:9*Lg:9@'/`6DHpT*m?v.*3,/1rgn/2CHho7nK?/;oQH/;g(k@.WOlJaVf1L*dGH?-$FFO%N&Rl9vAtrR)K@S/a%3`uaT[%%w@Vp.T2gB`:bMLhhG6$$_<wu#1eNP/=T4Q'CVqQ9NDki_OqnF%[6xr$JFW>n]>Z6#kTY6#?wOR/HZc6#]$%GrM+V29*M99T3@8v74QIKWV2EU%(Hrc)8(QM9Y?i.XGkdM9-Mp%u#tc%(q3n0#3<MY5TEaSR>=fr%&B(e+t6339&Y9N(i@MJ(PCr;-=fG<-c_6391=FW%.+35&0:L@.:bM8.0)V59.3#djbHLjRcjl<.WNs[kbgP[-/6YEn](gr6FuAlfAYdT.t/5##es_i'5O@##<k[U.<Io6#(M#<-*Ap)*WC*Nr]d-12m-3)#2Pk$I8M<V96w(Nr6tpL;60Y;7kJHl$OKe$IZFkO'E0/7(7(fZ-&?vX?VrJjiqY4q*X/Z>-#;Ii$YB)mATlSY,^gu@X[+i;-sU'x;3oI(#V;5cEx>u/*/mT8%rJZ[l#gL_&.bkp.U3pL_w#ZKj-mm,aR5:E<1>`D+t$&b%>CaK_7.0m_MJ=jL.t95:f;Gb%Yofh2`7Ol'[-'Z-=/O%I_G^S8vs.]IU#(a<EA3K;A7`T/WhDM0av:]Xje.W-)42h3D%XT3Q*D&R1lF=,*/mL:DO*M*_iM9(1reZ-LWL#BlZCj.WFoD@8=L`$VxQpBHMQ*9L)^G3g%wJ:%?UL3vYwlf1&h;-3.XZ'7GW]45,Ij0q(no%_0@>#&DLS78uI1C5CS#IQ&p*+uLYp7jcEB#S,m]#Q5OcQi.U^/-QB,H(ho>IpkMv#0_:F<m?0;emZ#E<@(cA#/;HW-TjWebJskD<G(Tq'lWMS4l68<-IH[]%Z]xBHIi),/X>Lm8fWlA#Jsfb%Zr;0D&JO]ur'eZ.I^Os-sMP]=6w*2_&Sd;-c8Dx$PsvFF^_bhq3]O,k-&pa1+<GJ1Q6pG;O21Z-@.q+Gv]WGui2hE8+(`#$ksZf:jCfD=lXWp9(c@(#aK;<7,9,/1bph>>c.MS(`I&UdCln,,IY<A-tP#)%it8W.vS'c+QG0u0vr-YiG&728=dnZ$6+`Zuc_*4Qpq268CxV&H@;dd$F7(X/O),##*l.j0-^$u7=?`#$iKJs7<,mAY0AfU#gUb]/dL%[ucLe3Q5g(sB^-*$#WvK'#+&O):N#>p8*>r24bWB@'xT`l8w@V=-);ia%gl%O_v>StJd1m(d[$09,44@>#Y3<;$JFLS7RYju.'UY6#hoq-$eJPd*#Q<l9I8>2C1xhE+qn*?-W<X#/`O?##-k#?$IH2Z>S+-/X9Bm6#v*,W%[jS,X&(G2(:w5T&_K+886[SMN2q*&F]hVmhLN.<Cj8(KEwj5J(g2Uj9x2Hv$#D+=g)O$a'NxiZ--%vR8S4-f;U;#B?>aEMgBZt8(FsY20qbVA=OK;>,@n;?@6bb)#q/+f*o@0t-lTXgLV.Dg*jOcQ/+2j5(%R(pfSg&02WSk&#qpWbHNtk/2p?N)#A=`9+;b*<-NTpp8:oh&5''d6#E)X;&2`>a*9uT=-3VM&.%s9g*A00KCSb_&5abYY,+xd;-FBr%%[bXt(vdut(#&JfL:eC)1XK*W-f_t-9JhFM_ueE?-T>u1)x'^l:SL+dt]4eF<1vfM:d+e<-Vku>/Sr5<GB%L^@pF$##`5MY5IHI29EVAW7TC&7#>q*7/2l.j0*sZiLNotjL]5Z6#Bra9)[5Z6#6b6]%I41N_eH[Y#rMx+;b%$k_tSq%40@Th(<Ono.WGOvK^Am6#:<l*<F%I^5''d6#SB>P&aBSs-ww*sB`SaJ2nPbJ2%V%T.L),##.Qw:M,Ei'#XDW2%t^,UVP0u`@`ddh2`O3W-+i;Zo07s`FZQ1C,b:W`#bN8M3gV3W/3^`,u_j92'uX#cQf($itqArbZgI7w/Dc_lSh,M#.h#5/4N'@t$fduD@<@M-GY7AT&KwwIJ:r)<-625)%.gUA=aG`c)D8HY>kafWfl5KnLX1G$Mf@6##i(MT.=b($#<SWu$>3_3_Bq1F_7:[&M)fG<-?`gJ&HUaK_%6]Y#opIq1UC_kLsjwO()2n6#fl5<-:;cp7&BJd<''d6#ElNC&$^bp7lqbP9.ncP9jr(T.c),##E>M&0Bc/*#ccv6#<4)=-uUCs*$;7<-8*1,(]7&I%1L.*+imd;HUhuMVv1X8=`I)W@P-Ga93tQ>6qX/]-f-?(H1;m9%N1G&8QBS_#?uw=53B)mAI*DP8YAMK5c%Tn$*RGK5>j@iLN.Dg*HNlN01AP##[r+@5Upl7AK_Bj_CU,87-Ogq)MITq)fFpD_lWIhMU.ha>wnG,*t3-mJCHvV%4_vV%H6GD&8D*=(G>wS^&a@(>k7N;7@S@&,ZVA2_`PHS)`kv##Jb'0%Mth0,Ym5w7Tkm##]wox=qY1E4cqMs-Zc26&e;IK1]IR8%^`WI)+2pb4ZvaMaNixCsoM.?.dl/H)Vo:T(:_Pp)]hHp.HUkT/@0o:7$`F/2a1ZOC@7L^uWH2J<32)o2VNeEHE^#@7/)*X8#Tf+413]'5;^#Y$di^@%tx*GM7bZY#KW9:##o;9`g:u`8e,-/(Z;ZlfTsC4BBnC@cw$b)>?`..2b]IG)]Yw5J3T9/`gXN:IFf'^#8*Aa*>K19.m]Z6#D9K,*ZEGpffg4:.t_&UL&B].*),7C#vBo8%N#G:.GLF,Sid.MNa:ba,a,X78KidPdsq-#G%2jbGB+/W$*s#a346w9u)w<N.Aww%#S4$=%VA%%#g4=>`PbZY#jK2?$d-]V$#GKN*nuNn4'T=IDN(.m0FWbs-nm'hLkI):8%E2p/;7:p/Mxk[>@^[A,T_*<-mif3%qU>>,0`p,Mh@jpf--rpf(',=-7n(F*Qubm>qfO]uwYDj(G7.@@x^4Au$p=l(?6MY5c#(pI?4+,)KW'VmNc.32tdN#HKbfS8OPgJ2C,gJ2sLe(&JI&<-WYMxGe^L_&&;$C/:EDh5+Dj^o;F[Y#dnou50lfr6WIQlLAl=$H5+3v6m6x0's(Zb+S[Cu7)xQ>6i4R>6dcWpB<7>s68Y)##nh*<-9eU-)tkuu,uug;-2@@Q/bX35/NO$##rvSs-:MOgLZgdh2(75L8'%_b*##[W-it7o8[Oo/1twC.38,aF3IM4I)<vQS@tY7?.to$H5qJ%?.nJuJ4p./7<Q&Z;%T(lq0MhXU%'cMR82aZPCjH)?7;W*+6>440*AJvf;<;wG1,:Qn:N0Wk11Ov3;mlEBuNCA]I)BU$-#I'l:7bb3:J;*FPl_/$gT@`c3TQ-qtbNEnFN,'p7@1Hv$Thaj0,(gE#.'ai93ejl/k9Um9v%[`3QXjfL*s89AAXBj_WNT`3,_B$pp=dl/a<6X15S;<-A(rITTXZ##Kp<_RMotjL:,UKME3Z6#0XEs-T>B)PFI<mL'I<mLj@`g*jA-q.a3pL_FGP)YgQW2M-nOs8j]HZ$wCx6#B,6<-0F@6/,l.j0.`',+R)ps-iwTHM11T49IErP0WftKM1E3mLBrugL_sdh2Y,lA#cfOY3j$I>k.vN@t5dd85OD-W-0vY5h%2$##mG_m/MMc##37p*#:`cd$4F<;$P'EM9Qb%/1@2_8.@XI%#@3Gs-LXQIMfPP&#9DO2_-,%O_I3M^#.9xr$:?dP9a:VaQ;0%a$.Kcf1nC?r)04Es-:O-h*5,0q.e3pL_P4I#[kj&3MxS:HOc)w1%7##^?2GD<-Z16)%T3PT.*[c6#DM`H%x-46`:]e]'S&;D3x`Q-d**P*I6gc'&0wfp78sr.rwG,<-5#<T58j1W-7sT8gLs)J%[6&<-B0^p,O[dDcZ>m6#cjF9.kkp`j?%KWBTU-dbdMNM%^Px+=bq]G3(+0]-V7*Xpj:Q46p1SR#edu.8qfmJaxrY&#bpB'#mVGC`9l%M1&ToO9NXrt.<?7p_C*@M9lFSh(DN(,2gFYj%?^T[uN#R>69;5&>`V^q)&+qD_]_a3_q[Ge-;6b3&3lZb+lGBX8`>SD=)QSD=G7M@cr4&S8-T9/`[QmRAFhd/;ct:;-dA8gLe>W8_VVpO9?Qw>6%Y&)*d(#j_fawNFD;d'&9^?8&)GL8.Gq[P/:w2h3D9O[@;Q/?&@)jZ8avIv$q_3v'Hj(/8)>upBHUocVwqm;-YY3v%/QnD_bHtW8gMd6#-$%GrYYYi9/n42_3v4%&Iq1w.)3pL_i@LLhq-J_6;4>s6*1ai90+J_63(Z_5hF3]-S&*V/8XY.Cod$VZCEQY.qA=ltW;qr44ROj0N@%%#K*2,#6B78.FY>a*?/L<-+A;=-k+0C'@c?M==0q&$6%f34j?7p_L9`l8C$Uh(CFl+MU8cPVu`5oLg=>5;1]6N:''d6#C.kC&$+X-;N26Z$4+5S&ik^/`8i>>#i=]9MG9AJ:oS(=-:YC)(>%f;7EY4kOOv9D<RA%^,B>749xD2^#a-RQ'd[T2`M`GP(r.'s/^iQ(u3/3H$ZFX,%cAqWfkpu=(&6nD_TW7$nF-jf:7h'hjCBUZHEgL_&XZci-U6NQLj:n%J*$2@(JmMV/_SQV?)oN8@mmNf3:C-DESuRJL)ec`*l)_6#$^Z6#+5T;-mbc$IdPd6#0$%GrX/HlfDvk3+V[;(?$.gfLpoM0(VFsa*`m?q.-3pL_;fbvI)5*+&[Qo;-J)r:<[5Z6#cU3B--998%.YDs@d$ffLSA8L(%Weh2)/RIO+9aP(Z=]:/#F/[#+;ZGE#NY,2HQYARI8;%k;id@?bP:%kZ)-cVH58JE[+Io7;;U@Js]Cg4[+(##NOC=M:<Z/C8'A41/gd7e]l9'#C-4&#dcv6#G#AT@K;_Kc@.)n8u*?v$<OcA#fV-d*hg2p/_fJ2_V(dt7@W/s7QIa>6D#CW.XP?(#(X+?-wqU-'bjGw-p&Dd*cgTp7'k=2_wJ.[BSioD_%2-F%8Rt/8(HC#$Wm#s7,ejV7C3,s7kaHv$TBGh-W2PuuJH:;$6%b1#[9F&#S&VV-FEo;-n/k91teYY,n7qp&82e4_uf]vnXMTU1i.?>#FO;;$&nm/,$[j;-Nr[K+rkbF3]U;8.?8rn/J(E.%>*+ip:%uh)JpQLcAYP.8eVbD+-V&B-IxO'c]/<0,+VD0_@]#3)]j4H;jjx2)]R)v#3/Up7j`4xYU&dGE,rn&Q'M`'#Bw*)*4-XKlb;uT8,M>^ZZ5Z6#rA$V%(.gfLJ@KNK63ip/:-V8_9Z4l9]RHT0L[<d.nWF+EgLu/*c0fS%w(6q7';Un`_L$##7;x-#Z##F%DLs6.A@N,8.Lprg=-q&$D/Sn$$WT29'?ti_NwY&m6Nsd*_Ygp7<^dC=(dk,4*;5)80N5l9or$(#:MFeulgAe$wN7%#Rc1<DF1T;.=<7mJ&Y9N_QeZY#=xED*:Am;-=pZEPa;d6#Nmmj>:$e&%Fqjs-iJ].M6oU1&UP5i&@;45;:Bm4K.U]X%KL?>#T8'&+g-IP/ZdDM24k0J(?nh?%u$Xxb*^(`)P-5b,u-Is**;5X-8DX32ib-##@&j@$=Vd;#x9q?`Sil_d]Gv6#5Lem/]k.j0IT@%#>In6%Mc2(&#Ino.riYa%6n?nA.bf_kctZM3_+#;-.N>,2Pn%v#^Sba*l/Fb*6uv<-$TU@-A1Mp$l@?>#R=u0Pubvu#`k%v#$?=b*Qe$0:WE^;.N#7,&RD4jLMN&;QB?b<-C$Iqn2fIC#lAK=:pM'J)UYHZ$U=24#G/F:/j;TPSa@lr->M`6#.^Z6#,c'3%d5P/:7><I+mCba*]M)<-mt7+%mu)c<NVr>n>[mof*/wiLhRGgLp+2Q9aZ5Q:Kg,^Z`Gv6#&v,-.+20p742O2(pS8gLYAuA@7Yw],BB,d*G/e>--7#9'iNNJ:Pl*H;kDsI3m(OF3nQ/@#/V[HJ]N$.5Y:5#66pb@?cP:%kMR%v,8HSPS8sr.E].Io76Z@`>:Zp88E'X:Q>j`5Xr?H(a%5YY#oLKxOCS>d$e$6YYA`'2:W7X=?PgfBH$'tV$h'9tUbd*b*8h'39WFrHOE4].2g4'&+kxx]?e*F>-6R%6%=c;Y-]6DtSnqTMB$uYl]$j:u-lmNfLZ$7##,->>#cU8=#=XI%#TZ.,).%no%vcg;--]GW-XVu#7F'c<%<M;NrZ2Z6#@>D)+DD(<-A]@Q-rND>&.NAa*Y7/<-.W5PMnhP593j)LD$S:%k:cho0eveB5F>HF%P49etcPAY*ri(Z-]OhF*qf(Z-w2oeM1nrpL9w2,%DeMYMtd9b*XONt-Nr2a*[i:<-w[03BB%42_;tq&OliK<(&Y99@<Hu^]vA(U.(n@X-Hg6Q';27kbB]%7/vS46#+*QtL;*n+%K5>##1.Y3`Zr]E[OS:;$FL'=(pNR1CAQ-uQKD6?$''d6#jb>=&A6o;-'F?X&cw,B#4ixfLa*chuc_;'k#*):M'gd_ue,nA/rDA=#xV8,Nv+3$#;cD>#?SJ&#ICh;%c@iA082e4_B]C0_8'*acF@,gLm9P0.c*ofLTp3mfe6+gLGN8K:XusY-wvG<%a0d6Nc';;u_:p-$>49et'gIq$>o,[KZ^&##8eLW&<2p)8+,dA#ZbG#$-tWL2<PYV-[=tM(QCuU#,Q]tu&M@3'uo[+MiX9<.5FNP&[?vd=(L>gL,T=o$G':am$Lvx%/[9*&h)e-6''_@'Q;]_>8?J'Jd2Lf>*Sbxu3UIZm3Bur6Q8ok]:$T/c2kn`*Y_S#Gcd&K2`h@G;_2Z;%'X,&P-'])NAF$[$56m<L@>nCWM,Ka=sl'v#%4:mXu,qx=3YVs%XS[`*7)Na*9D@Q8_1^j2$LQ(+6&@<-dDi;<Sc-KD$S:%kC2-#-@49etk'uA<ul_>$8v'W-'Gs&$%P%(#wr;gZuaZ5.bnRfLpjUN(I/W1j3)>$M3lv##CU.:.`._'#8>F2_S@PnK@``&J8s+%&hcYb+s=098`/VtK&rJfLSM6##dcv6#+[ru&`X%t-t[=&+`pR50&n@X-BOdCjw<FW/AuW.L$S:%k+7YFr&^@Q1_@rmt.4Puud6YY#.F*jLS#^%#D^Ev%c`4a*tq&68E[N7SmWK/)-T@%GwiTJD&(>v-hL<:.$Jpk]1j?R/&>uu#awA]4GOes-odE[9.h<s%qjA<-S$-H&tQZ5h)2V2:DR8m_`q[$*DA$O9aMtY-l>lN9KNs(t>*wx'$JY2V^_:'%wMq<;`1<i'P1FMhRP:IMIvDPIX9:^#Dm^<U5$qcVgNr;%DEWd4hX?2&HN'O98J;s%'on/:2=:[.OOH##qT0KEnhYV-E'l<U)f^UuT)P<MFe;g(a9Yuui]ub#Hk%3%^jw=PZesM0vk.j0fL6(#-2TkLdJZ6#UZc6#p#%Gr.TL)<?&42_[YgZh<B@4(&tacqFTf7ODIv6#S2)U%J,bbl7xIr%#K4jB9[OZ.%E$YUhS+L)DfY=0#Y$/*OpqO*hnZY#0K&##%(iAF?dv%+#luJW&rJfLpfelfe;F,29#x0:YB]49UFop&*'A*`-0I1,gmPW.+),##;j,T%0/bJ)oUGv$BaO-M$G-^=t)`n/tRM4#4At&%B)MP-hStm+lq?Q%]WP4Tn%nPhK?VhL(aYgLWFv6#uEUr)8itM(++V)+N/N<-;.G?g@,Vl-2vgAZ9T`28Y9@(#=_[[uR>ig$-C%%#6uD9`]d8@uNh5<.<?7p_7sgI;&o2[$5q/20(k`H_0%[&M3;@k_9Q7l+(HB<-7Mh?&7.4Wo-hmc*?Vds-2MNjLf-hb*b*/<-lxvi$EDh<-072X-AbkRSf;/Dtox3e2WCf>81R6l;L_@YQntm?,'o`<f/#67IV$<l2rv?@$h#R_:Z1u`#(_n$#2w;`#cpQ%Odi&)sYOho.fv#7#F/5##>L0E#a9ff$>.P)'0vE2_[(3'o0]7tf40M-M'8Y-;&)':^=_6m8cEvV%Bh)gLgGv6#7&KV-ADJb-D^oO9g.G>%0P>>#<`k[$5/.Q0%kRP/)bVI3'K+P(rb7H+CTexOvp9E*WO%W$%FO[7j-b6h-+mAY&7G>#(R<89W?*T;:PL#v/l8i#@L3jLY,^%#r;'&+*>2T.B*V$#E)>7%>'KK4DK@A%BtK)+g<S/)DDrT'0f^nfX,-b4BVw;%&ddC#2EIhlaN=d;op)vmJo1^O%.Ns`vHW)#+I?C#9g&##0rRSn,-0A=i<4gLbL,d$koC0_qeq>&AoLq7ARL@e0ac,2d>a*7;Sbi_#A,%$F,Rh(j:SC#poXV-^t?X-%-CW-k@%@#s?iG#9Eoluc,<%kPw`;$?UtAuvr$S>L-TSn0@Q-QZYg-Q80t1#6.`$#PhTP&LY(R</qpj_E^Jp&[UwK>_^TP&q>'Q'S2B/fIKr.&vhC%,'#$<-6or&.^:OGM3(xIM%#Pc/N,XJ(b.J]X:W/w$Zgd_urEGXPOJHl$M+hAOCQCG)dIw89FHv6#.K^s$4'ks-p#:hLr1bmfl.eH;$4T;.C6j'+#3_p7+j/A$Sn+ou;%###:MFeu(VQc$uB%%#5rt3+J@di1tCa6#(dd6#5$%Gr'sZiL+;_+E:dT)P;$%B(&UJ<-K0l&[4XPgL*=$##:J>$M-lJ%#xo&K)0@+<8E'NJ:(Dd<-jB+%(h:@X-0mG#[t83U-K_Jn.?.`$#n#`D92w^/143pL_5xUV$v=o6#/S,<-IIB0/A*V$#e>Hs]U0H)4GR6^(X%D?uh_s,8QP]`t<F6_]6%V_]DlU`]B7DnET%78%k,NI&9.tN:l@k2(@;uT8/?_/)4%Vc[P^8K#X?.G[upPV?(r&5A:'LB#KVd;#APZj:h?$Z$f=.K:K)W6Li-dI#(+2o$uT[%#%(q^#9g&##8kH#PhPo;%J5+rT%DXS*Z0ca<53a<%R/9,Ns3iZuKjZwBY$j;-O):@/HO$guM3mTMQ#3$#>g%s<8BgeZZ'A;$ZxOv$a8m[$N,q%=a'$Z$KdEgLg^D;$20#t-1cf-@qx0'#7;+eup/&vLuX&%#C-pUB,)#t7,GY##;sdo@jhYa=(pC#$$rfFE<Yvr[5%Mb8CV/=%>T[%#tLMkuevNA%s-^9Vn@9MB.YI)+djsgjtC&L('&[6#f]Z6#8oq-$r-#ccl%4a*VF+<-rL6m%+JR`HV]K`((q-B#/qbVRBGClo$uYl]Jmjv$R<_Y#qLoaOk%RSn-l68%/[Vd4tqg`$u6`a*1lIb*l..X-7#+UM&2tM(x5CPM2:K@#xLTqui@D5f8+ZY#<bs1'<Kf58I(1^#sB%j)=bj=-;YO$/VA0##'/D[BZsLV?Xev`j,VHs-gSMfLeh@Q-XM3K8kbxQE_*TkratFR-&c#WKgi3v%MDf#$T#FjLxQ?##>=Ql8C7_Z$feC?#j@_0GRoQS%>g2&+CU;T&:YG$MY*^fLG5pfLUO;e3=FCS'5sx]?%2g;%,/*ZUG-P`#M2>%keEXS.li-;:67mrQUq0`#X;%0:e?m'#2#S-#8HUN$ZB6C#Tc^c$u_d;-R=0(%(<nD_4[hu9S;qcj1Eou,G@?>#+T,<-EY,<-jFtJ-L*Y/%UQ*.-W^<.-6Gti_.d=_/6vRh(-#FD*(k`H_]$c9@_vcG*2`Bs&MSN$>$Br[GkFANi2^$Y+e>MJ(^)=((@l-N(^W=wT06.(&2[NP/i4=1)vr5x6L]B.*<`Ps-^+tt?w5EZo?N5rBV8Dg(L`.h4^<vu$>*viE@AO_A<PRLAxlP030I9/Bu%vK3vwlR$g,se<[j/2FZHGA-@m$l=014DWAWf`4YCQ+D<(J8CNO?426g&##Ptnf$%kt&#YYZC#;s?D361:M(T^lS/>-f;-GeDB%45=2_/Xpq)Qe,r)8S0j_J.HP/P2/^#'(Ow9gZc6#Zo.oSabBj_.]:;$$dF-vV,>(/],^'/D*f;-KY5<-sD:@-hrh0'i%Z0C`=gau@f7.2cfec)7+da*S=Wj9jOP8/dKQ8/BS;<-[g1a6WdU=%icec)MPG-Md`8%#XNSvM-:H4%&-lA#G:]H/@uV'k.vN@t4SoJaa>kW#qJ>>W:Jds71m7e*#]'58:Eu6#)h2&+igr<-MEP_&OQf;-Y:il%m%FD*6ekV7%v%?-nL#29@(4m'u@m)471w%42NI^$^=E_&^=E_&#T6]o12.J(XgAb*v<Iq@pK^5U_,e12.;<A4+Y?<-n1v<-ND,o$'w,K1g?'3(cF-(#^Rx&$bDPb%1vBw^EE>G2Em.(&9fou5fJ_q7I?HDOEn&X-$+f;]g++#(se4603SSiBjRC2^@P(@#t;w=-LmR[/Gv371_Vpe_=++3:^THv$x:C'/_PSiB?k2&FGk^`*_GPO3Y`XO%aUnM9bW$-bw6$c*:;DdDAMXWS28b`1HZ1P9_btA#/q+tArc'nBuGuG2DK>&RE5;%k2S-`>_M:%kNgPxDw`-=TmSAa#^/6a.IqTCu25n0#fiEwpvjt&#Bww%#M$oi$Alm0DHWT.XdYd6#4$%Gr4+,##qjmIMR4s0(r/hHM1.gfL@9iHM0lo1(^MvlfMBE/2c@ucMT'2hLg8s.&7TJb*GkP'=$gB=Sw/^4&xM8oA:M41q%,[-HeT_c)4skK2*pXV-rb5g)F[Sd+U]oCs.bXJ(q;%(8G<XdXQAxg)KGV2:O5:K*4%co7q3bi_7P$N(51/Z$m7rk^H$CW/(R#p%BY6hGW696C*S,<-I7_T&)du2rOvrj(p7#V#+HAXuP$''5tG8>,4%Q(j)']IEK5D)+:w;K&BTU`3e$9['R.SIO_Dm6#>_).--0gi0x<c@RWKU02]xK'#([b6#u4Y0&6fT4(bJYb+I4h2:])iP0V<iP0%W%6JuUIl'd[?W.rP(,2+I6gL,V`5MXel&#Z3>k-v/=VTb6u5*=OSt>_+5Auw`DR)mQF=-f/Zq*58/A$Gbr,#c,_'#h+KM0*X/=-N@;=-'uP2tnbI3:^5iP0^aD2_^47C@GbB1(K3[B(jD=#&i4V/:4x3VL]5Z6#*r*-?a-n##Qsdo@JZI%#`=+E=:*cA#`mkX-<aoN).ML@kOpBO9]=-E5X>4O%);Ld4ql$R*T'[t&/Vh[khgWkBdv0H4Hg&c$oLQ(%MMc##e?R8>+d5g)wXWY$3NnD_j5$O_2L?M97ZMW%e1Sh(=Cxf$D(0:)cH_c)$(0:)-bQ7Am@L@0D.Tq)D(Od;1uYCF9Ps0=Lq.Jlu*R*(dTjbsa%Cj_<nJM'T14sq$ba0*L&jhBPH4AuJ,IN)MLoN*a:(2)XSSiB;0E/:uwj>-1fq72VQiZ/t@BA+<bjl&4RHj_B+$##5JDi4+3ZG6o;0AF:)aKE-Yb?%0x`X-E1?c>xRkW)j%/01k95J$Gbr,#Bww%#/Kv6+kG'(+rdt/:uuw_F_qcNDd0H)4m7r>*cT:Ru#PS5ucD[3)bxP.Q6TGW8Rn$q7;GnW]Sn;J:a.(^#)RI::P'D#$opgR/mq:K#*Qq+)lZ97/39McuSa[v7=Sn(#`5MY58HgSIEF+,)%e_%O/Rj/2vGqhL-6Nd*xB;T@J&LN_4cYY#+*]V$6G0fM7E4m'rs6s.)cIg:H4n)G7x+s6b9Z,,Ubd##:N27otSI1C$iaJ2mZqG&,Hrc)oeZP/.5?f*9aOT%:XA;KjRak;t'm#KjLEO;m:FHHdG)Z@2;/^7*9u*<@vKUM)4^L<@&q6NfV.FlP:lRL3HF[?OY&(^'G:;$nL5Z$dU?e102<)#@F-@`og[Y#K36`4?jYQs7co6*a?7p_p-1O+Jq9[>wn8E#>3ou-sQ-iLiCm6#_bRm%7R.LMqB3mLqMd6#Q$%GrkAtw7=4p,3''d6#v(rA&TC+=(Yes3rlfw%+cuf<-U_bHtU_d##^ND&.;@gkL8^QQ:(=Gb%JKfn(^^.'(2/?q7KqkA#<d@3-9kGdFgNiq-.s&p7[T7(#a.N%v_)*H$fNc##d8q'#?W5[$v$*N&?jt2(&X1pf.V-W-oI4f,0)>$M1#m59J>pV.@0v_FZHbi_>0B1,r3c056_POiM%1kLGmZ<If9X=?[1,oJf-6r@8)d7C[]'h&_Ec?KrJIvRP[d##+G)s@/1ta+pRSh(>n/20#IS,(8l21,)+'u.*)TF4h:AC#432T%'a^F*XAic)k@C8.DlE<%[=8C#xH:a#ae_F*VuMul;<mrLpMDl:qA`#.0?LD3_[,FP-R(tJ>.p'7iq5FP5?*RLIpq<pmwTFJ2<302=LCu8]DWfUnga8NGEA.+@G-TBu,XWMKgF+,L?xf*s:8K1Vs($#rJ6(#34h?`QoH3b%PE(=QgJs7Y4+gL2xSfL('3$#Z;D(=)Uti_)86OMow%V82Lu)4;6rS_NN2]5>lO1:<`MnUZ)s_./i`K_MZo8B*S,<-&HFm$kBut(fsv%+2NVj0s:Rv$kL?x6SOr_,656Q8fS1^#B2IN+?-hDuvs1U)0,K58V]C#$o@[20QXvu#btHP/se]Ee.^Z6#95T;-Bs'9pA<q&$G2W]+:jlan2erjt_oYY#(X)##RWTs-ct[fL3MJL('&[6#A'A>--OtY$q.ho.axL/)?7b&'L,Bb*)*I=-g$kB-%At_$epv%+L&_a*8O/q.Cj2,))hLj;KF3Ylh3iZu[GOd4UAkW#tgCVt[-=9/pw78%=n2n02)`6#7^Z6#Ct;b$%,NBoH,d5/3%###r1,c*uvE0C$`]s7,GY##sD$X.8CP##a9F,%4sgFEZu^j(''d6#wPmE&O&#%&,nj'+B#.t-tdHiL[BZ6#TZc6#ssh]$,EPb%?8r*Fs<UQVUUE?'%5IdBu*2)F)T$8/04SR#h#D/8:?G&#AQk<-tOB5)@R-58<kBj_-xmo%nH,uBA(EV(8w@$&*&QZe.pC+,[<&68ocWs%EN*78KJBsn.bXJ(/73B-Jl8x.E4Fg1Wt+,)nsx+2=@Q(jl`_J<PK9/`/]d'&;O6b'3q9D3*oZCFmZtY-Ixbi_/;=(&d:WU25O@##'L;&IG,0Z-lKQLqPI/s7vUPa*E1KS/'),##dk.j03/5a*?lV<-ekSr%'@=G2SoxZ%>6o5L*S,<-jZE.&Y+eUR<WMCX4[?dF397Pf>4md*,fd2M4MAi+4G_wk$Bpr7P*UnB5FNP&r)#,2R4a6#T?X9+RRX<-1ts7%1,X]+WIQlL0rD0_2+[&Mgn@R9J_]s7,GY##*5C5%.CAJ1e9U;.?3AEN[UQc*[wP<-]2Q7CwOta*KKTT..),##I^5=plX=9@9?Z;%WjbA&1$'NMNCUm87[:a4=3:RJ?<.w%>];w*QNT<-;MOL+;RiL&,o2,8oa('#a8MY52>F'mx.2'#WHY;`@NL7J@YT;.YN.m0>98'+tpVa*/Ges-n/`)+2).$>Cb,rB^x'h&$J`K_*G2u$+BPb%]=]6#04*+(H>G.D=f*j1Ptv,'jwrW-`$2(m]5's7RG(xndYKi^Ns088CqMw$[@%%#nd0'#e(Fd9/vlG*):Ad;Q>ij_MkVV$h:Sh(9YQt:Yefi'OtL50t)p;-2P)E-#O+C&NOOd;gF6%/rll&#aPZ6#@qJP&Q2Hu--A<jLJ2Wpf/MNjL6T&e*5#sd;GDaRSQn_kDF^.+oJp-d;,hh>$=HE5EQ1DE%k8S-#G?O&#HoA*#WdHP8L4HP/XhN%/i`m6#@ww%#Gr+@5H9i.N[2Z6#pk,<&4d_c2*'A*`4#+T/T<LQ_&@,gLB5fo@pm'hLT[WmLjAZ6#qcd6#Qptv-&/4++dT#wG('Mph_Dv6#vna&FAi+2_NXm_(.3,/1+.lr6E>=gL4$8Q26vD%$,+ON*0[bV.n:$Ig2(BQ4]2SduhX$5F0ZS`t1+uX,TL268cPR]c65[;8DL*dt]5Z6#Z_3$'GDQSLk$*&&IUSV.H),##Y?oh0/R.9KB(o(-&eiOB?V5mq4'kt*N'x58a=nv$U.&tuFXeB7.p'E%HNc##,&*)#f1;D`g5R%58)tY-DxW>-X&+k_+R6;-h:Sh(RxOV6v8(Q/jsdo@heZ(#4TKs--d_:8x((m9v)Ts-nh%nLiDm6#nA((&f>MJ('spc$7/w%47Kx+;T,_p.W3pL_&BD-k`Epr%qu*)*1F/2'/8$N9#TY[l:GB?-1R35/:aXc;p6Z;%/YDs@94TkL/h+<8W>Gb%/*sa*jnE78`YC#$@NNa*B:+>-,F8[+Fo*#+8o*Y-Q?PE#j6>W%r=V$#YKb&#@2<)#K/VV-*VUV$d#60`7ud'&HiZCFmxcG*rkDs-R6@1Cr)?v$J3;B#pO@##JskZ-^3wSp.8xc=<?(/`15xA#9dLe?6R>x>urg)l1BiR-%D`9.FF3]-Nm5>-pHin#7cFX,w7#c*i;J7/O6]T$Mg4t9`KIK<XFiq'jNcA-t8':1Abdl8q/cIDbIIK<1iBb*k`Pp7jp-Z$eL%FQK1$##Vx.E<&kk2_n3E0_.uZ&M0p>,%AvB<-t)X7%-7jX'c%ZY#.9xr$$8Pa*HT;hCXsL4)ib-2&NraD<7P$cE?jtgjL0(Poj2)E<I`W;9Me@o%3eUj1a;a)%K5>##DR@%#rUh,DNMDs%%l)K:6a1p/c]_5/5sdo@EkSmACrgj_L:dl/a%Sh(*'e-61d1(&=oA:)&ejl/3p2#(4drBA`_G2_C_[&M*mVE-vocSL[5Z6#GQt/'kfYb+OOh69FUWY/>rW+&J1?a*a/up7Ho<#-S_Cv$gJ,W-`&Gb%47@$MCOnf;(8eM1W-$m'B431,V:SC#&-lA#LdvT/v[5>k1>^XuLKqs.N9GA4u,?cPq:iE%rjt&#tj*7%RdlkrXgt%=[Zbi_eu,6'^rRh(NC7q$a*Xx%W>qA=ppOe+Y2Z6#j_d&+j-u;-EJ_4&p6';.*q^#$SCR@%t%b,u:iHpt]`tl/1J%;.n^P7ew+Rp8V5mw-b**20I%2PSE,2226x8kL1O8oq&KA8s'vu&#([b6#b(xQ-cnQA%0(@>#_Ino.'fou5bZbp.G3pL_Ck>j`R+RP&RE4l93,o[YEM=2_fe.]eVem##JO=j*O2?O92&?+#Mbb%X24bX-UZ7K3JWJoUp<>RehqT`=ps:T/YC18.t-3<-h,7#%cNRK&K^(kbkuED*aa`8@.`d&6x`;;,P[4uHg%t)u]V32Kni[gs&ThKK1P23V'peD*xi_q7I2MDFqqm;-dBKW&FD(fD%04m'9DOw7kAm6#wq]v$=O@##`VH(#<Io6#.IQ)'R:SW.K),##VQ6r/S#ooJV,Fd=UjDpJgQ.K<AXucM9?1=-d8)]$iu($#^d0'#8Ja)#gicC`ss[Y#kljS_MW6+#aOIs-S4R[@f-`[erkH#:a5Z/(D=gK%C_HP8sXq&+'thT.U$%GrF&-*TghB9r9>V'#&jAKMSH#0&9Z1U.oZc6#di8K%.YDs@?X5lL#?,kM`em##%F7'RX,Em$(ZVO'm?3+(ZXG)4L2iF,AXho*V*IZ-R9ja5M9(5or$$&(<41B#w^q9mtkAJ;Zgi8&;am'vnP&w<h?D)+^)Us-cUN`<$`rS&u>?N0mcd6#$$%Gre'&3KOFti_1;>#JU^?2(+mVb&UbOS/E),##qk.j0$Z*p-3u`K_:B[2V(OP,MN3Ij<>:?ERFj^i-FUOV.q3=e#p(oO,k;LRqE8:PScp0p8g;Dd*6^,>>3aR>?2bf<-*'Qu+m7;9(Z-T>-/bq`$bG$N:Ehu=7O4&7#N/5##`k.j067>##-f%j0#HqhLn_NG<8$X#-29tA@xxM;ThAm6#_Iau.82e4_glSRf[642_gr[u%iN9>-A-q9VR;dF/_#9m%F7Vc*pwY9@OpF>H^he<-(//O.nmlk*GN2[>7iMGWk`@u%:KkM3GHm6#CY3X?bZsY/Z-.L,6X,r)7^QN1b#P1:=54-tQefr%R*=tlMIDpgV_l.^X(_B#Z/2o?`eV?@XJR+#^d0'#m<M,#QHL,`7m]Y#g>X?@hI#.#B3Fs-siXt9qnti_fjGk4xCdH3>m$)3*'A*`WN@'?dH<mLra&NM<.=jNWwh2<#>)s@29[M_m1k0,jm3DELhQa*iIHb*=Ooj9lXK/`]*@>#*b$j(.Y.W-7Pf#gXnHlLaEjw&OrT6('`V;9.>Gb%]=]6#(;2=-?Vit-*J+t9WM4uHw[sblLs=SRikY[%Z-i/)3V7C#;6db%TG)$[G'3c>7'1x$4jnM1P]Zw-ClwM1OV?[-LX2X-q&vW/r7q=-oGGW-8ves^Q*7cAYt`s^]S:..J6j6(xo?Y-U#M4B?Z%9C^tDJ:7gL#$<T9E-CWOwP@ffaltnZY#?uw=5Y`*mA<Lco7ReNZA_Ka$#dcv6#;JOZ%&fXmD^kQ##<Io6#0AP##3f(p$1^>T.+WH(#4(:RAXLF%7ePi`-iQ#0(^&O%,&AI+<l$AT&qGcf1qmj;-:4#HM$#3$#JwSb%UN,U.UD.&4J&n4*+:6(+S'lW-s>'fD&/p>G+Sp=@`a^&&SGn)e*#,FP]VLddG`P+3*_CP:*^X,45F-C+I0XY@:9b;7Ni6>@<<b;7-KV]-[+>=I)VED<>dt9M*7^L<[lEU;ZA7R2hO?,4U':A$.Hum&Cv.@?s2M7L4HF[?s8V7LUY$##8c0WJEUocV];gg2I3Jxk;MZ)GYi1p/XrRW%B5d'&;I'`=qhBj_8Cno%L8d/EY'w##dsdo@9(BkL+sx8seNEmLf5Z6#FUQt&MBTq.@3pL_F.?r'1hu,M&#QZGd54m';H4m'QHk;-)]>CHDge/&GlLEmr(6-.<>gkLB7Z6#fO3q%4Z.;6*JHs-4G6p8n>^5Uv$XOu]r)nO](oX.n&Aos.mC45;6MY5dt2d;mh/,)OCi1Tb::wG`_gJ)9I2q'3p=r7:(?K)o;GJ1WB0k$#J`K_='J,M0In.44k%36a-=,%?sx]?_xK'#YcZ(#0ZUp9a][`*pwOb*$kxa*)H$:.Hq.[#wNB7&['D.3Of;i:w.D9/@@i8.HWUV?G&.U%C>F5;#FM?Kf7w3;.Fa&8_q]a5vkkn0`IOD>j:IW$=?LG)g(U&dr4rx=Z'Q8<Zfi&Mdar5=MG_Z-K74BQ(NU<9PY_V$K:d>nlkMu7jD%U/+1)M^WMb&#p)xe*x#h<-DCV5%tD#EEa`eLCV4=2_``NCXLArp/1edl8JGI'NHPNr9]cLa4''d6#*^9L&#SLh&muLT.c),##?Ln*.wcIe*-01<-.bM5%MAgLC.+c5rJ(9w8_2]`.C<b<-8hk63,l@X-?fNvRd@C58/c;w$OA%%#_nl+#kn^h&?_[Y#u/=;$LX-58m+Dj_6hUY,2kCTTWSSn$/?)u(kYIG)Z1'&+,CBQ8OGTs7uNN`<#JD<&v&`oI#.<+N&O&'-jh;f:[E+R8TAM#$#ExR(J^h,2J'+&#ZH`,#KGGJ1bG.;6dJHX-_d2Os2`KA?QE6.O]Am6#rOra%ZjXx&)xZY#rMx+;D7T;-wnFj$'qPX(BFE0_nsv)>PG,7%+3BQ8^7]='qSv6#m),##d;Hh-RZ>r@CBp&?V_d##;7&/.,6j5CqHvV%ujo;-@X:H-N<tf-Z:<#Th6>eYmxXE.'*CS8YK`>$kaK=-`PLV2Ejg8.K)Kp.BPMH*r_Ci^a$#(+w4N<-%0bV$7co6*d?7p_FYkr-9t(`$*V`K_f?UiBw3Kv-kN)<JMI3Y$?&+udeiL_&'Pip.N3pL__)mZ./tDD+VRJmJNS9/`=uBqD$0hBJqU>>,+bp*&V]:;$:-V8_N[NGYa*#j$PAV@-t(Nx$A;W:/Iid_uaTX18rp62_#'/$&0pao7sqBj_.%no%Ue=x>(]v920a_c2D7T;-$Dup75#fc?fXro2_*Z<)XGD)F-)W&Hr%7##02+M$%PV,#h,_'#(>GJ1)`YY,CHY20Jsdo@7CP##^1x6*fTY6#4oq-$e?SIinC4m',t?i%+Fl+M)8_Tp[NuS&Nc5$&WoCb*#fCb*^Uns-?PtL:;[#p2KxHc]bem##@4ji-MuE=ZWfkA#[#vg$f]d8/Jt@X-H(OF3Z__Z%^j0^#4v1iHh)IMX7R;^1[[pU#Nw%o8FPCB5_]@W.27w(5+dYs-J(9j*Y$Ts6+BWLpf*h$2gQB%uQRfxI24'K>QTfxI2=Bg>@,'p7Ma;w$S_R%#:Pj)#^mGl$SIi;-h<s^%D2@w[H*P[$9mnD_=lg0MfAa$#(o8k$hAbXZ9d/s778s=%X']V$2)Jq&U_b9/lqm(#jaIe*7Rp<-0Q^+%[6Ne=g2,NDHj[C>^j4ZI)0Q/(2L%r'f?9dO#&v&#h,_'#-bHj8Do7jitU;:8k:)j_<Lco7iJ0j_qkTY,MA?P&BQnRAR_X8pGN&c$WKW/WkKD,)sPe;S9FP,k.vN@tDA&n0$<Q7e`5MY5F%*pI:qn;-N-q`$8-_3_$VZ&M9WCa3JZc6#w#%Gr7=G##C<1K('&[6#fTKV%3bV8&PmW8&tSfM1CIs;-FBDc=EYw],:ggJ)1p3p/h#q5/Tsdo@P(Ea*b,^Q8&aQZ$''d6#4ax?&D'OW-PL#r[qYeg<RRH##vJjJM]mT'+8K1U.=b($#3rB3%@q@.*o'4]-)rKb*TGca*_'/X6OAJ&]uY=;-oB,H)f'UF6:iYD7GugOctY7?.s/.oJp+pA$Y=iP`7@=,)?@jC,Zfi&MWwP8<*-D_>UbNwIs.%r[pR@$TfPSiBVA'Dj>+ff(n8$7#5/5##U:Ll%w+9W&hlD(==,pO9=/js%''d6#Ekt8&<(r;-7Xw#okY/6cfMm6#,GY##:MO?/=b($#h4+gLq'<'6uTM-*%v6C#.m@d)e:pH#=WAcN-Vh3(RqW%G)#mR$_W3OE+vfXu,lmHH]%A*eoqn%#6Iws$MMc##D/`<`T[x[>&,)d*MD2t-#?SCOSDck-7OtE<PNcHP%]0b*sSCU.<xL$#pQdl.Ne[%#7_[])gfsA#9_Sb%wH@SsM<p>PIRZY#K<MxO]BSs-$ld+80WO'#$/]6#:3pL_`2+iCsp#alsQ&%#-AW+MmRov$2D)u-ghDu7KA:B#_Tlb#t4ch'axP.Q#lhl/khAauCU`o$Flab.tvK'#H6WRqtAm6#s%P,'A]:a*VtHa*%1K/;h7x$7KA%#mx7L,fJd7iLM.M2:9I2W%K)9o8,XgZ-:DEl_gwho.7#m;-k^=?-akdd*d^pq.U<uD#M5FQ1R3H)4kj#iNHpKd81BU^#[3=e#86nU(OtiR8XY/]$sC$v#^+(##,,Pp.Kv$)*OluF`C2Q>-Srtv-c-hHMvoS%#=fPm:mh16(CCY31IN7%#7@%%#aPZ6#R))nunI12)oP.,)XuED*meec):))d*+@RQ%pEoT.*bM1)urbP8m(-g)0Ca58h$+iCq_$(#Q,_'#&DU7%]:r$#%Zt)8L6Q^$PwS%#3BJs7<o=H=2^6x'_)(a4X]qq7bNM4BV.R_#1N&##[_Hp.<H$)*(8%SC$4pfLaXm6#';G##>r+@5hD4a*Sdw,McSZ;BOI#@(E?_=(;Lf%*0JnXH2r)<%>0GJ(^xFj_Fa_c)dMc'&U>5a*Ee.Q8d-+',h3iZukr`Z8Z4'*#._[b8`bD6jaJ8MB6=)Dj?4+,)L^2VZ7)Tx8L0'E+oner84gFH=I2@C-F####+*3b$iqR%#[^''#b#s$-Chdl8HIb2_$g$O_s/LFagpPQ:8Ego8vHPW8@^g,(0$9X-xiTnL,P]C'Sga_(J####,MlYu6=,h%J'1?.js849bE8K):B$)*&BV#.F:(p7kdm;@>$%GV03>q.3vLV?i-wKGq&iLp7M&mA>MPoRG*+W-[V-F%1RST%iQ3v&`^TP&QXjfLxv,/(92b-;d?kM(oBa`%FxWt(J^Xc;S?9eXPF4/2lbYY,Y/c;-qdA,(r_YY,0])c(G1*lCWwlG*k:De$%$YA#c]<VnVU_J#I5^+4Xf@C#:_T=8l:hqC20ba#*]kJCg20BR]3H8;kK[^]*NTDK:BA>,NUiD?2)e?ekf8p%&&;m2,_oQ<(u)H4,Fn0)<cWa62Y7N3/q=n<*lvG4lrVh1;Y(##Z^p%4lik>#Sw78%mhZ+`D&)22eSr-$J[E0_)fZ&M9,#++t-`6/4+,##?82c<-iA,3:lSg%+'bxF9dA,3P$t;-=qX@T[5Z6#?sna*7F(39l?3D[v&Pd(#5`K_:o>>#4?hfLFT,<-G,sh$7VG=Z-7Q%JTq;?#W@sZ-#g`b#ekN=c[o1e*dv?W-Djg2D0+.##9&j@$3s7-#KQjA`jW[Y#Z6<;$n,QM'j46+W+JFF+<?7p_j==A+TVRh(A3,/1*kj;-9oql%adTP&Wd%Z$I.ui_u=D(&HS2(&[]P2(?aL;%5O@##6YF_.:=]6#,Skb*A6^a*<&d'+?1iW-O;q=-2TMd*5kFJ(Ju=bIn@vu#?Jsx4.Iho7Y)g;-.ics-Pj5++Jla88L9>)4>3(O0]<7s=@60^5?7Gj*2SAq.a;1TE.vR/j%]b@(/g29)<cWa6529>)MKv>5.Mo<8`H#sIb'N68gWid*Bq_l8YcK$MRGCh$n1b`*9f4<-Z^=?-FY4_$wo*M(p[vp0<0q&$6%f34f0Tj*2pST.ZTY6#r$*^%i[Hc*Z8om8-,N995AAp0Z%=d9%_IK<xCOPA?]3O0Y]Z_ucYC;$-8dq7&C5s.22Jv([ht9)D?9?TBbX)#:=]6#4A[T%4O@##.w/S%k^OpB4Ss>(mI?a*Pq(U.[Zc6#G+pK%785b@3v3(X7:/0<4v3&+kX%X-+#Q#[Fj49+2vGX-Ch8Z[V4IV+K/5##h:[<$.&`20o1fA_@``3_(#l-$Wu(9p<Hm6#IlUf:Vq]G3BVr)+82e4_fS*=ahmG:,K<?,&a1g@.d^K#$070X.#D0##GACf/meZK#PVCxL5Ovu#QQ>j0Tm(,)kb*;?N1&7#Lb7<-#oIm%Z2MK11AP##:=]6#@UY6#3oq-$p-[58,c$Z$eM79&hi9(Op^vPh)Tv6#t),##rQXn%;XUv8cQ9ppp8q9(98er8%7C#$r>_20&:AG2R&9G;eDr,kYe@h*N1u29XJui_J8E?%/+o(#F?g4&cEj;-(rGpQMd*%,RGo.&>an.&sst>-9B-(`'WdR0-]nR8h7fC#WN#]k=[-Qkc[9K,T7C+*w+l+N:1#Y/U3DG#`&;mu8+/6*`j&&,CC,w.nIBG3(LEqKUr.$;k-5t7/Yu##_sdo@(C>b>vqJfLHF9^$@X&>-g#1-%GB]f:sfCOju7u&/YES1=q&-R0qA-mk5L62lT^v';Y<7g`s0w(u;F.S/G%a20)E>G2JKw.:C%K?%@BJl/)c$##`xRh(J#@D36#Us-[6RV8m9O2_Fx%O_Vbn;-cct6+Aqh#,?TH*Z<6s4/nAJ^RO.Dg*%-)<-V9bN.%7lh2i?J*+,>ER8BD<DbZRi;-P#X&5(gd_ucPQt/65D6&]t7j92A7j`j3W@M%oQX-BXp9/[lsU#riA19PvPUA$<Q7e$),##>)Yu#bm&*#.c4m'p*Vp$Sf-L*Op;m$Xr?Y'd6[a*$NP*EW3JIc7x+s6Ykc_-]5Z6#e)#hob2Z6#%Av;-]g>w$RkUnfE&jc)J%1N(()TF4)li?#C]R_#m_Y)4cP'JhTYHU)dmbL:8#eh>%ARg$7/BUu;r#Z#*=Us-1x>c#>17=##r^^#aRu7.bP5kkeO=`W9CP##N,a2%`08/`VTkM*%xSfL)F?##$I]F%=%nei0bX`ooC^]+15*^,X@b@PM%=ltr#mk*CoUp7_soDttVXRcU6)mLdM#]uWxeh$#A%%#?QB@MOT6##$l.j0f0xfL7Ogk$DkNp(.dmAQH]XjLJBspfHt8q@jpnULtVoW=.fYC(RM:]&8)2<-i=<G<E>+jLSsWr7:<Gb%-jbp1;QrhLjdbjL^U&e*Y;6=-go'I*Zt-@IL-R68f+2_?isTm&L7Te2@qw[u-xeh$i5>##LS@=`bX-W_`Mm6#:XI%#`v8On'4pfLfs2M-31*Pamd4H(t2@2(vNO9.$/]6#G1`&+sEb<-Sphx$TC4Y-tBoP'SQfQ'h9=8%Y(b`*Fi.*+q'mb+4:(p71'uM_>$%GVnc*k'ZsLV?]1&B4N(ChLqNql8/T)w$0C%%#m0e4?L^E$8_3hnbh%4a*lms,MQu'kLA5U02XXK_'cj&68pugG*9Q^=-:p#e'1gKa5(TnlfOqn<-K5I3)$$sx+N'TcVB,CJ1Hpu6#&/5##wk.j0+)niLd8QJ('&[6#-vca?M0><%Z<Z-&LQ]'/E0&F.lr*)*],F<%^F^]+2n^$+-Zlp.BTY6#jxxv%c@)U81@[+6)F5gL4'm*=sX2[]^?U02#-gi0=1<<-X+Xor`AZ6#$2+8_Aek0(_sNe-SJ8ug9^.iLTG%IM%<<$#pe%j04l&kL86$##e+$L-5Amt$7O@##Fm;&+_KM<-ZJ'K-B=Jf.&vjh2c93n%3/f`*<7kX-IXC$%.n6g)BE&JhC51W-mcnbWTu/w6p`I)Sn$c5$Nsi:%q'qbWAQ%+OEt%h#4/B'sX7YY#u^HxOG%xJj:Kkc889=2_IkwZT.S2f*B*bp71r5al]`0u&/II`2HxF)4vfXH*M)p=u%c4muFhO`'bxP.Q/OLpTge6##?2u:$=s39#Bww%#'fYp%a6xr$(Duu#R>Mq%llC0_`#SvnZ2Z6#Ixw],WYHo8s]ui_p(cnEpVD=.^dfw#b2qU.Cvbs[gHIN'vl3pu$HAtuJ)'h(^@[5/(n&*#?-#e8W9Om'D`6n9[IK/)7kn;-=r:T.BTY6#?Y#<-,LNn%-uHq7&cP^?qGv6#k*lf%0HG>-OR1H-rsH1%406+&LFTq)gjN^2_9OL:#LEZ6ZDsI3h,MObcr/W&:#eh>LRE(SU6pVesHf1pUmpw%S?Q0mvJa?kR_(##j9gLpo1[cVjwb`*:@GS7s(Q:RGW>t7,GY##Tsdo@_q]b*IpRg1ucd6#u#%GrW)?lfE'mlL#*^fL'<5,2O;0*u=sAc$3QAdM9h+<8Q$:B#''d6#eMmE&#P@h:C%(/`AX@@&ZAD@-4U<*%E2-F%jVG-X`S4KP9g,^ZFEnB(LjR7A0Z*qgNHDo*x^P>-#lhl/-^@)v/uBF$G4ghX%7$c**@0<-X47b%bq%v#9f###82e4_=LNP@@6XM_g6V%,M?`D+gx_p.33pL_ELHpK=Z7.MJDKCO=%V&nmB*7%ohwp%fAMJ(aRLa*)n5X-3KsqeLV)B4%M4I)2r-x67TAX-v%M7n/H3aK`jde5$B%sCasC#.#CF]D$^qwSFXCRuRv^D.OEZ`#t8XcM7hNOWH+f.2Mwn%>r=XM_4xO?gZ_D>#DHcf()a6E+Fw@;$3:C#$2C_>$p'`KEVbd##-Yoq)w;#cEXEO2(wWW2(<^hW(P[7<-ABf>-t?Vp$r]6$GeJ#cEPOd;%xIZ[Jb'<?#$8YV-cKpn/h#W@tj?qU##J;/))>)W-B9(</ZLvu#kWp/1Www%#8f5G_,#`3_F8Bx,<E4-vT.V<-=kw6/rCa6#TV>$MD%3$#,57b6.i5<-6(H]%nWE.DZ#fv7=Hv6#nwN^0_[d##YaJ68-Q[A,9jce=7D23*RL+nM=l`n)2I#GC?S5Q:f.uq*C3468EBk>d((*/2Db9WJY[_68bRF&#LWo;-o0gn$kC%>-c.<u.,$%GrH0QpK]e2hF`-#X(&oQX-ZdqQ*m.#V#.axX#_L)h5Sl68%x[h@kd](T.*dd6#E[;<DwPjSA+-$k_9-(,)NDRh(r-]V$-GiOBZe^/)g`B+E=*x],]U>2_:Sx>IKpJ7(%9Aa*SGhn8BNPR_vpWt*ZmNa*EG-=-XSGS(+K)t%)vD%$$Xj-$APeO0$A74o:p04oe.Gt79HhI;rPo>eOMuD%tw78%b?g:d0qW<-T,f,8o5.K<Z5R>%5)bo7TJ-/4qw`C,F:Im8XGL#$uNj:%tVk)8@mH?$04SR#'S'i8axO&#C*cW%GMR&'H]u6B7j#0)kR.,)iOx;%S@+?.hvBh$]6xr$jq,A%HVnA'9=t:BA(Ld44.Ml%'tfX-I4N^eg_?J*FASM`HAlqt$Yqi)J/5##@'_2:*[HdF/M+22p@BA+W..T.R5=&#_5<2%,GUe==HnXH]$Y?._SK],2j,N9t#P]uasl`%pBJX-M[5cG<,,D%12YE;RLWfi'1j;-eLB$Lq<wm%lr*)*2,0]%KA?u-.f&p9Sj0b$DC4/2me,0D&gjTBc&PpssL(Q(*18k9Z#*c<PFgq'<2dm)duV0;d+9^H?9g<;(p_>$Oq5a3D/#v#fBai0hH@uuo-3)#]om(#IQ1TP`Am6#-4)=-933M%f.?>#DxSq241IP/?fti_$e61,hKto%uS.,)*'A*`@HHcMq5Z6#q@;=-hbPhLoqD0_O-]&M3;@k_OSF.-o(HTUi*x:(+SZb+kVcm:u554gUDtsSU,se&U>Fa*a^m7/t8H4(f;G2;/=Gb%pbq/2=7KV6qk6K2$dkV-Di8?(_<xN9v[LB#_o(p%$;#.8fRlA#9@$>)_8fH#x>AtunE63-A:)r7AsF&#^.]>eD%=$8n`kA#H]cA)6O@##/(L,bnxrb&UXD>#ve1#*Y3LE%HV06(=s%^dx+MsfNc.32I$J/Ci+U8gKnfcRwB56-..`m((V[Z-(=3uQrhuVfcZ3>hn.r>*W*&<-Jk+w$0%)]t<=.j<+Umqn1'O^,.O-58%vgY>=)+w7x3:*#fUs)#i':+Gq4^1,r5@$.1<mI<5t4Aukd)G#ZYmq(eX1(+;26Z-k+,'?ig&%#$?$(#5g$-`&$MG&.SHj&j[gr6(iqI*HRGcMrAm6#9S.1*t@K32<V(ej:O-h*.Q0<-ZuCl%3#@D3>KMm9I)ai9wobJ2atva*@pRq.o3pL_=sph_HtYD4aF8e%+*KM0wKp1..tb.+>*9iDQ`2<%fE@>#oAZ-.^/Ug*W*TR8sYcN`x::3,IfOI)YZs%,Ulu8.>PXj+I`%a+7.P]ubu+c%l2k@9)0n?$t*Fj1Rfdw-F#F/M,QLEPX]MV?4^,W-$/A?%]C$##/)w4Ai./'v#A`'#xWF?ej&b+(+ZY0:UL:DtOA9x,X5YY##J_(<6.%d;wc6A4i*'7#_Nn#S'I?c*l'TT.4r,O(DuaF3FA5f*D@.<-0vroCBA5f*)UkW-Q%2<'>&]iL9pIc=l-u`QPw<Ws;*]i&A5GB?/Rj/2rBRS.@X2Fp^da&d76Nd*lhNW-ktF4K#ihTTMdd.q5bWG+)IBX8vmF]u$?X[)<hJd8d?[XJj-d.#j8q'#Iefc&qCZY#Ok;;$(%VV-g)Xl%8lBb*Gld,M<x^nfwR?.25Drc#:0q&$^I:52$.gfL.OuM()2n6#;aIo:TUZ-NesY<%je0Z.@),##3Dq_%R'be*B#:78b]=2CJ0[B(8HKX-5H4l9pq^eXxlY&#j8q'#cO(,2`Zp>-]@c@(,#<X(2jJl`Xt+g$;xh)5>2+5$g7L.*V,8r@01Ld4-j&JhiG1u't<Zekafps7i:<s.c#Jb''tfX-iq/K5m+Yl(Qt:r@Gd@5)hH?jBWisx+XRc@tjMZN0[/5##2l.j0wAhhLDVc++3C]p.p#%Gr%YM;91r[(#Y1<H*owED*l9]Y-;79)-rHgd<j+Vp/3_NP/l%Ch<QN9/`Hl0cN&nA,3A][A,V#6v-wcIe*xgKW-C,u*c++Whb$Zwr)PfZh*TZ#s7H=L#$p;3@]nh$##-T%duurBF$.A%%#jLb>`/=Xt(t(I+<SqgJ)bLMiO^lkb$150F'F&_a%W>5?ekLm,cQ:A/([?@5(nSd>Gcw$iLfCZ;%FHl0.7ZcX-ElREZ9O/VmB(mb*48'=->&Oo(@))6/E_R%#s.oK8ZwA,3iJ'g2haSs-tPC:8i`*.-$FRS.Q0FT.0dd6#<U^_:YUvkgoH*j1Nx7?-ZT4n%LeV(+hi6b*Epp58@_GDOMKOr7MRLMU<_%3)WS6Q/78a`*NV#J_6R#^=-j7aHXVGP9FQ:6;0x0q-X/Yb+fKPc*s9fp@cb>2_c_.Ae*ZGi*p2::Bip#Quh)L*8Bm@Ac$QJV%8W),)vsai0'VNG)vv,*<MX1a4rGue+_t4EZB)s/<Leh@Ivv]%#sFLf=Q/w_FPn6iNJ+`&nENbR2Q%@3-8<C;.XF3]-f0Q+<K9TZ/A+j+V+?p<-anXA@SR3=.F.b/2K3=e#YwVQ:=5R&4BxnV.5L)Pt[Y%()q3n0#x$3W-Iu&r^_AMG)QPDN0[l9'#.f%j0Oh20;%g1p/Xlk,M8Pr2'Xq%v#A5?I#.qugLeXQof).3/2D<O(jNY(8o%uT^#26q%#,S,<-75T;-G5T;-W5T;-h5T;-x5T;-26T;-B6T;-R6T;-c6T;-s6T;--7T;-@RP8.F=]6#TNT>67+lZ.VMb&#1lgk.a4h'#J8#>=VcDN;8J9h9rYl]#]q.[#Yhxw'G-K:.FXFe<G)/=,AeNX-TDtF3v2VB#gQu:66.%d;,ZeKiLaR%#:L7%#dcv6#JY5<-'e3e$[(78%<?7p_x(-F%9TxHDo=^;.d7Tn$`Z95&2-n5h^Am6#C_M=-TUiX-1lVvetvx'&p/uHDu?]8Ur^mUrbMv6#%mRfL].0j0XV/bE_Bh<LqGW]+6v%IH78=2_G6=IH2w?L2)2h8.UD.&4=O'>.t=D=-tS,?G-t1C$=c@e431c,<CH(N0DWu]R?rVS.3D_C>Q(VS.D&0K3]qMZu1.7#6kh2@I<dShFkN7EAbh<lJo_Ws7+<quGCw5bG@OwY#Hw=']JifIq#*n>,i<OxbmTXgLe's;?&^gJ)Eo<#-Jr@&,48=2_'._E[<#oD_a5+iCD5=2_$+S=HmmkL:PfjJkg[pfduXeQk^;d6#XqA;%+G)s@BP8B&c;d6#bVV21Zf0'#v4'N(%Weh2MaGG%bLws-qf*&+a]Jj0GO=j1)*AX-r*</:t0EW-&Ug&6?;L7/X&-DkLNPW-kLdYuo4v.8(I;.3:xh;$IkLJdBdZ;$1R_R[8_U?@/`GGiQXvu#8$Brm6d_5/_k.j0ZQ+e<LK9/`'Dd'&N@t9)__D>#>$gi':DEl_U29p&DcDm/mTY6#rCa6#N1P5;D>3-C;p:<(U&Yb+IX@%>x:=x>GmL0*&il0&IQK<-iuY+B[qd##>sdo@,;3jLh`gs7xH2W%3IXt(rX>>,9Mbi_fJn;.2BO9`_--u%b25A#Z*x2Cx%2)FXe72CCC<JiA_as7@$Q&#,Q8c$dah053Fai0c]ln%V>sXBuRo>I;B2,)D:dq73o&X'S6-&8nxj^u<xYn$S@%%#X%)D`:Lf;%3Els-moHG=uI9/`7ud'&qR2xPE#7#6i&l;-lQirZ'ZqZ$&sN$%'9CX8Nbxv$dY19.Z3pL_EXd=(i*,=(mRcNj[b@*/chD;X7*<d*Bj4gL,V`5M[Z@F6[wm##csdo@7x8kLL)>$M=kI(#AvSK)[Peg;Oa7Ac,/EAGL21^#-IPq.`&w4AGgNGiW-cc)r`:2'np1d*jb.<-/u19.bk.j0f6MJ&Pcqr$DDi^ofmpl&w]q%4g,ji_l>*(&KsoA+U_[Q/W$%Gr.3%qfwkN;7fLs;75wJM0]36H&:LB%>@DMHcM&uh-@q=)&X/d2'Mb;_%VA$t1xul&#^Rx&$W%JfLe>W8_-I,M(OV2W%]Q2wg.Q(,2RUCj_@fr%4]jmJa<9llrc01+0?9AP2'D[lJdg&d*>vMX-$biAdW-MM%xG8>,#pul&^rB'#d6`d*S5U<-_Z04.7oYlLiAm6#Aq.>-Pb;U'l[TS:c&@12xpA*#([b6#X/N^Ap,YG%1.k3't/'RAC'IWALx1g*Fro<-F2cdT#Da/%3Q_T.4),##-bAN-4/aX%jEPS&1nHr@?K=2_<O[CF,<8X%eB@>#rDW]4)$A*`pZ0Z6fZfURvhHaPK99]Ztr,t74TqU@9Kp(k4[Ym0$),##/G:;$jU5+#Za+A&?9Xb+&_li9[IdF<cIC13vv&U+4i'?56r<F3(0r4f]<Y+MM1q5%CuM@$):_3$C4n0#2E&:Dbr($#fWt&#?S35/#)b`*DFP8/@Adp.<b($#](]q)fZc6#A(MT.VMb&#>6[&%49KNMdZg<(0QR@(J:Za*vKg>-RoXC.;tqFrD>nY+nHn9i>hfnqTG^_Os3M#=@ZS`t<A%n&28/A$jU5+#Qqn%#*b7i(o7'&+ds;R';hk?Gt'i@IlCm6<G/XFN>ln`*ot7T.]q.[#bI=R-G7dT'w.kbe>MHX-@wBId_0CG)6ioMBI(Mm'Sf8,GQ#W3(aE$2(_E;A(s<kBFn9OM_+A84;);`B#([()Nav=F3DxxV6j2[2%dIwou%f9^Y`[k`*IHSP#Su($ua*sI.$]-(uk8QpK*qbc/QXvu#Uvx:HA)#@UN'n5(ilGb**Xn_4JZc6#%tqFrh4&nfi:/nf9L<?#$8YV->?7^#TL;h$*Dxice2p;-]x7Q-88>d$.^]k)Kt0vEseoFe^2U_n9H]`]-)T%#YKb&##<TH)AvcL'E>oD_x:?<K/Me/(8[&:(Y2#++uivZ>o)..i2HQ:T)o]1(N#x%#'[b6#Wx=G-k#tm(bg4X-x<>8r8Fj:mRYWUIIHJ`t*Ge3093CG)ldqMBxd<K*1Qxr8`tkA#t)mI))2-78MmO&#jWEr$J6a<#^d0'#Of5G_Ci`3_mDk-$IXE0_&]Z&M1/%O_R5#8jw6J*dJdF?-o<8f$-0gi0_2x?ng%4a*:-cs-Th679%/=2_5Xihhb[vp0b(Rilo52>(7PV/:cO2r94^#5&0/pa*f;vt-HiCJ:H+>)4Sop3BLk'HOkQ%)E3>[>-e^CU)<.w-.-si>Rc9OG%tw78%buQlJ5Le29U>vm:_1dE(+%;B+NMD_F44lq&R82/('h`H_lrnD_wxlv*C%ap7g;h>$UBIT%g#bSs1r7vPblf(%jlO.#UKb&#'aU:86hL50Pdo;-3)mJ>A0%607Y120IrG)%2,x%+P'M50WGUA5h-_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd,k[5'T2dd$ZCh'`;?_c)f4Sh(44VE1ur?D3]7q%#]VH(#45T;-D5T;-T5T;-e5T;-u5T;-/6T;-?6T;-O6T;-`6T;-p6T;-*7T;-?e1p.)GS^$.UNb%YXr-$@2Ss9Vm&k_lg]f1bmpj_Wv,/(38F2_)h@k9pd.]evqe?*q;BU>cWpM`svli.hK?D*a>V>5,,22'9g?x>JR4WSNVt0&o7sD@iK@6Ovim6#+),##.r+@53.*v#+.]$7dn7T%mGfY,oR3T#'s7P#]piVd]a(]X=Q^@b$-eguwqT^#*h&M#wSTUu-%c&#U7XcMO0=a*.LPZ-WK#7#J:2=-?+0K%e.?>#8Qo'.lUcc*g,ba*<f7wYcIv6#?n]N-Y^3<TE3i&neCJQ--PIj'dVS#$>3ri'erW&#lDNq-=Y]9r9;Ci^Ajc120SWjLF8e@Hxi]s7/Yu##t(#eu*`7(#e3qv%?d[O('&[6#UZc6#XbPhLG@,gLW1fo@ZQ3.`YnFZ.N6Z6#q%qK-tK5w$-1t/8M]i4'r4DS_73['([_R=-mHaO-@W'=-sZ=W-[F/2'NiA/C9L>A+&,h2&R/Ow>tE99V>pP,2R*]V$kxx]?ISZ`*K)h9.FB%%#AjkM(TqpK%r=7`,h]E.32FMP8`I$9.%'Qip9;LZ-RYWe)B0BuAg];iKYb?6%G]Q_uF:f]I/q0J#S7L]lkn8@6=^6#>$+#mAcDNbQRYZY#:dNv$UNYO-Mc`:%ev;A+sj#H`&Vv6#A),##(Rr/upR0'+&Hs)WY;MhLJm$1/;bxX#56Gmk(I*L##<[8#edqS-GxrQ5Qie%1sU##,m;)^,M3Ha+9o2JUqE$1k.vN@tP-5dbl/T%#l8q'#?+KM0,sl8.ncqr$<U(_&kJG&#xuTL&DBqA-Hq=n6>d9q7G8M]lao>q7@?v^$ZF6##Sr6V8oN<j1cIVd+^tv##Lsdo@q8K,D/Uq,+&Z$7,$Ino.GRP8.'G^]+*`lk%]*w'+aK[m8hn2E,X0jf:v=6q7]';&5;7MD(F####osjr$C6a<#l8q'#UtdpG'&,d3GIrDEo)hWhDoq-$nTq&$ajT`3:-V8_SVvwlYa^/)]oY.>A2oiLrOiQ9JvhP0,44v6aq1+'rsu]-@x%BHx5Z6#T.PG-OCsM-N77Q/9vjh23]R_#$GVk9<%-q9]amJ,?m@0<x>wn*dK[Z98Q)?[d<*$#vuv(#5U8>5>s?D3WGUA5mlW8/u.X8/&]F&#xOF&#Q3M9/hKno.(k`H_`,5kM@;,f*_?u20]^''#_r+@5OBT:@.9xJNbPV'#FEX&#dcv6#lQj8.)*gi0M:r`%x7:c**`8r7=LlA#GRTH+ubr=-Xbb4)X>ls-8X6iLuQZ;D6,?v$v(,k_<=rr$i=Sh(7x:;-:24w7Z^Y&#1E=P9c<c2_^XD0_P;g>e5a/(maR)C,CV0m;:X6H+@bwo`hv8p92WdZ$4me%#uVNLYGoS3%(gAx%ZsZ:/Gr+@5v;_hLYpls-gWcc*Ak>Q8)A(B#9vriUtX%Cu/+@[%_$u`W&p=W%(mE9rO)e_bl`pU@+]l#%TD'7.k^lc*+k0K:u,M/)k/3LU;$a$@RBBE#ItfVmSFAO9#6Hv$WffZ$e`6R9q>ps7XF9:#p?G)M3CK0%=Mx%+P'M50WGUA5h-_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd8^t6'n&[`3lvJM0#Y.,)%ijj$tq:;-kI3v6Una5/xR@%#`KNjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%M3CK0%jK'VmdGgq^^0_;6/Ono.`?wu#8T(,2so,F%oweo8Pa83M,T$x'xxC>-3Inn,,82Y-oF^BRjp?+#V[,R$6$O=Zarcn_#]J_Qf5Q/(Kin[Ye:o[Y)q1/<,x-xk:0i_s[>1oI>4*l$f=Qx=`s*##T(+GM1SIp.a[=JI+B0i=@D)c<HXvV%4wXU%%dN>/Zpdh2buDs%kSuA&qG$6k.vN@tQnBuL]Dl;-xnaRNIkc&#=@%%#Ext$+'gfGM/%[p08ecgLAN''+*;P9IY]`FRAEAr7aH4Au?qr&0ZCSM`HAlqt_ii/)MRXCmTIr^9=K;s%hC]8&>@:o*me.ZP`bIw`8w,(Nwp'n/2mWfhx&xu#H-[cAgcs3(x_Hq7%[r#7Tvh]$h8(u-'(3&PPj5Iu#PS5u12*V&bxP.Q#Ww222m?]4wru/)W?i(EiFwt-N(cJCdJ@&,]MS<?Vkt;JFu;Q&0QU6//tqFrig1)+784?-?XL&(]`I1cum9X-OILxgL>uu#nsR%#8`-J-3f+%(rJGveZ&54k=x0l8EESBf9m)%vl@uU$j2<)#hnl+#.8q%=7xk+D(6eM1rdvf;pW+<-ju19.91>7(Tsb;-R%Vp.9Da6#EKJV:TpV`$5O@##cXE^-D84[I_W09VNQiA(GZC/(1*T-D7to88P_%/1CFET.rsqFrq@Rw`P@`g*s>_s-iduc*#8%=-#<tr$8a,F%^w$b[^w$b[Y1E_&Rf$<-RfG<-1CtR/V9eh2B%NT/&<6Q/?b^u.h=S_#:Ril%PiaF30n;a*c#K30XE/[#'cn$$-SlID?BFsQ8F-xgj'8Yem^-6Fhs%U#%=O4:i)BC%bClM9(s&nMI*O^4&%Yr_R6If(#)7H5T]V@#fpoRLk;1(>8cd>#UdH#6&I=w3'fCsnLpq5)h?RQDm@6W:)I.k'PaEm1jCkJ<=M2x?h3nl;TIhd?qKhW9$cg,=91?%$w#hA?&d2&7Nr%'-uvL-<eR`B6*=LfL3=1p7:)-Z$MT$6%a_g`*j1FC-iPYk%>7[b+Nwo+GYps`uSLZ6#C[c6#ntqFr/1u?.FF3]-:n-x.d-U.Cm.lm(-F&g:J$'58vIAx$K5>##W7p*#RfN.`%6]Y#K,[`*'?%<-x`5<-^@;=-u_EN03%###b:ZO(X1vZMp7LkL^8Z6#A@vr^O7LkL[PYrfF2;22Jih;-q=%q.1Uq&$U=[0>^-V8__pN88gTSL=p71D(U7w<-&bKI?^Dv6#,[]s-RdrmLV=UkLPUZ6#FZc6#vsqFrgB=gLIM>gLB=50Nv@VhLID4jLUbIbmrMgp8,9`D+vp=<-^fG<-ODnA-CQU@-VfG<-*Ywm/Z9eh2Y,lA#9=*Q9Kho(k.vN@t2EYK;<k*W-<s[N2H%@##RQXQ%<t7-#5&*)#Hkd@`jm+e+C2oiL<w9*#6$@@%Sid'&'r:;-%S8>58Q@##M8hW.:=]6#I.v<-)diU%?tsY*K5CN9@Ok/2C>ou,?)(<-vA8N%DXAqD*Y`K_D0ut(p2w=/GVOjLXSu?%Z4E_&phpD_AY+BmBq9a#l1bF3RHT29H^m0)D3Tv-?+@W$5WLD3M)fD_&LY^$/[YT5i<SXN:fj:;7O7iIl4[['k=hEHenI?MJ1jq.Q((,=c+92'O4fmWEld>6-3/(>3;_xtu<d>@12jA7E/-F%[u-F%7Dp-D@jgj<9B=tLOuOFc>(*c+HN0,K2/MVAaC*'6(A%N3`4p@?<Bk;7uMhl<S3Wk1CT+i<WBs02'9NfLWq6##g<fT$Nu;<#28E)#r#PV61Wsm$tFaa6B?q&$e8mx4YDCpL8RaK_ILZY#8>2/(LxKS.82e4_iCs9)P3o.4RC$LMX%_nfwR?.2's;+N$Bm6#?Y5<-$Khw--5*jLK)7A-KmVE-saJB/tWkU%tn;;$ZJf'.0`0HMm^[`*#q:b*h@ZB4ICo$$Xe_a4E<^Z-)U8r.e>@L(a;3&+NX=U%BVO,dmhssJ^<]E=v=TL(a)Ne3Vomu4PX2/>?=UY6.a.?5rR%(QLxfu@?N0W7PoQY@Bag88rPS_QQ9wla)Rpt-8la,<1Q=SA%b/??qVqC,KV+auRD*,QY.4)$$f)`H&P[M=B[dCH'Sni=Nk2b$hA*]XeExuld6EM0ej^6#6^Z6#'O]f$;AZCF5O99p%K@wBpal&>6;D9/SGif(])]V$w>-n&eG^7(gEos-6ZM78n4Z;%2l`s@Aa+/(nHjUI8njJ2fTW*.El*F3Lo+oJI[Rs?u4r0X0^4&HVJqcZ:#U@k-/;L1xKlu@=E'W7QrQY@BZKs72/$3<?#_qM;/YUB*^HS%sbDHA3Ops1<381<P0Wk1;$jk;#>t'#eL&&v-R[<$;A%%#8nvJ9PJ>s.B>Ws%Jluf*Oa-NBiG=2_fMu=$OaL_&?Iho78e?.MLW6L,2Iw;-kqbZH:@]duSet/2VTMR'bP$=-wtM+p[5Z6#gx_2:Vbd##Lvl&QX8d6#ko(0'&FRS.)6],X]8Z6#Noq-$8jm6#eF.%#Hr+@5,FE=G_(/W?P4vG*YQoc$^C?I4+ri?#a%NT/GN><.2w]]=sS.?.qVCg4ev1^-AKpl)C+mD7A7JuDW*ZV9`Y=;-S*a<-H8$J;fh$M,3ohV$f`P(21:6R:SH/12+?CW-m2go1o@BAg7ih2RaOB1;k<=S%Uhj;$ZPg&=;Pws$raNpTcOTdu./Cj$1[I%#fYI=`Y(G_#?:;;$-@78.%)###'X+<-9lls-Ol)a*/N(<-.C#l$Q8>>#pO@##m-LhLcMd6#:$%GrS:aa*Nabs-rG.*+TUqjBYQ%a+5E,<-rEWla:gAe*Gwos-fetgLamm6#^R@%#+r+@5fR?(#5ftgLe/eh2k(TF4+87<.#8pb*%mDT%v+gm051`$#A,m]#Ynn8%mAic)k@C8.Gq[P/%01^#]LQFH-cEcHvh7`>UK,HRmw:G#F[m%FTx?aGl%@I73HN'7Ok'L*^nP7$$^7E?J_ohul9ki-Y(>=Ip.=A#%2&c31vF/Fro[5/?t;3WxL(G33bULp*U&,22xUZuwi1C$4f[%#o;BA+Cqf-(H5YY#ukB(+v>B<-8kw6/?n:$#^4+gL#8Z6#3GE./_>Z6#ATY6#1<^8%lCW@'q9]0CXisJ2qAI?p2u?X-WKkA#x%8&4/sun%FEPA#_jA4CVL5ult?JG2f]Iv5+?QA#.MY>#JoLv#b(k4np#iLgvWh`Ng=)/XKt7-,d&^E+MK3wg;6MY5#5+jBJ:ii0cDn:Z0Vbf*L2-<-KY5<-4c2E%2.@>#I*QM'b52>5N1DQ')Y>>,[:$T&M+]A,@j^8%s%6C/8hx+2ahW(=k/1xPIqd-d&Sj30$>05`7f>>#.fuNFadTP&tuL,*l?vi_u72(&SO)##47xN9GX:a4H'8DEMgr-*qV6C#.m@d)oYRD*nX3.`c9@dD@_a`<;YEu:Toai>Gsi.EP*M.cp^t1WhrYt&&2b9JWq)L;bVrjFYjB&?'aZD6M`9&?m(i6aoqQbJf<hD3Ud[jD*91Z-j6S21I-F>-)e]jMk1axI;XR6ht/U_HsT`'>CVuaGA5XEe4jiLpVV*mA:/TrQEP]s78UJs7Y4+gLa@fo@<[u##%EEjL:=:p$SVYY#s$29.t'>ofO&nBn7M%J(8vps-,)niL#UP&#xk6U;1S5;-$]Q2((Bq.(hx4a*&u&q7jIuD4#-bd*NT;U%')XD#.;Rv$@]WF3ge#Q'+Bm%HaV,0ET'gQL'@hS`UF+ZuGsVLFoa2=Br+I-GOSqe0c3up@m2JL1=5Mw@dACp7:sN/>u^HHP],e[7L,Qrfo'O#7n.suC9mxa[^iDoICYVSnn+;SINme%#w-)n8,9O2(@W`&#^_M^6'9#,2jZ^`NBR$m8,rT#$RK.?nQ851:G;`D+27C#$G=7W-Tq:4^Ot1T/Tj4$MIMU58,:sl(-:pK2?PsD#h=S_#[J7&4+0f+4ZH7g)U;Xg3.0i$%+?o'/#(^-<KhouD/7MsuoH<oT[?&.+9UprBNneD4@5:i6X@_G3^8QO0DI)d@[+4U_;WBGBC>R/@795'6XFqE>^witS@W3wp+R(]Xgv1p@IHQuYG*wS@a$42_mkGs0:KA-[u_'`$>9'T.sCa6#88,8.;4MN9#2FM_3KC#GIf6-+(;sx$]p^0:DPDRq?'E/:@l=Y%(8>>#H-mi'lOif(FO;;$:DEl_$G2(&R:SC#.nvw%4h2w$IBuD#ae_F*^,MT%9:fw#<W*43,NZ]unYrn'kD:m9ewDf-eExJ1GH,aQcI(]XA^9AJoDlJ4RDA`sXns;$Us*H;^0]LC&g6=Th1Z;#*IZ$$`riLphl&)sJ)[`*q7HTJ+:E/2t;_hLx-P2(fT;w%m$ECt>nB#$=/d,*G,M*M/)=$%8a,F%E>oD_sTlOKq>UW/]@o8@oJ9/`s%d'&gRIL*G0Iq7[8d;%+F[m/<`k[$3aDb3Rd/m%w&mf(nLho.x1f]4e7H>#B-Tv-Q^4;HRU+ipK`e>NJYRx9@:h)3HeAB7Ag]Xu(As+MJ+nAJk]@@#?vMT`k@;(C+YW=l_)ngusGS(Gd/;#k(C1@j_YQfL0N^)vEbZG$,5i$#BLXS%B:iGD/Rehc(jN/)vSX6AQcT)lMvf0:r>(<-Ef&ePx:;8.I;;V.](A`=^_gBH@4+Au2,]'$dlu8%n0=$15H:;$V%m+#9*,;`Z?Xb%XXD>#^L##,Yw^g%RU*O9=;W78@Dte`j?l[PUW0j_?dv%+o3'V%gJif(sug;-/r(9.VJ^]+#;-L2DitM(CcS&$ae_F*N&Bc$,Zt?#Mw@8%e:pH#b#EA+1]O3;,xRh*fI9+*5;Zs.HdtL#6Cnou.n7ul#6br$?#m4:p$FT%VX:v#o;P40b_G%OR%EmuJDoJ06/(V$eU8=#::[U1>RYv%^VLp.P3pL_B4gYgE>,)%8sx]?[X8b*%%(<-%QRu%i#<A+kp'kb;xPV-`(2W-39xW_2?Z&42CEs-1tZiLSFZt$Iq[P/GL5$gp5Dj.mG]'5@%>U&EYZs.NBp(@do>;-=G2p/wlDW%iuJR18qN-42uUYuUBDS$_;:r8dCr;$[$r;$,I5`Q-0/N.(C+t$b%ip%SD)A7Oo>c;.$>D31sRdu)_C;$Ck9'#+p/20kT95&HhU50%j`=%V[D>#E&/n$bs52'nQa.'Fhx$l@cbA#0CM-,/AmX$8Ph9;;]s9)ET@ek2Sa+&$-cOM/PFb*f1Yu-#:9p7N5Z;%.S;s@OM?=/e`m6#XEX&#/r+@5.MJcNN%h,NZgdh2t7C?&-A0+*r(,H=I7NT/L@5Q'CG+jLKbIT(xDXS..J$`>Q(VS.T6At-Q./)=WUd*.DH:g(*X352)M*Y$P:)d;8G_%JpVL,5H`:S%Uej;$Uv*H;x&RI2DV/21W5x-#$),##6G:;$`U5+#f]K7`6iYY#FT6X/)RGgL$xSfLmUv/(ex`mfMBE/2r8S2BJ@kM(nZ/4pG)4-?u56D03#5$MI-sFr'R?0s)-/i)NCI8%/_FG2gfe;6rap@#.MY>#r[d5/isadu#?T*uiKB7X#,(21e%/M1H]PVhP8r:M`Q7F%R)AlfR[?n9Bcw],aP)qi,^m6#`gD2/Hr+@5CIo^H?0q&$.26X1e?7p_C'02'F&f--lr*)*88=2_Sx.$pH%9?R:^.iLV5#l9@Ati_:&^'/N/c;-w5^P93k8e?uC)E4(k`H_r0l9&(5Zb+l'*)#&>05`V#nv]]Gv6#'bOa<1cp/)u^el/wuVW%JT7TGe<%a+<v0W-?qGKj<e9a#jN1d2>Fk=.@EL:%^`WI)5Djc)E2lsoVwwp(pPYmL$5GT/-ltGF^V@cmUKoHH1=uaO6^Fou__3EGUt=n<`t4`uA%TQ2t'Bq/w.I;BxQC2DjN,X$5ZdWBOi48n2N<q.xY<F=&utH/;`%`,HL0PDLJ&3>bG.;6AB<a*Ue.d/)sxEPZM1HdkSn'P[tMYKkML,5l/;^-DvX[RxC)hH-QNJMn@0@nDVA:K2?+@?D&e*]$,>>#e$v[tG_%d;9[TxX0`-W-EV-F%.o*E<sNvv$(k`H_>Dmpg)@,gL`h1U:E+F>(woG&&XO3:.$/]6#<Uma*qlMW-p11uJobTB+bc*hLMx=G-]Vri1lujh2HL3]-+S4I)CaQI<nm5Q8DX)P(x&lA#;rR)32(-J*^#1M:bS0;:D1Slu_e-bm/-1m7B12k%Z.XEGdVW)ui05##s1+M$lt7-#^pB'#;xJM0JQxQ_<Z/e*(`as-3f8KMA*Y<%gtsWUJ.OX(W]80<;Di*6p,$*&TR)##tk5gL+MDpLOcc,+utQ<-9.JB.UhFJ(5A-W-pfA=d60X^,C;>x6Y*J:RG7SC60hJQC/r*W7Q+wu@8*=v6BaMg;v6;?K[2T[7=N7.56xnj);:htk>)*=J*w@_>d?TXJ3H@A4q)/6=WSDaLa?)T<?rTn1+6Dd20r2H$ms7-#BRj=_9J`3_VWj-$$(&h*>3q&$x9r+;pZcQs=nZQsQk:$g'rDM0/+C2_)2WEe9*.ekmJG&#P_tR-h5XCR]`,8(ifYb+CnF(.CC<5MeDi'#w*kB-;R'EuVem##Lk=t8]wlH37ZRD*AF;8.Dlpl8?WsP(ThhYId<*l:X8DjFPVM[%<?x^FPvD&7fDIdF/^rm&Zna9/DxD9Lxf9ddQEw+F?uLpCC0D@8F5r$7W@hE>_'stS$6YY#H,iLp)Xwc;b**20w3ad+>(o.26Fj;-3[4Ls,I<.fdQj$#*ht6#7$pN-QS.Q-CM.Q-PPM:%aVB(O+m`m183+F(-FE<-I%&e%Rf>nEm@h0ML91*<%cVmLt[WiK(hG,*6Ew<8nX?x69B7g)g;2oC<P2.(lfgc;;ij:;f48'M=Y:xk*`+FPJl&>@9t[>6Frvu@??b;7l;j'Qnw+wgLdC5%J%swJXV['ms$jp;eds71lX2T;l)KS1*U&,2_.N%vXxD@$2YI%#Pqpl&db<q./3pL_B@.?TJwT1(RNNe-@[2nU+27*&d/man)qj-$`b;m'sn5gL/r[2NVs@X-l*3l%=A0+*tB:a#+ri?#t^?bQavgI_;w3VH9CvE*`NB6&fg<s-4%?c#*8PruklrE#X8FciG)c?e?VpT$vW6E0xR?<_'j_3_`sj-$deKq^];d6#rxvi$JS4$g%ECpL(4p)=fZj$#NGnL('&[6#>XOr%K>0X?b6dqr^Nto%YANb%i]a8/E=eQ%5qJl)&_Y'$]q.[#FQYgp_6-kE,+@**pD*&+&/W4'k+mC(/YADNnA?@KF`4/NG.*j2HeA`8.NA6=&>uu#K0(]X1[<vGa_LS.l?4]bID`5/Wk.j0JR7%>5J0j(Co<#-=-g5/bfDmfvGqhL%6%*N<d7iL'OHc*Akls-&nUf:n<YXp[5Z6#v:r_C?E<C(#VHq7`iTppaDd6#3tqFrqed;-J`5<-&XCtL]$Bqfcv5g1#.@x69ZAX-N.3Y$*u?X-i.x>%(5<T%?4QtLRAbD?%9ML#.+7CVRe0qjGO]X#@'X/>H0/]Ii4[c;Hk)O1NT,4)22X`f8x6NR5xOJ(hESA=8EFtL2PE`$YdE5/1;:;KB*dd?:bTD3B<A1<1:)]$`;iu5-i-,`Tr$,2ehm9p]@Ex*iFIq7:5)9/''d6#A[N*%H2+8_:U+=(]b==(gJd?ACHq&$1rqr$<?7p_;Sq<1BHB*Yql('#t,f@>wNd;%EKD`$hfYC/W1E(&Sid'&sBCh5S:SC#0=^K%`tC.3n`N.)$LkA#E[5L%v4P8.Gq[P/ntlV-LB+_)Wd8*+&xg^+$Zk%?`WQlT,;P>#cpA/bLr`50%5Jp&#WG8/DpW`>MLf:RFZA%k(hw4SD87V%`tuN%dnj0;.vjT#'en[uvT1C,e,JJh3iCv#/(D-4tDC`3$,>>#*#*]Xk[;vG<(EfUgxEZ>2mw],%Neh%LN6-FDD4jL+;tmfElXs?Wv^Hk)hmc*uwjjKdF$_@[*g<(8NxA+F,HW-UOLjt7sfc$7ctM(5WLD3q,,cGWJT88[*r;?%01^#p/euNGPC@,bMaE#cL/a&usf@#9_;d*:VPYhSEDH(57YD[qCwKu/`@x8&h3ltKekiZDi&$K7$`SMmox.mr/2i^s<n(<&IOj'PrZc2Di%7#L6dh%Na<+N?TP8/:LUi%WrUV$IC<cY&@,gL'N83%HY0dMsAZ6#hTY6#'J7b%m+v<-6S-Hf@:'1(GJK,'iMg2&h'GJ(:-V8_r.oD_-5u-$.^Z6#RV>W-SD%*Psh?x6.rIv$eL0+*XhJr8sr0^#sgq=%33g8/'@j?#l;':UNN$o/Q:ro.lNSF>u#?5&e'<M<Bnso.i)xg)ni1tDkiF=%P^'1:HY&R<p%mL5/<H+Uj#tXB$3P+VjPVCSqT?>Qp/@vUHGNVO4J]ZKD$###%81V$EaJ*%Z5>##:Ekr$OP:;$96'[MO6gg1Q=ZV-BK]c;0?Qdn4UT+MeR?##]jbq$eRS70q+3)#oKfI_h5J9iATK<-Al'38Cu4;6o?.5/lRiu7(YkL:poBMs?Nv6#7mRfL<WO&'ed+gN'x=2(]jjB.n*M8.1a7u.($enTRJx>&x-)T75n`Y#]iiLp,*:a3YN9D3&d$7#X_rF;*@,gL_:fo@@tC$#h@wilcEW$#([b6#0;__%QiIsHH<rpLVvHu%,IRS.Iugo.+)B0Mtj8TAZo5K)`X>>,RXi;-/r(9.=u@;$>v(:.l*M8.iw>v><[-<.0?QdneSsG/,jQ_u0)u:?&7M'#^#mx4UXv%kS7]Hd.`rCaNCi;-/Lp0%IkGY.Zf0'#G)Cs$;]JZ>Uf:/`Mq3rR3)X#-C]MY>p6*B#l_0^>FPYAu<$enTkhoS-160iub5n0#`As1BCK=;HoYHJ(HI5JC+pI#.GF@[>'o]A]RED^+3leY&o-9uc;Q.^#e+%X-CEsZ^NPN%XAE=;H-R0,).G3>5od)W&Xjf;-TtW.Hs,^%#<Io6#Q,o,=^^h02cF-(#([b6#>5UXo5cg&?n.u,4k5n12/DW]4dA2X%PgZ-F&_S.cnIZ]6a8Z6#Zoq-$v0+rR#5F,6#x1s-X7F#>T,.m0]6P>-6ImT''p;Q-=xYq7$LC0c92W%vqlb6%i4i$#,&*)#<@Ju*FW%68#k^/`Z*[Y#D38WAvPjSAL*.m0B@?k_wRAD*&xSh(J/w%4ICbo@ExQHb)Dx?(#;C$&8gk;-#)3U%4E#u-gV_f<ti[&,IDI'N9LdO%T9.L,Hc:Q?`fKd6S[&w'J0SX-VWGx'?*g-8*(1^#u+Sq.C3+A#1b`l`GgZipFr:)4mkAau67YY#vqfIqTL8a3EDou,,7G/FO>uH;YHt2(:-V8_m4Ki%5uV)d05rh$.>`K_@1ZY#=lec)E,W]+DGCG+]b(*<CO([eSK)/)(hrA+)Nt9.)3ot-&mH7/R60)37*es;7xmv$dk+qtdWkw*s-7kt^QOp.7@$@`JTx8BA^R/&_-]V$'E^f1TV+Z$11Qx%;GBP8Swxc3=7C[%BuPg3-%S(#<Io6#wQ0o/rKa)#([b6#Os<Z%cG^e*WYb<-DPco$lVf0)pDK]F:JoO9D>Vp/tc_c2jFd;-#dRa*3kZs7TQxlB=H'X-IL=>(rV#<AdNY?.VC:p72Lu&#';G##8^(*%0iHP/@'[i9m3x[o1vLF,3+U#Ipw`u7ctW(5;6rS_iT[Y#R)KM0l:BP8:DEl_bkBBHXT$12>RGLM$[8/N?dqZ$p_#ud@+*c<YA)-c,DD'#Lj9'#aPZ6#lT;i%bW95&IDI'NAoKnfuF-.2iNOgLV&]iL6wh3(L=g_':-(W.22&T&sx2C*S5'NVL<D+*b==p^+Vd>#VC&),H>uu#mW^20ql),)nBIP/>wC6sw/lG*FX1p/Hf(b*c&];.XYt&#8p8g&2tTd;J;#3`kun^$DQ-(bD@80)mgB^#qn75?=$^)=0?QdnJ``Y-S;;3iO,['v,tNt$3K6(#vkl><tNvi_%d<oA#]Y8/-cvXlMKm2(NaLw-),xe*bf)<-^:NQ=(?L#$[5mB0ns,)3Cs)1Wg-<j9UAUp.[Z=U$U@+lTfD8j(Pk'*=S@n(<QHA5SrH*20AJp7RAjc126x8kLk'/V8u,?r@WV>s.OI7X$nX8[[c>Z/(fYQC>-,?v$8+%xc$Cu`4k=Eq.$>05`;/N0t]Gv6#9[sa%`%CqD2jXp>*IF&#<GkP0&-<gLGI5T:5@%f3_t587G7o]4X<,j'<IR8%D`NV?+o1T/*h0iDk&l;HrP18IN%FY:1Ym.T+``m;BO]/1xhYxHZI=K4%NHO_Q>2BLbt1fd$Ah9Ml7LtL-h3:sR9hf:gCl;$Km1k'#+Oj'BoC;$g9&7VSv0r:k6IsLh4'@nMK9pWM/;3Y&>uu#;m&##W;#d;<*GJ(+w_%OH;tn/7:r$#dcv6#34M1&eQi8_wqJfLPo<mf7Md;-Gr7=+'gc&#([b6#r^HW?X.XX&`Gv6#s(B;-9Sx'.YY&FEU/=2_7NwqTXjdh2oqg_.)[CDNbHr(Ev.4Q'?P`_=<Gi/:+GYF[meU4;jTR>Ab-=S.,i.MN]O-)4)&q=@*CKiD6k*oeaukXu'b#W8Ln?(jKVFn:S)(3:I$R*=Gn=T%HbQ^?jb*j=-?gC/>?uu#aC]nLbo7G=nZ'^#hwEC&@<Xb+8SC;?KcbA#l,@:&5XSq`auf]-ldS@#=m>r#;f=.u8&_-k%5YY#pbM:mpQpE@ggZ`*ZdM@YwQ9/`(eh0,--a9Dkiec)4)Iv&@r7.2FH.%#([b6##F/HDX8w#8]5Z6#eJ*Z%]g2QN)v<mfiNOgL03DhL+SBnf4kuZ-<=@8%l&QJ(tNQISvEHO($D9o[9p(9/NH,uc43lB,_#h#$'nWCsTsA>GYa2#Shf_r$qe#:7mdZ`#cv%vLn2,]uaBQxLB/U&v5?g/+12FM.BK2A7R903:<A^l8rJmS@of@F#rMX]/4iNkDYF/2't:@,VQ1o_b<E[6qWLV*%J5$0)''d6#6d6u+GFIb*.b'30Yc`B#$t@X-4^m_bad$9.mwJ%X(OrYu_*^=YvpcxX.1[`<*T4?#Hts%=0ssCE$T]o.(+h^#rGYYuTKB[MH7-##+I?C#ImP4oA4YJCoMF]Fq,Md*mwE^FY?ti__r&eZ'.j;-d9ff$K9:=m5m4)6@6ie&U6qE#4-;hLOv+h:rFvV%>v<gLnH*7%N'R,*eW+T.c3rI3/)lo$xahY%jq.[#A#ET%Z#m,EO]V[%eeq>ZH+'?AD@D7=1k]?&`OUj9gIM0F8SSJ*oXDNCT%%B]U$l/O<u&@73QfhIxpB?7/2)Q2^i^V:TPJ51$U:lK[p@b@QMuO/?H:;$qC]nLr_f)At(-Z$(1&H;WOxT&(k`H_Y;nD_P,Qr%6Mb2_Gr_K_r3(4+5VSq).4f.c)LMC]j4X&+Bp]N9*o&*#-QP,2ac:/[F<@B(]jhm/t/oO(4>eC#[,*Z5altI#iRo:d$x2ulgCAA$c4>b#9gkm#O6;mLi?6##KV0w$lL7%#<BdR=q(m,*d#60`QGA^#dMc'&EQ7O+-;PV-82e4_/v8(Oe)tY-:7Sd*uK^]+I^sS&S+&a+R4A&,lv,a+TFx],k)H&,E7T;.f't=-_iRQ-^8XK&_nb0(jc)6/9CP##L^J'F_4k^,uq-x6N]kL):C/W-(pw$px5RS#&9;W/%)h*+ih1u@q2rnLGU]+8iXAx$IGpj2$Yrq8gE^,?RZoxIw5`/8nAUB#;m&##CU%d;^ffl.[E9H;78;jVxf2+&=2BW64>eC#jabVHEX9cM_b#V#qmbrH`jMl8$T]o.(@p)GRF-##<Z=U$aJ.^0n168`9rYY#<2DV?4HFKjUdm2(R(#T@awb59L)b`*Dra<HG5$Z$V,q8.ol68%sU9B#KHif(I])-*IC@b29D#%/PF7`,sq-x6;gSX-kO`S%YBnCs8@=JO;fYU&5s,o/:k+=$.GW`uL77]*t)1gcbqTW$P<xJ1(jaa#Yn03$0-m3#<Ud%F.$[S[QLrm'.s_6#&bN'S/^7?7?I,hLncd##;>cR]/G_mV&kMLC`8Z;%`olM(h,9Q8qA;/`CR[?TUi:;$?gQi$oC^TrZ4&Q/dujh24'lA#p/?T%;%;8.rdboIT'3?#j7LfuMr5xk*T@l%Emf10XCuk]aBKr?=o=Y,auo>$rRQ5.MWn$9%WrS&h'Fm/ZCa6#ecd6#X-LS-Dh+w$+?>F%m4'&+($U3Bo(Wr91?5,2Oqow7UJiXg`Gv6#V^nI-Os_]$Tg3bNFKWJ:FtV@kWr,J_&2-F%M.^u5vqn:?(ask],S29.`t7-#A(pf.[VJSPFYFjf/P-##?H:;$,V5+#ED#D(EtsT.BZc6#s-xUj&PO@(_PNw>otT#$66Huf67CP8O'mAQ=:G87P<W@kL3s-$T(mUQ$Jpk]=Xd%F%Q[VZDb^`*17S3Q6oA&Ej^7.`)j&C#WYiLp,-)mAQ:x4A:F&T.nk.j090,I><:bJ%J$'O9[@'?-En%v#r]g;-1#)-%CoWt(6OjHDU4#H31Jm++D@>U%sr$CFN5/^7XCm>@5x8S)9Z'*<3H;[Jd:*4;ZgTpDS.fX&K>T$@xB]Q<xD^S1[Nn`QN.?@R(:#[gV'MMD7iLfLSb-##S>uu#YW5+#'GS2`SB3L#M-pqB#e/G(t1H<-cXhl%Ug,T.Q=ZV-GjZY5bR&;manZ@k>+di^$(mUQuUX:#:RI[urKDl*..nH-J'A5)7r?##kCb.%6Xf5#BL7%#H5I=+6aqA8<:W78'W^auR_O/%8sx]?=2/s7lpG,*50A9&'h`H_N#G$GPPV8&3?kM(smaS+n#iT%'AQB97=$R0*)'b#Sr'+Gm`1P<8E,tNEK.G>$KiL#(44CM@puHj;D;8$0xV[?ls(rKYuQ>#O3md?L7nC<->UVK:a0&=46+XL/;[($$8=rZ/2k%g+cO]uhl0h$i1$##4jrU@^*5p/MMw70cUd%FdcTv#ks3T&2C>?%TX6##dcv6#./5##*Y5<->DGO-a%u'%/t#O_9-Zl$vwu/&4Z_-;<]Pb#Q=`*%8sx]?P%N&+GYEu6<twUHH??YYBqaku)QB>$WNP/$v-Tiu),>>#$rM]=ZqeE+T9^6#&^Z6#=fER:x'^fL$2CfD=d7p&wa6mJ#<L'#]=BA+(k`H_BcTq'4RH5(Y'JoA*Q2<%-:pK29nC$`tUU&9Zh?lLuldJ(u)ZM;G1UcP8`;8.U0HO:akYgLsYPu+n_>@5-'=H#X)@HBC9d8/hQwkt$/kr$M0VC$&g1$#/,'ptjce`*UiSj0G`w&$V$wu#;6rS_^il;-X-US-;[V=-dv]L:kb8&A]wA<(;$#L:$9$O_&2>>#,3xr$_;=8%J&lk:Ph-L*8X+rL(NjiMb.T:-#>?W-<mvEe/_75%-VR2.^DbD8Oq9/`awsH?sb`8.-`($#M7e;-juDf%_L)68csuY'8mPM*Xxb5++i'Yt#_%Q-xbF[&Y&8gL#Li'#B^c)M+Ha$#cV6g>qx(d*V`m8.WCa6#G=nj((k`H_T521+h)T%#:=]6#S(IH+7J%*&&O7eticv6#)),##dk.j0eS1%cVG?k(IC@b2Rn@X-P8Q$GbnB#$AIHa3x?7f3c0af:H#aS7jE<nFTb8rU.sE`0j&BlBtJG1k+QKlCMeIDQLWi`3gUEi16n==ASR2e$m:PwLu^?##N'+&#,@2/(Oh1[%MQR.ML[bA#1;KFaRhMqiWb;qig]C0_oEs#798$:(c-'L:X2o&,''d6#4w]f$<8TRfSVI&,4m#X$MHf;-o>vXOh4i>$oIb]uCQm*Nal$A4vA8OtRr-<$T*p8OKx3&+9)1<-?S7Q-XZ@Q-.Y-.1Fe[%#e;BA+h9=8%8/`D+Q)iBI]3<$#([b6#1qll$h`[?pd@`BSF@,7*0@$:r^#Fb*b2C<-q:*08Dx(d*YZ)B#qNf9?s6G#[NrIm-hbF/dYAFC#PDiLp$k(mAkY^uGud/;I3.=2_xS_kbr_YY,n52s'Bx[.2k*1wpYC.EEqR9/`[V*hYU`:;$*778.LXns-]4FGM-a.iLY##L:Ee^8iBKx(<B/0Z-Xqx*dT,=v6K([1'YnnA#P&.G?eY<W/Ao0J#v[jZ6ke6,G/vgN&b0cVE7]a:;9ewIJa]7n<?:%@#Z2X%.o,ofa_K5&-Xw?`QVId[R(IPwgMF,PCe4&##=Xd%Frc%QAQ??A+5vSrQ6'T02aGr-$/wb.+j7Oa*QP.<-'Maj$iv8o8.>)-*(k`H_D.&W]hLm8(Q?:WHPgg)Pj^j$#GKb&#dcv6#0Y5<-=m8_%Z8'6(P[d##ip'W-Yfi:q(t@X-^J/<&^qJk7fVZ?$rQB9O&m;kuv%A)Xtit$^a>s7Pc[YId_Gqd-,7<D5XdE5KTkqA]DiHa$`?9LXcCQ[R5-ithK+ei]H:dH?XG68L#O16#U0=G2,i$W$7aF'Sb:xCW((*/2`nRfL&bdc*[&cs-?1e8@w1uJawwSfL?8bmff<4gL1w(hL>SV-2D6i$#O<1K(-T%I6E^Na*CZ#68u?qeVi'Sa+''d6#GL,l$I,>>#H#[`*]F#9.psqFr3%V5'AM2W-c;lY'USXK3,ulV-3>%&4vcMD3#01^#-:2t7^Y[.2mZWaK,HLR#w_T*7Hs'I#M<vr#Ys'K*'Aiv-mu07fP&brQfRjG?EobbtJ/&V14'pI$5a7%#FSpF_+gSKuk19fF/G^X@WE^9VLk`H_ja-4E<j@iLD>+jLf0=>f.fG<-n6Pw$NfD_&NfD_&>q%F.V(E_&)><YJgpT9VD$v1%K5U,+<nw;-LKM`$sJj&-1t)d*<g(<-qU>P(Jpd_bEI=2_J>wTMnGwTM?v,F%S]2<+]$3=-csbB,_1x8@X-gcVwm9E*WO%W$&LX[7X<&M3p4S60DA?01E<PAR?])BY$7G>#(O*s8m7q++a#1R/8sr.E5#$A+xjT/1f(Lp./(no%,uw6#,,2m&m0M4Br9`j;3Zo$&@.Za*$%js-MdQ)E[`Zp.Cj2,)Y'cJ(616g)t_tU#J`.:dTa[xtN9GA4nj>fLWT&d;4`r'Q$/;'#k%;;-CFDp78h*B,uW>>,fr9l%%%*_ONimc*]q.<-daA:HUbm##8`h;-2:2=-j8+O%6l1%cVo:%Ge7OVh+X;W-%W1#$KG>c4xhDE<8=Z]'_lRE)jmIe<=(*?##<6G$gEWl2UPM@#>1aYCC$_K1wY0#6X);179IhD=8G[?TuDiLp]$OI`&m<v?QUEX*U5K-#0ga6+JTWH-3r]T]$VZuu&7YY#@3fmK'h&2+>$VX/<^hnuU,xh$5W?N[jNs=-dHj'#>mt6%GW5+#s2h'#]`uj$G=m>^0Dw[$)CRS.(k`H_61'q^t(;'#oo`gO<vnIM+>tdZdT?;3J90p%kcIG)S1_&+r=p>-w%Q=*#0gs-.?fPBGM<j1taBVgnQ'D&.xPr#r;;VB/g790f.a-;HeZ$$Vh$ouJ&hX/SB^%#]YZ20X:)d;NlOV-YncR1[<N$#dcv6#CHsS&D]@a+>av%++23t-:P5'=7]rS&l3o;-+5Ht$jsF&@RTd2(:ek6/43pL_3g(;?-2&cPa,uE<taKis`$Mn;;xfFGOF-##'[b6#GN$@H6UL[%ELD8.CIYP;h:Kw%oQR5`dI=l0Sru7.UKW@kg>2T%-+*9UwsDGFwUfu#ScU:m['7)4f7mYu0O5bu$J<hucJAmMU2o'AU####TD-(#7207+CMoR-(=3/%8)a+316'*FG^bVHQXvu#[SAl.Owjp.53pL_q<pRJ30(toR=CB%cvdh2&*SX-6jM@c5;_^#`txU#;w#^[KsZip0cG_jft*X-fj9A735rD3ij=G2=&^8pn)w7A2?i50Huw4ACd.T&soi_bEbT:@wN=x>4q$23#S+@(EG[m2]5Z6#@4WRq`'e##Msdo@]rB'#/Xu8J9-q2<mhx9CKS6MTcj0=->_)3,uS_t-qbf`*G4;%5$),##xLVS$,V5+#b7?8`,JYY#+S:;$T1lv%;vg;-w-_nAn@d:Td).2(Hf^6A]CweMk'W<%'h`H_,*N^2u8F0&/UJ[#[AAtu(Y'B#I6oD==-`)-&X+,/:@hcDgQlNXcqmMa'HG,2KOa5/YCa6#;P5$MA*^fLN;+p@tO;s%L.F1+[74B=kHF&#be;m8fgQC#<d#V#$+%w#%RcJ$8%+]uXP$63F8'##'NQDWFsZ`*4ALlS-A<jLBUAPB,%FB,;6rS_L/[`*q(&<-p>kJ-p>kJ-=AOb*/Y6b*`8hp.33pL_NnpU@o`6M3sCF$%N^o;-JWmL%u#D5'm1'&+FZcD+vU'^#,D2T.#vjh2Hr*3N4j()3e:Xe)Crq;$U%vv&Qmxt#7+s@$)ng^#]C24unsb_N)-gf1_LmC%.xAS&Q+N[$29Smus5Glu9-.b$4s<A#'eDs%&iQ[5w5i?>53#3)NcJ1(Kg[%#'[b6#0Y5<-h.cp7iU^oork%^&;kJ-8s&J1CLtx2)SqO%v1g-k$mh1$#*vv(#]U8>5[eq`$B#?]#a+[w'Tv],M_8d6#%C]<-9o0%%smJs-ZeJb*3V%=-7>[s(j+>5(KCNq7>P-TKt(E+&BZ&6Acad)Gqlm6#A;G##,r+@5S;F&#c@=gL]5Z6#Rg3f-<c7HOeI):8,=$Z$(.n&+pUAY-i3m;J3bkAD4).fM0>Y,O[[dER@rJfL5OhP8twi<%ul:$#^Kb&#@X4]:@as9'WkQ##64i$#dcv6#IY5<-M:bJ%K;>>#gX7b%0'+Q8piSrKYnLq73hgv-''d6#'8Po$qO?>#'qX-?^T95&ot7W-8s7o8CKb2_r.oD_oJk-$_,M4DB8xiLNcbjLFk2pf<g9^d7WrphF.=F3-,0J3h]LY$GTh>$dn]k&xvb[WUEdquWwqAdrlNx+1<8B+$5e)3';G##Ovmo%l_b&#FXI%#1_R*+*2'<-.?0W$rk9u?t;I21>[as-/9D39`k[v7;?j)+cPFq7@U]NM>7,s6RDBA+<TZ`*Am/iLTDHofC]4T8Q$+2_5/6O&8#iR/>*fI*uN?u%[#b>&;AnO0fSWCs5S>pRgv#%+Jj0q7+:7#6</E:)P;G##Y)Un%1M3jLCb`'#CY/E#JFho7p,mi'`:/s7u:'Q>5qtj*?I(5s>t?B(G_&_&;5GB?IBM2MLUf;8FIE/2:H>c%2JDu4-N(,2DHo,3q3'&+YAu`4^YCa4CJsx4ZJ:&5E7T;.xh7P&mEu9)0g=r7l,gG3ZpuI+cDQ5hT(h=uX+EZ-:+G&m^KV$/S@G&8c[<`#)8?ulv>QDWSVW]+j,$7#?/5##qEFc%@XvQU<v+%&dV?K:'>39BV'Bv$Gp'3(''d6#J;P@&x*E<-SjTUBBKihL)Ng%#%7lh2#^UD3'K+P(Bv<niD8xiL&5.Z$e?s+3OFOlZXJw+uZNQ_#)+R=dnq$_uu>Hnt%$###HFhfuGZ-$=sE[m0Fo%7#8i1W-0-N)+%6(@-_bYh%#6gNk0Wr</R8T7(M?4d*Xs<30@),##ek.j0xF2;98U13(4g]j-FD=81/q&=[Pn4[$ZUCFla0?uYg%P&+YE7'+C?=X-3a#<8S_vu#l1O%O<kAW8&AD'#_fNP/K+-5/d8$-Q]5Z6#$p.SunvJ%#:=]6#2Z_d%37so_'/=.3ZG1T.$>05`^h;(,WU3eH_K=p7M&M#$9sVC,I6`G#eI=18N`eC#YR[%#HO-,vkvki$1N7%#bp5sEbb[A,Q%aD+PnJcEM@*9BIrI.2exED*9'2<?d'NaG.765()U]T.$2+8_Yg^)&4.m5((JD0_cdlh87w-C#F;DD34*x9._)ct$KB,=(>&d3u&F7?#EWd4AeGnR*K3%)$+fw)$eYpX86=d;%[;t$%X:i@kRL::8o>eM1N'iP0G(m[?@dU1L6OWfknxR?()J?Q8JFNC$+v_)&Lh*88eu7WACe-Q8(7]Y-ruHgEk(^1,-Vx]$3e$^&N>uu#doN%OEar>I8htD#,x4;6Y2,<-b4tm-V+7O0KeE0_3-7a$0t/200`/;6neIV8lG4l9t.Q&mb%$E(?dPq7),q,3''d6#Vwr>&&dCm8UCo21$DW]4X/c;-,V,<-5@Y0._]>lLA(?J.+c5g)XFED)89$#8ho8DtuZLi:Sf?7,Eo>`+t8[_#)8?ul9:ODW?dv%+3EJ$MSR6##Rk.j0QuD&+7oP<-?nnq.Pf_0(g;l8hpi(8I(]C?%?S?t$iLe6)l=.^Fq3FM_4:2q'VNAX-6:L](D4jf1G)2$.TnODW/pTH+F6&?Mx)&S%n5>##5f1$#3dupOPgcgLhLXJMfSrhL8?VhL4)>$M(G$##-r+@5g6+gLWwCHMXkm##&FqhL9Z/c$E;q;Q)i7.2cfec)Us^g:U6fp_URQ##auGd.aPZ6#Ow0G&/QnD_#YeW(l2eh2DctM(Y,lA#,vDs%cKpn/T-2W#xs.9$UW5W-Ytfv.tP)K($<Q7et4f`tIAoH+cG0O09;+eu4`A*%1x9hL*2^%#iK6@`/rTE>7?VhL[wv##c]m6#u2l%Tx:S>%rMif(XfW]+:DEl_09e--01(lKrDp_O=p%?RtGNV&ap4l9Z$cZe-VA1(nX]nfr/LhLkaH7A#Q'Z-*g*_$ro'W-7q$&O+COoTT:6:vh3iZuoDWJM9Qdeq-]m<-MOw>%KKsk]';G##atS.$j(7&%[rJV6n9'7#MRov$:]8>5Y#'02a^93_.%^Q_,@,gLp+fo@&`l9'uV+I->7V?^S:-+>#M%(#&umD%V_9U)U5`3_4I-d*3T4KCi1B6_AS1&&./j>>%A0?-''d6#[(A@[GW*#&e,QM'Nb&9.cZc6#&j4U'fe<wTwoW6N0H,F%UZcBeu$_b*@E'X-7bLx5_FUJD^lZX-SDMji()F&+vSC:.4g8lYSN*%,;b3SRZeJPo+%X]4k@L$MQR6##Rk.j07dIk9bqG,*IO5s.C%:j_&*FM0lunl$/CMsJ$Mr'#eW8[JF4D&P@6q&$Q7ho.Cf=2_g['J)S%qDlPF4/2lbYY,g-%3B%Vdv$WH9D3'_2m0M6`i%ftgq^0/A'.$3*jLandh2_j4f*lVj2KXNgv-o=7`,6JVD&Kh_+4ULD8.rM[L(:=pW_>Y7?MjWVf<wa#-?t<R^]H)B*-ls5^GSto<:5[Ue,='5LD+tFY@<PRc4N:B`60j#T'&MUVA?^u;T/LGT%2'@dD>>JXp[[X69QZ&2FFHP6Wa^&##WE&d;^sP]42Q6x'W9qt%E.i68?0W0tfqGI#'xlR$vR46#oG<#vdcsL#Q+d%.1rLC?V'4m'oo1d+h9=Y-.db[lXbN9B^7cVJC+]R&FfgWhdx###K1,Ka*f7(#CY(,2p`#Q8X`Js7]FFgLN+fo@&qWQ8'B2d*O<Ql$QV-F%Q'c&DmJK/)UHr*'1[a39%BtdXMfDI(noYb+^pXe<DusY-Bb%Q8#H`D+q[wJ::9pV.u*:W.9Fl+M:3CkLOQAqfB>qP81Y^;.5o$(%MhZM9L-XX-X.:iCp#+HXY9Z:Z_Lo+)T/5##CG:;$)Vd;#C'+&#,>pf$fPL`d8*hrItCZ;%+0e>$aZ,a+X(Em&J,I?GLQM=Kw$`6(>mUN01),##gk.j0.9D39S5=2_HxnTCT'Tr%?E_3_vjDe-sUH*R><6Q:/6+72Y?WJ:$S:%kI['90H9PSnTv&#Gj8@I2/^@)vvM,3%=?$(#CJa)#;q/k$t?X<U=_^t(I>uu#oeOj$0Oe2&ww#OE7KihLkn@R9I65F%S`O&`swpu,e1Sh(jf::s/l.(#;Cf6#C$%Grwx$Q/l;w&$a&Q]4Exb2_AYC0_%Sp?9KD-F%-63]5['%ha%/L+E#Sa=(^(A=(>rS,&a_k[$jJ7&4'a[D*$v&X^ccf+4QG@['(@9j1v$1F*lYWI)OgHd)c[NT/uBI>#v4oL(9T:;?u>C[9gelV-FEu-ER8.WJ<.TrD63ba#*B.#,,RFHEdYn8K2XIaC^'AIuF8s;0?8_(OX@U,F)&898(Ym>#eMQWewHh5F.ZXOOrX5(Re&^/3*rGxO%%[uW'V_x8t8r`*0W:[ut6od#d`gP)F92#,7.%##B1U+vfxZk$O:q'#$O(,2h9=8%h3xr$l+JpIrkTj(^2xr$#,m;-YF$?&]:2E%RmXb+EB%%#c9(4fVeZ##aPZ6#]81@-dko;%BDRq1n1Jd)WIo$$xH:a#Ot.HD.#;Z>9=F]-.93Q8nxNoq1J,)71/6@Cp4qPF[XYIqD.l)>CEs6;)WQnC^mmt(TofY,YY9=9a^*@)EVBRGA&(&BatcE'`5Mo<8rvb+#=A6<(#vP2`3i+MK6*$#Q8HZ$3ZI%#5eFo$ogCnWNL`QjZK9-mWHK-mQi#T&Mi#T&cm*3B6Kjp'jGv6#_1:l%&v.cP[;Z6#F@V?Mk$bH_[0P'ADsNXC@KL,;bIK/)Sr2-*%-'u.j$*iM&ueC#x^&.$RmwiL92?,2;x&fq$'veq</MG#cb$w%Wmei9lgW@Md(8Eh#.OOXf5P.U8#Yr$NN_0GhM=.#P7Tm$uXH(#-JRS.ujRq$5O@##8$'k0<Io6#<4i$#Nr+@5WJ?&F)?ti_%F>r)arkM1C-468[gT/`:o>>#f1+_$R@mPjoAa6.QlRfLhsugL'`XjLPaYgLO7--Nb/U&$/]NT/EUjU8Kk1I37ZRD*7RM8.uiWI)avtgl<@=T%G?%stogLl<U;>YurE%V.Sf@^MTQ@5;<m%0<pQc@TEJMfUu0rY#)'?Z.^;'N&aEQ(7?V'Rfwl(<AY38Y%:E?moVN'U%1OkRBPEj?,qJOK=[.>gLxwO1#+XXi$Ig'S-L6a_*9x8&v^Fa2i%gVU6qGv6#k`ji%'K9<-oE80'-BkSpbAm/(/90W-q*EX(R2#3)O?Z)494;3tShFj)^,vu>8sVtVSnP7[$4A7nMor&_w3I)3Mw>#qAEPfLO:L&vWDfp$Tf0'#.4$I%3e;)HU3k(&:J*=(sMS32Ao5b;c1L'#S+lr-82e4_&awSDeAm6#O38>-T&F#&cK_c)p/9S%X055r>vRiL/Agf1p:Rv$lFU?^-otgLqDh-%n];a#exF)4fHuD#S,m]#NQ@Q.+XEhFUo*5AF21[-@-q]HRwiT1Lq4]-inw[bke?>-GrJ]5H<,=$N/ZnAM>Kpuh[hx)Q>SF*F$SI4vGF-fY;53'X3n0#gYo.C=YZ`a?uXY,iwa6#*^Z6#65T;-M_(I&K,P3)+_uGMbMd6#-$%GriNOgL+C6c*iO/<-wm(=/Cr+@5q)$*N]5Z6#v0^Z.hOs6#K-/>-L-/>-Oq.>-u*^j'-v67/515##[X'HM+rq`N0w$aNX6:pMm6:pMP[FoMNIf7M,JWmGZFv;%GL.lL($AX-62M:%=,6O(vu.&4hhi?#g1b]+*7pr-m@E*M'8?4M%j'#,1a9%tKm9B>P31#M&=p+MPE'oF,3I20WR0_>l:gilmG:nNVeW'5-o-W$)XWS%q`W.h&:/W-5V-F%ffIWHm9O+dSXH##:=]6#Gvs'%6QK/)rbQ,DiNV8&aFr;-5de&+P%Na<mm'</t0%2&WbD>#a-'9.VZc6#nVc;-5CIQ/'tqFr#FlofX%v;-:AAF-dX(H-SlI.%,pE-Z'EC_&H_Lk+8#D_&cUFk4iqbk4S_Bv-,8.GZ*SrB#J_G)42C71MpnKb*-Cg,20%eX-YGBuZ7(%:M[(7H^B9t87&Dx$]^HL3MEc&Y#lfnmIms4/up4x$`OD[i^H+E]CEke#9nV)###tfx=01poeve8>5h''7#Y/5##ik.j0SGc;-j,OJ-j,OJ-1F%m%5O@##IvBW.:=]6#/%FSVlurs?r[Jm_Ow'02tT35/A6=<-M1v<->+(RAjS9/`eItQN<`M*IbYc;-b-rH-G^R/&PSuu#@j%n$vrOV-s<'5:7:kM(E]$a4^vO/)C%tY-t[-2&xbDM0WL>2_1t1O+`Kv`QOgSqfMpKYGmf`h)x,Tv-HQ><.<-w)4GU@lLH@Ji$J2rh1G#GQ'ch5g)Eo80%-Dlf:N<O0-(_Vn'/F^]Q1u#f-)t_>#Cj^N-Ot+7R2s*M2QVdh4p/v+?VU7@uALlY#Mm,Sn0?Q;$2iHo%`%7na5BIT/^35hU-Q1@9:CRW$QXqs-UmAmUN^97/VCOfL-J@'vC'7s$6@%%#:vv(#A7mi'B/8>,d#60`6rd'&MVd'&'n/20H+m&+Q8<dMxMQI%i)J21=3+d3qJfM1ST3N1=j$)3TQ*j1VN760$DW]4JGI'NunAfjk@<A4YZp%4+gI&#3pPs-8r/kL?uO(..5*jL.XPgL'am6#P_R%#*r+@5I%Gt7dN/UD%QO^2MHtb+4_W<-rOTE[gX:p$M6nO(R25L#fEPF38t@X-:H7g)dB)]?AW9W7>pX@??Q0W7UT;w$$=cxAcH;Z7$4>043+FK**4]P#3cK.VUDdVupXNL#:W)?@-Af>8ND?F%W;,?6=K^TKTWb'[*a<l0Ak92'h]kTVR4nRnBp?$^52(##:EUDWLo%8@N`RwG-A_>$AbS<-KsIj%``>>#;fec)nn*)**[7p&f.m;-+M#<-6,5o..b#&4MvAV-tp]q$X7Ba<7ki[,rB6g)]IR8%g2@ou/Cooo,+vQ11]:?#0QaZ6BNsbrgZV(E=e*?#2O.P%RjuR<X9/rK(BDW/oF[51m*H*'0ITk_%o&H5+/5##i*MP-lkaf/5f1$#1C=8%KZ<X(uH`wgrn=b<hS9/`']0wg3W9<-9sqh.KZc6#4c8u%RotM(:H7g)TH3]F<VPxFb1;&=29QBi@dQSeUGQfLLR?##HPUV$&xhH-ONE'/Z4=>`3<$XL94j;-ks9-%-UV8&;ts;-'%nOa<Sr-2`Jif(-)Z=-Y)g&C]eY_H,4pfLG&8f$$2Dn<MZ3t&1'2hL6'2hL].W?>=.=2_tL^.=[5Z6#gBO,%)ABpT=vnIM&3Z6#G?1T%-:ki0JsRF4LJ]L(X_Y)4f7K,38,aF3mQJw#.QT%kedl3Kk%gpFTlwC<jct.Q`'JNWs=0tHweJ7L/GA:$+t(Hu9c1Ed84vf:gkOh6ARnS_%85D7'G:;$^*Tj0ld0'#5s)D#KBW]4kq5p/U5u`49n<4p4XcB]>TZHd,L;s%C35X-?tOXpX5Z6#k7[A-lqkR-49pg1&Ps6#G),##?r+@5T?fd<U`6L,'KB->O1CkLVNq02E-reNc*A>-rA,)%=g.v%I)XB(Gk2X?rxZ9K]wR'&KdF<-jN7j%Rfd'&):<;$U5HX$xqIs-YZ+I<Dm'^#oO)<-11ip.usqFrcf*<o59MhL'IjFM/bG[$X']V$gTs;-)mTL&(HC_&MDO&`N*SS%L>Rh(uT95&7vR8/&uM/)VFe5/,vjh2PeIk96[VH*ORd,*Ynn8%JBr>5/P7C#/X^`3Qt6g)/CI>#9=F]-lUTqu^;s0#$Hwo7tWt1=:7),$uKY1OJH]ASdX*8RcU-eb;'sY#%@If_%)G:vT%A]uFix$Ng_tx=#x;9;FHjS&klGU;3(-`#b>Y`u/UO2(^uI[uWvVSK$),##<PUV$L`D4#+ukn*Sv4<--_&m*UJFO%H@[/:P:Cw.iJ:b<cL4wR:+,s6?C=8%@^Ts-eb)6JPxacmhGQ/(i:/nfSO;8.Q4n5/4CZV-2mwiL[Y6C##R$c=4Td<VPP*G#g#Tau`UNhuIZVkuU%tLu8kI#gf_6oRDhH1^`&'?u75n0#h>SY,1K:v6K5J#$JnDT&IOdY#ds.b'Uoa#om$f:(,L=m&G2+8_WL2]&;An*P;ZjE.dx1m9ta9N_;r>>#'[D>#PGl;-ZJ[Y%5><X(jY(:8MNV8&h)8R3.B,F%>rA:)?uA:)2N,F%1-%Uh`xLM:E)dG*H9o;-p+:1MhmIv9.iG<-mo-A-Z-;.M_O6ofd5DD3^>2,)RgwiLn*M8.V5c)4JbM1)%fT#$Vus9)-relJd:<Zu333t0.ccQBg$*;Du:ukFCRL+P;wvGP&jgdGai)9$&M.@uxx)`uHEeM0x7fuYrR`GuUtHQMBbk$Uw&&##HRq/#`<2o$xkd(#e_ea$W-T<px+2'#:=]6#T<>O->VdL-5LbU%-<K<-vU3B-<#6:8(<vV%m<H+<U2Qqp9QR*N/7nQ8gZrS&F2l;-*M#<->x$6%p7o]4t*5j1i6tG<4EdF#=j-^4NdHd)H-XIU@Ebh3paMW#ii[l'b/9T%srBt6ZIBquW9HV%wCoCNmH+fs;[EK1?0=FXf$%EX6@=G<<Vv[-`kx,<b$@@IN;###<R@%#Yw<<8[rN#-ojq8TVnP@(>We$?KaT/`(8>>#(8dX$7jc'&P0k%=D3F2_wLZ&M1)`3_Lq2QLTF-##'[b6#/KxOt+L>gLBecgLF4pfL0qugLc$ct?cVbA#onF.>cRwA-RPl)%#PqC%f_aD+3+Fj0vOs6#J`($#>r+@5G8V/10Je;%nnlV-mDsI3[lL5/Hr<F3JZrhL$9&2)clnfj@%E^2sWFC#aG/'Ff<<m<)^Ldo0ZP[f)-WLMg@hLgZ1NV?&^$$Ua<;O#YvIvU$4;rQ6wd_um$###v^l'vtNeW$[;F&#*VFB_s=ZKlfk4F&8nI*-];d6#)hi@%&o?>#+(ai9Zu^>$(#6W-LtxFGi+^4(H,l;-0)%^7$Gr'#exHs-qvdiLbYn^$BAFl;7uAgLc@VcDvQ[A,2B/j1_Fr;-PfG<-H;I*&.*Q]40W=K2rT<v6:YT=u=/Hc%r3s8%LgfX-w[R_#OM>c4'M3]-i9j?#m&l]#KG>c4P3k`<A@D&6J=qn1MB1>.ip7T$m;npFl;_w9&<Hqt:%w=J?xWn1TY-,`JC'0<d^JM3i;Z?#rg'LNQ@XY)S^S#6N^5o/i_>DQTo;rA+0k'>09X1u_TJmM,2,B.b$>^'d&>Z6ZYoO;Ub=k3s4pr-*XM78glRa+hoZ6#_fRQ-#5T;-UK*$)^T95&_PrZ@h%4a*o&d)<2X&:)9pnD_B[`2MW]LI;gFe6M].(5%Lucp7#%96(L.f.2h=BA+d)c8.3),##K+@Q8]f7p&p3t)<SSbA#N6S2(C>(<-j:m)%[6xr$mCdm'82e4_OY_@-HW4?-T_I+%/^C_&b`ABH1iG<-;3=n%kuED*.)9R3:[eQ8dvBB#l^A@#0q3L#n;oO(F*nO(L8i/:8t@X-pKsHHdrrMKPWdg[N(DN#%eh4u2pl@O.S8;6V,`Y5$:^Y5m%&,MD31Ju$2[Ku+6sLK&5>##$0Xa$%&e(#kd0'#]3_ZH[3E$#;PG$M^B6##%EYc%P`d'&Z9=8%Gh()6-lu8.V;w&$lQ:Z-]`?mM3h:^>#b1p/fB<oAqaQZ$''d6#YU`A&]=Ip.$>05`t-Z81Xjdh2J)UHmfkY)45k,&4S.tD#p(s/1(*AX-j_^F*D]G>#+*(V%PtKi:*cF;USx*>:ShcpPV60DKpFbOo]v%e#^AqPMNSMK#fJRd$<Owkk_K^&OEdd4apwTqWYLo6G;H0b%Cc2xCNgGZuJMJ>s-K-5-nw7lu%AeVW&>uu#'ep4AE(oA4<*GJ(=SDD3Jn/q@Nrgj_A7ku5`Z93_/d`HkaJm6#VvK'#Yxg^%VV>>#JXLk4Bfti_.-71,w*VV-PXP8/8NOQ':DEl_EBU:)Z43(&FG+P0_ts/2''d6#+u*C&v>g58w-#d3ru#d3/kI-FNn]v$gp8o8QJ(lKSGq#$t1]6#F61-%[']V$DQ-58Fk9wg><u(3'p#N()uls-%gHiLo^an8p4Z;%>DbEnUHI1,<@h0,hmi0,M/w%4V<SC#xq65/+0qi'Js$d)js'Y$tB:a#H^(PM-@=I%veNT/1W07/KJ=l(ik'E#58^F*P8&d)&$h^#hobG#AVK[%4?1>;AF$R0[6(R#BLGr9(Rme@F>)11I2dP;Er+gO(QoQ#Dfo,W%k.S1E';s$;*vl1ZYA.&^'Gx>.;7G>m4Vm$Af#^tPxG>#/MNX-'jwlBa1#`U`6-1I-F7H$OUl@OQ;P>#%/5##Y/Xa$A&e(#s2h'#e@78.ro]^-QvE%,lFMK*L8,U.U:SC#(Vg58Mb&NKjl[u.oYRD*J7rV$E5sFP/<e3P:U,i<r]'VV9h6M>nGGC)@(#XKRB?=/`fws8SDEB#Ua3WN2:$XLis(S#&XxO#sCM>'nH%t?9%RRDC2W.1f*'9qVG@3=qjW*(E;n4#wj((v#b*X$q'*)#+_SY58<GJ1kNto%G,M*M@3jl%'hjl/R]u;-]KN^%Irq2@uE;s%si'g2Wm&g2Ccq29[gn;S_16%&9Dh;-vnG'](%5M('&[6#0W?Y8^Jm6#?.`$#Aiti_&M2(&n:BA+[$U;.MdFs-&93jL*Cm6#w,uv-rp2a*pcp;?DE'N(VJCZ@Y]p88jC(lKhT2h)oYRD*Z_OF3RV]q)OI&N'($S],O4(;:^=sfWddN1g_`.Vhn`4L@hZZl9oioWI=+0O2=?utoFsAw616_R/Pd-4$Pp08I=B(v#UE1c)k^1S#80PP#+:#i+L0:0(Sq`QL>TH;T`j$]#-*%q8'xIs$(CEJ1sN>+#;_*X$3ZI%#m96I$=?Gp.Aa+/(8`n`$YMcL:_65F%B5OH=b7hD(D3Xb+2%####5ko_Y)Gb%uMRh(26am$,.$Z$:U?v$7242_iq@k=xx7^$^YP2(duL/)>agJ)[p&K22M8[>bQl)46otM(AJc4%*63:evX'^utZLnualu0#V83p@ZWC#MPQ?YYLSY=lAX)$]$i0^uA6YY#M#p(<-g`W%jqV(aT1a&+4R)<-E:.6/ok.j0t)ChL79MhLcMm6#fEX&#qnfd9.kPW.<T(,2X,nZ]']7(#q5M/Y[5Z6#sVY9UKf_&&9Yk3(];Yb+Cctl9m=Rm0'Auu#>u^;%^#bJ2Muk[%pE)?<'32H*%-VV-oFl?Kt[`i0TmQ)3nGUv-Xp^q%klWI35Hrc)DZR*N:X1N(NF:a4I6A$&3IQ1)Qrli9@8Xj;ENVrZ(oTp7Op_)t5m[m:fEZ#WbgKn%8#*j;6'M2+ifmq<+>>g=9Df:?/5dP&6xvSLmvXu#E9<uA+%DG##,99TP_=a0pZ7;@[127U.&w4A&5GYu2TLJ('w?]OkHFgL349NKC+)d*a6/<-vaM^%E>d'&fGif(o`G68.:aVT9mu,2,N;b@>k[a*#i%68=>.p(Z)HO*^F^]+IC@b24>0N(^?ti0jn0N(A,m]#[sUO'%CuM(xND.3TX)P(^TX.[5g]n;#Q#>cVrvp1T[Y<@HZIc2o)jtA'kuQ#AH=X;&4F_t/`C=25g'Iu70ZwCpm_Ru8)IoBFc$0#$uTB#hE%##a*B>c>#U;@=9;X-;^5emAxu.:x6O2(5EkM(mh_8&Unr;-t`-.%2N,F%kB3KC7W,BZ]mdh2h4g6AL6dg)EoEb3s'M<hmmj?#+(^auI)K<_cBKV_:,M=uxAH9HCPuhO&s0:(4=Y-D8aVLu3OpjaoLPF`S-inf>`774<JO*vlas1%`GY##;xL$#olvC#wn.C&mxgo.(rgi_JZ<<%cv50`:NoW_<;q9pY'w##>sdo@d$ffLh2_h$/0$o&W4-T&bQSZ$.B,F%J4)qi1K,F%0ANNN57)=-bKf>-IY#<-p&Y?-KM#<-8(h$/s6EF(hwpC4t$wU7+xI$7FSX/Mwf5T8Oa7p&EBs^%1d?*&EDSs9*TY,2$-k;-A4YG-(5T;->Smh-hiMfOL:8.2=sbv6_T^:/,%w9.,ImO(0sZ['7-1#$]q.[#27E:.Vn@X-)`OF3N+#,Ma$<D%c=UJG%-:iP[nIA+9/i)?dJ#H?*3gW_J9uhu]d(6PhZG1H/R+tAYflDETKBC%%a-DWA`')E)1-YP*'@L<mt#A465,^I#QLTEtv0f$vr^83>`3G5uaRY%%5YY#Wa]=l)/.#c^hHP/fm^6#[auO-xo4U_t,^%#:=]6#]u<N.)$%Gr;Yh;-nN1=%MPCs-i-<t*jro#>S&NmL^;d6#lFCp$+BPb%&DY8&:N$^,:q2W%-DBqDY_k[$kZ&,;@RcH31'mf(]?^M'VK1>]bb[iTnm`p<n$:[Nms%6=m'LwN8`b</8R>_79l0X/9ik,2s^:S#F^(Q##<@RD*.oP[+>^VcG;.3MC0[5a[$cmLB<*QaBP@>#'0&##tLWDW::)1&JG:;$-:qo-mpVp`/TG,2Qw@;$[Hea*8&77/515##sUG29t(J>.[1YV-&3.Pfe;gM#p*_^u5/0iu8u(v#S,MfLF:-##68-=0lwh7#Ak8>_h#l8V?t8FIo%n;%b'*$#*ht6#f%@A-1s%'.>F8MBYbat(&[NP/`%9c$B-X&&Fc$N9s(hB%8%,s6^./R<UTtVfH4jM';p8x?tTMh)NCI8%p<6g)dOpr6oSqH%?iHA#s0v1<_D%gG3SIU0fgH`uMPnkte3u`4#Oot-r.:+46jv]uhx7*D%tM?7v#Av8e6i+6r%8/q4fi^4,HE</;I8`,aK&23,PO?gMF3D<dqYS['1pu5)m$7#tf*_$nHq&$2uqr$:-V8_GlC0_IBE6jO,@k_E0u9)1#Sh(LAW]4oKo>-#k0W.VSk&#jtk];9+#c,[3C02wp/20W6+T.%),##uTWv)unuu,6=cA#R+Y50r@(h3_ddh2#6M</PQi8Ilxr=cD@Q`6dm#245/s#$aw`D<V#;/G.MRq0u0r,=4d0(>.4?BJ)MN`$/Wa>Pxobv8XMtA]tM%)4^(52EJC6423VGD7Pls.?jF/)6sGvA4Orw9B^3)Z7SZ)_@3%-M;&Kx.#n_u.:oj:Jq/9PM'%WOoR3a,W-Q$XRq`=*c<3RmEPGG&GrdrVmfw9TP84:O2(d-A<-_nv*RcbR:(XKS49hbT/`4]>>#Dw-*.5Fl+M7g)?>WMF&#O2l;-+Z;E-ag:]$5buM(W2J_4HH/i)$'lA#1S4Q'Fg?)*Fg,FFw+7J#Fq.nu@=aD#pD87LqO'C#478x?t_G8%^9inqdtj4o?`$2bvh.,#UWR#HrD,)a4=Hm0%:s(6qhBb*Gt7gLEk7#%C:Dh34UUA(w:ms-*sZiL^8F_$FAd'&9Y7xGim`D+R6G&,EAtZ$Gq[P/C^UD3(l@Q/eUT/)(EL#$&r=T%[r.[#E-t.ca:]>#_i-R9QISSBTSMQ9Bv2lM-ZS-:hGh:?soF*X'?g`Ks#+)fJvUPW6c@I4hgkTBGkZ9:)9`&$rnNrH6glQLqqTo`K]%##$wfx=3qdfhmDKM0I]TrQJJ`2294TkLw#(T90>XM_nOSZRVtv##]sdo@O8v^]SIXt(>=LS7l_.K:6?IW&#HN8Ak2MNr6KihLHce)*Z[-lL$[27WxqJfL6kS*+K^9gL808Q2LWc8/Y>%&4jCHb>+=-c*'C;6Am(%HDg=LTs=A>)>@fn:D%*[s'1+<01#XG0;q4K$$AHBqBM3N'['uZ@RYLPrAVYMQ9V:s7BWc`Q9ZTwtLacZ`]q-XxD_LgJ?oMkH*,=RIJe#D#.VbJ>D#;aU;9QoWA5u'<9i'sv@OHsJ3$,>>#d9%##n2QDWl.bo79CP##:]$<-v?>I9@;q#$''d6#nD-B*^`@%>Gje+4ZH7g)gRpY,OBxS%5RAxbwx7/q;B+oL6T3(vHp%p$frB'#]bY+#e&kUROC`D+)PjS8ps`8'aDoNO_.Th(%62/(YaXc;*'A*`>*,/([su9):r9nN8c/*#<Io6#qB])<[GE/288=2_dQxRV^;d6#&8wx-qfTx7U$U=Sl*Wj&-/JJt9c4(.n1)mLMWimM]5Z6#v1UCIc5Z6#B:2=-P%Rq$@ru.:9QiUR%FI=dP#Hg)bEW]FIAws]W#^k9'BWm/b95eT+BL;K`?EU:>1bObZT)rOJTd3D0wcd?se.<i7]6t9rp0qB`V>W-RA-F%c)-D6MA4)>@+AT%uD@)G6O0tJ.k5t$/Fp1EOXMuC3*R-PrYZe>-@g2'5fqv9vr](7[1SG=[GQ4MkeNj0m?1)4cF4k:vqGD4oK$N:NlJfLSe6##W=;S$n(r7#8Ja)#qZ4_$m_3m&Hi:Em5f9a><'U3(j^NP/(k`H_w1d'&DWXmLPXZ##/nMi%uM6H;(ImAQ=gAe*/1Qa*KK6.DS=YD4u%9gL?V[#8/CM^Q[0pm0YFL8.UD.&4vcMD3CcK+*dM3&+k:EU%/OmSD'0es'1&QK1'hY0;m+B$$=9LG);chv9Y)-X:QNF/J*$_wI(nHxNm?6^4;F69:rZF9B&,,CR]whS0sF*ObkW)&7k<H#5;VPhN:p?%k,/TrcO'kj/4%Ic4pU'q/68`e$LF`QjGR%##XJVDWg'_%Oq._-27VUV?;,Obd/#5$M^2&GrD#u2(7CP##.O)W%Q3;t-iNOgL0p(-2dw6A-dpDoAPmXA@etV*%NfVd;.T9/`=o9+$NDZY>G6=2_gcC_&R'N^26%eX-e0+,%?WaD#[YXI#CWEI`lp#VuN:ZV#Eatm%-d,SIh1YY#vbT#$AU(R<<6F%k?RF-d[rJV6]Q^6#m*bu*dg^W--s%F.vm9v6d>wG&E?U`3F,Rh(8+VV-fYu'&)$KM0MLZ/C9KF&#n^-)'OvXb+/4[s-;.KkLeaQ##dcv6#IY5<-l.g,Mp7+)#SBNb$jq.[#/JRj0*D+^4_Ue8%Pv)E*A=;a*P,4U%]@%W=(=DZKHTAi*46r=%eN'$7uUUcDh#OC?$jN0(-w4O0CDEmVNhvne)/%-5+]Bt/+8.-5)S9t/,Qf7`$mSeO$hm2M5@8=&c5>g=r64-;a4Wh=/FU3(r9Sn9FZI.5nO'q/71Rc45[-(#,j?S@:>_c`qVgi0,P$;H5h*W-lN2&RcE[c$1``'#:=]6#oZc6#$$%Grc;g;-pOx;%n)j0,q%FD*Ya5A4sfcElu?vx%+dHT.9CP##l:ljdSI-##$l.j0EMZ?em#,X$9*6^$&,]]4e[fZ$bcp_OjfD^4tB:a#2$+)f.uQjRcRph;saj?68kdU&R4XZ5[`Ex7f;?V%i:2Y78s1QVi28&4*5.-5*V9t/3L?$$MS'XN`:0lbZMfv$Us=x@$BrQ&VfgoDxW5o/kw?=-a[?9K)rOrASS;69Qov:ASSMQ9Xr5L/lwf&v?iF&<*b@qSxP+n=xEhwNwV=3>'87Q/BF-:0BnY_7O3.Q0O;gn;AgCW-I:[3b]b4@MFvqQa`'uwMk2G>#)>uu#raD4#5Sf2`(guH5Hx7/(OjXb+Hb<X?j5X2(r`3m$^HXS%=WO2(:4+T%e-VR'D%/I2c,d[-'8.5JjPP=A6aJc=f$?D#(M,R$K,Wu7<*6/(Uh@E5MH%-#Q3n0#wJqu;lj9jLfuFx;Lq^NCUJ`k#@JDs#Zt,@Rvv,i;mBOw?'SWVd.kho7p>$7#o&54kIVOjL8O=)#aPZ6#e%Ma%$pd9Kt^<r$`aIh,aB/S`jtf.%8sx]?cnRfL_ZsMMlPJ1(.6MN9=>Gb%]=]6#QPt'+?pld;VZEj1/EsD+LOBW%H@ti0U^cj[f2i>.g,YJ4m]w;/eWiS$;@`LI*AN:;PB)`73i[j3`c;ELWWIm=Mj^#$1Pnd5)2+w./u&b6HsoF,TW2O1-qJ],<_s3CZFO)5VU^`65Tb;&uo+>@9,epU2&lAHNbm0;wwc`4#L-.<9/IpgK7$##LJ3@RaJa?u@Q4o;)(#t7=MP0:;dHN3CBvH2T9>?E*QZFA$),##,>;S$g^J>U*UKJc^7]>#arHn9O@JSBU]im9k[=g$-SmoRSmLp&WZAo;:9CW-xN,?ILb2L;:8MQ9ct=5Co$B$7V7lsu,^F7:3kXeGJn/@RMDN(v-WV$<U.4vZCe3@RxH2[IZ$1m&^r^aHoKgA0$K>t_VUkF5@4vM,MA(##qBp`W('K]=8CP##Se%j0F)Y/(3+,##WTE$M.*^k&rLxx-[j`g;RELbXhE2wtt####vWc'vCQMo$84e.%_OReXp5Z6#.TbK&'<hd;c&$:Ti8Z6#NWif,v8Mb=e/=2_j`c'&I]?0l#Ino.QI?X]Q#1XDnnTvLpK-52tMH'6?Fcg;ZAIGH<ViX/N2wo9vAt'>WEOe6x['q/A5VJNM#fJ3Q8Vv-t(cI3P5Mv-kl5v6(Q=W9MG-9'(saD>O`F+PdqXlCO$;MD)Ze3'M.MZJ(/*nFFV1Z60?JC>KnVF4/-jb=wov.UDo'71Fe]%-Fr'71tY@i;MJLF=79acioV,/1%bS%bLVr22t>r3V;pMj;o$2p/8V-<-Y7-A%.7@>#66)h$q]ggW4tr3,^ps3Vm5Z6#/%X6&(1*u/e`m6#N_R%#Wr+@5lv:d*O05e;9]4^,?_p6_6$;TJ+0Jc@h(]9&_=(r0`3Iu/1](Z#_rKEHQcu]Lx,xce),IF;O97R_<ppg4p<7b'2TY9`X_tF5cw(*[=L'XN+fK'AW9:R_F'8<A>qim;^]F&#b0Qj:[i5AkI-h'02KDO#]o.nu*Yu9+>NBxkPGs3`13#t;-HbA7^*H/CF<*IbkLUp$P3wC+:$%M1(G/Rh26E;=(=DZKsRxN%L-1Rh>D</<mVg8'h;;K(vb%=AxNI)ujD]WA1bTT%oL0t/.Wf7`#mSeO#em2M4=8=&b/5g=q-og:a.EL=.4lQ'p-8R9ZejR;0#.'5&DkW/D11-##r^^#3T&##h3Hr09dlt;qOvi_&s3Jk'xWmJEATfb)$Bk&x8Tc;('d*7RYju5@<5U%_.Gd=Unm##^sdo@t52=.9hIGe%b#01dN'$7KB9lScj<C?wZ0W$,5m=77ml5Vej;)3E-G)<b2]TA^k,;dw%*u:d4mx%@Za2<$UB_Gck;+*sshG)W-aN9^*gO<K9r_$d*@##Sk7p$:)G6#;Ja)#R9EA`WwZY#&or;-)Nix$*w/20JXP8/54w;-,fB4.v;_hLt[HLMQR&%>G8O2(PU_x7#dc&#`3EJM.J`Q9qwLD-`Kh02%?GJ1Dqe;-v3#:&eGm6#CVSMB.5T;.75FM_FK&C%+BPb%);jvfaM*R'C=ir_cV8f3'[U&$9KJa$As_20ponr6@YDD3-mc'&vaTM';hSs-sc>lLw`k*E4#?mSm&l]#^DB=oY.]?M'w^+%_*A[#,K]0)ih,K?b)<+6[@qf(5g%R7loCZu^*IO=5@osAl).:9(qjL^eXAXBJtw^5$n_S0G1^G3htFF5Pk+ZJ7+mP&k^')3<Agt/t%V23oC6W:E0jbudx)CA18%Ok^RDs#r7C[8P*p%-2w;H*F:W2'tn;1D?[:80`j[B5ng`e3`v5X$.7tRn`iVDW=Q?D*:@Z78cq2w$7f>>#LQ.,)5v:<-4=%q.ZCa6#GNQR*'kSNMCuvt$n?8<-YLdd$8sx]?-$Q68$5Z;%2l`s@3.*v#NhV78&h5-j<PM7Sro^*+rE9#.:-W[$T6&&$C7$h*ul(Z-'QXFNU[ZY#+V-c`5EG5JkQpV7@w-^#tQ-^#Fh##_eb_0PDn8&==sfG3Q)OM,qxM7uI0?6QcYYcM6BmcMwb1hPpS0e*xB[lLtb/e*e_<;2D_`8$&[f5#02<)#ZKW]4Z^eM14K</`dMc'&GuiJs@bo(#<Io6#e2h'#br+@5uF-.27p[k9/SMs%69i0,#vg;-Nn]N-Q3YK.KTY6#=iZm8%H`p/''d6#8*3s@]STs7dH2W%l8N4BFnA,3LjKF%0fVs@+[it6-IGL%%gS>,=u;9/MjOu@s5Hv$eAV#(+(;582kJPEV`cgE(ODW/,^+u#XFwN:k(E_&=r[R9j&kb$_(@51j;O$6'@32M??3?6,?sVTp$YlCs9m4W:wVI3F51`5NrN=8npMI353x>6x&pH>aBAsfhk$##uH3D<:2V/(tILP/Z]l%=b`nlBF'Mj;>6q&$Y*AJ1`s%j_e?=W8;Pr-23Evq7<*?v$TQ;B#<7u6#xb%b%pO9'#%l.j0R0Ha=p?S#e:nkD#*miO'=RIw#J)$<-Wbra%qn.W-cQ@0uV+tkNJ-]S%;2I&,rP9^>%@9<NFJBs7J+/d<EC3ktHF?cQ9c6W.`vfLCY-eN8<nF&#TsPgMfOOYYn:&ed)Wv6#%WjU-O^_=%p_tX?v>q2Wg5eh2VwmY#xH:a#6C/[#wFXi%PKx7R2ODR1<@Bb6`jZ??YPZT8CX(loKwmU#MpwVrmj?13E)V@tnFwEi+M^-HVFR-H&bS-H5ex+2NIQs%tRQ-Hh52/(Y(b`*1;:^OOko2)#C7f3&kRP/%N%d)H1i?#FRtf2k$ZN1D:tB#uDs6;)EUqBD_DsuM(R?iA](N#0[Y:3/'-ArMno[tIv,*#+I?C#svBJ(YYr`W]Qt(3A=WPAi87J5s$Hx%Z'A;$^(w1'H/>>#$&Cs$GotM('O`CjaobL^KX'ttX_rSRZx-g)(Q(pA$N[&#XqoE@4tpcd4mY,2S3xr$o.#^?;JfA#Ub(?$u(b`*BXs5/UU)W-c0;hLcwklAarHD3=K)s6,D28n*IW-?wbY7[U]IMpUrdu>ld]r/<XI%#c]m6#;@Rm/*r+@5r4h-2,6ji-Pgk'&`wr;-a8I1%xs+F%HC59#@uhv>]kD7SPR9/`.P7M1i:3D#i>[L(=J&v5)jTv-<MjD#ULD8.('F2MfW&jMLY>V'W5MG)FkR@#s@04*goS51bf%uD#0TW7@EDW/tQOkWjCNw6vdjkBCqax%_+VCsHGlh)hGmDQJSgf<w392'JZB(6.'g+@i*YI2enrZF>:[iL))*ZuP'Bm$p7g0M2Ks$#hRd;-g5_S-f(93%LF`Qj4`f+McY[*NST()NdSrhLYuDejs(X8/QaL6/]k.j0B`^I;Rm/K2/E6C#sOcm0jfE.3YDRi.2LmO(fi[m-xXfq)ou.&4+M>c4*2W:CuPpw3&/<PWL3Un/YlQX7M:jhD%9VU1:1dh/ii;>GTBlqq4erR0/9PNaJPuh)[5ZI2J^7cCmFjKM,H=5&ImJgLq&7##I<vv$B0&5#00;,#5HLS7#nJ]=h-H#$LB0<-RY5<-JF;=-5Y5<-uiCE%M5>>#S;BA+Lces7/Yu##oO5hL)@,gLCAfo@(9p*#W/Yt7t,&F.aIpp06/;-2Yjpl&Ha'T.j),##qHmD-UY5<-<`5<-.u`a%Ex`3rcMd6#usqFr::^kLJC$of$fZ.2MSC0(^N<89i=vV%E3cu@RFvr-iL0+*I5^+4^m:)3e:Xe)k@C8./?Rw`$AS^$7vsI3=B39A>9%+m1%wGE[)kDWMOv_?&NZ=AeE?Q#%b#N4+Uc>A9pCw,p527L;^X[?gm1rKIkZA27<R51%St*o8W96[JMf2v)[E7:EWMYRKCBxb:'a/lRpWJ:Le5xJL_5xJ`YYhb/gQ.I_nX*>Daq_6?q5B@Y)TM;ql@4opY]$?X#@Ok--#w]Ml#qs7OHp%?EM[(/JFU#,/8R#WA#0#=WZ`*mWYip=]]]+#k?]O*F8c*E.xH;mPb2_l4GB?7KiG>[R?##dcv6#Z..b%lcC0__JnD_#P#<-J$h0%@1BkNv:vZG)=kM(FP;h)V<SC#.$s8.6T.IM_P/J34dk-$ZGVD3o[rS%(jXV-F<:Po(du2h2.s<oj$p<fo/+%d>d7hj+)gHkn@&Bu's*W6's)p@L10quS(Q9M'eCU#qX6>G8^x-$^8M4o%7KfLZ$7##s/qF$7kV4#nom(#_Ksx4kT95&V>:&5w<+<-U1UW.]Q@##*]GW-b?Jb%[C35&YDCpL6u`K_klZi$AfCZ@`AZ6#ATY6#]/VP-O9S6%U%E_&t8:qBV[-lL[[-lL(=-c*.$($G%=8=%wCx6#)),##sk.j0;@gkLG4[68G=Gb%Zofh2u4Ee/KAP^,Sg'u$pH3Q/o0`)+Ic9B4DQaa4W]DD3e7#`4q,Z-/oMJL2f4%HN#dtxFFBSA,'`_s2+HA)G)vVFSr(g8SXf5(Gr$b30@Sv%OePev.B6-O4bVw;/<-Zx[CvG#7&;k638xg8SAj,^6q&@A-R;'C-/gZa0U_,r#'hM4#'F2780d%`=UuYL222YV-qC;O#8Hrcutll:tg]7R3u%$`j.*UDWm9#^,,Ce2&-o.0)bmH'XGtBh5@YN=5A7i;-R3RA-hK3#.7fU*O&j1e$[l7K8b*?v$gW4^OJMKC-napC-w6Bo1(Uew#rxGNuZ2Kq#Ph?6MNA-##7Tv6Qe,ls%dv[O(q?e>3(5vjui4q6tZ),##r=w4$(;6&Ma*Z`O<=H/(i_^`j->Ke-9m0W--tpBJWrVG2GgF8%aMFnEt2QlJMMQ2'P>e-6Iv=$MJ7$##=dk9`JR<*4-bng#$o-4vXFEY.DJEP$;4PG-BYo^.p1tM(AW08/$^j[tQlRfLibbl$2gC<.t^9YcRNwV%2sxV%NqtpfmiG/1G?aY#&p=$Ml[of$[s1'o'`K:#(@0<M0F0p6Uujp#%pR1$igHguN6YY#SGq@bjefrd^hHP/2V97;CHv6#B+Z^?-XPgL`+ii:J27[@Zx:t':S6$=@O#^6H$ZLN&U+k:%.ZD4a4fN:'7v`4,HD/E&oBS/Svib6)m9P:q:D&5T(9gL`:tO#VpL_$m:F&#1?U-1[e%j0D<O(jn0X4o%uT^#26q%#,S,<-75T;-G5T;-W5T;-h5T;-x5T;-26T;-B6T;-R6T;-c6T;-s6T;--7T;-A[lS.HIo6#=iu8.*r+@5<wb;HVCm;%@+Fv'ZDNm$MC[x6+raO'krbUA5%]v5M4^_>UB(RLG9M99^O<^@DJ?I>X*ku-jE_MDmLM8.hAPP2`67aA^aEt/NNc=$mQu98Jlfm0o)=/#l*rYHiuZQN@tJfLj3$##J&/'#<o###'vk-$WPl-$h+m-$x[m-$27n-$Bhn-$RBo-$cso-$sMp-$-)q-$=Yq-$D^V&#%W5g$wxC0_xdL:#8CP##F;)6MBNs$#<cl>='CHv$LxnQ--SbR-UG6X$Ew`9i`6kg4TBJ^>Vt<>-`cg0/0)9v5@S$:iHcG?65-]'2werO#0-3d$m:F&#&iSwQx6Z6#MSP7%4T,F%[7P&`%Z>wTIXUs.:Ngc;0AZ;%GhQ#$I:tP-pdrS-*2PP(81j5/e3pL_M0)58[m$Z$W@r58pT#Ok;W_@-eLi3,^),##8;kx#&L17#RT[p_7(VV$=&>t7r4+gL;KihLDVOjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%Ma*(q@?erIh_kHYm*=-_#H-mi'Vcec)9fL/sXgdh2cLGT'1EaK9fYU+41]bT9JdYs-=lZ.MN*v-M]e$##*^$8@k<-Mg$+%v#ZSv6#&`oY%A`+D4V`K999ESX-af&H#:*/q$k9H&MKcEB-4dEB-DjPT9?D=b+tt//L%fM'OwNOD3kJ&$$QdK>>A>O_8YFNP&C+0k;ekn>'1`1hLaddh2B)<Z-3:,,M1]9<0kPPc`hsMQJ.MUe$M?`c#Tn/WNtqJfL%:lc-Bp'.H6&n6#HrEj.`PZ6#+obr&wATYLmZaG3]eSnEpa@YCj)R&#J74R-`aLc3rsS-Z_<7_8qY8/CbZCkXX)ldXEx$?:aeYH3Ij]:$rAEDu'd0)Mg#7&4moX<%)c[6#i]Z6#x4T;-?h5h%Yn%v#U>>(Fcnv/vG;*F37q(dE>aJOFfHU-HuX)#Gbk$?@mjMF*B/#^?dTSX-2+TfLit#I#6[mW#,(@hCdR)Ou$P-CuHcDE-XbDE-Mktv/);G##`PZ6#Kn'F0Ytgs/L^JG;%fM'O-3@I#8Hg4M@EvpLe)tcu$)&5#u6>##B&Y981k0j_$&###Ko]#'#xSfLAUnlfS=ep.Ivvl&`c@I$H0`c#PCe>MtqJfLS9m`-*)r-?muj&HD&dlMQla^-#O$+7<iXB#n[xeqG;ZM'lm'16P.5G#Y?$fq$xD:m,[3pJ+.g-6>s),)sFw6#(i^W&UY>>#]W&68SP%Ic^;d6#Npim$+BPb%A%3dDf6BY&&%C>,pfT*+p<0#.pi^*+Ys%s&p6k]-PR^v-pl^*+I1P#$G3I*._1o+MC'2'#_n6p*8k.@>UdSs7,GY##tELb%hvv%+(n_b%IlxKYs2)iskT50(QpXb+H[nw>u@tx%g][`*BtJdMCpae$N7Rj@FjD:iSu0*>aDT<QA[2v#Ff$X-pe8>($rHq7O7'#(T/5##@FJX#<7,##^d0'#+O/[)*Q6I%eda*cdMjE'#Me?-7@_TQ<G@/V7mu7e@-M&#n08a4_aTkbC2/;6k%Vl;AA[./mCa6#70;HkHTkbjHiec):%vu#h%wX$JG:;$:hO))'?L#$*R6^u..OG)Sdw3QS=lC3P[4g1Le60#N_aP$mB%%#%gNsSo_.iLU]@V'eY>VCRM(.;+mTp9Rfh;.l3*D+'5Vv-n6*D+-n(#(?xNi1it/F.i>Fj1S6Y%Nnvl-2kr###@$&>GDiG`jX;>8%cHb5/Te%j0w<gl8P?ti_xpDe-T7pK2*pXV-4Dl-$5@3L#j_Dsu*].H#/uIl#f84I#dhPiTgoG;;5;^l8&w*w7_Jm6#(;G##(1j/)2=_hLDH`CG;AIS@c)dLpWw:Jhi(],MqXPgLR1#,Mc^:Djn;Tm'q9(DN;e9K-;b0`$V_o;Oe`:)Ng)KJLmkT]u1hNM-S%WjQ?M)uM9M>gLr9Q/(kZbgL_)s/R:FMIRRLq1TT9#ktIBU4oMbYVZT_DM0AdwQ/);G##aPZ6#(p3^#OmZZ<ZEnXHU2KK2lXR@#BS,lLB2or#Q;Y'$4J3=&vW[@kF:GV#P[^:#u5QD-cGm`-O:F['OSuu#x%^;%0cm;-kAQW%,0b29MRExBAd3=Cgrr3$#3>b#&??G$eKrYl_[:8.dZE?#f5YY#2bEJ1'KwrZ1:NP&SrGHX#q,D-:_g0%'-,F%eDct703Z;%DrtM_/SYY#$@)=-/H9S%h.^Tri2=1).&Es%f^'h)$t2#P$@FOouihqoI=5fC(BUJ(UK>F#[]mf1gN'LU$UGAP8`hfV@tq/;;Ul##Zw9S-:vx_%[BXS%XGb8@rBvV%kCg>$wRj'/^MkKP)_<:MK6m9M-44]->`Iu.hQ6Y5S?Q,)cF9fC$L'1prF(s#Qcosr$j@quCBKwK]85`j#$VYYv'v;%Dj@:Ts`QI%8v]0k)P#<-l'ei&_0]V$*^$8@^u=REkDT_O$4fnnn$PttEVRstL6n0#'f>]OS$+HWOe+,)IT_'AVq@3kV_D>#`(p#$:DEl_'FDX(1erS&2HFwp4mN&`6,>(/M*.l+av4j(xR=F%+0*(;p`T.X5/G$Mhfsp$hGMJ(<fv<-@M.Q-b=eA-4;d,%3Q,F%_9N^2(&:W-,1;W-7.E.NU;Z;%bU;/:&8APuj&J:vrZoX##1j197?6F#mTIu#3di$kpu.)t$Q((NY>80#A0:N$Kg1$#TXBX(?oiEIF[JQC*_:)N5e*mfE<l[$liHg>(4v0&#+'u.Sk+_J1?Ke$?EL#$6Wftu&qPN#m`5juPej1^)IfluJ/e0>8/@]bI$0Ab#h/A=u0-0)ahgnJ8-&M3`AZ6#bxvG$+HKG.WQto%sgh7/*WX6'f2l6#'####GqR-H8.<?#&kHD*5Y(?#<.&Q#(:,N[1pGG2'bD^M3@]qL3Hcc2Q^GSfiAbJ2u_MqJPDOP]L[+,)vsai0b=Bw%:vxn.B),##NSkh9-#M505K,5&WgkN9J<V*4I#_lSvlBe*vmGv.9`XAuwBj%$9M>4%PplO04n7^5Xa@CsHw6C#:1A:#uI<`WRSJAO$<R?gT60A=,'`J:70=2_8R4?.h1bA+wQ8=-EC+J%@)J'f=3(kbsa*iCMj7p&Mk3T.dujh2_w=K.HL3]-meeJ3:0fX-Y2?ru0<p@O@mjX#oZY:;+F%&=#,7Hq>q/S33PID$#?t9#2c/*#Bcdl8wl*)*cU+p8^2p;-_TE,schf[>3(V3Xv`P1:pKm92)c;&5A8dG*[SUA5q3u59g8u6#-Ngs7P+:kLHPbJMXbZ^=XAkM(@S@&,q=ZL20s*Q'.7>d3twC.3p&PA#;h^OT0nu8/'%*v#[,DW-SHOS/m01SeFsW::&N[R0&Wmo/n<UoeGWR=9*&kO1G]d0-;Eh1peR[%-OktK4)xFN1cUw@-P$Ch4,1YN1)v>o/R&doLhB:41gEm3+:['NC6(0U/4&wW72Or]FR_YY,$x;F?7S..2#Lk,40c81(GN7%#([b6#1Xa+`JB^6@CXrS&rRK#$PQjj1qCn;%JvXhu<50J3[QV`$_caN1LUIc$4qka=Ye&9KF@'^-'Ft:m5+A['R7N#7Xe<V1OiLTUP_>s8'$^D?xYa+6-S7(#d0LBPa^gcVDK]V$@(VK*,vu5&2+'u.XRG)4?SM0v$epG)?+ins/-d+=?;<3U.-x@kOg(,)=Q6'$VUZ##7[og:&cnY6dI%X-n4LqK*rJfLLL-##7SkA##,OQ`x<L`P)plV-Llt^#MPweq?3j>#JZ#H*ic0riBCf-;P$>#-?OIeFmRHuu_S$4$@U#3#D-rB4<H7g)_k=mu?1A:#$),##8EV0$]Pkd9oX(E#X_Y)4DctM(;HC^#;_S=uw%p=ul=;k#]mI>,*9h*MHgo'.>1LU:-<iOB@IHv$H]X_$BD7I%2ZnD_GwR='?;G)%mUd;-*SrpL?n;J:w<kM('($Z$U&X8&/qR5'Pn?k%S:SC#,f#<0&aZ*M,-OF3*Sdh-FQ(RWK2lu#jXZvjeTII$H`]<.giJS[u3<8%$YqKG(P,6Uj-0_-t?3L#,_'B#G/G>#oAY>#o-AI_q4N`##32O#5q,]3Ext2$i978#Z;bq_8+VV$bmpj_B?wZ$V]Rh(pq%v#)i5<-3l5<-6xls-os0hLF#4bj>dTP&*<o05MhvS&[p@v$Ew((&3pC(&7v1(&Fq_#>t>::%ZM[]4t%E%$*l`?#,J@U/_77,C$'veqcB8?dA0[du3R(kB.*=xkQ1;jZgNZ`^$Mu_jgb4iF*I:;$1f[J(v(gfh^hHP/DX,87&]n6#Wa(1.]jAKM:R%(#cfYs-MxEx>W?V)+Gdg$'=Bt;-@rus-=^jjLYtQlLh)9nLx4voLu=NL+mEXB.D<O(jMW+8of?XkOxa4eH8(6kOf14>5#b_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd/'x5'np$)3Ws&02:DEl_*Wsjt3^c'&5AW]4LGl;-:%g^$U,in/^xK'#:f%j0B[fF-^x:T.5dZ(#mBmJ<&9Q;B6bUN()3wA4R`?<.(gE.3C-;o0n[)PCH4NO;B8=qLDxAO;_:Iq:u.Ic4(YEnL6RC&5cGM'JD57p0c,V?HRr)a>S(qA?ZdSnLM<k^[mmUnL.'Vp.TXH05f#.u1;GNn:xPW%Qp(?7/G==4:[Y?aS,hG`43SSiB.+/TI(O<8%^P:SI3R5W-r_-<Aux9+E0/4m'4<O2(t6XU%n32NK,'qU@GT+6'''d6#ZcBc$TP>>#U>+@9$AKd2]Gmlf^MvlfAWQJ(ZH7g).q3L#O<N1)4o0N(xE3L#n#0@#4D;8$E+QV#GkJwmM:3,2/6k+LL2LD3t-_wjVt)#G$xQxk1X@20$4Nul&HQfL/g0&$D/Mg$J.o:AlYGq72b_s-:ktGFxKd*=,T8dF#Rm*=s=>J2>tWU.fx3J2B0'r.^5KkLv)5gN;5U1=5E5r.h.Xf2@'bU.h+Of26SJfLZ$7##IhT#$Q4Y6#^8q'#:O(,25wJM0MBE/27[;^%.axgL@,Uiu2xcW-Z7p$%6-V3([rB'#([b6#h'R1&as/2&ct%v#1F/2'a^93_Vu/4R@=2=-5oGo$lk*T.w$5N')pcg$oK(E#->7<.vFq8.a<:T%6`Y)4V]G>#n6:#.=[#lT[>lr7Z0GW[-ANM9;ZjZ%gn)5C>.),Po-L.(cc+p7rVhR/u/xs&elO1^3.K'7;fbQ&MePr/6q6X93xBFG(@BVEEPcp'UJnb#[A<l$<h1$#g)+:_+v_3_Yaj-$*:uX?/Map'0ii/sWg``$K.qX&</D<-h9T7h$7$c*3`gm/4Yu##8ofh2kbYO%`^b6s^;=0&#.kr?*H_%@*Eh@@PDpkG`^UlW_I51H`^h1Xh616N,P?QNIJNK7x9/lEtT;Z7#F]LF1_e)#sNYb#'rMD%'5>##;:l3`pRWt(;2GHl/klgLK*>$MU4Fa*Hv26/q#%Grmj0-Mm6Tg%BQ>K:8N`R:@mSX-5-ot->;gF4_R(f)Fp7H#PVI+ML`J:90kD[$WIG/$[n#G4jo#G4c(a'3[#E%$/#>6#cGX:_xY_3_YN.*Ht>@lfISZ`*M$1<-*rY<-6er=-pOd@&.XUZB-j:)&TlCe6G2+8_o$21&jI8'o*3e38]IX,M6*8Q2ZN/i)o0q+MgMQO(Z=]:/#F/[#ktXA>5rqxPeJ%ku310=/Q6T[uW#>LQh)=YVA9NuuonKi1=%&8%SnO,2.ZhV$u`D4#C:r$#<Q.,)uM9m'xo^DNkAN$#([b6#)u;M-6`5<-iN:h(/#Lm'>EZ6W?/#^?EpvJ(w?,T%mcMD34IRX-'8.5JKG27Pc%F4bn#LBY$F+on81B];/+NkEOHJ-t$*_6tso*Z1;ID8$rh#3#8<M,#<1([TwF)20d#60`b$L6iY5Z6#Sw<J-bN9;%^V>>#cn/20XuED*JnL5/AO@##,jxcNbIhkLbIhkLDuPoLx0nlLc0nlL3*<d*l[<<-:=9C-HrwBM3<TnL7al0N]5oijQ_>>,6tbf((T#a4eCjV7LBqG2#C7f326UM'fL0+*Hu<j1BW..0ABkR/g<7f3%Ue+4cYcH37ZRD*CF;8.P26X1.A^Y,G/3g_OgHd)lYWI)`[VM0Y^eg);4qI,2duh:@&$TU1M.>udIvt74gNm1,X9@[Q)$&5tb^XB0#q$CxIC]8;uOjB^Ucv87r:(HD'xY67EOPE'ddO#[.5S/=.OO:%J'^+oRxI2M>1S.qXds:MtCj(P]CC,2t)]5*UJ72UgJo'HvvBAt]cP2kFQs:uQ+b53'<]5o?.b>)`^S:O?Yk0w#q9KZ(wu#*SQrH3g:,VrA:D3:JK`E$dIe*6N0<-7?^1=8E`hL[SpS8vE;s%Lr&u%pGIftPXZ##ibWj0V4@1(fMHijPU##,;^0<-X1)*%>+PV6k$cP9pQ;/`Twe'&[+e'&f_k[$WP@&4xo`D37T.d):4dM9%QZ?$#F/[#o8L>$jk#A%8)TF4>WtR8=9-`,;W0&=Gl]MQaeOlCG1`VFF`A2Qbj$#Q]*kjL?QI91hhpUVd+ST%02S*=nAIO#%H?Y8;>MH>-h9H`7AlYJe[dxB+nQHPI-;E@%%_15?$KJeO*1&MQ.Wf4U;,G[C9OCeV4_-5bN]Lm.?ZnOr.@qA:h7I?hIbl<kovU5xQ]+H[4bY75<ka4.L#B@,0Xo0p5e)#cJ.;6,bIZ#UCHP/XJ5D<ba^6#[^Z6#[>pV-:wX1:TQh;(C5O5(CV+T8L?eM1(E'<-=c5$,3aihjgr$)3.+35&d#60`x4d'&fIe'&^T95&ZX@<-H4`T.lCa6#@5/F-hfG<-NfG<-TM#<-v@Rm/T9eh2E]R_#.85T'rxl8.HcP>#VVZ20tq-x68Oo$$n:@anlV1#$PP5^$,n%oDdnk1D=-cVAf^%<8)_6E6D`&14@`>LFUQZX(n@@u>?RA`,@M4U0dADT9TNY<8g:^r,D7]<.kDjW/kT=^6CC%I4GTju6l<TWA.Q*aGpc[5V4tou6j3KWA.KeDGScOpL,gtxF:/S90:@/`,:@Dh3:)Yh)>wlW-<Dr$'^gVhLun$##vQN`<.Z?/Lb1pu,u.?VH=Q>12*ji^'3D7Jrv+-E7cWwr7HVE/2/ZNYfmCba*(ZCU.rCa6#moB(%XBM:##enaFC04m'LRK?--:pK2l[e[#7lT8@V]iH*YweP/5EI)*u&i/<@v7H#9(5xRM%T:_Z@3<JsXtnB@(6i(&VHx^4XGO#FRPHu+.8#8M>4)>E6<U:a@3_P2E#lu/d%::6XA1Fl<v0*YAX8A+DuN*S'k/m_dsC/>UED5$wj&5]X'd5M2`]0-MVS$T`D4#ew&99E_*iC/7oP'gUCs%2]2N9qF'/`2V-]8I?j/:',0Z-2@3L#I0fX-h?3L#u%i>$DrfE#&Vv$$a;<L#%l2`#xaM(rFcuZ#&e,O&#I%?uR0JfLf1Lau=ZR#M1;3$#:hpl&aO)##_o8gLA[elfe;F,2#kp20BZc6#%$%Gr-fk[P^&a<%''d6#r4bs6VDq<:7+Lk+3TKs-hHFgL(_]g:hQdO(X_Y)48%1N(j;j=PGeqo$g0#LGHG@%4>7(@t+eg+MWv@_u,1j[$rg[%#V%bJ%HtL.&954[BuYA/`S27A.9R,L2Z,d8/K2QA#KG>c4F:K,303Gg1p:Rv$otNonMrqA,#JH59Zg<V3[^aRBIrY<-UE,h1$YiOfr9m3%v[bC$=(]NMAr+L<5r1f_*9]N1H+e`a*bso%*A-($e)m[$dgZ`*9^$<-5j]c$R[=F3&0fX-G@H>#LH>@#i:F]u>C=euwTEp#7ph_$OGO:?6U)##gX8&vDilf$IBP##EXI%#x:3U-@W-7:g*;s'3'%0)`JD,)<UGgLs,:>GQ^:no'hxXc$r0AO?^i%O&iET#P:gkLo2Voe$Y[%4meY-?eQ1lohL5JhZoo32U;,l9n+)H*wIOp:/+=2_'j)3;];d6#1jmI%XW*I-SO)##hpF0'we[T.3),##(**q-Mu`C=HtPwJOqfZ$:-xe*4(ZT%F/F_>Yqs<J+q%C>[$'=J^#L._K2'J3q'>D#t1h@B%L_gOeuB%Bw9:KO$QC@AXkg$A>$&_f1e5A4DLOrdAN=8%cIiI;OCD?%:+,s6<(A;$S;sA4fg4:.u10J3BsjS$JX>SmS+Z4aWAMmLgipu,?qV]Fr,sr-Gxg1kx-,GM1`[`*.K8H2bCa6#mim6#4####=r+@5f7Ew]:@_l8.ZK/)dUE)+s%*WHSXQh,F[QmUl4Kr0]#3e&g42N(=-X3J-xe,;j$eX-_kJu.w<7f3?;Rv$D.Y)4)]FIF^a87;Sfjf2J#JA+XH%s-Q;qZ-DOcT#+1&^7@9d.<*n;.3L?XH$*(fX,LH0;.%(/W$)Pbs.JRUYP:<XH36>%7#?/5##h2&j_[),F%_Fc?g6[n.',YmTr:i7oq-]5<-81TL84A@60+p/20et@;$I9N/2h(r;-;fG<-LF*wZC+,s6H?2/(rm/<-/_EN0/l.j0Nsn%#0)4GMHJl2(2YajLB`>d$P`d'&6O@##`&Gb%[ofh28=Vd41_$&%E_;a*qT2t-P7PcMLPem0IpQA.n+ns.w]3T#KZ@x8CL6:0b_<]-KpR*=;v8HF*)2DjI)f--O[Jq/L4tJ.So%Q0krVA74@bO:#@1S0SOEp%DKne<3?0W7LmL;.b?q;.Rr[fLEjZY#:VC7#HXI%#1*b`*_3iC=6nF(=PGZ;%85#B+9Btj0gCa6#iIj6#osqFr4PU58*5=gN''IW&%-'u.fTU&$kf*F3>HF:.8ax9.<`(?#dH^r*UDfT0X?)i<BNbL$_2g&,+j<@2AEs@8-G>)BP:65/(Os)5ZL_`.Rnis#A>Z1/l2b6`beF<qOjEX&Y*<$#82QE,Z`gs7<d:Th`Gv6#m=eA-g1/R0JZI%#ce%j0'a?iLQ<wQ89*$Z$'[L&#>h3<-xq9%%GJ<j1TwX5_BJUv-,*SX-eU.7V1vFj)HcP>#365o;Uli,2%9E.3g+^=d?#5uuVFwd),-WF=NRgH<^[<v6EZ:;.-L6-3On@LZ`3CZ-xtV@64Aep8CAsgVvP45/F4IiT`,ue<_o]G3%XJW-usnNO'K5kk:QU9VoFZY#682/(Rb/,MH1q[%Y0xr$idJ<-gJC@-S:qc*ew`p7jirS&+*tM(hpk$IM+:kLcMm6#k2h'#kc`oC`o598@>Gb%`TG(=*01w.5HNb$m)RD*?g,P&/r7_&@lLYG@QvT/E0s@I_dFk<@Rrk%`lIM1V1`;$`<%03aR5N1L`=</(Dns.*4-%5_Rj3=F@+k3N=_R1L@BG3V)>(5aEal2(>O</M3GjLNVjfLrX5&#rNPb#?Oc##PlK`$,iHw^dgZ`*B?949[qbA#Vw+T%/kH)4(P:8.B*jI_GVSCs+Un<$gx>1pSn@J1#H9G`#m020Deco7Gr%7#aa#pL+Y7f$,8j,F&@,gLqRfo@>h1$#mEmO('&[6#^xs/%8O@##f%*)#X[X>-KX(?[vpBP:9Nk2_%[E0_N*]&MN@h0M06Z6#ffG<-ffG<-&>c03w./c&%i^Tr.sVwKZ(e'&;1^?p-L=G2RWO*Ivw:;-e78o8arD(=o_/?nPpAO9NnZp.].>[IGS+J2F08^55F5e<,T&HF5TQ40DMM69HBI_>9.m/2Rmt-$C%/m0dliP0c_c`4Xa=Z6%oi;$NTD*4:lcK3,(fR9v9(S0[2r*3(h#Z.LnS`,-kq;.ofq;.Y/KkLI'3/3N####WSZ$vf-Jl#sYt&#=(]<;E#xP',n1]$RE+W-tW]gOtOS1(4/sD+-dwlf**V/:-AOQ':-V8_,E&F.jCZY#aYDg]w32Y&k+?>#Sw;;$0[35/Sn.<-AZ#xo*,./(l2mi'[[-5/lRiu7u5iT/SQCD3hK]P/i1.^&8cK+*]q.[#dF#X&RV)2D3JMDj;CjJs&JW,)M)p_>Zt>e<L*#uJul<b=<:d/2sh'K2KMM/seB'>.wRQC5'39B5`6;1?E:qC#>xR/Mr7LkLkG2/#d7]l#:)>u50FZ)49,B+4_T/i)U)mscl*oC_I?c=apKA7#Op]sI$cj%XH7Jup%(4]-5+</1O^m<aG^t7IBxN]X.jHk41<2>5*V@a*QYlNBG6R<I$Z@1g3$fo`+jHiLqcR^0tBCR#p-###I2HJ;QeB#$&@g,2:sdo@;HXS%&>uu#rVTI*M/(W-dOZ42iUiL7#G,d3f-p11x7mx6kj^IK;hB$A8%:jEnv[%fipHx-kQ-iLELCsL`X/%#YgvD-cV6J8T1F2_IdlwNgEZ6#ATY6#Jq)REjo%&4Yq[P/jaj'%8WAa+w^/=-ftGk.E5Jh(q)l+jlOU5HIW_C@1`NsB1;_>IFuZjLl]ZY#%#4MgQ'SG`lcnB-DYmT%,&%N0Wk.j0Pf_0(<2f49j=vV%,G)s@^gU]-QbmWoU*p7nE,RAXVq%/15ZFc*sst/:(qR?n>kfrm22.30)+`]F[6rr-;jW?nKofv$>/#^?IXw<?KDHZ$_O##,&:6gLd;W8_.=2=-swgR7Yxa%;<^CwKAa3Mg.F_Qs,g+P];OGk*)`Y*<w$M50(C(<.d#60`%ftA#6rd'&h52/(I<=8%^45gL.i@mMKbhp7:_Yb#8KUPSqc&02M=dl/e@OYY2BPM'jh+GMg2th<qepU@8e&kraqvi9I4SR/frao7;L.5Sk`3W.fG_KsVb,1%>/#^?3aN)<kY[Ks(>/1(a05(+N0Sg:je2^#?MH>+&Tc2rM?gh$Z`''#hrj%;T]UKsig<d$R8wc&bqDW'`Gv6##OPW%A2d'&,%<;$h^TP&R82/(IDI'NMQ378Q>Gb%hX0=/^pdh2>%NT/7U>v>ZZ(4)_T3Mg-D'02$,>>#+_o7nqSMAXav5A4PxoD=v%_Xoj_=A;k;h>$+oVU%u.'q#ACn?;<-P`krn;&/13pL_>?QFW=s<#-K.=#-H)-g)s1Zn%q1d;-q#Px-$M`K_+_SK'`P-9.lIo$$JRra*Y>v,;m%3^#^dV%6T/5##,/'q#6Gu6#$K6(#9T#D>6GDm8OSQe4EI]r%pL##,t[+,&W`c7(Ocir?L:AR1jT3MgA]/60A-AYGK?->Yg2&42u0&,;3<L#$sTc[$qmToIdrr%XJ7(42[3u4ost@p.,,N]X.4$42#8t'42VSfLQWuw$DSb5;-0UB#[Np(WZH98n4Ec>-wkZb+4L4=;2-uA#papE@E.tE@CJ@@-&C8@-4L4=;A)7C#X#+###]WDW[ap%4,?,PNO)C&=kj,pM)ts3&u[e[-bSS$9pBOA#^Kro$L7LpLq0BJ1p@2Dai?j3MZMk$%9##^?OnSfFDq?K)<09m8M,TfFb6/,;=kUB#Nk/cVO<LPA8@wJM:U>%&<C>ME:?p<;*.C'#B-=]u6'1J#lQ<7D]bYi%mR;;$^YMY>DGu`4`AHW-JM<ME<)L9;*Rc]umqVuL7=PLFUeDMEUwg1;Tnuc<%R>t.pmLYYEg?ME<5>s69dMY>:9dA#..kZ-9c=_H`F$##eOs`uuKJvLMfl&#5_S).b5/gLAK^C':9hKc]E-_=Sgh%IJX^k$u_P$IP[d##+G)s@WkW,;&LQ]ud%jR+uk@J1`C`gVj.15/aub1^[8a#8uu`C=/M0/`siqH%/<GJ1`X>>,JP4gLTX[B&VfwY>_38_Q(oHxOO/wp/A'4]ugG5F#YcOx19>uY@,#HfXd_n/;@B6;[/o[20Sn@J1m%6G`ApKfX8Wgm>fSSnVGj_xApfl:;TPS_#5KIxOB;1;H$NYc2HkKeF0<M-2[&QM'XQfa*L63NKwQHZ$wCx6#t232;6BR]uk*v^0'l>r#@e)0;-'R]uEM-e%Cf.l#vj96;nrdG*x>vJ1S2A7#G^t7I7XK]XO4PqT.Kj4;*RASoujtp.s)PfUVEMqT2g.S@K_ZhLELCsLc>aQ=?Db5;]Kw_#12D)3^6d#,Uuou,-o[6#IYnk*r/r^133u,;u1Xx[+IH>Y82&M1Zd5A4:#Rrd7u68%ea#A[jGm6#Fv;a*>GDT.osqFrgK8r/?0uJ()2n6#FE`.MP)+((1-D3;@^Z?$8])D%aEX&#PTOR>=+v2Bp+3?SWXe5/2NU;.?vNYP$=wG3OT[rTOMcs69dMY>79q-4l`)E@7V:F;6un?$tkBJ%7xL$#Y8_f>JJboC5DDQ&/b=V(E$lk:c7i>$qk?'*6sao7Gi(5SZ/3W.Lw.qpI**#&BoNi:?6j>$lp4T+35^l8r*WgVlw-5/N'#DW<u0QDcFmaP2k6&%;/#^?,R.3BxIIM3+eC)3e@pj1$),##9C5b#%^Y##C5C69-x96;mGv6#8)g6BEdHv$awT)&+pv_#L%Li:MC7Ac5`pm*u^LZ>8,w<(:Ffg:Zg?;':eC)3rB;p0XWL]Xknho.#SVoIE-dX8-c8bGB;?p%M7L2Bf_j>$rePY/N,>>#t=SGMN8E5f4,o_-M._'?JN/g:.-9T%]om>-2=q`$>G#F>E86?$:Qb.%DB*&7F,-X--HY4rWh)Z#gWIj9$w1^-vOY'?5HvD-ppAp:G]j>$0p^P)DpES7[aT)3ECUV-$6BJ1et&7#(SbMEB,fiLYO9MBWcis%$,>>#5*_W$]oYY#^QX=H$)(f#%Bm6#3V3B-:k?uSPq'02TKG4T*8.m0XK7m0o6dx%P+<N9$shP0j&&Q0@%=x>/#kIbi`Z6#iZc6#;tqFrWSk&#4KNjLVVL).C3*jLZgdh2wo2V,:$+PVRXZ>#+5DYl'&/S/5';;Zsdr+L%jcDE%-7$$&M]nG$ox@+[lvP/hrES7]jpD3BH;d2fKb&#Cb>>,=WZ`*d#60`i]c'&RS8v%x-f;-N>:O&/^C_&8mN&`E?,/(.RrQjFAd'&-Kc'&+Fl+M0w_#?#'hM<kcMYR*XM#&)vl6,cFwX-/^#u'*283+ORxM01tqFrMme%#(3a+N`4#&#1Li)E96PvI]KFp%ibWX-XJ[&HaM=?)gX=18Hmrt.bBV>Pm%@D3[;t+;x<OV?F&%01xd/*#[id(#dcv6#bY5<-`_IaEbiP<K`fYE2U'F0_U?]&M1)`3_COE_&m_P&`X^`l8*QWNtNmt(<b(nY6*Axg%.i.^Zxb542EaXc;ulFNB&KuVfdWa2M]5Jg<Z_ZJ;#qZJ;@60'&+?tQjx8;8MV]=O%'i'21->&6(p?N)#'[b6#)H[i.GJj6#mL5-M2?*mLk<*mL(X$lL3E3mLoi?+#h:4gL0HgI296pt-gr:)Ft<i>$X*AK)-#&?RwG2J/?Jt5;IrO]uf+wi$4u@J1=%Mm/]4/,)vM:D3P?DP8m-LQ1v4M'#S$c9^Y$wLM,bdc*Ws0<-$Y5<-aN:=%FHb;1Skv##?ocs-&TJGNa6wlLh`m6#8wK'#hr+@5MKMmLVI$29hLbGk$YJ,&&JZb+QMae*OS#9@l+w<(4W(,2_2MY5FpQs'sDZ6#PTY6#Ioq-$4lnPhDUL).On[e*a#v9.S,m]#*`D<-6#qH+n]XV-o$=BGm.P]u]W&>-rndi$X2DY-:s=%@+<X=G$>E4AW$AJ1e,aDsEpDE3+b.-#l_p/`-N]Y#r&=;$JFLS7&j0#?Da]p7@<Os%WBU2`@0q&$YbsH?'W$QM+MDpLpAm6#FM$A/2s+@5nbqpL&<0s7,;o5B''d6#]5$M&7B-=(O2Jj`Ede/&mas;-cBf>-`KVm$Bq@>#H>eGkmZAqf4Zin8<8`D+]]q]59E4m'hkF59o?169aJmx=G2iEM?UW,#v+LU-r,u78(;*W%m@&%+3>/DT=fY$6%G061;m-_-&&f+M0-[8[j'Gm/(?$(#ciTP&Dd@a$?d%V&W[t9)_%;;$%M^]+G=T;.x/'<-AfMY$r%18.7Mb2_]UD0_8H/62/8/.,St4LU>vGt$i;l;-@g%9*IQr`$i7?>#kkjUIFwZIM%.m,*iT35/kki;-0%DT.kTNI3xtxmG-04dX^cp$&R1&&4/b@0u^_;@#mc3cMqtNl=.Mn(5f`_+>2]<D5_dWo:arx6:iftbr%bTDW$3KMTs;cfUe;B]k<j61>;rIN3;d-1>-fj/1<:pF>2$0J=lD.;m[j0`0p,Uf#Px0'#o[lc*#74t-PT/bE])J9&&>uu#`_k[$GK#X.0Adg*@FS=-1S]F-NS]F-vf=(.I+R'P:fit0c>m6#Mirvn2iTnf_q-c*QT:?-_S2=0i[-##NbPj#1):'#]00/`)E)t%udf8.Wk.j0`ahD<EtGg)9L2d*(YNQ/%7#ttX_rSRJF3g)nv'pAjsZ&#H5g9;u2U'#FoH;h)F5gL_6pfLPl$(%IYfqh<D&:#90x8J>:0v5rdeIDv#'/i+cMj0%g)`#g[)x*YDrL-Kw?C%**v.%rFh'#00;,#Qv?C%^Ev6#M#14&TP>>#4icID,JG.DFRlre.'<H:T,>>#;Uv@Fg@sA41:NP&pBbw'OGuu#pDth)GVIe%UtgVdCW6R*]H&AFlLW&4Wo-g)EJ_8.Rk.j0N$H&#uNBI*bmH'X$YV,%th))#YU^%O&`d##qmse*V+Q-M?GPGMp9MhLa=PcM'X?.q&sglS1-PC&0ZrcE9#qM(#(Wa%'H1+t(>9K/j^nw#DJM(=Fg#RESrVG2`&fLC$1U^#(A@w#c&$[J`kmi9#%EE%w)loL'A_j*+r3R/p1tM(,K:;?Q<I]%Qjw`$gf?a/X17bO%G(^%pN?^RHim##U)YR<5Vn+VXN2p7*/O)N]WR4B9bipfFGC/1ws[Y#qf+iCNm+TUB:Ps6#>Zw/Mdxc;sf?iKo.k)F8+[VH1%<-m5T^uGaB898MCQ1+kKJf$LG:;$u(b`*l5r0:oZ^FE*mbA#WMm&-NP-h*l%X505mX+`_HJ;Hb+aKEwwSfLOWkM*gDm6#`C5QURXvV';>dv*sLUHM2.L4N-nJe*%RKv-e6b(NKgF&%5a1d2Rui2'H#e&P&b0)WwpuX?DVvrRV@o/(GXkcVANxX?_Mpr[V@o/(X8OE$guRe*kNND>ljUaO$4fnnK+blAOSHT%)f>]O4t5_AJI0,)?gA$MUpbA%fqWt*J*wa-wpY=?M>UB#2nVrQ*]t(s$cnf*Sfv=-plo4rGwmi9#t`M9'wk6/LH7g)u;e79aMb2_7<K8ID-_=?gj?5prxee*QfVU..8CN$tmo4rJ#7s*7Hp<-/no4r<UCQ$4Bt9#5(V$#;[_=?d/:/`FUQG$m=Xa*a<1A-F(Kcl`qZY#_OU(jV8M8@2:CP8:'At*E]+:9Z'Jib;:Ps67u4Pr>o$>o[8Z6#W3ki*??q&$+;###]`?mM$gP;HACtX?tvO#$cpbA%a>(2#=n.1$C#85D5AJS#w2cQs5K.;6U-EZ#e85i:9?gA#u1g*N0Frd*RD$*5ih8*#DU+q$C4i$#g0l6#./5##b]m6#,.r5/3r+@5ns,aN7KeaN8KI*N5(BK204N?#b3uJ(&gKc+bhqo.^_)v#w.-Honp+G20aP7nf'h,o??k'&WPFA+O5Jlut30;HTJb<6wZIhuXw8sN>.J`u0pe=P^;m?60bYfqLLvu#mRNiKF5-W-1V-F%@p;G&M;YY#1aTP&4_d;%KX#<-1M#<-pP^OPALM=-ZaOZ-]<JXoSXH##dcv6#r66KF'4pfL?L>gLR9MhL4?7*N8KihLJAiI2rujh2xm@X-.BF:.9EsI37w3e$gv69MG=+F3>HF:.uKx[b%p^[usKf(M<S9X#2=S(MDxp9$%f5=j3?@X#IdY-2Bg+tl$,>>#qaYipBoPp.eQtG*r+j2/%####q/>wTcCT:@@_T/)mcMQ0h3iZuh2jW#P)-&MnL6##'CJ9$:3ex-ujQiLAFT_-I#2S&>w^>$$e-^#8dEv$Y1)H3$7gfL8&grQ;3$H^HZ9<++C7gL9DH>#FwhH-bN*nLH/gfLb=PcM[2uo7AF#L2*pXV-?SlYuc_;'kSGL;@ww3,N9'I:2I6e,MKD>,MQnUD3D>l-$xQRvnXviwLvTNNMsg6##c+&9$m6a<#^d0'#$x*4)i/mi'[5e38s_Xb-c5Z6#5p4[nUMQdjM:'&+X4,oA-OGH35Hrc)`2n`*H,Rn/i=aX.MLKg2CY#<-%)e&4sbcv,%r$##UW/I$.ev(%MMc##PU)##+Muu#3^BK-<n7Y-HwL4BN$h>$.x(&0BVw;%(vD%$rS4ck9nJVm3Bur6`2^3Uma0v>PG8>,'][6#S([<KS8988A`V8&E'Nu&shuu,-E5g)0T0<-4Y5<-<foF-af-]-%GKb7JS5%cC@1^#hP5j`RH(5oBgF^,q75V-`X-##9gnw#cS24#w;E/MZ-p+MwAD2%C9Xb+415##`qkV9x>fBJrF3]-vdU.C/j?g(55n0#7+;YPggG8@aG`c)P2m6#-P5W-H78W]8Z7.MkQQ##x$H4(+GL8.Gq[P/+.GA+u<9=-9mh%is6,</V%s8$5WpkL?Z@4_wV_3_^mj-$kcH+<H5'XU3MU'<]^%T&G;1QSEnhH%P]?h*$50=-&6onRd_$##m3GB$6[m(%N@%%#m1b`*j*6?>4n8aYq%oZ(PlJR-^[6c*mM>#-]OhF*KoF&+F*x<-#lhl/Q5H?$tYr4%C6J'.Qp1f8(-Ts7XF9:#W'&X7u1'&+P,mi'i)]V$NnP<.]7q%#LKb&#45T;-D5T;-T5T;-e5T;-u5T;-/6T;-?6T;-O6T;-`6T;-p6T;-*7T;-;@pV-IQ3hPNUNb%YXr-$RZr,#u5UhL?5'j0=b($#]dv`*U)QX-I[XqgYhM;$t4U1Ce@[?$6fMJ<^H9(6Sb3N0==BV.89f&,8He.Mwex1(84wW-P4B*enQ*iC^[Ms%+sg-OM=$##aPZ6#UQp20x)fI*m[fC#H.61h)MH?$ZCSM`%YT@MwU/S[*Y^GDql),)vsai0O*^6#7^Z6#8>pV-w./`=_voQ0Ko08.82e4_ar#?etDZ6#ATY6#Loq-$/dd6#qJY3&K2hm8Z+ds.[LZ>#9iMf'nmg3*MjR,3mkAau64G>#:#]d#RaD4#;v0Q9nt:%Grrl^$Y#9C/U(*)3Uh-QM]rJfL83Rbu&Tn8#ER@%#(:xr$A=.S([wbf(l%(&n)Rd&%p=Cl%Tc:;$cJ*XLbZ8%#^,eh2(>`:%?DXI)#^c8/I,QA#G&9f3w_H>#E_-s2G8w4'kV`%'9Ro'?AJET%6XD^4ji4kO[WOi01I)##789a*rhNq.D>2/(H<5qV2B&UDB+G?%li/J3[YWI)*)TF4LxUQ5AgMA7$7WB9=axO(A/o77.$-M;7TuO3x8p'5^h8e?O?lu>j>Rlf$6SWoqnZ>#JB0##8>bA#PVCxL.S?>#KN_iprRLp.1xd;-iCYu^v9@q$vxe+MMOD,)Z*[;:,61'#V_GR$HCOGM6`d##622E%$(j6<TA>>#:DEl_X:FcMd@3%A4/G$MW*+-:BunK<X*]S%BK0=-q-NM-x<NM-oeB%%k(b`*Uml/:U3h#$tCd$GG^T9.v]A=u.ctS/-<&<%<TZ`*?/$<-'7NM-]@oII4[ha'Q/uR%mr1X-w:#XJZ@-YuCT7@#V-w(10'dU9s:_^#f2HPo,)A3`R_Wk<cUD+(1'-Nii5Jt3J#,YuM,6V#1PR,.nQ0#$tB:a#+&S>%hYm&:p6]wBS,',Dg`%)*P2m6#-####`PZ6#KTY6#3Klh'hoJwB<ZRD*ERM8.]CI8%5scN#5HUk=5Sr23A@Pc-D)HxG6@[(#7+CcDs#c7nW-cc)]Yv6#-/5##4+l?%YY>>#ACXS%OdgG*Apt;-amU]$#-bf:5:Y#%;ntD#+87<.@j5mSD8+*4<,H2C2EjO1+]Ff2[bj.+<_x6/Z&pI$v5wV:hulA#AeLI($AZWS]eZM9O0MDF:hOR/xqxXYxu*/C%TeC-3wW0*c^:U9)S?>#*@^ip,8Aa*>-Yl0Nuh<-h?J[-qiBS.k$R%k*td9D8qc7eo&.d/Pf_0(78Pdj'L/=-5Y)xJhf8o'2?P>-%^+x-`>uu#_Fdf_rB1dMUuou,4BU1p/Rj/2#Z6iL^=i2:xuos7XF9:#U?G)MU=oo@3rno%<5D)+GbL50WGUA5h-_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd,k[5'MKao:$dgJ)[8_5/MR@%#5KNjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%M9vS(%?x%Vm)r'^#E2av-$0rr-8cmJ)oF%P&5pC_&KnL:#JZI%#BHAo0T;F&#FEX&#c]m6#J'+&#^,eh2#IOv'DRHC+CfxQ/TNl]-TbQ42guV8).hBk-Za2O1Cm(Z-d<>X;XWxr1'CFM$unpB%46>##3PWnM23x.2S#.*.WTE$MF=#&#Gr+@51;qU@E<bi_TA5m'I4:N_3`YY#CX>>,_<-<.g8u6#?L^e<,UgJ)%v+^%m@c,M.C?of'xv.2&CwG3XMp>eMeJkr`s_k89=3<%#.&tu.c2J)EMF_f;q+nawn5JC]69d*cWYO-MeLH-0B<@<uwrS&O?C#-UO=#-[=E)+Ao':ghGv6#h(xQ-&uMF(dRn/)4G6p8;A9WR$?>JUi]RJdqn`/Qh+'p7@d+e<^hHP/DZd(N),xe*F.,<-GY5<-v%i=18CP##D@dO('&[6#QLXR-3Jni$nvv%+<?7p_B4.F%k?j;-xw7>-*bKS/UBbgjr*PV6i/Wi%].e'&>V1X:u`2S/$^)5(BV0sfONW/2va_E#D:Ok'C07?$vBo8%UVmt$J)TF4Z`WO'5nt.2:bwt-bcRi1:b3:.Ql1V1hXnP)O*e(+83/P2q3n0#ZqmO]]ODD<LQ(,)m,u(3ZlL<-vP]IG^uqI;XN'/`MBMB#;.;;$ICsq8>51B#eMG#-h(d;-Fc>W-cr#Ze;>6o/wqGD4NgP40P-`p/h680QF*.e-<<CwKfjxu#w<7G;7=G##Ve%j0bnRfLgu*a*;YY,M]5Z6#eF`j=(ams%d=%t-vG4$M.?sFr;XN?#-2uKP/mE6va)5XLP32G#xp`suE^$Rsc?GgaPwqD.:bM8.7U:N:0AfU#V)[&/+7YFr.K^*I<(rf:)Am;%2,4@Rw0W7<K6nnC#t3r$o_ME%3oD0_1`U$J$gdw$;/#^?fcDS/mZc6#AtqFrix`8/XF3]-M(>F+oEY<-Ce?DeBDR&4J,,F+k'xf$D+'Z-P'Jq.:w@2#k^wKWgH?jB=Q?D*%40JL7<3a*T(><-Ympt<@vRiLht1'#[/Gs-*=id*'_c,DN*FM_pkjH%)9Gb%_?7p_w4Ps%4jSb.jx#3)rpWt*O0Hd;:*_>$xPp;-1V>W-**&wIMCW4-kbdCj*fUi:U@%lFT%co7g%mcE8sk;-9:T8%o/)bRf>sA#Sq9o-G0Gb%g.?>#%Gho7qvK#$6=];%O0M:#WCn`$,8TR.dCT/)9eAn8vhB/DK3/S<15X&+>a1KMQD;N$fD[@%,g,t$a3`W&gwS4&,3gi0gN8W-R^P7ASt.9&`_YY,VvM4/LBlGtfj2B8g@QgD$?>JU?ed;oHbMt-u7FVMGA[tLo]BE%5BY4/usn9_As3rTw5;F=oF>2_2blsSg#?9S78Z6#F*HD-21Wv=m8K;eVja)++,`jL9[Fj1Ijo*+(QrP9PWGhM46GPJOi:8%P1]o@/MNjL55oiL/Bad*jAZm/B0`$#([b6#pl`SCKft/M`H5gL(I-##dcv6#:Y5<-3`5<-AY5<-NgiI&jl*)*-6d>-(:[A-+Qf/&#7>j1D(%B&]okZI[5UB#uQvd%I1kY#MwjO:w>lu-YSuK-SnFX.(#.<.@9F#-ssdA5^T;SZQl4B+siR+Mc8jf:5Zr^fAMBP8-*;N9cMF&#1qrs%:DEl_ii1(&]Kto%p2X5'O>'W%<2^8&6f@:.:bM8.ZB7ej&2SQ$t7VQ#Lw(cu1%+GMkU;VZc47XC/npj_>IuG-MhqD.1AP##58=2_79GGIsx,E5TQ$:&9bM1)V=]2C?2^wMFseC#q3:pMI1nN%PA%%#'3IK<rtnP'js5N0:sdo@GH.%#g@=gLuw`m$*cO<qOiuNFUm]'/Yt%v#5EkM(#$5g)xCRd*i4=1)Ul%E<4Dd;%a?A+%x[?78a86D6mX1s086eH3>;9p7ojx=%X)p^+e4^NUaQ`$5F[C3(D@W)^PL;K*%aBE%#<4gL5?k1`<%ZY#Uap9V-^_$'_-V8_5b/bIA<hN)^Gv6#7/)U%mQ#E<I.5n(x^rfuAI>2?EeJVmq1S>21sc7IODu=lQXvu#1/Z&5u/LhLl+%ENFV&%#8@R&@q#Pg$.BnD_ev^3_rw@8q7>M-2EvD,)o*'b,Ebn&k.vN@tk<1+GOl@A4]kbD*k>,#-][6c*j;p],D*K%#$)5Yuh>//.s&%qLD1^%#s$A;$G:c?I^?N$#.r+@5SG%fM]5Z6#Htqd-:P`<U]i>>#b-++d%(^fLVZ(]$PmR)$$HVF=*W?T.eaQ.g4+jc2R;Cf=3iTC#rU$M1M8-t7r_@8%.#^7-b5GP29I]i-g;OJ-lK-2>k'AT&,UCF*V'6Q9A&ADpr<rv$&uw[u*lqF]rrGD/VM7%#6tj'IQkjj1;Q(,2cuxH:m,#d3oE,01bCa6#k]Z6#bZc6#a^4?-wY./2FXa+`4]>>#,V:;$.IRS.?J%a+Q0.m0:sG,*48=2_EM#C/03%I6*'@L2H_/Y_gUXp^Qd[^R*:)q8)rHv$b7Ev';-eH3TLI=7Y-8K)BOUJ)C9(QCCo[d+P&7tLl+2'#-V##,#U<a*Bm><-@[AN-*iOR-Z`IQ--_LmQInor6Sp<#h=#YoRZT/cVSF;/Dc2(81+b_K2jYs>2.MVQ&PP>/64-:C,$La$#B%P'#s)grHA%//(w%v,O%:#gL,7Z6#o=?L->;dT%B3Xb+2%###(>05`?a%B#]M@kX'%l**,cTV6+FYI)#0Tv-cfmS/vZQ4.q)iu.7p*p@$K%v5aVr27Zhmm'mwoV/]#)>5R2/S[OQHT/,<Tv-h?7f3-p><-)-me-EFB0D:$b:mEd$)*?SKAIp5Z6#&ZJsr%5kK,#$#sK&fec?Kd@(#I_?guvEE-v5Nc##Y_D>#qpZIM`+4L<^/7>%]X>N`xmMJ#i%E.%dmsf(KXXRcU6)mL3PwjuCs[)vQICE-mlq@eqB/=[Vr>X75gNm1Fb=Q#/-(O=/8Dm29P,<7_YIi1?A0BH06AC>0D%##:F?`ECcPoR=1Y4`tG')(v3Pr/ZBME4snZ1M24o_u%IVE4PXTU)LtU50Ku0@/?lC$#mX9b?'FX%$8D0##%w_?##jr4#wh%lu%Ci(v?Y*^@'QU-;SY+5Vi,:]=QMcb+QEIg)B=U'#%2PuuV917#*Qt:(bSvi'T::R>47VB#SWMxOCwP]+d7db*b?kp.415##.LPZ]W(jr?$uYl]=)>2#$uTB#l)b(<I($AFj]le=Mt(&P2l@Y-vMZ=]aL$##_AY+%jv+F%S@Ft.U'^`nvK'lo:XtK=QUZY#W@/K(0P4F7>/bo7515##^/kWoT_H##,r+@5g6+gL.j[a*U?,<-6IXb*g#OgL:GoD_^'We$+&mb+hbYV-V&U]=nk:Zu61oGnq6bOo8;fA#@lFB#aZ,K(B<AI[@V4=.[<TJ(>+Lj9B3*##`j<$MtQKxZ:8.A%WXD>#Y(b`*l5.6/SImV-2+TfLdoDR#J`JUu#M9Tnu6o3NLoY.%2'O&%d7>##>9+n%NQb8.Rk.j0v)601g6<2#(Ot.%H)bA%FKgVUR3Ao8HicR*N####tnw-%>YTB%o27C-B=sN9Vjd;%a[RR(FMa@XA>.8@)vX%Crq.[#C]R_#tf/&+Ma22(t<_</ih6c*PFam9?[d31fq9*PJ5gp24aj<&F8Z&:'p;w$7Xaf>O$n(HDP7BMQ(n.:6>;]b2sDD*WX)*%t6w9KUqv##=sdo@3/D)+Xnp>>+gB#$2G?W-rtYqTdoDw$KREf;mVm`6.l@79YikE4.UMx5$a_$'r6XO:JF3'61Uxt'tfM50/%N*IL#,YuXj(?#<f>6:i_L/)1n8X-M>-[75>nbPp:#gL/t&j0Q)c;-7?>O-L&+^%mfC0_$hM^2Fw+,%RA[1KON^DW*&5TmP9nRc:q)##&Ik.%=`^B%KEflL?oP29]l2HE-^OoR/CaWf?lVvu_L$##M&HZ$GEiO%H25vcX>$Z$$`Hg-q3n0#*@k(3h@wi'#m;gOpW-r@PV2H*%bGD*Jmc:%vJw%+P'M50WGUA5h-_M:xigY?2OpfDB5#sIRq+)OcV45Ts<=AY-#FM_=_NYd+eR5'L0S,DbW[A,7>`5/VR@%#>KNjLTb6lLemsmLuxYoL/.AqL?9(sLODetL`OKvLpZ2xL*go#M:rU%Mkdf+%H=&Vm)r'^#D)EZ-#'VV-Dq'B,ICbo@UT8gO8Hr-Mp=70`G@?>#L%]o@EArD+3>0^%c3K1X:-s8.`e[e4<*-M;Thn*5:$q1;9vxF4T_&g1wlwOcBj&7-O6?n0JGCGNOxmL42gS+4UFF`#G:.%MmS6Yuw?>>#0+d+#a_CH-)rWJ'it[<-0p*A`E>`P-d9sq/Z`<M('&[6#JbL`$n(FD*;>c6A2djJ2OZ(i')==Q/.$s8.3u?P1laNA,n?CG)BOUJ)A9CmCl$&x,d-j_?N2CA=n+5Yu0=.2.%(eIMhNw/XguDm$pB%dM*7aP-utgO.sk.j0i_w/)xOUGNS2Q)X$uYl]X&SB#=*(##J7lwLxaU^%dPG)1H%T*#h_95&07NP&QM=/`=1e'&*30w@Rg1*#<Io6#+c/*#dr+@5%ld.2Msn%#*ht6##91@-:F;=-^@;=-d'MeMFaugjxQM7+r)=r7w0,d3(o]n$B.$HT`[eMN-iR_#xH:a#wo'(%ec'gMs`A(8g>Y]u_n&WTkZ_u?FatA#4-==(S$vn*vce*3:h4pBXK9>GJ)p*+K-%K)L8Gb+3,lk0%5YY#7Ae,)JEm&+stLX/XW[g)X%r_,AKND#VRlb#[hae)ZTW`+Lxte)YTj%,9nS@#.oYwKHfEwKL6xu#fMiu5bnRfL`('j0f0xfL^&QJ(ZOEs-QlRfLtafB&r-;LF0'wa$=xUf:07Ji)]kGH37uIl#pQwKs.Da1%MqD8%UD/#C4B<xB26*xB9Pb2_DcC0_,M-uQVGUWf`&eh2:H7g),$s8.:r9_u21^,hKDp.Qi&&=#w[&]X?,MP-OEIM.f&U'#EU3W-hXBs9`8Z6#$oq-$YjtJ4f5Z6#7k%>-LAL[-;7Cm;a2Z6#AJNsHn*oP'$48W--FX5;i_$%CIbC@IRn']X^CUCjS9a58=XbA#R8UT.:bwt-+lB4.$w;s@]-;N;>WN#&SNr-MT]%0%CQ*]%np&V-jsI$.TXD>#bljA#svSZPMApa5H.u@5OD#E=@,uj@R$gV.q$vsux)eJ*MZR,MwD8#MxwJ_QnJuL'imJ)lxTEr$YRIX-3eKm;MUeP/nRLm;dH0<pSZ^=cPh/v-jH_38ou('#w[&]X&?qp9v5go%7bC)l1Ptmfp(U-2En+jBO)?v$%ckA#raxj/Ssdo@iK93(/OJs-s5UhLX?VhLE#a0('/sbN:U[A,UTwM1=V0xn]3*$#dcv6#8),##1cpj%hRJn3IBAb.k#O^2Pu?<AkPic)AQkmLenfG9V?U^#]Rlb#I*fV'P'849B9:B#E,>iuGBdhLS4tuLi,F`%3Nc##<Pk5;Nu'kLg?UkLrRrhL$SrhL)EIEN$nlgLbl&V-Dj&V-l,0_%1)D-mRL)qii&L-mr_'[>dF@&,&u2j(BAS8/D'+<-_;It/SjArQx,DeM6DK%kP)uh98$Pl9u[%(#]2G+%eHJa%P4=&#Zm-lDD4`D+5(:p/C6Yq']r00Mb<Y?%g>2/(b:c;%tvkG*$F+<-&DnA-KZGI+w8BW$BVw;%lVgb.r>l>-Hj^v-qpv]5S0a&5ZWo],(vU#$gLv.<Qo38n0kVFn,9T&=;BS&,74%]6Oe`/)BG)C&+@&sAt_t%v<$:>#$)5Yusle[#GtEx@<Ndv$bmpj_`6`v$ECKq@GQ((&;4<<-F=.b%:.3<-,*#O-_x[<<<dis%,$s8.M#sc%(u^#,F0O)Sd)?A4U0h&8stb_Jv.FcMJSGgL)XL`N?4^4&AO,'$^*dfCkdW#JWZw&/a,IH3H%t&$7*Lhp=DDCJq>IErl40B#5,PoL[P>&#3?2/(dI3T.q(no%*,2h$#w+F%XQ?tLd52/(=VH&OqaYgL'@]xGk_K/)j%kA#uJ)E<vA9vHMg5aP_jP#+nZVF=dZTR/Wit>/gAK*+nMYj)4:0p&on[R9:D1d4xnrW'd8H8/G$CW/AOMv@es_>$hEDv$CJ2N<im,x't$4X-xpOtU/Annn`>aX.Y&Z]o5q/K1tMlDSD.vl/PGYb+a^;O+S0v<.9)5YuoP.@#oNp*#I*1k$FTfr@DW.I,d3Lq@4s&WnvK'loX`%JtJxmX$UdV(vd_6Yu0dI@#7+d+#Qe[%#`/*=%g'nHQjqNP&:DEl_J0)(&_^TP&AC<W-6=G&8QaHl$e:;;$WmDF=gUV]fNQ_=%dl/&+2u39/UN#A#B6jPMTs.F@H)dju&0?Z5&4&f$naYJEvBHe<:gf`*m%###?jkG3@W.:.[e%j0cQn8&9Yp-QLG_ARoTqU@,5M4BX.`Dd*c@C#(M#/CU,jl^[ueGs/M&M%A*[QNBSI/rd&C2VJ('2BNbbc)Tc->>=Q>127-^02`4h'#([b6#=BCX(7(<<-'P=q@WAeM1hS^G3nZnp@U#M50%&T:g*WWs@$t'^#t8DT%G)^A+-fns.Uacx#h1&x?vD.oL^%R>#hZiH4],h;.(Tj>6&CCl:iZf=-d=@..,ew;-HqU/)H&#F+0(6U00D7-5)rSU/#Smu@3x002IxC%6@vm&#px-cVfx2QBp&DD*6mqv6<Ul##q%Fl;9x)dE*AvV%wkL/2fscA,g3+<-Z&L^=.]dG*uJtW6i=I=/U3#&--NMW/SKje3[dsL))g6M193x>6$b]NkB=Hu@iWcqKknfS%j,T'+2]iZ-/b27'9N?`,&*(q%VR$@-?]eM1$U-t9qgkTBs]b84w@uu#qq39#/C,+#^mou5Y-wu#TrE-dTVUV$cppj_)+$29>cti_/+]w'0aRh(:Ino./@RS.)F^]+98N59f2`>-^f6#6KnL50GI5s.O<eM18mG,*qg;,<-;w20J3pL_IRvu#])I;Lq#..kaGm6#j&BkL_6Z6#4&11M[`<B-@Z;E-)uaB-S1I20-vjh2w[R_#[B'o2uU]L(mR$p.8K]=%_]B.*(_Aj0NNv)4u3YD#bXgfLxkQ1M,oKb*94BW-Qeow'uZhiB9F8`,9vrW/9@/`,hphE#a-3DHQb2C+d-MR>'*Z(+XqP^H+GGi(onN0;ae=PCp.,M(Mk#>Yp)*T/4':44pY)V?4=Ps/Y=R^A05ZS+&BJc4Xsqf%-J:?9dUg'+8L'lo7Fdq07fnH5CBe(#C2[4vIwD[$$8>##NN79_qD_3_c&k-$#Y_h&t:`K_Fw1^#PsAl9]MF&#:?]5'-7)=-1O%:.xWa+`YQdA#D'i>$qH;`$)>f+Mm;kAFTarS&o-k5/dTSX-.%TfLW*E.Nmc3>d$X&.UT]KY#$YI`35u9cDlR:>uOK,Po,J_M#8L[.1#sl>d?ul5/G7oQWbpZF#Z5Z6#a_b+JJss#&Ak%u%X:tl$ngcj#p1/Ltg@&=#BiIxdG=cAO.FOJ(H$9PJXYt&#?f%j0D<O(jdB&8ovU'^#49Gs-WR-iLPikjLWtQlLh)9nLx4voL2@]qLBKCsLRV*uLcbgvLsmMxL-#5$M=.r%M`'(q@.GEjLh67>8&ps/2''d6#E.m=&fw+=(fw+=(m:SC#,p:9/.QYx6vx:u$7,m]#c)7d)2:qR'?dBB@98Uv-AP-W-#)Z$0#8?_/%T/G4SwC.3o-no[[lwm:w%,$,fHNr73]AZ$@`E(=bFk^#xa1o0HL:E4fP2B#+YEJ247]V8cYHt7il^F4m)&T0&B:$72MGK3jx^S.sv9uAJw2b=;$4D+0nNb$sT&Y.Y4&-<739],2)@F<e0(q.g>NG).QctA]Alk<=XA[##*'Q2X>n;/EErhLr_$t7^_/fN_fI(?Aqjb=.DH>#9Xd(+84(DN`le`*^5p.$=](##Drl-$G6+##W_$##h7(##)w%##ak$##TD'##9E&##J27b3`]'##n-%##)_%##Ox###`P'##8fG<-c:Fg2*R%##eR$##+P(##aB*##'*k-$+h*###,(##Q^&##gVvp/'.%##=s+##Ds?W%u_N4#ITg5#9G'=#E2w+#Q#66#.MC2#'vO1#8.73#MTB5#1T@;#1Lx(#^SZ6#pgD/#u,j/#@4$RE=@Q.#WuE,#0;l-$,>k,#6f-F%a^r:#:fu1#<:E_&`VJwB?8*7#im<$#w0k^o]/^0#Q0]3#:TY-?Zq59#mu66#g$Ww0w9<kFJQ'_S%&5<#/OB8#c=(F.Q%O7#prh5#u$uQNkL.F%*(j2#h5P4#[oWhLBfK=#ou-_J+<m)#tA3wgPl[6#eP7R*`S?wT/,B;#@%%&#G.W9VqQh8#VL-1#WVZ-?8m7R*io?wTuUI&#80;-#a/aE[-;sE@dra-6^)p##m3LwB%+o&#o>_w'2w0(#pA_w'/bb'#n#G_&Y@T+#u*h;#bW1kX/U='#m^/F%u*;_8(wj9;OhZ<#nVaE[kj7kOPxOk+JCjQa8D[-?A:5_A/vx.#41b*#t1sfL-(m<-exhH-4QZL-Bb[u/At+##qQ'##Yr.>-n?:@-RA;=-wwsb.YT###[tqh.o9'##B%v[.YH###WH+_.hm###t'l?-SgG<-og3j.+]*##Hvre.>9(##*lA$0>/%##N^(##83RA-jT]F-hA;=-::Bc.1F'##e><J1E#%##bv(##TG%##<X_@-hN#<-q)m<-?S[I-NWjY.BP*##i,NM-2AFV.Ni*##wgG<-hcP[.7j)##M`Nb.hE(##q,f'0TT$##v`%##Q@:@-=uqh.SD*##PteQ-3cDE-V4_W.lw'##9t:T.X8*##RMx>-7O#<-$'kB-eZKk.'<%##&xgK-GD(h.8i+##5(c00E/&##s_'##OB;=-3?9C-#*LS-I^AN-vX_@-$m*J-?dP[.r:'##1Sgc.R%###gs.>-h$u_.Pk(##oAFV.j^)##hgRU.nb###ln+G-N(c00Z#&##D8+##>LwA-ahG<-BZ?T-%Nx>-NK,[.lE)##8Y_@-374R-2)l?-;aNb.,w)##N`BK-Ol5d.c_(##i2QD-Ir-A-PZV.0Ol'##X.(##=bCH-/[`=-[m:g%%^Z(#EJn8#if53#XXK:#D-x%#Pt60#a'q:#;A]-#6rl##&nd--7Dw(#1)bjL;ve;#f,O1#x?9*#fXofLBfK=#f,k-$gJ8-#@oTkLi:s7#7Xs4#uHcgLv>]0#,?%iLSv56#v7D_&X<-+#sgpE@1Li/#+/b9D`A>_/T8C2#?op=#sG+1#@J=jLpt49#?wjEIHSD_&V?@;#YP)7#Nag5#L(Vw0.h/%#4?2hL9'xU.esA>#7%kB-(;/70:C@>#n3E>#_Al-$4KF>#Se]j-+f.F%8WF>#7^BK-]65O-XtfN-[4`T.jgA>#WqO,/fXD>#_)l-$1AC>#*?:@-q?FV.OdF>#$eF?-@e2m.:qE>#Ae2m.%*B>#H%kB-sq.>-=4?l.7XE>#Wpon.7NB>#eM#<-qL.U.H'F>#n#jE-R%kB-0Z@Q-Bk*J-hCsM-`pon.uBA>#Fk*J-s*Yg.r4D>#TnM2/X7@>#;sl-$PcXG<@9wc<7u#d<x88)=$T+E=<pS]=$QP8.v#px=&^OA>`em]>SSY#?&F1;?Vh7Z?5Whr?C/L;@<,6W@,sdo@(LSs@#(*5AGSdSAU-'pAJtf5B@A&2B`W^PBK)D2CQ9>2C@d_MCSWCjCb#u+Dl^10D_6UcDM=q(E3`SGEEL5)F&Qn`FG2X^G[B+;H3VbrH6p4WI'q^oI*P_SJ1306KnQViKBZr.LTR3/MD)QJMvCN-N9NK`N#Vg%O8tcxO[T_]P&tL#QYK@VQ6Z@;RLLYVRw,<8SR((TSA>p1T-jSPTL3W2UVb1JU*5U/Vs&.GV*:*,W&5HGW>/hcW0lM)Xa]&AX2@xaXIp]xXZ->YY85YuYCu[YZC)7;[F:XV[n(+9]I'3P]_:j1^6,JP^O(gl^H=C3_wiFf_Lqb+`M.Cc`NO$,a3a]ca@W4Eb4d;]b4xr=cG'=#do:o:d&rVYdpo$<eU`0Seksg4f@9PSfT#dof;<LPg1#elgrCAMh4>aihF+BJi0CYfipb9GjfOp(khWv(k(QW`kC^<&l%(2Yl-)5>mHH]vm=]*SnheEon.TBSo;3'5pe`CPpvC`lpq8u1qxU@MqN_40r9tqFro'7cr>1R(s^+8Gs+DNcsC>n(t^HUDtpTj@to8@at'_/]tKiJxt?Cg%uv@+Au=#4$v,,Guuq05##$:P>#wd6#59ClY#cL1v#+UL;$U^hV$Zg-s$SpH8%ruhP/`$eS%j,*p%0bV8&T/'9&%@aP&ccKT&tH&m&%).m/LQA2'BY]M'B5T;-cWjfLIw(hL6jD<d9Vn<?TCu$,g9UhL=C,1UjKqhL3(wn]lW-iLEj@iLspIiLGvRiLP9T%urxH21t2wiLISiJDO<)W@:(C2qc4MdE-TU&lVirW%2w?'5(p&kLA&1kLl2CkL+9LkLMU$Li/DgkLKQqkLg]-lLYajXe5iGlL@hVf<7uYlLU1nlL4$pfN;7)mLTs5N)>IDmL22o)Gd9RgW6F]B-Dn%nL4R:tSG*AnLh>TnLsB^nLWOpnL-T#oLgb5oLg<]u83Uc7_So=81K$[]I.mnD$ZMhPMk1h]nZGCpL;SMpL(YVpL)/B-#`fqpLVOoQ2]CGw/cx6qLN/AqL35JqLr:SqLYA]qLRNoqLjRxqLl_4rL&g=rLCJ^xAqwarLh/lrL,<(sL.A1sLm]f;:HP_/>4D5aR#RTsL/`_sL)lqsL7q$tLmw-tL1'7tL]2ItL3:RtL;1:I?Xf/IZ/EmtLth,c.2W2uLac<uL)DbId6pVuLb+kuLk1tuLX@jc[=DAvLuUTvL:x8WVBcovLcp#wL@s+qE)tu?(G+GwL/8QwL4c8eerEv3Y?&VLHGm&(gPbCxLg*_4PSt_xL/$-AUV0%#MU,sM6X<7#M3JA#MwNJ#McUS#MxTS#M,O2Z`Z@rAhtu])p_ZIBL;q)h@d)F$MW/G$M@5P$MmD>C1g;b$MKGl$M@Mu$MnS(%MIZ1%MDfC%M/P-uspr^%MF#`%MA.r%M9M6j%t4-&M>B&8uu:6&M.I@&M*I@&M-MI&Mahi8G$Yd&MJlw&MMw3'M9/F'M^jwQQ,4W'MtEk'MXKt'M+-;.91R/(M].5.^3_A(MDxO:c5kS(M1icx<7wf(MB/q(M)3$)M#TO;5;95)MJG?)MGO2mR>KP)MeVZ)MO_d)MPem)M[iTT?n:JTZbwOarF&D*MZ3N*MO2N*Mm?a*M84i$FKDr*M.fKIC.9AI_VEK%4PcI+MYL8o[=RH`EZUK`NwP<`sgcR;6X7xfLb8Hv$Km6s$SwQ8%(*nS%F<N5&TDjP&5M/m&2VJ2'T_fM'cq]G2Sj+j'vrF/(_%cJ(q-(g(NYlS.LA_G)1C*j0jJ$d)'R?)*=ZZD*-eOd*Jdv`*JaG)+fq8E+4*s]+IhA,2/58#,(>S>,BFoY,3O4v,G:0?-Jk0s-CVjfLMD4jL7gnJV#NEjL=I.??H@]d<&aajLAkkjL7ptjL9qF3L*#0kLx+:kLd+:kLd2CkLE>UkL8Wx3U5vLej%2d@-q&/M)t=+&u6lGlL5vQlL?Dl(Pge]A$;4vlLk>*mLiC3mLcH<mLh7wAQAXVmLMbamL^Wt5_DkrmL3Z:t83w2*cG'8nLu/BnLC7KnL*^k*G1TCODLEfnLLKG[nOW+oLY01u]Qd=oLph>oL-tPoL.+doLS1moLxDiiW=ERP`sw78q9mPvA]PLpL8a`pL*mrpLbaEw&TK[EHd%7qL/.AqL[5JqL>NC_Idk(x/jInqLTLoqLnRxqLw/JRrvX1.lkGI:hpnNrL=rOrLD[//5/#T`RM.j`@u6'sLcA1sLiF:sL8MCsLWQLsLTFNmN%[^sLEehsL5lqsLBr$tLDw-tLKwDn<,0HtLt5x<C.<ZtL'KntLrPwtLeQwtLv'c1#3Z2uLge<uL1f<uLWkEuLlkEuLISV%KcK5J?9)juL]3tuL1NC2>;5&vLc8'vLU*qJ-<;/vLW>0vL3HK;MCv3<#QHZhLZ0nlL)vR#/QVwu#O+k-$6Q'v#9`&v#.[@Q-Q>Ps/Xa$v#G.'v#F3RA-v[Lh.e-(v#s75O-c,NM-q$jE-@ij'/6G&v#J]j-$UTsMU0x_fU3C./VhHsJVj;[cV)1efVMHffVZv+,Wx-N,W5Ew(W>(IGWV+%HWpWW`WEPP8.Pas%Xlh.)X8x))XRvBDXG-,bX?rS]Xx&pxX[05>YMZlS.49PYY2WjfL=pkr3Tw_xL7RvLmU'ixLIsp@qU#MA1:qZw'wOK-ZhmBwTv&=0#GFo^oSSJ,#JY=_8GFa3#bh3(#AKLk46-=w^70=w^NM,F.XX)##9;IwKc6s##uN4qL=3S>-fq-A-bX_@-,k)M-P5S>-@6`T.Ga%v#:O#<-n)LS-@hG<-AhG<-JZwm/fU#v#qx&v#wFtJ-=EsM-H*m<-6wre.[/&v#,sdT-Ws.>-daCH-l64R-rdg0/8`'v#5,k-$ms,5gs4EPgfdGPgfdGPgl%alg^Rflgm.&2hp?GMhPUTjhk$o+iO-4Giifsgi37Oci@J0Dj`QK`j.Ww(kp2j)kHZg%kTe,AkMthDk%nG]kSVjfL#eB(MvjK(M/sT(MV.t_r8$g(MW'h(Mf,q(M_9-)MA:-)Ms9-)MlC%;uhkiS?GN5WeIUj;5?NP)Mf5$TmCgu)MMC(0gG)D*M=-E*M'-`$+&QZ0B0n]E[m$31#U)L_&N4g-6f?t&#KNOoLUo-A-WeEB-6DrP-8_-&/3&#v#3Zo-$Wk%v#Lm*J-YeEB-R@EY.Lm&v#lp,D--QYO-[l5d.[=$v#:?oY-qq2F%;^'v#p#=;$d)k-$9D?;$gYB;$IR;;$Y+?;$dsj-$/@$Z$4_QZ$?j$W$wWjfLlu'm]&ma`sv1M/UTxxcjpL9T73P^J`^RFgL*J/<?/[Y#Y`_XgLd9p;mNmx#GK)@2hbkkgL>0YH;0&+2_gS^-6iS]-#/+N4#-$e--I$e--?iE)#gNixL:5X<#`1)R<h'_-6]im92mIdERM+R-HheFk4pRdER+8f8#.L5R*$ar7#KL/R3FtN9`Ec[w'>s,F%Sk9*#XN_-6[iWEeEaO1#uqJfLTvsb.+F<;$pcQX.HE=;$CTi].+BB;$A0QD-vvsb.S^=;$_.PG-7=9C-qJ-X.V`:;$9RGw.`x:;$x@m-$1P?;$]Al-$=Xn-$,s/m0*o5m0,s/m07FQ21Ybq21A*fJ1pGfM1C/^j101+g1VWjfLC9LkL+]qKiq/oe*1JgkL4PqkLYV$lLV]-lLQ^-lLqb6lL=gvXR6i>lL^oHlLWtQlLa$[lL^*elL;3nlLpa3Ad<7vlL$9wlLJ>*mLnB3mLZl4sS?I;mLb=6B$@ODmL_^tS%cLa'#;*69#*j0%#>590#$),##xx4>#ca1rapUK97n=G##_0)mLIqE^MJwN^MK'X^ML-b^MM3k^MN9t^MO?'_MCfg9vZ?:@-rIg;-u[Gs-qEKsL+rfFMUw`V$`H<;$_)^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$/<Te$>+g&vDWCv#c$H`-MF`e$lI`e$mL`e$2/BL,w9X_&@%<VHg-*X_x(f+MXQQ##2N<Z$qb<qVuZV.hM&@MhN/[ih?)wW_CK*`s]v.Z$-?Y0.QSIFM+=aM-'OA/.^=4gL$^m>#*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;->x]GM%NYGM%NYGMOmMv#%$3Z$#C&j-]`/eZ%;+,MOmMv#%'Ev$&'Ev$&'Ev$&'Ev$&'Ev$'-Nv$vB&j-ZV/eZ#$S+i*9Ev$&'Ev$&'Ev$&'Ev$&'Ev$&'Ev$&'Ev$'-Nv$wB&j-[Y/eZWIWP&jQVv$e;^e$/?^e$/<Te$&'Ev$&'Ev$&'Ev$&'Ev$&'Ev$&'Ev$&'Ev$'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%'0a;%-TA<%Ipg4JcR1_]-S1_]-S1_]-S1_]-S1_]-S1_]-S1_]-S1_]%5o+MUg)?#,Ba;%-Ba;%-Ba;%-Ba;%-Ba;%-Ba;%-Ba;%-Ba;%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%.K&W%0W8W%V+(_]K,^=uwCF]uxLbxu#YkA#0rA,MLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMLauGMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HMMg(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM)g(HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HM*m1HMX/*$#EX$0#ZlnFMJ7-###SbA#+:HZ$f)55&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&B>^8&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&CG#T&ES5T&U((_]M,Bxtv:+AuwCF]uxLbxu^>Z9i)Ao+M(*N?#T($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&U($T&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&V1?p&W7Hp&?VR2.[cR+Ml&<$#Ic>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&>>>p&?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'?GY5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'-gX5'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'.ptP'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'/#:m'7S-n'Hmg4J4`G>#).6Z$>CE_&(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$/<Te$;G:m';G:m';G:m';G:m';G:m';G:m';G:m'<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(<PU2(=V_2(wB&j-fY/eZ^C@8%[df2(a/^e$+3^e$,6^e$-9^e$.<^e$/?^e$/<Te$0,U2(0,U2(0,U2(0,U2(0,U2(0,U2(0,U2(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(15qM(2;$N(wB&j-gY/eZckWP&u`,N(e;^e$/?^e$/<Te$15qM(15qM(15qM(15qM(15qM(15qM(15qM(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(2>6j(:o)k(Cdp4J2ABxtv:+AuwCF]uxLbxuQ'jEePMjEePMjEePMjEePMjEePMjEePMjEePMjEe0Vo+M#T8@#OC7j(PC7j(PC7j(PC7j(PC7j(PC7j(PC7j(PC7j(QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)QLR/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)3GQ/)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)4PmJ)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)5Y2g)6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*6cM,*7liG*7liG*7liG*7liG*7liG*7liG*7liG*7liG*7liG*7liG*7liG*?F]H*Fmp4J:l>uu#YkA#xFg;-'l(T.ax))#O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-O#;P-P#;P-P#;P-P#;P-P#;P-P#;P-P#;P-P#;P-P#;P-P#;P-P#;P-R5r1.eP7+MgrS%#uIg;-vIg;-wIg;-0%^GM5#p@#cN9d*J74R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-c:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-d:4R-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-E0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-F0#O-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-:=aM-;=aM-;=aM-;=aM-;=aM-;=aM-;=aM-;=aM-;=aM-;=aM-;=aM-C0:)0:g+:vcrn%#uIg;-vIg;-wIg;-xO,W-Xm]e$#q]e$/0)>5E*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9if*[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9ig-[9i:uo+M<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM<.+JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM=44JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM>:=JM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM?@FJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJM@FOJMo_G&#CX$0#piwbMv$,cMw*5cMw'#GMJ7-###SbA#+:HZ$&F6;-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-k;`>-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-lD%Z-mJ.Z-J@On-J(Q9i>(g+MlLXJM>YlA#lJ.Z-J74R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-l:4R-BTGs-3A^SMDQhSMEWqSMF^$TMGd-TMFWUsL39U*#K9WFMr'c5vJj_lgLs$2hM&@MhN/[ihO8w.iCYfQa0v6PJCTZe$$2xFM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM/$;-M7a:1.sLTsLipHlL<<$'vk3_M:m<$j:pQQ/;1f8R*oR`e$kZ$GM?ZGOMx0;+vGY`=->Hg;-?Bg;-McAN-Nl]j-,9(_]@e?ig5(7pJ,Cee$MFee$NIee$Le%pJMe%pJOq7pJ7vR3Ov=`S%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'9N1_]M`5_]c7?/:(S-pJ*qx/.r@xNM2qx/.r:SnLx:4-$Mk.pJ)h]j-/B(_]GM/,M#>4-$C]AN-NcAN-NcAN-NcAN-NcAN-Ol]j--9(_]E>j+Mv%A0#Mn@5KNn@5KNn@5KNn@5KOtI5K'h]j-.<(_]$][P&<CR5Ke;^e$/?^e$/<Te$Nn@5KNn@5KNn@5KNn@5KOtI5K(_AN-NcAN-NcAN-NcAN-NcAN-NcAN-NcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-OcAN-Pl]j-/<(_]GGs+MO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMO(RTMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMP.[TMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMQ4eTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR:nTMR4ItLGAg-#;&kB-;K,W-Ik]e$lI`e$mL`e$kZ$GM1HgnL_2m2$+ss1#*Ig;-+Ig;-,Ig;--Ig;-6<@m/B?7wuTuO6#7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-@Gg;-AGg;-BGg;-CGg;-Qg=(.(-08Mgf.)*E3Ei^p]^e$9ZTe$q^OOMsfYOMi0v*v4:L3$5NVmLqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM&B8#MX5Z6#_>0,.iTtGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IMi/E6.*5EJMo/E6.'tarLe1cZMk1cZMk1cZM=>vQ#j&32_l,<2_`WHp-L+;'okRJ'oO$CDWg0Q#$rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-4tA,M?PV3$m;aM_KRD'S,Il+M^=d6#H@#-M^=d6#<lG<-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-MrA,M`7lZM`7lZM`7lZM`7lZM`7lZM`7lZM`7lZM`7lZM`7lZM`7lZM4V`3$`gVM_TnK4.`a:xLaX`3$vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-4tA,M`7lZMO059#e@W)#(CXGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMBA=/MhpR`E,)Alfqaae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$fw.X_]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJM'Y7$vksjp#QGg;-RGg;-SGg;-TGg;-UGg;-VGg;-WGg;-XGg;-YGg;-]YGs-agPlL7E*UMQJ3UMRP<UMUkg_MXsgCMLvOD<d$ClfU_`e$tb`e$ue`e$vh`e$7Xae$MLLfC7hEGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[E3greWo8giAo]1g9MK-Qrs]V$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#s#*)#=eaRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMg9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.Vdaj1j<_1g3P_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$UT->55K5/MQINJMRRjfMUv7DkY=1Al+:-$$7pt.#xfXOMtlcOMurlOMvxuOM7XFRMB_W0vNLx>-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-K*`5/IH5+#'+ofLR)G9#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/tg,>5e(u%F;-MDF<6i`F=?.&G>HIAG?Qe]G@Z*#HAdE>HBmaYHCv&vHD)B;IE2^VIF;#sIGD>8JHMYSJIVuoJJ`:5KKiUPKLrqlKM%72LN.RMLO7niLP@3/MQINJMRRjfMS[/,NTeJGNUnfcNVw+)O[N_]Pgx*#Q^a?>Q_jZYQ`svuQa&<;Rb/WVRc8srRdA88SeJSSSfSooSg]45ThfOPTioklTjx02Uk+LMUl4hiUm=-/VnFHJVoOdfVpX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[*?28]+HMS],Qio]-Z.5^.dIP^1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Ga8iYcat(J`tu1f%uv:+AuwCF]uxLbxu$c0^#xFg;-#Gg;-$Gg;-%Gg;-&Gg;-'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-K(`5/q7L/#VF,LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MMxG4-v?V3B-PHg;-QHg;-QCdD-VIg;-`0%Q/:VYxFI.r`<t&8)=u/SD=v8o`=&jB#?<U1L,&%ae$CpQX(MLLfC%1EGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[E3greWo8giC+>igEe<wTt#^V$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#s#*)#?eaRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMg9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.Vdaj1lN?ig3P_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$UT->55K5/MQINJMRRjfMUv7DkY=1Al+:-$$7pt.#$gXOMtlcOMurlOMvxuOM7XFRMB_W0vNLx>-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-K*`5/IH5+#)+ofLT5Y9#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/tg,>5g.u%F;-MDF<6i`F=?.&G>HIAG?Qe]G@Z*#HAdE>HBmaYHCv&vHD)B;IE2^VIF;#sIGD>8JHMYSJIVuoJJ`:5KKiUPKLrqlKM%72LN.RMLO7niLP@3/MQINJMRRjfMS[/,NTeJGNUnfcNVw+)O[N_]Pgx*#Q^a?>Q_jZYQ`svuQa&<;Rb/WVRc8srRdA88SeJSSSfSooSg]45ThfOPTioklTjx02Uk+LMUl4hiUm=-/VnFHJVoOdfVpX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[*?28]+HMS],Qio]-Z.5^.dIP^1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Ga8iYcat(J`tu1f%uv:+AuwCF]uxLbxu$c0^#xFg;-#Gg;-$Gg;-%Gg;-&Gg;-'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-K(`5/q7L/#XF,LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MMxG4-v?V3B-PHg;-QHg;-QCdD-VIg;-`0%Q/:VYxFK4r`<t&8)=u/SD=v8o`=7_5,Ere;,W.O)F.qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$E.ee$pfPc;RvA;$-)WMh]&^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$B#_e$BvTe$c`k*v22'U#:Hg;-;Hg;-<Hg;-=Hg;->Hg;-?Hg;-@Hg;-AHg;-BHg;-CHg;-DHg;-EHg;-FHg;-GHg;-HHg;-IHg;-JHg;-KHg;-LHg;-MHg;-NHg;-OHg;-PHg;-QHg;-RHg;-SHg;-THg;-UHg;-VHg;-f1#O-]Hg;-^Hg;-_Hg;-`Hg;-aHg;-bHg;-cHg;-dHg;-eHg;-fHg;-gHg;-hHg;-iHg;-jHg;-kHg;-lHg;-mHg;-nHg;-oHg;-pHg;-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-)Ig;-*Ig;-+Ig;-,Ig;--Ig;-.Ig;-1Ig;-2Ig;-3Ig;-4Ig;-5Ig;-6Ig;-7Ig;-8Ig;-tIg;-uIg;-vIg;-wIg;-xO,W-Ym]e$#q]e$$t]e$%w]e$&$^e$''^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$E,_e$Av5VH*];,2RQaJ2SZ&g2TdA,3Um]G3Vvxc3W)>)4X2YD4Y;u`4ZD:&5QC*jLu+X'8PNbe$QQbe$QLOe?Vbee$Xe[e$Gbc'vlD^6$sGg;-tGg;-uGg;-xYGs-wCKsL>GVPM7XFRMN_W0v<5)=-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-K*`5/IH5+#++ofLcAl9#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/tg,>5i4u%F;-MDF<6i`F=?.&G>HIAG?Qe]G@Z*#HAdE>HBmaYHCv&vHD)B;IE2^VIF;#sIGD>8JHMYSJIVuoJJ`:5KKiUPKLrqlKM%72LN.RMLO7niLP@3/MQINJMRRjfMS[/,NTeJGNUnfcNVw+)O[N_]Pgx*#Q^a?>Q_jZYQ`svuQa&<;Rb/WVRc8srRdA88SeJSSSfSooSg]45ThfOPTioklTjx02Uk+LMUl4hiUm=-/VnFHJVoOdfVpX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[*?28]+HMS],Qio]-Z.5^.dIP^1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Ga8iYcat(J`tu1f%uv:+AuwCF]uxLbxu$c0^#xFg;-#Gg;-$Gg;-%Gg;-&Gg;-'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-K(`5/q7L/#ZF,LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MMxG4-v?V3B-PHg;-QHg;-QCdD-VIg;-`0%Q/:VYxFM:r`<t&8)=u/SD=v8o`=&jB#?<U1L,&%ae$CpQX(MLLfC%1EGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[E3greWo8giGOU+iEe<wTx/^V$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#s#*)#CeaRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMg9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.Vdaj1psV+i3P_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$UT->55K5/MQINJMRRjfMUv7DkY=1Al+:-$$7pt.#(gXOMtlcOMurlOMvxuOM7XFRMB_W0vNLx>-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-In(T.IH5+#(anI-6K,W-Qk]e$5RoEIp/DDWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[k8hiq(>#REP*QD*:#)d*bs?^P5h5fq=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1MW6fq5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Garfd/r1nIc;/-QD*:#)d*[N_]PVZ5/r=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1NaQ+r5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Gaso)Kr1nIc;00QD*:#)d*[N_]PWdPJr=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1OjmFr5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>GatxDgr1nIc;13QD*:#)d*[N_]PXmlfr=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1Ps2cr5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Gau+a,s1nIc;26QD*:#)d*[N_]PYv1,s=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1Q&N(s5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Gav4&Hs1nIc;39QD*:#)d*[N_]PZ)MGs=sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMRP<UMSVEUMVjg_MXsgCM+K#g1R/jCs5S_e$TY_e$fD9VQ(EjG<B+Me$s_`e$MLLfCutDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[;t58]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Gaqo`cs_E1_AC>_V$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#0F5+#d^QIM9a@.MN21&=1*.`sWe`e$vh`e$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$&vPe$C8C;$EJ*)t]&^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$B#_e$BvTe$bX[wukaoX#9Gg;-:M,W-rZcEetpkOMvxuOMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM&B8#MEo^=#OKn*.RCXGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMBA=/Mgf.)*k6d@tp]^e$9ZTe$raF4Mf+LA=v8o`=pX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[$Y=atach4J9ZDA+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-+:-$$:9L/#J[LXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM&B8#MG%q=#>s%'.haZIM;peIM<vnIM=&xIM>,+JM?24JM@8=JMc]Kg-9+M'SdGXV-/(lA#G%^GMf45GMh=aM-uQA/.KX:=M/8,,MHBm:$$nG<-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-4tA,MG?m:$uBCAuu%#RERRoi'20O2(39kM(4B0j(5KK/)=>%a+>G@&,?P[A,@Yw],Ac<#-?)wW_*r2X_n#IkXn#IkXn#IkXn#IkXn#IkXCo]]XC]AAuXice$wlce$xoce$#sce$$vce$%#de$&&de$m$1Auq9_]uk]xQEIP_V$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(jOB-mX-LG)=p,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],,/.ktnt6ktnt6ktnt6ktnt6ktnt6ktnt6ktu+4,MBL);$o7b]u>u7'oII:;Z%hTYZ&qpuZ,)%ktnt6ktsrn+Ms96>#8A]'._nBHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM4Bi-Mcfe`*wuNwTdhWwTdhWwTdhWwTdhWwTdhWwTdhWwTdhWwTdhWwTdhWwTdhWwTv.4,M8Q2;$dnpxufxgK-hRD*/:?$)*$'Oe$8WTe$.&oA#9S;qLDkj0v?Bg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-3k&gLmV3B-.$)t-f3UhLP;-##7Gg;-FrA,Mb8-##RG/B#mddIMHvnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMBA=/M%=aM-#OA/.OU:=M/8,,MLW)v#$nG<-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-4tA,MKT)v##e?^#>^CX(%w]e$&$^e$TV:;$bWaV$]&^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$B#_e$BvTe$aO@[uxOl>#9Gg;-<YGs-;bsjLFkbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VM#:BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.P?*j1QHE/2RQaJ2SZ&g2TdA,3Um]G3Vvxc3W)>)4X2YD4Y;u`4ZD:&5U[NjLR*aV$2Nbe$QQbe$eLKR*Vbee$Xe[e$Gbc'v<aLv#uYGs-C4]nL%slOMvxuOM7XFRMB_W0v$Y`=-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-.*`5/YV.H#Z(ofL*ZZ##'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/1sn_sBaHD*:#)d*;')dE5L=X(:bae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$xonEe]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMPC$LMQI-LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MM&T4-vU]:Z#PHg;-QHg;-e``=-VIg;-`0%Q/0QIfC(qj`<v2J)=R*F_&ue`e$vh`e$7Xae$/=r.:+CEGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[Wo8gi1)C8%3mR3OQfUV$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#1TfX#rZQIM:j[IMbnl*vU4)=-:Hg;-;Hg;-<Hg;-=Hg;->Hg;-?Hg;-@Hg;-AHg;-BHg;-CHg;-DHg;-EHg;-FHg;-GHg;-HHg;-IHg;-JHg;-KHg;-LHg;-MHg;-NHg;-OHg;-PHg;-QHg;-RHg;-SHg;-THg;-UHg;-VHg;-xHrP-]Hg;-^Hg;-_Hg;-`Hg;-aHg;-bHg;-cHg;-dHg;-eHg;-fHg;-gHg;-hHg;-iHg;-jHg;-kHg;-lHg;-mHg;-nHg;-oHg;-pHg;-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-)Ig;-*Ig;-+Ig;-,Ig;--Ig;-.Ig;-1Ig;-2Ig;-3Ig;-4Ig;-5Ig;-6Ig;-7Ig;-8Ig;-tIg;-uIg;-vIg;-wIg;-xO,W-Ym]e$#q]e$$t]e$%w]e$&$^e$''^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$E,_e$PM_e$QP_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$Jx?M0[:x+MQINJMRRjfMiX5DkY=1Al+:-$$.<4I#WdXOMFvv'vsfG<-uGg;-vGg;-9ZGs-:m.nL-[MXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM(bL6v2Wl##UpN+.`@XGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMBA=/Mgf.)*#`dS%p]^e$:a^e$05?M0DH2)F;-MDF<6i`F=?.&G>HIAG?Qe]G@Z*#HAdE>HBmaYHCv&vHD)B;IE2^VIF;#sIGD>8JHMYSJIVuoJJ`:5KKiUPKLrqlKM%72LN.RMLO7niLP@3/MQINJMRRjfMS[/,NTeJGNUnfcNVw+)O[N_]P#Y+#Q^a?>Q_jZYQ`svuQa&<;Rb/WVRc8srRdA88SeJSSSfSooSg]45ThfOPTioklTjx02Uk+LMUl4hiUm=-/VnFHJVoOdfVpX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[*?28]+HMS],Qio]-Z.5^.dIP^1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Ga8iYcat(J`tu1f%uv:+AuwCF]uxLbxu$c0^#xFg;-#Gg;-$Gg;-%Gg;-&Gg;-'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-EGg;-PGg;-QGg;-RGg;-SGg;-TGg;-UGg;-VGg;-WGg;-XGg;-YGg;-a(`5/%(hB#5?)UMQJ3UMRP<UMijg_MXsgCMLvOD<<P_S%U_`e$8vKc;#BSD=v8o`=7_5,Ere;,WY27R*qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)C>S@1c:;$Z6Rs%]&^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$B#_e$BvTe$aO@[u&i:?#9Gg;-<YGs-;bsjLFkbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VM#:BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.P?*j1QHE/2RQaJ2SZ&g2TdA,3Um]G3Vvxc3W)>)4X2YD4Y;u`4ZD:&5U[NjLVNxo%2Nbe$QQbe$eLKR*Vbee$Xe[e$Gbc'v@#rv#uYGs-C4]nL%slOMvxuOM7XFRMB_W0v$Y`=-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-.*`5/YV.H#_(ofL.s)$#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/1sn_sFmHD*:#)d*;')dE5L=X(:bae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$xonEe]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMPC$LMQI-LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MM&T4-vYu_Z#PHg;-QHg;-e``=-VIg;-`0%Q/0QIfC,'k`<v2J)=R*F_&ue`e$vh`e$7Xae$/=r.:+CEGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[Wo8gi5MZP&3mR3OUrUV$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-)(LB#1TfX#vZQIM:j[IMbnl*vU4)=-:Hg;-;Hg;-<Hg;-=Hg;->Hg;-?Hg;-@Hg;-AHg;-BHg;-CHg;-DHg;-EHg;-FHg;-GHg;-HHg;-IHg;-JHg;-KHg;-LHg;-MHg;-NHg;-OHg;-PHg;-QHg;-RHg;-SHg;-THg;-UHg;-VHg;-xHrP-]Hg;-^Hg;-_Hg;-`Hg;-aHg;-bHg;-cHg;-dHg;-eHg;-fHg;-gHg;-hHg;-iHg;-jHg;-kHg;-lHg;-mHg;-nHg;-oHg;-pHg;-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-)Ig;-*Ig;-+Ig;-,Ig;--Ig;-.Ig;-1Ig;-2Ig;-3Ig;-4Ig;-5Ig;-6Ig;-7Ig;-8Ig;-tIg;-uIg;-vIg;-wIg;-xO,W-Ym]e$#q]e$$t]e$%w]e$&$^e$''^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$E,_e$PM_e$QP_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$Jx?M0`Fx+MQINJMRRjfMiX5DkY=1Al+:-$$.<4I#[dXOMFvv'vsfG<-uGg;-vGg;-9ZGs-:m.nL-[MXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM(bL6v6p:$#UpN+.d@XGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMBA=/Mgf.)*'.&m&p]^e$:a^e$05?M0DH2)F;-MDF<6i`F=?.&G>HIAG?Qe]G@Z*#HAdE>HBmaYHCv&vHD)B;IE2^VIF;#sIGD>8JHMYSJIVuoJJ`:5KKiUPKLrqlKM%72LN.RMLO7niLP@3/MQINJMRRjfMS[/,NTeJGNUnfcNVw+)O[N_]P#Y+#Q^a?>Q_jZYQ`svuQa&<;Rb/WVRc8srRdA88SeJSSSfSooSg]45ThfOPTioklTjx02Uk+LMUl4hiUm=-/VnFHJVoOdfVpX),WqbDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[)6mr[*?28]+HMS],Qio]-Z.5^.dIP^1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Ga8iYcat(J`tu1f%uv:+AuwCF]uxLbxu$c0^#xFg;-#Gg;-$Gg;-%Gg;-&Gg;-'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-EGg;-PGg;-QGg;-RGg;-SGg;-TGg;-UGg;-VGg;-WGg;-XGg;-YGg;-a(`5/%(hB#9?)UMQJ3UMRP<UMijg_MXsgCMLvOD<@uvl&U_`e$8vKc;#BSD=v8o`=7_5,Ere;,WY27R*qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)C>S@5o:;$_Zj5']&^e$(*^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$1E^e$2H^e$3K^e$4N^e$5Q^e$6T^e$7W^e$8Z^e$9^^e$:a^e$;d^e$<g^e$=j^e$>m^e$?p^e$@s^e$Av^e$B#_e$BvTe$aO@[u*+`?#9Gg;-<YGs-;bsjLFkbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VM#:BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.P?*j1QHE/2RQaJ2SZ&g2TdA,3Um]G3Vvxc3W)>)4X2YD4Y;u`4ZD:&5U[NjLZs92'2Nbe$QQbe$eLKR*Vbee$Xe[e$Gbc'vD;@w#uYGs-C4]nL%slOMvxuOM7XFRMB_W0v$Y`=-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-.*`5/YV.H#c(ofL25N$#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-I.%Q/1sn_sJ#ID*:#)d*;')dE5L=X(:bae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$xonEe]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJMPC$LMQI-LMRO6LMSU?LMT[HLMUbQLMVhZLMWndLMXtmLMY$wLMZ**MM&T4-v^7.[#PHg;-QHg;-e``=-VIg;-`0%Q/0QIfC03k`<v2J)=R*F_&ue`e$vh`e$7Xae$/=r.:+CEGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[Y%KgiF<)#,^kk1BOHE/2dr6#6*1h^#/$:J#c'SNMhs&nLUOux#kGg;-lGg;-mGg;-2.A>-wx(t-6hHiLBJPA#AGg;-HGg;-].%Q/iQBJ(%tQ]OY<(&P^Zq]Pwf?X(7xs34/Bg.v'gG<-aHg;-&/A>-kmG<-lmG<-gHg;-hHg;-%a`=-jHg;-w;)=-smG<-tmG<-pHg;-qHg;-whDE-#iDE-uHg;-DxX?-wHg;-xHg;-GxX?-$O,W-`mGX(rdXOMoK)=Mp[=DWrk`cWst%)X)_Yq;nVYq;uw$YM-*/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYMCF@&MsfYA#^s[H#sD?$v&Bg;-d.%Q/0<]xF7bZM9jw'm9CqL#$kGg;-lGg;-mGg;-2.A>-wx(t-R7W'Mwk0KM5j0KM^vCB#4jR8/5jR8/7ve8/o'w?055cw9c<WJ:(4Xw9FI,,M`2%$$<V^21Qh9R*CBsjt2M2/1*`]e$*f>P8utDGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[M6eM1/Ap>Hp['#,G3Ej1xu^e$H5_e$UYUe$,bj-vFNQ_#o/)mL,/:.v&Bg;-jmG<-I`d5.qi=WMmtGWMh$QWMi*ZWM'7mWMtH2XMDUDXMW[MXM)6AYM53/>M[kK4.D*BkLTFg;-Z.E6.'YLXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYMCF@&MO7LkL*f&H#6.FCMFVOjLHZ@C#ex]GM(:LkLnGqE#ddDuLtd[_#fZGs-:S4oLstGWMn$QWMk6mWMnH2XMpTDXMqZMXMG$k4#^rX?-)nG<-0h&gL.L,I#0`eBMFvv'v;gG<-uGg;-/&^GMMnB)M^fX`WGH')Xt'ADXu0]`Xv9x%YwB=AYxKX]Y;VC_A+UL_A1:TX(&&de$')de$&vPe$Yggf1d$b`3XZI9ia1tu5*1h^#/$:J#%(SNM<9q&v6gG<-kGg;-lGg;-mGg;-2.A>-wx(t-RhHiLaFOD#AGg;-HGg;-VM,W-:*6_AcsR]O+%/^5AJZ_&jiZ_&3$,A=OF%2TnxOPTk+LMUnFHJV8_*,WqbDGWw<o`X=I%@0;KEL,/1KX(pT44M_nk`<$Ko)=t#ZY5We`e$vh`e$[^D#$]dM#$FF:@-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-30#dM*CSYM,H]YM'NfYM&B8#M^<EMM<?EMMeKXD#<ZG#6V*LS-<.LS-<.LS-=7ho-sEB-mZ-$,M<?EMMfTt`#<ZG#6Y<-5./;l<M6Mo(WqbDGWjOB-mZ-$,MgWt`#>muHM<?EMMg^9&$;T>#6=ZG#6Y3ho-w_p-6<T>#6>aP#60h'44=aP#6^F[_&vice$wlce$xoce$#sce$+xWYZ,-quZjOB-m[3-,MnmkD#*t[H#D^-QM3=f6ME*[M9&NVV6(9IfCi*C2:l3_M:m<$j:pWvf;3T<,<E^@&GB6*F.>nae$?kNe$%iTV6k,RS7/1*A=jcEVZUs(W7l?KX(P_=2v#5)=--[Gs-G0)mL:G1[M=YL[M:lh[Mf1A4vQY`=-J1]^.3W35v;gG<-Za`=-HJ)a-_Gv34pT44M`mk`<t&8)=6l*W7We`e$vh`e$*A1REpXLXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYMCF@&MA@6'$5S0K-kGg;-JqN+.`@fnLWWGs-5NVmLwZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM&B8#MRDnF#ms[H#.0x)vsq1c#ne]n.'Y42vG#)t-Jm.nL+g4ZM/#5$M9+3c#:nG<-7Ig;-:Ig;-AKA/.sSv]M#l<^MX*OBMU<Y0.gLxnL0Fg;-BHk3.IYLXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYMCF@&MrY,oLbe&H#46RI/04(3vrR+oLS)8qLr]>4Mc&1&=CRE_&ue`e$vh`e$P`C3kHObV?:$2)Fx@P)=RVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$&vPe$LO4;?0E0v?3x79AqI)A=7B-5A4C9/D*P`SA6qfSA@WlTA3@p1B7:_o[[wMe$DEOc;)HMS]1)FM_0kxSAr0]_&7Yde$:cde$:W?e?u%x7e>Nx?0(Q+DEFNcof`]@MhO?M#$.f%Y-U_`e$UWIfC.:NA=v8o`=pX),W08O#$qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-HcDE-swdT-5ZGs-_LxnL*6JqL^W`J#v,IqLgn(+$M9aM--k&V--k&V-6]xf.Kg0+$SD3#.dX+oLDB]qL[8wlL,#vOM()doL<u1+$(ZGs-Zl.nL,UDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM&B8#M8_ORMt`ORMN5)f#2u[H#pC@#M7*)f#O5]nL1g4ZM/#5$MH#)f#:nG<-7Ig;-:Ig;-1k`e.]Kw4v_qX?-$<-5.;g;^M_*OBM;Ib(MYmk`<*=:-mmx9DEhl[e$e,&qrV2%)W08O#$qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-(Ig;-Ju%'.:a;^MIqE^MJwN^MK'X^ML-b^MM3k^MN9t^MN6bBMOe`V$pu*dE_)^e$)-^e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$.6Ke$KQ8RE5di+MsoY.#LeG)FxJGk=2@Z.hM&@MhN/[ihFh+REKQ8REKQ8REf]C8%`dmA#*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-.Ag;-LZ]F-LZ]F-LZ]F-LZ]F-Mdxb-+X+RE6gi+Mtuc.#KbPDFLbPDFLbPDFLbPDFMhYDF4`xb-,[+REk.[P&xVnA#.Gg;-/Gg;-.Ag;-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-MZ]F-Ndxb--[+RE8pr+MN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMN((SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMO.1SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMP4:SMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMQ:CSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMR@LSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMSFUSMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMTL_SMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMURhSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMVXqSMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMW_$TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMXe-TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMYk6TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TMZq?TM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM[wHTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM]'RTM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM^-[TM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM_3eTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTM`9nTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMa?wTMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMbE*UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMcK3UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMeWEUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMf^NUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMgdWUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMhjaUMg^3uLDYkD#u)87Mr'c5vJj_lgLs$2hM&@MhN/[ihO8w.iDbxQEsD/AODVWe$$2xFM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM.qugLXusUMjvsUM;$l1#ihf`O2N1Z6`qL9iEh+RE)rL9iK$,REjV9REjV9RE)rL9itMJ]O[G[e$ihf`Ob(T_&++Be?b(T_&5vU_&jq+&Pkq+&Pkq+&Pkq+&Pkq+&Plw4&P2V]F-ldxb-IX+REkY9REkY9REkY9REkY9REUrs+Mk&'VM>6:M#0aDE-mm=(.BvKHM=V]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-lZ]F-mdxb-K[+RE:Lc-6D(HYPjpUe$$2xFM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM.qugL]7BVM=8BVM;&buL-22J#0sO8M]4RA-0sO8M3q:HMRwCHM/'MHM.qugL^=KVM>>KVM>>KVM>>KVM<,kuLj22J#>9RA-n1s>M4wCHM15RA-box/.T<SVM?DTVM?DTVM?DTVM?DTVM?DTVM?DTVM=2tuLIok0M?DTVM@J^VM@J^VM@J^VM@J^VM@J^VM@J^VM@J^VM@J^VMiVqM#?lxuQAu=;RAu=;RAu=;RAu=;RAu=;RAu=;RAu=;RAu=;RAu=;RAu=;RB(YVRB(YVRB(YVRB(YVRB(YVRB(YVRB(YVRB(YVRB(YVRB(YVRP9EQTt_MiTuP/5]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>Gaq[?NUEx-A=>a`1gJaCPgKj_lgLs$2hM&@MhN/[ihO8w.iI:_KcXj5JUIgZe$$2xFM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM.qugLl<vWM'>vWMNAn3#(v'jUxJGk=d)].hM&@MhN/[ihFh+RE';:RE';:REAFE8%`dmA#*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-.Ag;-([]F-([]F-([]F-([]F-)exb-]X+REhOk+MOGw3#'s0/V(s0/V(s0/V(s0/V)#:/V4`xb-^[+REFn]P&xVnA#.Gg;-/Gg;-.Ag;-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-)[]F-*exb-_[+REjXt+M*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM*P;XM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM+VDXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM,]MXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM-cVXM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM.i`XM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM/oiXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM0urXM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM1%&YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM2+/YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM318YM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM47AYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM5=JYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM6CSYM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM7I]YM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM8OfYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM9UoYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM:[xYM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM;b+ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM<h4ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM=n=ZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM>tFZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZM?$PZMHT(%MmJ,I#V*87Mr'c5vJj_lgLs$2hM&@MhN/[ihO8w.iDbxQEdd^%bDVWe$$2xFM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM.qugL:lh[MKmh[MIZ1%M.L,I#oaeBMJq*'M7Z1%MTkG<-cB#-MKmh[MKmh[MIZ1%M$f&H#oaeBM7V]F-oaeBM2hu,MZ`eBM5'MHM=V]F-L[]F-L[]F-L[]F-Nn=(.>h)'M@sq[Mu#j7#cB#-MLsq[MLsq[MLsq[MLsq[Mu)/S#KcY`bNol`bgZ1_ALU;REmA?2'L$,REMX;REMX;REMX;REMX;REMX;REMX;REMX;RE7kl+MM#%]MM#%]MM#%]MM#%]MM#%]MM#%]MM#%]MM#%]MM#%]Mv/8S#Mu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcNu:AcO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cO(V]cP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcP1rxcQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dQ:7>dRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdRCRYdSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnudSLnud'R8Tot_MiTqE25]+HMS],Qio]-Z.5^.dIP^/mel^0v*2_1)FM_22bi_3;'/`4DBJ`5M^f`6V#,a7`>GadTx4p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p&D)5p'MDPpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APpx<APp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp#F]lp$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q$Ox1q%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq%X=Mq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq&bXiq'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r'kt.r(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr(t9Jr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr)'Ufr*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s*0q+s+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs+96Gs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs,BQcs-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t-Km(t.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt.T2Dt/^M`tq]-Z6dG+REJgLPgwFg;-KIg;-LIg;-MIg;-NIg;-[h&gLS_HF#;+87MP_)vu)=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP's1f%u0gi%u0gi%u2N1Z6&rP9iKs$2hr/i%ub(T_&T*^_&/gi%u0gi%u0gi%uA+uJ;&rP9iEh+REErP9i2krS&Z0K9i4'S5'L$,RE1Z=RE1Z=RE1Z=RE1Z=REnH`.h#K.Au3&AAu4*^_&0p.Au1p.Au1p.Au1p.Au2v7Au3V]F-3o=(.ZXXgL%&,cMZ5?Y#C@#-M2,5cM2,5cM2,5cM2,5cM2,5cM2,5cM2,5cMY/->#1#J]u2#J]u2#J]u2#J]u2#J]u2#J]u2#J]u2#J]u2#J]u3)S]u3V]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3]]F-3cxb-jV+REId:5g=rLe$J=ee$K@ee$LCee$MFee$NIee$K28^#?xrqLP[vuumAg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-.Ag;-4Y]F-K@On-,+Q9iIj_lgvPeA#bxJ_&S'^_&32fA#L28^#4Y]F-WXI'M.OP,MBYI'M1e(HM=V]F-WXI'M:wCHMCV]F-K:4R-5Y]F-5Y]F-7l=(.&`v&M);>GM^A6##bB#-M5;>GM5;>GM5;>GM_JQ>#pHKC-7l=(._['HM=V]F-6cxb-kY+REv%o+M5;>GM6AGGM6AGGM6AGGM6AGGM6AGGM6AGGM^D?##5DF#$6DF#$6DF#$6DF#$6DF#$6DF#$7JO#$3V]F-6Y]F-6Y]F-6Y]F-6Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-7Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-8Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-9Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-:Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-;Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-<Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F-=Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F->Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-?Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-@Y]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-AY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-BY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-CY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-DY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-EY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-FY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-GY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-HY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-IY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-JY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-KY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-LY]F-TL6x/<nu'vW7bx#uGg;-tAg;-I:)=-JCDX-+2EX(J.OX(J.OX(J.OX(K1OX(K1OX(K1OX(L4OX(L4OX(L4OX(M7OX(M7OX(M7OX(k9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9ik9[9iTl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5RETl5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5REUo5RE`1$RE?.sf1DVWe$EB)GMK'X^ML-b^MM3k^MN9t^MN6bBM8f=(.i,BkL8N,W-^j]e$*0^e$+3^e$,6^e$-9^e$.<^e$/?^e$.6Ke$c@6REc@6RExZI9i@78,2[G[e$I/@e?xZI9iSA[ihL$,REc@6REc@6RExZI9i_;6,2[G[e$b'I/2b(T_&++Be?b(T_&5vU_&c0eJ2d0eJ2d0eJ2d0eJ2f<wJ2/f8_AdC6RELD9fhL$,REdC6REdC6REdC6REdC6REN[p+MdP6LM7aIC#0aDE-fl=(.;uKHM=V]F-eY]F-eY]F-eY]F-eY]F-eY]F-eY]F-fcxb-CW+REeF6REeF6REeF6REeF6REeF6REeF6REeF6REeF6REeF6REO_p+Mf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMf]HLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMgcQLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMhiZLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMiodLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMjumLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMk%wLMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl+*MMl8g)$%_Id#WeXOMB_W0v1gG<-qHg;-rHg;-sHg;-tHg;-uHg;-vHg;-wHg;-xHg;-#Ig;-$Ig;-%Ig;-&Ig;-'Ig;-&Cg;-56&F-6?Ab-m*3XCIg?DW.LacWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ@13XC(E.,M6g.QM6g.QM6g.QM6g.QMb2#*$?%uZ-n*3XCM/<AX%C]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ@13XC6C?XC7F?XC7F?XC7F?XC7F?XC7F?XC7F?XC7F?XCO;W]XcTtSAXice$wlce$xoce$#sce$$vce$%#de$&&de$6scSA8&)pA8&)pA8&)pA8&)pA8&)pA8&)pA8&)pA8&)pA8&)pA9,2pA0;Ab-p*3XCTcouY&Q:pA]uce$%#de$&&de$7&)pA9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B9/D5B:5M5B0;Ab-q*3XC,Q.,M9#JQM8mrpLwX%g#FZV6MJ23(v1*[QM<.]QM=4fQM9FF3NxY,oLuUY*$-sA,Mb'(SMU'(SMV-1SMD-1SME3:SME3:SMF9CSMHK$5Nd=n]-XYg-6SoJR*SoJR*HZY_&HZY_&I^Y_&Kjl_&h@C;IPMB;IQV^VIKD^VILM#sILM#sIMV>8JMV>8J5C7kX?BDkXX#9REI[ClfNj_fL):ee$J=ee$K@ee$LCee$MFee$NIee$NF[e$PGluusC3L#(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-.Ag;-bZ]F-cdxb-@X+REG$@igI8H/M,Cee$MFee$NIee$au6/Mbu6/Md+I/MEE`'8'VtGM+e(HM,k1HM-q:HM.wCHM/'MHM.qugLQJ3UMcK3UMcK3UMcK3UMcK3UM4O+1#c.[JM3`xb-AX+REcA9REcA9REcA9REcA9REMYs+M5XFL#d4eJMb*Be?+oBHM/'MHM.qugLRP<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UMdQ<UM6_OL#d7wfM3V]F-fg=(.mEmtL8N,W-)m]e$K@ee$LCee$MFee$NIee$NF[e$*:qJ;E>'RE):d;%wFg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-8FwM01@6$v)osL#:v?qL[*elLWojUM0&(M#^Ec`O'I^88F(SX(e(SX(`JZ_&`JZ_&cSZ_&cSZ_&vc_iTVqYvQ$io1B<CWk=$[DL,$[DL,P2gw9pISX(pISX(rOSX(rOSX(rOSX(u)krQ.$82UJq22U&Y12U'cLMU9CMMUwOLMUxXhiUPh*<@l2TD<umNe$qRMe$/'EL,/'EL,t1[_&t1[_&w:[_&w:[_&&J[_&&J[_&'M[_&'M[_&(P[_&(P[_&4c:RE/4TX(/4TX(*V[_&*V[_&Ea^`<nS2vZb3ae$2CNe$@hTX(@hTX(0Xu+MBSC[MBSC[MBSC[MEf_[M[0S4$1e@DbRn;DbRn;Db[j0;eOE0;eOE0;ePNKVePNKVePNKVeRa,8fRl5sI2<CX(7[^/Dw8j+i[]w.i[]w.ieL6sI>bCXCOg2,M2o-7$<_Xv-,skOMN>3(va`R@#m8:pL9dRIM:j[IM[C#*v-D_hL1UNmLF#*(vu8o`=re;,W^p>X(qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$&vPe$^EX`<^p$a*70Ze$8$G_&>+v^])qZA+-RU3OZ=x(W'1EGWrk`cWst%)Xt'ADXu0]`Xv9x%YwB=AYxKX]Y#UtxY$_9>Z%hTYZ&qpuZ'$6;[(-QV[JkCp/4$-wpigoc;T^<31TTq1B$a[1gJaCPgKj_lgLs$2hM&@MhN/[ihO8w.iPA<Ji<as21,POfCJRk(tsu.Dt)(LB#n$,'$0JbGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHMO:_0M#7,,2dr6#6ssrc<7lD8A4C9/DoHUQ9eY[r6r#XV$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-Bg<#H`Gx^]@qWe$bX[wu#1gE#9Gg;-:Gg;-g@On-xu^e$H5_e$V`_e$`%`e$%Fk4J;^%qrNALe$x+xFM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMCJXJMiBV+vH[AN-Mg&gLXDcx#gjvEMbpowu?SR&,rV?X(Av^e$H5_e$V`_e$`%`e$&AujtQ&T`E8n)F.:bae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$lW'Ra]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJM&T4-v4A5b#PHg;-QHg;-e``=-VIg;-`6@m/p>cuuG4^*#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-EYGs-=CEjLD818Mgf.)*3h;/:p]^e$:a^e$f'R9i>6EJMHi0KMVhZLM`HWMMY=#*vWQqw-,^ErL:kbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMm9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.``Ua4=1?/:<l_e$7F[xFTR3/MQINJMRRjfMu'6DkY=1AlrdQN:U'o+2u,XV$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-BlW>-CusY-Bg<#H(Lv^]@qWe$bX[wu5C,F#9Gg;-:Gg;-g@On-xu^e$H5_e$V`_e$`%`e$`dm1BdP*dEp^Ne$:bae$;eae$<hae$=kae$>nae$?qae$@tae$Awae$B$be$C'be$D*be$E-be$F0be$G3be$H6be$I9be$J<be$K?be$LBbe$MEbe$NHbe$OKbe$PNbe$QQbe$RTbe$SWbe$TZbe$U^be$Vabe$lW'Ra]sbe$^vbe$_#ce$`&ce$a)ce$b,ce$c/ce$d2ce$e5ce$f8ce$g;ce$h>ce$iAce$jDce$kGce$lJce$mMce$nPce$oSce$pVce$qYce$r]ce$s`ce$tcce$ufce$vice$wlce$xoce$#sce$$vce$%#de$&&de$')de$(,de$)/de$*2de$+5de$,8de$-;de$.>de$1Gde$2Jde$3Mde$4Pde$5Sde$6Vde$7Yde$8]de$tdfe$ugfe$vjfe$wmfe$wj]e$v(+GM#45GM$:>GM%@GGM&FPGM'LYGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMEVkJM&T4-v6MGb#PHg;-QHg;-e``=-VIg;-`6@m/r>cuuI@p*#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-EYGs-=CEjLD818Mgf.)*5$sf:p]^e$:a^e$f'R9i>6EJMHi0KMVhZLM`HWMMY=#*vWQqw-,^ErL:kbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMm9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.U[NjL5%vf:2Nbe$QQbe$eLKR*Vbee$W_Re$`l_uG'V:,;vpWe$bX[wu#P>F#9Gg;-:Gg;-AY`=-7Rx>-7Rx>-7Rx>-8[=Z-m$/F.kZq+Mgm6+#h[S&$OAXGM(RcGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHM13`HM29iHM3?rHM4E%IM5K.IM6Q7IM7W@IM8^IIM9dRIM:j[IM;peIM<vnIM=&xIM>,+JM?24JM@8=JMA>FJMBDOJMCJXJM>'crLLD^nL&x])$@54R-,J,W-nj]e$:a^e$3hrjt^*%v,HLP8/Vvxc3`rmY6oa;,<;eDj1<<-wp(1Hv$wFg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-EYGs-=CEjLD818MkGA3/:bYF#nj]e$:a^e$rbGfCK1=#-HLP8/Vvxc3`rmY61(=2Cl:0B#,^ErLXkbRM;qkRM<wtRM='(SM>-1SM?3:SM@9CSMA?LSMBEUSMCK_SMDQhSMEWqSMF^$TMGd-TMHj6TMIp?TMJvHTMK&RTML,[TMM2eTMN8nTMO>wTMPD*UMQJ3UMRP<UMSVEUMT]NUMUcWUMViaUM[19VMm9BVM^=KVM_CTVM`I^VMaOgVMbUpVMc[#WMdb,WMeh5WMfn>WMgtGWMh$QWMi*ZWMj0dWMk6mWMl<vWMmB)XMnH2XMoN;XMpTDXMqZMXMraVXMsg`XMtmiXMusrXMv#&YMw)/YMx/8YM#6AYM$<JYM%BSYM&H]YM'NfYM(ToYM)ZxYM*a+ZM+g4ZM,m=ZM-sFZM.#PZM15lZM2;uZM3A([M4G1[M5M:[M6SC[M7YL[M8`U[MtnobMutxbMv$,cMw*5cMw'#GMK=6###SbA#$]'^#%fB#$&o^>$'x#Z$(+?v$)4Z;%*=vV%+F;s%,OV8&-XrS&.b7p&/kR5'0tnP'1'4m'20O2(39kM(4B0j(5KK/)6TgJ)7^,g)8gG,*9pcG*:#)d*;,D)+<5`D+=>%a+>G@&,?P[A,@Yw],Ac<#-E1T;.Vdaj1Ch7)<3P_e$RS_e$SV_e$TY_e$U]_e$V`_e$Wc_e$Xf_e$Yi_e$Zl_e$7F[xF5K5/MQINJMRRjfMUv7DkY=1AlrviG<8#<R*gu]1gJaCPgKj_lgLs$2hM&@MhN/[ihO8w.iVfsJi5CRD<=_g-6%JbGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHMO:_0Mg6,,2dr6#6ssrc<7lD8A4C9/Dqsrc<X&xc<Y,+d<_fg,.wrV^M_-b^MM3k^MN9t^Mc]Kg-7)M'SXvX'SXvX'SHZB8%r'2d<a/^e$+3^e$,6^e$-9^e$.<^e$/?^e$0B^e$W&xc<Y,+d<_]Kg-8,M'Sogq+M+umF#Z;O)==QxKGY#Y'SY#Y'SY#Y'Sl@Y.h-pM'SnR:fhwJM'S@1-`s7U3&=Q^fe$rZ]e$a2sJ;F.8qV):d;%wFg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-8]3B-^M,W-h8Ke$TEa-QTEa-QTEa-QTEa-QTEa-Qpgh+MTtlOM&xd+#S&XD=T&XD=U,bD=V/OJ-T3OJ-VE0,.U>4gLS-*G#*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;->rA,M'+*G#[VKE=3,m4JogXfU9ru(bQJWfi-7@kXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXnwBkXrpq+M@13G#o.1a=GCD'SP;vl&/kR5'0tnP'-17kXnwBkXUHa-Qm8b-Qm8b-Qm8b-Qm8b-Qm8b-Qm8b-Qm8b-Qm8b-QZ@x?KZ@x?KZ@x?KZ@x?KZ@x?KZ@x?KZ@x?KZ@x?K3ar+M-gYI#h/&'G[nZxFa9&;H#YkA#/Bg;-J;)=-J;)=-J;)=-M;)=-M;)=-M;)=-bW)..[AcwLoN,W-)m]e$K@ee$LCee$MFee$NIee$OLee$M;@e?8&0`sEVi34r^fe$safe$a6=VH)Vf%uv:+AuwCF]uxLbxu#YkA#xFg;-'l(T.sBY'$ZS'DM)XlGM0_uGM+e(HM,k1HM-q:HM.wCHM/'MHM0-VHMO:_0MM7,,2dr6#6ssrc<7lD8A4C9/D%lK#$:/&F-C<4R-DEOn-x)Q9ih/Aig3bWGW,Cee$MFee$NIee$C8UGWI74R-DEOn-x)Q9il[k+MldE4#gQKC-uIg;-vIg;-/uA,MC^MXMljaO#C8UGWJ74R-ENk3.Q?4gL0maO#*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;->rA,MC^MXMljaO#C8UGWK@On-#-Q9imbt+MC^MXMmjN4#J^AN-D<4R-D<4R-D<4R-EEOn-#*Q9im_k+MlgN4#C;hcWD;hcWD;hcWD;hcWD;hcWFG$dWoY`Eem_k+MmjN4#5C#-MDdVXMDdVXMDdVXMDdVXMDdVXMDdVXMmpjO#DAqcWLIk3.VWXgL[sjO#.Gg;-/Gg;->rA,MDdVXMDdVXMmpjO#C;hcWD;hcWD;hcWFJ6)XI74R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-E<4R-FEOn-$*Q9iEw`9iEw`9iEw`9iEw`9iEw`9iEw`9iEw`9iEw`9iEw`9iEw`9ioht+MnvsO#EJ6)XJ74R-E<4R-FEOn-%-Q9iEw`9iEw`9iEw`9ioek+MFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMFpiXMo&'P#EMHDXFMHDXFMHDXTY+$$eqv,$,aI3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kM^X3kqnt+MMvrXMMvrXMMvrXMMvrXMv)t4#Mr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YNr)&YOx2&YP[kR-NakR-NakR-Oj0o-(*Q9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9iI-a9istt+MI,/YMI,/YMJ5JuM>@XA+JRTYYO[kR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-PakR-Qj0o-0dI3kPgX3kPgX3kPgX3kttk+MK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMK8AYMtDTP#J%&#ZK%&#ZK%&#ZM4J>ZI74R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-L<4R-MEOn-,-Q9iL6a9iL6a9iL6a9iv$l+MMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMMDSYMvPgP#L7]YZM7]YZM7]YZOF+vZI74R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-N<4R-OEOn-.-Q9iN<a9iN<a9iOBj9igw*xuOM]5#T[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[U[=;[VbF;[P[kR-UakR-UakR-Vj0o-/*Q9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9iPBa9i$4u+MPVoYMPVoYMPVoYM*vp5#xvM%$x,08Mgf.)*=Teo[p]^e$:a^e$B8AR*x8$$v__*ZMNa+ZMNa+ZMNa+ZMwm>Q#N]<8]FsX?-NxX?-OxX?-OxX?-OxX?-OxX?-OxX?-OxX?-OxX?-PxX?-PxX?-PxX?-PxX?-PxX?-PxX?-PxX?-QxX?-QxX?-QxX?-QxX?-QxX?-QxX?-QxX?-RxX?-RxX?-RxX?-RxX?-RxX?-RxX?-RxX?-SxX?-SxX?-SxX?-SxX?-SxX?-SxX?-SxX?-TxX?-TxX?-TxX?-TxX?-TxX?-TxX?-TxX?-UxX?-UxX?-UxX?-UxX?-UxX?-UxX?-UxX?-VxX?-VxX?-VxX?-VxX?-VxX?-VxX?-VxX?-WxX?-WxX?-WxX?-WxX?-WxX?-WxX?-WxX?-XxX?-XxX?-XxX?-XxX?-XxX?-XxX?-XxX?-YxX?-YxX?-YxX?-YxX?-YxX?-YxX?-YxX?-ZxX?-ZxX?-ZxX?-ZxX?-ZxX?-ZxX?-ZxX?-[xX?-[xX?-[xX?-[xX?-[xX?-[xX?-dk2q/peN5vqj39#IIg;-JIg;-KIg;-LIg;-MIg;-T6@m/W@cuuvP9:#'Gg;-(Gg;-)Gg;-*Gg;-+Gg;-,Gg;--Gg;-.Gg;-/Gg;-0Gg;-1Gg;-2Gg;-3Gg;-4Gg;-5Gg;-6Gg;-7Gg;-8Gg;-9Gg;-:Gg;-;Gg;-<Gg;-=Gg;->Gg;-?Gg;-@Gg;-AGg;-BGg;-EYGs-n5]nLMsE^MJwN^MK'X^ML-b^MM3k^MN9t^MN6bBMLIdY#S?mA#%Gg;-,(`5/1ge)$4LbGM)XlGM*_uGM+e(HM,k1HM-q:HM.wCHM/'MHMY9jvuW:w0#sLBMBZ/Pb%DFP8/9___&T=jl&<9ZR*MM:;$<Fj_&%4=G2@Rj_&]tFJ(q8l_&[efi',ml_&nV4;-;Dm_&#`DM0[On_&Y@35&0$p_&/^C_&ZBp_&0aC_&eap_&hW_c)N)q_&iZ_c)dch_&?1x7n#Mi_&qHGJ(*A(v#1:<p%o]sJ;u4i_&aTZ`*lpk_&QrQS%.dl_&U;WlA6&m_&nckr-AHp_&kASY,dYq_&8#FS7,Yi_&L0gx=rW,[.E''u$<g`=-/fG<-DtG<-0fG<-]B`T._VDw$qB`T.a``<%(CfT%?hH5f4W9M-@^je3f+_.G_UbM:C10@-^meF-$'4RDHHi]G)>2eG<QCq1_hie=e%q*H0Pw#JpJ@7MRr,)OM;4/Mm<OA-9*7L2S.]OCGfm989kf&6[Kx)486%P1Q8tF795ox0:HqQC5YiEHJZ93<RNNw8[DcU:3A2eG_0iTCoaY&7gWwF-VSKKFrAouB:eo*H9#I>Hl6rTC%m>PENfsKOsV:MR42,FHr(622d8_DI(9nWqHEwgFi93W).-UqLZ(iD.1%fFHk;aeEo>pKF+(rE-K&'sI5i`PBtLI*.n9O^Mv'WH0;pwF--rI+Htf1eG'>ZhF@>HxLcnCG-oGFVC3h:qLbw?Q107%F-'&$lE7>?LFx4_TrWnwr1xg#RMv0*hF@'oFHs^1?-6vTSDj;C[-Qr%(/m%1,NZ<:8M8mZ^QDw-@-[MIW?.gR)Fcf85TXh+#H&H9kE$IG@0FK:cH>%S+H,UnHZ<oL*H-kwF-xBrE-tYkVCIm*SM+,DrC07`.G6b_QMg;CSM`2p)8V3q#?p/fQDJ))PMJ&DVCTp9th;D+7D4OtfD,SnbHC/kKcIv#Q/GA+G-;1kCI`-DSasj:?-'<FVCJ+j'/_q@;1&aV=B(sI'0=X&iF?D0[H7)Ni-PoF%KJ)^j18JW8&UL*W+@cFVC?Y9kEn;OVC#:ugDJ^UcHdEDtB0H)e.j5KKFU4)iL+7tlE0_/iF*g]TC3E4%6w'rE-<MvLF8vNG-uLCnD*LeF-&5H1Fs2+nD6j31>['e?Spk-@-8.qgLC@<hF@0m`Fd`[+%22AUCx_.6/o5ouB9IupL::<LFO`s<1XSh/N<KJZMxR9@84hI5BF=U)0cvZ6D/#YVCo&<:/]@HlE.lxv7vU9NC@UnSDu$wE74rcdGCrwiC(-v>-e=pIO4FqbG#$/>B5(VVC>Ct?-j(J0lmvR0PMU6pD,S[MC9dFVC0SpQW<42eG87FGHK<NE#t$x^0@f7FH;)`q16jvRMs.(_IUBkWh/d)=BXVG-Mo,.m/?_tfD(&vLFC5H=M=K/eGC3[t(#/(sIL_%<-DUovM<4^iFNGO8Mlb(*%(LNW-o>63)J9,#HqP#lE;$O(I46xF-I=ofGD>#_]EXEo8LXU'#B;F&#0E-(#aJ#lL:ht)#9<#s-xs6qLHNh*#J$S-#ce.u-)HwqLrQ2/#I<x-#U5C/#H#Z<-6s:T.P)1/#l?:@-YQQ9/huJ*#G[=oL%bamLe9CSMI5B-#4^&*#1DjJNo*XVReigcN&+elL6D_kL.3CkL?<^-#O)B;-$W)..Uv8kLY3C*#dVs)#VS;_]f<Uq)MUg+MRIhkLJm<3O@?3&.rn.nLSgXRM`/lrLk6T-#*>//.+)trLuaamLkK;/#-2g*#BQ&GMx0AqLFr%qL.GTsMNi>oLE_4rLI2L*#Ca5<-ou&$.'h$qL;GOJMD2oiLP2oiLw*A>-d&@A-B)m<-6o,D-]?f>-_LC6*[3@_XA:SqL)SD/##-3)#L2^V-uC<L#h$S-HI2w9)]LFwK<EPwTNrOk+mfG&>3^)Fe3M&jC[@TDFM26RsfG2R3E^tKG'+auG/(=2C&qM>H_wk>-$$Oe$Ha(@'1Xf'&Mao7R?SG&#gY^(OGT]A,SXn92sC-AF.uwlBK'.#H0,@2C8Ch]Gj9M>H@Hi`FT/&aF-=He-Ebh]G41f5BRbDYGRHlMCGN2RNoW?:MbJS?g80(@'>5/dEfiCk=?,j+M9G+RML(8qLiX+rLT3CkL$shHOdKG&#CblO-GmA,M#*aa-[t(F7=dd>-D+uP81WL_&BVK21g,Pf6GXl?BG^OkFwOwWUP%co7ED+j1mKl>-[Z3L##)w89fwY.#+ABsLY2MC-j?[*.,HwqL]fXRMp.AqL6xXrLZ:v.#a)1/#CsY<-Tr.>-l`Uq7['=2CB0?gDN=-AF:7A5B/(=2CEd]q),XM_8iP2R3]JFdMr4'w8hd,gDt6N&Z6juLN[1Y[$FYU<-MHh<.DB+.#ca<&><7@<-LHJF-rjTK-WlUH-%ti''=%g+Mg4T-#U*YwMN=0s7JoW>-(w0Ec6C;=-mp-A-9+d%.K>G&8eQfwB.?^uGeCN^???-lN0.lrL]%1kLgX5.#FCGO-c3[Y%K8w9):jA']pl0DEqx>VH=<A_/6m'<-eR6fSKPgS8^0d&6%*tV$^YpP8.,9&G-95O-OGg;-/j)M-V]R+%dnA2CR=1#HmN7ZHE`k(EIt+mBSAwu%gP4GDxA[DF`<XCMTvc.#gNNj;kKM/#e`hQ8wp[PBwdY>-CxsfDIGF,M7$uRM@k=8MSQG&#v5[qL8fipLQWG&#Kmk.#4*B;-cp-A-P@reMLd'pOp>?a$>X.Q8OPGK3tU5.#DrLm8&7i`F:-qj)iU']8Vjh,F.r%qL`W5.#u>EW8Nqg@8d(Te?7uP9'^;wu%H(tfDRvO<-uIKC-mV3B-/d1p.00f-#UhWw9C9g'&;Rn-$1CTE5kaamL[Un'&g%b-66du7IPIH]F[?JW-imh3=rBs>e/fipLq4oiL-9*r9l:bMChqwA-[oWB-WGuG-r&@A-VHrP-6a5<-]b499<mmd+2V;Y$/[x7I/8e?^$==SI%$Eb$-:auG[l3_$I.e9`Ve)F..F&;Hb3N'$BR=RM*A1sLUA]qLNuY<--:9s$f0q9Mhr*L5>Zk-$._M_8C=C,Mg#F?8pfm--^*<F.&Rjs-8ABsLM@9C-hZ*Z%-[)G75c$<-RrL'9ht7R3R$]<-Ua:AMr'I^&5mc3=xdj9;CP+DN3@PL'Re5R*vCMt-KQ(eN];CSMO8-&8TS+?I3:SqLfRxqL&LG&#5U2E-hL`.M7h'1&?8JcM-;&E3v(+GMk,rOf7uZb%/`o>G4K&##*J(v#JrKS.EH1Vd5vF;$7,cV$.n*s$41[S%J)(p%:UWP&>n82'B0pi'FHPJ(Ja1,)N#ic)R;ID*VS*&+dkho.]x&#,h'.5/wxFuucF#v,S#A;-mtYV-kw:8.o9ro.sQRP/msc7eY8#kkv,hGd#wNM0'90/1r#Hrd-^,,21vcc258DD39P%&4=i[]4A+=>5ECtu54K+206WFM0Mt587^R,`sSB258=sbi0Yg.29^)fi9bAFJ:fY',;G^AG;AScc;iuIoeAVa4fp@Z`<tX;A=xqrx=&4SY>SlCJ1Ux_f1.ekr?2'LS@[:%,28KHPA<d)2B@&aiBlM,YleK?JCHVx+Dij;GDIPSfCP1:DETIq%FXbQ]Fh^m+De^m7[qOb1giFqxF_0NYGcH/;HgafrHk#GSIo;(5JsS_lJwl?MK%/w.L)GWfL-`8GM1xo(N5:P`N9R1AO=khxO:E>D3C9euP7Jr%4GQEVQKj&8RO,^oRSD>PSH,;A4Y^.]tYi:MT^+r.UbCRfUf[3GVR*KcVl*0DWpBg%XtZG]XZorx4OS*>YNVEYYPcauY9-7GD,Z[rZ0s<S[45t4]8MTl]<f5M^@(m._D@Mf_HX.G`Lqe(aP3F`aTK'Abwd=]b#+TY5]&?Yca>v:deVVrd+^m7e-U5;632%Poo=4Pf[cNlfub0Mg5tPV65pGrm'=Hfh+U)Gi92BciZC5S[PC]1p30A`j7Hx@k;aXxk?#:YlC;q:mGSQrmKl2SnO.j4oSFJloW_+Mp[wb.q`9CfqdQ$GrhjZ(sl,<`spDs@tt]Sxtxu4Yu&2>##*DlY#.]L;$2u-s$67eS%:OE5&>h&m&B*^M'FB>/(JZuf(NsUG)R57)*VMn`*ZfNA+_(0#,c@gY,gXG;-kq(s-o3`S.sK@5/wdwl/%'XM0'Zj(EN1L`Ej2+AFj,f%F-Wpf1k#/DE3&mc27>MD3;V.&4?oe]4C1F>5GI'v5Kb^V6O$?87S<vo7WT;58Yarl8iE%YulI52908G]F_&]i9dGOJ:h`0,;lxgc;gDx.:;OID<['EYGtR)&=xk`]=B1`uG(:]Y>,R=;?0ktr?4-US@8E65A<^mlA@vMMB'8>J:)DYf:HPffC1'I%tNubcD0`u+;TC_`EX[?AF]tvxFa6WYG:.;G;eNAVHeH&;HhjorHjv48Io5loIsMLPJwf-2K%)eiKHH(/LJTCJL-Y&,M1r]cMP/w(N7@Y`N;X:AO?qqxOWOV`<C3RYP[Zo%=IWNVQ0nirQO&KSRS>,5Se&5A=AJDcVp8YoIo;u4JYc(2T^%`iTb=@JUfUw+VjnWcVn09DWrHp%XvaP]X$$2>Y(<iuY,TIVZ0m*8[4/bo[8GBP]<`#2^/C;M^1Dmx=3[r._FFVf_J_7G`Nwn(aR9O`a`>(Vm9Pm%bX^K]b]v,>ca8ducE=ju>g]`rdku@Seo7x4fsOXlfOb/;?xp6MgxvQig%0n.h'66JL+Om+i/hMci3*/Dj7Bf%k;ZF]k?s'>lC5_ulGM?VmKfv7nO(WonS@8Pol=Nlonsgr?[qOip`31JqdKh+rv;-8@jpd(s$U$DsagD`s/QFf_tVA]txox=u,mdo@cOe7n*>Y>#.V:v#v<[;$2tHo[ROxLp61R8%:I3p%>bjP&B$K2'F<,j'JTcJ(NmC,)R/%d)VG[D*Z`<&+_xs]+c:T>,gR5v,kklV-o-M8.sE.p.w^eP/%wE20)9'j0-Q^J11j>,25,vc29DVD3=]7&4Aun]4E7O>5IO0v5MhgV6Q*H87UB)p7YZ`P8^s@29b5xi9fMXJ:jf9,;n(qc;r@QD<vX2&=$ri]=(4J>>,L+v>0ebV?4'C8@8?$p@<WZPA@p;2BD2siBHJSJCLc4,DP%lcD/ZW+iQ,:`aAT=8%>To4SKpiCs8HNDEXU-&F]nd]Fa0E>GeH&vGia]VHm#>8Iq;uoIuSUPJ#m62K'/niK+GNJLJgCG)N)%)*RA[`*VY<A+Zrsx+/`/,M3xfcM7:GDN;R(&O?k_]OC-@>PGEwuPK^WVQ0c:;$>Cqr-&qSP&nxer6m6#5AQ,48.<8:c`?`<PAKp287tm0/(m+:8Ro7USRUD55SY]llSGb,DN<lGi^`+iiTxT85&29El]I<p=cLPmi'5bPuY_4TY,-`Z(a7^v=YB=uu,.m4SR.]9;-lQOM'YqX.qp+u7R,4#2BjeefUjhEGV`_,58i1r@br]12':b_xOD;-JUhw&)WR3H`N5LC]ON;PlSWc1MTf$^%X/0_`WvZ>AX$tuxX(6VYY,N7;Z0gnrZ4)OS[8A05]<Ygl]@rGM^D4)/_HL`f_Le@G`P'x(aT?X`aOe%G`ZdT]b_&6>cc>mucgVMVdko.8eo1foesIFPfwb'2g%%_ig)=?Jh-Uv+i1nVci508Dj9Ho%k=aO]kdW6crxRZS%#wjxkC/LYlGG-;mK`drmOxDSnS:&5oWR]lo[k=Mp`-u.qdEUfqh^6Grlvm(sp8N`stP/Atxifxt&,GYu*>P##.P(Z#c'v=PF#JP8e3;YP+[;ci^DkCj`P0`j8^k=l:CwS%8WOxk>[W5&Bt8m&F6pM'JNP/(Ng1g(R)iG)VAI)*ZY*a*_raA+c4B#,gL#Z,keY;-o';s-s?rS.wWR5/%q3m/)3kM0-KK/11d,g15&dG29>D)3=V%a3Ao[A4E1=#5IItY5MbT;6Q$6s6U<mS7YTM58^m.m8b/fM9fGF/:j`'g:nx^G;r:?)<vRv`<$lVA=(.8#>,FoY>0_O;?4w0s?89hS@<QH5A@j)mAD,aMBHDA/CL]xfCPuXGDT7:)EXOq`E]hQAFj3$Mg:i(cH%YjBF%qV=B.p>LF,MiEH3GSu'B^IUC-mgoDt6vsB(gv@&u+Pk+=lqaHI9tp7)`I'Io#/>BJ3kp7LociO<@^TC4Ch8)N%VeG%^4rCEm<sLOF;=-U62IM)o7U.'wI:CS(mHM>30COVTNhFm'ZWBuvb'%1rHUM^[j$9K-eh,^DpP'p3jqMZ6GjD5G2eG;[hQMQTCp7I,;njL*#6Bi>pKFJZ=$g.Zf8&_FemL'RqjEc9i;%Y2Ud1B)a7D'EtNEE,&oDUq,:2m<+KN5cl,Mwap_-grjv%EwHQ8FhI6'>9`9CrdM=B=2g8&)%/Y-0*Y:2.rhp&RrY1Fi9x/M/,em8@lKv$q0#O-ob?MMYen6/0,DEH]aG3NHr/49ISYedGI,V)jq$>(=x^kE5S)COICPh%LgP']F_u`F_P1d-^OKg<J3*39=cKv$ZSdh-77Uj203%*NV9UPNwQ^_-lMCbImck*@MLWTB,ZkVCVj@JMP3*39bODW-I&$<83BIENSAC[-I0HsSnMlgNf-<j9wF+m9dT*T&vi7r%nBxjM1Gaj9Z2Bp&%6(A&.O'X8U5Hv$MA[A-_oqlL409s$um'hN+U/0:_<xHZqTF0N7;E/:dSDA&:nFZ-ZJtJWE?sJ:-o$Q'62JnMf=pNMANk,NQqfK:KpkW-Z;9[^glfBHJqd?8&U`8&/d_&&<nd;%gKTW$#0U-OISS,;uXB/;HLHs%k`Jg%)[.B?Nv4-;:5UW-)$,:28t0=8FhDs%P5@A-IRGdM.u=H;cr]J;E%KhGrZ=OMA'Yd;Rub,Mx6^TC'#[)%W#/>BS;R)<INEs%pcK<MnFt_$saFOM=TU*<mKe8&;PcG-=](d-xl.'$Y<;IMd31E<Krf'&%Xf5/[.poD3_qQM*FLE<kC#%'qg2f6O2P2(^?VtU/g*u1*5Kv$$7(H/^CclE:H7RML5VE<,mX7D/o;2F0%OGHMikdGsi;X'MSv.'4k0x7*7=m'NOg@'o'x?T>.Z8&]^O/)BZo5_M62IMR7rdMXqpC-VUbn-<%gp019.*N,W)E-PH[e-5RE*[@[;MF5kvGM4cK<M'+9MF'wI:CGG5HM,I5HMeBUa<x>KW-evPX(]N>rB*SvLFtBb;]XrdB=Z?2FI86-Y8#)xP'-)+o&w#lOMIqaS8lPV8&G]2WJR`HB=2v^W-)vleH/Z1C&()9kEjng^=VA1j(tdU@0+EuOMuD2X-Uv4B6Z%*_=pf1l+35ww'@N$>89hDs%@T.m-&<O4F<ux6*$-/W%,Q2u$93_x7R8Hv$F:*B/?3G<B&[-MNN.N?>dXM<-A[=Z-3&6MG>Ehx7-c^/D(NkVCEN5b[M6eL,M)9&OGZu-Ouw]TC,P8^&m.d=&jf]AmRVd>>-Mh;-RLg%'laXtC-B8^Q*[(dM8^m>>Gh7m'1+DRWm:GcGjs9C%.[Ac$.nHwB0ov@&DSAq`4E7O=]0f#I_S0dN;L=KMMb)Z>-ODs%:Q(E%&BCPMAjDv>oob8&xi]g%/Z1C&q@k'&pa8W-ktk/<Z4/<?O+M>?4d0<-pXg_-+`9l+&.F[9(NUPM#ESW?nJf;%q^sq-fp).Z)T_PM2Nos?Raa8&mk8o%Ap;v8IPl'&Y(m;-3:Yw$(1t89rI-:&Tf0SDoGFVC?H'686L,(&O[N9B9FPC&[#8kEGgxp&a7hoDHj3oMQi[MNi'n29JTj8&%9N:)]83eF-0[/;@#FoM?0GH;dED9C2Rm;%[qI[9vv'1NcOolD=Hfp&WgitBK9/b-jAVU)_,rODWI=;.Q;*7DlW7W%BpEL50)*JO3:Ca<e^U@-mlGW-(<[X(dM3.FG5f$KvXT9rDXvLF6QRh>_w2Ui@9S5'fRl@'MMA'fATkM(h#IH+p*#UC1;%@^BPj'SG#hJ)*Jh15lR;bR[ATt%_0=gG$W'oD8c8QC,dk]>t0(m9qk+p8vB_M:GEi`FdM0T&0a]7*1tkC&)?;ONo2pK:-5QhFPeaUD$tcjNUMigED32)FE<MDF4[Ds%/YD=-$h;a-#p8r)0#]lN*M@iNni)?>&CP59<s><-GfL).)P]lNi'RQ8DA5T&5%aF.eA%PDDrnQ/OMbdGwG+7Dt/Xp&2)TlN773_=NSciOkvj39,ZkVC(k`9C=IcM:T6dM:cYcs-gG%1OG_:-OH-w29AEFW-6I*f-up0hNslniNjb]g:LW&T&[uN^-gW0`&oRY(HR:G/;I^xP'_?)''f11<Jal:3(ab7/G^YTlNQQQ3B`HxW-,Beh<P0rm;Tq@5BNK*HM2x]TC4Ch8)4==o(_Wbh<f2>e;iYj=(PjSAOvVm*&QnvS&L0bh<=L>HMr<%eMZJ1@-dEW0:gj@5B[_aQ/OaP<B(gv@&'?)?e*[c,MB&Ml-[97%9khY3D^t^2BjR)W-9<8n(a9?NBVu1<-B/AV%.$)7<I;<$8a``8&ieBd%WX-n;Y<=2CJpX2(b?NR'Q%>t9J:=2C@lKv$*s0`$)#dh<mt8tB0,DEH/Neh<P-Dq:wR,V)PjSAO+r0`$IdtWSlDYe;S0XMC2h*<-&8Du&JDN$819Hv$+s0`$qBVj203%*Nxq0`$1k>U;RO?n;hQW=C[i@NC)`I'I7xdh,I*@,M:/-a$H>N$8CmR5'P6bh<D1O$8H=tiC6$FW-'ndtCHTeh<F=b$8kDd;%x2-h-IsT=1NVa$8rZDs%2Pm]%nIBI6rbgI6N=Ct8hp7HDl`'T&89hq;VKTJDvjD?$mGcdG=,W2`k#SdDZvEs%=%<^%=@(@B_*en;kmpfDJ&%C/DX%Q'IH_x&:fWnM%,]dDKJ:<-ZPn'&<nd;%<9dX$CF#1OuueDEIMc;-<`?a$XD&N`?-hkNdCFEEEVUW-I/-:2X4T@8QhDs%@%<^%#?)FRDO51O0X2.P./GG-J&LW.'?$@&<-2q%@t'RB1=kCIr9DeGgvb'%?`?a$f9/<-P1cp7O2Hv$?`?a$%,h.QF[G1O]RdLO=BQ_FhK&CO:_?a$[%;@@QnT%8Ee%T&E7s>&[%;@@%4[MMN0M-MkHSv&cX-F@]6Eo;i5i`FK?=<-sQ<r&[%;@@NnT%8=l`8&UbRj%^_l=9F$8p&Z>i*RS31%K$R4%TU=V2(GUo5B+)YVC@-$j;cgNhYR+p@8+jR5'=GPb@OBvTM34s='@HnGtE$iaN8YGu;#8(4+UT[GM0_?a$4:;vnnJB#G<*3w$xJcdG(`JZG@CIW-M.;@@gAbo;oYe]GQ+iW-D.;@@UP:@-P1cp7&h@p&.lSO&JqYlNE]c,M0_?a$c?<f-IUP7*ZD>m'M[4W'5,6B6%G;wG`>tdM-V`<Hs=)X-I4;@@JvDMO>cl,M2%Ei-Y=NB-t1)<H8)CW-F:a'JxbXYBf.Z'88^9W-T<KRCXEQA8K+bYH[YY2(o7`d-Y<KRCKhYHM@YwaNTD+o$7eHRCr+if;#maYHA<=<-&#wm%WLPA8kmaYH'SQ<-eikKMZRt)9Y.?v$;kd;%Xv+G-cEAd;,DBZH*HX7DZPAZI%:#gL4t8MFN%Y58NT:C&'SU5'uVm5LE$iaNF9LLMn-;sHP?f;-TbA_%4Ebt:eg8p;%)B;Iw50<->@5HM-1cp7na%T&3g5x%DLK8McW@TIv__VIOY(<-Zk&c$bk:l+j0@LEF^$TMIgepIt]f;%A-Tr-6]#(]FX^8MwPR5Jid*T&tE1[-O^36(%cn5J8o^,MX#%#%,8%[7_w^2BkGw]-Mm;FGQ6%n;$L9/Da&5<-O^u%&&2xKj'cn5Jsx9aN:Nto;'bpfD`v+<-V^u%&o8<FG^#4o;*9d;%?Z#<-Zp)Y$cHEo;0Q.&G;q)W%ZB#)%9hdoDkQrpCt5kjE&s]GM7oYW-o6ERLJ&NMOcXT#Gf/#<-C/BgLlS_[-l'ERLLp=H;SRbm'uf0SD=>m<-8J]?O9klgLt3Z<-'TM>O;6V-M3n`u&KF9Y(WEs3XG#hJ)/xDf6T'QV)b`lM(rB@&O=3`HMW?m<-$)we%Q7C6;R``8&Mv><->v><-;v><-oe]d;'4mQqNp=H;la`8&@:a^%`-en;%.QGE[I]MCWb7<-G().&'9+1323@aN&eg#GZF]MCWb7<-G().&a-eI-eZaS;B;XMC/NUd;9k%T&W1DI&OZUw[w.mvGSv]5'XC%+'b1Pk`olKp;*n*#H^0o<-Nh<C(uxPFR5Cn-vVX6n;Mj%T&?&H<-KV.m-'tHd=A[_p7S^`8&e+i&OFEXaEG?MDF:$Ap&X:`e&P%>o*ks&p;s@=2C[E]W-P.Pk`&)mVHQo,k2TdA,3Um]G3fXoS8VGg;-WGg;-XGg;-YGg;-ZGg;-[Gg;-dGg;-eGg;-q[W/1.$'K:RlqaHn5:dDH2pGMM-$Y%-VmlE/J-5EUe^L202`e$+$J29Sg[7MgNEmL+')i1;+UVCeHb'%'HOVC*OrfLl=i`Fl*v-G&bvLFp?VeGcO[aH4K/>Br_IeG@,:oDY8]=B$NKmA),ddGj`D=''AvhF2onfGxm@uBjmeTC]gJjB@M:WCuPh(%<PDeGjY6&Fl,L(%+jlHGhc?&Ft(DEHSARQDt4;hFkMTh2(6O_ILjbAF9sLq1=[6WCRMt?H'a6`%S]cHM8x?DI></9&-KFVCI(8>-o[$2M(_MgCFW<:)l)Xw9=?/9&-ZkVCcB$t.dr*7D9O>C&1k_$BFQsS&5V(g2<*W8&^h>C&H-<I-M)T=%MY343pNZ:&%G@bHltY<BA$wt(jHZ:&,gpKF)8$lE>Bnt(I_a:8jXfS8lkF59q0cp8Ue^L2j`_e$U]_e$CwZjB2AvLF4S(*H`,Sj1#9SS'*g^oDk9iTCC';qLxIq2B0mXVCk<2=BbvL?pF3FcH/GqoDG[a8.)9XcHj+#^G,KG(&ER2eGgVF$8<HYb%aX0pMV?(x$+C8N2.uls-B?rQMYDWFM[K:x$%:o/3L7lp7K==O4C$obHu/[x-EjjON(EjHG@*[RM5>6$GvlpKF%,rEH:B4m'K)+^G7-RnMP&Sn$8SB^GoFxUCb.^,M1HY)N2KPdM19g,MX`wr7Z[CC&2YkVC?p;v7Fb]q)buBO4Sgmw03<@C&267C&;ZN['nhr*7HR2eGT2VcH$%)OX/1rNX1C7OX2C.OX14rNXG*/OX3=%OX@.Mj;=[1EN_NqLMI(ofM3NPdM7#.BO<Dn^Oi;E/N7D$PN/<>dM$=Y+H9,=&GHGQ=M076xLHFQ=M2:6xL'%<i-7CVOX_#9OXI<AOX3O@OX`tu.P$=Y+HJuT'GmSY_Hv`1eGa],LFI8P4%c-1</'w(vBKt'9&;Y)X'hEvsB*8mlE<`*s1<gB*NgVe^$*GHw&;OXMCHZS5'Uc_O+.s-6MI)QvGxVKSD^/]v$1<[rLT`?=.'WpKF?;pE@JKW8&x&3gL4$/HD0'AUC@pls-6*.nM(1eQ8h-GR*Nf]R*0&;jrC'MeM?-WI32$S5'VrFgLs54aEG#frLmvr,D&dCEHm'.:MXBu[$nHaR*7[vV%6t7T&RJKPNtVK#GxX`$9U)W&H+9)vB(UvlE3,HlEIt[>/qKn'I.L:qL1n(-Mo5h8/t6`.GZcpPN[dkaErTitBt&%L>VD^T&v8FnDHj38MLL-3B8A2eGCHrqL5)LBF#O`TC/H+7DAsY<-jn$m%D2_8.k7FVCWq7<-]Hu<%5a9<->CVT.18,-Gq='<&oYrsB+eDtBO`3e;t1[w')[@eGA#^n*CM14F8t;s%O.g'&;ZWXC.OvV%cKH)FJxCk`@er=-uP6e%4*S5'6SKgLlBHjB*SvLFF)b>H6hL6MXt4-;hbSq)*IZoD-V/F%x]ju//lP<-oo*v%66oP'$KdeQ;DR['mv6R<LgoP'dA$=h<fe0uL*IL,p+Q2(<XdgL[:iEN<j?b<qp]+.cq7j(kGs<UfrKu(o)Ou(<kJ,*gAFhL5a$F<bPEX(?nmgL2apW$Sg[@'L?kk+k8>N()`I'IemIgL9hrGDKW7rLL&l)<D?c'&s(fTCui#lEEq:h.rxuhF^a%NNS)cd;w1u3+2rY1F=ZF4+/wrDN+5ZZG?N*ONWee+%pv[C-m*tB-NM%m-9i[<UfU?78r/pq)egk0l=TkM(Q*RdMP3[68r:ww'UwCgL@l[q.l7FVC@_$]'A,=H=LNo>-iRD+(Fv0j(/s]dMUK*78]n8:)MMW?8X4e['0O#lF>r*dtJHf>-%*'s$=Z0j(S.UdMVTER8*l8:)XJ53)?OD=-ObKl'a8[-HT4`<-WB-6'kx^U)p.Z<-jPA4(a1I,*;)qZP1Y4D'6[OW812_t7G:)d*L,9eM-QT@PORT@Pr6BS8nG)7<ZK#3DjKnR8=GPR*%qN>Pn$'@Pruhq7b3dG*,u1eMn&hBFHm4O+7/tnD2]%/GS<b'%3=FcHT^oJC<^Ps--AnRMrEvJCA,Vp.vUXnD7=1%'J3Ee-=uXVCO]@q./6O_I=I1%'tikK3ahxR02qVMF'^J>BK^<oMrRGgLq+29.tuUeGX]lQ':GViF2,`EH>)d<-/J?H.>lcdGL/Gm'DGme-0W`9CuD:c$OG)D5gGg;--<Ev5k,>>#-(35&9(ErmZ<TT9'KMM')>MMFA@;;$47Y&#r^).-%5;'#`wX;9bMLU8?8I&#DC_O;'h_/<)^H&#Z[$l;=S>+>6sH&#0E2:2'9PF%(<PF%)?PF%vU=R<38*x',HPF%Z+RS%*>;MF4Y_e$Zl_e$a(`e$g:`e$mL`e$s_`e$#r`e$N9&##TQj-$HSbA#][q`#,umo%G25P9i'6cWB'#0scA:MFGkF>#^K0L,TI?>#_,q^#4v2`#LiJa#e[cb#'O%d#?B=e#W5Uf#p(ng#2r/i#JeGj#cW`k#%Kxl#=>:n#U1Ro#n$kp#0n,r#HaDs#aS]t#$Juu#;:7w#FxD@$Hi]A$a[uB$#O7D$;BOE$S5hF$l(*H$.rAI$FeYJ$_WrK$wJ4M$E/bX$hv#Z$*j;[$B]S]$ZOl^$sB.`$56Fa$M)_b$frvc$(f8e$@XPf$XKig$q>+i$32Cj$K%[k$dnsl$h+u6%FFD4%<lM<%m>=I%%97[%fh?4&<d[)&+cZ,&cNm?&&/$c&A8>+')>?(';rh?':$KM'0+1R'`@SX'x3lY':'.['Z2k]'s%-_'5oD`'Mb]a'jmCc'0a[d'HSte'aF6g'#:Nh'<0gi'Sv(k'li@l'JZWp'rUT#(:^8.(Ihr8(o#>B(fGGJ(='uU(l#r_(.m3a(2/Vg('@xp(k%Qv(fkg')@S@-)w@V4)amF>)K[;`)/w@t)Ears)G0(v)_6`0*`,:V*BsoI*#a-W*pSEX*2G^Y*J:vZ*c-8]*%wO^*=jh_*_:ta*HNAe*W>Wl*F2pm*_%2o*]w.x*ujF#+m,j)+9WZ0+iIr4++=46+C0L7+[#e8+tl&:+6`>;+NRV<+gEo=+)91?+A,I@+ZxaA+rh#C+4[;D+LNSE+eAlF+'5.H+&2,N+AmZS+n`sT+QPl&#WTW-vSO>5]s%:_]QA<JiQdrg$Q#Alf7Rc1gFZCPgGd_lgHm$2hIv?MhJ)[ihOJE/ilxgV$$%?v$%.Z;%&7vV%'@;s%(IV8&)RrS&*[7p&+eR5'4HbQ'urRMBb>niB-x<2C2C'NCoxjfC0=9/D1FTJD2OpfD3X5,E4bPGE5klcE99.&GZMJAG;Ke]G<T*#H=^E>H>gaYH?p&vH@#B;IA,^VIB5#sIO1V9JdL3j'#$`A+1WaM9n?Lm9L`B/:h-_M:i6$j:j??/;kHZJ;lQvf;/N<,<A^R&GgOH>G=^E>HU71AlE.@N(%(U.h:[gmg389xt+9)fq8m]'/5.xK>B=a3=WPl-$?hxIUI1Be6SmU(WDnh--u>:5&;#<R*T/]%O]<E_/moIE#t?DY&>E7mgWCt(NCXh;-`,:w->3ChLxRYO-8M#<-55T;-@*Yg.ONq3$R@Rm/[0C3$Xhk2$YfG<-k)e*0(I0#$d_`8$0)m<-T'l?-fl'S-mm'S-HhG<-rm,L/[ERw#+thxLC.A4$P.&tY4F$O-qdX:^`Jd`M%VHs-2(N'MH:abM]MJN/@]35vMXZ&M#[U6vKB'%N^G.;#VEkxul%9kLL1CkL:LS$v@Jp.vshG/v:+m/v1CE)#xFN)#K:)mLq$P5vokv&MLq*'MIw3'MM9X'MbjK(MHAf7v>vTB#nd-o#Furs#qd'f#nFUn#Ltlj#8rboL_Y+p#aN#<-bOV].jmP/v@+2m2p;20vXgr0v>H7wu:N@wu#xkJaU_d:$:+f1$1D`0$_Nq3$Q#J^.m5w4$qt1IM.ITY,f2v9)tOm-$+^W%O#/8R*Wa#N0/hk*vmnt*vc^^sLKf45v?iD&dcUTvL,'01$<^W1#@+i;-sugK-P4H-.*GAvL5$I/voX]vLin#wLD$#xuXOo'.PA1pL0r%qL=:SqLuXEr$dRKSef)43)ELI&MJ0?6#sVZ$vVB_S-wD^$.ORSvLL_^vLWq#wLBL30v,w'hL7/;hL43DhL&:MhL4KihLbsfwu<jZIM(jF5$*?t$McP*8$XA]'.gh](MtpNuLAQL6$Z5cwL.^2xLalw&MLGfqL2PbROu+g@#2kVW#O(.m/9L)W#Np4Y#h).i.@8mr#ZH5s-Hw?qLaFer#&>lX8TOm+shbYp/:+I/1<AqD4X+(RET=2&FnRg9Dc[goemldof/(ZAlntjf(qTCJiA'dJiSa-fq=e>Ji0I:vQLmm?BVj9VH]''m0JjCD3A]WAPhNNq;#uMq;sB_^$_7'vL?MI&M0GfqL9+1a#+e'f#.f-o#4w[K8/H<MqSeju-3?dtLB*1.vde4s1dk`4#Epi4#]Ak]#ioF@N-PU<N%,>$MGS'(M$+>$Ml>u5$'Ef9$Dh](M(P*8$<77Q/kX,7$%_`8$U8_5/U#+xuLosjLju'kLPLf$vu0*)#;T%)v+1o)v?OF*vtEeqL4BS,vcU*5vuNK6vxiJ(M@Ne7v2Up58p23vQ9#Q'J&XflS?:I/1GbnD4Q4(@9d`6pRgNOC4;u]&vnp((vPv1(vl,D(vj=`(v::1pLgI^)vl1x)vqHo1vKJt$MPmL%MiI]4v$7-&M(+Y5vF`@+ME#)hLu.;hL,8_S-rQ-T-Nad5._^-iLm/,xum[WjL9fbjL?w'kL(RqkLR@F%vU@1pL]t%qL*eIf$QRYK<#=u5$XERw#YiVuLhJx:Nc6P9#NX`mLUtTK-MLME/t[7)vIW[#Maoi3vI]9%Mj)i%Mvh45v`E_hL8d7iLZ^XjL3Tr#veF(v#$@0:#wXkR-@[kR-ABFR-&_W#.+;1pLK,^)v6h^k.kBf1v8nK4..pEZM:Jvm#2=Dk#[O]vLH[+p#^s.>-hW^C-qpY@.6I=2$,M-W-tal2Vo%A4$iXkR-2'wT-D5T;-E5T;-F5T;-Oo`V8jcbi_F0,n/*Dj%v>^8&vorDm.<v1(vI_mL-H6_S-YFHL-;Q;e.#[42vs(wT-WS0K-Tfg,.K`@+MBQ/wub3ChL::MhL<KihLE'Y<%K]D_&H=?']YH+=-gbaC(wvK'JJGM'J=I229_w@A=r5HE#J.-Y#*d)'MOrqU#`R%T.$Af1vj_nI-j`nI-'3@u1'sX2v`_h3vDr-4vehK%MJH(]$*YXoe$uf6gwp6Mg;qUig1Sk.hx34j'hu?Mq[o&vQJURs-WQqhLs%pwu_]-iLrx:#vglB#vinqU+k@N>>5^E29.OD)Fo*U?g(HISeScF29G^.mguYPP&-6DJiJ0gMq`NT(W,-Zmgq-_CsKxsOfLgQ`to_/,sDw]9V-Z.kX.ctOfSL7X1SEej2KsX?-6J6t.cP%)vKvZW&%0sxL(dp1v_sX2vdl43)rk+p#Xf-o#=:Z]Me%Y5vS22].qCYuuilc5&ais^$MLI&MW(A4$/WjU-ikUH-j%(m8L8#^,aGcoo?wt+sc]#&c?vkfVGe[PK>bfMqckd@k_(s+s=MwlgRK3eQW+cCsIRu(k8VAJiv?w%cS1t`te/N.h=Q>Mq4R7;nOT<b.K,l:$I5T;-c'xU.?@28$W5T;-))m<-H6`P->gG<-9_mL-FI5s-:53k8U-?v$(cP]l-:.;n(cP]lY`>_A](I/1>h_>$FaFWS4klgLqbf#M+VTvLpk<s#XPc)M16W+9TgNYdH;r+sH;r+sGd>Mq1+Z]lEtQ&/OQMig^N*4F/<M>5#T-:9+:>GM7`Y*vd6$r/S=B6v#]X*vG[6M&rYaVd_3n##sI0#$@Ef9$I'89$W5T;-05`T.^;T6$gLUpMVj9=#XEkxuv%9kL3.8$v$RQ$vlXZ$vOJp.v'iG/v&lxvL>L30vEw'hL/6Y-;gf),s$.*R<smP,s#@_Cs(1)F.NZr^f&/XWS7j<s##25)MrGl$Mw=SjQNX4?-%&jE-4x^8/`oP/v=(>wLD1Dw/WTW-v2ee@#Pa,T%i49_$s[8+MDR'(M3^8+Mg]8+M>709$)i)M-tugK-5M#<-TfJC1swY7$]%%w#;_`8$M5T;-]fG<-^lL5/e?,/$H8'E:UV_]lMK5qV%%ruP#v?e?cEU3XN%&L>hp#L>`xii'c64ZdQC:xtK&/L,qeQf:SDbi_F8RV[P=ci_9,N`t-BTs-d^-iLGB2pLq]G*v)1xfLZ9-)MF(],8+qPGa[I@k=bVQk=lbp(k)W,poE1@ulE3o;-$o['Q)4O'MT3hP:f7`jV@V^9$E^;YL<-N]lEgei_sR-;nZ*O/)'7DGa6j18f6j18fRUr;-XvQx-oX]vL:Kn3#u0ChLql[IMIwW8$E]Lv#Tq.W-*UUv@vEL6$Yqe8.j[X*v*IwP8C8N[$Mm`CssM%&++`58.=^o-$`x58.1hCVZ-)Q`a<u.>cI^(5g217m'4TTj(&w(a*LgG)+D`.E+xUZS%MY<s[rW`l]hJhre6+=5g5S#.QQ.2&FOP62'0RNs-a7-&M_*A>-x<K$.[KhhL2-50.KA1pLoxM..h^^sL^IN?#XQ]X#Z.QV#e/xfLpPAbMia:%M]CsvuZE_hLpvM$9q?S'f1gu5/<Xo5#BLI#M'TS#M(Z]#M)af#M*go#M+mx#M,s+$M-#5$M.)>$M//G$M05P$M1;Y$M2Ac$MfxD7#d;G##tUN5$kil%0l5w4$tb;<#W^nI-QP/(%)*`EeDnC&+q1mD4<5'_]:7aKl@Lso%*m:Mq7sRjr0'2hLW/;hLN3DhLwtDi-W6o'/<s>8%0+`@kBgL1pPlAX1QS=,M+e7iLgB,gL0]8+M1,-Y#Y#bWS-9jb$K74/(C70fqCD_oo$t*;n&*=;n?=:_82ZqRnio#@07L-Kai-F]bjG]xt.Vq;-XkUH->lL5/^CRw#_h](McDcG-E@eA-E@eA-CY?X.5kR%#AG@2.qHeG;fbI_SlFUe-5R-iL8ACM#V^K%M`]wV#)=Y0.Blm7;0[AsRAtelS%$$ZZbXgrZNpds[E.$2^3('8eQ^gre5/R5gW5Bv#`2lj(&v%a*iCg9DR?f;-RfG<-3Y`=-,s:T.Nhi4#fqpk.5A6$v>NXR-/]R$8B'CB>Pq8;?24ko@#E^?%=,ks#EIJF-GB;=-YX3B-p$KZ.5,l:$Hlb_.1Ef9$NFlDNXGp%#h]hR#Ap4Y#MG5s-lM]vLkkCe95cq]lPn-ci>%V;n#d2]X#n#,s[`w^$vFw2D:,ks#HIJF-^kaf/L=T6$ENq3$_?/W-jO6LGtvv^f$Q#LGJ)-j0V?78.C70fqv0aoo]`l;-%coF-NBh@/R^8&v([`mLU,_&va;XGa&I@_/*um-$lj0`aR;D-dXTo-$_go-$bpo-$:=wKG&,2F%Bn8eHC.3F%RpFs-a-:hL9e_p$NZq^oU9H)*CG2d*H3%I-dA[*.icajL=rtjL5S%$v28M(vDu[fL3^8+MU`*^McH?5.P3rJ:)C<Jij[p(khDv+s-j>pog#b@kY3IpK-m=L#vOI@#C;7[#)S[I-V6T;-X6T;-_6T;-a6T;-b6T;-e6T;-bj;..f7-&MK.6:vJw'hLm<c-;DO._S=2D_&o7L-Q8Hk-$HsN.hB$=ul1:Ns-KFeqL^^_sLDX[&M^9X'MA:a:%N-$XLkvSQLiu2*MmW'h9/q@3kK74/(8b<ul4YWV[h+bd+Y=#*vhev&'xHP1pY]p-$CDbCsLgtoolKpE@6Bk-$_QCwKRF<ulu22_ABoif1bh*)3xr.2BjPWU-H6_S-L`2^'^4elS&4aiT3n]fUlvdrZ<-Nwn^6_S-3%&3%bJI,)4[/g)eHO,*9vcG*Ll(&c7ob_.gtQ0#7GJF-'8=K&3<@?%Jkw&M@I&o#mJA=#b9w0#[:':#H)BkL&c7(#=AgkL4_k%vtrl+#iDtJ-xQB1(C[85&957qimi3,MLsugL*>lT#]H)uLiv2*MHD8#MS&`AMrGBt#AI[s-0o:*Mn7vm#]?eA-G*.m/DY*9#(<`(vHD_>>5qTq'7.gfL<*NEMJ`Kk.U=B6v,)Qh1:@.wu5O@wu7$+xuF+ofL+sT(Ma[e+:kTO&#LwOw$H>QJ1I:Xj.XEj%vU[@Q-']Lh.hr-4vho7^.PZRwu.,LQ:Ld;/QxV0X:[,bV-sW7X:xbb9Mv/hc2J46X:)o6X:3YKd=_HYsLCQBt#K7i*M9A;'<;&:Mqj+c]ldcF.b?.:[/cd;<#T>6$vj:=JiTZK/Ms+Y3FM_`3F*J_3F6r]p^6Gl$MWMI&M$'aR#+$=]#Kl'hLXOK$N6RFv-PhtgL9,3;n8Ro1KEfsOflTxIUKxsOfg^tRnY'PfLZ/DrdU94`a*e?a$mku1gv:Cv#s$4j'O2YS%<^h&d2)>$M)@sF9_:r%c'.t+s8^%w>^^q&ufc^V$E0gi'h,k-$+sSY,Hq35&,tK1pQkeoo3kas-K&$&MkQ>T#]Q]X#PL)W#@9R8#W:':#9)BkL0Rk%vsFk7/%2x)vTcajLS([##a)V$#50QV#w_?K#&RFv-fF278ZOx5'Rij:ZTBXT.BRQ$vn0&F-h>9C-[C]'.NsINMI)IN#xDQ&M%SL6$/G;4#gE@Gaw.@8f>$Uq)kbS(W[@05^[@05^w/B<-W:6L-[eq@-Rv>1%:dbY#).Bk$WI`Y#RT:;$Ki60>@_Vq)N2###`U18.5vC)+5oah#H#?X1-ep`MSfHWKA6>##*&>uu/>n4vXBg;-//QP0Q@K6v%H)8vWe)'Mo-Z<-ZBrT..5HPJg?wx-;InuLW.gfL=BHDMAp9xt30p_&db/TV*/x>QcDR`<UmUq)m0q1BivFk=u_@ulXf,;n-#U&ck0U%OH&9L#t]JfC4BFlSXu-L,&RS7$aG2eQ&*/YChJWvO8+)t-QXu=Pbf5LhK[t0OGD<ul[&+##gxK4FEc)'M=:-)MwEL@O2QSW-9#Q'JS66]XWsuE@UZ)fq[[,#vbe)'MpB'9vW`K%M7](p.gb1ci[p3eQBe%M^n5:Mq3Y>GaO9d?.430`al+P]li$BnE$0c'&HCEF%>+j'&cEt'&`g2E,L6rENIv'w-C2KWNrd:gLs_8D*Jh7P>.5K>Y0dU<.bqd@kmipY(v2#wP<,,ci1no&(%8q;-p0r5/b,j<#B$4KNbTYP&G1]1vdhcXQwXEiK4:5s)axkxu-U]F-Hg(T.v3o-#%'+J-anPW-%CWF%wk$DE]2_u>CUS(WC@GfC/0X2(Ajt;.C=au>[XWo$]mN.MM2<ulQna2MhApV-%i:L#R)3wp0u<@'EO5]XkSuIU/rbCsW#68f?wchLuFf4vPco(kB[@&c%5/fqH_$W]gS;w[t#?D-MT'4.>n4wL)1f,v:OYS.Ms9+v`N#<-l/n39H9kxB0MFvQl)Eo[XRNMqGe/Qh6c0HPACq19TUkxuE??h-pxP-+SJ$X;C,#/MQ.rOf<-FF%nY*GMPi[+MC>>d$_WCAPdsd$.]`K%Ml4l5vDeZ-+4eoRn7&m'JW14.$#AK6v]u?4vnrX?-I4t;MEhE#NNTwP87G[;@K>Z9VBDo1Bv#s.:*f<S@<h1eZ*^n`FZGm?BMT0R<I-Bul&0MK<W*wN9f3bW86u]+M@+#GM0.jp.$+)##*x:L#aOEk=dF#Pf]gJlS4XU.hjD0;n=x>Ga$8(44;xH3k9>(3)dUTvL5oR_)@%I;@<vPYdxNGAPoMQj,bN9E>P03YP%%N/:tH%kVAv^oLA6L1pWshV[=sOe$[-3ciQ0D:2Qnb2v$P`iLT2Ru%<K]9vit&F.'8f:)L_bh#j:h+vV(>uugfFw&wC$68QL,IH0PkxuSY*+.WAt$M`>oW.nWH&#K1T)/UxbxuxX/9/9%t5vq25)MGuN8v`I2r8j,o=D]w(#vb7i*MOE23v9+8'.ldKe9+:cxu3g(l9mP`)J)@sQN)L&kk).1fq1]q;-wSFv-hFCXM8_&)vI'KV-UY@/&jH(@0uIO&#W>c[Mi(CLMJ2(@-wq-A-n%KkMF?VhL_/P-;(d/F,Y5^49mT=_/tIkxuLNFAXG?d:ZkgclgDelF%Bi.1vP?1AOP3&W*EH5.8uPdxu%8-<-#E9P)kYE5v`l,Q9X8w-dV0..=4>,ciVl'##k;Ls`s8IF%.E#/v:5(@-ABpgL/Yqm8hm'#vWc#tLjGKp8:DZEl+bl,M$,cP8f_kxu,hG<-sk%Y-)KKF%BSkxu)l4?-LnCaNu1i4JWVGlSCQR=13tTA9'B0Xo11<ulDm.#vENSkPu??uu&m-c;6JOKN^V_@-i_F/b4(u48c[kxuf(#x7Ik6w^a:`s-9K/(MUX>hL5(rOf_tBJijh`8.gZ8VH(F`n#L5Z98mh$=LJOr;-f;MTex$U[%*lLW;FlDBMZi9xtQoBHMja4<%VF*8$1NNbWKq0VfH-aafg<q[7cnQ_o8&(bNeNAQ/lMh=cMSCulE^_lgp4(@.T@NJ8mUgE>^eYq:/igJ)Ou(S:Fn(eMuOF[(v`3vQfVad=]dlX(6@tF.?;s`/m`gaN&lZP/a8G&#3q73i[:_1&Zp^q.[&+##>_;L#8SBgLgA7:&#Zu'8ZX`-6%2xq)S3/q7ZSkxud_8GMqn,D-qjsNM-Z]'NK/[f(*6=;naK[F.Uf.3)b6*k9R>Ik=&Y'#vi9TSM0@1p&w$a8.%WEo[PFrM9]Zb&#LR:xLh_#PR,2;x.*l2`aGUZF.:aXq^b3@78.0xjkp?i-MnApV-`gA@0Qnb2vbe:F,NkTe$@DQ&M[(Z2v?q8gL>%KZ.]l4:vq=c[M)/Q:?cXbxusV@Ji1b*W-(99Wf^dl[$JJZ)OOiA,&bO4.$OH)uLeWqWNG`_@ku([M>8p,]MfqGhQ`7$##]1a8^Mo*gO/1av7nQO&#^h?2&FXlxuItEf-@cx'dmP5VHV'TrLLI`+vkw`7T9*@F'Hqn90QUns[%>W/%Auni'AK3-MC)S8M_%[J:%U`>n.EmmT%/k1/wZQ&#C0v]+K;Ax0IjW-M*e)fqFre4VX6jg:Eh[,tdwa=cq%:.M34rOfLEM.h.5Up7:4K&vgd6^;PwWw9PRJCM<uA,Mn3I58hXr@0j_M^O-3WeO:$mx'iJFA'm]_Y-Rk@g4?OvbXx)cG%tCS6OSv;v>#`I'$Pq<M-721T(1vIH<-`WXC/NcK:eDs*.0E#/vIEhM8K^b&#W8s,:EmZh,ZPkxuHA7#%[6>6SM_nI-Q3-a$L#Df8@xrQ1Xuvt.>9Crd3oYF.P*/&c7_aX1&^nxugqiU%%^8Fl#0Bo%.ZZ(Wo3i-M.apV-g'Vw9VVCW-J>I54xg)j_2JXxOeD6e8_E?e6FT^l+C7@m8W%F>H=8=#vW//9v*6_S-/2,%M=VTvLnX]'N3tD#Mff=rL7i=5vLEPh%-eJlS*l2`a#x@K:Z_b&#%QPI84aKdkD^l2ALinW]ApgD9SNf^-vWiV:>6*;nX)s(kqjfN9-V3hYAVg99Ycb,'euO<MA;/$(N9H/$-r>,Mr7*7)or9+vW-)0vp&>uuHCK6v'thxLVOj6&i5i*M1eM=MmYU%OAu`S8d2s%c'UaW-<l@e?kTMd=3Y-rXxhc9']=LhLi=kBMl>m]%xrY;KY06IPYcvIU[_M>PA().&kp6F%AJV0v.'>uuwW#t&AiEiKP-h.$`=)W-gqv?0LxHlSgE*L5BZQ1pw[wp.>2JfCMjaF.H<.F7VeifViA>W-,`UfQH&>uule)'MkcbjL:%x+)Ts*G=j*k3X__m58&Skxu'x3OP2S=_.Rr$8#TDojL7;C.vv-W'MTWg?NAi0E>O,)r;0^;S@]rX9i/rbxuo/p>Pb.M68p80RhR`r7@k>7*--*<+Q+RN,+&r?bNOeU.(J&>uuWl4:ve?1AOPs5M*0tMhL7Z<:M.U#A'/o2T./pb2vbO)V8orX3Famo-$1LQW&e5d&'rQ7^lCkY%OFh#DNSkoRnH+S1pqmC`/FlDBM6.,cia2-xgg%7X1-8ci9S#&?7VSDV?NsTw0peqXM)g%8@Xib_/kUVV$3m]F.P10]Xd?k--4]@k2-bl,MeU?M9JUXh#g-k&P[^8c$Fb^.$_MOe?41(#vg0;/8c@nh,/(d:VAF9.$5lw69=i_nN?b>QqrwsOT6eoRne/@fFj8t88sEp9;;B%qBL(De$aQhe$kBfj93rHL,Qo$w%ujE88bREX()Ic^?L.&,,93AxtuY8xt/L[e$GDc^$n'kx7oQN'O_^Oo&u>nEIv:%9Rpd)fq*SRvn0,UT8Y-[LGb>O5=3^N?[+3.GW=g(P-,BP:0ABKWQ.HS(W%>U+`(MrWQUuXvLMH&FMEQ0T(N4<8$gr$P)'/###OW*W9`?QfC9C?`Ei:D'S81+@'[]l-$$Ik4Ja]:&5e^+poHhcCsFJx(kmqIDXXnjW-T/1u9>ivIUgs&@0hs6]XKGRr9aO.`a`Zr?95<h=cmHBX(8_h:ZxvPV[gw_]lm&d<gA2_k9Y05)Mm$1l85kO?IC<wU:e7`I7Zi>IY18vT%'9LGEFC>REBCh,M<+gcMGxc8.kXni'0HgJ)H2g&v[5n#RLp.n$s+ms-Nbju>NB.&c]@wDP%?xs:AX5;'@C:p7%kJ32e<F,%NoQ?I2In20*?BulLm]V$#m:?[Iq>9Pf<VuQv?Kh.'DV#qO%^b%(:I7R-c_FWWG3v%Vhr]OW`_@kQh=ShM,C<.[mjl/jJo`&liEs?>h=@ROrPd$SoH9./Cf=c'?,<-57u(.r;PDMF.,ci@]Q;QbLw<-la,%.>8i*M+&m18+0TQ(m*RI'FT(?n*/8('ts*citgcH>YRQ##l/)JtG6^)S3%&Qbv.Hs%:-/9v+OUb;]dkxuc0;t-Cj](M8;'9vtY5[$Hfx[8PEf>-=(kVM?4'1vqTb*v%J)uLP''1v4At$ML<e9M2'ImLK3T+%c^U.$dqPB;i5%]0_xF3bL1r-$jx#M^=i`=cfq'm9Pl%dN<2h'&8Hk-$Btu9M9ri'&315]XIiUPKt.P)=6R(eZ3UpQWQjuRn6mk;-<O#<-)Af>-sZvxL_;ClS`Fi'&.35/M?vkfV'KpooYk(.-KbqrSwYW49;MQV[[3B8fS'Z3O1]gd=$[D#&#Sp63jKlQW(,-68P]Sq)1d^LY+Wnxun+B;-4(De$fYogLsUJd@1m_lgfNX,;/dNYd6*=($/Z9K-G>@Z8Fb'n'<p,>>`3q.CtJbA>%u,I-K,l-$'kP]40t79&VdM.h1dg'&@'8F.pf`r?m+%@'U;Uw00YNh#N+_xOKPSY,<CKi#Ya2'#8Cd;#1Ob0N^&5h:Fx'#v,.FcMll)fq-H&F.KYC<-3U^C-s%@A-Oo8Z.#Mh/#@;Mt-Kv8kLFJi'#*u'KE3+f34w+h;-Hs=g$d0OW-Cn;L#NoxOfqO0XC?RqQ1oGRe)&$+;nil%:;scm+s`=4B=Zrkxu+Vi-F=/:#vv@E-vL#>G-Ep=?'8,)0vLS<V(W$Qk#9'e,MITi].k(>uu?$[6%tcudDLJ?X1xbbvee`P9R+gkq7wFc=p)X8K'rIBEW>dd2&e8/@',-k-M]p/&Fq(gcNph&R/[$%##*P6VH(9dV[g+:L#9iUhLsD23vEf4s1P+rvugl4:vg`s-v*i](MFw&1vw4vM8a`'#vRw?qL):McDJuh?B&cZxF0iX3Oft)##vg%M^unQe$QAi=c1xc,M3'C]Q%.l3E(YaM,)FdQqGZvE&H(C9@dr=5XEc)'MkCl5v4Q42v4j](Mo/%+#Zfb.#F*]-#p[W1#B:h+v?fdIMa=?uuG'suLh7$##E]?w^:o]+MHZlS.p-/9vVZ`=-&&vhLsapC-<Qp$.9xhb96<Wt(<,R(WJBqfD3b/<-8=.FN$7#GMbt>P8QZhV[PGBX:Rw3kkk?Ie-,3hi'HkUp/j.Q`<S0(&P)q#^,Gro&#FV`r?d6(@0<e%HMQ$axL/Kf4v@1rl'$*-,sQ`FqDu(wRn+#VMqfSMfLIclO-3ude%sK*##llDrdw87eHQ[f_M'E23vn6`P-iNM=-=?DX-2Tw?9^XK&#VE32U[ZKMqK44j.HTb*v'_nM.qr$8#T>?MqT@NMqGCv?@@<dD-8txr%:`'gLfmw&MpI:a:-kkxuV[V&.HT:xL9WZ)Mp#-:vbTrP-lV%mHhfNYdbpSFeG-Bul_nui_N^-Fe7)n9;=JHlStq,i4#2i4JR.W(W%[3Fe<t@F.kx]%OqqZJMrqfr%l*@gLd0$*9;4p(k_=hGa9SR1p0^C8fZ,g>TwU.`aQcmi'we=Ji_Ns%c+/^>HN;$XU&vPe$Q(#PfRlicN.h7^A,@6T'>CvGM+.D:'cEQk#BoiT.WeP/vJ*B;-p6T;-ZdvI'EasjLm5=%v4k*J-QwGd.v)^*#NU#l$Ai.1v*RFs-H<@#M^AT1vr/&J.A+rvu5mCm/]O.)v98:3v0<X3.g25)M4Ep3MMHJF-?^W#..7gwOst%'.Wv?qLjeN0vu'>uueAOl:AjUPKtUMW-ka#LEr$0?.H+S1pFE(?G<$+KPV81[-gn'aQUGlg*-vx-:[_C_&Om]?^aRZKuag[l8?xU3XYH&FNG'Kj9:rkxu%Th`.4Q42vcIF0&pSsQCALfr%k>&Qh[@On-4<Ww9(:)dMg;=@8R.(@0p@LaND%U[%(T]*&F(?)=B.%gVnX]Ee;^P<-.FTk$@*QfLODtL^/(DgLJ'/r)u8kEej>.FM?j'Q:;loFetQKv[$<ZR0kp+X-nH7X:a`R1p?eNYd5o:ENw#3m&I8]_$Ra=?-:W*'%*s9KY4mGPM=;^;-m)tV$%iV/:b9L#vR[E5vhmDBM1.(58]bi63j0e-Mb33p..I)##U3m3O5R<r7a&v'Zahi+(Y3R#1Mvk<-:M$EOY],*(,v?qL]WN0v/qnB[VV-=.qSAxtTw_GMUo_@M7Y5<-F/B;HF;.-FbAHDM0Jc);:+<_A#J+Sj*cZZ(;o56+CHB,33j*hb9koRnMwcCsW@36/Cio=#?eY#<3rUv@41<ul`8AT@ul9#vH*Q7vf3Z[G[[T-Q4WQV[Wuo(k&n_`decq@-`6e2MfoF58+^Uv@VxUE%VY,;nwIF&#VJTeM4UZ58Xg3g74+mxuqnw2.]($&M[5?6#7k9'#ZcrmL__5.#orarLJ'n'vk*V$#_M>8.=sKiT0+Y&#;ht9).5s9)H%4^,p*N&ZN,@tLo&^%#VNc)M#8?uu4/0oLotP%.KqZiLxwc.#;x[:.2Bfl/?(LgLaC?uuqBK6vG7T;-6Y_@-@4)=-o,ZpLhupg-N_Ib%RHr.C3kg+Mc`4rLQhCH-9O,hL&Y@U.tF.%#Y5&L<Spb&#8.)mL7xH/v)F*%;`LE;n:3XrHvwKCIZ=i&MKr8V%jjg$'R%Fk4^)b,MS1$##ok`<-2nVE%Y-/W-CHXF%L#a8g)eocOH:I'&1Xd,MEj5d.<Q?(#K5T;-WAg;-mC0%%xs+F%/4*.$1jW%O7fii'?%T;.1M?v?*L`'/v[R>6sOB/;,UV8&<Ul&#Vm*##-R*<-e&l?-i@1).b[XOMoTW,#CJ*B'<,)0vg@E-ve%Md%;q1;63(g6<`e[%#_ocW-.[*@9bk^&#Sp$7*<Sw],'buP9.`v'&#'EgLR2jaM`]`m$S9cw'6o6G;mRO&#+/)q%ob8o85,BQ(PQUX%hgtR1D)Vl-n89@0hpNw9(xfQ/CRm7RH*P1pA>;q%u'Th#I]GgL0DK;-jaavPrrM+&+q)XCL6I>H%tT#ZMMS.hmTSx0Lmd`t*:LKai7tZ%`i#^OxRup7`Q;'m?Hr.&J.?^Q>=5HM[OEa6_8H6/k(>uu98i*MGq_@MWFlSM>GDd'He#f$>HA=##Lj9B`-n39Q&H/ZN$rk=XYkxuVgh).f='?FP[0E>eD9QYdoA5-*M#B0.3e6i8m-I/B/4&##IxnL/IF)#xQ1a3#'D(vH,j<#o8E)#e@>'v.%),#9Ss+M2Yi69qrQ>6K&5m'7`sfDC7g;.N;0X:3;q-$=Yq-$tPDX(Z)v(3)K?rd+AxE7cgcw'YpBJ14&5gL44[M0M8GlSM.tOf>>*GMVx(hL:p@(#A+rvunDMiLC3I:MDPF)#ANUpLTcbjLL7?uu%oA,MnNEmLr+:kLe2nlLl(r4Jt7$XLtNK)m-sFZMP/2M8s?Y'A[<549wY3dtcp$:Mcmhx$?]qamoM6I%nK2gLg^(p.>Vm4J9Z$ed'+Jq`dksWUjmCK*C=Cu,JMtcMeu]+Mdx)fqCh#PfGF&FnY=i;-2T2E-pn0t'S$.-M^YT9vG;x/MTo4w&cbgE:IsfFew?Z%Ob,`9M$sI[0A1$#8Hk1eM]eO//Q(>uu9m]e$?uh;-BK,hLACg;-ptH/8?_,:;x-d,Mb8-)MD#Re%Sw)ed_2e+MvDuCNru@jLBh0]XmX#3Da@Ci)kI5gL67ri9tB[l)F8KUAF4w<(i5i*MhLJ8#>W(EM(S0o)rW1W1M4$##dI&d9D+`_]Z?C.$:(;?RT#X_OYTZiO,$839tiZ_#cl:;$(I2Adi<PM'NaLfL/soRnC[=S@*x:L#IOX(W90'(&TaZq)0(u%+n=_NB2G_Mqb(o1BN_<<-%ZU[%GtH6;$o=5v9;@#M*II7vk-rvu4'$&M.@uD:pv#obnOQ^$?d)fq_l(<--qLfV8_(E'<<EHM7-[SA8T@U;lu#Z$IQ8NB?q-L,]/oxuuB50&9CV99^v<9'eVaR'0si'/f)raM1`Fo$;8n`mep`7>dAQV[`M19.CSvRn7ufYoT]T9vPZ&.$)S+1O(1>cM<4b=cqVxL^&O?_88#[(WPCRYd-;txuDF40M0;q&vpx(t-]shxLa2h#>.8G(dT9u2>`/12Un6/<-;wBd'oNj7Rg3/A=f&BlS)()t-mSJCMk)m<-Gq#-.Bwgb?G@i^oBi.1v88K$.M#F$M3=ZwL5fDE-4jhp&p6P1p8FmW]hu2*MIgT=>RHXbdOo9xtjSi,k1[vxLG*>$MX^uT)W2><-ihG<-i&kB-N^P_-)0kO)9Pof$(O;)N8)lH(-@8N9Q]kxuagPhLmJV[%*(3<-/:J1>Yejp'WI(j<JLFk4a:;<-UgFE<-[KiY#iWsQb6lKM)G]('_YlHMkL-j9[V:C&/#@`&guFi$<3e,MbE%DE<p$w%.CQ6+;u2Q8o_4K31]*+&X^F<-kR>K&J+W'M2YRb8IRkxuSb59%6tqxuO/6*&Z8J;MqmHi$u,^oo<'U492$9e?Mmk&6Mx,:v,nvd$q8nxungGQ+<djGMr=ZwLpVq,7Labool:?q7Q%;WJmu.C'3^,<-t:`P-:3Zl$LJCq7_Hr%cd]:S8u2*;n+.P88EfS&#3Mi)&X%BJiOBs3XB]v^OXm);XT,8,(4ItL3v2Za&Gn<Q8)q3WS3rcW-Kp$4XO3I,MEmF58Gp.5^>?W_#D-=;$;W*G41uFG)Dua-6kP]CsK-45&ZpJe$k3@M9)tbw'6a.;6Ku%*+)UoRnF?*F.'pUh-+trEc01<ultDgQ8@66Z$Cn;L#[_r-$F`T.hV,+ciblwOf4owE&KAP##JQx>-NNe%PZM@O:&[kxuqKOP:F=0R3gI?$va'>uuWJV0vvN.)vv?t$MrH`+vThG<-DBg;-0-7i$nR:xLKKT1vBP'#vF5)=-]7><'Hx+#vgI)uLl'O0v/.)0vf'>uu]Z?,vh*OV0/%t5vgj((vlwE$MM?5&#EwRu-]_ErL*]8+MB@w/v9?nqLhPwtL)qT(MX]8+MnGl$MnQHf?k&r?B<R4?Ipb<^-ajpx7%];-`m<EJ'cV(.D[f3'64D:wMNP>rd,QxcMY+)GD1h@5^%i:L##wne-CTko(]/-8fvExDX=i`=c;ao-$8Jq-$FFHo[>MFo[4.Un)Y#qCM[(#GM=lx8#&u`^MG8ehDA%>R*HPn-$>K#EXgL%JUOb4F@LZuRneQ]oo4jfGaMX0fqQft,M>/wHE,Q]SqOA&l;5'V(&-*Lv[,U^C-Zoeu%0$_Wo[-0w7]K@k=SD2K:ivjnMl8Rh%[OIlSof-8fKv9N91$:MqC^>Mq;V=#vWpb2vVG4v-2aS)9R,IW&J4$##.jxMCO^C4+(Ykxu9k%'&Z3YF.ih.<-I]CqR`aQa$PwB.$P[)sIEQ:dNR'_r6l5LMqeg;kOa^FlS*nxP/kQ%##v$&JU]wW/MQhGfC?.QGa%c<MsJ:S(WYgvuQt9fDX4v/ciMtG5^w)0F%Z2=_8%1/R<$h$GM%9i:ZA-gi',W;R*rmj7RN^4F%K`xOfgVT+`B[[k;PE0_MX6f,v/-W'M6=I7v/U:xL=8'9v>9WX(B1Ld=TQ'(MdhE$'lY`WH(lkxum=^Gla@15%VLg-6Zr>;n-/c=Tiroo',WP(HZ)nQ't1>gL41%mL'sJfL1RAbMth_1MvYdV?@Jcr)AF4wn@pf_%8q;r2&P?FNsXl58dWU4+G%@j`;`wj'r2e'&Adk-$srwFMq/'4&]o*:)9I5fZJKfs2e6qa-,^W48r_'#vU'1GD;fAfHGK6TI2@>S3bVa/4VwE$'_'8vP3Z960E#u29eWQEn<UbjDk$P%Uf?t%:hQC54OI/(M.XZ)M'Xdx%p[>w%J+np%NXI?PS#4v%ctDQ8Xm<B.ALSW8BOn--+=*nMF)7`-'R4EPF+bbMIb7N'@:t-$'XD-M2-'vGCPYR*cQjl46rkxut$XF&qARf$)(Q7v5@W6&)LdCs=7@68oaA^HP?d:Zq,^KCE&9bI]Qmxu.L['&^R@/N.VR#'X-u-$?''32n9b=cgkW(WQs*ciHq2IMgqp5R>/l99n`l_dY]xk(?#`q2T0s%c3#T;g)`Jg%QIVBIG^b;.8;-`ajsMq2dgK^Z_.N<B%(#GMu<%eMj8Lw-Ri](M/k3C9m((#vxcCaM4HaZ<ivadXuD3U-s5&?n7FBBA),,sKKHViLFx^x=D`d--Nx%F._OWH;NVtx@/1DBR#w[;'7U8=)XNg5+b-fO9'/###9'OKrUd&>GkT(fqOGp-$k6s-$VOr-$.ZaCsdm9Mq@-vQqK0'1vbQ42vawR=BkJ,2:$4x34%DP_81);MqHQ:X:HP_ooEe5F%/.wO9wIR*fx_sQNv-8W-CTK_&o:UL&S2`lg-$uxY_ZR]lbJ]SSBKD*'3(b'/S7;-v.<?g-F/>wp>;0dM;0;a*')QN9M/:#vk(>uuum:'9rG4)S.n'N,'GZW-d9ji=tjs6gbjL]$J8(W-4$?_A(kh&#:Bl`M)v7,v9Vh3vUDM.MIYjfLhD'9vR'6;#Q=ci_FG5sIEehX&ft)/'/O?gL0EtL^+.>Ji#SF&#bR05^mV),s[PMk4m&^xnG_*^M8b)u&ANS4$BNF)EKt^LlHoT.hf&BlSl::L#ph'GM+d/hL%4O'Mr0l5vdEHL-#BQxL+s+A9/xOkM^PtL^[w1YP-Q^oow5e&#YJSd:`.,F%]u%lMa%jE-fY)E'h_LX(oBS9`pYj:ZOZ4mi6CQxLgfC%Mxi`3vwrxCMNgE_Of9E3&kYE5v[7T;-e%059EF*=(^I/3'E.hgLEEsi9liGU=D^eGcG5E[f2Z9h&;_aDlGJS0V;sN.h3W&##CM*GMp(D_&l[e'&94Te$ZF.%#SX@U.HTb*v^RFv-;1rOB(-:MqX_3/M6PmJ)DZl)+MFZxF3fj-$es/X:4o&.$EZ0@0&?q/:QkkxuV]B$GlmE>H67u&#kuW9#N`nQ/8@&)3g[Ard.NF,3Ym<N$mXX;.fJp;-YgG<-^l:*%<o2F%3RBJ(YR+^,#WcoIX:?X1#[H_&l*2L,i`08.:Mw],:ndC=Bb4`6;fC%MnJPxuV&>uuRCo'/@al`)HX0.$U^p297Vkxu4c%Y-'7SG57sN8vihOP8vB`#vlMo5#['Q7vFTGs-R?nqL'sna*Gqas-W^ErLgoNuL-<TnL)sJfLx'gGME9Tm*gIMN9&jW9^Q=$##*rxOfcCa-QL](W-<b_'mPF`*%xVY:p@.r%M$>ZwLbQ'(M'Q8g%;&$&MaYKwLatMG;aSkxuuZ`=-JBqS-W1]^.C//9vfSAQ%adZ+%`Qm`F/1:#vf'>uuIbc4%%'EgLs02+vWshxL$JEwAnb2:2w$q`F9TGQ8-nl&#36:3vWW7+'owUX(4jm-$<Tk-$tWHXf'4H]%S1EwT;jDrdpsPfLRrO?-R]t`+dm:*M$)lq*bxQW-Cn;L#d@rq;W]=5rqp-T-8(Sn$fRqdMN8CP8-6wXfkFpo'>R2*NO&3vcfZD6O^b/)*]hsvPhU:nAv*r)/Ks09T%mN.h.5j1B]l7]Xp^@,M3c]r6$e6L,)(Q7v;U/]>]qj.bt<*NMWKS>MIKx>-IcEq'gvTV:RYa,#Is<W-+p%/$,Fm,M./r%M.`N0v9ewhA?RkxuSW%;'uim+sHA.,sUs*@n=fC%M@EI7vH)Q7vmKU_&klZ_&QK<j1.`=L<lvWxF8A;MqsUsMCNMq92X[..$oSK.Q7vltNUK=;.f'>uu'^7F%JYD_&]#6Y1HPIU1s<'<(YxiW82A]'.%d7AC8a?X/d04,%:BxP8X[kxu<.1h$Pl3I$NY#sIekL]lfs9MqHhblgvGbhLg02iL?Y,Q9gM1#v='>uuc<j;-Lc88'KuWi#FN#Y-,AgRUWq9S-jkXkL-ill9i^&:)uFbxuXtJg:aMc'&Eb>'$66L1p:.Ke$8KRd@lQ)F7soKV_2<%eM`m88'1sObZQ;Lw-=2RfLJ0d%.p`)$8O%,C/<B+kiH@R]Md$m18ko`qMRe4:iruN$okbEB->iHi$(:aa%sMJ@'jS(39UENI-'Pbxu5#Y:)x(U8gr2rOfW>Z(Wfs9Mq=eL_&F73F%BEEo[Ts$B=8[lQW-;Qk+uE]w0^k..$RFb@>IS]oo<Qo,ME>pV-2Q$:)'^7F%_AH_&TIb+&gYjk#K01E5=L`t-^X.K8Ek@%>at^-Q)(=X-6'%(83fj-$k>CeHM](W-tuUq2;R(#vkP;(;SbQh,Q+/F.i#CMq[%ukLehhAOP<Qt()[0F.DMkxukkp8'E,>gChbir;%g6h:1NL]lsnlgL<lw&Mq+84vM[5<-F8];'#K*#vT:Z]M-=g08vOU4+^*53)>RAw7>52oA.)#3)0e8KNiN>rd4$rxuVdO_&Kg*HM%_&^&D@n(<HYOV-F%^j0n[P+#b:L/#i:F&#);w0#VtO6#Zl9'#Noq7#u`39#1fZ(#2R7%#)(4A#JW.H#gBO&#Ve9B#W&fH#*B$(#fWQC#jJFI#7aQ(#u8ND#v]bI#JGW)#(^/E#)v0J#Wl8*#9]YF#9,CJ#sql+#Kh@H#OJqJ#<q@-#W6xH#W]6K#H?x-#_TOI#_iHK#PWF.#>3vN#>vZK#?)Y6#;lMW#=<<h#Kc&*#a6+e#k'Ki#f`$0#<fsh#E'vj#7fW1#O:^i#O9;k#HL^2#ZkPj#^^rk#Te,3#f3)k#fj.l#c9m3#qdrk#p&Jl#spi4#/&lm#0?ol#Q]L7#B+Io#AK+m#tn<9#^m,r#]W=m#:ng:#mfMs#ldOm#Tg2<#(l+u#($(3$S)K&X?22j'Ada1^P)%d)K7'a*QcY+`wd*m/eDgM0k-o@b:GVD3xqWA4#q0YcF:O>5*XP;6-Eh:dfStf:@]:)<Lx&Pf:WvlAcAwiBi&k@kLiOGDq@5)EuiGulXU-&F2HulJ4fDrm64<Da(2rxbGTfV$o1foeTNZlfVD(p%&(_ig]/8Jh^f_P&4's(jkL)>llF@2'JVHVm3V>>#1As1B7`-F%142>PO,goR+rbA#V2p5AJ####uZP+#+EBU#^3FA#eKkA#w8$C#+E6C#3^ZC#KPsD#c[YF#st(G#,h@H#@6xH#)3vN#UqSa#7x8i#HR,j#Rwcj#^92k#%&lm#V+Io#;#js#%]:v#^fAb*7B(<6Z3Xx#l86$$)KQ$$3&E%$CJ&&$McJ&$gBr($mpon.>HO*$)1h)MOd0)Mv<X3.Qq)'MqAb'MNYI;#1l:$#`S_pLn#L-#XUr,#*6t9#'KKU#guaT#--mN#,8)O#Mo%;34gDW#2%ss#NT5j#CUNL#lGmtL'c._#Es`s#@'ss#)(dlLNO&@#4hHiLFj:)-E7?>#l*VS.M465/U0sr$/jGG2dpBD3oVLM'8CY`NsW6AOvV%&+D6RYP'E/;Q(2=>,P)KSR/,(5S0Vtu,XYclS7iv.U9(UV-hb<GV@Ro(WL$no.B<Tg)REMP8=dr/1bL5+#$bcF#,,i?#reY+#3*;G#<8%@#9k7-#L)fH#N+=A#E9o-#VMFI#eeV[%x8BP]TVt1^[vfi0C1v._dX2G`eGGJ1P-4Dak6f%bnuCG2[mgxbu#_ucwL@D3jr@Se)mr4f.=tx4,_Mci<I)DjAQMS74_Vs?FFIw#4>uu#H=i$#@w<x#?J1v#G;<)#o$p&$p]Lv#kwl+#4T7)$BuEx#;'J-#SMX*$X[K#$cVh/#&_s-$K[v$$3YC7#I;B6$eqB+$8wp:##G)8$RnWrLrc@(#)@3/1-Y:Z#IVj)#kt]a#wK1a3A0]-#9GFe#?HuY#Wsk.#F4Uf#wk*J-4_.u-nkMuL7uQj#A?EY.Y^N1#To8gL:L);?kc0^#x79;-8FPdM7LYGMBeC)N$4pfL3xSfLO>1[-XB<L#NV:;$&CU8/.veA#5-a[$cDFJ:wWW`<vs@>#7B-5A2=kMCsS?X(kYx+Dx.pG<*t7L#)<oFi6aT3([oa]+SfA>,:aEe-'#QA#J]1?#gBO&#`d9B#SiC?#'0_'#`>-C#`+i?#+<q'#fVQC#X>Y>#3T?(#pOsD#lYBW0Wl8*#4[YF#RMkGM,o/@#tkc+#)$2G#eF6IM,#e>#<q@-#95xH#<d:?#Nr[&F*2vN#5>XA#Sd2<#JoSa#ZCGb#2S<1#+w8i#v4X]#D492#YQ,j#?k)`#LL^2#Lvcj#PW8a#ZwG3#[82k#_>>b#c9m3#N$lm#)j(c#Q]L7#5*Io#oXd_#tn<9#4wis#>A?_#mYJ=#K=n0#]6bc2G?,j's%I/(-X7G;Md(g(d`D,)c$*20Q&`G)*l&d)(c'58YVw`*kC=&+/4$29^oWA+4Q+m/fl@D*(0bM0x,'j0;4,87,HB/1DoVD3r@]`*@lRA4PbO>5$f=A+L_K;61rfV65<JP/Pw,s6F;-#>C0VY,)7J>>n0B8@abW`376_S@b<qiBnQ5>5OrOGDq>/)E#6MV6WLh`EnG+&F7.r(<xcqlJ%WDSebn'&+p4foe>f]lfh6_]+&(_iguus.h#dkl/*@?Jh#Pl(j/Vdf1B&1>lFQBVmBk=A41B&M^HYOV-u9mr-3+GS7v#'/1-QBJ191E_&vAP`<t2J)=e,?X(T?ZlA54oPBsdNe$3C&;Hu.?VH3vG_&['<VQ^svuQA=i,3?+)J_8Pti_:es92qETxbC_IAcj97X:@-69#xf0'#JMA=#^QJ=#Fm9'#w.,##P;P>#e@aD#7%M$#_4r?#wFjD#RbR%#oqw@#pYZC#Ztn%#,.=A#^0FA#:$eiLux(B#f6OA#HNNjL&;iB#XXwm/-B$(#nPHC#Xx(t-eM#lLCLXD#p'Xn/MSj)#QiAE#fSGs-5r.nLE^-F#.][@#<.JnLNpHF#r2G>#B@fnLKpdF#.:pg1p_P+##nuF##?Y>#OeFoL_DNG#$TGs-Z3(pLRi/H#)TGs-dKLpLt%KH#2#)t-hW_pL38gH#6#)t-rv6qL[P5I#9#)t-v,IqL']GI#;#)t-$9[qLSiYI#VQaZ5pbW1#9q&M#<nvC#jrF6#^*lQ#ugAE#wFt$MiurR#Rm@u-<.$&MsnxS#3nJE#P?j'M.*iU#FtSE#rJP)M^`XW#Uu)D#@<=&#sQ'^#(&E`#C?3jLwuL^#b9pg16&w(#B>a`#<??_#,PMmLR#ia#j2W`#A0]-#eGFe#kKQ_#Wsk.#&5Uf#`_Ph1x4e0#9LNh#3q2`#_@dtL.j(i#7w;`#6`N1#&'Bi#v.O]#<rj1#+3Ti#vb%3%O?/;Q+M9;-P)KSR&AK8S[T2L,&pCMTpR$3U3Mxx+c@@JUs[?/VRxH_&9f<GV>Lo(WB+Mq;949DW_PUdW9SAA+u^P]X]P6&Yvr+F.I?iuYN>M>Z(Y$@0_#FS[i+#5]2e@;$A+v._=l9N_KxED*HRr+`:cTJ`&<;R*own(a=(QGas-J_&&Ik%bBo)Abv6J_&&ngxbP6f]cueQe$1^`rdD6^Ve$uQe$<G=PfHZuofF:-F.D(q.hSDRMh&QGk=JFQfhV`NJi0CRe$PkMci?'2,j9-K_&dBf%kDt%Ak/Ghi0=gbxk`[CAl??K_&d5_uliEw>m?_x%4IYZrmlas;nCq=A4O(Wono&p8oTGJP8VOSlo(T55pKdK_&7i4MpYoIipXM/58E3gM'O)`G)mGKe$Ua#g1?MZG23GLe$W;;)3p-B%6k&po%VE)p7v[B58xlLM']j%m8+NnR9&)ii'fStf:,b7,;/Vef(o+qc;'<N,<^d>X(UMm`<H/1&=Imjo.-O+v>1jC;?Lj38.1hbV?-A?v?dQF_&b^vlA8`82Bkb4_AgA8/C2=kMCvV?X(8od]FUg&#GShJJ(d?aYGW)#vG-)@X(1XA;HNGtYH28@X(<xQ/$@og#$$Tf5#;tk2$G37w#](%8#<;B6$X'%w#6k^:#f3d7$_$)t-opS(M;s38$eOc##p6p*#BEEjL#TP8/Rnvu#/,V`3cvp%4v2=;$n:Q`<$ej%=,dtr$2?ZlAWEpPBsdNe$?C&;HSv=VHP1VS%w.NfL[=+GMNe9R*3k2S[jw0t[:WTP&?+)J_?/>f_<st:&NETxbK@j=cViQM'w0Z+ibP4ci.X_'8u0m<#,7i$#m`]=#2m+Y#8I@@#*>G##>Ml>#GUR@#HO7%#Q_[@#=2G>#Vh[%#Cw*A#HiC?#pbW1#vp&M#'DbA#GOg2#'^5N#18OA#YtG3#5,mN#T8fT%Cs4M^I>Ki^K1'&+JwE`aUI[%b`$_]+hfr7edgLoe4RRe$e#Uul&:j:mlJu92t=/PoFY65ppd.F.UOHu#_K'^#_9=&#iQ'^#hK'^#lQb&#fjK^#uW9^#6&w(#.>a`#4eK^#,PMmL>ZfS8P/ko.:^22BXnKMB[]KP/N1_`Ef,x%Fi:-20h&15Jaq.UJ&%IM0/l]cMp<:DN-fDk=]9J`jo@_%kHM<R*]^F]k_R(&l??K_&o,CYloeVul&'%#,HP?Vme3wumEQK_&p(WoniW88oI^K_&%oOip/%05q4^[Y,t@wCWHYOV-2tmr-F,L]=v#'/1W$AJ191E_&_AV`3UOs%4V3F_&D4+;?8]$Z?gdF_&dav1B4Q;MB#EG_&3C&;HIW=VH3vG_&RPj+MNm-GMBMH_&9K+M^YL#m^kqI_&f=Df_9Y9/`v<J_&:s*PfQ??lfYSuo%*u:L#PO[&#JMA=#&QJ=#)i1$#w.,##3;P>#5%`?#7%M$#B4r?#4elF#RbR%#$rw@#DV(?#Xne%#=(4A#=w1G#pbW1#jp&M#[(;G#jrF6#C*lQ#B9%@#wFt$MiurR#XM9o/c:I8#NHnS#NZwm/gF[8#HZ3T#Y6@m/4_T:#Zl#V#8F#]5Sd2<#sqVW#,)fH#@<=&#XQ'^#T/+e#C?3jLwuL^#hpha36&w(#s=a`##S[[#R]s)#Mu]a#-QaZ5us@-#H5+e#I`n[#LaO.#Ux9f#4JPb#=MKsL5Qfg#GPYb#,G*1#g^jh#Rtsn14YE1#Xl,r#V,Mc#fT/(M83Ir#_$)t-lgJ(M5Eer#b$)t-r#g(MPW*s#kZwm/JHZ;#s_Ds#nZwm/Qa)<#jwis#'<xu-.Zc)MM@1QpkQOY>^'l.qD9gM'UxOV-G?,j'j`H/(AcWlAKWcJ(s1*g((u#29AK_T%`W%d)rJ6A4U>@)*f(]D*o#Yc2YVw`*0@>&+w`Q]4^oWA++6+m/r-28.&$F20C5cM0D6<J:*<'j02dB/1D*[i9.T^J1cU%g1Vldu>2m>,2_U[G29(E_&[/vc2`e<)3;.E_&tGVD3+5RA4U2p(<Bxn]4d?5#5nTq.CF:O>5M/UqB8qQ>6K_gr6NkgV6O'-s6KR0;6VE)p7,+C58..>A+]j%m8+NnR92@Y]+fStf:808,;;nUY,o+qc;'<N,<^d>X(N8E($f.5'$vwl+#lBr($r_(($&.),##U7)$+Q:v#,@D,#9bI)$,#)t-^9(pL]3H;@Wfci076_S@>Z$p@2NA>#B&WMB8loiBdL%,2GA8/C8OkMC&88R*h$)+$gNd$$PW=.#v.U+$8rC($Yvk.#e@q+$`C'#$a21/#gR6,$LG`t-<,krL$hI,$7]FU%?dqlJHnx(WC]ED*Eb<DaYt/>c?fQ]=dAmucHYIVdxkQe$5s.8eF?Xs6kRe8#rrj5$,=s%$o_w8#U/06$t+-$$wwE9#W@K6$9h]&$%.X9#@M^6$9[J&$/L0:#1r>7$]L1v#jdA(MSZw7$8c)%$opS(M7T38$5k:u6G?H;#S/5##jEbA#E2G>#iHX&#JW'B#KDc>#DB<jL#)MB#JSGs-NajjL8;iB#_k@u-Rm&kL7l@C#XJl>#]5TkL;.fC#Z>Y>#gS,lLJ.+D#s9xu-olPlLBFOD#bs?W%tR9;6[[T`N_Ivr$<[:AOe3Q]Oh3ol&@tqxOfHMYPgnVS%HN3;Qo2FSRYN2L,uA,5S(S,pSE,Pe$15%/U%8;JUPrH_&1Yw+V$4<KV&kSP&m't(WdGYGW7m['8;@T`WY5:)X;#]'8E-MYYAg1#Z-7s92MK.;Z7h`Qj3-*#,*]+87dI#v,E7BZ-3:CP8[lo#$rH75/fJqWh,uIJ1>U(58,Tgf1pwo+MRHPGM0tZ>#1N6(#s]ZC#s*=A#RUPj:8G``36F8#6PJf>$SfbZ$:Ou%O$5uQjVkrQjYtrQj4=2>PC8nu5bFC<%FBnuPsheEnGkIVQZEs(<LgjrQS1-8R^T8D<&IiW%R5goR8*$,MaajZ#Te,3#F&mj#Fk)`#1eovL2X3k#M-N`#6q+wLlQEk#')Xn/c9m3#?PVk##H`t->3PwLWdtk#xT1Z#mWD4#'o.l#&bCZ#spi4#.1Sl#@`Xv-Tv_xL9YQ?Z1095&E3gM'Oa,j'eNx+2IKG/(3oeJ(qY2>5Md(g(xFE,)_Uho.Q&`G)9l%HDPU7%#tw<x#amg#$TbI%#o-Ox#5_(($Xn[%##:bx#oSm$$ws9'#q>?$$6SA&$%*L'#<KQ$$.m;%$)6_'#M&E%$#O9#$=sd(#TJ&&$+[K#$G;<)##%p&$$Vnw#Vl/*#+75'$)qha3^(K*#/IP'$0i3x#iL,+#8n1($&G`t-EFfnL]@8H<cado7#oi]=fC.#>j2al8)7J>>#:+v>5J22'/[F;?t6bV?cNF_&Rt's?6%N<@SAKP/76_S@uJi2`igJw#B-S-#dMX*$&xD_8n/Wm/hr9+$la)%$TdO.#9/U+$1GY'$Yvk.#^@q+$Xo<x#a21/#`R6,$LG`t-<,krL$hI,$7]FU%MdqlJDbx(W<s1/(Eb<DaYHCSeiW;;-p4foe-2]lfovrr-$rBMgecOci(skl/,=ON0p?v7$4JZ$$opS(MtTB)&4`ZY#AR587m2po%P-QS7j1058lg<;$Zj.29+<7R9na[Y#a8+/:swCJ:R$F_&:jBG;#L[c;T*F_&FUAm/reY+#-0DG#5(Xn/*:D,#/HiG#,#)t-[3(pLWc&H#SQqw-+^0Q;LoK#$#Vs+&Zl=JC0O)F.mf=GD;r/gDWHRw9q(u(EX_p/1PWF.#-O+m#4*rZ#-ES5#=[=m#=T[[#1Qf5#<hOm#7$iZ#6d+6#?*um#EM9o/A,Y6#IT_n#X.:w-%>b$Mn@&o#Dt_Z#ScU7#Q#@o#FH`t-1cB%MDMoo#E6@m/b7@8#VS3p#BUGs-@=6&M3xXp#Wh=(.GOQ&Mx.lp#)F3#.T$<'M<XUq#bm@u-Y0N'M+fhq#Z$.+52UB:#3/5##[<G##R&fH#IAN)#,c8E#4.an5Wl8*#2%^E#l9VG#b4g*#sNGF#G6$C#EFonLRVF0&d^8@#tkc+#T$2G#>+=A#$(),#'C`G#0d:?#0L`,#.b7H#_ZZC#xmJs-hW_pLDV^H#0.DG#B-]-#i;+I#70=v/H?x-#;SOI#,P>p3+?J5#`U4m#c9a`#0Qf5#2hOm#C*1t36d+6#6$lm#&Wcb#;p=6#)1(n#Nrpo/C2c6#:HLn#9$)t-w1O$M(gin#<$)t-'Dk$MuF/o#f4-_#ScU7#R#@o#L)Xn/Woh7#+0Ro#a@Qp/[%%8#M;eo#KZwm/b7@8#1N*p#NZwm/hI[8#/aEp#PZwm/lUn8#8sap#M$)t-IUZ&MaFup#Y0%[#On)'M.LCq#q)7*.U$<'M+__q#PUGs-[6W'M8lqq#[6`T.uro=#`)[:&DHH/(?Pw4AKWcJ(?C+g(]ILS.OpC,)-CQK3I#$$AU>@)*x_]D*/@Zi9YVw`*e1=&+i6*20^oWA+O;0p.4ofr6vTI5/AsfP/Rr`r?$n*m//HF20GWSc;(0bM08p'j0W1&8@,HB/1&E^J1_eXlA2m>,2dwWD3:P7A4]O`S%JRl'$C/*)#FV8&$xn<x#IAE)#1cJ&$0bT#$MMW)#3%p&$ak:($Vl/*#h75'$)qha3^(K*#4IP'$lwL($iL,+#sn1($&G`t-EFfnL]@8H<9C^`*#oi]=,B,#>0/QP&)7J>>6s(v>UlCJ1/[F;?X:aV?cNF_&Rt's?@bS=@p>EP876_S@:N$p@EOFG)B&WMBf3pmBZP05/GA8/C8OkMC&88R*h$)+$)5>'$PW=.#4/U+$OPew#Yvk.#BAq+$sa)%$a21/#DS6,$LG`t-<,krL$hI,$7]FU%jdqlJaa#)W2nwr$Eb<Da`ZCSeKR/;?p4foe[gZlf/=tx4$rBMg)8XigqvVV-(4$/hu%9Jhqjvu,2qVciFk2Djp*gc)?mkxk(t%Bl/,PP/D2LYlbn$#mO`<R*nVHVml^[Y#WHdkM_afw#/=//.*IhhLe/Gx#S?f>-A8P4%GTll&YZ`P8xn#m8MeE_&0-]M9&7vi9%.uQN5sTG;:r9g;]a>X(:86)<@+DJ<,#QP&#oi]=2g(v>*<]Y#/[F;?-d_V?cNF_&Rt's?:O46B7p=;$GA8/CMPXFFSt+,)a0E>GSm]YGVwff(hWA;HH5tYH,WG_&^6WVQirfwQ#F<8%'WNS[59eo[Dato%rX,Z$UAjA#Yf+Z$TY4Z$POXR-^D#X4R=G##RxL$#kWt&#)_''#`.`$#[DpkL0u[(#sSGs-O$loLZMN,#3#)t-%mWrLoQ;/##kd(#Hx>tL*Q+1#_TGs-D]n#Mv/Q6#7$)t-qu<$MbGv6#L)901d[*9#_a39#b6i$#Pb:5/x@0:#stp2<0Gcm'WV*&+K$BZ$Jr'#,FXrr$dI#v,OtG[-m<IP/l$;8.Q@65/3@=X(E$OM0hlpO1u<28.,Tgf1x>,,2[NSS%0mGG2r:Qh2x?mr-4/))3g*b`3`$o92hFtu543$]6-[QV-N'QS7g#no7[8t+;UNMP8#nUq8LI4>5Zj.29YpIM9UQ>X(4EFJ:U&bf:R$F_&<^TW-jDVRqK-lD#tkc+#0%2G#HhBB#OeFoL&QEG#gfAE#TwboLZcaG#_#3D#Z3(pLXi/H#+g(T.4Xr,#6Fuw$ZNHPAE'PqA0NA>#=g)2BH;EMBqM?X(k5&/Cmd?JC:[^9MiM]fC%AKf+X]NG#LK4.#xYXI#cD#]5pbW1#rp&M#vow@#jrF6#M*lQ#Jjn@#wFt$MiurR#Rm@u-<.$&M.*iU#OTPF#rJP)MQ`XW#9w*A#@<=&#cQ'^#b'F]#C?3jLwuL^#b9pg16&w(#'>a`#O]Aa#,PMmLR#ia#EZke#A0]-#TGFe#Z@k]#Wsk.#b4Uf#`_Ph1x4e0#uKNh#ll*]#_@dtL>F=KNqG%&+8CY`Nd*6AOf'SP&>hU]OjHmxOg$85&B*7>P=&OYPGVjr6FBnuP=20;Qs$q+DJZNVQ<A,8R=3',2P)KSRCOhsRC^>D3TA,5SQB*USYn_i9XYclSD(%2TSIAX(5)`iT`6x.U*R6GDc@@JU(4[jUC'JM0gXw+V*F<KV'tol&m't(WD@[GWnToEI;@T`W4r;)XfI(REE-MYYAg1#Z3nk34KK.;ZLG)<--ES5#U[=m#.IuY#3Wo5#?oXm#2O(Z#9j46#(1(n#HM9o/C2c6#RILn#7hG<-=vm]%G'^]=f02da/QAJ:6^JZ&*bK]bmNbxbF-t92.$->cP]DYc%FJ_&4H);d4p?Vd(OJ_&:m%8et>;Se*UJ_&<G=PfHZuofE2qEIF`t1g#s3Mg8NCX(H:6Jhl>rih4tJ_&N_2Gi$,*YJb-wY#5bT:#;x>r#u/O]#iaA(M4?[r#`$)t-os](M=dwr##$=]#u/#)M@v<s#'*F]#%B>)M?,ks#0J.f2XsD<#e3/t#.t3]#uro=#/=n0#9VNY5E3gM'0Y.j'&u>M9IKG/(PqfJ(O0e%FMd(g(?IF,)JLPfCQ&`G)Z?Ia3PU7%#%x<x#V1h+$VhR%#I4Xx#Gpn)$Zte%#N96$$w/6$$%*L'#YKQ$$O3i($)6_'#ShU6*X,#j9u'FV?lrTG;*iqc;(h>PAq76)<@+DJ<$1+;?#oi]=(=J>>&%/>>-O+v>w?bV?]nMe$3Mh`E;cGAFV:1DEa0E>GOh%vG'HG_&1XA;H295.Wm$LS7Eb<Da-E1>cwUw%4$,>>#-h.9&%;oYYsBf>i-c@(#:'xU.#)>>#Ej$B4;.`$#[9F&#&E-(#RuJ*#s*2,#k#@qLfPmv$$KVB-Vw>H=WCi(E,T@C-JPWO;6UMrZ2ZIC-E#4J=,h2fq(]L*5-Yu##Me[%#npB'#>Ja)#eUG+#/b.-#k7M>63/5##?:r$#`EX&#*Q?(#FPj)#g[P+#1h7-#n7)^51f1$#Qqn%#r&U'#:&*)#X1g*##=M,#uYs3N-@I##CF.%#dQk&#.^Q(#J]&*#khc+#5tI-#ULf>-^,TW4U'+&#v2h'#>2<)#]=#+#'I`,##g/4N/L[##GR@%#h^''#2jd(#Ni8*#otu+#9*]-#?t-W%[kfi'Y+pu,$B#,2BFKV6aVTc;+n^o@K.h%FV2Q<BG1+5Sjx02UpX),Wv9x%Y&qpuZ,Qio]22bi_>7;dal;OVCvnde$F1ee$NIee$Vbee$_$fe$g<fe$oTfe$xN<'I8U8s$.b7p&4B0j(:#)d*@Yw],F:pV.LqhP0RQaJ2TpS,3;f_e$_x_e$e4`e$kF`e$qX`e$wk`e$'(ae$+.Ne$7kmfC9qlcE?Qe]GE2^VIKiUPKQINJMW*GDO^a?>QV,5d3F2ce$jDce$pVce$vice$&&de$,8de$2Jde$8,>eG]aMYcHNcofRSs+j]X->mg^=PpqcMcs&ug>$*(`5/o1JuB.`HIM>,+JMDPbJMJuBKMPC$LMK57%HQVO@$]Gg;-cGg;-iGg;-oGg;-uGg;-%Hg;-+Hg;-1TGs-HYERM='(SMCK_SMIp?TMO>wTMUcWUM[19VM`C9vL,7b@$hHg;-nHg;-tHg;-$Ig;-*Ig;-0Ig;-<*`5/3efYB?HZ]MHk<^MN9t^MT^T_MZ,6`MaPm`MguMaMbga9H+QUG$sO,W-]m]e$(*^e$.<^e$4N^e$:a^e$@s^e$P/KMF5^vM0RQaJ2X2YD4_iQ>6eIJ88k*C2:qa;,<'gk&>$,>>#/nti$LDuu#0PMq2`IH?$b*,##G&&VMSVEUMM2eTMGd-TMA?LSM;qkRM5L4RM7RxqL_dx<$3Hg;--Hg;-'Hg;-wGg;-qGg;-kGg;-eGg;-iSGs-R[rMM]6<MMVhZLMPC$LMJuBKMDPbJM>,+JM@2oiLap4=$<Gg;-6Gg;-0Gg;-*Gg;-$M,W-Wgfe$nN]e$re,$$6C35&UL5/&tIW-?tNj-$ni_3=8RL_&0#7`&232#50=jl&7Y_e$NG_e$H5_e$:8Gp&1BPk-r3W9`,P+,M@?)=-;:)=-<CDX-/,A'fWouY#_V^5'BYIm-.)A'fE'd.q#d6Jr0*+Q'H<fe$a*fe$Znee$T[ee$NIee$H7ee$AuZe$kN`;%T=vV%01Zi$RP):2[m5K)*gu(3)4HZ5=6o-#^AU/#(M<1#HX#3#id`4#3pF6#?rl.8Wn`cW(_k]Yg2<XC,%0x':uVF%^<xr$;k$$$93LG):k9:)QYl-NTUZ-NqSY0N5@xQMsCH>#[5m<-^Z#<-`Z#<-jZ#<-lZ#<-nZ#<-pZ#<-rZ#<-*NMt-h8b$MZgS8#.r)`#b2G>#T;M.MNF6##o3UhLZk)Z#e15##H/MT.g:P>#qMx>--d[q.xe`4#H3qtmW?EVnT?>s(Pb;GiQ[xtmORqtmQKN;nfJ'v#LYicNs;4&>(cb&#f?-IMWjqsLkH<mL=-lrL[P;=-5)m<-J5T;-KrRU.rE,+#q=;E/iDRw#/4'r*9(Mn/4pb2$/W=2$AMx>-MLx>-&hL>=u184$Qi-4$w4O$M)I<mLSlQ/$(/Cv+N.IMTeR*,ViXefUdCIJUDY?&5R%*pAo<hA#1EK/)/G-??9g&##;nuE7PE=;$]lWA+w^eP/7_hB#tBw(<)5###rHHh,e,^Y#'D(v#s*^88_>c'&V-4kk'9c'&)?c'&kiP_/HQ=_/3i?_/'%ff17pcY>UsUUnZ+iB#D7Juc+fVG2s5Hk4iXk7e&uK^#ZX0Pf%ftA#D_Qw997]J1Zk$##JqcS7th>29)J*,)d<.@n%/D#$_,(/#r33-$D4*jL$`)v#Nte%#WIT&#wc+^%F7.5/05r%4oCm%=4Q;MBbKAVH#A/GM><WrQ@4Df_ONp=c#C;cinD/]t,]_V$LWV'8a6V'8Lf:kF]^#g1:YWPA<Yml&B&WMB#OLk+&>+,Mj)b+.5/=GM;@GGM:4pfLn_L2#&i.1$_M?IMamQ/$FiEF.^rd(#_.5$$T'Fx#CH<jLWb2v#1<EJMds+x#ES#<-IX`=-#mN71$(v+#gcP/$p*,##7#:Ca&-Z-#"