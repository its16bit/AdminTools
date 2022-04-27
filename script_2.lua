script_name('AdminTools')
script_author('Tobbi_Marchi & Jesse_Flores')
script_description('Многофункциональный помощник для администрации проекта PayDay RP.')
script_version('0.0.1')

require 'moonloader'
local sampev = require 'lib.samp.events'
local imgui = require('imgui')
local inicfg = require 'inicfg'
local memory = require 'memory'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local Matrix3X3 = require "matrix3x3"
local dlstatus = require('moonloader').download_status


encoding.default = 'CP1251'
u8 = encoding.UTF8

local directIni = 'ahelper.ini'

local ini = inicfg.load(inicfg.load({
    main = {
        skin = 0,
        admpassword = '',
        admtag = '|| ',
        admlvl = 1,
        sms_admin = '',
        combo_org = 0
    },
    cheats = {
        wallhack = false,
        clickwarp = false,
        inf_ammo = false,
        gm_car = false,
        gm_mode = false,
        no_bike = false
    },
}, directIni))
inicfg.save(ini, directIni)

local organization = {
    [0] = u8'Не использовать',
	[1] = u8'Полиция ЛС',
    [2] = u8'ФБР',
    [3] = u8'Армия Сан-Андреас',
    [4] = u8'МЧС',
    [5] = u8'La Cosa Nostro',
    [6] = u8'Yakuza',
    [7] = u8'Мэрия Лос-Сантос',
    [8] = u8'Полиция Сан-Фиеро',
    [9] = u8'The Ballas',
    [10] = u8'Los Santos Vagos',
    [11] = u8'Русская Мафия',
    [12] = u8'Grove Street',
    [13] = u8'Радио Лос Сантос',
    [14] = u8'Varios Los Aztecas',
    [15] = u8'The Rifa',
    [16] = u8'Армия Лас Вентурас',
    [17] = u8'Полиция Лас Вентурас',
    [18] = u8'Байкеры',
    [19] = u8'Правительство',
    [20] = u8'Военно Морской Флот'
}

local true_false = {
    templeader_combo = false,
    sms_admin_input = false,
    skin_input = false
}

local window = imgui.ImBool(false)
local teleportmenu = imgui.ImBool(false)
local templeader = imgui.ImBool(false)

local admintag = imgui.ImBuffer(tostring(ini.main.admtag),256)
local skin = imgui.ImInt(ini.main.skin)
local admpass = imgui.ImBuffer(tostring(ini.main.admpassword), 32768)
local adm_lvl = imgui.ImInt(ini.main.admlvl)
local message_admin = imgui.ImBuffer(u8(ini.main.sms_admin), 256)
local combo_org = imgui.ImInt(ini.main.combo_org)

local cWallHack = imgui.ImBool(ini.cheats.wallhack)
local clickwarp = imgui.ImBool(ini.cheats.clickwarp)
local inf_ammo = imgui.ImBool(ini.cheats.inf_ammo)
local gm_car = imgui.ImBool(ini.cheats.gm_car)
local gm_mode = imgui.ImBool(ini.cheats.gm_mode)
local no_bike = imgui.ImBool(ini.cheats.no_bike)

local font = renderCreateFont('Arial', 9, 9)


local tab = 0
local tpmenutab = 0

local fa = require 'fAwesome5' -- ICONS LIST: https://fontawesome.com/v5.15/icons?d=gallery&s=solid&m=free

local fontsize = nil
local fa_font = nil
local fa_glyph_ranges = imgui.ImGlyphRanges({ fa.min_range, fa.max_range })
function imgui.BeforeDrawFrame()
    if fa_font == nil then
        local font_config = imgui.ImFontConfig()
        font_config.MergeMode = true

        fa_font = imgui.GetIO().Fonts:AddFontFromFileTTF('moonloader/resource/fonts/fa-solid-900.ttf', 13.0, font_config, fa_glyph_ranges)
    end
    if fontsize == nil then
        fontsize = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 30.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic()) -- вместо 30 любой нужный размер
    end
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('amenu', function()
        window.v = not window.v
        imgui.Process = window.v
    end)

    sampRegisterChatCommand('tpmenu', function()
        teleportmenu.v = not teleportmenu.v
        imgui.Process = teleportmenu.v
    end)

    sampRegisterChatCommand('templeader', function()
        templeader.v = not templeader.v
        imgui.Process = templeader.v
    end)

    if check_server() then
        print('Доступ разрешен!')
    else
        print('Доступ запрещен! Скрипт работает только на серверах PayDay RolePlay!')
        thisScript():unload()
    end

    autoupdate()

    while true do
        wait(0)

        if clickwarp.v then
            while isPauseMenuActive() and not window.v and not teleportmenu.v and not templeader.v do
                if cursorEnabled and not window.v and not teleportmenu.v and not templeader.v then
                    showCursor(false)
                end
                wait(100)
            end
            if isKeyDown(VK_MBUTTON) and not window.v and not teleportmenu.v and not templeader.v then
                cursorEnabled = not cursorEnabled
                click_warp()
                if not window.v and not teleportmenu.v and not templeader.v then 
                    showCursor(cursorEnabled)
                end
                while isKeyDown(VK_MBUTTON) do wait(80) end
            end
        end
        if inf_ammo.v then
            memory.write(0x969178, 1, 1, true)
        else
            memory.write(0x969178, 0, 1, true)
        end
        if gm_car.v then
            if isCharInAnyCar(PLAYER_PED) then
                setCanBurstCarTires(storeCarCharIsInNoSave(playerPed), false)
                setCarProofs(storeCarCharIsInNoSave(playerPed), true, true, true, true, true)
                setCarHeavy(storeCarCharIsInNoSave(playerPed), true)
                function sampev.onSetVehicleHealth(vehicleId, health)
                    return false
                end
            end
        else
            if isCharInAnyCar(PLAYER_PED) then
                setCanBurstCarTires(storeCarCharIsInNoSave(playerPed), false)
                setCarProofs(storeCarCharIsInNoSave(playerPed), false, false, false, false, false)
                setCarHeavy(storeCarCharIsInNoSave(playerPed), false)
            end
        end
        if gm_mode.v then
            setCharProofs(playerPed, true, true, true, true, true)
  			writeMemory(0x96916E, 1, 1, false)
        else
            setCharProofs(playerPed, false, false, false, false, false)
  			writeMemory(0x96916E, 1, 0, false)
        end
        if no_bike.v then
            setCharCanBeKnockedOffBike(PLAYER_PED, true)
        else
            setCharCanBeKnockedOffBike(PLAYER_PED, false)
        end

        if combo_org.v == 0 then
            true_false.templeader_combo = false
        elseif combo_org.v > 0 then
            true_false.templeader_combo = true
        end
    end
