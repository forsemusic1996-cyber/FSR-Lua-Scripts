--[[
-------------------------------------------------------------------------------------------
*              FSR Preset Manager
* Section      Main
* Author:      Andrew Dihtiaruk (FSR)
* Version:     1.0.0
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:    


-------------------------------------------------------------------------------------------
--]] 
function print(v)
  reaper.ShowConsoleMsg("\n" .. tostring(v));
end; 

local ctx = reaper.ImGui_CreateContext("Preset Manager");
local presetList = {}
local selectedPresets = {}
local presetFile = nil
local nativePresetFile = nil
local presetFileExt = nil
track = nil
fxnum = nil
autoSwitchPreset = true
local shift = false
local ctrl = false
local alt = false
local previousFXName = nil
local searchQuery = ""
local currentPresetIndex = 0
local activePresetName = ""
local currentFXName = ""

local lastWindowW, lastWindowH = 500, 700
local lastWindowX, lastWindowY = 0, 0
local pendingWindowSize = nil
local pendingWindowPos = nil

local lockWindowPosition = reaper.GetExtState("PresetManager", "LockWindowPosition") == "true"
local lockWindowSize = reaper.GetExtState("PresetManager", "LockWindowSize") == "true"

local sortMode = reaper.GetExtState("PresetManager", "SortMode")
if sortMode == "" then sortMode = "none" end

local horizontalMode = reaper.GetExtState("PresetManager", "HorizontalMode") == "true"
local showNumbers = reaper.GetExtState("PresetManager", "ShowNumbers") == "true"
local showTooltipsInline = reaper.GetExtState("PresetManager", "ShowTooltipsInline") == "true"
if reaper.GetExtState("PresetManager", "ShowTooltipsInline") == "" then showTooltipsInline = true end
local showColorFilters = reaper.GetExtState("PresetManager", "ShowColorFilters") ~= "false"
local showTags = reaper.GetExtState("PresetManager", "ShowTags") ~= "false"
local showColorMarkers = reaper.GetExtState("PresetManager", "ShowColorMarkers") ~= "false"

local rowsPerColumn = tonumber(reaper.GetExtState("PresetManager", "RowsPerColumn")) or 15
local columnWidth = tonumber(reaper.GetExtState("PresetManager", "ColumnWidth")) or 200
local legacyScrollbarSize = tonumber(reaper.GetExtState("PresetManager", "ScrollbarSize"))
local scrollbarSizeVertical = tonumber(reaper.GetExtState("PresetManager", "ScrollbarSizeVertical")) or legacyScrollbarSize or 12
local scrollbarSizeHorizontal = tonumber(reaper.GetExtState("PresetManager", "ScrollbarSizeHorizontal")) or legacyScrollbarSize or 12

local filterByColor = nil
local rowsPerColumnInput = tostring(rowsPerColumn)
local showMenuBar = reaper.GetExtState("PresetManager", "ShowMenuBar")
if showMenuBar == "" then
    showMenuBar = true
else
    showMenuBar = (showMenuBar == "true")
end

appearance = {
    keyBackground = "BackgroundColor",
    keyAccent = "AccentColor",
    keyAccent2 = "AccentColor2",
    keyAccentVersion = "AccentColorDefaultVersion",
    keyText = "TextColor",
    defaultBackground = 0x1E1E1EFF,
    defaultAccent = 0x4488FFFF,
    defaultText = 0xE0E0E0FF,
    closeRequested = false
}

function appearance.loadColor(key, defaultColor)
    local saved = tonumber(reaper.GetExtState("PresetManager", key))
    if saved then
        return (saved & 0xFFFFFF00) | 0xFF
    end
    return defaultColor
end

appearance.backgroundColor = appearance.loadColor(appearance.keyBackground, appearance.defaultBackground)
appearance.accentColor = appearance.loadColor(appearance.keyAccent, appearance.defaultAccent)
appearance.textColor = appearance.loadColor(appearance.keyText, appearance.defaultText)

if reaper.GetExtState("PresetManager", appearance.keyAccentVersion) ~= "2" then
    if appearance.accentColor == 0x00AAFFFF then
        appearance.accentColor = appearance.defaultAccent
        reaper.SetExtState("PresetManager", appearance.keyAccent, tostring(appearance.accentColor), true)
    end
    reaper.SetExtState("PresetManager", appearance.keyAccentVersion, "2", true)
end

appearance.accent2Color = appearance.loadColor(appearance.keyAccent2, appearance.accentColor)

local scriptPresetsOpen = false
local newPresetName = ""
local scriptPresetNames = {}
local currentScriptPresetIndex = 0

scriptPresetSaveMask = {}

function resetScriptPresetSaveMask()
    scriptPresetSaveMask.mode = true
    scriptPresetSaveMask.numbers = true
    scriptPresetSaveMask.inlineTooltips = true
    scriptPresetSaveMask.rowsPerColumn = true
    scriptPresetSaveMask.columnWidth = true
    scriptPresetSaveMask.scrollbarVertical = true
    scriptPresetSaveMask.scrollbarHorizontal = true
    scriptPresetSaveMask.windowSize = true
    scriptPresetSaveMask.windowPosition = true
    scriptPresetSaveMask.foldersPanelWidth = true
    scriptPresetSaveMask.tags = true
    scriptPresetSaveMask.colorFilters = true
    scriptPresetSaveMask.colorMarkers = true
    scriptPresetSaveMask.foldersPanel = true
    scriptPresetSaveMask.sortMode = true
end

resetScriptPresetSaveMask()

local colorMarkers = {}
local colorMarkerFile = reaper.GetResourcePath() .. "/Scripts/PresetManager_ColorMarkers.txt"

local availableColors = {
    { name = "Red",     color = 0xFF4444FF, priority = 1 },
    { name = "Orange",  color = 0xFF8844FF, priority = 2 },
    { name = "Yellow",  color = 0xFFFF44FF, priority = 3 },
    { name = "Green",   color = 0x44FF44FF, priority = 4 },
    { name = "Cyan",    color = 0x44FFFFFF, priority = 5 },
    { name = "Blue",    color = 0x4488FFFF, priority = 6 },
    { name = "Purple",  color = 0xAA44FFFF, priority = 7 },
    { name = "Pink",    color = 0xFF44AAFF, priority = 8 },
    { name = "None",    color = nil, priority = 99 }
}

local colorPriority = {}
for _, c in ipairs(availableColors) do
    if c.color then colorPriority[c.color] = c.priority end
end

local SCRIPT_ID = "PresetManager"
local customPresetRoot = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "/Presets"
local tags = {}
local tag_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_Tags.txt"
local tooltipTags = {}
local tooltip_tag_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_TooltipTags.txt"
local presetSaveTags = {}
local preset_save_tag_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_PresetSaveTags.txt"
local script_presets_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_ScriptPresets.txt"

local allFXFolders = {}
local folders = {}
local fx_folders_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_FXFolders.txt"

local allPresetFolders = {}
local presetFolders = {}
local preset_folders_file = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID .. "_PresetFolders.txt"

local currentFolder = nil
local selectedFolderIndex = nil

local showFoldersPanel = reaper.GetExtState("PresetManager", "ShowFoldersPanel") ~= "false"
local foldersPanelWidth = tonumber(reaper.GetExtState("PresetManager", "FoldersPanelWidth")) or 150

local isDraggingSplitter = false
local dragStartX = nil
local dragStartWidth = nil
local dragPresetName = nil
local dragSelectedPresets = {}
local dragTagIndex = nil

local renameState = { open = false, index = nil, input = "" }
local tooltipState = { open = false, index = nil, input = "" }
local savePresetState = { open = false, input = "", autoFocus = false }
local folderRenameState = { open = false, index = nil, input = "" }
local newFolderState = { open = false, input = "" }

local font = reaper.ImGui_CreateFont("Arial", 14)
local noFxFont = reaper.ImGui_CreateFont("Arial", 18)
local compactHelpFont = reaper.ImGui_CreateFont("Arial", 12)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, noFxFont)
reaper.ImGui_Attach(ctx, compactHelpFont)

local scriptPresets = {}
local scriptPresetHotkeys = {}
local currentFilteredList = {}
local currentIndexMap = {}

local waitingForHotkey = nil
local hotkeyInputActive = false

local TOOLTIP_RIGHT_MARGIN = 16

local feedbackMessage = ""
local feedbackTimer = 0
local feedbackColor = 0x4488FFFF
local FEEDBACK_DURATION = 1.0

local lastPresetCount = 0
local lastPresetFileTime = 0
local nextExternalCheckTime = 0
local filterCacheVersion = 0
local filteredCache = { signature = nil, presets = {}, indexMap = {} }
local tooltipWidthCache = { signature = nil, width = 0 }

local function disableKeyboardNav()
    if not (reaper.ImGui_GetConfigVar and reaper.ImGui_SetConfigVar and reaper.ImGui_ConfigVar_Flags and reaper.ImGui_ConfigFlags_NavEnableKeyboard) then
        return
    end
    local flags = reaper.ImGui_GetConfigVar(ctx, reaper.ImGui_ConfigVar_Flags())
    flags = flags & ~reaper.ImGui_ConfigFlags_NavEnableKeyboard()
    if reaper.ImGui_ConfigFlags_NavEnableGamepad then
        flags = flags & ~reaper.ImGui_ConfigFlags_NavEnableGamepad()
    end
    reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_Flags(), flags)

    if reaper.ImGui_ConfigVar_NavCaptureKeyboard then
        reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_NavCaptureKeyboard(), 0)
    end
    if reaper.ImGui_ConfigVar_NavCursorVisibleAuto then
        reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_NavCursorVisibleAuto(), 0)
    end
    if reaper.ImGui_ConfigVar_NavCursorVisibleAlways then
        reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_NavCursorVisibleAlways(), 0)
    end
end

disableKeyboardNav()

local function invalidatePresetViewCache()
    filterCacheVersion = filterCacheVersion + 1
    filteredCache.signature = nil
    tooltipWidthCache.signature = nil
end

local function showFeedback(msg, color)
    feedbackMessage = msg
    feedbackTimer = reaper.time_precise() + FEEDBACK_DURATION
    feedbackColor = color or (appearance.usingDefaultTheme and 0x4488FFFF or appearance.accentColor)
end

function appearance.lerpColorRGBA(c1, c2, t)
    if t <= 0 then return c1 end
    if t >= 1 then return c2 end
    local r1, g1, b1, a1 = (c1 >> 24) & 0xFF, (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
    local r2, g2, b2, a2 = (c2 >> 24) & 0xFF, (c2 >> 16) & 0xFF, (c2 >> 8) & 0xFF, c2 & 0xFF
    local rr = math.floor(r1 + (r2 - r1) * t + 0.5)
    local gg = math.floor(g1 + (g2 - g1) * t + 0.5)
    local bb = math.floor(b1 + (b2 - b1) * t + 0.5)
    local aa = math.floor(a1 + (a2 - a1) * t + 0.5)
    return (rr << 24) | (gg << 16) | (bb << 8) | aa
end

function appearance.offsetColor(c, offset)
    local cr = math.max(0, math.min(255, ((c >> 24) & 0xFF) + offset))
    local cg = math.max(0, math.min(255, ((c >> 16) & 0xFF) + offset))
    local cb = math.max(0, math.min(255, ((c >> 8) & 0xFF) + offset))
    return (cr << 24) | (cg << 16) | (cb << 8) | 0xFF
end

function appearance.colorRGBAtoRGB(c)
    return (c >> 8) & 0xFFFFFF
end

function appearance.colorRGBtoRGBA(c)
    return ((c & 0xFFFFFF) << 8) | 0xFF
end

function appearance.rebaseColor(color, fromBase, toBase)
    local rr = math.max(0, math.min(255, ((color >> 24) & 0xFF) - ((fromBase >> 24) & 0xFF) + ((toBase >> 24) & 0xFF)))
    local gg = math.max(0, math.min(255, ((color >> 16) & 0xFF) - ((fromBase >> 16) & 0xFF) + ((toBase >> 16) & 0xFF)))
    local bb = math.max(0, math.min(255, ((color >> 8) & 0xFF) - ((fromBase >> 8) & 0xFF) + ((toBase >> 8) & 0xFF)))
    return (rr << 24) | (gg << 16) | (bb << 8) | (color & 0xFF)
end

local theme = {
    WindowBg = 0x1E1E1EFF, Text = 0xE0E0E0FF, TextDisabled = 0x808080FF,
    FrameBg = 0x333333FF, FrameBgHovered = 0x444444FF, FrameBgActive = 0x555555FF,
    TitleBg = 0x1A1A1AFF, TitleBgActive = 0x2D2D2DFF,
    Button = 0x404040FF, ButtonHovered = 0x505050FF, ButtonActive = 0x606060FF,
    CheckMark = 0x4488FFFF, ScrollbarBg = 0x1A1A1AFF,
    ScrollbarGrab = 0x404040FF, ScrollbarGrabHovered = 0x505050FF, ScrollbarGrabActive = 0x606060FF,
    SliderGrab = 0x4488FFFF, SliderGrabActive = 0x4488FFFF,
    Header = 0x3D3D3DFF, HeaderHovered = 0x4D4D4DFF, HeaderActive = 0x5D5D5DFF,
    Separator = 0x505050FF, PopupBg = 0x252525FF, MenuBarBg = 0x2A2A2AFF,
    ActivePreset = 0x4488FFFF, TooltipText = 0x888888FF,
    FolderColor = 0x4488FFFF,
    FolderActive = 0x4488FFFF,
    FolderSeparator = 0x4488FFFF,
    SplitterHovered = 0x707070FF,
    SplitterActive = 0x4488FFFF,
    PlaceholderText = 0x666666FF,
    DragDropTarget = 0x4488FFFF
}

function appearance.refreshThemeColors()
    local bg = appearance.backgroundColor
    appearance.usingDefaultTheme = appearance.backgroundColor == appearance.defaultBackground
        and appearance.accentColor == appearance.defaultAccent
        and appearance.textColor == appearance.defaultText
    theme.WindowBg = bg
    theme.Text = appearance.textColor
    theme.TextDisabled = appearance.rebaseColor(0x808080FF, appearance.defaultText, appearance.textColor)
    theme.FrameBg = appearance.rebaseColor(0x333333FF, appearance.defaultBackground, bg)
    theme.FrameBgHovered = appearance.rebaseColor(0x444444FF, appearance.defaultBackground, bg)
    theme.FrameBgActive = appearance.rebaseColor(0x555555FF, appearance.defaultBackground, bg)
    theme.TitleBg = appearance.rebaseColor(0x1A1A1AFF, appearance.defaultBackground, bg)
    theme.TitleBgActive = appearance.rebaseColor(0x2D2D2DFF, appearance.defaultBackground, bg)
    theme.Button = appearance.rebaseColor(0x404040FF, appearance.defaultBackground, bg)
    theme.ButtonHovered = appearance.rebaseColor(0x505050FF, appearance.defaultBackground, bg)
    theme.ButtonActive = appearance.rebaseColor(0x606060FF, appearance.defaultBackground, bg)
    theme.CheckMark = appearance.accentColor
    theme.ScrollbarBg = appearance.rebaseColor(0x1A1A1AFF, appearance.defaultBackground, bg)
    theme.ScrollbarGrab = appearance.rebaseColor(0x404040FF, appearance.defaultBackground, bg)
    theme.ScrollbarGrabHovered = appearance.rebaseColor(0x505050FF, appearance.defaultBackground, bg)
    theme.ScrollbarGrabActive = appearance.rebaseColor(0x606060FF, appearance.defaultBackground, bg)
    theme.Header = appearance.rebaseColor(0x3D3D3DFF, appearance.defaultBackground, bg)
    theme.HeaderHovered = appearance.rebaseColor(0x4D4D4DFF, appearance.defaultBackground, bg)
    theme.HeaderActive = appearance.rebaseColor(0x5D5D5DFF, appearance.defaultBackground, bg)
    theme.Separator = appearance.rebaseColor(0x505050FF, appearance.defaultBackground, bg)
    theme.PopupBg = appearance.rebaseColor(0x252525FF, appearance.defaultBackground, bg)
    theme.MenuBarBg = appearance.rebaseColor(0x2A2A2AFF, appearance.defaultBackground, bg)
    theme.SliderGrab = appearance.accentColor
    theme.SliderGrabActive = appearance.accentColor
    theme.ActivePreset = appearance.accentColor
    theme.TooltipText = appearance.rebaseColor(0x888888FF, appearance.defaultText, appearance.textColor)
    theme.FolderColor = appearance.usingDefaultTheme and 0x4488FFFF or appearance.accentColor
    theme.FolderActive = appearance.accent2Color
    theme.FolderSeparator = appearance.accent2Color
    theme.SplitterHovered = appearance.rebaseColor(0x707070FF, appearance.defaultBackground, bg)
    theme.SplitterActive = appearance.accent2Color
    theme.PlaceholderText = appearance.rebaseColor(0x666666FF, appearance.defaultText, appearance.textColor)
    theme.DragDropTarget = appearance.accentColor
end

appearance.refreshThemeColors()

function appearance.drawMenuItems()
    local noInputs = reaper.ImGui_ColorEditFlags_NoInputs()
    local changedBackground, newBackground = reaper.ImGui_ColorEdit3(ctx, "Background Color", appearance.colorRGBAtoRGB(appearance.backgroundColor), noInputs)
    if changedBackground then
        appearance.backgroundColor = appearance.colorRGBtoRGBA(newBackground)
        reaper.SetExtState("PresetManager", appearance.keyBackground, tostring(appearance.backgroundColor), true)
        appearance.refreshThemeColors()
    end

    local changedAccent, newAccent = reaper.ImGui_ColorEdit3(ctx, "Accent 1 Color", appearance.colorRGBAtoRGB(appearance.accentColor), noInputs)
    if changedAccent then
        appearance.accentColor = appearance.colorRGBtoRGBA(newAccent)
        appearance.accent2Color = appearance.accentColor
        reaper.SetExtState("PresetManager", appearance.keyAccent, tostring(appearance.accentColor), true)
        reaper.SetExtState("PresetManager", appearance.keyAccent2, tostring(appearance.accent2Color), true)
        appearance.refreshThemeColors()
    end

    local changedAccent2, newAccent2 = reaper.ImGui_ColorEdit3(ctx, "Accent 2 Color", appearance.colorRGBAtoRGB(appearance.accent2Color), noInputs)
    if changedAccent2 then
        appearance.accent2Color = appearance.colorRGBtoRGBA(newAccent2)
        reaper.SetExtState("PresetManager", appearance.keyAccent2, tostring(appearance.accent2Color), true)
        appearance.refreshThemeColors()
    end

    local changedText, newText = reaper.ImGui_ColorEdit3(ctx, "Text Color", appearance.colorRGBAtoRGB(appearance.textColor), noInputs)
    if changedText then
        appearance.textColor = appearance.colorRGBtoRGBA(newText)
        reaper.SetExtState("PresetManager", appearance.keyText, tostring(appearance.textColor), true)
        appearance.refreshThemeColors()
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Default") then
        appearance.backgroundColor = appearance.defaultBackground
        appearance.accentColor = appearance.defaultAccent
        appearance.accent2Color = appearance.defaultAccent
        appearance.textColor = appearance.defaultText
        reaper.SetExtState("PresetManager", appearance.keyBackground, tostring(appearance.backgroundColor), true)
        reaper.SetExtState("PresetManager", appearance.keyAccent, tostring(appearance.accentColor), true)
        reaper.SetExtState("PresetManager", appearance.keyAccent2, tostring(appearance.accent2Color), true)
        reaper.SetExtState("PresetManager", appearance.keyText, tostring(appearance.textColor), true)
        appearance.refreshThemeColors()
    end
end

function appearance.pushAccent2ButtonColors()
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), theme.FolderActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), theme.FolderActive)
end

