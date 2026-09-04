--[[
-------------------------------------------------------------------------------------------
*              FSR  Region Templates
* Section      Main
* Author:      Andrew Dihtaryk(FSR)
* Version:     1.00
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:    
    

--]]
local r = reaper

if not r.ImGui_GetVersion then
    r.MB("ReaImGui not installed!", "Error", 0)
    return
end

local ctx = r.ImGui_CreateContext("Region Templates")
local function disableKeyboardNav(ctx)
    if r.ImGui_GetConfigVar and r.ImGui_SetConfigVar and r.ImGui_ConfigVar_Flags and r.ImGui_ConfigFlags_NavEnableKeyboard then
        local flags_var = r.ImGui_ConfigVar_Flags()
        local flags = r.ImGui_GetConfigVar(ctx, flags_var)
        flags = flags & (~r.ImGui_ConfigFlags_NavEnableKeyboard())
        if r.ImGui_ConfigFlags_NavEnableGamepad then
            flags = flags & (~r.ImGui_ConfigFlags_NavEnableGamepad())
        end
        r.ImGui_SetConfigVar(ctx, flags_var, flags)
    end
    if r.ImGui_SetConfigVar then
        if r.ImGui_ConfigVar_NavCaptureKeyboard then
            r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_NavCaptureKeyboard(), 0)
        end
        if r.ImGui_ConfigVar_NavCursorVisibleAuto then
            r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_NavCursorVisibleAuto(), 0)
        end
        if r.ImGui_ConfigVar_NavCursorVisibleAlways then
            r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_NavCursorVisibleAlways(), 0)
        end
    end
end
disableKeyboardNav(ctx)
local font = r.ImGui_CreateFont("Arial", 14)
r.ImGui_Attach(ctx, font)

local FONT_SIZE = 13

local SCRIPT_PATH = ({r.get_action_context()})[2]:match("^(.*[/\\])")
local EXT_SECTION = "RegionTemplatesManager"
local EXT_KEY_DATA = "groups_data"
local EXT_KEY_ACTIVE_SLOT = "active_slot"
local EXT_KEY_ACTIVE_GROUP = "active_group"
local EXT_KEY_LOCK_POSITION = "lock_position"
local EXT_KEY_NO_DOCKING = "no_docking"
local EXT_KEY_WINDOW_W = "window_w"
local EXT_KEY_WINDOW_H = "window_h"
local EXT_KEY_WINDOW_X = "window_x"
local EXT_KEY_WINDOW_Y = "window_y"
local EXT_KEY_GROUPS_PANEL_W = "groups_panel_w"
local EXT_KEY_ITEM_SPACING = "item_spacing"
local EXT_KEY_SHOW_COLOR_MARKERS = "show_color_markers"
local EXT_KEY_SHOW_ITEM_NUMBERS = "show_item_numbers"
local EXT_KEY_DELETE_PREV_REG = "delete_prev_regions"
local EXT_KEY_INSERT_AT_CURSOR = "insert_at_cursor"
local EXT_KEY_LAST_EXPORT_PATH = "last_export_path"
local EXT_KEY_SHOW_FOLDERS_PANEL = "show_folders_panel"
local EXT_KEY_ZOOM_TO_REGIONS = "zoom_to_regions"
local EXT_KEY_CLEAR_TOOLTIP = "clear_tooltip"
local EXT_KEY_BACKGROUND_COLOR = "background_color"
local EXT_KEY_ACCENT_COLOR = "accent_color"
local EXT_KEY_TEXT_COLOR = "text_color"
local SWS_DELETE_ALL_REGIONS_ACTION = "_SWSMARKERLIST10"

-- File extensions:
--   .rgti = one Item
--   .rgtg = one Group
--   .rgt  = the complete Preset Library (All)
local ITEM_FILE_EXTENSION    = "rgti"
local GROUP_FILE_EXTENSION   = "rgtg"
local LIBRARY_FILE_EXTENSION = "rgt"
local FILE_HEADER = "[RegionTemplates]"
local FILE_VERSION = "2.0"

local MIN_WINDOW_W = 300
local MIN_WINDOW_H = 200
local MIN_PANEL_W = 80
local DIVIDER_WIDTH = 6
local TEXT_INDENT = 6

local groups = {}
local selected_group_index = 1

local lock_position = r.GetExtState(EXT_SECTION, EXT_KEY_LOCK_POSITION) == "true"
local no_docking = r.GetExtState(EXT_SECTION, EXT_KEY_NO_DOCKING) ~= "false"
local delete_prev_regions = r.GetExtState(EXT_SECTION, EXT_KEY_DELETE_PREV_REG) ~= "false"
local insert_at_cursor = r.GetExtState(EXT_SECTION, EXT_KEY_INSERT_AT_CURSOR) == "true"
local show_folders_panel = r.GetExtState(EXT_SECTION, EXT_KEY_SHOW_FOLDERS_PANEL) ~= "false"
local zoom_to_regions = r.GetExtState(EXT_SECTION, EXT_KEY_ZOOM_TO_REGIONS) == "true"
local show_clear_tooltip = r.GetExtState(EXT_SECTION, EXT_KEY_CLEAR_TOOLTIP) ~= "false"
local zoom_padding_pct = 2

local last_export_path = r.GetExtState(EXT_SECTION, EXT_KEY_LAST_EXPORT_PATH)
if last_export_path == "" then
    last_export_path = SCRIPT_PATH
end

local ITEM_COLORS = {
    { name = "None",   color = 0x00000000 },
    { name = "Red",    color = 0xFF4444FF },
    { name = "Orange", color = 0xFF8844FF },
    { name = "Yellow", color = 0xFFFF44FF },
    { name = "Green",  color = 0x44FF44FF },
    { name = "Cyan",   color = 0x44FFFFFF },
    { name = "Blue",   color = 0x4488FFFF },
    { name = "Purple", color = 0xAA44FFFF },
    { name = "Pink",   color = 0xFF44AAFF },
}

local show_color_markers = r.GetExtState(EXT_SECTION, EXT_KEY_SHOW_COLOR_MARKERS) ~= "false"
local show_item_numbers  = r.GetExtState(EXT_SECTION, EXT_KEY_SHOW_ITEM_NUMBERS) == "true"

local MARKER_SIZE = 5

local layout = {
    groups_panel_w = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_GROUPS_PANEL_W)) or 180,
    item_spacing   = 5,
}

local saved_window_w = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_WINDOW_W)) or 500
local saved_window_h = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_WINDOW_H)) or 400
local saved_window_x = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_WINDOW_X))
local saved_window_y = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_WINDOW_Y))
saved_window_w = math.max(saved_window_w, MIN_WINDOW_W)
saved_window_h = math.max(saved_window_h, MIN_WINDOW_H)

local first_frame = true

local active_slot_index = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_SLOT))  or 0
local active_slot_group = tonumber(r.GetExtState(EXT_SECTION, EXT_KEY_ACTIVE_GROUP)) or 0

local rename_item_index = nil
local rename_item_buf   = ""
local open_rename_item_modal = false

local rename_group_index = nil
local rename_group_buf   = ""
local open_rename_group_modal = false

local new_group_buf        = "New Group"
local open_new_group_modal = false

local save_template_buf        = "New Template"
local open_save_template_modal = false
local pending_save_data        = nil

local pending_markers = {}

local pending_save_layout      = false
local pending_save_layout_time = 0
local SAVE_DELAY               = 0.5

local open_import_modal = false
local import_data       = nil
local import_mode       = 1

local pending_export_group = nil
local pending_export_item  = nil
local pending_delete_group = nil

local is_dragging_divider = false
local drag_start_x        = 0
local drag_start_w        = 0

local toast_message  = nil
local toast_time     = 0
local toast_duration = 2.0
local toast_is_error = false
local clear_tooltip_flash_until = 0

local function ShowToast(message, is_error)
    toast_message  = message
    toast_time     = r.time_precise()
    toast_is_error = is_error or false
end

local function LerpColorRGBA(c1, c2, t)
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

local function ColorRGBAtoRGB(c)
    return (c >> 8) & 0xFFFFFF
end

local function ColorRGBtoRGBA(c)
    return (c << 8) | 0xFF
end

local function LoadColorSetting(key, default_color)
    local saved = tonumber(r.GetExtState(EXT_SECTION, key))
    if saved then
        return (saved & 0xFFFFFF00) | 0xFF
    end
    return default_color
end

local DEFAULT_BACKGROUND_COLOR = 0x1E1E1EFF
local DEFAULT_ACCENT_COLOR     = 0x00AAFFFF
local DEFAULT_TEXT_COLOR       = 0xE0E0E0FF
local background_color = LoadColorSetting(EXT_KEY_BACKGROUND_COLOR, DEFAULT_BACKGROUND_COLOR)
local accent_color     = LoadColorSetting(EXT_KEY_ACCENT_COLOR,     DEFAULT_ACCENT_COLOR)
local text_color       = LoadColorSetting(EXT_KEY_TEXT_COLOR,       DEFAULT_TEXT_COLOR)