end

function imgui.OnDrawFrame()
    if not window.v and not teleportmenu.v and not templeader.v then
        imgui.Process = false
    end

    if window.v then
        local myname = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 1000, 675 -- WINDOW SIZE
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2 - sizeX / 2, resY / 2 - sizeY / 2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('AdminTools ' .. fa.ICON_FA_TOOLS, window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
        imgui.PushFont(fontsize)
            imgui.Text('Admin Tools')
        imgui.PopFont()
        imgui.SameLine()
        imgui.Text(fa.ICON_FA_TOOLS)
        imgui.SameLine()
        imgui.SetCursorPosX(965)
        if imgui.Button(fa.ICON_FA_TIMES, imgui.ImVec2(20, 20)) then window.v = false end
        imgui.BeginChild('tabs', imgui.ImVec2(160, 620), true, imgui.WindowFlags.NoScrollbar) -- Создаем BeginChild для "вкладок"
            if imgui.Button(fa.ICON_FA_USER_COG .. u8' Основное ', imgui.ImVec2(148, 25)) then -- Создаем проверку на нажатие кнопки
                tab = 0 -- Если кнопка была нажата, то переменной tab передаем 0
            end
            if imgui.Button(u8' Статистика ' .. fa.ICON_FA_USER_COG, imgui.ImVec2(148, 25)) then -- Создаем проверку на нажатие кнопки
                tab = 1 -- Если кнопка была нажата, то переменной tab передаем 0
            end
            if imgui.Button(u8' Стилизация ' .. fa.ICON_FA_USER_COG, imgui.ImVec2(148, 25)) then -- Создаем проверку на нажатие кнопки
                tab = 2 -- Если кнопка была нажата, то переменной tab передаем 0
            end
            if imgui.Button(u8' Вспомогательное ПО', imgui.ImVec2(148, 25)) then
                tab = 3
            end
            if imgui.Button(fa.ICON_FA_KEYBOARD .. u8' Горячие клавиши', imgui.ImVec2(148, 25)) then
                tab = 4 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8' Биндер', imgui.ImVec2(148, 25)) then
                tab = 5 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8' Репорт', imgui.ImVec2(148, 25)) then
                tab = 6 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8' Формы', imgui.ImVec2(148, 25)) then
                tab = 7 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8' Чекеры', imgui.ImVec2(148, 25)) then
                tab = 8 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8' Слежка', imgui.ImVec2(148, 25)) then
                tab = 9 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(fa.ICON_FA_EXCLAMATION_TRIANGLE .. u8' Варнинги', imgui.ImVec2(148, 25)) then
                tab = 10 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(fa.ICON_FA_CODE .. u8' О скрипте ', imgui.ImVec2(148, 25)) then
                tab = 11
            end
        imgui.EndChild() -- Закрываем данный Child
        imgui.SameLine() -- Отступаем от Item'а и рисуем на той же строке
        if tab == 0 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs1', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)
                imgui.Text(u8'Текущий ник: ' .. myname .. '[' .. id .. ']')
                imgui.PushItemWidth(120.00)
                if imgui.InputInt(u8'Уровень администрирования ' .. fa.ICON_FA_CHART_LINE, adm_lvl) then save() end
                imgui.Hint(u8'Укажите свой уровень администрирования')
                imgui.SameLine()
                imgui.SetCursorPosX(500)
                imgui.PushItemWidth(120.00)
                if imgui.InputInt(u8'Скин после входа ' .. fa.ICON_FA_MALE, skin) then save() end
                imgui.Hint(u8'Нажмите на иконку, чтобы включить/выключить выдачу скина после авторизации как администратор\n\nВсего существует 311 скинов.\nСоответственно выбирайте скины в диапазоне [0-311]')
                imgui.PushItemWidth(120.00)
                if imgui.InputText(u8' ' .. fa.ICON_FA_TAGS, admintag) then save() end
                imgui.Hint(u8'Тэг указывается в формате - || NickName\nГде вместо NickName должно быть указан Ваш игровой никнейм\n\nПрефикс будет выглядеть так:\nАдминистратор Tobbi_Marchi[323] посадил в деморган Jesse_Flores[360] на 300 минут. Причина: ДМ ЗЗ '.. admintag.v)
                imgui.SameLine()
                imgui.SetCursorPosX(500)
                imgui.PushItemWidth(120.00)
                if imgui.InputText(u8'Сообщения в /a после входа ' .. fa.ICON_FA_COMMENT, message_admin) then save() end
                imgui.PushItemWidth(120.00)
                if imgui.InputText(u8'Админ пароль ' .. fa.ICON_FA_KEY, admpass, imgui.InputTextFlags.Password) then save() end
                imgui.Hint(u8'Укажите ваш пароль от /alogin')
				imgui.SameLine()
				imgui.SetCursorPosX(500)
                imgui.PushItemWidth(120.00)
				if imgui.Combo(u8'Организация после входа ' .. fa.ICON_FA_BRIEFCASE, combo_org, organization) then save() end
                imgui.Separator()
            imgui.EndChild()
        elseif tab == 1 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar, true)

                imgui.Text(u8'Статистика | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 2 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar, true)

                imgui.Text(u8'Стилизация | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 3 then
            imgui.BeginChild('tabs4', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                if imgui.Checkbox('Wallhack', cWallHack) then
                    if cWallHack.v then
                        nameTagOn()
                        save()
                    else
                        nameTagOff()
                        save()
                    end
                end
                if imgui.Checkbox('ClickWarp', clickwarp) then
                    save()
                end
                if imgui.Checkbox(u8'Бесконечные патроны', inf_ammo) then save() end
                if imgui.Checkbox('GM Car', gm_car) then save() end
                if imgui.Checkbox('GM Mode', gm_mode) then save() end
                if imgui.Checkbox('No Bike', no_bike) then save() end

            imgui.EndChild()
        elseif tab == 4 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Горячие клавиши | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 5 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Биндер | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 6 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Репорт | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 7 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Формы | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 8 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Чекеры | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 9 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Слежка | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 10 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('tabs2', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)

                imgui.Text(u8'Варнинги | В разработке ...')

            imgui.EndChild() -- Закрываем Child
        elseif tab == 11 then -- Также как и сверху, но с другим значением переменной
            imgui.BeginChild('tabs3', imgui.ImVec2(820,620), true, imgui.WindowFlags.NoScrollbar)
                imgui.SetCursorPosY(20)
                imgui.CenterText(u8'AdminTools - многофункциональный помощник для администрации проекта PayDay RP.\nОн имеет огромный список инструментов, которые помогут вам в администрировании.')
                imgui.CenterText(u8'а также простой дизайн и расположение всех инструментов, в которых не составит труда разобраться.')
                imgui.CenterText(u8'Авторами даного скрипта являются: Tobbi_Marchi & Jesse_Flores')
                imgui.SetCursorPosY(100)
                imgui.SetCursorPosX(100)
                if imgui.Button(u8'Проверить обновления',imgui.ImVec2(200,20)) then autoupdate() end
                imgui.SameLine()
                if imgui.Button(u8'Перезагрузить скрипт',imgui.ImVec2(200,20)) then thisScript():reload() end
                imgui.SameLine()
                if imgui.Button(u8'Выключить скрипт',imgui.ImVec2(200,20)) then thisScript():unload() end
                imgui.SetCursorPosX(100)
                if imgui.Button(u8'Автор Tobbi_Marchi',imgui.ImVec2(200,20)) then os.execute('explorer "https://vk.com/rickmoonlight"') end
                imgui.SameLine()
                if imgui.Button(u8'Автор Jesse_Flores',imgui.ImVec2(200,20)) then os.execute('explorer "https://vk.com/dev_16bit"') end
                imgui.SameLine()
                if imgui.Button(u8'Группа PayDay',imgui.ImVec2(200,20)) then os.execute('explorer "https://vk.com/pdrpsamp"') end
                imgui.NewLine()
                imgui.Separator()
                if imgui.CollapsingHeader(u8'Обновление v1.3') then
                    imgui.Text(u8'- Был убран баг с наложением текста от кликварпа друг на друга!\n- Было добавлено меню выбора организации при входе!\n- Была добавлена проверка на сервер!(теперь скрипт работает только на PayDay RolePlay)')
                end
            imgui.EndChild()
        end
        imgui.End()
    end

    if teleportmenu.v then
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 600, 600 -- WINDOW SIZE
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2 - sizeX / 2, resY / 2 - sizeY / 2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Teleport Menu', teleportmenu, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove)
        imgui.BeginChild('teleporttabs', imgui.ImVec2(85, 565), false) -- Создаем BeginChild для "вкладок"
            if imgui.Button(u8'Общ.Места', imgui.ImVec2(85, 25)) then -- Создаем проверку на нажатие кнопки
                tpmenutab = 0 -- Если кнопка была нажата, то переменной tab передаем 0
            end
            if imgui.Button(u8'Развлечения', imgui.ImVec2(85, 25)) then
                tpmenutab = 1 -- Если кнопка была нажата, то переменной tab передаем 1
            end
            if imgui.Button(u8'Города', imgui.ImVec2(85, 25)) then
                tpmenutab = 2
            end
            if imgui.Button(u8'Нелегалы', imgui.ImVec2(85, 25)) then
                tpmenutab = 3
            end
            if imgui.Button(u8'Госки', imgui.ImVec2(85, 25)) then
                tpmenutab = 4
            end
            if imgui.Button(u8'Работы', imgui.ImVec2(85, 25)) then
                tpmenutab = 5
            end
        imgui.EndChild()
        imgui.SameLine() -- Отступаем от Item'а и рисуем на той же строке
        if tpmenutab == 1 then -- Если tab равен 1, то рисуем BeginChild
            imgui.BeginChild('teleporttabs2', imgui.ImVec2(495, 565), true)
                if imgui.Button('Counter-Strike', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, -2098.4677734375, 86.241798400879, 35.3203125)
                end
                if imgui.Button('Casino LS', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1022.4281005859, -1132.7653808594, 23.828125)
                end
            imgui.EndChild() -- Закрываем Child
        elseif tpmenutab == 2 then -- Также как и сверху, но с другим значением переменной
            imgui.BeginChild('teleporttabs3', imgui.ImVec2(495, 565), true)
                if imgui.Button('Los-Santos', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1362.2567138672, -1038.9110107422, 26.140625)
                end
                if imgui.Button('San-Fiero', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, -1826.1483154297, 160.33590698242, 15.1171875)
                end
                if imgui.Button('Las-Venturas', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1797.1667480469, 832.83911132813, 10.664346694946)
                end
            imgui.EndChild()
        elseif tpmenutab == 3 then -- Если tab не равен ничему, что описано выше
            imgui.BeginChild('teleporttabs4', imgui.ImVec2(495, 565), true)
                if imgui.Button('The Ballas Gang', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2456.3103027344, -1331.1014404297, 24)
                end
                if imgui.Button('The Grove Street', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2490.0139160156, -1669.9241943359, 13.335947036743)
                end
                if imgui.Button('The Rifa Gang', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2768.9892578125, -1947.7357177734, 13.368236541748)
                end
                if imgui.Button('The Aztecas Gang', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2178.8835449219, -1796.6197509766, 13.368200302124)
                end
                if imgui.Button('The Vagos Gang', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2853.5815429688, -1537.1246337891, 11.093799591064)
                end
                if imgui.Button('La Cosa Nostra', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1446.1320800781, 748.97857666016, 10.8203125)
                end
                if imgui.Button('Russian Mafia', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 953.82830810547, 1734.3770751953, 8.6484375)
                end
                if imgui.Button('Yakuza', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1467.453125, 2773.3977050781, 10.671899795532)
                end
            imgui.EndChild()
        elseif tpmenutab == 4 then -- Также как и сверху, но с другим значением переменной
            imgui.BeginChild('teleporttabs5', imgui.ImVec2(495, 565), true)
                if imgui.Button(u8'Полиция ЛС', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1548.099609375, -1703.7918701172, 5.890625)
                end
                if imgui.Button(u8'Полиция СФ', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, -1604.0522460938, 690.98638916016, -5.2421875)
                end
                if imgui.Button(u8'Полиция ЛВ', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2280.6552734375, 2452.3327636719, 10.8203125)
                end
                if imgui.Button(u8'ФБР', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 2647.6499023438, 479.26000976563, 10.829999923706)
                end
                if imgui.Button(u8'Больница ЛС', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1178.2052001953, -1324.3649902344, 14.108599662781)
                end
                if imgui.Button(u8'Автошкола', imgui.ImVec2(480,25)) then
                setCharCoordinates(PLAYER_PED, 755.32592773438, -1434.9217529297, 13.725299835205)
                end
                if imgui.Button(u8'Армия ЛС', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, -1343.3968505859, 469.87341308594, 7.1875)
                end
                if imgui.Button(u8'Армия СФ', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, -2260.8371582031, 2313.4680175781, 4.8125)
                end
                if imgui.Button(u8'Армия ЛВ', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 212.34869384766, 1910.7576904297, 17.640625)
                end
            imgui.EndChild()
        elseif tpmenutab == 5 then
            imgui.BeginChild('teleporttabs6', imgui.ImVec2(495, 565), true)
                if imgui.Button(u8'Автобусник', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1263.318359375, -1817.9395751953, 13.394823074341)
                end
                if imgui.Button(u8'Таксист', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1090.1885986328, -1775.3374023438, 13.342300415039)
                end
            imgui.EndChild()
        else -- Если tab не равен ничему, что описано выше
            imgui.BeginChild('teleporttabs1', imgui.ImVec2(495, 565), true)
                if imgui.Button(u8'Мэрия', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1478.1539306641, -1739.5426025391, 14.546875)
                end
                if imgui.Button(u8'Автошкола', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 755.32592773438, -1434.9217529297, 13.725299835205)
                end
                if imgui.Button(u8'Центральный Отель', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1787.5316162109, -1290.6809082031, 13.658506393433)
                end
                if imgui.Button(u8'Банк Los-Santos', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1464.2767333984, -1023.532409668, 23.833103179932)
                end
                if imgui.Button(u8'Гора Vine-Wood', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1515.5979003906, -819.18121337891, 70.042610168457)
                end
                if imgui.Button(u8'Университет', imgui.ImVec2(480,25)) then
                    setCharCoordinates(PLAYER_PED, 1420.6588134766, -1678.3989257813, 13.546899795532)
                end
            imgui.EndChild()
        end
        imgui.End()
    end

    if templeader.v then
        local _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 600, 600 -- WINDOW SIZE
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2 - sizeX / 2, resY / 2 - sizeY / 2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('TempLeader', templeader, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove)
        imgui.BeginChild('templeader', imgui.ImVec2(583, 565), true)
            if imgui.Button(u8'Полиция ЛС', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 1')
            end
            if imgui.Button(u8'Полиция СФ', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 8')
            end
            if imgui.Button(u8'Полиция ЛВ', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 17')
            end
            if imgui.Button(u8'Полиция ФБР', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 2')
            end
            if imgui.Button(u8'Армия ЛС', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 3')
            end
            if imgui.Button(u8'Армия СФ', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 20')
            end
            if imgui.Button(u8'Армия ЛВ', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 16')
            end
            if imgui.Button(u8'Правительство', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 19')
            end
            if imgui.Button(u8'Мэрия ЛС', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 7')
            end
            if imgui.Button(u8'Больница ЛС', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 4')
            end
            if imgui.Button(u8'Русская Мафия', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 11')
            end
            if imgui.Button(u8'Байкеры', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 18')
            end
            if imgui.Button(u8'Yakuza', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 6')
            end
            if imgui.Button(u8'La Cosa Nostro', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 5')
            end
            if imgui.Button(u8'The Ballas', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 9')
            end
            if imgui.Button(u8'Los Santos Vagos', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 10')
            end
            if imgui.Button(u8'Grove Street', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 12')
            end
            if imgui.Button(u8'Varios Los Aztecas', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 14')
            end
            if imgui.Button(u8'The Rifa', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 15')
            end
            if imgui.Button(u8'Радио ЛС', imgui.ImVec2(566,25)) then
                sampSendChat('/templeader 13')
            end
            if imgui.Button(u8'Уволитьтся', imgui.ImVec2(566,25)) then sampSendChat('/uval ' .. id .. ' 1') end
        imgui.EndChild()
        imgui.End()
    end
end

function salattheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.WindowRounding = 2.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.84)
    style.ChildWindowRounding = 2.0
    style.FrameRounding = 2.0
    style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0
    style.GrabMinSize = 8.0
    style.GrabRounding = 1.0

    colors[clr.FrameBg]                = ImVec4(0.42, 0.48, 0.16, 0.54)
    colors[clr.FrameBgHovered]         = ImVec4(0.85, 0.98, 0.26, 0.40)
    colors[clr.FrameBgActive]          = ImVec4(0.85, 0.98, 0.26, 0.67)
    colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.42, 0.48, 0.16, 1.00)
    colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.CheckMark]              = ImVec4(0.85, 0.98, 0.26, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.77, 0.88, 0.24, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.85, 0.98, 0.26, 1.00)
    colors[clr.Button]                 = ImVec4(0.85, 0.98, 0.26, 0.40)
    colors[clr.ButtonHovered]          = ImVec4(0.85, 0.98, 0.26, 1.00)
    colors[clr.ButtonActive]           = ImVec4(0.82, 0.98, 0.06, 1.00)
    colors[clr.Header]                 = ImVec4(0.85, 0.98, 0.26, 0.31)
    colors[clr.HeaderHovered]          = ImVec4(0.85, 0.98, 0.26, 0.80)
    colors[clr.HeaderActive]           = ImVec4(0.85, 0.98, 0.26, 1.00)
    colors[clr.Separator]              = colors[clr.Border]
    colors[clr.SeparatorHovered]       = ImVec4(0.63, 0.75, 0.10, 0.78)
    colors[clr.SeparatorActive]        = ImVec4(0.63, 0.75, 0.10, 1.00)
    colors[clr.ResizeGrip]             = ImVec4(0.85, 0.98, 0.26, 0.25)
    colors[clr.ResizeGripHovered]      = ImVec4(0.85, 0.98, 0.26, 0.67)
    colors[clr.ResizeGripActive]       = ImVec4(0.85, 0.98, 0.26, 0.95)
    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.81, 0.35, 1.00)
    colors[clr.TextSelectedBg]         = ImVec4(0.85, 0.98, 0.26, 0.35)
    colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
    colors[clr.ChildWindowBg]          = ImVec4(1.00, 1.00, 1.00, 0.00)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.ComboBg]                = colors[clr.PopupBg]
    colors[clr.Border]                 = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
    colors[clr.CloseButton]            = ImVec4(0.41, 0.41, 0.41, 0.50)
    colors[clr.CloseButtonHovered]     = ImVec4(0.98, 0.39, 0.36, 1.00)
    colors[clr.CloseButtonActive]      = ImVec4(0.98, 0.39, 0.36, 1.00)
    colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[clr.ModalWindowDarkening]   = ImVec4(0.80, 0.80, 0.80, 0.35)
end

function red_theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    style.WindowRounding = 10
    style.ChildWindowRounding = 10
    style.FrameRounding = 6.0

    style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
    style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
    style.IndentSpacing = 21
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 13
    style.GrabMinSize = 17.0
    style.GrabRounding = 16.0

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
    colors[clr.TextDisabled] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.WindowBg] = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ChildWindowBg] = ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border] = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.BorderShadow] = ImVec4(1.00, 1.00, 1.00, 0.00)
    colors[clr.FrameBg] = ImVec4(0.22, 0.22, 0.22, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.18, 0.18, 0.18, 1.00)
    colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1.00)
    colors[clr.TitleBg] = ImVec4(0.14, 0.14, 0.14, 0.81)
    colors[clr.TitleBgActive] = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.MenuBarBg] = ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
    colors[clr.ScrollbarGrab] = ImVec4(0.36, 0.36, 0.36, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.24, 0.24, 0.24, 1.00)
    colors[clr.ComboBg] = ImVec4(0.24, 0.24, 0.24, 1.00)
    colors[clr.CheckMark] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.SliderGrab] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.SliderGrabActive] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.Button] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.ButtonHovered] = ImVec4(1.00, 0.39, 0.39, 1.00)
    colors[clr.ButtonActive] = ImVec4(1.00, 0.21, 0.21, 1.00)
    colors[clr.Header] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.HeaderHovered] = ImVec4(1.00, 0.39, 0.39, 1.00)
    colors[clr.HeaderActive] = ImVec4(1.00, 0.21, 0.21, 1.00)
    colors[clr.ResizeGrip] = ImVec4(1.00, 0.28, 0.28, 1.00)
    colors[clr.ResizeGripHovered] = ImVec4(1.00, 0.39, 0.39, 1.00)
    colors[clr.ResizeGripActive] = ImVec4(1.00, 0.19, 0.19, 1.00)
    colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
    colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
    colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
    colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered] = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram] = ImVec4(1.00, 0.21, 0.21, 1.00)
    colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.18, 0.18, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(1.00, 0.32, 0.32, 1.00)
    colors[clr.ModalWindowDarkening] = ImVec4(0.26, 0.26, 0.26, 0.60)
end

function god_theme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    style.WindowRounding = 7
    style.ChildWindowRounding = 7
    style.FrameRounding = 3.0

    colors[clr.Text]                 = ImVec4(0.86, 0.93, 0.89, 0.78)
    colors[clr.TextDisabled]         = ImVec4(0.36, 0.42, 0.47, 1.00)
    colors[clr.WindowBg]             = ImVec4(0.11, 0.15, 0.17, 1.00)
    colors[clr.ChildWindowBg]        = ImVec4(0.15, 0.18, 0.22, 1.00)
    colors[clr.PopupBg]              = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]               = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg]              = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.FrameBgHovered]       = ImVec4(0.12, 0.20, 0.28, 1.00)
    colors[clr.FrameBgActive]        = ImVec4(0.09, 0.12, 0.14, 1.00)
    colors[clr.TitleBg]                = ImVec4(0.04, 0.04, 0.04, 1.00)
    colors[clr.TitleBgActive]          = ImVec4(0.16, 0.48, 0.42, 1.00)
    colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.MenuBarBg]            = ImVec4(0.15, 0.18, 0.22, 1.00)
    colors[clr.ScrollbarBg]          = ImVec4(0.02, 0.02, 0.02, 0.39)
    colors[clr.ScrollbarGrab]        = ImVec4(0.20, 0.25, 0.29, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
    colors[clr.ScrollbarGrabActive]  = ImVec4(0.09, 0.21, 0.31, 1.00)
    colors[clr.ComboBg]                = colors[clr.PopupBg]
    colors[clr.CheckMark]              = ImVec4(0.26, 0.98, 0.85, 1.00)
    colors[clr.SliderGrab]             = ImVec4(0.24, 0.88, 0.77, 1.00)
    colors[clr.SliderGrabActive]       = ImVec4(0.26, 0.98, 0.85, 1.00)
    colors[clr.Button]                 = ImVec4(0.26, 0.98, 0.85, 0.30)
    colors[clr.ButtonHovered]          = ImVec4(0.26, 0.98, 0.85, 0.50)
    colors[clr.ButtonActive]           = ImVec4(0.06, 0.98, 0.82, 0.50)
    colors[clr.Header]                 = ImVec4(0.26, 0.98, 0.85, 0.31)
    colors[clr.HeaderHovered]          = ImVec4(0.26, 0.98, 0.85, 0.80)
    colors[clr.HeaderActive]           = ImVec4(0.26, 0.98, 0.85, 1.00)
    colors[clr.Separator]            = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.SeparatorHovered]     = ImVec4(0.60, 0.60, 0.70, 1.00)
    colors[clr.SeparatorActive]      = ImVec4(0.70, 0.70, 0.90, 1.00)
    colors[clr.ResizeGrip]           = ImVec4(0.26, 0.59, 0.98, 0.25)
    colors[clr.ResizeGripHovered]    = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[clr.ResizeGripActive]     = ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[clr.CloseButton]          = ImVec4(0.40, 0.39, 0.38, 0.16)
    colors[clr.CloseButtonHovered]   = ImVec4(0.40, 0.39, 0.38, 0.39)
    colors[clr.CloseButtonActive]    = ImVec4(0.40, 0.39, 0.38, 1.00)
    colors[clr.PlotLines]            = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[clr.PlotLinesHovered]     = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[clr.PlotHistogram]        = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[clr.TextSelectedBg]       = ImVec4(0.25, 1.00, 0.00, 0.43)
    colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(text).x / 2)
    imgui.Text(text)