function appearance.popAccent2ButtonColors()
    reaper.ImGui_PopStyleColor(ctx, 2)
end

local keyNames = {
    [0x08] = "Backspace", [0x09] = "Tab", [0x0D] = "Enter", [0x1B] = "Escape",
    [0x20] = "Space", [0x21] = "PageUp", [0x22] = "PageDown", [0x23] = "End",
    [0x24] = "Home", [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down",
    [0x2D] = "Insert", [0x2E] = "Delete",
    [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
    [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y", [0x5A] = "Z",
    [0x60] = "Num0", [0x61] = "Num1", [0x62] = "Num2", [0x63] = "Num3", [0x64] = "Num4",
    [0x65] = "Num5", [0x66] = "Num6", [0x67] = "Num7", [0x68] = "Num8", [0x69] = "Num9",
    [0x6A] = "Num*", [0x6B] = "Num+", [0x6D] = "Num-", [0x6E] = "Num.", [0x6F] = "Num/",
    [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4", [0x74] = "F5",
    [0x75] = "F6", [0x76] = "F7", [0x77] = "F8", [0x78] = "F9", [0x79] = "F10",
    [0x7A] = "F11", [0x7B] = "F12",
    [0xBA] = ";", [0xBB] = "=", [0xBC] = ",", [0xBD] = "-", [0xBE] = ".", [0xBF] = "/",
    [0xC0] = "`", [0xDB] = "[", [0xDC] = "\\", [0xDD] = "]", [0xDE] = "'"
}

local imguiKeyMap = {
    [reaper.ImGui_Key_Backspace()] = 0x08,
    [reaper.ImGui_Key_Tab()] = 0x09,
    [reaper.ImGui_Key_Enter()] = 0x0D,
    [reaper.ImGui_Key_Escape()] = 0x1B,
    [reaper.ImGui_Key_Space()] = 0x20,
    [reaper.ImGui_Key_PageUp()] = 0x21,
    [reaper.ImGui_Key_PageDown()] = 0x22,
    [reaper.ImGui_Key_End()] = 0x23,
    [reaper.ImGui_Key_Home()] = 0x24,
    [reaper.ImGui_Key_LeftArrow()] = 0x25,
    [reaper.ImGui_Key_UpArrow()] = 0x26,
    [reaper.ImGui_Key_RightArrow()] = 0x27,
    [reaper.ImGui_Key_DownArrow()] = 0x28,
    [reaper.ImGui_Key_Insert()] = 0x2D,
    [reaper.ImGui_Key_Delete()] = 0x2E,
    [reaper.ImGui_Key_0()] = 0x30, [reaper.ImGui_Key_1()] = 0x31, [reaper.ImGui_Key_2()] = 0x32,
    [reaper.ImGui_Key_3()] = 0x33, [reaper.ImGui_Key_4()] = 0x34, [reaper.ImGui_Key_5()] = 0x35,
    [reaper.ImGui_Key_6()] = 0x36, [reaper.ImGui_Key_7()] = 0x37, [reaper.ImGui_Key_8()] = 0x38,
    [reaper.ImGui_Key_9()] = 0x39,
    [reaper.ImGui_Key_A()] = 0x41, [reaper.ImGui_Key_B()] = 0x42, [reaper.ImGui_Key_C()] = 0x43,
    [reaper.ImGui_Key_D()] = 0x44, [reaper.ImGui_Key_E()] = 0x45, [reaper.ImGui_Key_F()] = 0x46,
    [reaper.ImGui_Key_G()] = 0x47, [reaper.ImGui_Key_H()] = 0x48, [reaper.ImGui_Key_I()] = 0x49,
    [reaper.ImGui_Key_J()] = 0x4A, [reaper.ImGui_Key_K()] = 0x4B, [reaper.ImGui_Key_L()] = 0x4C,
    [reaper.ImGui_Key_M()] = 0x4D, [reaper.ImGui_Key_N()] = 0x4E, [reaper.ImGui_Key_O()] = 0x4F,
    [reaper.ImGui_Key_P()] = 0x50, [reaper.ImGui_Key_Q()] = 0x51, [reaper.ImGui_Key_R()] = 0x52,
    [reaper.ImGui_Key_S()] = 0x53, [reaper.ImGui_Key_T()] = 0x54, [reaper.ImGui_Key_U()] = 0x55,
    [reaper.ImGui_Key_V()] = 0x56, [reaper.ImGui_Key_W()] = 0x57, [reaper.ImGui_Key_X()] = 0x58,
    [reaper.ImGui_Key_Y()] = 0x59, [reaper.ImGui_Key_Z()] = 0x5A,
    [reaper.ImGui_Key_Keypad0()] = 0x60, [reaper.ImGui_Key_Keypad1()] = 0x61,
    [reaper.ImGui_Key_Keypad2()] = 0x62, [reaper.ImGui_Key_Keypad3()] = 0x63,
    [reaper.ImGui_Key_Keypad4()] = 0x64, [reaper.ImGui_Key_Keypad5()] = 0x65,
    [reaper.ImGui_Key_Keypad6()] = 0x66, [reaper.ImGui_Key_Keypad7()] = 0x67,
    [reaper.ImGui_Key_Keypad8()] = 0x68, [reaper.ImGui_Key_Keypad9()] = 0x69,
    [reaper.ImGui_Key_KeypadMultiply()] = 0x6A, [reaper.ImGui_Key_KeypadAdd()] = 0x6B,
    [reaper.ImGui_Key_KeypadSubtract()] = 0x6D, [reaper.ImGui_Key_KeypadDecimal()] = 0x6E,
    [reaper.ImGui_Key_KeypadDivide()] = 0x6F,
    [reaper.ImGui_Key_F1()] = 0x70, [reaper.ImGui_Key_F2()] = 0x71, [reaper.ImGui_Key_F3()] = 0x72,
    [reaper.ImGui_Key_F4()] = 0x73, [reaper.ImGui_Key_F5()] = 0x74, [reaper.ImGui_Key_F6()] = 0x75,
    [reaper.ImGui_Key_F7()] = 0x76, [reaper.ImGui_Key_F8()] = 0x77, [reaper.ImGui_Key_F9()] = 0x78,
    [reaper.ImGui_Key_F10()] = 0x79, [reaper.ImGui_Key_F11()] = 0x7A, [reaper.ImGui_Key_F12()] = 0x7B
}

local childBorderFlag = 0
if reaper.ImGui_ChildFlags_Border then
    childBorderFlag = reaper.ImGui_ChildFlags_Border()
else
    childBorderFlag = 1
end

local function BeginChild(id, w, h, border, flags)
    if border then
        return reaper.ImGui_BeginChild(ctx, id, w, h, childBorderFlag, flags or 0)
    else
        return reaper.ImGui_BeginChild(ctx, id, w, h, 0, flags or 0)
    end
end

local function getHotkeyString(hotkey)
    if not hotkey or hotkey.key == 0 then return "" end
    local parts = {}
    if hotkey.ctrl then table.insert(parts, "Ctrl") end
    if hotkey.alt then table.insert(parts, "Alt") end
    if hotkey.shift then table.insert(parts, "Shift") end
    local keyName = keyNames[hotkey.key] or string.format("0x%02X", hotkey.key)
    table.insert(parts, keyName)
    return table.concat(parts, "+")
end

local function sanitizeFXName(fx_name)
    if not fx_name or fx_name == "" then return "_unknown_" end
    local sanitized = fx_name:gsub("[|<>:\"/\\?*\n\r]", "_")
    sanitized = sanitized:gsub("^%s+", ""):gsub("%s+$", "")
    if sanitized == "" then return "_unknown_" end
    return sanitized
end

local function ensurePresetDirectory(path)
    if not path or path == "" then return false end
    if reaper.RecursiveCreateDirectory then
        return reaper.RecursiveCreateDirectory(path, 0) > 0
    end
    return false
end

local function copyPresetFile(source, destination)
    if not source or source == "" or not destination or destination == "" then return false end
    local sourceFile = io.open(source, "rb")
    if not sourceFile then return false end
    local content = sourceFile:read("*all")
    sourceFile:close()

    local destinationFile = io.open(destination, "wb")
    if not destinationFile then return false end
    destinationFile:write(content or "")
    destinationFile:close()
    return true
end

local function getPresetFiles(tr, fx)
    local nativeFile = reaper.TrackFX_GetUserPresetFilename(tr, fx)
    local _, fxName = reaper.TrackFX_GetFXName(tr, fx, "")
    local fxFolder = customPresetRoot .. "/" .. sanitizeFXName(fxName)
    ensurePresetDirectory(fxFolder)
    return fxFolder .. "/presets.ini", nativeFile
end

local function syncCustomPresetFileToNative()
    if not presetFile or presetFile == "" or not nativePresetFile or nativePresetFile == "" then return false end
    if presetFile == nativePresetFile then return true end
    if not reaper.file_exists(presetFile) then return false end
    return copyPresetFile(presetFile, nativePresetFile)
end

local function openCustomPresetFolder()
    ensurePresetDirectory(customPresetRoot)
    if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(customPresetRoot)
    elseif reaper.ExecProcess then
        local safePath = customPresetRoot:gsub('"', '""')
        reaper.ExecProcess('explorer.exe "' .. safePath .. '"', 0)
    else
        reaper.ShowMessageBox("Preset folder: " .. customPresetRoot, "Preset Manager", 0)
    end
end

local function LoadAllFXFolders()
    allFXFolders = {}
    local f = io.open(fx_folders_file, "r")
    if f then
        for line in f:lines() do
            local fxName, folderName = line:match("^(.+)|(.+)$")
            if fxName and folderName then
                if not allFXFolders[fxName] then allFXFolders[fxName] = {} end
                local exists = false
                for _, existing in ipairs(allFXFolders[fxName]) do
                    if existing == folderName then exists = true break end
                end
                if not exists then table.insert(allFXFolders[fxName], folderName) end
            end
        end
        f:close()
    end
end

local function SaveAllFXFolders()
    local f = io.open(fx_folders_file, "w")
    if f then
        for fxName, folderList in pairs(allFXFolders) do
            for _, folderName in ipairs(folderList) do
                f:write(fxName .. "|" .. folderName .. "\n")
            end
        end
        f:close()
    end
end

local function LoadFoldersForFX(fx_name)
    local key = sanitizeFXName(fx_name)
    if not allFXFolders[key] then allFXFolders[key] = {} end
    folders = allFXFolders[key]
end

local function SaveFolders()
    local key = sanitizeFXName(currentFXName)
    if key and key ~= "_unknown_" then allFXFolders[key] = folders end
    SaveAllFXFolders()
end

local function LoadAllPresetFolders()
    allPresetFolders = {}
    local f = io.open(preset_folders_file, "r")
    if f then
        for line in f:lines() do
            local fxName, presetName, folderName = line:match("^(.+)|(.+)|(.+)$")
            if fxName and presetName and folderName then
                if not allPresetFolders[fxName] then allPresetFolders[fxName] = {} end
                allPresetFolders[fxName][presetName] = folderName
            end
        end
        f:close()
    end
end

local function SaveAllPresetFolders()
    local f = io.open(preset_folders_file, "w")
    if f then
        for fxName, presetMap in pairs(allPresetFolders) do
            for presetName, folderName in pairs(presetMap) do
                f:write(fxName .. "|" .. presetName .. "|" .. folderName .. "\n")
            end
        end
        f:close()
    end
end

local function LoadPresetFoldersForFX(fx_name)
    local key = sanitizeFXName(fx_name)
    if not allPresetFolders[key] then allPresetFolders[key] = {} end
    presetFolders = allPresetFolders[key]
    invalidatePresetViewCache()
end

local function SavePresetFolders()
    local key = sanitizeFXName(currentFXName)
    if key and key ~= "_unknown_" then allPresetFolders[key] = presetFolders end
    SaveAllPresetFolders()
end

local function setPresetFolder(presetName, folderName)
    if not presetName or type(presetName) ~= "string" then return end
    if folderName then
        presetFolders[presetName] = folderName
    else
        presetFolders[presetName] = nil
    end
    SavePresetFolders()
    invalidatePresetViewCache()
end

local function addFolder(name)
    if not name or name == "" then return false end
    if currentFXName == "" then return false end
    local trimmed = name:match("^%s*(.-)%s*$")
    if trimmed == "" then return false end
    for _, f in ipairs(folders) do
        if f == trimmed then return false end
    end
    table.insert(folders, trimmed)
    SaveFolders()
    return true
end

local function deleteFolder(index)
    if not folders[index] then return end
    local folderName = folders[index]
    for presetName, folder in pairs(presetFolders) do
        if folder == folderName then presetFolders[presetName] = nil end
    end
    SavePresetFolders()
    table.remove(folders, index)
    SaveFolders()
    if currentFolder == folderName then currentFolder = nil end
    selectedFolderIndex = nil
    invalidatePresetViewCache()
end

local function renameFolder(index, newName)
    if not folders[index] or not newName or newName == "" then return false end
    local trimmed = newName:match("^%s*(.-)%s*$")
    if trimmed == "" then return false end
    local oldName = folders[index]
    for _, f in ipairs(folders) do
        if f == trimmed and f ~= oldName then return false end
    end
    for presetName, folder in pairs(presetFolders) do
        if folder == oldName then presetFolders[presetName] = trimmed end
    end
    SavePresetFolders()
    folders[index] = trimmed
    SaveFolders()
    if currentFolder == oldName then currentFolder = trimmed end
    invalidatePresetViewCache()
    return true
end

local function openNewFolderModal()
    newFolderState.open = true
    newFolderState.input = ""
end

local function openFolderRenameModal(index)
    folderRenameState.open = true
    folderRenameState.index = index
    folderRenameState.input = folders[index] or ""
end

local function updateScriptPresetNames()
    scriptPresetNames = {}
    for name, _ in pairs(scriptPresets) do table.insert(scriptPresetNames, name) end
    table.sort(scriptPresetNames)
end

local function LoadScriptPresets()
    scriptPresets = {}
    scriptPresetHotkeys = {}
    local f = io.open(script_presets_file, "r")
    if f then
        local content = f:read("*all")
        f:close()
        for presetName, presetData in content:gmatch("@@@(.-)@@@(.-)%%%%%%") do
            scriptPresets[presetName] = {}
            for key, value in presetData:gmatch("([%w_]+)=([^;]+);") do
                if key == "hotkeyKey" then
                    if not scriptPresetHotkeys[presetName] then scriptPresetHotkeys[presetName] = {} end
                    scriptPresetHotkeys[presetName].key = tonumber(value) or 0
                elseif key == "hotkeyCtrl" then
                    if not scriptPresetHotkeys[presetName] then scriptPresetHotkeys[presetName] = {} end
                    scriptPresetHotkeys[presetName].ctrl = (value == "true")
                elseif key == "hotkeyAlt" then
                    if not scriptPresetHotkeys[presetName] then scriptPresetHotkeys[presetName] = {} end
                    scriptPresetHotkeys[presetName].alt = (value == "true")
                elseif key == "hotkeyShift" then
                    if not scriptPresetHotkeys[presetName] then scriptPresetHotkeys[presetName] = {} end
                    scriptPresetHotkeys[presetName].shift = (value == "true")
                elseif value == "true" then scriptPresets[presetName][key] = true
                elseif value == "false" then scriptPresets[presetName][key] = false
                elseif tonumber(value) then scriptPresets[presetName][key] = tonumber(value)
                else scriptPresets[presetName][key] = value end
            end
        end
    end
    updateScriptPresetNames()
end

local function SaveScriptPresets()
    local f = io.open(script_presets_file, "w")
    if f then
        for name, preset in pairs(scriptPresets) do
            f:write("@@@" .. name .. "@@@")
            for key, value in pairs(preset) do f:write(key .. "=" .. tostring(value) .. ";") end
            local hotkey = scriptPresetHotkeys[name]
            if hotkey then
                f:write("hotkeyKey=" .. tostring(hotkey.key or 0) .. ";")
                f:write("hotkeyCtrl=" .. tostring(hotkey.ctrl or false) .. ";")
                f:write("hotkeyAlt=" .. tostring(hotkey.alt or false) .. ";")
                f:write("hotkeyShift=" .. tostring(hotkey.shift or false) .. ";")
            end
            f:write("%%%\n")
        end
        f:close()
    end
    updateScriptPresetNames()
end

local function GetCurrentSettings(mask)
    local settings = {
        horizontalMode = horizontalMode, showNumbers = showNumbers,
        showTooltipsInline = showTooltipsInline,
        rowsPerColumn = rowsPerColumn, columnWidth = columnWidth,
        scrollbarSize = scrollbarSizeVertical,
        scrollbarSizeVertical = scrollbarSizeVertical,
        scrollbarSizeHorizontal = scrollbarSizeHorizontal,
        windowWidth = lastWindowW, windowHeight = lastWindowH,
        windowX = lastWindowX, windowY = lastWindowY,
        lockWindowPosition = lockWindowPosition, lockWindowSize = lockWindowSize,
        sortMode = sortMode, showColorFilters = showColorFilters, showTags = showTags,
        showColorMarkers = showColorMarkers, showFoldersPanel = showFoldersPanel,
        foldersPanelWidth = foldersPanelWidth
    }

    if mask then
        settings.scrollbarSize = nil
        if not mask.mode then settings.horizontalMode = nil end
        if not mask.numbers then settings.showNumbers = nil end
        if not mask.inlineTooltips then settings.showTooltipsInline = nil end
        if not mask.rowsPerColumn then settings.rowsPerColumn = nil end
        if not mask.columnWidth then settings.columnWidth = nil end
        if not mask.scrollbarVertical then
            settings.scrollbarSizeVertical = nil
        end
        if not mask.scrollbarHorizontal then settings.scrollbarSizeHorizontal = nil end
        if not mask.windowSize then
            settings.windowWidth = nil
            settings.windowHeight = nil
            settings.lockWindowSize = nil
        end
        if not mask.windowPosition then
            settings.windowX = nil
            settings.windowY = nil
            settings.lockWindowPosition = nil
        end
        if not mask.foldersPanelWidth then settings.foldersPanelWidth = nil end
        if not mask.tags then settings.showTags = nil end
        if not mask.colorFilters then settings.showColorFilters = nil end
        if not mask.colorMarkers then settings.showColorMarkers = nil end
        if not mask.foldersPanel then settings.showFoldersPanel = nil end
        if not mask.sortMode then settings.sortMode = nil end
    end

    return settings
end

local function ApplySettings(settings)
    if settings.horizontalMode ~= nil then
        horizontalMode = settings.horizontalMode
        reaper.SetExtState("PresetManager", "HorizontalMode", tostring(horizontalMode), true)
    end
    if settings.showNumbers ~= nil then
        showNumbers = settings.showNumbers
        reaper.SetExtState("PresetManager", "ShowNumbers", tostring(showNumbers), true)
    end
    if settings.showTooltipsInline ~= nil then
        showTooltipsInline = settings.showTooltipsInline
        reaper.SetExtState("PresetManager", "ShowTooltipsInline", tostring(showTooltipsInline), true)
    end
    if settings.rowsPerColumn then
        rowsPerColumn = settings.rowsPerColumn
        rowsPerColumnInput = tostring(rowsPerColumn)
        reaper.SetExtState("PresetManager", "RowsPerColumn", tostring(rowsPerColumn), true)
    end
    if settings.columnWidth then
        columnWidth = settings.columnWidth
        reaper.SetExtState("PresetManager", "ColumnWidth", tostring(columnWidth), true)
    end
    if settings.scrollbarSize then
        scrollbarSizeVertical = settings.scrollbarSize
        scrollbarSizeHorizontal = settings.scrollbarSize
        reaper.SetExtState("PresetManager", "ScrollbarSize", tostring(scrollbarSizeVertical), true)
        reaper.SetExtState("PresetManager", "ScrollbarSizeVertical", tostring(scrollbarSizeVertical), true)
        reaper.SetExtState("PresetManager", "ScrollbarSizeHorizontal", tostring(scrollbarSizeHorizontal), true)
    end
    if settings.scrollbarSizeVertical then
        scrollbarSizeVertical = settings.scrollbarSizeVertical
        reaper.SetExtState("PresetManager", "ScrollbarSizeVertical", tostring(scrollbarSizeVertical), true)
        reaper.SetExtState("PresetManager", "ScrollbarSize", tostring(scrollbarSizeVertical), true)
    end
    if settings.scrollbarSizeHorizontal then
        scrollbarSizeHorizontal = settings.scrollbarSizeHorizontal
        reaper.SetExtState("PresetManager", "ScrollbarSizeHorizontal", tostring(scrollbarSizeHorizontal), true)
    end
    if settings.windowWidth and settings.windowHeight then
        pendingWindowSize = { w = settings.windowWidth, h = settings.windowHeight }
    end
    if settings.windowX and settings.windowY then
        pendingWindowPos = { x = settings.windowX, y = settings.windowY }
    end
    if settings.foldersPanelWidth then
        local width = settings.foldersPanelWidth
        if width < 60 then width = 60 end
        if width > 400 then width = 400 end
        foldersPanelWidth = width
        reaper.SetExtState("PresetManager", "FoldersPanelWidth", tostring(foldersPanelWidth), true)
    end
    if settings.lockWindowPosition ~= nil then
        lockWindowPosition = settings.lockWindowPosition
        reaper.SetExtState("PresetManager", "LockWindowPosition", tostring(lockWindowPosition), true)
    end
    if settings.lockWindowSize ~= nil then
        lockWindowSize = settings.lockWindowSize
        reaper.SetExtState("PresetManager", "LockWindowSize", tostring(lockWindowSize), true)
    end
    if settings.sortMode then
        sortMode = settings.sortMode
        reaper.SetExtState("PresetManager", "SortMode", sortMode, true)
    end
    if settings.showColorFilters ~= nil then
        showColorFilters = settings.showColorFilters
        reaper.SetExtState("PresetManager", "ShowColorFilters", tostring(showColorFilters), true)
        if not showColorFilters then filterByColor = nil end
    end
    if settings.showTags ~= nil then
        showTags = settings.showTags
        reaper.SetExtState("PresetManager", "ShowTags", tostring(showTags), true)
    end
    if settings.showColorMarkers ~= nil then
        showColorMarkers = settings.showColorMarkers
        reaper.SetExtState("PresetManager", "ShowColorMarkers", tostring(showColorMarkers), true)
    end
    if settings.showFoldersPanel ~= nil then
        showFoldersPanel = settings.showFoldersPanel
        reaper.SetExtState("PresetManager", "ShowFoldersPanel", tostring(showFoldersPanel), true)
    end
end

local function navigateScriptPreset(direction)
    if #scriptPresetNames == 0 then return end
    currentScriptPresetIndex = currentScriptPresetIndex + direction
    if currentScriptPresetIndex < 1 then currentScriptPresetIndex = #scriptPresetNames end
    if currentScriptPresetIndex > #scriptPresetNames then currentScriptPresetIndex = 1 end
    local presetName = scriptPresetNames[currentScriptPresetIndex]
    if presetName and scriptPresets[presetName] then ApplySettings(scriptPresets[presetName]) end
end

local THEME_COLOR_COUNT = 25

local function applyTheme()
    local t = theme
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), t.WindowBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), t.Text)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), t.TextDisabled)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), t.FrameBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), t.FrameBgHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), t.FrameBgActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), t.TitleBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), t.TitleBgActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), t.Button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), t.ButtonHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), t.ButtonActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), t.CheckMark)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(), t.ScrollbarBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(), t.ScrollbarGrab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(), t.ScrollbarGrabHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(), t.ScrollbarGrabActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), t.SliderGrab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), t.SliderGrabActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), t.Header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), t.HeaderHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), t.HeaderActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), t.Separator)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), t.PopupBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(), t.MenuBarBg or t.TitleBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), t.DragDropTarget)
    return THEME_COLOR_COUNT