local theme = {
    WindowBg             = 0x1E1E1EFF,
    Text                 = 0xE0E0E0FF,
    TextDisabled         = 0x808080FF,
    FrameBg              = 0x333333FF,
    FrameBgHovered       = 0x444444FF,
    FrameBgActive        = 0x555555FF,
    TitleBg              = 0x1A1A1AFF,
    TitleBgActive        = 0x2D2D2DFF,
    Button               = 0x404040FF,
    ButtonHovered        = 0x505050FF,
    ButtonActive         = 0x606060FF,
    CheckMark            = 0x00AAFFFF,
    ScrollbarBg          = 0x1A1A1AFF,
    ScrollbarGrab        = 0x404040FF,
    ScrollbarGrabHovered = 0x505050FF,
    ScrollbarGrabActive  = 0x606060FF,
    Header               = 0x3D3D3DFF,
    HeaderHovered        = 0x4D4D4DFF,
    HeaderActive         = 0x5D5D5DFF,
    Separator            = 0x505050FF,
    PopupBg              = 0x252525FF,
    MenuBarBg            = 0x2A2A2AFF,
    Border               = 0x505050FF,
    ActivePreset         = 0x00AAFFFF,
    ToastBg              = 0x2A2A2AEE,
    ToastSuccess         = 0x44CC44FF,
    ToastError           = 0xFF4444FF,
    Divider              = 0x505050FF,
    DividerHovered       = 0x707070FF,
    DividerActive        = 0x00AAFFFF,
    DragDropTarget       = 0x00AAFFFF,
}

local function OffsetColor(c, offset)
    local cr = math.max(0, math.min(255, ((c >> 24) & 0xFF) + offset))
    local cg = math.max(0, math.min(255, ((c >> 16) & 0xFF) + offset))
    local cb = math.max(0, math.min(255, ((c >> 8)  & 0xFF) + offset))
    return (cr << 24) | (cg << 16) | (cb << 8) | 0xFF
end

local function RefreshThemeColors()
    local bg = background_color
    local br = (bg >> 24) & 0xFF
    local bgc = (bg >> 16) & 0xFF
    local bb = (bg >> 8) & 0xFF
    theme.WindowBg             = bg
    theme.Text                 = text_color
    theme.TextDisabled         = LerpColorRGBA(text_color, bg, 0.5)
    theme.FrameBg              = OffsetColor(bg, 21)
    theme.FrameBgHovered       = OffsetColor(bg, 38)
    theme.FrameBgActive        = OffsetColor(bg, 55)
    theme.TitleBg              = OffsetColor(bg, -4)
    theme.TitleBgActive        = OffsetColor(bg, 15)
    theme.Button               = OffsetColor(bg, 34)
    theme.ButtonHovered        = OffsetColor(bg, 50)
    theme.ButtonActive         = OffsetColor(bg, 66)
    theme.CheckMark            = accent_color
    theme.ScrollbarBg          = OffsetColor(bg, -4)
    theme.ScrollbarGrab        = OffsetColor(bg, 34)
    theme.ScrollbarGrabHovered = OffsetColor(bg, 50)
    theme.ScrollbarGrabActive  = OffsetColor(bg, 66)
    theme.Header               = OffsetColor(bg, 31)
    theme.HeaderHovered        = OffsetColor(bg, 45)
    theme.HeaderActive         = OffsetColor(bg, 61)
    theme.Separator            = OffsetColor(bg, 50)
    theme.PopupBg              = OffsetColor(bg, 7)
    theme.MenuBarBg            = OffsetColor(bg, 12)
    theme.Border               = OffsetColor(bg, 50)
    theme.ActivePreset         = accent_color
    theme.ToastBg              = (OffsetColor(bg, 12) & 0xFFFFFF00) | 0xEE
    theme.Divider              = OffsetColor(bg, 50)
    theme.DividerHovered       = OffsetColor(bg, 80)
    theme.DividerActive        = accent_color
    theme.DragDropTarget       = accent_color
end

local function SaveLayoutSettingsImmediate()
    r.SetExtState(EXT_SECTION, EXT_KEY_GROUPS_PANEL_W,   tostring(layout.groups_panel_w), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_ITEM_SPACING,     tostring(layout.item_spacing),   true)
    r.SetExtState(EXT_SECTION, EXT_KEY_SHOW_COLOR_MARKERS, tostring(show_color_markers),  true)
    r.SetExtState(EXT_SECTION, EXT_KEY_SHOW_ITEM_NUMBERS,  tostring(show_item_numbers),   true)
    r.SetExtState(EXT_SECTION, EXT_KEY_SHOW_FOLDERS_PANEL, tostring(show_folders_panel),  true)
    pending_save_layout = false
end

local function SaveLayoutSettings()
    pending_save_layout      = true
    pending_save_layout_time = r.time_precise()
end

local function SaveSettings()
    r.SetExtState(EXT_SECTION, EXT_KEY_LOCK_POSITION,    tostring(lock_position),       true)
    r.SetExtState(EXT_SECTION, EXT_KEY_NO_DOCKING,       tostring(no_docking),          true)
    r.SetExtState(EXT_SECTION, EXT_KEY_DELETE_PREV_REG,  tostring(delete_prev_regions), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_INSERT_AT_CURSOR, tostring(insert_at_cursor),    true)
    r.SetExtState(EXT_SECTION, EXT_KEY_ZOOM_TO_REGIONS,  tostring(zoom_to_regions),     true)
    r.SetExtState(EXT_SECTION, EXT_KEY_CLEAR_TOOLTIP,    tostring(show_clear_tooltip),   true)
end

local function SaveAppearanceSettings()
    r.SetExtState(EXT_SECTION, EXT_KEY_BACKGROUND_COLOR, tostring(background_color), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_ACCENT_COLOR,     tostring(accent_color),     true)
    r.SetExtState(EXT_SECTION, EXT_KEY_TEXT_COLOR,       tostring(text_color),       true)
end

local function SaveWindowSize(w, h)
    r.SetExtState(EXT_SECTION, EXT_KEY_WINDOW_W, tostring(math.floor(w)), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_WINDOW_H, tostring(math.floor(h)), true)
end

local function SaveWindowPosition(x, y)
    r.SetExtState(EXT_SECTION, EXT_KEY_WINDOW_X, tostring(math.floor(x + 0.5)), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_WINDOW_Y, tostring(math.floor(y + 0.5)), true)
end

local function SaveLastExportPath(path)
    local dir = path:match("^(.*[/\\])")
    if dir then
        last_export_path = dir
        r.SetExtState(EXT_SECTION, EXT_KEY_LAST_EXPORT_PATH, dir, true)
    end
end

local THEME_COLOR_COUNT = 24

local function applyTheme()
    local t = theme
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(),             t.WindowBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),                 t.Text)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TextDisabled(),         t.TextDisabled)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(),              t.FrameBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(),       t.FrameBgHovered)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(),        t.FrameBgActive)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBg(),              t.TitleBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(),        t.TitleBgActive)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),               t.Button)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(),        t.ButtonHovered)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),         t.ButtonActive)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_CheckMark(),            t.CheckMark)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarBg(),          t.ScrollbarBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarGrab(),        t.ScrollbarGrab)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarGrabHovered(), t.ScrollbarGrabHovered)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarGrabActive(),  t.ScrollbarGrabActive)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(),               t.Header)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(),        t.HeaderHovered)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderActive(),         t.HeaderActive)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Separator(),            t.Separator)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(),              t.PopupBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_MenuBarBg(),            t.MenuBarBg)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Border(),               t.Border)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(),       t.DragDropTarget)
end

local function popTheme()
    r.ImGui_PopStyleColor(ctx, THEME_COLOR_COUNT)
end

---------------------------------------------------------------------------
-- BEAT-BASED CONVERSION HELPERS
---------------------------------------------------------------------------

local function TimeToBeatPos(time_sec)
    return r.TimeMap2_timeToQN(0, time_sec)
end

local function BeatPosToTime(qn)
    return r.TimeMap2_QNToTime(0, qn)
end

---------------------------------------------------------------------------
-- ZOOM TO REGIONS
---------------------------------------------------------------------------

local function ZoomToRegions()
    local num = r.CountProjectMarkers(0)
    if num == 0 then return end

    local min_pos =  math.huge
    local max_pos = -math.huge

    for i = 0, num - 1 do
        local _, isrgn, pos, rgnend = r.EnumProjectMarkers3(0, i)
        if isrgn then
            if pos    < min_pos then min_pos = pos    end
            if rgnend > max_pos then max_pos = rgnend end
        end
    end

    if min_pos == math.huge or max_pos == -math.huge or max_pos <= min_pos then
        return
    end

    local span    = max_pos - min_pos
    local padding = span * (zoom_padding_pct / 100.0)
    local view_start = math.max(0, min_pos - padding)
    local view_end   = max_pos + padding

    r.GetSet_ArrangeView2(0, true, 0, 0, view_start, view_end)
end

---------------------------------------------------------------------------
-- SERIALIZATION
---------------------------------------------------------------------------

local function SerializeGroups()
    local parts = {}
    for i, group in ipairs(groups) do
        local safe_name  = group.name:gsub("[|]", ""):gsub("\n", " ")
        local item_parts = {}
        for j, item in ipairs(group.items) do
            local safe_item_name = (item.name or "Template"):gsub("[|]", "")
            local item_color     = item.color or 0
            local safe_data      = item.data:gsub("\n", "\\n")
            table.insert(item_parts, safe_item_name .. "::" .. tostring(item_color) .. "::" .. safe_data)
        end
        local items_str = table.concat(item_parts, ";;")
        table.insert(parts, safe_name .. "::" .. items_str)
    end
    return table.concat(parts, "||")