end

function imgui.Hint(text, delay)
  if imgui.IsItemHovered() then
      if go_hint == nil then go_hint = os.clock() + (delay and delay or 0.0) end
      local alpha = (os.clock() - go_hint) * 5 -- скорость появления
      if os.clock() >= go_hint then
          imgui.PushStyleVar(imgui.StyleVar.Alpha, (alpha <= 1.0 and alpha or 1.0))
              imgui.PushStyleColor(imgui.Col.PopupBg, imgui.GetStyle().Colors[imgui.Col.ButtonHovered])
                  imgui.BeginTooltip()
                  imgui.PushTextWrapPos(450)
                  imgui.TextUnformatted(text)
                  if not imgui.IsItemVisible() and imgui.GetStyle().Alpha == 1.0 then go_hint = nil end
                  imgui.PopTextWrapPos()
                  imgui.EndTooltip()
              imgui.PopStyleColor()
          imgui.PopStyleVar()
      end
  end
end

function sampev.onServerMessage(color, text)
    if text:find('%{FF00FF%}%[A%] %{FFFFFF%}Вы успешно авторизовались как администратор (%d+)') then
        lua_thread.create(function()
            wait(500)
            sampSendChat('/skin ' .. ini.main.skin)
			wait(1000)
            sampSendChat('/a ' .. ini.main.sms_admin)
            wait(500)
            if true_false.templeader_combo then
                sampSendChat('/templeader ' .. ini.main.combo_org)
            end
        end)
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 1227 then
        sampSendDialogResponse(1227, 1, 0, ini.main.admpassword)
        return false
    end