end

local function popTheme(count)
    if count > 0 then reaper.ImGui_PopStyleColor(ctx, count) end
end

local function LoadColorMarkers()
    colorMarkers = {}
    local f = io.open(colorMarkerFile, "r")
    if f then
        for line in f:lines() do
            local name, color = line:match("^(.+)|(%d+)$")
            if name and color then colorMarkers[name] = tonumber(color) end
        end
        f:close()
    end
    invalidatePresetViewCache()
end

local function SaveColorMarkers()
    local f = io.open(colorMarkerFile, "w")
    if f then
        for name, color in pairs(colorMarkers) do f:write(name .. "|" .. tostring(color) .. "\n") end
        f:close()
    end
end

local function setColorMarker(presetName, color)
    if color then colorMarkers[presetName] = color else colorMarkers[presetName] = nil end
    SaveColorMarkers()
    invalidatePresetViewCache()
end

local function getColorMarker(presetName) return colorMarkers[presetName] end

local function LoadTags()
    tags = {}
    local f = io.open(tag_file, "r")
    if f then
        for line in f:lines() do if line ~= "" then table.insert(tags, line) end end
        f:close()
    end
end

local function SaveTags()
    local f = io.open(tag_file, "w")
    if f then for _, t in ipairs(tags) do f:write(t .. "\n") end f:close() end
end

local function LoadTooltipTags()
    tooltipTags = {}
    local f = io.open(tooltip_tag_file, "r")
    if f then
        for line in f:lines() do if line ~= "" then table.insert(tooltipTags, line) end end
        f:close()
    end
end

local function SaveTooltipTags()
    local f = io.open(tooltip_tag_file, "w")
    if f then for _, t in ipairs(tooltipTags) do f:write(t .. "\n") end f:close() end
end

local function LoadPresetSaveTags()
    presetSaveTags = {}
    local f = io.open(preset_save_tag_file, "r")
    if f then
        for line in f:lines() do if line ~= "" then table.insert(presetSaveTags, line) end end
        f:close()
    end
end

local function SavePresetSaveTags()
    local f = io.open(preset_save_tag_file, "w")
    if f then for _, t in ipairs(presetSaveTags) do f:write(t .. "\n") end f:close() end
end

local function saveSearchAsTag()
    if searchQuery ~= "" then
        local exists = false
        for _, t in ipairs(tags) do if t == searchQuery then exists = true break end end
        if not exists then table.insert(tags, searchQuery) SaveTags() end
    end
end

local function getActivePresetName()
    if not track or not fxnum then return "" end
    local retval, presetname = reaper.TrackFX_GetPreset(track, fxnum, "")
    if retval then return presetname end
    return ""
end

local function getActivePresetIndex()
    if activePresetName == "" then return 0 end
    for i, preset in ipairs(presetList) do if preset.name == activePresetName then return i end end
    return 0
end

local function findFilteredPosition(originalIndex)
    for i, mapIdx in ipairs(currentIndexMap) do if mapIdx == originalIndex then return i end end
    return 0
end

local function getFileModTime(filepath)
    if not filepath or filepath == "" then return 0 end
    if not reaper.file_exists(filepath) then return 0 end
    local f = io.open(filepath, "rb")
    if f then
        local size = f:seek("end") or 0
        f:close()
        return size
    end
    return 0
end

local function loadPresets(tr, fx)
    if not tr then return end
    presetList = {}
    presetFileExt = nil
    local customFile, nativeFile = getPresetFiles(tr, fx)
    presetFile = customFile
    nativePresetFile = nativeFile
    local file = io.open(presetFile, "r")
    if not file and nativeFile and nativeFile ~= "" and reaper.file_exists(nativeFile) then
        if copyPresetFile(nativeFile, customFile) then
            file = io.open(presetFile, "r")
        end
    end
    if not file and nativeFile and nativeFile ~= "" then
        presetFile = nativeFile
        file = io.open(presetFile, "r")
    end
    if not file then
        lastPresetCount = 0
        lastPresetFileTime = 0
        return
    end

    local content = file:read("*all")
    file:close()
    syncCustomPresetFileToNative()

    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
    end

    local currentPreset = nil
    for i = 1, #lines do
        local line = lines[i]
        if line:match("^Ext=") then
            presetFileExt = line:sub(5)
        elseif line:match("^%[Preset%d+%]") then
            if currentPreset and currentPreset.name then
                table.insert(presetList, currentPreset)
            end
            currentPreset = { data = {}, tooltip = "" }
        elseif currentPreset then
            local name = line:match("^Name=(.+)$")
            local len = line:match("^Len=(.+)$")
            local tooltip = line:match("^Tooltip=(.*)$")
            if name then
                currentPreset.name = name
                currentPreset.nameLower = name:lower()
            elseif len then
                currentPreset.len = len
            elseif tooltip then
                currentPreset.tooltip = tooltip
                currentPreset.tooltipLower = tooltip:lower()
            elseif line:match("^Data") then
                table.insert(currentPreset.data, line)
            end
        end
    end
    if currentPreset and currentPreset.name then
        table.insert(presetList, currentPreset)
    end

    for _, preset in ipairs(presetList) do
        if not preset.nameLower and preset.name then preset.nameLower = preset.name:lower() end
        if not preset.tooltipLower then preset.tooltipLower = (preset.tooltip or ""):lower() end
    end
    lastPresetCount = #presetList
    lastPresetFileTime = getFileModTime(presetFile)
    activePresetName = getActivePresetName()
    invalidatePresetViewCache()
end