end

local function SerializeGroup(group)
    local safe_name  = group.name:gsub("[|]", ""):gsub("\n", " ")
    local item_parts = {}
    for j, item in ipairs(group.items) do
        local safe_item_name = (item.name or "Template"):gsub("[|]", "")
        local item_color     = item.color or 0
        local safe_data      = item.data:gsub("\n", "\\n")
        table.insert(item_parts, safe_item_name .. "::" .. tostring(item_color) .. "::" .. safe_data)
    end
    local items_str = table.concat(item_parts, ";;")
    return safe_name .. "::" .. items_str
end

local function SerializeItem(item)
    local safe_item_name = (item.name or "Template"):gsub("<SEP>", "")
    local item_color     = item.color or 0
    local safe_data      = item.data:gsub("\n", "\\n")
    return safe_item_name .. "<SEP>" .. tostring(item_color) .. "<SEP>" .. safe_data
end

local function DeserializeGroups(raw)
    local result = {}
    if not raw or raw == "" then return result end
    for group_str in string.gmatch(raw .. "||", "(.-)||") do
        local gname, items_str = group_str:match("^(.-)::(.*)$")
        if gname then
            local group = { name = gname, items = {} }
            if items_str and items_str ~= "" then
                for item_str in string.gmatch(items_str .. ";;", "(.-);;") do
                    local iname, color_str, data = item_str:match("^(.-)::(%d+)::(.*)$")
                    if iname and color_str and data then
                        data = data:gsub("\\n", "\n")
                        table.insert(group.items, {
                            name  = iname,
                            color = tonumber(color_str) or 0,
                            data  = data
                        })
                    else
                        iname, data = item_str:match("^(.-)::(.*)$")
                        if iname and data then
                            data = data:gsub("\\n", "\n")
                            table.insert(group.items, {
                                name  = iname,
                                color = 0,
                                data  = data
                            })
                        end
                    end
                end
            end
            table.insert(result, group)
        end
    end
    return result
end

local function DeserializeItem(raw)
    if not raw or raw == "" then return nil end
    local sep1_start, sep1_end = raw:find("<SEP>", 1, true)
    if not sep1_start then return nil end
    local iname = raw:sub(1, sep1_start - 1)
    local sep2_start, sep2_end = raw:find("<SEP>", sep1_end + 1, true)
    if not sep2_start then return nil end
    local color_str = raw:sub(sep1_end + 1, sep2_start - 1)
    local item_data = raw:sub(sep2_end + 1)
    if iname and item_data and item_data ~= "" then
        item_data = item_data:gsub("\\n", "\n")
        return {
            name  = iname,
            color = tonumber(color_str) or 0,
            data  = item_data
        }
    end
    return nil
end

local function SaveGroups()
    local data = SerializeGroups()
    r.SetExtState(EXT_SECTION, EXT_KEY_DATA,         data,                       true)
    r.SetExtState(EXT_SECTION, EXT_KEY_ACTIVE_SLOT,  tostring(active_slot_index), true)
    r.SetExtState(EXT_SECTION, EXT_KEY_ACTIVE_GROUP, tostring(active_slot_group), true)
end

local function LoadGroups()
    local raw = r.GetExtState(EXT_SECTION, EXT_KEY_DATA)
    groups = DeserializeGroups(raw)
    if #groups == 0 then
        groups = {{ name = "Default", items = {} }}
    end
end

local function DeleteGroup(idx)
    if not idx or not groups[idx] then return end
    table.remove(groups, idx)
    if selected_group_index > #groups then selected_group_index = #groups end
    if selected_group_index < 1 then selected_group_index = 1 end
    if #groups == 0 then
        groups = {{ name = "Default", items = {} }}
        selected_group_index = 1
    end
    if active_slot_group == idx then
        active_slot_index = 0
        active_slot_group = 0
    elseif active_slot_group > idx then
        active_slot_group = active_slot_group - 1
    end
    SaveGroups()
end

local function CreateFileContent(data_type, data)
    local lines = {
        FILE_HEADER,
        "version=" .. FILE_VERSION,
        "type="    .. data_type,
        "format=qn",
        "date="    .. os.date("%Y-%m-%d %H:%M:%S"),
        "[DATA]",
        data
    }
    return table.concat(lines, "\n")
end

local function ParseFileContent(content)
    if not content or content == "" then return nil, "Empty file" end
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    if #lines < 1 or lines[1] ~= FILE_HEADER then return nil, "Invalid file format" end
    local version, data_type, data, format
    local data_start = false
    local data_lines = {}
    for i = 2, #lines do
        local line = lines[i]
        if data_start then
            table.insert(data_lines, line)
        elseif line == "[DATA]" then
            data_start = true
        elseif line:match("^version=") then
            version   = line:match("^version=(.+)$")
        elseif line:match("^type=") then
            data_type = line:match("^type=(.+)$")
        elseif line:match("^format=") then
            format    = line:match("^format=(.+)$")
        end
    end
    data = table.concat(data_lines, "\n")
    if not data or data == "" then return nil, "No data found" end
    return { version = version, data_type = data_type, data = data, format = format }
end

local function WriteFile(path, content)
    local file, err = io.open(path, "w")
    if not file then return false, err end
    file:write(content)
    file:close()
    return true
end

local function ReadFile(path)
    local file, err = io.open(path, "r")
    if not file then return nil, err end
    local content = file:read("*all")
    file:close()
    return content
end

local function GetExpectedFileExtension(data_type)
    if data_type == "item" then return ITEM_FILE_EXTENSION end
    if data_type == "group" then return GROUP_FILE_EXTENSION end
    if data_type == "all"  then return LIBRARY_FILE_EXTENSION end
    return nil
end

local function GetImportTypeLabel(data_type)
    if data_type == "item" then return "Item" end
    if data_type == "group" then return "Group" end
    if data_type == "all"  then return "Library" end
    return "Unknown"
end

local function CleanFilename(name)
    if not name or name == "" then return "template" end
    local clean = name:gsub('[<>:"/\\|?*]', "")
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then clean = "template" end
    return clean
end

local function GetSaveFilePath(default_name, extension)
    extension = extension or LIBRARY_FILE_EXTENSION
    local clean_name = CleanFilename(default_name)
    local retval, path = r.JS_Dialog_BrowseForSaveFile(
        "Export Region Templates", last_export_path, clean_name .. "." .. extension,
        "Region Templates (*." .. extension .. ")\0*." .. extension .. "\0All Files (*.*)\0*.*\0"
    )
    if retval == 1 and path and path ~= "" then
        if not path:lower():match("%." .. extension .. "$") then path = path .. "." .. extension end
        return path
    end
    return nil
end

local function GetOpenFilePath()
    local retval, path = r.JS_Dialog_BrowseForOpenFiles(
        "Import Region Templates", last_export_path, "",
        "Region Templates (*.rgt;*.rgti;*.rgtg)\0*.rgt;*.rgti;*.rgtg\0All Files (*.*)\0*.*\0", false
    )
    if retval == 1 and path and path ~= "" then return path end
    return nil
end

local function ExportAll()
    local path = GetSaveFilePath("preset_library", LIBRARY_FILE_EXTENSION)
    if not path then return end
    local data    = SerializeGroups()
    local content = CreateFileContent("all", data)
    local ok, err = WriteFile(path, content)
    if ok then
        SaveLastExportPath(path)
        ShowToast("Library exported!")
    else
        ShowToast("Export failed: " .. (err or "Unknown error"), true)
    end
end

local function ExportGroup(group_index)
    if not groups[group_index] then return end
    local group   = groups[group_index]
    local path    = GetSaveFilePath(group.name, GROUP_FILE_EXTENSION)
    if not path then return end
    local data    = SerializeGroup(group)
    local content = CreateFileContent("group", data)
    local ok, err = WriteFile(path, content)
    if ok then
        SaveLastExportPath(path)
        ShowToast("Group exported!")
    else
        ShowToast("Export failed: " .. (err or "Unknown error"), true)
    end
end

local function ExportItem(group_index, item_index)
    if not groups[group_index] then return end
    local group = groups[group_index]
    if not group.items[item_index] then return end
    local item    = group.items[item_index]
    local path    = GetSaveFilePath(item.name or "Item", ITEM_FILE_EXTENSION)
    if not path then return end
    local data    = SerializeItem(item)
    local content = CreateFileContent("item", data)
    local ok, err = WriteFile(path, content)
    if ok then
        SaveLastExportPath(path)
        ShowToast("Item exported!")
    else
        ShowToast("Export failed: " .. (err or "Unknown error"), true)
    end
end