end

function save()
    ini.main.admtag = admintag.v
    ini.main.skin = skin.v
    ini.main.admpassword = admpass.v
    ini.cheats.wallhack = cWallHack.v
    ini.cheats.clickwarp = clickwarp.v
    ini.main.admlvl = adm_lvl.v
    ini.cheats.inf_ammo = inf_ammo.v
    ini.cheats.gm_car = gm_car.v
    ini.cheats.gm_mode = gm_mode.v
    ini.main.sms_admin = u8:decode(message_admin.v)
    ini.cheats.no_bike = no_bike.v
    ini.main.combo_org = combo_org.v
    inicfg.save(ini, directIni)
end

function nameTagOn()
	local pStSet = sampGetServerSettingsPtr()
	activeWH = true
	memory.setfloat(pStSet + 39, 1488.0)
	memory.setint8(pStSet + 47, 0)
	memory.setint8(pStSet + 56, 1)
end

function nameTagOff()
	local pStSet = sampGetServerSettingsPtr()
	activeWH = false
	memory.setfloat(pStSet + 39, 50.0)
	memory.setint8(pStSet + 47, 0)
	memory.setint8(pStSet + 56, 1)
end

function onScriptTerminate(script, quit)
	if script == thisScript() then
		imgui.Process = false
		imgui.ShowCursor = false
	end
