--[[
-------------------------------------------------------------------------------------------
*              FSR Set MIDI Note Names
* Section      Main
* Author:      Andrew Dihtiaruk(FSR)
* Version:     1.O.0
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:     http://reaper-script-feedback.forsemusic1996.workers.dev/
-------------------------------------------------------------------------------------------
-- @about
-- By default, notes in REAPER's MIDI Editor are not labeled with note names.
-- This script automatically assigns note names to MIDI notes when you double-click a MIDI item


### How to assign the script to double-click

REAPER → **Options** → **Preferences…** → **Editing Behavior** → **Mouse Modifiers**

1. **Context:** `Media item`
2. **Mouse modifier:** `Double click`
3. Select **Default action**
4. Click **Action list…**
5. Find and select: `Set MIDI Note Names`
6. Click **Apply** → **OK**

Now double-clicking a media item will run the **Set MIDI Note Names** script.


-------------------------------------------------------------------------------------------
--]]  
local r = reaper

local OPEN_ITEM_PROPERTIES_FOR_AUDIO = true
local TARGET_CHANNEL = 0
local HORIZONTAL_ZOOM = true

local CMD_ITEM_PROPERTIES  = 40009
local CMD_OPEN_MIDI_EDITOR = 40153
local CMD_ZOOM_TO_CONTENTS = 40468

-- C notes intentionally omitted:
-- 0, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120

local NOTE_NAMES = {
    [1]="C#-1", [2]="D-1", [3]="D#-1", [4]="E-1", [5]="F-1",
    [6]="F#-1", [7]="G-1", [8]="G#-1", [9]="A-1", [10]="A#-1", [11]="B-1",

    [13]="C#0", [14]="D0", [15]="D#0", [16]="E0", [17]="F0",
    [18]="F#0", [19]="G0", [20]="G#0", [21]="A0", [22]="A#0", [23]="B0",

    [25]="C#1", [26]="D1", [27]="D#1", [28]="E1", [29]="F1",
    [30]="F#1", [31]="G1", [32]="G#1", [33]="A1", [34]="A#1", [35]="B1",

    [37]="C#2", [38]="D2", [39]="D#2", [40]="E2", [41]="F2",
    [42]="F#2", [43]="G2", [44]="G#2", [45]="A2", [46]="A#2", [47]="B2",

    [49]="C#3", [50]="D3", [51]="D#3", [52]="E3", [53]="F3",
    [54]="F#3", [55]="G3", [56]="G#3", [57]="A3", [58]="A#3", [59]="B3",

    [61]="C#4", [62]="D4", [63]="D#4", [64]="E4", [65]="F4",
    [66]="F#4", [67]="G4", [68]="G#4", [69]="A4", [70]="A#4", [71]="B4",

    [73]="C#5", [74]="D5", [75]="D#5", [76]="E5", [77]="F5",
    [78]="F#5", [79]="G5", [80]="G#5", [81]="A5", [82]="A#5", [83]="B5",

    [85]="C#6", [86]="D6", [87]="D#6", [88]="E6", [89]="F6",
    [90]="F#6", [91]="G6", [92]="G#6", [93]="A6", [94]="A#6", [95]="B6",

    [97]="C#7", [98]="D7", [99]="D#7", [100]="E7", [101]="F7",
    [102]="F#7", [103]="G7", [104]="G#7", [105]="A7", [106]="A#7", [107]="B7",

    [109]="C#8", [110]="D8", [111]="D#8", [112]="E8", [113]="F8",
    [114]="F#8", [115]="G8", [116]="G#8", [117]="A8", [118]="A#8", [119]="B8",

    [121]="C#9", [122]="D9", [123]="D#9", [124]="E9", [125]="F9",
    [126]="F#9", [127]="G9"
}

local item = r.GetSelectedMediaItem(0, 0)
if not item then return end

local take = r.GetMediaItemTake(item, 0)

-- AUDIO ITEM
if not take or not r.TakeIsMIDI(take) then
    if OPEN_ITEM_PROPERTIES_FOR_AUDIO then
        r.Main_OnCommand(CMD_ITEM_PROPERTIES, 0)
    end
    return
end

-- MIDI ITEM
local track = r.GetMediaItemTake_Track(take)
if not track then return end

-- Якщо E4 вже встановлена, повторно note names не записуємо
local changed = r.GetTrackMIDINoteNameEx(0, track, 64, TARGET_CHANNEL) ~= "E4"

if changed then
    for pitch, name in pairs(NOTE_NAMES) do
        r.SetTrackMIDINoteNameEx(0, track, pitch, TARGET_CHANNEL, name)
    end
end

if HORIZONTAL_ZOOM then
    -- Відкрити вибраний MIDI item у MIDI Editor
    r.Main_OnCommand(CMD_OPEN_MIDI_EDITOR, 0)
    local editor = r.MIDIEditor_GetActive()

    if editor then
        -- Zoom to contents
        r.MIDIEditor_OnCommand(editor, CMD_ZOOM_TO_CONTENTS)

        if changed then
            r.MIDI_RefreshEditors(take)
        end

        -- Перенести edit cursor на початок MIDI item без переміщення play cursor
        local editor_take = r.MIDIEditor_GetTake(editor)
        if editor_take then
            local editor_item = r.GetMediaItemTake_Item(editor_take)
            if editor_item then
                local item_start = r.GetMediaItemInfo_Value(editor_item, "D_POSITION")
                r.SetEditCurPos(item_start, false, false)
            end
        end
    end
end