local function ImportFile()
    local path = GetOpenFilePath()
    if not path then return end
    local content, err = ReadFile(path)
    if not content then
        ShowToast("Cannot read file: " .. (err or "Unknown"), true)
        return
    end
    local parsed, parse_err = ParseFileContent(content)
    if not parsed then
        ShowToast("Invalid file: " .. (parse_err or "Unknown"), true)
        return
    end

    local file_extension = path:match("%.([^%.\\/:]+)$")
    local expected_extension = GetExpectedFileExtension(parsed.data_type)
    if file_extension and expected_extension and file_extension:lower() ~= expected_extension then
        ShowToast("Invalid extension for " .. GetImportTypeLabel(parsed.data_type) ..
            ": expected ." .. expected_extension, true)
        return
    end

    SaveLastExportPath(path)
    import_data = parsed
    import_mode = 1
    open_import_modal = true
end

local function GetImportDescription(data_type)
    if data_type == "item" then
        return "Add to selected group"
    elseif data_type == "group" then
        return "This group will be added to the group list."
    elseif data_type == "all" then
        return "Choose how to import the library contents."
    end
    return "Unknown import type."
end

---------------------------------------------------------------------------
-- OLD FORMAT MIGRATION (seconds → QN)
---------------------------------------------------------------------------

local function IsDataBeatBased(data_str)
    if data_str and data_str:match("^QN[123]:") then
        return true
    end
    return false
end

local function ConvertOldDataToQN(data_str)
    if not data_str or data_str == "" then return data_str end
    if IsDataBeatBased(data_str) then return data_str end
    local new_parts = {}
    for S in data_str:gmatch("{{.-}{.-}{.-}{.-}}") do
        local pos, rgnend, name, color = S:match("{{(.-)}{(.-)}{(.-)}{(.-)}}")
        if pos then
            local pos_num    = tonumber(pos)
            local rgnend_num = tonumber(rgnend)
            if pos_num and rgnend_num then
                local pos_qn = TimeToBeatPos(pos_num)
                local end_qn = TimeToBeatPos(rgnend_num)
                table.insert(new_parts, '{{' .. string.format("%.10f", pos_qn) .. '}{' ..
                    string.format("%.10f", end_qn) .. '}{' .. name .. '}{' .. color .. '}}')
            end
        end
    end
    if #new_parts > 0 then
        return "QN:" .. table.concat(new_parts, "")
    end
    return data_str
end

local function MigrateGroupsToQN()
    local changed = false
    for _, group in ipairs(groups) do
        for _, item in ipairs(group.items) do
            if item.data and not IsDataBeatBased(item.data) then
                item.data = ConvertOldDataToQN(item.data)
                changed   = true
            end
        end
    end
    if changed then
        SaveGroups()
    end
end

local function ApplyImport(mode)
    if not import_data then return end
    local data_type    = import_data.data_type
    local data         = import_data.data
    local is_qn_format = (import_data.format == "qn")

    if data_type == "all" then
        local imported_groups = DeserializeGroups(data)
        if #imported_groups == 0 then
            ShowToast("No valid data found", true)
            return
        end
        if not is_qn_format then
            for _, group in ipairs(imported_groups) do
                for _, item in ipairs(group.items) do
                    if item.data and not IsDataBeatBased(item.data) then
                        item.data = ConvertOldDataToQN(item.data)
                    end
                end
            end
        end
        if mode == 2 then
            groups = imported_groups
            selected_group_index = 1
            active_slot_index    = 0
            active_slot_group    = 0
        else
            for _, g in ipairs(imported_groups) do
                table.insert(groups, g)
            end
        end
    elseif data_type == "group" then
        local imported_groups = DeserializeGroups(data)
        if #imported_groups == 0 then
            ShowToast("No valid data found", true)
            return
        end
        if not is_qn_format then
            for _, group in ipairs(imported_groups) do
                for _, item in ipairs(group.items) do
                    if item.data and not IsDataBeatBased(item.data) then
                        item.data = ConvertOldDataToQN(item.data)
                    end
                end
            end
        end
        for _, g in ipairs(imported_groups) do
            table.insert(groups, g)
        end
    elseif data_type == "item" then
        local new_item = DeserializeItem(data)
        if not new_item then
            ShowToast("Invalid item data", true)
            return
        end
        if not is_qn_format and new_item.data and not IsDataBeatBased(new_item.data) then
            new_item.data = ConvertOldDataToQN(new_item.data)
        end
        if selected_group_index >= 1 and selected_group_index <= #groups then
            local target_group = groups[selected_group_index]
            if target_group and target_group.items then
                table.insert(target_group.items, new_item)
            end
        end
    else
        ShowToast("Unknown data type", true)
        return
    end
    SaveGroups()
    ShowToast("Import successful!")
end

LoadGroups()
MigrateGroupsToQN()

---------------------------------------------------------------------------
-- GET CURRENT REGIONS AND RULER LANES (saves as QN)
---------------------------------------------------------------------------

local function GetCurrentRulerLaneCount()
    local info_ok, info_count = false, nil
    if r.GetSetProjectInfo then
        info_ok, info_count = pcall(r.GetSetProjectInfo, 0, "RULER_LANE_COUNT", 0, false)
        if info_ok and type(info_count) == "number" and info_count > 0 then
            return math.floor(info_count + 0.5)
        end
    end

    -- RULER_LANE_COUNT was added after the first ruler-lane API. On those
    -- versions, count existing lanes through RULER_LANE_TYPE instead.
    if r.GetSetProjectInfo_String then
        local found_count = 0
        for i = 0, 128 do
            local ok_type, lane_exists = pcall(r.GetSetProjectInfo_String, 0, "RULER_LANE_TYPE:" .. i, "", false)
            if not ok_type or not lane_exists then break end
            found_count = i + 1
        end
        if found_count > 0 then return found_count end
    end

    if info_ok and type(info_count) == "number" and info_count >= 0 then
        return math.floor(info_count + 0.5)
    end
    return nil
end