end

function readFloatArray(ptr, idx)
    return representIntAsFloat(readMemory(ptr + idx * 4, 4, false))
end

function writeFloatArray(ptr, idx, value)
    writeMemory(ptr + idx * 4, 4, representFloatAsInt(value), false)
end

function displayVehicleName(x, y, gxt)
    x, y = convertWindowScreenCoordsToGameScreenCoords(x, y)
    useRenderCommands(true)
    setTextWrapx(640.0)
    setTextProportional(true)
    setTextJustify(false)
    setTextScale(0.33, 0.8)
    setTextDropshadow(0, 0, 0, 0, 0)
    setTextColour(255, 255, 255, 230)
    setTextEdge(1, 0, 0, 0, 100)
    setTextFont(1)
    displayText(x, y, gxt)
end

function getCarFreeSeat(car)
    if doesCharExist(getDriverOfCar(car)) then
      local maxPassengers = getMaximumNumberOfPassengers(car)
      for i = 0, maxPassengers do
        if isCarPassengerSeatFree(car, i) then
          return i + 1
        end
      end
      return nil -- no free seats
    else
      return 0 -- driver seat
    end
end

function getVehicleRotationMatrix(car)
    local entityPtr = getCarPointer(car)
    if entityPtr ~= 0 then
      local mat = readMemory(entityPtr + 0x14, 4, false)
      if mat ~= 0 then
        local rx, ry, rz, fx, fy, fz, ux, uy, uz
        rx = readFloatArray(mat, 0)
        ry = readFloatArray(mat, 1)
        rz = readFloatArray(mat, 2)

        fx = readFloatArray(mat, 4)
        fy = readFloatArray(mat, 5)
        fz = readFloatArray(mat, 6)

        ux = readFloatArray(mat, 8)
        uy = readFloatArray(mat, 9)
        uz = readFloatArray(mat, 10)
        return rx, ry, rz, fx, fy, fz, ux, uy, uz
      end
    end