local function savePresets()
    if not presetFile or presetFile == "" then return false end
    local file = io.open(presetFile, "w")
    if not file then return false end

    file:write("[General]\n")
    if presetFileExt then
        file:write("Ext=" .. presetFileExt .. "\n")
    end
    file:write("NbPresets=" .. tostring(#presetList) .. "\n\n")

    for i, preset in ipairs(presetList) do
        if preset.name and preset.data and preset.len then
            file:write("[Preset" .. tostring(i - 1) .. "]\n")
            for _, dataLine in ipairs(preset.data) do
                file:write(dataLine .. "\n")
            end
            file:write("Len=" .. preset.len .. "\n")
            file:write("Name=" .. preset.name .. "\n")
            if preset.tooltip and preset.tooltip ~= "" then
                file:write("Tooltip=" .. preset.tooltip .. "\n")
            end
            file:write("\n")
        end
    end

    file:close()
    syncCustomPresetFileToNative()
    lastPresetCount = #presetList
    lastPresetFileTime = getFileModTime(presetFile)
    invalidatePresetViewCache()
    return true
end

local function checkForExternalPresetChanges()
    if not presetFile or presetFile == "" or not track or not fxnum then return end
    local now = reaper.time_precise()
    if now < nextExternalCheckTime then return end
    nextExternalCheckTime = now + 0.4
    local currentFileTime = getFileModTime(presetFile)
    if currentFileTime ~= lastPresetFileTime then
        local oldPresetNames = {}
        for _, preset in ipairs(presetList) do
            oldPresetNames[preset.name] = true
        end

        loadPresets(track, fxnum)

        if currentFolder then
            local newCount = 0
            for _, preset in ipairs(presetList) do
                if not oldPresetNames[preset.name] then
                    setPresetFolder(preset.name, currentFolder)
                    newCount = newCount + 1
                end
            end
            if newCount > 0 then
                showFeedback(newCount .. " preset(s) added to: " .. currentFolder, 0x44FF44FF)
            else
                showFeedback("Presets updated", 0x44FF44FF)
            end
        else
            showFeedback("Presets updated", 0x44FF44FF)
        end
    end
end

local refreshData

local function reopenFXUIFast(tr, fx)
    local targetTrack = tr or track
    local targetFx = fx
    if targetFx == nil then targetFx = fxnum end
    if not targetTrack or targetFx == nil then return false end

    local hadFloating = reaper.TrackFX_GetFloatingWindow(targetTrack, targetFx) ~= nil
    local hadChainOpen = false
    if reaper.TrackFX_GetOpen then
        hadChainOpen = reaper.TrackFX_GetOpen(targetTrack, targetFx)
    end

    if hadFloating then
        reaper.TrackFX_Show(targetTrack, targetFx, 2)
        reaper.TrackFX_Show(targetTrack, targetFx, 3)
        return true
    end
    if hadChainOpen then
        reaper.TrackFX_Show(targetTrack, targetFx, 0)
        reaper.TrackFX_Show(targetTrack, targetFx, 1)
        return true
    end
    return false
end

local function refreshFX(tr, fx)
    local targetTrack = tr or track
    local targetFx = fx
    if targetFx == nil then targetFx = fxnum end
    if not targetTrack or targetFx == nil then return false end

    local hadFloating = reaper.TrackFX_GetFloatingWindow(targetTrack, targetFx) ~= nil
    local hadChainOpen = false
    if reaper.TrackFX_GetOpen then
        hadChainOpen = reaper.TrackFX_GetOpen(targetTrack, targetFx)
    end

    if reaper.TrackFX_SetOffline then
        local wasOffline = false
        if reaper.TrackFX_GetOffline then
            wasOffline = reaper.TrackFX_GetOffline(targetTrack, targetFx)
        end
        if not wasOffline then
            reaper.TrackFX_SetOffline(targetTrack, targetFx, true)
            reaper.TrackFX_SetOffline(targetTrack, targetFx, false)
        end
    else
        local wasEnabled = reaper.TrackFX_GetEnabled(targetTrack, targetFx)
        reaper.TrackFX_SetEnabled(targetTrack, targetFx, false)
        reaper.TrackFX_SetEnabled(targetTrack, targetFx, true)
        if not wasEnabled then
            reaper.TrackFX_SetEnabled(targetTrack, targetFx, false)
        end
    end

    if hadFloating then
        reaper.TrackFX_Show(targetTrack, targetFx, 3)
    elseif hadChainOpen then
        reaper.TrackFX_Show(targetTrack, targetFx, 1)
    end
    return true
end

local function trackFromNumber(tracknum)
    if tracknum == 0 then
        return reaper.GetMasterTrack(0)
    elseif tracknum > 0 then
        return reaper.GetTrack(0, tracknum - 1)
    end
    return nil
end

local function getFocusedTrackFX()
    local retval, tracknum, _, focusedFx = reaper.GetFocusedFX2()
    if retval == 0 or (retval & 1) ~= 1 then return nil, nil end

    local tr = trackFromNumber(tracknum)
    if not tr then return nil, nil end
    return tr, focusedFx
end

local function getVisibleFXOnTrack(tr)
    if not tr then return nil end
    if reaper.TrackFX_GetChainVisible then
        local visibleFx = reaper.TrackFX_GetChainVisible(tr)
        if visibleFx and visibleFx >= 0 then
            return visibleFx
        end
    end
    local fxCount = reaper.TrackFX_GetCount(tr)
    for i = 0, fxCount - 1 do
        if reaper.TrackFX_GetFloatingWindow(tr, i) ~= nil then
            return i
        end
    end
    return nil
end

local function resolveActiveTrackFX(includeStoredFallback)
    local tr, fx = getFocusedTrackFX()
    if tr and fx ~= nil then return tr, fx end

    if includeStoredFallback and track and fxnum ~= nil and reaper.ValidatePtr2(0, track, "MediaTrack*") then
        local fxCount = reaper.TrackFX_GetCount(track)
        if fxnum >= 0 and fxnum < fxCount then
            return track, fxnum
        end
    end

    local selectedTrack = reaper.GetSelectedTrack(0, 0)
    local selectedFx = getVisibleFXOnTrack(selectedTrack)
    if selectedTrack and selectedFx ~= nil then
        return selectedTrack, selectedFx
    end

    local masterTrack = reaper.GetMasterTrack(0)
    local masterFx = getVisibleFXOnTrack(masterTrack)
    if masterTrack and masterFx ~= nil then
        return masterTrack, masterFx
    end

    return nil, nil
end

local function restartFocusedFX()
    local tr, fx = resolveActiveTrackFX(true)
    if not tr or fx == nil then
        showFeedback("No active track FX", 0x6666FFFF)
        return false
    end

    if refreshFX(tr, fx) then
        track = tr
        fxnum = fx
        showFeedback("Active FX restarted", 0x44FF44FF)
        return true
    end
    return false
end

local function switchToPreset(index)
    if track and fxnum and presetList[index] then
        syncCustomPresetFileToNative()
        reaper.TrackFX_SetPreset(track, fxnum, presetList[index].name)
        currentPresetIndex = index
        activePresetName = presetList[index].name
        selectedPresets = {}
        selectedPresets[index] = true
    end
end

refreshData = function()
    LoadTags() LoadTooltipTags() LoadPresetSaveTags() LoadColorMarkers()
    LoadScriptPresets() LoadAllFXFolders() LoadAllPresetFolders()
    if currentFXName ~= "" then
        LoadFoldersForFX(currentFXName)
        LoadPresetFoldersForFX(currentFXName)
    else
        folders = {}
        presetFolders = {}
    end
    if track and fxnum then loadPresets(track, fxnum) end
    selectedPresets = {}
end

local function openRenameModal(index)
    renameState.open = true
    renameState.index = index
    renameState.input = presetList[index].name
end

local function openTooltipModal(index)
    tooltipState.open = true
    tooltipState.index = index
    tooltipState.input = presetList[index].tooltip or ""
end

local function openSavePresetModal()
    savePresetState.open = true
    savePresetState.input = ""
    savePresetState.autoFocus = true
end

local function saveNewPreset(presetName)
    if not track or not fxnum or presetName == "" then return false end
    local base64bytes = {['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,['J']=9,['K']=10,['L']=11,['M']=12,
                         ['N']=13,['O']=14,['P']=15,['Q']=16,['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,['Z']=25,
                         ['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,
                         ['n']=39,['o']=40,['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,['x']=49,['y']=50,['z']=51,
                         ['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['+']=62,['/']=63,['=']=nil}
    local function B64_to_HEX(data)
        local chars = {}
        local result = {}
        for dpos=0, #data-1, 4 do
            for char=1,4 do chars[char] = base64bytes[(string.sub(data,(dpos+char),(dpos+char)) or "=")] end
            if chars[3] and chars[4] then
                table.insert(result, string.format('%02X%02X%02X', (chars[1]<<2)+((chars[2]&0x30)>>4), ((chars[2]&0xf)<<4)+(chars[3]>>2), ((chars[3]&0x3)<<6)+chars[4]))
            elseif chars[3] then
                table.insert(result, string.format('%02X%02X', (chars[1]<<2)+((chars[2]&0x30)>>4), ((chars[2]&0xf)<<4)+(chars[3]>>2)))
            else
                table.insert(result, string.format('%02X', (chars[1]<<2)+((chars[2]&0x30)>>4)))
            end
        end
        return table.concat(result)
    end
    local function String_to_HEX(str)
        local VAL = {str:byte(1,-1)}
        return string.format(string.rep("%02X", #VAL), table.unpack(VAL))
    end
    local function FX_Chunk_to_HEX(FX_Type, FX_Chunk, Preset_Name)
        local Preset_Chunk = FX_Chunk:match("\n.*\n")
        if FX_Type=="JS" then
            Preset_Chunk = Preset_Chunk:gsub("\n", "")
            return String_to_HEX(Preset_Chunk..Preset_Name)
        end
        local Hex_TB = {}
        local init = 1
        for i=1, math.huge do
            local line = Preset_Chunk:match("\n.-\n", init)
            if not line then
                Hex_TB[i-1] = "00"..String_to_HEX(Preset_Name).."0010000000"
                break
            end
            init = init + #line - 1
            line = line:gsub("\n","")
            Hex_TB[i] = B64_to_HEX(line)
        end
        return table.concat(Hex_TB)
    end
    local function Get_CtrlSum(HEX)
        local Sum = 0
        for i=1, #HEX, 2 do Sum = Sum + tonumber(HEX:sub(i,i+1), 16) end
        return string.sub(string.format("%X", Sum), -2, -1)
    end
    local function Write_to_File(PresetFile, Preset_HEX, Preset_Name)
        local file, Nprsts
        if reaper.file_exists(PresetFile) then
            local ret_r
            ret_r, Nprsts = reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", PresetFile)
            Nprsts = math.tointeger(Nprsts)
            reaper.BR_Win32_WritePrivateProfileString("General", "NbPresets", math.tointeger(Nprsts+1), PresetFile)
        else
            Nprsts = 0
            file = io.open(PresetFile, "w")
            file:write("[General]\nNbPresets="..Nprsts+1)
            file:close()
        end
        file = io.open(PresetFile, "r+")
        file:seek("end")
        file:write("\n[Preset"..Nprsts.."]")
        local Len = #Preset_HEX
        local s = 1
        for i=1, math.ceil(Len/32768) do
            local Ndata
            if i==1 then Ndata = "\nData=" else Ndata = "\nData_".. i-1 .."=" end
            local Data = Preset_HEX:sub(s, s+32767)
            local Sum = Get_CtrlSum(Data)
            file:write(Ndata, Data, Sum)
            s = s+32768
        end
        file:write("\nName=".. Preset_Name .."\nLen=".. Len//2 .."\n")
        file:close()
    end
    local function Get_FX_Data(tr, fx)
        local fx_cnt = reaper.TrackFX_GetCount(tr)
        if fx_cnt==0 or fx>fx_cnt-1 then return end
        local ret, Track_Chunk = reaper.GetTrackStateChunk(tr,"",false)
        local s, e = Track_Chunk:find("<FXCHAIN")
        if not s then return end
        for i=1, fx+1 do
            s, e = Track_Chunk:find("<%u+%s.->", e)
            if not s then return end
        end
        local FX_Type = string.match(Track_Chunk:sub(s+1,s+3), "%u+")
        if not(FX_Type=="VST" or FX_Type=="JS") then return end
        local FX_Chunk = Track_Chunk:match("%b<>", s)
        local PresetFile = reaper.TrackFX_GetUserPresetFilename(tr, fx, "")
        return FX_Type, FX_Chunk, PresetFile
    end
    local FX_Type, FX_Chunk = Get_FX_Data(track, fxnum)
    local PresetFile, NativePresetFile = getPresetFiles(track, fxnum)
    if FX_Chunk and PresetFile then
        local Preset_HEX = FX_Chunk_to_HEX(FX_Type, FX_Chunk, presetName)
        Write_to_File(PresetFile, Preset_HEX, presetName)
        presetFile = PresetFile
        nativePresetFile = NativePresetFile
        syncCustomPresetFileToNative()
        reaper.TrackFX_SetPreset(track, fxnum, presetName)
        loadPresets(track, fxnum)
        activePresetName = presetName
        if currentFolder then
            setPresetFolder(presetName, currentFolder)
        end
        return true
    end
    return false
end

local function getSelectedCount()
    local count = 0
    for _, v in pairs(selectedPresets) do if v then count = count + 1 end end
    return count
end

local function delete()
    local hasSelection = false
    local deleteIndices = {}
    for i, selected in pairs(selectedPresets) do
        if selected and presetList[i] then hasSelection = true table.insert(deleteIndices, i) end
    end
    if not hasSelection then return end
    if not presetFile or presetFile == "" then return end
    table.sort(deleteIndices, function(a, b) return a > b end)
    for _, index in ipairs(deleteIndices) do
        local presetName = presetList[index].name
        if colorMarkers[presetName] then colorMarkers[presetName] = nil end
        if presetFolders[presetName] then presetFolders[presetName] = nil end
        table.remove(presetList, index)
    end
    SaveColorMarkers()
    SavePresetFolders()
    selectedPresets = {}
    savePresets()
    reopenFXUIFast()
end

local function clearColorMarkersForSelectedPresets()
    local changed = false
    for i, selected in pairs(selectedPresets) do
        if selected and presetList[i] then
            local presetName = presetList[i].name
            if colorMarkers[presetName] then
                colorMarkers[presetName] = nil
                changed = true
            end
        end
    end
    if changed then SaveColorMarkers() end
end

local function clearColorMarkersInActiveFolder()
    if not currentFolder or currentFolder == "" then return end
    local changed = false
    for _, preset in ipairs(presetList) do
        local presetName = preset.name
        if presetFolders[presetName] == currentFolder and colorMarkers[presetName] then
            colorMarkers[presetName] = nil
            changed = true
        end
    end
    if changed then SaveColorMarkers() end
end

local function navigatePreset(direction)
    if #currentFilteredList == 0 then return end
    local currentOriginalIndex = getActivePresetIndex()
    local currentFilteredPos = 0
    if currentOriginalIndex > 0 then currentFilteredPos = findFilteredPosition(currentOriginalIndex) end
    if currentFilteredPos == 0 then
        if direction > 0 then currentFilteredPos = 0 else currentFilteredPos = #currentFilteredList + 1 end
    end
    local newFilteredPos = currentFilteredPos + direction
    if newFilteredPos < 1 then newFilteredPos = 1 end
    if newFilteredPos > #currentFilteredList then newFilteredPos = #currentFilteredList end
    if newFilteredPos ~= currentFilteredPos and newFilteredPos >= 1 and newFilteredPos <= #currentFilteredList then
        local newOriginalIndex = currentIndexMap[newFilteredPos]
        if newOriginalIndex then switchToPreset(newOriginalIndex) end
    end
end

function getLastTouchFX()
    local tr, fx = resolveActiveTrackFX(false)
    if tr and fx ~= nil then
        local _, fx_name = reaper.TrackFX_GetFXName(tr, fx, "")
        local _, track_name = reaper.GetTrackName(tr)
        return tr, fx, fx_name, track_name
    end
    return nil, nil, nil, nil
end

local function checkScriptPresetHotkeys(anyPopupOpen)
    if waitingForHotkey or scriptPresetsOpen then return end
    if anyPopupOpen then return end
    if reaper.ImGui_IsAnyItemActive(ctx) then return end
    if reaper.ImGui_IsAnyItemFocused(ctx) then return end
    local ctrlDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
    local altDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
    local shiftDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
    for presetName, hotkey in pairs(scriptPresetHotkeys) do
        if hotkey and hotkey.key and hotkey.key ~= 0 then
            if (hotkey.ctrl == ctrlDown) and (hotkey.alt == altDown) and (hotkey.shift == shiftDown) then
                for imguiKey, vk in pairs(imguiKeyMap) do
                    if vk == hotkey.key and reaper.ImGui_IsKeyPressed(ctx, imguiKey, false) then
                        if scriptPresets[presetName] then ApplySettings(scriptPresets[presetName]) end
                        return
                    end
                end
            end
        end
    end
end

local function keyboard_shortcuts()
    shift = reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Shift()
    ctrl = reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Ctrl()
    alt = reaper.ImGui_GetKeyMods(ctx) == reaper.ImGui_Mod_Alt()

    -- Escape is reserved for closing the script, including while a popup is open.
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape(), false) then
        appearance.closeRequested = true
        return shift, ctrl, alt
    end

    local anyPopupOpen = reaper.ImGui_IsPopupOpen(ctx, "", reaper.ImGui_PopupFlags_AnyPopupId() + reaper.ImGui_PopupFlags_AnyPopupLevel())
    checkScriptPresetHotkeys(anyPopupOpen)
    if not anyPopupOpen and not scriptPresetsOpen and not waitingForHotkey then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Delete(), false) then
            delete()
        end
        if ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z(), false) then reaper.Undo_DoUndo2(0) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F1(), false) then
            showMenuBar = not showMenuBar
            reaper.SetExtState("PresetManager", "ShowMenuBar", tostring(showMenuBar), true)
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F2(), false) then
            if selectedFolderIndex then
                openFolderRenameModal(selectedFolderIndex)
            else
                local selectedIndex = nil
                for i, selected in pairs(selectedPresets) do if selected then selectedIndex = i break end end
                if selectedIndex then openRenameModal(selectedIndex) end
            end
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F3(), false) then
            showTooltipsInline = not showTooltipsInline
            reaper.SetExtState("PresetManager", "ShowTooltipsInline", tostring(showTooltipsInline), true)
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F5(), false) then
            restartFocusedFX()
            refreshData()
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4(), false) then
            saveSearchAsTag()
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Tab(), false) then
            showFoldersPanel = not showFoldersPanel
            reaper.SetExtState("PresetManager", "ShowFoldersPanel", tostring(showFoldersPanel), true)
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), false) then navigatePreset(-1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), false) then navigatePreset(1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false) then navigateScriptPreset(-1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false) then navigateScriptPreset(1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space(), false) then reaper.Main_OnCommand(40044, 0) end
        if reaper.ImGui_IsMouseClicked(ctx, 2) then navigateScriptPreset(1) end
    end
    return shift, ctrl, alt