local function GetRulerLaneTypes(lane_count)
    if not lane_count or lane_count <= 0 or not r.GetSetProjectInfo_String then return nil end

    local lane_types = {}
    for i = 0, lane_count - 1 do
        local ok_call, retval, lane_type = pcall(
            r.GetSetProjectInfo_String, 0, "RULER_LANE_TYPE:" .. i, "", false
        )
        if ok_call and retval and lane_type and lane_type ~= "" then
            lane_types[#lane_types + 1] = lane_type
        else
            return nil
        end
    end
    return table.concat(lane_types, ",")
end

local function SetRulerLaneCount(target_count, lane_types_str)
    if target_count == nil or target_count < 0 then return end
    target_count = math.floor(target_count + 0.5)

    local current_count = GetCurrentRulerLaneCount()

    -- Create missing lanes explicitly. This also works in REAPER versions
    -- where RULER_LANE_COUNT is not available as a settable value.
    if current_count and current_count < target_count and r.GetSetProjectInfo_String then
        for i = current_count, target_count - 1 do
            pcall(r.GetSetProjectInfo_String, 0, "RULER_LANE_TYPE:" .. i, "region", true)
        end
    end

    if r.GetSetProjectInfo then
        pcall(r.GetSetProjectInfo, 0, "RULER_LANE_COUNT", target_count, true)
    end

    if lane_types_str and r.GetSetProjectInfo_String then
        local lane_types = {}
        for lane_type in lane_types_str:gmatch("[^,]+") do
            lane_types[#lane_types + 1] = lane_type
        end
        for i = 0, target_count - 1 do
            local lane_type = lane_types[i + 1]
            if lane_type == "region" or lane_type == "marker" then
                pcall(r.GetSetProjectInfo_String, 0, "RULER_LANE_TYPE:" .. i, lane_type, true)
            end
        end
    end

    -- Removing a lane is supported by the ruler-lane type setter in newer
    -- REAPER versions. Work from the bottom so lane numbers below the target
    -- stay unchanged for the regions that are about to be inserted.
    current_count = GetCurrentRulerLaneCount()
    if current_count and current_count > target_count and r.GetSetProjectInfo_String then
        for i = current_count - 1, target_count, -1 do
            pcall(r.GetSetProjectInfo_String, 0, "RULER_LANE_TYPE:" .. i, "", true)
        end
    end

    if r.GetSetProjectInfo then
        pcall(r.GetSetProjectInfo, 0, "RULER_LANE_COUNT", target_count, true)
    end
    if r.UpdateTimeline then
        r.UpdateTimeline()
    end
end

local function GetRegionLaneNumber(markrgn_index_number)
    if not r.GetRegionOrMarker or not r.GetRegionOrMarkerInfo_Value then return 0 end

    -- EnumProjectMarkers3 returns the displayed marker/region number, while
    -- GetRegionOrMarker(index, "") expects an internal index. Resolve the
    -- object through its GUID so markers and regions can be interleaved.
    if not r.GetSetProjectInfo_String then return 0 end
    local ok_guid, guid_ok, guid = pcall(
        r.GetSetProjectInfo_String, 0, "MARKER_GUID:" .. tostring(markrgn_index_number), "", false
    )
    if not ok_guid or not guid_ok or not guid or guid == "" then return 0 end

    local ok_object, region_object = pcall(r.GetRegionOrMarker, 0, -1, guid)
    if not ok_object or not region_object then return 0 end
    local ok_lane, lane_number = pcall(r.GetRegionOrMarkerInfo_Value, 0, region_object, "I_LANENUMBER")
    if not ok_lane or type(lane_number) ~= "number" then return 0 end
    return math.max(0, math.floor(lane_number + 0.5))
end

local function GetCurrentRegions()
    local num, _, num_regions = r.CountProjectMarkers(0)
    local lane_count = GetCurrentRulerLaneCount()
    if num_regions == 0 and (lane_count == nil or lane_count == 0) then return nil end

    local lane_types = GetRulerLaneTypes(lane_count)
    local regions_data
    if lane_count ~= nil and lane_types then
        regions_data = "QN3:" .. lane_count .. ":" .. lane_types .. ":"
    elseif lane_count ~= nil then
        regions_data = "QN2:" .. lane_count .. ":"
    else
        regions_data = "QN:"
    end
    for i = 0, num - 1 do
        local _, isrgn, pos, rgnend, rname, markrgn_index_number, color = r.EnumProjectMarkers3(0, i)
        if isrgn then
            local pos_qn = TimeToBeatPos(pos)
            local end_qn = TimeToBeatPos(rgnend)
            local record = '{{' ..
                string.format("%.10f", pos_qn) .. '}{' ..
                string.format("%.10f", end_qn) .. '}{' ..
                rname .. '}{' .. color
            if lane_count ~= nil then
                record = record .. '}{' .. GetRegionLaneNumber(markrgn_index_number)
            end
            regions_data = regions_data .. record .. '}}'
        end
    end
    if regions_data == "QN:" then
        return nil
    end
    return regions_data
end

local function GetCurrentRegionIDs()
    local region_ids = {}
    local total = r.CountProjectMarkers(0)
    for i = 0, total - 1 do
        local _, isrgn, _, _, _, markrgn_index_number = r.EnumProjectMarkers3(0, i)
        if isrgn and markrgn_index_number then
            region_ids[#region_ids + 1] = markrgn_index_number
        end
    end
    return region_ids
end

---------------------------------------------------------------------------
-- INSERT TEMPLATE (QN → time via current tempo map)
---------------------------------------------------------------------------

local function InsertTemplate(item, slot_idx, group_idx)
    if not item or not item.data then return end
    local region_ids = GetCurrentRegionIDs()
    if #region_ids > 0 and delete_prev_regions then
        for i = #region_ids, 1, -1 do
            r.DeleteProjectMarker(0, region_ids[i], true)
        end
    end

    local data   = item.data
    local lane_count, lane_types_str = data:match("^QN3:(%d+):([^:]*):")
    lane_count = tonumber(lane_count)
    if not lane_count then
        lane_count = tonumber(data:match("^QN2:(%d+):"))
    end
    local has_lane_data = lane_count ~= nil
    local is_qn  = IsDataBeatBased(data)

    local parse_data = data
    if lane_types_str then
        parse_data = data:match("^QN3:%d+:[^:]*:(.*)$") or ""
    elseif has_lane_data then
        parse_data = data:match("^QN2:%d+:(.*)$") or ""
    elseif is_qn then
        parse_data = data:sub(4)
    end

    local regions = {}
    local min_qn  = math.huge
    local function AddParsedRegion(pos_str, end_str, name, color, lane)
        if not pos_str then return end
        local pos_val = tonumber(pos_str)
        local end_val = tonumber(end_str)
        if not pos_val or not end_val then return end

        if is_qn then
            table.insert(regions, {
                pos_qn = pos_val,
                end_qn = end_val,
                name = name,
                color = tonumber(color) or 0,
                lane = lane,
            })
            if pos_val < min_qn then min_qn = pos_val end
        else
            local pqn = TimeToBeatPos(pos_val)
            local eqn = TimeToBeatPos(end_val)
            table.insert(regions, {
                pos_qn = pqn,
                end_qn = eqn,
                name = name,
                color = tonumber(color) or 0,
                lane = lane,
            })
            if pqn < min_qn then min_qn = pqn end
        end
    end

    if has_lane_data then
        for S in parse_data:gmatch("{{.-}{.-}{.-}{.-}{.-}}") do
            local pos_str, end_str, name, color, lane = S:match("{{(.-)}{(.-)}{(.-)}{(.-)}{(.-)}}")
            AddParsedRegion(pos_str, end_str, name, color, tonumber(lane) or 0)
        end
    else
        for S in parse_data:gmatch("{{.-}{.-}{.-}{.-}}") do
            local pos_str, end_str, name, color = S:match("{{(.-)}{(.-)}{(.-)}{(.-)}}")
            AddParsedRegion(pos_str, end_str, name, color, nil)
        end
    end

    if lane_count ~= nil then
        SetRulerLaneCount(lane_count, lane_types_str)
    end

    local offset_qn = 0
    if insert_at_cursor and min_qn ~= math.huge then
        local cursor_pos = r.GetCursorPosition()
        local cursor_qn  = TimeToBeatPos(cursor_pos)
        offset_qn = cursor_qn - min_qn
    end

    r.Undo_BeginBlock()
    for _, region in ipairs(regions) do
        local final_pos = BeatPosToTime(region.pos_qn + offset_qn)
        local final_end = BeatPosToTime(region.end_qn + offset_qn)
        local region_object

        if r.AddRegionOrMarker then
            local ok_add, object = pcall(r.AddRegionOrMarker, 0, true, final_pos, final_end, region.name, -1, region.color)
            if ok_add then
                region_object = object
            end
        end

        if not region_object then
            r.AddProjectMarker2(0, true, final_pos, final_end, region.name, -1, region.color)
        elseif region.lane ~= nil and r.SetRegionOrMarkerInfo_Value then
            pcall(r.SetRegionOrMarkerInfo_Value, 0, region_object, "I_LANENUMBER", region.lane)
        end
    end
    r.Undo_EndBlock("Insert Region Template", -1)
    if lane_count ~= nil then
        -- Assigning a region to a lane can make REAPER recreate a missing
        -- lane, so enforce the template count once more after insertion.
        SetRulerLaneCount(lane_count, lane_types_str)
    end
    if r.UpdateTimeline then
        r.UpdateTimeline()
    end

    active_slot_index = slot_idx or 0
    active_slot_group = group_idx or 0
    SaveGroups()

    if zoom_to_regions then
        ZoomToRegions()
    end
end

local function ClearProjectRegions()
    local region_ids = GetCurrentRegionIDs()
    if #region_ids > 0 then
        r.Undo_BeginBlock()
        for i = #region_ids, 1, -1 do
            r.DeleteProjectMarker(0, region_ids[i], true)
        end
        r.Undo_EndBlock("Clear All Regions", -1)
    end
end

local function DeleteAllProjectRegionsWithSWS()
    if not r.NamedCommandLookup or not r.Main_OnCommand then
        ShowToast("SWS action is not available", true)
        return false
    end

    local command_id = r.NamedCommandLookup(SWS_DELETE_ALL_REGIONS_ACTION)
    if not command_id or command_id == 0 then
        ShowToast("SWS: Delete all regions action not found", true)
        return false
    end

    r.Main_OnCommand(command_id, 0)
    return true
end

local function IsAnyInputActive()
    return r.ImGui_IsAnyItemActive(ctx)
end

local function IsAnyPopupOpen()
    return r.ImGui_IsPopupOpen(ctx, "", r.ImGui_PopupFlags_AnyPopupId() + r.ImGui_PopupFlags_AnyPopupLevel())
end

local function QueueColorMarker(item_color, line_y, line_h, panel_right_x)
    if not show_color_markers or not item_color or item_color == 0 then return end
    local col = ITEM_COLORS[item_color + 1]
    if not col then return end
    local x = panel_right_x - MARKER_SIZE - 8
    local y = line_y + line_h / 2 - 1
    table.insert(pending_markers, { x = x, y = y, color = col.color })
end

local function DrawPendingMarkers()
    if not show_color_markers or #pending_markers == 0 then return end
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    for _, marker in ipairs(pending_markers) do
        r.ImGui_DrawList_AddCircleFilled(draw_list, marker.x, marker.y, MARKER_SIZE, marker.color, 16)
    end
    pending_markers = {}
end

local function DrawToast()
    if not toast_message then return end
    local elapsed = r.time_precise() - toast_time
    if elapsed > toast_duration then
        toast_message = nil
        return
    end
    local alpha = 1.0
    if elapsed > toast_duration - 0.5 then
        alpha = (toast_duration - elapsed) / 0.5
    end
    local win_x, win_y   = r.ImGui_GetWindowPos(ctx)
    local win_w, win_h   = r.ImGui_GetWindowSize(ctx)
    local text_w         = r.ImGui_CalcTextSize(ctx, toast_message)
    local padding        = 12
    local toast_w        = text_w + padding * 2
    local toast_h        = 28
    local toast_x        = win_x + (win_w - toast_w) / 2
    local toast_y        = win_y + win_h - toast_h - 10
    local draw_list      = r.ImGui_GetForegroundDrawList(ctx)
    local bg_alpha       = math.floor(0xEE * alpha)
    local bg_color       = (theme.ToastBg & 0xFFFFFF00) | bg_alpha
    r.ImGui_DrawList_AddRectFilled(draw_list, toast_x, toast_y, toast_x + toast_w, toast_y + toast_h, bg_color, 6)
    local border_color   = toast_is_error and theme.ToastError or theme.ToastSuccess
    local border_alpha   = math.floor(0xFF * alpha)
    border_color         = (border_color & 0xFFFFFF00) | border_alpha
    r.ImGui_DrawList_AddRect(draw_list, toast_x, toast_y, toast_x + toast_w, toast_y + toast_h, border_color, 6, 0, 2)
    local text_alpha     = math.floor(0xFF * alpha)
    local text_color     = (theme.Text & 0xFFFFFF00) | text_alpha
    local text_x         = toast_x + padding
    local text_y         = toast_y + (toast_h - r.ImGui_GetTextLineHeight(ctx)) / 2
    r.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, toast_message)
end

local function ProcessPendingSaves()
    if pending_save_layout and (r.time_precise() - pending_save_layout_time) > SAVE_DELAY then
        SaveLayoutSettingsImmediate()
    end
end

local has_js_api = r.JS_Dialog_BrowseForSaveFile ~= nil
local last_w, last_h = 0, 0
local last_x, last_y = nil, nil

local function DrawHelpShortcut(key, description, highlighted)
    local shortcut_color = highlighted and theme.ActivePreset or theme.Text
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), shortcut_color)
    r.ImGui_Text(ctx, "●")
    r.ImGui_SameLine(ctx, 0, 4)
    r.ImGui_Text(ctx, key)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_SameLine(ctx, 0, 8)
    r.ImGui_Text(ctx, "- " .. description)