end

function jumpIntoCar(car)
    local seat = getCarFreeSeat(car)
    if not seat then return false end                         -- no free seats
    if seat == 0 then warpCharIntoCar(playerPed, car)         -- driver seat
    else warpCharIntoCarAsPassenger(playerPed, car, seat - 1) -- passenger seat
    end
    restoreCameraJumpcut()
    return true
end

function showCursor(toggle)
    if toggle then
      sampSetCursorMode(CMODE_LOCKCAM)
    else
      sampToggleCursor(false)
    end
    cursorEnabled = toggle
end

function setEntityCoordinates(entityPtr, x, y, z)
    if entityPtr ~= 0 then
      local matrixPtr = readMemory(entityPtr + 0x14, 4, false)
      if matrixPtr ~= 0 then
        local posPtr = matrixPtr + 0x30
        writeMemory(posPtr + 0, 4, representFloatAsInt(x), false) -- X
        writeMemory(posPtr + 4, 4, representFloatAsInt(y), false) -- Y
        writeMemory(posPtr + 8, 4, representFloatAsInt(z), false) -- Z
      end
    end
end

function setCharCoordinatesDontResetAnim(char, x, y, z)
    if doesCharExist(char) then
      local ptr = getCharPointer(char)
      setEntityCoordinates(ptr, x, y, z)
    end
