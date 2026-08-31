--[[
-------------------------------------------------------------------------------------------
*              FSR Key Transposer
* Section      Main
* Author:      Andrew Dihtiaruk (FSR)
* Version:     1.00
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:     http://forum.cockos.com/showthread.php?t=309129
    
----------------------------------------------------------------

First, select the note/key in which the sample is currently playing. 
You can find it in the loop’s name or determine it yourself.
Then choose the target note/key from the submenu to transpose the sample.
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▶ ♪ Piano_Loop.wav   │   │ SELECT SOURCE KEY    │   │ MATCH C TO:D         │
│   Current key: C     │ → │──────────────────────│ → │──────────────────────│
│                      │   │ ▶ C                  │   │   C       (+0 st)    │
│                      │   │   C#                 │   │   C#      (+1 st)    │
│                      │   │   D                  │   │ ▶ D       (+2 st)    │
│                      │   │   D#                 │   │   D#      (+3 st)    │
│                      │   │   E                  │   │   E       (+4 st)    │
│                      │   │   F                  │   │   F       (+5 st)    │
│                      │   │   F#                 │   │   F#      (+6 st)    │
│                      │   │   G                  │   │   G       (-5 st)    │
│                      │   │   G#                 │   │   G#      (-4 st)    │
│                      │   │   A                  │   │   A       (-3 st)    │
│                      │   │   A#                 │   │   A#      (-2 st)    │
│                      │   │   B                  │   │   B       (-1 st)    │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
--]] 

if not reaper.APIExists("JS_Window_Find") then
    reaper.ShowMessageBox("Потрібен js_ReaScriptAPI!", "Помилка", 0)
    return
end

local notes = {
    { name = "C",  value = 0  },
    { name = "C#", value = 1  },
    { name = "D",  value = 2  },
    { name = "D#", value = 3  },
    { name = "E",  value = 4  },
    { name = "F",  value = 5  },
    { name = "F#", value = 6  },
    { name = "G",  value = 7  },
    { name = "G#", value = 8  },
    { name = "A",  value = 9  },
    { name = "A#", value = 10 },
    { name = "B",  value = 11 }
}

local function nearestDiff(fromVal, toVal)
    local d = toVal - fromVal
    if d > 6 then d = d - 12 end
    if d < -6 then d = d + 12 end
    return d
end

local function getCurrentPitch()
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        local take = reaper.GetActiveTake(item)
        if take and not reaper.TakeIsMIDI(take) then
            return reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
        end
    end
    return 0
end

local function buildMenu()
    local parts = {}
    local actions = {}

    for _, src in ipairs(notes) do
        table.insert(parts, ">" .. src.name)

        for _, dst in ipairs(notes) do
            local diff = nearestDiff(src.value, dst.value)
            local sign = diff >= 0 and "+" or ""
            table.insert(parts, string.format("%s (%s%d st)", dst.name, sign, diff))

            actions[#actions + 1] = {
                from = src.name,
                to = dst.name,
                diff = diff
            }
        end

        table.insert(parts, "<")
    end
    
    -- Додаємо сепаратор та октавні зміщення
    table.insert(parts, "")
    
    local currentPitch = getCurrentPitch()
    local newPitchUp = currentPitch + 12
    local newPitchDown = currentPitch - 12
    
    table.insert(parts, "+12")
    actions[#actions + 1] = {
        from = "current",
        to = "octave_up",
        diff = currentPitch + 12,
        isAbsolute = true
    }
    
    table.insert(parts, "-12")
    actions[#actions + 1] = {
        from = "current",
        to = "octave_down",
        diff = currentPitch - 12,
        isAbsolute = true
    }

    return table.concat(parts, "|"), actions
end

local function applyPitchToSelectedItems(diff)
    local cnt = reaper.CountSelectedMediaItems(0)
    if cnt == 0 then
        reaper.ShowMessageBox("Вибери хоча б один item", "Увага", 0)
        return
    end

    reaper.Undo_BeginBlock()

    for i = 0, cnt - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)

        if take and not reaper.TakeIsMIDI(take) then
            -- Встановлюємо абсолютне значення pitch замість додавання
            reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", diff)
        end
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Transpose sample by key menu", -1)
end

local menuStr, actions = buildMenu()
local result = gfx.showmenu(menuStr)

if result > 0 and result <= #actions then
    local a = actions[result]
    applyPitchToSelectedItems(a.diff)
end