end

local function getFilteredPresets()
    local cacheSignature = table.concat({
        tostring(filterCacheVersion),
        searchQuery,
        tostring(filterByColor or ""),
        tostring(currentFolder or ""),
        sortMode
    }, "\31")
    if filteredCache.signature == cacheSignature then
        currentFilteredList = filteredCache.presets
        currentIndexMap = filteredCache.indexMap
        return currentFilteredList, currentIndexMap, cacheSignature
    end

    local filtered = {}
    local queryLower = searchQuery:lower()
    local searchActive = (searchQuery ~= "")
    for i, preset in ipairs(presetList) do
        local presetColor = colorMarkers[preset.name]
        if filterByColor and presetColor ~= filterByColor then goto continue end
        if currentFolder then
            local presetFolder = presetFolders[preset.name]
            if presetFolder ~= currentFolder then goto continue end
        end
        if searchActive then
            local nameLower = preset.nameLower or preset.name:lower()
            local tooltipLower = preset.tooltipLower or (preset.tooltip or ""):lower()
            local nameMatch = nameLower:find(queryLower, 1, true)
            local tooltipMatch = tooltipLower:find(queryLower, 1, true)
            if not (nameMatch or tooltipMatch) then goto continue end
        end
        table.insert(filtered, { preset = preset, originalIndex = i })
        ::continue::
    end
    if sortMode == "az" then
        table.sort(filtered, function(a, b)
            local aName = a.preset.nameLower or a.preset.name:lower()
            local bName = b.preset.nameLower or b.preset.name:lower()
            return aName < bName
        end)
    elseif sortMode == "colors" then
        table.sort(filtered, function(a, b)
            local aColor = colorMarkers[a.preset.name]
            local bColor = colorMarkers[b.preset.name]
            local aPriority = aColor and (colorPriority[aColor] or 50) or 100
            local bPriority = bColor and (colorPriority[bColor] or 50) or 100
            if aPriority ~= bPriority then return aPriority < bPriority end
            local aName = a.preset.nameLower or a.preset.name:lower()
            local bName = b.preset.nameLower or b.preset.name:lower()
            return aName < bName
        end)
    elseif sortMode == "tooltips_az" then
        table.sort(filtered, function(a, b)
            local aTooltip = a.preset.tooltip or ""
            local bTooltip = b.preset.tooltip or ""
            if aTooltip == "" and bTooltip ~= "" then return false end
            if aTooltip ~= "" and bTooltip == "" then return true end
            local aTooltipLower = a.preset.tooltipLower or aTooltip:lower()
            local bTooltipLower = b.preset.tooltipLower or bTooltip:lower()
            if aTooltipLower ~= bTooltipLower then return aTooltipLower < bTooltipLower end
            local aName = a.preset.nameLower or a.preset.name:lower()
            local bName = b.preset.nameLower or b.preset.name:lower()
            return aName < bName
        end)
    end
    local resultPresets, resultIndexMap = {}, {}
    for _, item in ipairs(filtered) do
        table.insert(resultPresets, item.preset)
        table.insert(resultIndexMap, item.originalIndex)
    end
    currentFilteredList = resultPresets
    currentIndexMap = resultIndexMap
    filteredCache.signature = cacheSignature
    filteredCache.presets = resultPresets
    filteredCache.indexMap = resultIndexMap
    return resultPresets, resultIndexMap, cacheSignature
end

local function calculateMaxTooltipWidth(filteredPresets, cacheSignature)
    local tooltipSignature = table.concat({ cacheSignature or "", tostring(showTooltipsInline) }, "\31")
    if tooltipWidthCache.signature == tooltipSignature then
        return tooltipWidthCache.width
    end
    local maxWidth = 0
    for _, preset in ipairs(filteredPresets) do
        if preset.tooltip and preset.tooltip ~= "" then
            local w = reaper.ImGui_CalcTextSize(ctx, preset.tooltip)
            if w > maxWidth then maxWidth = w end
        end
    end
    tooltipWidthCache.signature = tooltipSignature
    tooltipWidthCache.width = maxWidth
    return maxWidth
end

local function formatPresetName(preset, displayIndex)
    if showNumbers then return tostring(displayIndex) .. ". " .. preset.name end
    return preset.name
end

local function drawColorPickerMenu(presetName)
    reaper.ImGui_Separator(ctx)
    for _, colorInfo in ipairs(availableColors) do
        local isSelected = (colorMarkers[presetName] == colorInfo.color)
        if colorInfo.color then
            local cursorX, cursorY = reaper.ImGui_GetCursorScreenPos(ctx)
            local drawList = reaper.ImGui_GetWindowDrawList(ctx)
            reaper.ImGui_DrawList_AddCircleFilled(drawList, cursorX + 8, cursorY + 7, 5, colorInfo.color)
            reaper.ImGui_Dummy(ctx, 16, 0)
            reaper.ImGui_SameLine(ctx)
        else
            reaper.ImGui_Dummy(ctx, 16, 0)
            reaper.ImGui_SameLine(ctx)
        end
        if reaper.ImGui_MenuItem(ctx, colorInfo.name, nil, isSelected) then setColorMarker(presetName, colorInfo.color) end
    end
end

local rangeStartIndex = nil

local function drawPresetItem(preset, originalIndex, displayIndex, itemWidth, maxTooltipWidth)
    local selected = selectedPresets[originalIndex]
    local isActive = (preset.name == activePresetName)
    local markerColor = getColorMarker(preset.name)
    local hasTooltip = preset.tooltip and preset.tooltip ~= ""

    reaper.ImGui_PushID(ctx, originalIndex)

    local pushedColor = false
    if isActive and theme.ActivePreset then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.ActivePreset)
        pushedColor = true
    end

    local displayName = formatPresetName(preset, displayIndex)
    local clicked = false
    if itemWidth then
        clicked = reaper.ImGui_Selectable(ctx, displayName, selected, 0, itemWidth, 0)
    else
        clicked = reaper.ImGui_Selectable(ctx, displayName, selected)
    end

    local itemMinX, itemMinY = reaper.ImGui_GetItemRectMin(ctx)
    local itemMaxX, itemMaxY = reaper.ImGui_GetItemRectMax(ctx)
    local itemCenterY = (itemMinY + itemMaxY) / 2
    local drawList = reaper.ImGui_GetWindowDrawList(ctx)

    local fixedRightEdge = itemMaxX - TOOLTIP_RIGHT_MARGIN

    if showColorMarkers and markerColor then
        local dotX = itemMaxX - 12
        reaper.ImGui_DrawList_AddCircleFilled(drawList, dotX, itemCenterY, 4, markerColor)
    end

    if showTooltipsInline and hasTooltip and maxTooltipWidth > 0 then
        local tooltipColor = theme.TooltipText or 0x888888FF
        local tooltipText = preset.tooltip
        local tooltipStartX = fixedRightEdge - maxTooltipWidth - 4
        local nameWidth = reaper.ImGui_CalcTextSize(ctx, displayName)
        local nameRightBound = itemMinX + nameWidth + 10
        if tooltipStartX > nameRightBound then
            reaper.ImGui_DrawList_AddText(drawList, tooltipStartX, itemMinY + 2, tooltipColor, tooltipText)
        else
            local availableWidth = fixedRightEdge - nameRightBound - 4
            if availableWidth > 30 then
                local tooltipW = reaper.ImGui_CalcTextSize(ctx, tooltipText)
                if tooltipW > availableWidth then
                    local chars = math.floor(availableWidth / 7)
                    if chars > 3 then tooltipText = tooltipText:sub(1, chars) .. "..."
                    else tooltipText = "" end
                end
                if tooltipText ~= "" then
                    local textX = fixedRightEdge - maxTooltipWidth - 4
                    if textX < nameRightBound then textX = nameRightBound end
                    reaper.ImGui_DrawList_AddText(drawList, textX, itemMinY + 2, tooltipColor, tooltipText)
                end
            end
        end
    end

    if clicked then
        if shift and rangeStartIndex then
            local startIndex = math.min(rangeStartIndex, originalIndex)
            local endIndex = math.max(rangeStartIndex, originalIndex)
            selectedPresets = {}
            for j = startIndex, endIndex do selectedPresets[j] = true end
        elseif ctrl then
            if selectedPresets[originalIndex] then
                selectedPresets[originalIndex] = nil
            else
                selectedPresets[originalIndex] = true
            end
            rangeStartIndex = originalIndex
        elseif alt then
            selectedPresets = {}
        else
            selectedPresets = {}
            selectedPresets[originalIndex] = true
            rangeStartIndex = originalIndex
            currentPresetIndex = originalIndex
        end
        if autoSwitchPreset and not ctrl and not shift then
            switchToPreset(originalIndex)
        end
    end

    if pushedColor then reaper.ImGui_PopStyleColor(ctx, 1) end

    if reaper.ImGui_BeginPopupContextItem(ctx) then
        if reaper.ImGui_MenuItem(ctx, "Rename") then openRenameModal(originalIndex) end
        if reaper.ImGui_MenuItem(ctx, "Delete") then
            if not selectedPresets[originalIndex] then
                selectedPresets = {}
                selectedPresets[originalIndex] = true
            end
            delete()
        end
        if reaper.ImGui_MenuItem(ctx, "Edit Tooltip") then openTooltipModal(originalIndex) end
        drawColorPickerMenu(preset.name)
        reaper.ImGui_EndPopup(ctx)
    end

    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
        dragSelectedPresets = {}
        local selCount = getSelectedCount()

        if selCount > 1 and selectedPresets[originalIndex] then
            for idx, v in pairs(selectedPresets) do
                if v and presetList[idx] then
                    dragSelectedPresets[idx] = true
                end
            end
            dragPresetName = preset.name
            if searchQuery == "" and filterByColor == nil and sortMode == "none" then
                reaper.ImGui_SetDragDropPayload(ctx, 'reorder_multi', tostring(originalIndex))
            else
                reaper.ImGui_SetDragDropPayload(ctx, "DND_PRESET_MULTI", "m")
            end
            reaper.ImGui_Text(ctx, selCount .. " presets selected")
        else
            dragSelectedPresets = {}
            dragPresetName = preset.name
            if searchQuery == "" and filterByColor == nil and sortMode == "none" then
                reaper.ImGui_SetDragDropPayload(ctx, 'reorder', tostring(originalIndex))
            else
                reaper.ImGui_SetDragDropPayload(ctx, "DND_PRESET", "p")
            end
            reaper.ImGui_Text(ctx, preset.name)
        end
        reaper.ImGui_EndDragDropSource(ctx)
    end

    if searchQuery == "" and filterByColor == nil and sortMode == "none" then
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local retval, payload = reaper.ImGui_AcceptDragDropPayload(ctx, 'reorder')
            if retval then
                local fromIndex = tonumber(payload)
                local toIndex = originalIndex
                if fromIndex and toIndex and fromIndex ~= toIndex then
                    local movedPreset = table.remove(presetList, fromIndex)
                    table.insert(presetList, toIndex, movedPreset)
                    selectedPresets = {}
                    savePresets()
                    invalidatePresetViewCache()
                    showFeedback("Moved 1 preset", theme.FolderColor)
                end
            end

            local retval2, payload2 = reaper.ImGui_AcceptDragDropPayload(ctx, 'reorder_multi')
            if retval2 then
                local toIndex = originalIndex
                local selIndices = {}
                for idx, v in pairs(dragSelectedPresets) do
                    if v and presetList[idx] then table.insert(selIndices, idx) end
                end
                table.sort(selIndices)

                if #selIndices > 0 then
                    local movedPresets = {}
                    for _, idx in ipairs(selIndices) do
                        table.insert(movedPresets, presetList[idx])
                    end

                    local sortedDesc = {}
                    for _, idx in ipairs(selIndices) do table.insert(sortedDesc, idx) end
                    table.sort(sortedDesc, function(a, b) return a > b end)

                    local adjustedTo = toIndex
                    for _, idx in ipairs(sortedDesc) do
                        if idx < toIndex then adjustedTo = adjustedTo - 1 end
                        table.remove(presetList, idx)
                    end

                    if adjustedTo < 1 then adjustedTo = 1 end
                    if adjustedTo > #presetList + 1 then adjustedTo = #presetList + 1 end

                    for i, p in ipairs(movedPresets) do
                        table.insert(presetList, adjustedTo + i - 1, p)
                    end

                    selectedPresets = {}
                    dragSelectedPresets = {}
                    savePresets()
                    invalidatePresetViewCache()
                    showFeedback("Moved " .. #selIndices .. " presets", theme.FolderColor)
                end
            end

            reaper.ImGui_EndDragDropTarget(ctx)
        end
    end

    reaper.ImGui_PopID(ctx)
end

local function getPresetRowHeight()
    if reaper.ImGui_GetTextLineHeightWithSpacing then
        return reaper.ImGui_GetTextLineHeightWithSpacing(ctx) + 2
    end
    return 22
end

local function drawVerticalPresetList(filteredPresets, indexMap, cacheSignature)
    local totalPresets = #filteredPresets
    if totalPresets == 0 then return end
    local maxTooltipWidth = 0
    if showTooltipsInline then maxTooltipWidth = calculateMaxTooltipWidth(filteredPresets, cacheSignature) end

    local rowHeight = getPresetRowHeight()
    local scrollY = reaper.ImGui_GetScrollY(ctx)
    local windowH = reaper.ImGui_GetWindowHeight(ctx)
    local overscan = 6
    local firstVisible = math.floor(scrollY / rowHeight) + 1 - overscan
    if firstVisible < 1 then firstVisible = 1 end
    local visibleCount = math.ceil(windowH / rowHeight) + (overscan * 2)
    local lastVisible = firstVisible + visibleCount - 1
    if lastVisible > totalPresets then lastVisible = totalPresets end

    if firstVisible > 1 then
        reaper.ImGui_Dummy(ctx, 0, (firstVisible - 1) * rowHeight)
    end

    for displayIndex = firstVisible, lastVisible do
        local preset = filteredPresets[displayIndex]
        local originalIndex = indexMap and indexMap[displayIndex] or displayIndex
        drawPresetItem(preset, originalIndex, displayIndex, nil, maxTooltipWidth)
    end

    if lastVisible < totalPresets then
        reaper.ImGui_Dummy(ctx, 0, (totalPresets - lastVisible) * rowHeight)
    end
end

local function drawHorizontalPresetList(filteredPresets, indexMap, cacheSignature)
    local totalPresets = #filteredPresets
    if totalPresets == 0 then return end
    local maxTooltipWidth = 0
    if showTooltipsInline then maxTooltipWidth = calculateMaxTooltipWidth(filteredPresets, cacheSignature) end
    local numColumns = math.ceil(totalPresets / rowsPerColumn)
    local rowHeight = getPresetRowHeight()
    local columnHeight = rowsPerColumn * rowHeight
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), scrollbarSizeHorizontal)
    local windowFlags = reaper.ImGui_WindowFlags_HorizontalScrollbar() + reaper.ImGui_WindowFlags_AlwaysHorizontalScrollbar()
    local _, availHeight = reaper.ImGui_GetContentRegionAvail(ctx)
    if BeginChild("HorizontalPresetList", 0, availHeight, false, windowFlags) then
        local scrollX = reaper.ImGui_GetScrollX(ctx)
        local windowW = reaper.ImGui_GetWindowWidth(ctx)
        local itemSpacingX = 6
        local columnSpan = columnWidth + itemSpacingX
        local overscanCols = 2
        local firstVisibleCol = math.floor(scrollX / columnSpan) + 1 - overscanCols
        if firstVisibleCol < 1 then firstVisibleCol = 1 end
        local visibleCols = math.ceil(windowW / columnSpan) + (overscanCols * 2)
        local lastVisibleCol = firstVisibleCol + visibleCols - 1
        if lastVisibleCol > numColumns then lastVisibleCol = numColumns end

        if reaper.ImGui_IsWindowHovered(ctx) then
            local wheelV = reaper.ImGui_GetMouseWheel(ctx)
            if wheelV ~= 0 then
                reaper.ImGui_SetScrollX(ctx, scrollX - wheelV * 50)
            end
        end
        for col = 1, numColumns do
            local startIdx = (col - 1) * rowsPerColumn + 1
            local endIdx = math.min(col * rowsPerColumn, totalPresets)
            if col > 1 then reaper.ImGui_SameLine(ctx) end
            if col < firstVisibleCol or col > lastVisibleCol then
                reaper.ImGui_Dummy(ctx, columnWidth, columnHeight)
            else
                reaper.ImGui_BeginGroup(ctx)
                for displayIndex = startIdx, endIdx do
                    local preset = filteredPresets[displayIndex]
                    local originalIndex = indexMap and indexMap[displayIndex] or displayIndex
                    drawPresetItem(preset, originalIndex, displayIndex, columnWidth, maxTooltipWidth)
                end
                reaper.ImGui_EndGroup(ctx)
            end
        end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx, 1)