end

function teleportPlayer(x, y, z)
    if isCharInAnyCar(playerPed) then
      setCharCoordinates(playerPed, x, y, z)
    end
    setCharCoordinatesDontResetAnim(playerPed, x, y, z)
end

function removePointMarker()
    if pointMarker then
      removeUser3dMarker(pointMarker)
      pointMarker = nil
    end
end

function createPointMarker(x, y, z)
    pointMarker = createUser3dMarker(x, y, z + 0.3, 4)
end

function setVehicleRotationMatrix(car, rx, ry, rz, fx, fy, fz, ux, uy, uz)
    local entityPtr = getCarPointer(car)
    if entityPtr ~= 0 then
      local mat = readMemory(entityPtr + 0x14, 4, false)
      if mat ~= 0 then
        writeFloatArray(mat, 0, rx)
        writeFloatArray(mat, 1, ry)
        writeFloatArray(mat, 2, rz)

        writeFloatArray(mat, 4, fx)
        writeFloatArray(mat, 5, fy)
        writeFloatArray(mat, 6, fz)

        writeFloatArray(mat, 8, ux)
        writeFloatArray(mat, 9, uy)
        writeFloatArray(mat, 10, uz)
      end
    end
end

function rotateCarAroundUpAxis(car, vec)
    local mat = Matrix3X3(getVehicleRotationMatrix(car))
    local rotAxis = Vector3D(mat.up:get())
    vec:normalize()
    rotAxis:normalize()
    local theta = math.acos(rotAxis:dotProduct(vec))
    if theta ~= 0 then
      rotAxis:crossProduct(vec)
      rotAxis:normalize()
      rotAxis:zeroNearZero()
      mat = mat:rotate(rotAxis, -theta)
    end
    setVehicleRotationMatrix(car, mat:get())
end