end

local function loop()
    disableKeyboardNav(ctx)
    local window_flags = r.ImGui_WindowFlags_MenuBar()
    if r.ImGui_WindowFlags_NoCollapse then
        window_flags = window_flags | r.ImGui_WindowFlags_NoCollapse()
    end
    if r.ImGui_WindowFlags_NoNav then
        window_flags = window_flags | r.ImGui_WindowFlags_NoNav()
    end
    if r.ImGui_WindowFlags_NoNavFocus then
        window_flags = window_flags | r.ImGui_WindowFlags_NoNavFocus()
    end
    if lock_position then
        window_flags = window_flags | r.ImGui_WindowFlags_NoMove() | r.ImGui_WindowFlags_NoResize()
    end
    if no_docking then
        window_flags = window_flags | r.ImGui_WindowFlags_NoDocking()
    end

    r.ImGui_PushFont(ctx, font, FONT_SIZE)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize(),        4)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameBorderSize(),      0)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowBorderSize(),     0)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(),        3)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(),          6, layout.item_spacing)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ChildBorderSize(),      0)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_SelectableTextAlign(),  0, 0)
    RefreshThemeColors()
    applyTheme()

    if first_frame then
        if saved_window_x ~= nil and saved_window_y ~= nil then
            r.ImGui_SetNextWindowPos(ctx, saved_window_x, saved_window_y, r.ImGui_Cond_Always())
        end
        r.ImGui_SetNextWindowSize(ctx, saved_window_w, saved_window_h, r.ImGui_Cond_FirstUseEver())
        first_frame = false
    end

    r.ImGui_SetNextWindowSizeConstraints(ctx, MIN_WINDOW_W, MIN_WINDOW_H, 16384, 16384)

    local window_title = "✦ Region Templates"
    if not show_folders_panel then
        local active_group = groups[selected_group_index]
        if active_group and active_group.name and active_group.name ~= "" then
            window_title = window_title .. " (" .. active_group.name .. ")"
        end
    end

    local visible, open = r.ImGui_Begin(ctx, window_title .. "###RegionTemplatesMain", true, window_flags)
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape(), false) then
        open = false
    end
    if visible then
        local cur_x, cur_y = r.ImGui_GetWindowPos(ctx)
        cur_x = math.floor(cur_x + 0.5)
        cur_y = math.floor(cur_y + 0.5)
        if cur_x ~= last_x or cur_y ~= last_y then
            last_x, last_y = cur_x, cur_y
            saved_window_x, saved_window_y = cur_x, cur_y
            SaveWindowPosition(cur_x, cur_y)
        end

        local cur_w, cur_h = r.ImGui_GetWindowSize(ctx)
        if cur_w ~= last_w or cur_h ~= last_h then
            last_w, last_h = cur_w, cur_h
            SaveWindowSize(cur_w, cur_h)
        end

        if not IsAnyInputActive() and not IsAnyPopupOpen() then
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Space()) then
                r.Main_OnCommand(40044, 0)
            end
            if r.ImGui_Key_Delete and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete()) then
                DeleteAllProjectRegionsWithSWS()
            end
            local ctrl = r.ImGui_IsKeyDown(ctx, r.ImGui_Mod_Ctrl())
            if ctrl and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z()) then
                r.Main_OnCommand(40029, 0)
            end
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Tab(), false) then
                show_folders_panel = not show_folders_panel
                SaveLayoutSettings()
            end
        end

        -- ----------------------------------------------------------------
        -- MENU BAR
        -- ----------------------------------------------------------------
            if r.ImGui_BeginMenuBar(ctx) then
                if r.ImGui_MenuItem(ctx, "Save") then
                    local regions_data = GetCurrentRegions()
                    if regions_data then
                        pending_save_data    = regions_data
                        save_template_buf    = "New Template"
                        open_save_template_modal = true
                    end
                end
                if r.ImGui_BeginMenu(ctx, "Layout") then
                local changed_cursor, new_cursor = r.ImGui_MenuItem(ctx, "Insert at Edit Cursor", nil, insert_at_cursor)
                if changed_cursor then
                    insert_at_cursor = new_cursor
                    SaveSettings()
                end
                local changed_del, new_del = r.ImGui_MenuItem(ctx, "Delete regions before insert", nil, delete_prev_regions)
                if changed_del then
                    delete_prev_regions = new_del
                    SaveSettings()
                end
                local changed_zoom, new_zoom = r.ImGui_MenuItem(ctx, "Zoom to regions after insert", nil, zoom_to_regions)
                if changed_zoom then
                    zoom_to_regions = new_zoom
                    SaveSettings()
                end
                r.ImGui_Separator(ctx)

                local changed_markers, new_markers = r.ImGui_MenuItem(ctx, "Show Color Markers", nil, show_color_markers)
                if changed_markers then
                    show_color_markers = new_markers
                    SaveLayoutSettings()
                end
                local changed_nums, new_nums = r.ImGui_MenuItem(ctx, "Show Item Numbers", nil, show_item_numbers)
                if changed_nums then
                    show_item_numbers = new_nums
                    SaveLayoutSettings()
                end
                r.ImGui_Separator(ctx)

                local changed_lock, new_lock = r.ImGui_MenuItem(ctx, "Lock position and size", nil, lock_position)
                if changed_lock then
                    lock_position = new_lock
                    SaveSettings()
                end

                r.ImGui_Separator(ctx)
                r.ImGui_TextDisabled(ctx, "Appearance")
                local changed_background, new_background = r.ImGui_ColorEdit3(
                    ctx,
                    "Background Color##appearance_background",
                    ColorRGBAtoRGB(background_color),
                    r.ImGui_ColorEditFlags_NoInputs()
                )
                if changed_background then
                    background_color = ColorRGBtoRGBA(new_background)
                    SaveAppearanceSettings()
                end

                local changed_accent, new_accent = r.ImGui_ColorEdit3(
                    ctx,
                    "Accent Color##appearance_accent",
                    ColorRGBAtoRGB(accent_color),
                    r.ImGui_ColorEditFlags_NoInputs()
                )
                if changed_accent then
                    accent_color = ColorRGBtoRGBA(new_accent)
                    SaveAppearanceSettings()
                end

                local changed_text, new_text = r.ImGui_ColorEdit3(
                    ctx,
                    "Text Color##appearance_text",
                    ColorRGBAtoRGB(text_color),
                    r.ImGui_ColorEditFlags_NoInputs()
                )
                if changed_text then
                    text_color = ColorRGBtoRGBA(new_text)
                    SaveAppearanceSettings()
                end

                if r.ImGui_MenuItem(ctx, "Default") then
                    background_color = DEFAULT_BACKGROUND_COLOR
                    accent_color = DEFAULT_ACCENT_COLOR
                    text_color = DEFAULT_TEXT_COLOR
                    SaveAppearanceSettings()
                end

                r.ImGui_EndMenu(ctx)
            end

            if r.ImGui_BeginMenu(ctx, "Import") then
                if not has_js_api then
                    r.ImGui_TextDisabled(ctx, "Requires js_ReaScriptAPI")
                else
                    if r.ImGui_MenuItem(ctx, "Import from File...") then
                        ImportFile()
                    end
                end
                r.ImGui_EndMenu(ctx)
            end

            if r.ImGui_BeginMenu(ctx, "Export") then
                if not has_js_api then
                    r.ImGui_TextDisabled(ctx, "Requires js_ReaScriptAPI")
                else
                    if r.ImGui_MenuItem(ctx, "Export All...") then
                        ExportAll()
                    end
                    if r.ImGui_MenuItem(ctx, "Export Current Group...") then
                        ExportGroup(selected_group_index)
                    end
                end
                r.ImGui_EndMenu(ctx)
            end

            if r.ImGui_BeginMenu(ctx, "Help") then
                r.ImGui_TextDisabled(ctx, "Keyboard shortcuts")
                DrawHelpShortcut("Tab", "Show or hide the groups panel")
                DrawHelpShortcut("Escape", "Close the script completely")
                DrawHelpShortcut("Up / Down", "Browse templates")

                r.ImGui_Separator(ctx)
                r.ImGui_TextDisabled(ctx, "RGT file formats")
                r.ImGui_Text(ctx, ".rgti  Item - one template")
                r.ImGui_Text(ctx, ".rgtg  Group - one group")
                r.ImGui_Text(ctx, ".rgt   Library - all groups")

                r.ImGui_Separator(ctx)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), accent_color)
                r.ImGui_Text(ctx, "✦ Made by Andrew Dihtiaruk")
                r.ImGui_PopStyleColor(ctx)

                r.ImGui_Text(ctx, "✦ Support Ko-Fi")
                if r.ImGui_IsItemHovered(ctx) then
                    if r.ImGui_SetMouseCursor and r.ImGui_MouseCursor_Hand then
                        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_Hand())
                    end
                    if r.ImGui_IsItemClicked(ctx) then
                        if r.CF_ShellExecute then
                            r.CF_ShellExecute("https://ko-fi.com/pianohousestudio")
                        elseif r.ExecProcess then
                            r.ExecProcess('cmd.exe /c start "" "https://ko-fi.com/pianohousestudio"', 0)
                        end
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            r.ImGui_EndMenuBar(ctx)
        end

        -- ----------------------------------------------------------------
        -- KEYBOARD NAVIGATION
        -- ----------------------------------------------------------------
        local cur_group = nil
        if selected_group_index >= 1 and selected_group_index <= #groups then
            cur_group = groups[selected_group_index]
        end

        if not IsAnyInputActive() and not IsAnyPopupOpen() and cur_group and type(cur_group.items) == "table" and #cur_group.items > 0 then
            local key_up   = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow())
            local key_down = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow())
            if key_up or key_down then
                local current_idx = 0
                if active_slot_group == selected_group_index then
                    current_idx = active_slot_index
                end
                local total_items = #cur_group.items
                if key_up then
                    current_idx = current_idx - 1
                    if current_idx < 1 then current_idx = total_items end
                elseif key_down then
                    current_idx = current_idx + 1
                    if current_idx > total_items then current_idx = 1 end
                end
                local item = cur_group.items[current_idx]
                if item then
                    InsertTemplate(item, current_idx, selected_group_index)
                end
            end
        end

        -- ----------------------------------------------------------------
        -- LAYOUT: folders panel + divider + items panel
        -- ----------------------------------------------------------------
        local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
        local content_start_x, content_start_y = r.ImGui_GetCursorScreenPos(ctx)

        if show_folders_panel then
            local effective_panel_w = math.min(layout.groups_panel_w, avail_w - MIN_PANEL_W - DIVIDER_WIDTH)
            effective_panel_w = math.max(effective_panel_w, MIN_PANEL_W)

            local groups_panel_visible = r.ImGui_BeginChild(ctx, "GroupsPanel", effective_panel_w, 0)
            if groups_panel_visible then
                for i = 1, #groups do
                    local group = groups[i]
                    if group then
                        local selected    = (i == selected_group_index)
                        local display_name = "  " .. group.name
                        r.ImGui_Selectable(ctx, display_name, selected)
                        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
                            r.ImGui_SetDragDropPayload(ctx, 'DND_GROUP', tostring(i))
                            r.ImGui_Text(ctx, group.name)
                            r.ImGui_EndDragDropSource(ctx)
                        end
                        if r.ImGui_BeginDragDropTarget(ctx) then
                            local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND_GROUP')
                            if retval then
                                local source_idx = tonumber(payload)
                                local target_idx = i
                                if source_idx and target_idx and source_idx ~= target_idx then
                                    local moved_group = table.remove(groups, source_idx)
                                    table.insert(groups, target_idx, moved_group)
                                    if selected_group_index == source_idx then
                                        selected_group_index = target_idx
                                    elseif source_idx < selected_group_index and target_idx >= selected_group_index then
                                        selected_group_index = selected_group_index - 1
                                    elseif source_idx > selected_group_index and target_idx <= selected_group_index then
                                        selected_group_index = selected_group_index + 1
                                    end
                                    SaveGroups()
                                end
                            end
                            local retval_item, payload_item = r.ImGui_AcceptDragDropPayload(ctx, 'DND_ITEM')
                            if retval_item then
                                local item_idx = tonumber(payload_item)
                                if item_idx then
                                    local source_group = groups[selected_group_index]
                                    local target_group = groups[i]
                                    if source_group and target_group and source_group ~= target_group then
                                        local moved_item = table.remove(source_group.items, item_idx)
                                        table.insert(target_group.items, moved_item)
                                        active_slot_index = 0
                                        SaveGroups()
                                    end
                                end
                            end
                            r.ImGui_EndDragDropTarget(ctx)
                        end
                        if r.ImGui_IsItemClicked(ctx) then
                            selected_group_index = i
                        end
                        if r.ImGui_BeginPopupContextItem(ctx, "group_ctx_menu_" .. i) then
                            if r.ImGui_MenuItem(ctx, "Rename Group") then
                                rename_group_index = i
                                rename_group_buf   = group.name
                                open_rename_group_modal = true
                            end
                            if r.ImGui_MenuItem(ctx, "Delete Group") then
                                pending_delete_group = i
                            end
                            if has_js_api then
                                r.ImGui_Separator(ctx)
                                if r.ImGui_MenuItem(ctx, "Export...") then
                                    pending_export_group = i
                                end
                            end
                            r.ImGui_EndPopup(ctx)
                        end
                    end
                end
                r.ImGui_Spacing(ctx)
                if r.ImGui_Button(ctx, "+", 18, 18) then
                    new_group_buf        = "New Group"
                    open_new_group_modal = true
                end
            end
            r.ImGui_EndChild(ctx)

            r.ImGui_SameLine(ctx, 0, 0)

            local divider_x = content_start_x + effective_panel_w
            local divider_y = content_start_y
            local divider_h = avail_h

            r.ImGui_SetCursorScreenPos(ctx, divider_x, divider_y)
            r.ImGui_InvisibleButton(ctx, "##divider", DIVIDER_WIDTH, divider_h)

            local is_hovered = r.ImGui_IsItemHovered(ctx)
            local is_active  = r.ImGui_IsItemActive(ctx)

            if is_active then
                if not is_dragging_divider then
                    is_dragging_divider = true
                    local mx, _ = r.ImGui_GetMousePos(ctx)
                    drag_start_x = mx
                    drag_start_w = layout.groups_panel_w
                end
                local mx, _ = r.ImGui_GetMousePos(ctx)
                local delta  = mx - drag_start_x
                local new_w  = drag_start_w + delta
                new_w = math.max(MIN_PANEL_W, new_w)
                new_w = math.min(avail_w - MIN_PANEL_W - DIVIDER_WIDTH, new_w)
                if new_w ~= layout.groups_panel_w then
                    layout.groups_panel_w = new_w
                    SaveLayoutSettings()
                end
            else
                is_dragging_divider = false
            end

            local draw_list    = r.ImGui_GetWindowDrawList(ctx)
            local line_x       = divider_x + DIVIDER_WIDTH / 2
            local divider_color = theme.Divider
            if is_active then
                divider_color = theme.DividerActive
            elseif is_hovered then
                divider_color = theme.DividerHovered
            end
            r.ImGui_DrawList_AddLine(draw_list, line_x, divider_y, line_x, divider_y + divider_h, divider_color, 2)

            if is_hovered or is_active then
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())
            end

            r.ImGui_SameLine(ctx, 0, 0)
        end

        -- ----------------------------------------------------------------
        -- ITEMS PANEL
        -- ----------------------------------------------------------------
        local items_panel_visible = r.ImGui_BeginChild(ctx, "ItemsPanel", 0, 0)
        if items_panel_visible then
            if selected_group_index < 1 or selected_group_index > #groups then
                selected_group_index = 1
            end
            cur_group = groups[selected_group_index]

            local panel_x, panel_y   = r.ImGui_GetWindowPos(ctx)
            local panel_w, panel_h   = r.ImGui_GetWindowSize(ctx)
            local panel_right_x      = panel_x + panel_w - 10
            local items_avail_w      = r.ImGui_GetContentRegionAvail(ctx)

            pending_markers = {}

            if cur_group and type(cur_group.items) == "table" then
                local items_to_delete = {}
                for i = 1, #cur_group.items do
                    local item = cur_group.items[i]
                    if item and type(item) == "table" then
                        local item_color = item.color or 0
                        r.ImGui_PushID(ctx, i)
                        local is_active_slot = (active_slot_group == selected_group_index and active_slot_index == i)
                        local display_name   = item.name or "Template"
                        if display_name == "" then display_name = "Template" end
                        if show_item_numbers then
                            display_name = string.format("%d. %s", i, display_name)
                        end
                        display_name = "  " .. display_name
                        local cursor_x, cursor_y = r.ImGui_GetCursorScreenPos(ctx)
                        local line_h             = r.ImGui_GetTextLineHeight(ctx)
                        QueueColorMarker(item_color, cursor_y, line_h + layout.item_spacing, panel_right_x)
                        if is_active_slot then
                            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), theme.ActivePreset)
                        end
                        local clicked = r.ImGui_Selectable(ctx, display_name, is_active_slot)
                        if is_active_slot then
                            r.ImGui_PopStyleColor(ctx)
                        end
                        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_None()) then
                            r.ImGui_SetDragDropPayload(ctx, 'DND_ITEM', tostring(i))
                            r.ImGui_Text(ctx, item.name or "Template")
                            r.ImGui_EndDragDropSource(ctx)
                        end
                        if r.ImGui_BeginDragDropTarget(ctx) then
                            local retval, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND_ITEM')
                            if retval then
                                local source_idx = tonumber(payload)
                                local target_idx = i
                                if source_idx and target_idx and source_idx ~= target_idx then
                                    local moved_item = table.remove(cur_group.items, source_idx)
                                    table.insert(cur_group.items, target_idx, moved_item)
                                    active_slot_index = 0
                                    SaveGroups()
                                end
                            end
                            r.ImGui_EndDragDropTarget(ctx)
                        end
                        if clicked then
                            InsertTemplate(item, i, selected_group_index)
                        end
                        if r.ImGui_BeginPopupContextItem(ctx, "item_ctx_menu") then
                            r.ImGui_Text(ctx, "Color:")
                            local draw_list      = r.ImGui_GetWindowDrawList(ctx)
                            local radius         = 6
                            local ctx_spacing    = 4
                            local border_thickness = 2
                            local text_h         = r.ImGui_GetTextLineHeight(ctx)
                            for ci = 1, #ITEM_COLORS do
                                local col_info   = ITEM_COLORS[ci]
                                local is_selected = (item_color == ci - 1)
                                r.ImGui_SameLine(ctx, 0, ctx_spacing)
                                local ctx_cursor_x, ctx_cursor_y = r.ImGui_GetCursorScreenPos(ctx)
                                local center_x   = ctx_cursor_x + radius
                                local center_y   = ctx_cursor_y + text_h / 2
                                if ci == 1 then
                                    r.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, 0x444444FF, 16)
                                else
                                    r.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, col_info.color, 16)
                                end
                                if is_selected then
                                    r.ImGui_DrawList_AddCircle(draw_list, center_x, center_y, radius + 1, 0xFFFFFFFF, 16, border_thickness)
                                end
                                r.ImGui_InvisibleButton(ctx, "##col" .. ci, radius * 2, text_h)
                                if r.ImGui_IsItemClicked(ctx) then
                                    item.color = ci - 1
                                    SaveGroups()
                                end
                            end
                            r.ImGui_Separator(ctx)
                            if r.ImGui_MenuItem(ctx, "Rename") then
                                rename_item_index = i
                                rename_item_buf   = item.name or ""
                                open_rename_item_modal = true
                            end
                            if r.ImGui_MenuItem(ctx, "Delete") then
                                table.insert(items_to_delete, i)
                            end
                            if has_js_api then
                                r.ImGui_Separator(ctx)
                                if r.ImGui_MenuItem(ctx, "Export...") then
                                    pending_export_item = { group_index = selected_group_index, item_index = i }
                                end
                            end
                            r.ImGui_EndPopup(ctx)
                        end
                        r.ImGui_PopID(ctx)
                    end
                end
                DrawPendingMarkers()
                if #items_to_delete > 0 then
                    table.sort(items_to_delete, function(a, b) return a > b end)
                    for _, idx in ipairs(items_to_delete) do
                        table.remove(cur_group.items, idx)
                        if active_slot_group == selected_group_index and active_slot_index == idx then
                            active_slot_index = 0
                            active_slot_group = 0
                        elseif active_slot_group == selected_group_index and active_slot_index > idx then
                            active_slot_index = active_slot_index - 1
                        end
                    end
                    SaveGroups()
                end
                if #cur_group.items == 0 then
                    r.ImGui_Dummy(ctx, 0, 40)
                    local txt = "No templates"
                    local tw  = r.ImGui_CalcTextSize(ctx, txt)
                    r.ImGui_SetCursorPosX(ctx, (items_avail_w - tw) / 2)
                    r.ImGui_TextDisabled(ctx, txt)
                end
            end
        end
        r.ImGui_EndChild(ctx)

        DrawToast()

        if pending_delete_group then
            DeleteGroup(pending_delete_group)
            pending_delete_group = nil
        end
        if pending_export_group then
            ExportGroup(pending_export_group)
            pending_export_group = nil
        end
        if pending_export_item then
            ExportItem(pending_export_item.group_index, pending_export_item.item_index)
            pending_export_item = nil
        end

        -- ----------------------------------------------------------------
        -- MODALS
        -- ----------------------------------------------------------------
        local modal_flags = r.ImGui_WindowFlags_AlwaysAutoResize()

        if open_import_modal then
            r.ImGui_OpenPopup(ctx, "Import##RegionTemplatesImportPopup")
            open_import_modal = false
        end
        if r.ImGui_BeginPopupModal(ctx, "Import##RegionTemplatesImportPopup", true, modal_flags) then
            local import_type = import_data and GetImportTypeLabel(import_data.data_type) or "Unknown"
            r.ImGui_Text(ctx, "Import " .. import_type)
            r.ImGui_Spacing(ctx)

            if import_data and import_data.data_type == "all" then
                if r.ImGui_RadioButton(ctx, "Add groups to group list", import_mode == 1) then import_mode = 1 end
                if r.ImGui_RadioButton(ctx, "Replace entire group list", import_mode == 2) then import_mode = 2 end
            else
                r.ImGui_Text(ctx, GetImportDescription(import_data and import_data.data_type))
            end

            r.ImGui_Spacing(ctx)
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "Import", 120, 0) then
                ApplyImport(import_mode)
                import_data = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel", 120, 0) then
                import_data = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        if open_new_group_modal then
            r.ImGui_OpenPopup(ctx, "Add New Group")
            open_new_group_modal = false
        end
        if r.ImGui_BeginPopupModal(ctx, "Add New Group", true, modal_flags) then
            r.ImGui_SetNextItemWidth(ctx, 250)
            local changed, new_val = r.ImGui_InputText(ctx, "##new_group_input", new_group_buf, 256)
            if changed then new_group_buf = new_val end
            if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx, -1) end
            local enter_pressed = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter())
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "Create", 120, 0) or enter_pressed then
                if new_group_buf ~= "" then
                    table.insert(groups, { name = new_group_buf, items = {} })
                    selected_group_index = #groups
                    SaveGroups()
                end
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel", 120, 0) then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        if open_rename_group_modal then
            r.ImGui_OpenPopup(ctx, "Rename Group")
            open_rename_group_modal = false
        end
        if r.ImGui_BeginPopupModal(ctx, "Rename Group", true, modal_flags) then
            r.ImGui_SetNextItemWidth(ctx, 250)
            local changed, new_val = r.ImGui_InputText(ctx, "##rename_group_input", rename_group_buf, 256)
            if changed then rename_group_buf = new_val end
            if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx, -1) end
            local enter_pressed = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter())
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "OK", 120, 0) or enter_pressed then
                if rename_group_buf ~= "" and rename_group_index and groups[rename_group_index] then
                    groups[rename_group_index].name = rename_group_buf
                    SaveGroups()
                end
                rename_group_index = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel", 120, 0) then
                rename_group_index = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        if open_rename_item_modal then
            r.ImGui_OpenPopup(ctx, "Rename Template")
            open_rename_item_modal = false
        end
        if r.ImGui_BeginPopupModal(ctx, "Rename Template", true, modal_flags) then
            r.ImGui_SetNextItemWidth(ctx, 250)
            local changed, new_val = r.ImGui_InputText(ctx, "##rename_item_input", rename_item_buf, 256)
            if changed then rename_item_buf = new_val end
            if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx, -1) end
            local enter_pressed = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter())
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "OK", 120, 0) or enter_pressed then
                if rename_item_buf ~= "" and rename_item_index and cur_group and cur_group.items[rename_item_index] then
                    cur_group.items[rename_item_index].name = rename_item_buf
                    SaveGroups()
                end
                rename_item_index = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel", 120, 0) then
                rename_item_index = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        if open_save_template_modal then
            r.ImGui_OpenPopup(ctx, "Save Template")
            open_save_template_modal = false
        end
        if r.ImGui_BeginPopupModal(ctx, "Save Template", true, modal_flags) then
            r.ImGui_SetNextItemWidth(ctx, 250)
            local changed, new_val = r.ImGui_InputText(ctx, "##save_template_input", save_template_buf, 256)
            if changed then save_template_buf = new_val end
            if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx, -1) end
            local enter_pressed = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter())
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "Save", 120, 0) or enter_pressed then
                if save_template_buf ~= "" and cur_group and pending_save_data then
                    table.insert(cur_group.items, { name = save_template_buf, color = 0, data = pending_save_data })
                    SaveGroups()
                end
                pending_save_data = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "Cancel", 120, 0) then
                pending_save_data = nil
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndPopup(ctx)
        end

        r.ImGui_End(ctx)
    end

    popTheme()
    r.ImGui_PopStyleVar(ctx, 7)
    r.ImGui_PopFont(ctx)

    ProcessPendingSaves()

    if open then
        r.defer(loop)
    else
        if pending_save_layout then
            SaveLayoutSettingsImmediate()
        end
    end
end

r.defer(loop)