end

local function drawFolderItem(folder, index)
    local isCurrentFolder = (currentFolder == folder)
    local isSelected = isCurrentFolder

    reaper.ImGui_PushID(ctx, "folder_" .. index)

    local pushedColor = false
    if isCurrentFolder then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.FolderColor)
        pushedColor = true
    end

    reaper.ImGui_Selectable(ctx, folder, isSelected)

    if pushedColor then reaper.ImGui_PopStyleColor(ctx) end

    if reaper.ImGui_IsItemClicked(ctx) then
        selectedFolderIndex = index
        currentFolder = folder
    end

    if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
        reaper.ImGui_SetDragDropPayload(ctx, "DND_FOLDER", tostring(index))
        reaper.ImGui_Text(ctx, "Move: " .. folder)
        reaper.ImGui_EndDragDropSource(ctx)
    end

    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local retval, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_FOLDER")
        if retval then
            local fromIndex = tonumber(payload)
            local toIndex = index
            if fromIndex and toIndex and fromIndex ~= toIndex then
                local movedFolder = table.remove(folders, fromIndex)
                table.insert(folders, toIndex, movedFolder)
                if currentFolder then
                    for i, f in ipairs(folders) do
                        if f == currentFolder then selectedFolderIndex = i break end
                    end
                end
                SaveFolders()
                showFeedback("Folder moved", theme.FolderColor)
            end
        end

        local retval2, payload2 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET")
        if retval2 and dragPresetName then
            setPresetFolder(dragPresetName, folder)
            showFeedback("1 preset to folder: " .. folder, theme.FolderColor)
            dragPresetName = nil
        end

        local retval3, payload3 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET_MULTI")
        if retval3 then
            local count = 0
            for idx, v in pairs(dragSelectedPresets) do
                if v and presetList[idx] then
                    setPresetFolder(presetList[idx].name, folder)
                    count = count + 1
                end
            end
            dragSelectedPresets = {}
            dragPresetName = nil
            showFeedback(count .. " presets to folder: " .. folder, theme.FolderColor)
        end

        local retval4, payload4 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder")
        if retval4 and dragPresetName then
            setPresetFolder(dragPresetName, folder)
            showFeedback("1 preset to folder: " .. folder, theme.FolderColor)
            dragPresetName = nil
        end

        local retval5, payload5 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder_multi")
        if retval5 then
            local count = 0
            for idx, v in pairs(dragSelectedPresets) do
                if v and presetList[idx] then
                    setPresetFolder(presetList[idx].name, folder)
                    count = count + 1
                end
            end
            dragSelectedPresets = {}
            dragPresetName = nil
            showFeedback(count .. " presets to folder: " .. folder, theme.FolderColor)
        end

        reaper.ImGui_EndDragDropTarget(ctx)
    end

    if reaper.ImGui_BeginPopupContextItem(ctx, folder .. "_ctx") then
        if reaper.ImGui_MenuItem(ctx, "Rename Folder") then openFolderRenameModal(index) end
        if reaper.ImGui_MenuItem(ctx, "Delete Folder") then deleteFolder(index) end
        reaper.ImGui_EndPopup(ctx)
    end

    reaper.ImGui_PopID(ctx)
end

local function drawSplitter()
    local splitterWidth = 6
    local cursorX, cursorY = reaper.ImGui_GetCursorScreenPos(ctx)
    local _, availH = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_InvisibleButton(ctx, "##splitter", splitterWidth, availH)
    local isHovered = reaper.ImGui_IsItemHovered(ctx)
    local isActive = reaper.ImGui_IsItemActive(ctx)
    if isHovered or isActive then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
    end
    if isActive then
        local mouseX, _ = reaper.ImGui_GetMousePos(ctx)
        if not isDraggingSplitter then
            isDraggingSplitter = true
            dragStartX = mouseX
            dragStartWidth = foldersPanelWidth
        else
            local delta = mouseX - dragStartX
            local newWidth = dragStartWidth + delta
            if newWidth < 60 then newWidth = 60 end
            if newWidth > 400 then newWidth = 400 end
            foldersPanelWidth = newWidth
            reaper.SetExtState("PresetManager", "FoldersPanelWidth", tostring(foldersPanelWidth), true)
        end
    else
        if isDraggingSplitter then
            isDraggingSplitter = false
            dragStartX = nil
            dragStartWidth = nil
        end
    end
    local drawList = reaper.ImGui_GetWindowDrawList(ctx)
    local splitterX = cursorX + splitterWidth / 2
    local lineColor = theme.Separator
    if isActive then
        lineColor = theme.SplitterActive
    elseif isHovered then
        lineColor = theme.SplitterHovered
    end
    reaper.ImGui_DrawList_AddLine(drawList, splitterX, cursorY, splitterX, cursorY + availH, lineColor, 2)
    reaper.ImGui_SameLine(ctx)
end

local function drawFoldersPanel()
    if not showFoldersPanel then return end

    if BeginChild("FoldersPanel", foldersPanelWidth, 0, false) then
        local isAllSelected = (currentFolder == nil)
        reaper.ImGui_PushID(ctx, "folder_all")

        local pushedColor = false
        if isAllSelected then
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.FolderColor)
            pushedColor = true
        end

        reaper.ImGui_Selectable(ctx, "All", isAllSelected)
        if reaper.ImGui_IsItemClicked(ctx) then
            selectedFolderIndex = nil
            currentFolder = nil
        end

        if pushedColor then reaper.ImGui_PopStyleColor(ctx) end

        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local retval, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET")
            if retval and dragPresetName then
                setPresetFolder(dragPresetName, nil)
                showFeedback("1 preset removed from folder", theme.FolderColor)
                dragPresetName = nil
            end

            local retval2, payload2 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET_MULTI")
            if retval2 then
                local count = 0
                for idx, v in pairs(dragSelectedPresets) do
                    if v and presetList[idx] then
                        setPresetFolder(presetList[idx].name, nil)
                        count = count + 1
                    end
                end
                dragSelectedPresets = {}
                dragPresetName = nil
                showFeedback(count .. " presets removed from folder", theme.FolderColor)
            end

            local retval3, payload3 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder")
            if retval3 and dragPresetName then
                setPresetFolder(dragPresetName, nil)
                showFeedback("1 preset removed from folder", theme.FolderColor)
                dragPresetName = nil
            end

            local retval4, payload4 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder_multi")
            if retval4 then
                local count = 0
                for idx, v in pairs(dragSelectedPresets) do
                    if v and presetList[idx] then
                        setPresetFolder(presetList[idx].name, nil)
                        count = count + 1
                    end
                end
                dragSelectedPresets = {}
                dragPresetName = nil
                showFeedback(count .. " presets removed from folder", theme.FolderColor)
            end

            reaper.ImGui_EndDragDropTarget(ctx)
        end

        reaper.ImGui_PopID(ctx)

        for i, folder in ipairs(folders) do
            drawFolderItem(folder, i)
        end

        reaper.ImGui_Spacing(ctx)
        if currentFXName ~= "" then
            if reaper.ImGui_Button(ctx, "+##addFolder", 20, 20) then
                openNewFolderModal()
            end
        end

        reaper.ImGui_EndChild(ctx)
    end

    reaper.ImGui_SameLine(ctx)
    drawSplitter()
end

local function drawRenameModal()
    if renameState.open then
        reaper.ImGui_SetNextWindowSize(ctx, 300, 0, reaper.ImGui_Cond_Always())
        reaper.ImGui_OpenPopup(ctx, "Rename Preset##modal")
        if reaper.ImGui_BeginPopupModal(ctx, "Rename Preset##modal", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            local input_width = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, input_width)
            local changed
            changed, renameState.input = reaper.ImGui_InputText(ctx, "##renameinput", renameState.input)
            if reaper.ImGui_Button(ctx, "OK") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                if renameState.input ~= "" then
                    local idx = renameState.index
                    local oldName = presetList[idx].name
                    presetList[idx].name = renameState.input
                    presetList[idx].nameLower = renameState.input:lower()
                    if colorMarkers[oldName] then colorMarkers[renameState.input] = colorMarkers[oldName] colorMarkers[oldName] = nil SaveColorMarkers() end
                    if presetFolders[oldName] then presetFolders[renameState.input] = presetFolders[oldName] presetFolders[oldName] = nil SavePresetFolders() end
                    if activePresetName == oldName then activePresetName = renameState.input end
                    savePresets() reopenFXUIFast()
                end
                renameState.open = false
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then renameState.open = false reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
    end
end

local function drawFolderRenameModal()
    if folderRenameState.open then
        reaper.ImGui_SetNextWindowSize(ctx, 250, 0, reaper.ImGui_Cond_Always())
        reaper.ImGui_OpenPopup(ctx, "Rename Folder##modal")
        if reaper.ImGui_BeginPopupModal(ctx, "Rename Folder##modal", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            local input_width = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, input_width)
            local changed
            changed, folderRenameState.input = reaper.ImGui_InputText(ctx, "##folderrenameinput", folderRenameState.input)
            if reaper.ImGui_Button(ctx, "OK") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                if folderRenameState.input ~= "" then renameFolder(folderRenameState.index, folderRenameState.input) end
                folderRenameState.open = false
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then folderRenameState.open = false reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
    end
end

local function drawNewFolderModal()
    if newFolderState.open then
        reaper.ImGui_SetNextWindowSize(ctx, 250, 0, reaper.ImGui_Cond_Always())
        reaper.ImGui_OpenPopup(ctx, "New Folder##modal")
        if reaper.ImGui_BeginPopupModal(ctx, "New Folder##modal", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            local input_width = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, input_width)
            local changed
            changed, newFolderState.input = reaper.ImGui_InputText(ctx, "##newfolderinput", newFolderState.input)
            if reaper.ImGui_Button(ctx, "Create") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                if newFolderState.input ~= "" then addFolder(newFolderState.input) end
                newFolderState.open = false
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then newFolderState.open = false reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
    end
end

local function drawTooltipModal()
    if tooltipState.open then
        reaper.ImGui_SetNextWindowSize(ctx, 350, 0, reaper.ImGui_Cond_Always())
        reaper.ImGui_OpenPopup(ctx, "Edit Tooltip##modal")
        if reaper.ImGui_BeginPopupModal(ctx, "Edit Tooltip##modal", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            local avail = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, avail - 30)
            local changed
            changed, tooltipState.input = reaper.ImGui_InputText(ctx, "##tooltipinput", tooltipState.input)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "+", 20, 20) then
                if tooltipState.input ~= "" then
                    for t in tooltipState.input:gmatch("[^/]+") do
                        t = t:gsub("^%s+", ""):gsub("%s+$", "")
                        local exists = false
                        for _, tt in ipairs(tooltipTags) do if tt == t then exists = true break end end
                        if not exists then table.insert(tooltipTags, t) end
                    end
                    SaveTooltipTags()
                end
            end
            if #tooltipTags > 0 then
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 2, 2)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 2, 2)
                local max_width = reaper.ImGui_GetContentRegionAvail(ctx)
                local cur_width, first_in_row, h_padding = 0, true, 2
                for i, t in ipairs(tooltipTags) do
                    local btn_w = reaper.ImGui_CalcTextSize(ctx, t)
                    local btn_size = btn_w + 10
                    if cur_width + btn_size > max_width then cur_width = 0 first_in_row = true end
                    if not first_in_row then reaper.ImGui_SameLine(ctx, 0, h_padding) end
                    if reaper.ImGui_Button(ctx, t .. "##tooltipTag" .. i) then
                        if tooltipState.input == "" then tooltipState.input = t
                        else tooltipState.input = tooltipState.input .. " / " .. t end
                    end
                    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseReleased(ctx, 1) then
                        table.remove(tooltipTags, i) SaveTooltipTags() break
                    end
                    cur_width = cur_width + btn_size + h_padding
                    first_in_row = false
                end
                reaper.ImGui_PopStyleVar(ctx, 2)
                reaper.ImGui_Separator(ctx)
            end
            if reaper.ImGui_Button(ctx, "OK") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                local idx = tooltipState.index
                presetList[idx].tooltip = tooltipState.input
                presetList[idx].tooltipLower = (tooltipState.input or ""):lower()
                savePresets()
                tooltipState.open = false
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then tooltipState.open = false reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
    end
end