function click_warp()
    lua_thread.create(function()
        while true do
        if cursorEnabled and not window.v and not teleportmenu.v and not templeader.v then
          local mode = sampGetCursorMode()
          if mode == 0 then
            showCursor(true)
          end
          local sx, sy = getCursorPos()
          local sw, sh = getScreenResolution()
          if sx >= 0 and sy >= 0 and sx < sw and sy < sh then
            local posX, posY, posZ = convertScreenCoordsToWorld3D(sx, sy, 700.0)
            local camX, camY, camZ = getActiveCameraCoordinates()
            local result, colpoint = processLineOfSight(camX, camY, camZ, posX, posY, posZ,
            true, true, false, true, false, false, false)
            if result and colpoint.entity ~= 0 then
              local normal = colpoint.normal
              local pos = Vector3D(colpoint.pos[1], colpoint.pos[2], colpoint.pos[3]) - (Vector3D(normal[1], normal[2], normal[3]) * 0.1)
              local zOffset = 300
              if normal[3] >= 0.5 then zOffset = 1 end
              local result, colpoint2 = processLineOfSight(pos.x, pos.y, pos.z + zOffset, pos.x, pos.y, pos.z - 0.3,
                true, true, false, true, false, false, false)
              if result then
                pos = Vector3D(colpoint2.pos[1], colpoint2.pos[2], colpoint2.pos[3] + 1)

                local curX, curY, curZ  = getCharCoordinates(playerPed)
                local dist = getDistanceBetweenCoords3d(curX, curY, curZ, pos.x, pos.y, pos.z)
                local hoffs = renderGetFontDrawHeight(font)

                sy = sy - 2
                sx = sx - 2
                renderFontDrawText(font, string.format("{FFFFFF}%0.2fm", dist), sx, sy - hoffs, 0xEEEEEEEE)

                local tpIntoCar = nil
                if colpoint.entityType == 2 then
                  local car = getVehiclePointerHandle(colpoint.entity)
                  if doesVehicleExist(car) and (not isCharInAnyCar(playerPed) or storeCarCharIsInNoSave(playerPed) ~= car) then
                    displayVehicleName(sx, sy - hoffs * 2, getNameOfVehicleModel(getCarModel(car)))
                    local color = 0xFFFFFFFF
                    if isKeyDown(VK_RBUTTON) then
                      tpIntoCar = car
                      color = 0xFFFFFFFF
                    end
                    renderFontDrawText(font, "{FFFFFF}Удерживайте ПКМ, чтобы телепортироваться в машину", sx, sy - hoffs * 3, color)
                  end
                end

                createPointMarker(pos.x, pos.y, pos.z)

                if isKeyDown(VK_LBUTTON) then
                  if tpIntoCar then
                    if not jumpIntoCar(tpIntoCar) then
                      teleportPlayer(pos.x, pos.y, pos.z)
                      local veh = storeCarCharIsInNoSave(playerPed)
                      local cordsVeh = {getCarCoordinates(veh)}
                      setCarCoordinates(veh, cordsVeh[1], cordsVeh[2], cordsVeh[3])
                      cursorEnabled = false
                      showCursor(false)
                      removePointMarker()
                      break
                    end
                  else
                    if isCharInAnyCar(playerPed) then
                      local norm = Vector3D(colpoint.normal[1], colpoint.normal[2], 0)
                      local norm2 = Vector3D(colpoint2.normal[1], colpoint2.normal[2], colpoint2.normal[3])
                      rotateCarAroundUpAxis(storeCarCharIsInNoSave(playerPed), norm2)
                      pos = pos - norm * 1.8
                      pos.z = pos.z - 1.1
                    end
                    teleportPlayer(pos.x, pos.y, pos.z)
                    cursorEnabled = false
                    showCursor(false)
                    removePointMarker()
                    break
                  end
                 
                  while isKeyDown(VK_LBUTTON) do wait(0) end
                  cursorEnabled = false
                  showCursor(false)
                  removePointMarker()
                  break
                end
              end
            end
          end
        end
        wait(0)
        removePointMarker()
       end
        cursorEnabled = false
        showCursor(false)
        removePointMarker()
    end)
end

function check_server()
    local servers = { -- Вписываем айпи серверов, которые нам нужны | Ниже пример
        '46.174.54.102'
    }
    local ip = select(1, sampGetCurrentServerAddress()) -- Получаем айпи сервера на котором мы сейчас
    for k, v in pairs(servers) do -- Проверяем
        if v == ip then
            return true -- Если мы находимся на том сервере
        end
    end
    return false -- Если мы на другом
end

function autoupdate()
    local dlstatus = require('moonloader').download_status
    local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
    if doesFileExist(json) then os.remove(json) end
    print('Начало проверки обновления')
    downloadUrlToFile("https://raw.githubusercontent.com/its16bit/AdminTools/main/version.json", json,
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
                            print('Найдено обновление: '.. thisScript().version ..' -> '.. updateversion ..'! Загрузка..')
                            wait(250)
                            downloadUrlToFile(updatelink, thisScript().path,
                                function(id3, status1, p13, p23)
                                    if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                    elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                        print('Загрузка окончена. Скрипт обновлен на версию '.. mc .. updateversion)
                                        goupdatestatus = true

                                        reload(false)
                                    end
                                    if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                                        if goupdatestatus == nil then
                                            print('Скрипт не смог обновится на версию '.. updateversion)
                                            update = false
                                        end
                                    end
                                end
                            )   
                        end)
                    else
                        update = false
                        print('Версии совпадают. Обновлений нет')
                        sampAddChatMessage('[AdminTools] {FFFFFF}Обновлений не найдено')
                    end
                end
            else
                print('Не удалось получить JSON таблицу', "Ошибка")
                sampAddChatMessage('[AdminTools] {FFFFFF}Обновление не удалось')
                update = false
            end
        end
    end)
    while update ~= false do wait(100) end
end

god_theme()