local function drawSavePresetModal()
    if savePresetState.open then
        local popupTitle = (currentFolder and ("Save Preset (" .. currentFolder .. ")") or "Save Preset") .. "###SavePresetModal"
        reaper.ImGui_SetNextWindowSize(ctx, 350, 0, reaper.ImGui_Cond_Always())
        reaper.ImGui_OpenPopup(ctx, popupTitle)
        if reaper.ImGui_BeginPopupModal(ctx, popupTitle, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            local avail = reaper.ImGui_GetContentRegionAvail(ctx)
            local clearW = reaper.ImGui_CalcTextSize(ctx, "Clear") + 16
            local plusW = 20
            local spacing = 8
            reaper.ImGui_SetNextItemWidth(ctx, avail - clearW - plusW - spacing)
            if savePresetState.autoFocus then
                reaper.ImGui_SetKeyboardFocusHere(ctx)
                savePresetState.autoFocus = false
            end
            local changed
            changed, savePresetState.input = reaper.ImGui_InputText(ctx, "##savepresetinput", savePresetState.input)
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Clear##savepresetclear") then
                savePresetState.input = ""
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "+##savepresetaddtag", 20, 20) then
                if savePresetState.input ~= "" then
                    for t in savePresetState.input:gmatch("[^/]+") do
                        t = t:gsub("^%s+", ""):gsub("%s+$", "")
                        local exists = false
                        for _, tt in ipairs(presetSaveTags) do if tt == t then exists = true break end end
                        if not exists then table.insert(presetSaveTags, t) end
                    end
                    SavePresetSaveTags()
                end
            end
            if #presetSaveTags > 0 then
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 2, 2)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 2, 2)
                local max_width = reaper.ImGui_GetContentRegionAvail(ctx)
                local cur_width, first_in_row, h_padding = 0, true, 2
                for i, t in ipairs(presetSaveTags) do
                    local btn_w = reaper.ImGui_CalcTextSize(ctx, t)
                    local btn_size = btn_w + 10
                    if cur_width + btn_size > max_width then cur_width = 0 first_in_row = true end
                    if not first_in_row then reaper.ImGui_SameLine(ctx, 0, h_padding) end
                    if reaper.ImGui_Button(ctx, t .. "##presetSaveTag" .. i) then
                        if savePresetState.input == "" then savePresetState.input = t
                        else savePresetState.input = savePresetState.input .. " " .. t end
                    end
                    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseReleased(ctx, 1) then
                        table.remove(presetSaveTags, i) SavePresetSaveTags() break
                    end
                    cur_width = cur_width + btn_size + h_padding
                    first_in_row = false
                end
                reaper.ImGui_PopStyleVar(ctx, 2)
                reaper.ImGui_Separator(ctx)
            end
            if reaper.ImGui_Button(ctx, "Save") or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
                if savePresetState.input ~= "" then saveNewPreset(savePresetState.input) end
                savePresetState.open = false
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "Cancel") then savePresetState.open = false reaper.ImGui_CloseCurrentPopup(ctx) end
            reaper.ImGui_EndPopup(ctx)
        end
    end
end

function drawScriptPresetSetting(text, maskKey)
    local rowX = reaper.ImGui_GetCursorPosX(ctx)
    local availableWidth = reaper.ImGui_GetContentRegionAvail(ctx)
    local checkboxWidth = reaper.ImGui_GetFrameHeight(ctx)

    reaper.ImGui_BulletText(ctx, text)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, rowX + availableWidth - checkboxWidth)

    local changed
    changed, scriptPresetSaveMask[maskKey] = reaper.ImGui_Checkbox(ctx, "##saveSetting_" .. maskKey, scriptPresetSaveMask[maskKey])
end

local function drawScriptPresetsWindow()
    if not scriptPresetsOpen then return end
    reaper.ImGui_SetNextWindowSize(ctx, 450, 500, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), theme.WindowBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.Text)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), theme.FrameBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), theme.FrameBgHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), theme.FrameBgActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), theme.Button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), theme.ButtonHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), theme.ButtonActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), theme.Header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), theme.HeaderHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), theme.HeaderActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), theme.TitleBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), theme.TitleBgActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), theme.Separator)
    local visible, open = reaper.ImGui_Begin(ctx, "Script Presets###ScriptPresetsWindow", true)
    if visible then
        reaper.ImGui_Text(ctx, "Current Settings:")
        reaper.ImGui_Separator(ctx)
        drawScriptPresetSetting("Mode: " .. (horizontalMode and "Horizontal" or "Vertical"), "mode")
        drawScriptPresetSetting("Numbers: " .. (showNumbers and "Yes" or "No"), "numbers")
        drawScriptPresetSetting("Inline Tooltips: " .. (showTooltipsInline and "Yes" or "No"), "inlineTooltips")
        drawScriptPresetSetting("Rows/Column: " .. rowsPerColumn, "rowsPerColumn")
        drawScriptPresetSetting("Column Width: " .. columnWidth, "columnWidth")
        drawScriptPresetSetting("Scrollbar Vertical: " .. scrollbarSizeVertical, "scrollbarVertical")
        drawScriptPresetSetting("Scrollbar Horizontal: " .. scrollbarSizeHorizontal, "scrollbarHorizontal")
        drawScriptPresetSetting("Window Size: " .. math.floor(lastWindowW) .. "x" .. math.floor(lastWindowH), "windowSize")
        drawScriptPresetSetting("Window Pos: " .. math.floor(lastWindowX) .. "," .. math.floor(lastWindowY), "windowPosition")
        drawScriptPresetSetting("Folders Panel Width: " .. math.floor(foldersPanelWidth), "foldersPanelWidth")
        drawScriptPresetSetting("Tags: " .. (showTags and "Visible" or "Hidden"), "tags")
        drawScriptPresetSetting("Color Filters: " .. (showColorFilters and "Visible" or "Hidden"), "colorFilters")
        drawScriptPresetSetting("Color Markers: " .. (showColorMarkers and "Visible" or "Hidden"), "colorMarkers")
        drawScriptPresetSetting("Folders Panel: " .. (showFoldersPanel and "Visible" or "Hidden"), "foldersPanel")
        drawScriptPresetSetting("Sort Mode: " .. sortMode, "sortMode")
        reaper.ImGui_Separator(ctx)
        local saveRowWidth = reaper.ImGui_GetContentRegionAvail(ctx)
        local saveButtonWidth = reaper.ImGui_CalcTextSize(ctx, "Save") + 16
        reaper.ImGui_SetNextItemWidth(ctx, math.max(40, saveRowWidth - saveButtonWidth - 8))
        local changed
        changed, newPresetName = reaper.ImGui_InputText(ctx, "##newpreset", newPresetName)
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Save") then
            if newPresetName ~= "" then
                scriptPresets[newPresetName] = GetCurrentSettings(scriptPresetSaveMask)
                SaveScriptPresets()
                newPresetName = ""
            end
        end
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Saved Presets:")
        reaper.ImGui_Spacing(ctx)
        if BeginChild("PresetsList", 0, -30, true) then
            for name, settings in pairs(scriptPresets) do
                reaper.ImGui_PushID(ctx, name)
                local hotkeyStr = ""
                if scriptPresetHotkeys[name] then hotkeyStr = getHotkeyString(scriptPresetHotkeys[name]) end
                local displayName = name
                if hotkeyStr ~= "" then displayName = name .. " [" .. hotkeyStr .. "]" end
                if reaper.ImGui_Selectable(ctx, displayName, false, 0, 0, 0) then ApplySettings(settings) end
                if reaper.ImGui_BeginPopupContextItem(ctx, name .. "_ctx") then
                    if reaper.ImGui_MenuItem(ctx, "Load") then ApplySettings(settings) end
                    if reaper.ImGui_MenuItem(ctx, "Delete") then scriptPresets[name] = nil scriptPresetHotkeys[name] = nil SaveScriptPresets() end
                    if reaper.ImGui_MenuItem(ctx, "Update with Current") then scriptPresets[name] = GetCurrentSettings(scriptPresetSaveMask) SaveScriptPresets() end
                    reaper.ImGui_Separator(ctx)
                    if reaper.ImGui_MenuItem(ctx, "Set Hotkey...") then waitingForHotkey = name end
                    if scriptPresetHotkeys[name] and scriptPresetHotkeys[name].key ~= 0 then
                        if reaper.ImGui_MenuItem(ctx, "Clear Hotkey") then scriptPresetHotkeys[name] = nil SaveScriptPresets() end
                    end
                    reaper.ImGui_EndPopup(ctx)
                end
                reaper.ImGui_PopID(ctx)
            end
            reaper.ImGui_EndChild(ctx)
        end
        if reaper.ImGui_Button(ctx, "Close") then scriptPresetsOpen = false end
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 14)
    if not open then scriptPresetsOpen = false end

    if waitingForHotkey then reaper.ImGui_OpenPopup(ctx, "Set Hotkey##modal") end
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), theme.PopupBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.Text)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), theme.Button)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), theme.ButtonHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), theme.ButtonActive)
    if reaper.ImGui_BeginPopupModal(ctx, "Set Hotkey##modal", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, "Press any key combination for: " .. (waitingForHotkey or ""))
        reaper.ImGui_Text(ctx, "(Ctrl/Alt/Shift + Key)")
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_TextColored(ctx, theme.ActivePreset, "Waiting for input...")
        reaper.ImGui_Spacing(ctx)
        local ctrlDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        local altDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
        local shiftDown = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
        for imguiKey, vk in pairs(imguiKeyMap) do
            if reaper.ImGui_IsKeyPressed(ctx, imguiKey, false) then
                if vk ~= 0x1B then
                    scriptPresetHotkeys[waitingForHotkey] = { key = vk, ctrl = ctrlDown, alt = altDown, shift = shiftDown }
                    SaveScriptPresets()
                    waitingForHotkey = nil
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
                break
            end
        end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape(), false) then
            waitingForHotkey = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        if reaper.ImGui_Button(ctx, "Cancel") then waitingForHotkey = nil reaper.ImGui_CloseCurrentPopup(ctx) end
        reaper.ImGui_EndPopup(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 5)
end

local function drawColorFilterButtons()
    if not showColorFilters then return end
    local drawList = reaper.ImGui_GetWindowDrawList(ctx)
    local buttonSize = 16
    local spacing = 4
    for i, colorInfo in ipairs(availableColors) do
        if colorInfo.color then
            local isActive = (filterByColor == colorInfo.color)
            if reaper.ImGui_InvisibleButton(ctx, "##colorBtn" .. i, buttonSize, buttonSize) then
                if filterByColor == colorInfo.color then filterByColor = nil else filterByColor = colorInfo.color end
            end
            local btnMinX, btnMinY = reaper.ImGui_GetItemRectMin(ctx)
            local btnMaxX, btnMaxY = reaper.ImGui_GetItemRectMax(ctx)
            local centerX = (btnMinX + btnMaxX) / 2
            local centerY = (btnMinY + btnMaxY) / 2
            local radius = isActive and 7 or 5
            reaper.ImGui_DrawList_AddCircleFilled(drawList, centerX, centerY, radius, colorInfo.color)
            if isActive then reaper.ImGui_DrawList_AddCircle(drawList, centerX, centerY, radius + 1, 0xFFFFFFFF, 0, 2) end
            if i < #availableColors - 1 then reaper.ImGui_SameLine(ctx, 0, spacing) end
        end
    end
end

local function drawMenuBar()
    if not showMenuBar then return end
    if reaper.ImGui_BeginMenuBar(ctx) then
        if reaper.ImGui_BeginMenu(ctx, "View") then
            if reaper.ImGui_MenuItem(ctx, "Vertical Mode", nil, not horizontalMode) then
                horizontalMode = false reaper.SetExtState("PresetManager", "HorizontalMode", "false", true)
            end
            if reaper.ImGui_MenuItem(ctx, "Horizontal Mode", nil, horizontalMode) then
                horizontalMode = true reaper.SetExtState("PresetManager", "HorizontalMode", "true", true)
            end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Show Numbers", nil, showNumbers) then
                showNumbers = not showNumbers reaper.SetExtState("PresetManager", "ShowNumbers", tostring(showNumbers), true)
            end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Show Tooltips Inline", nil, showTooltipsInline) then
                showTooltipsInline = not showTooltipsInline
                reaper.SetExtState("PresetManager", "ShowTooltipsInline", tostring(showTooltipsInline), true)
            end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Show Tags", nil, showTags) then
                showTags = not showTags reaper.SetExtState("PresetManager", "ShowTags", tostring(showTags), true)
            end
            if reaper.ImGui_MenuItem(ctx, "Show Color Filters", nil, showColorFilters) then
                showColorFilters = not showColorFilters
                reaper.SetExtState("PresetManager", "ShowColorFilters", tostring(showColorFilters), true)
                if not showColorFilters then filterByColor = nil end
            end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Show Color Markers", nil, showColorMarkers) then
                showColorMarkers = not showColorMarkers
                reaper.SetExtState("PresetManager", "ShowColorMarkers", tostring(showColorMarkers), true)
            end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Show Folders Panel (Tab)", nil, showFoldersPanel) then
                showFoldersPanel = not showFoldersPanel
                reaper.SetExtState("PresetManager", "ShowFoldersPanel", tostring(showFoldersPanel), true)
            end
            reaper.ImGui_EndMenu(ctx)
        end
        if reaper.ImGui_BeginMenu(ctx, "Layout") then
            reaper.ImGui_Text(ctx, "Presets per column:")
            reaper.ImGui_SetNextItemWidth(ctx, 80)
            local changed1
            changed1, rowsPerColumnInput = reaper.ImGui_InputText(ctx, "##rowsInput", rowsPerColumnInput, reaper.ImGui_InputTextFlags_CharsDecimal())
            if changed1 then
                local num = tonumber(rowsPerColumnInput)
                if num and num >= 1 and num <= 999 then
                    rowsPerColumn = math.floor(num)
                    reaper.SetExtState("PresetManager", "RowsPerColumn", tostring(rowsPerColumn), true)
                end
            end
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Text(ctx, "Column width:")
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local changed2
            changed2, columnWidth = reaper.ImGui_SliderInt(ctx, "##widthSlider", columnWidth, 100, 400)
            if changed2 then reaper.SetExtState("PresetManager", "ColumnWidth", tostring(columnWidth), true) end
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Text(ctx, "Vertical scrollbar size:")
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local changed3
            changed3, scrollbarSizeVertical = reaper.ImGui_SliderInt(ctx, "##scrollbarVerticalSlider", scrollbarSizeVertical, 4, 24)
            if changed3 then
                reaper.SetExtState("PresetManager", "ScrollbarSizeVertical", tostring(scrollbarSizeVertical), true)
                reaper.SetExtState("PresetManager", "ScrollbarSize", tostring(scrollbarSizeVertical), true)
            end
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Text(ctx, "Horizontal scrollbar size:")
            reaper.ImGui_SetNextItemWidth(ctx, 150)
            local changed4
            changed4, scrollbarSizeHorizontal = reaper.ImGui_SliderInt(ctx, "##scrollbarHorizontalSlider", scrollbarSizeHorizontal, 4, 24)
            if changed4 then reaper.SetExtState("PresetManager", "ScrollbarSizeHorizontal", tostring(scrollbarSizeHorizontal), true) end
            reaper.ImGui_Separator(ctx)
            appearance.drawMenuItems()
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Lock Window Position", nil, lockWindowPosition) then
                lockWindowPosition = not lockWindowPosition
                reaper.SetExtState("PresetManager", "LockWindowPosition", tostring(lockWindowPosition), true)
            end
            if reaper.ImGui_MenuItem(ctx, "Lock Window Size", nil, lockWindowSize) then
                lockWindowSize = not lockWindowSize
                reaper.SetExtState("PresetManager", "LockWindowSize", tostring(lockWindowSize), true)
            end
            reaper.ImGui_EndMenu(ctx)
        end
        if reaper.ImGui_BeginMenu(ctx, "Sort") then
            if reaper.ImGui_MenuItem(ctx, "Original Order", nil, sortMode == "none") then
                sortMode = "none" reaper.SetExtState("PresetManager", "SortMode", sortMode, true)
            end
            if reaper.ImGui_MenuItem(ctx, "A-Z", nil, sortMode == "az") then
                sortMode = "az" reaper.SetExtState("PresetManager", "SortMode", sortMode, true)
            end
            if reaper.ImGui_MenuItem(ctx, "Color First", nil, sortMode == "colors") then
                sortMode = "colors" reaper.SetExtState("PresetManager", "SortMode", sortMode, true)
            end
            reaper.ImGui_EndMenu(ctx)
        end
        if reaper.ImGui_BeginMenu(ctx, "Presets") then
            if reaper.ImGui_MenuItem(ctx, "Manage Script Presets...") then
                resetScriptPresetSaveMask()
                scriptPresetsOpen = true
            end
            reaper.ImGui_Separator(ctx)
            if next(scriptPresets) then
                for name, settings in pairs(scriptPresets) do
                    local hotkeyStr = ""
                    if scriptPresetHotkeys[name] then hotkeyStr = getHotkeyString(scriptPresetHotkeys[name]) end
                    if reaper.ImGui_MenuItem(ctx, name, hotkeyStr) then ApplySettings(settings) end
                end
            else reaper.ImGui_TextDisabled(ctx, "(No saved presets)") end
            reaper.ImGui_EndMenu(ctx)
        end
        if reaper.ImGui_BeginMenu(ctx, "Actions") then
            if reaper.ImGui_MenuItem(ctx, "Refresh") then restartFocusedFX() refreshData() end
            if reaper.ImGui_MenuItem(ctx, "Open Presets Folder") then openCustomPresetFolder() end
            reaper.ImGui_Separator(ctx)
            local hasSelection = false
            for _, v in pairs(selectedPresets) do if v then hasSelection = true break end end
            if reaper.ImGui_MenuItem(ctx, "Delete Selected", nil, false, hasSelection) then delete() end
            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Clear all color markers in active folder", nil, false, currentFolder ~= nil) then
                clearColorMarkersInActiveFolder()
            end
            if reaper.ImGui_MenuItem(ctx, "Clear all color markers for selected presets", nil, false, hasSelection) then
                clearColorMarkersForSelectedPresets()
            end
            if reaper.ImGui_MenuItem(ctx, "Clear All Color Markers") then colorMarkers = {} SaveColorMarkers() end
            reaper.ImGui_EndMenu(ctx)
        end
        if reaper.ImGui_BeginMenu(ctx, "Help") then
            local noFocusedFx = (currentFXName == nil or currentFXName == "")
            if noFocusedFx then reaper.ImGui_PushFont(ctx, compactHelpFont, 12) end
            reaper.ImGui_BulletText(ctx, "Esc - Close script")
            reaper.ImGui_BulletText(ctx, "Double-click title bar - Toggle menu bar")
            reaper.ImGui_BulletText(ctx, "F1 - Toggle menu bar")
            reaper.ImGui_BulletText(ctx, "Tab - Toggle folders panel")
            reaper.ImGui_BulletText(ctx, "F4 - Add current search as Tag")
            reaper.ImGui_BulletText(ctx, "F2 - Rename selected")
            reaper.ImGui_BulletText(ctx, "F3 - Toggle tooltips inline")
            reaper.ImGui_BulletText(ctx, "F5 - Restart focused FX + Refresh data")
            reaper.ImGui_BulletText(ctx, "Del - Delete selected")
            reaper.ImGui_BulletText(ctx, "Up/Down - Navigate presets")
            reaper.ImGui_BulletText(ctx, "Left/Right - Switch script presets")
            reaper.ImGui_BulletText(ctx, "Ctrl+Click - Multi select")
            reaper.ImGui_BulletText(ctx, "Shift+Click - Range select")
            reaper.ImGui_BulletText(ctx, "Drag preset to folder")
            reaper.ImGui_BulletText(ctx, "Drag multiple to reorder/folder")
            reaper.ImGui_BulletText(ctx, "Custom hotkeys for script presets")
            reaper.ImGui_BulletText(ctx, "Right-click search field for tags")
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_TextColored(ctx, theme.ActivePreset or 0x4488FFFF, "✦ Made by Andrew Dihtiaruk")
            if reaper.ImGui_MenuItem(ctx, "✦ Support Ko-Fi") then
                reaper.CF_ShellExecute("https://ko-fi.com/pianohousestudio/shop")
            end
            if noFocusedFx then reaper.ImGui_PopFont(ctx) end
            reaper.ImGui_EndMenu(ctx)
        end
        reaper.ImGui_EndMenuBar(ctx)
    end
end

local function cleanFXName(fx_name)
    if not fx_name then return nil end
    fx_name = fx_name:gsub("This plug%-in's configuration window is currently floating%.", "")
    fx_name = fx_name:gsub("^%s+", ""):gsub("%s+$", "")
    return fx_name
end

local function getWindowTitle()
    local title = "✦ Preset Manager"
    if not showFoldersPanel and currentFolder then
        title = title .. " (" .. currentFolder .. ")"
    end
    return title
end

function exit()
end

local function loop()
    disableKeyboardNav()

    if pendingWindowPos then
        reaper.ImGui_SetNextWindowPos(ctx, pendingWindowPos.x, pendingWindowPos.y, reaper.ImGui_Cond_Always())
    end
    if pendingWindowSize then
        reaper.ImGui_SetNextWindowSize(ctx, pendingWindowSize.w, pendingWindowSize.h, reaper.ImGui_Cond_Always())
    else
        reaper.ImGui_SetNextWindowSize(ctx, 500, 700, reaper.ImGui_Cond_FirstUseEver())
    end

    reaper.ImGui_PushFont(ctx, font, 13)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), scrollbarSizeVertical)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 3)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 6, 4)

    local themeColorCount = applyTheme()

    local windowFlags = 0
    if showMenuBar then windowFlags = windowFlags + reaper.ImGui_WindowFlags_MenuBar() end
    if reaper.ImGui_WindowFlags_NoCollapse then windowFlags = windowFlags + reaper.ImGui_WindowFlags_NoCollapse() end
    if lockWindowPosition and not pendingWindowPos then windowFlags = windowFlags + reaper.ImGui_WindowFlags_NoMove() end
    if lockWindowSize and not pendingWindowSize then windowFlags = windowFlags + reaper.ImGui_WindowFlags_NoResize() end
    if reaper.ImGui_WindowFlags_NoNav then windowFlags = windowFlags + reaper.ImGui_WindowFlags_NoNav() end
    if reaper.ImGui_WindowFlags_NoNavFocus then windowFlags = windowFlags + reaper.ImGui_WindowFlags_NoNavFocus() end
    if reaper.ImGui_WindowFlags_UnsavedDocument then
        windowFlags = windowFlags & ~reaper.ImGui_WindowFlags_UnsavedDocument()
    end

    local windowTitle = getWindowTitle()
    local visible, open = reaper.ImGui_Begin(ctx, windowTitle .. "###PresetManagerMain", true, windowFlags)

    if visible then
        local _, winY = reaper.ImGui_GetWindowPos(ctx)
        local _, mouseY = reaper.ImGui_GetMousePos(ctx)
        local titleBarBottomY = winY + reaper.ImGui_GetFrameHeight(ctx) + 4
        local onTitleBar = reaper.ImGui_IsWindowHovered(ctx, reaper.ImGui_HoveredFlags_RootAndChildWindows()) and mouseY >= winY and mouseY <= titleBarBottomY
        if onTitleBar and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            showMenuBar = not showMenuBar
            reaper.SetExtState("PresetManager", "ShowMenuBar", tostring(showMenuBar), true)
        end

        lastWindowX, lastWindowY = reaper.ImGui_GetWindowPos(ctx)
        lastWindowW, lastWindowH = reaper.ImGui_GetWindowSize(ctx)
        pendingWindowPos = nil
        pendingWindowSize = nil

        local newTrack, newFxnum, fx_name_raw, track_name = getLastTouchFX()
        local fx_name = cleanFXName(fx_name_raw)
        local fxReallyChanged = false
        if newTrack and newFxnum then
            if track == nil or fxnum == nil then fxReallyChanged = true
            elseif newTrack ~= track or newFxnum ~= fxnum then fxReallyChanged = true end
        end

        -- Keep the last valid FX context when focus is temporarily outside FX windows.
        -- This avoids losing preset list while opening/switching plugin windows.
        if (track ~= nil or fxnum ~= nil) and (newTrack == nil or newFxnum == nil) then
            track = nil
            fxnum = nil
            currentFXName = ""
            presetList = {}
            folders = {}
            presetFolders = {}
            selectedPresets = {}
            currentPresetIndex = 0
            activePresetName = ""
            currentFolder = nil
            selectedFolderIndex = nil
            searchQuery = ""
            filterByColor = nil
            rangeStartIndex = nil
            lastPresetCount = 0
            lastPresetFileTime = 0
            invalidatePresetViewCache()
        elseif track and not reaper.ValidatePtr2(0, track, "MediaTrack*") then
            track = nil
            fxnum = nil
            currentFXName = ""
            presetList = {}
            folders = {}
            presetFolders = {}
            selectedPresets = {}
            currentPresetIndex = 0
            activePresetName = ""
            currentFolder = nil
            selectedFolderIndex = nil
            searchQuery = ""
            filterByColor = nil
            rangeStartIndex = nil
            lastPresetCount = 0
            lastPresetFileTime = 0
            invalidatePresetViewCache()
        end

        if fxReallyChanged then
            track = newTrack
            fxnum = newFxnum
            currentFXName = fx_name or ""
            loadPresets(track, fxnum)
            if currentFXName ~= "" then
                LoadFoldersForFX(currentFXName)
                LoadPresetFoldersForFX(currentFXName)
            else
                folders = {}
                presetFolders = {}
            end
            previousFXName = fx_name
            searchQuery = ""
            selectedPresets = {}
            currentPresetIndex = 0
            filterByColor = nil
            currentFolder = nil
            selectedFolderIndex = nil
            rangeStartIndex = nil
            invalidatePresetViewCache()
        end

        if track and fxnum then
            activePresetName = getActivePresetName()
            checkForExternalPresetChanges()
        end

        shift, ctrl, alt = keyboard_shortcuts()

        if appearance.closeRequested then
            open = false
        end

        drawMenuBar()

        appearance.pushAccent2ButtonColors()
        if reaper.ImGui_Button(ctx, "Folders", 50, 0) then
            showFoldersPanel = not showFoldersPanel
            reaper.SetExtState("PresetManager", "ShowFoldersPanel", tostring(showFoldersPanel), true)
        end
        appearance.popAccent2ButtonColors()

        reaper.ImGui_SameLine(ctx)

        local availW = reaper.ImGui_GetContentRegionAvail(ctx)
        local inputWidth = availW - 80
        reaper.ImGui_SetNextItemWidth(ctx, inputWidth)

        local inputPosX, inputPosY = reaper.ImGui_GetCursorScreenPos(ctx)
        local changed
        changed, searchQuery = reaper.ImGui_InputText(ctx, '##search', searchQuery)

        local isSearchActive = reaper.ImGui_IsItemActive(ctx)
        local drawList = reaper.ImGui_GetWindowDrawList(ctx)

        if not isSearchActive and searchQuery == "" then
            local now = reaper.time_precise()
            if feedbackMessage ~= "" and now < feedbackTimer then
                local remaining = feedbackTimer - now
                local alpha = math.min(1.0, remaining / 0.3)
                local r = (feedbackColor >> 24) & 0xFF
                local g = (feedbackColor >> 16) & 0xFF
                local b = (feedbackColor >> 8) & 0xFF
                local a = math.floor(255 * alpha)
                local fadedColor = (r << 24) | (g << 16) | (b << 8) | a
                reaper.ImGui_DrawList_AddText(drawList, inputPosX + 5, inputPosY + 3, fadedColor, feedbackMessage)
            elseif feedbackMessage ~= "" and now >= feedbackTimer then
                feedbackMessage = ""
                reaper.ImGui_DrawList_AddText(drawList, inputPosX + 5, inputPosY + 3, theme.PlaceholderText, "Search...")
            else
                reaper.ImGui_DrawList_AddText(drawList, inputPosX + 5, inputPosY + 3, theme.PlaceholderText, "Search...")
            end
        end

        if reaper.ImGui_BeginPopupContextItem(ctx, "##searchTagsPopup") then
            if #tags > 0 then
                for i, t in ipairs(tags) do
                    if reaper.ImGui_MenuItem(ctx, t .. "##searchTag" .. i) then
                        searchQuery = t
                    end
                    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseReleased(ctx, 1) then
                        table.remove(tags, i)
                        SaveTags()
                        if searchQuery == t then searchQuery = "" end
                        break
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "(No tags)")
            end
            reaper.ImGui_Separator(ctx)
            local canSaveTag = searchQuery ~= ""
            if canSaveTag then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.ActivePreset or 0x4488FFFF)
                if reaper.ImGui_MenuItem(ctx, "Save Tag") then saveSearchAsTag() end
                reaper.ImGui_PopStyleColor(ctx)
            else
                reaper.ImGui_MenuItem(ctx, "Save Tag", nil, false, false)
            end
            reaper.ImGui_EndPopup(ctx)
        end

        reaper.ImGui_SameLine(ctx)
        appearance.pushAccent2ButtonColors()
        if reaper.ImGui_Button(ctx, 'Clear') then searchQuery = "" end
        appearance.popAccent2ButtonColors()

        reaper.ImGui_SameLine(ctx)
        appearance.pushAccent2ButtonColors()
        if reaper.ImGui_Button(ctx, "\240\159\146\190##savePreset", 25, 0) then
            if track and fxnum then openSavePresetModal() end
        end
        appearance.popAccent2ButtonColors()

        if showTags and #tags > 0 then
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 2, 2)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 4, 2)
            local max_width = reaper.ImGui_GetContentRegionAvail(ctx)
            local cur_width, h_padding, first_in_row = 0, 4, true
            for i, t in ipairs(tags) do
                local btn_w = reaper.ImGui_CalcTextSize(ctx, t)
                local btn_size = btn_w + 12
                if cur_width + btn_size > max_width then cur_width = 0 first_in_row = true end
                if not first_in_row then reaper.ImGui_SameLine(ctx, 0, h_padding) end
                if reaper.ImGui_Button(ctx, t .. "##tag" .. i) then searchQuery = t end
                if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                    dragTagIndex = i
                    reaper.ImGui_SetDragDropPayload(ctx, "DND_TAG", tostring(i))
                    reaper.ImGui_Text(ctx, t)
                    reaper.ImGui_EndDragDropSource(ctx)
                end
                if reaper.ImGui_BeginDragDropTarget(ctx) then
                    local accepted = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_TAG")
                    if accepted and dragTagIndex and dragTagIndex ~= i then
                        local movedTag = tags[dragTagIndex]
                        if movedTag then
                            table.remove(tags, dragTagIndex)
                            local targetIndex = i
                            if dragTagIndex < i then targetIndex = targetIndex - 1 end
                            table.insert(tags, targetIndex, movedTag)
                            SaveTags()
                        end
                        dragTagIndex = nil
                    end
                    reaper.ImGui_EndDragDropTarget(ctx)
                end
                if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseReleased(ctx, 1) then
                    table.remove(tags, i) SaveTags()
                    if searchQuery == t then searchQuery = "" end
                    break
                end
                cur_width = cur_width + btn_size + h_padding
                first_in_row = false
            end
            reaper.ImGui_PopStyleVar(ctx, 2)
        end

        drawColorFilterButtons()

        reaper.ImGui_Separator(ctx)

        drawFoldersPanel()

        if BeginChild("PresetsPanel", 0, 0, false) then
            if fx_name ~= nil and fx_name ~= "" and #presetList > 0 then
                local filteredPresets, indexMap, cacheSignature = getFilteredPresets()
                if #filteredPresets > 0 then
                    if horizontalMode then drawHorizontalPresetList(filteredPresets, indexMap, cacheSignature)
                    else drawVerticalPresetList(filteredPresets, indexMap, cacheSignature) end
                else
                    if currentFolder then
                        reaper.ImGui_TextDisabled(ctx, "No preset in folder")
                    else
                        reaper.ImGui_TextDisabled(ctx, "No matching presets")
                    end
                end
            elseif fx_name ~= nil and fx_name ~= "" then
                reaper.ImGui_TextDisabled(ctx, "No presets found")
            else
                reaper.ImGui_PushFont(ctx, noFxFont, 18)
                reaper.ImGui_TextColored(ctx, theme.TextDisabled or 0x808080FF, "No Focused FX")
                reaper.ImGui_PopFont(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_PushFont(ctx, compactHelpFont, 12)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.TextDisabled or 0x808080FF)
                reaper.ImGui_BulletText(ctx, "Esc - Close script")
                reaper.ImGui_BulletText(ctx, "F1 - Toggle menu bar")
                reaper.ImGui_BulletText(ctx, "Tab - Toggle folders panel")
                reaper.ImGui_BulletText(ctx, "Right-click search field for tags")
                reaper.ImGui_PopStyleColor(ctx)
                reaper.ImGui_PopFont(ctx)
            end
            reaper.ImGui_EndChild(ctx)
        end

        drawRenameModal()
        drawTooltipModal()
        drawSavePresetModal()
        drawFolderRenameModal()
        drawNewFolderModal()

        reaper.ImGui_End(ctx)
    end

    popTheme(themeColorCount)
    reaper.ImGui_PopStyleVar(ctx, 5)
    reaper.ImGui_PopFont(ctx)

    drawScriptPresetsWindow()

    if open then reaper.defer(loop)
    else exit() end
end

ensurePresetDirectory(customPresetRoot)
LoadTags()
LoadTooltipTags()
LoadPresetSaveTags()
LoadColorMarkers()
LoadScriptPresets()
LoadAllFXFolders()
LoadAllPresetFolders()

folders = {}
presetFolders = {}

reaper.atexit(exit)
reaper.defer(loop)

