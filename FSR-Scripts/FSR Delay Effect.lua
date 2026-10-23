--[[
-------------------------------------------------------------------------------------------
*              FSR Delay Effect
* Section      Main
* Author:      Andrew Dihtaryk(FSR)
* Version:     1.0.0
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:    http://reaper-script-feedback.forsemusic1996.workers.dev/
    
--]]
local required_api = {
    'ImGui_CreateContext', 'ImGui_InputDouble', 'ImGui_SetNextItemWidth',
    'JS_Composite', 'JS_LICE_CreateBitmap', 'JS_LICE_DestroyBitmap',
    'JS_LICE_Clear', 'JS_LICE_Line', 'JS_LICE_FillPolygon',
    'JS_LICE_FillRect', 'JS_LICE_FillCircle', 'JS_Window_FindChildByID',
    'JS_Window_GetClientSize', 'JS_Window_ScreenToClient', 'JS_Window_FromPoint',
    'JS_Window_IsWindow', 'JS_Window_InvalidateRect', 'JS_WindowMessage_Intercept',
    'JS_WindowMessage_Peek', 'JS_WindowMessage_Release', 'JS_Mouse_GetState',
}
for _, name in ipairs(required_api) do
    if not reaper[name] then
        reaper.ShowMessageBox('Missing API: ' .. name ..
            '\nInstall/update ReaImGui and js_ReaScriptAPI in ReaPack, then restart REAPER.',
            'Delay Effect', 0)
        return
    end
end

-- Initialize ImGui context
local ctx = reaper.ImGui_CreateContext('Delay Effect')
local font = reaper.ImGui_CreateFont('sans-serif', 14)
reaper.ImGui_Attach(ctx, font)

-- --- LOGIC VARIABLES ---
local note_length = (60 / reaper.Master_GetTempo()) / 2
local default_decay = 0.7
local selected_note = 'eighth'
local pan_mode = 'off'
local ribbon_state_section = 'DelayFadeScript_RibbonDrop'
local saved_pitch_step = tonumber(reaper.GetExtState(ribbon_state_section, 'PitchPerRepeat')) or -0.5
local ribbon_pitch_step = math.max(-2, math.min(2, saved_pitch_step))
local ribbon_drop_enabled = reaper.GetExtState(ribbon_state_section, 'Enabled') == '1'
local reverse_alt_enabled = reaper.GetExtState(ribbon_state_section, 'ReverseAlt') == '1'
local fade_mode_enabled = reaper.GetExtState(ribbon_state_section, 'FadeMode') == '1'
local fade_in_enabled = reaper.GetExtState(ribbon_state_section, 'FadeInEnabled') == '1'
local fade_out_enabled = reaper.GetExtState(ribbon_state_section, 'FadeOutEnabled') ~= '0'
local fade_progression = reaper.GetExtState(ribbon_state_section, 'FadeProgression')
if fade_progression ~= 'fall' then fade_progression = 'grow' end

local window_open = true
local drag = nil
local last_layout_expanded = nil

-- --- THEME MANAGEMENT ---
local show_theme_editor = false
local current_theme_name = "Default"
local new_theme_name = "My Theme"
local ext_section = "DelayFadeScript_Themes"

-- ImGui Color Constants Shortcuts
local CLR_WIN_BG = reaper.ImGui_Col_WindowBg()
local CLR_TXT = reaper.ImGui_Col_Text()
local CLR_BTN = reaper.ImGui_Col_Button()
local CLR_BTN_HOV = reaper.ImGui_Col_ButtonHovered()
local CLR_BTN_ACT = reaper.ImGui_Col_ButtonActive()
local CLR_FRM_BG = reaper.ImGui_Col_FrameBg()
local CLR_SLD_GRB = reaper.ImGui_Col_SliderGrab()
local CLR_SEP = reaper.ImGui_Col_Separator()
local CLR_TITLE_BG = reaper.ImGui_Col_TitleBg()
local CLR_TITLE_BG_ACTIVE = reaper.ImGui_Col_TitleBgActive()
local CLR_TITLE_BG_COLLAPSED = reaper.ImGui_Col_TitleBgCollapsed()

local function push_gray_titlebar()
    reaper.ImGui_PushStyleColor(ctx, CLR_TITLE_BG, 0x303030FF)
    reaper.ImGui_PushStyleColor(ctx, CLR_TITLE_BG_ACTIVE, 0x424242FF)
    reaper.ImGui_PushStyleColor(ctx, CLR_TITLE_BG_COLLAPSED, 0x272727FF)
end

local function pop_gray_titlebar()
    reaper.ImGui_PopStyleColor(ctx, 3)
end

-- 5 Ready-made Presets
local themes = {
    ["Default"] = {
        [CLR_WIN_BG] = 0x202020FF, [CLR_TXT] = 0xFFFFFFFF,
        [CLR_BTN] = 0x404040FF, [CLR_BTN_HOV] = 0x505050FF, [CLR_BTN_ACT] = 0x606060FF,
        [CLR_FRM_BG] = 0x2A2A2AFF, [CLR_SLD_GRB] = 0x808080FF, [CLR_SEP] = 0x505050FF
    },
    ["Light"] = {
        [CLR_WIN_BG] = 0xDDDDDDFF, [CLR_TXT] = 0x000000FF,
        [CLR_BTN] = 0xBBBBBBFF, [CLR_BTN_HOV] = 0xAAAAAAFF, [CLR_BTN_ACT] = 0x999999FF,
        [CLR_FRM_BG] = 0xFFFFFFFF, [CLR_SLD_GRB] = 0x404040FF, [CLR_SEP] = 0xAAAAAAFF
    },
    ["Ocean"] = {
        [CLR_WIN_BG] = 0x101525FF, [CLR_TXT] = 0x80D0FFFF,
        [CLR_BTN] = 0x203550FF, [CLR_BTN_HOV] = 0x304560FF, [CLR_BTN_ACT] = 0x405570FF,
        [CLR_FRM_BG] = 0x152030FF, [CLR_SLD_GRB] = 0x5090CCFF, [CLR_SEP] = 0x304560FF
    },
    ["Cherry"] = {
        [CLR_WIN_BG] = 0x251010FF, [CLR_TXT] = 0xFFC0C0FF,
        [CLR_BTN] = 0x502020FF, [CLR_BTN_HOV] = 0x603030FF, [CLR_BTN_ACT] = 0x804040FF,
        [CLR_FRM_BG] = 0x301515FF, [CLR_SLD_GRB] = 0xCC5050FF, [CLR_SEP] = 0x603030FF
    },
    ["Matrix"] = {
        [CLR_WIN_BG] = 0x001000FF, [CLR_TXT] = 0x40FF40FF,
        [CLR_BTN] = 0x003000FF, [CLR_BTN_HOV] = 0x005000FF, [CLR_BTN_ACT] = 0x007000FF,
        [CLR_FRM_BG] = 0x002000FF, [CLR_SLD_GRB] = 0x20AA20FF, [CLR_SEP] = 0x005000FF
    }
}

-- Current editable colors (cloned from active theme)
local current_colors = {}

-- Helper: Deep copy table
local function copy_table(t)
    local u = {}
    for k, v in pairs(t) do u[k] = v end
    return u
end

-- Helper: Serialize for storage (Simple Hex Format)
local function save_user_themes()
    local str = ""
    for name, data in pairs(themes) do
        -- Don't save built-in presets to ext state to save space/complexity, 
        -- only save if it's not one of the standard 5 (simplified logic here)
        if name ~= "Default" and name ~= "Light" and name ~= "Ocean" and name ~= "Cherry" and name ~= "Matrix" then
            str = str .. "THEME::" .. name .. "::"
            for col_id, col_val in pairs(data) do
                str = str .. col_id .. "=" .. col_val .. ";"
            end
            str = str .. "|"
        end
    end
    reaper.SetExtState(ext_section, "UserThemes", str, true)
    reaper.SetExtState(ext_section, "LastTheme", current_theme_name, true)
end

-- Helper: Load User Themes
local function load_user_themes()
    local str = reaper.GetExtState(ext_section, "UserThemes")
    if str and str ~= "" then
        for t_chunk in str:gmatch("THEME::(.-)|") do
            local t_name, t_data_str = t_chunk:match("^(.-)::(.*)$")
            if t_name then
                themes[t_name] = {}
                for c_id, c_val in t_data_str:gmatch("(%d+)=(%d+);") do
                    themes[t_name][tonumber(c_id)] = tonumber(c_val)
                end
            end
        end
    end
    
    local last = reaper.GetExtState(ext_section, "LastTheme")
    if last and themes[last] then current_theme_name = last end
end

-- Apply selected theme to current_colors
local function apply_theme(name)
    if themes[name] then
        current_theme_name = name
        current_colors = copy_table(themes[name])
        save_user_themes() -- Save selection
    end
end

-- Initial Load
load_user_themes()
apply_theme(current_theme_name)

-- --- CORE FUNCTIONS ---
-- The Arrange graphics use JS/LICE directly. No ImGui overlay window is created.
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function rounded(v) return math.floor(v + 0.5) end
-- Amplitude, not power: 20*log10(0.001) = -60 dB.
local function rt60_gain(elapsed, rt60) return 10 ^ (-3 * elapsed / rt60) end
local function gain_for_db(db, phase) return 10 ^ (db * phase / 20) end
local function end_db_for_drag(vertical_pixels, gain_span)
    local normalized = clamp(math.abs(vertical_pixels) / gain_span, 0, 1)
    return -normalized * 60
end
local function curve_phase(db, phase)
    local last_gain = gain_for_db(db, 1)
    if math.abs(last_gain - 1) < 0.000001 then return phase end
    return (gain_for_db(db, phase) - 1) / (last_gain - 1)
end
local function has_bit(value, bit) return math.floor(value / bit) % 2 == 1 end

local native = {
    hwnd = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000),
    bitmap = nil, width = 0, height = 0, owned = {}, armed = false,
    last_down = 0, last_paint = 0, last_key = nil, bounds = nil,
    delay = nil,
}
local project = reaper.EnumProjects(-1, '')
local instance_section = 'DelayFadeEnvelopeNative'
local instance_token = reaper.genGuid()
reaper.SetExtState(instance_section, 'instance', instance_token, false)

local function release_mouse()
    if native.hwnd then
        for message in pairs(native.owned) do
            reaper.JS_WindowMessage_Release(native.hwnd, message)
        end
    end
    native.owned = {}
    native.armed = false
end

local function cleanup_native()
    release_mouse()
    if native.bitmap then
        reaper.JS_LICE_DestroyBitmap(native.bitmap)
        native.bitmap = nil
    end
    if native.delay and reaper.JS_Window_IsWindow(native.hwnd) then
        reaper.JS_Composite_Delay(native.hwnd,
            native.delay[1], native.delay[2], math.max(1, native.delay[3]))
        native.delay = nil
    end
    if reaper.GetExtState(instance_section, 'instance') == instance_token then
        reaper.DeleteExtState(instance_section, 'instance', false)
    end
end
reaper.atexit(cleanup_native)

local function arm_mouse()
    if native.armed then return true end
    local messages = { 'WM_LBUTTONDOWN', 'WM_LBUTTONUP', 'WM_LBUTTONDBLCLK' }
    for _, message in ipairs(messages) do
        if reaper.JS_WindowMessage_Intercept(native.hwnd, message, false) ~= 1 then
            release_mouse()
            return false
        end
        native.owned[message] = true
    end
    -- Only release messages that this instance actually acquired.
    if reaper.JS_WindowMessage_Intercept(native.hwnd, 'WM_SETCURSOR', false) == 1 then
        native.owned.WM_SETCURSOR = true
    end
    native.armed = true
    native.last_down = 0
    return true
end

local function arrange_geometry()
    if not native.hwnd or not reaper.JS_Window_IsWindow(native.hwnd) then return nil end
    local ok, w, h = reaper.JS_Window_GetClientSize(native.hwnd)
    if not ok or w < 2 or h < 2 then return nil end
    local view_start = reaper.GetSet_ArrangeView2(0, false, 0, 0)
    local zoom = reaper.GetHZoomLevel()
    if not view_start or zoom <= 0 then return nil end
    return { width = w, height = h, start_time = view_start, zoom = zoom }
end

local function item_geometry(item, g)
    if not item or not reaper.ValidatePtr2(0, item, 'MediaItem*') then return nil end
    local track = reaper.GetMediaItem_Track(item)
    local y = reaper.GetMediaTrackInfo_Value(track, 'I_TCPY')
        + reaper.GetMediaItemInfo_Value(item, 'I_LASTY')
    local h = reaper.GetMediaItemInfo_Value(item, 'I_LASTH')
    if h < 2 or y + h <= 0 or y >= g.height then return nil end
    local finish = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
        + reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    return { x = (finish - g.start_time) * g.zoom, y = y, h = h,
        baseline = clamp(y + h / 2, 2, g.height - 3), finish = finish }
end

local function invalidate(bounds)
    if bounds then
        reaper.JS_Window_InvalidateRect(native.hwnd,
            bounds[1], bounds[2], bounds[3], bounds[4], false)
    end
end

local function clear_graphics()
    if native.bitmap and native.bounds then
        reaper.JS_LICE_Clear(native.bitmap, 0)
        invalidate(native.bounds)
    end
    native.bounds, native.last_key = nil, nil
end

local function ensure_bitmap(g)
    if native.bitmap and native.width == g.width and native.height == g.height then return end
    if native.bitmap then reaper.JS_LICE_DestroyBitmap(native.bitmap) end
    native.bitmap = reaper.JS_LICE_CreateBitmap(true, g.width, g.height)
    if not native.bitmap then error('Could not create the Arrange drawing bitmap.') end
    native.width, native.height = g.width, g.height
    native.bounds, native.last_key = nil, nil
    reaper.JS_LICE_Clear(native.bitmap, 0)
    local linked = reaper.JS_Composite(native.hwnd, 0, 0, g.width, g.height,
        native.bitmap, 0, 0, g.width, g.height, false)
    if linked ~= 1 then error('Could not attach the envelope to Arrange: ' .. tostring(linked)) end
    if not native.delay and reaper.JS_Composite_Delay then
        local ok, a, b, c = reaper.JS_Composite_Delay(native.hwnd, 0.025, 0.05, 2)
        if ok == 1 then native.delay = { a, b, c } end
    end
end

local function curve_count_and_db(d)
    if not d then return 0, 0 end
    local step = d.note_step or note_length
    local count = math.min(100, math.floor(math.max(0, d.end_time - d.start_time) / step + 0.000001))
    -- Height controls gain independently of the horizontal length of the gesture.
    local db = end_db_for_drag(d.start_y - d.end_y, d.gain_span or 48)
    local duration = math.max(0, d.end_time - d.start_time)
    local rt60 = db < -0.000001 and duration * 60 / -db or nil
    return count, db, rt60
end

local function copy_chunk_with_new_ids(chunk)
    for _, key in ipairs({ 'IGUID', 'GUID', 'FXID', 'EGUID' }) do
        chunk = chunk:gsub('(\n[ \t]*' .. key .. '[ \t]+){[^}\r\n]+}',
            function(prefix) return prefix .. reaper.genGuid() end)
    end
    return chunk
end

local function reverse_copy_item(copy)
    -- REAPER exposes take reversal as a built-in action rather than a TakeInfo field.
    -- Temporarily select only this generated copy, then restore the user's selection.
    local selected_items = {}
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        selected_items[#selected_items + 1] = reaper.GetSelectedMediaItem(0, i)
    end
    for _, selected in ipairs(selected_items) do
        reaper.SetMediaItemSelected(selected, false)
    end
    reaper.SetMediaItemSelected(copy, true)
    reaper.Main_OnCommand(41051, 0) -- Item properties: Toggle take reverse
    reaper.SetMediaItemSelected(copy, false)
    for _, selected in ipairs(selected_items) do
        reaper.SetMediaItemSelected(selected, true)
    end
end

local function apply_reverb_fade(item, repeat_count, decay_factor, note_step, final_db, range_start, envelope_duration, selected_pan_mode, ribbon_drop, pitch_step, reverse_alternating, fade_mode, fade_in_on, fade_out_on, fade_direction)
    local ok, chunk = reaper.GetItemStateChunk(item, '', false)
    if not ok then error('Could not read the selected source item.') end
    local source_volume = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
    local source_fade_in = reaper.GetMediaItemInfo_Value(item, 'D_FADEINLEN')
    local source_fade_out = reaper.GetMediaItemInfo_Value(item, 'D_FADEOUTLEN')
    local item_length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
    local source_take_for_length = reaper.GetActiveTake(item)
    local repeat_length = item_length
    if source_take_for_length and not reaper.TakeIsMIDI(source_take_for_length) then
        local source = reaper.GetMediaItemTake_Source(source_take_for_length)
        if source then
            local source_length, length_is_qn = reaper.GetMediaSourceLength(source)
            local source_offset = reaper.GetMediaItemTakeInfo_Value(source_take_for_length, 'D_STARTOFFS')
            local playrate = reaper.GetMediaItemTakeInfo_Value(source_take_for_length, 'D_PLAYRATE')
            if source_length and not length_is_qn and playrate and playrate > 0 then
                -- Copies expose the remaining audio in the source from the take's
                -- current offset, but stop at the real source end (never loop).
                repeat_length = math.max(0, (source_length - source_offset) / playrate)
            end
        end
    end
    local source_take = (selected_pan_mode ~= 'off' or ribbon_drop) and reaper.GetActiveTake(item) or nil
    if selected_pan_mode ~= 'off' and not source_take then
        error('Stereo panning modes require a media item with an active take.')
    end
    local source_pan = source_take and reaper.GetMediaItemTakeInfo_Value(source_take, 'D_PAN') or 0
    local source_pitch = source_take and reaper.GetMediaItemTakeInfo_Value(source_take, 'D_PITCH') or 0
    local first_pan = source_pan >= 0 and -1 or 1
    local first_position = range_start or (reaper.GetMediaItemInfo_Value(item, 'D_POSITION') + note_step)
    local track = reaper.GetMediaItem_Track(item)
    local duration = envelope_duration or repeat_count * note_step
    local rt60 = final_db and final_db < -0.000001 and duration * 60 / -final_db or nil
    local created_items = {}
    for i = 1, repeat_count do
        -- Each repeat samples the end of its time division on the visible curve.
        local elapsed = math.min(duration, i * note_step)
        local gain
        if rt60 then
            gain = rt60_gain(elapsed, rt60)
        elseif final_db ~= nil then
            gain = gain_for_db(final_db, elapsed / duration)
        else
            gain = decay_factor ^ i
        end
        local copy = reaper.AddMediaItemToTrack(track)
        if not reaper.SetItemStateChunk(copy, copy_chunk_with_new_ids(chunk), false) then
            reaper.DeleteTrackMediaItem(track, copy)
            error('Could not duplicate the source item.')
        end
        reaper.SetMediaItemInfo_Value(copy, 'D_POSITION', first_position + (i - 1) * note_step)
        reaper.SetMediaItemInfo_Value(copy, 'B_LOOPSRC', 0)
        reaper.SetMediaItemInfo_Value(copy, 'D_LENGTH', repeat_length)
        if selected_pan_mode ~= 'off' then
            local copy_take = reaper.GetActiveTake(copy)
            local pan
            if selected_pan_mode == 'pingpong' then
                pan = i % 2 == 1 and first_pan or -first_pan
            else
                local spread_levels = math.max(1, math.ceil((repeat_count - 1) / 2))
                local spread = i == 1 and 0 or math.min(1, math.ceil((i - 1) / 2) / spread_levels)
                local side = i % 2 == 0 and -1 or 1
                pan = side * spread
            end
            if not copy_take or not reaper.SetMediaItemTakeInfo_Value(copy_take, 'D_PAN', pan) then
                error('REAPER could not pan a stereo repeat.')
            end
        end
        if ribbon_drop then
            local copy_take = reaper.GetActiveTake(copy)
            if not copy_take or reaper.TakeIsMIDI(copy_take) then
                error('Ribbon Drop requires an audio item with an active take.')
            end
            -- Native take pitch adjustment: change each repeat by the chosen step,
            -- keeping the item length and timing unchanged (no added FX).
            local pitch = source_pitch + pitch_step * i
            if not reaper.SetMediaItemTakeInfo_Value(copy_take, 'D_PITCH', pitch) then
                error('REAPER could not apply the Ribbon Drop pitch change.')
            end
        end
        if reverse_alternating and i % 2 == 1 then
            local copy_take = reaper.GetActiveTake(copy)
            if not copy_take or reaper.TakeIsMIDI(copy_take) then
                error('Reverse Alt. requires an audio item with an active take.')
            end
            reverse_copy_item(copy)
        end
        if fade_mode then
            local max_fade = math.max(math.min(item_length * 0.45, note_step * 2),
                source_fade_in, source_fade_out)
            local fraction = fade_direction == 'grow'
                and (i / repeat_count) or ((repeat_count - i + 1) / repeat_count)
            local function fade_length(base, enabled)
                if not enabled then return nil end
                return base + (max_fade - base) * fraction
            end
            local fade_in = fade_length(source_fade_in, fade_in_on)
            local fade_out = fade_length(source_fade_out, fade_out_on)
            if fade_in then reaper.SetMediaItemInfo_Value(copy, 'D_FADEINLEN', fade_in) end
            if fade_out then reaper.SetMediaItemInfo_Value(copy, 'D_FADEOUTLEN', fade_out) end
        end
        local expected_volume = source_volume * gain
        reaper.SetMediaItemInfo_Value(copy, 'D_VOL', expected_volume)
        local applied_volume = reaper.GetMediaItemInfo_Value(copy, 'D_VOL')
        if math.abs(applied_volume - expected_volume) > math.max(0.000000000001, expected_volume * 0.000001) then
            error('REAPER did not apply the calculated repeat volume.')
        end
        reaper.SetMediaItemSelected(copy, false)
        reaper.UpdateItemInProject(copy)
        created_items[#created_items + 1] = copy
    end
    return created_items
end

local remove_overlaps_after_drag

local function commit_repeats(item, count, factor, step, db, start_time, duration, selected_pan_mode, ribbon_drop, pitch_step, reverse_alternating, fade_mode, fade_in_on, fade_out_on, fade_direction)
    reaper.Undo_BeginBlock2(0)
    reaper.PreventUIRefresh(1)
    local created_items
    local ok, err = xpcall(function()
        created_items = apply_reverb_fade(item, count, factor, step, db, start_time, duration,
            selected_pan_mode, ribbon_drop, pitch_step, reverse_alternating,
            fade_mode, fade_in_on, fade_out_on, fade_direction)
        remove_overlaps_after_drag(created_items)
    end, debug.traceback)
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, 'Draw Delay Effect', -1)
    reaper.UpdateArrange()
    if not ok then error(err, 0) end
    return created_items
end

remove_overlaps_after_drag = function(created_items)
    if not created_items or #created_items == 0 then return end

    local candidates, seen = {}, {}
    local function add_candidate(item, is_created)
        if item and not seen[item] and reaper.ValidatePtr2(0, item, 'MediaItem*') then
            seen[item] = true
            candidates[#candidates + 1] = {
                item = item,
                track = reaper.GetMediaItem_Track(item),
                position = reaper.GetMediaItemInfo_Value(item, 'D_POSITION'),
                is_created = is_created,
                order = #candidates + 1,
            }
        end
    end
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        add_candidate(reaper.GetSelectedMediaItem(0, i), false)
    end
    for _, item in ipairs(created_items) do add_candidate(item, true) end

    table.sort(candidates, function(a, b)
        if a.track ~= b.track then return tostring(a.track) < tostring(b.track) end
        if math.abs(a.position - b.position) > 0.000000001 then return a.position < b.position end
        -- Keep a pre-existing selected item if a repeat lands at the same start.
        if a.is_created ~= b.is_created then return not a.is_created end
        return a.order < b.order
    end)

    local previous = nil
    for _, current in ipairs(candidates) do
        if previous and previous.track == current.track then
            local start = reaper.GetMediaItemInfo_Value(previous.item, 'D_POSITION')
            local next_start = reaper.GetMediaItemInfo_Value(current.item, 'D_POSITION')
            local length = reaper.GetMediaItemInfo_Value(previous.item, 'D_LENGTH')
            local max_length = math.max(0, next_start - start)
            if max_length < 0.000000001 then
                -- Two items cannot both retain the same start without overlapping.
                -- The tie sort keeps the user's original item and drops the repeat.
                reaper.DeleteTrackMediaItem(previous.track, current.item)
            elseif length > max_length + 0.000000001 then
                reaper.SetMediaItemInfo_Value(previous.item, 'D_LENGTH', max_length)
                reaper.UpdateItemInProject(previous.item)
            end
        end
        if reaper.ValidatePtr2(0, current.item, 'MediaItem*') then previous = current end
    end
end

local function finish_drag()
    local d = drag
    drag = nil
    clear_graphics()
    if not d then return end
    local count, db = curve_count_and_db(d)
    if count < 1 then
        return
    end
    local selected_pan_mode = d.pan_mode
    local ribbon_drop = d.ribbon_drop
    local pitch_step = d.pitch_step
    local reverse_alternating = d.reverse_alternating
    local fade_mode = d.fade_mode
    local fade_in_on = d.fade_in_on
    local fade_out_on = d.fade_out_on
    local fade_direction = d.fade_direction
    if selected_pan_mode ~= 'off' and not reaper.GetActiveTake(d.item) then
        reaper.ShowMessageBox('Stereo panning needs a media item with an active take.', 'Delay Effect', 0)
        return
    end
    if ribbon_drop then
        local take = reaper.GetActiveTake(d.item)
        if not take or reaper.TakeIsMIDI(take) then
            reaper.ShowMessageBox('Ribbon Drop requires an audio item with an active take.', 'Delay Effect', 0)
            return
        end
    end
    if reverse_alternating then
        local take = reaper.GetActiveTake(d.item)
        if not take or reaper.TakeIsMIDI(take) then
            reaper.ShowMessageBox('Reverse Alt. requires an audio item with an active take.', 'Delay Effect', 0)
            return
        end
    end
    commit_repeats(d.item, count, default_decay, d.note_step, db, d.start_time,
        d.end_time - d.start_time, selected_pan_mode, ribbon_drop, pitch_step,
        reverse_alternating, fade_mode, fade_in_on, fade_out_on, fade_direction)
end

local function draw_native_curve(g, rect, d, hovered)
    ensure_bitmap(g)
    local x0, y0 = rect.x, rect.baseline
    local x1, y1 = x0, y0
    local count, db = 0, 0
    local active_pan_mode = d and d.pan_mode or 'off'
    local active_ribbon_drop = d and d.ribbon_drop or false
    local active_reverse_alt = d and d.reverse_alternating or false
    local active_fade_mode = d and d.fade_mode or false
    if d then
        x1 = clamp((d.end_time - g.start_time) * g.zoom, x0, g.width - 1)
        y1 = clamp(y0 + d.end_y - d.start_y, 1, g.height - 2)
        count, db = curve_count_and_db(d)
    end
    local key = table.concat({ tostring(d and d.item or ''), rounded(x0), rounded(y0),
        rounded(x1), rounded(y1), count, string.format('%.2f', db),
        hovered and 1 or 0, d and 1 or 0, active_pan_mode,
        active_ribbon_drop and 1 or 0, active_reverse_alt and 1 or 0,
        active_fade_mode and 1 or 0 }, ':')
    if key == native.last_key then return end
    local now = reaper.time_precise()
    if now - native.last_paint < 1 / 30 then return end
    native.last_paint, native.last_key = now, key
    local bitmap = native.bitmap
    reaper.JS_LICE_Clear(bitmap, 0)
    local color = active_fade_mode and 0x8BCEF5FF
        or (active_reverse_alt and 0xFF9870FF
        or (active_ribbon_drop and 0xD68BFFFF
        or (active_pan_mode == 'pingpong' and 0xFF73B7FF
        or (active_pan_mode == 'spread' and 0xB879FFFF
        or (db < 0 and 0xFFFFC166 or 0xFF68DAB5)))))
    if d and x1 > x0 + 1 then
        local dx = x1 - x0
        local segments = clamp(math.ceil(dx / 8), 16, 96)
        local points = {}
        for i = 0, segments do
            local t = i / segments
            points[#points + 1] = { x0 + dx * t, y0 + (y1 - y0) * curve_phase(db, t) }
        end
        for i = 2, #points do
            local a, b = points[i - 1], points[i]
            -- Use convex strips: JS_LICE_FillPolygon accepts convex polygons.
            local xs = string.pack('<i4i4i4i4', rounded(a[1]), rounded(b[1]), rounded(b[1]), rounded(a[1]))
            local ys = string.pack('<i4i4i4i4', rounded(a[2]), rounded(b[2]), rounded(y0), rounded(y0))
            reaper.JS_LICE_FillPolygon(bitmap, xs, ys, 4,
                db < 0 and 0x291F180D or 0x29111F1A, 1, 'COPY')
        end
        for x = math.max(0, x0), x1, 10 do
            reaper.JS_LICE_Line(bitmap, x, y0, math.min(x + 4, x1), y0, 0x60505050, 1, 'COPY', true)
        end
        for i = 2, #points do
            local a, b = points[i - 1], points[i]
            for offset = -2, 2 do
                reaper.JS_LICE_Line(bitmap, a[1], a[2] + offset, b[1], b[2] + offset,
                    0xFF13191E, 1, 'COPY', true)
            end
            for offset = -0.5, 0.5, 0.5 do
                reaper.JS_LICE_Line(bitmap, a[1], a[2] + offset, b[1], b[2] + offset,
                    color, 1, 'COPY', true)
            end
        end
        for i = 1, count do
            local t = clamp(i * d.note_step / (d.end_time - d.start_time), 0, 1)
            reaper.JS_LICE_FillCircle(bitmap, x0 + dx * t, y0 + (y1 - y0) * curve_phase(db, t),
                2, color, 1, 'COPY', true)
        end
        reaper.JS_LICE_FillCircle(bitmap, x1, y1, 4, 0xFF13191E, 1, 'COPY', true)
        reaper.JS_LICE_FillCircle(bitmap, x1, y1, 2.5, 0xFFFFFFFF, 1, 'COPY', true)
    end
    reaper.JS_LICE_FillRect(bitmap, rounded(x0) - 3, rounded(y0) - 11, 6, 22, 0xFF13191E, 1, 'COPY')
    reaper.JS_LICE_FillRect(bitmap, rounded(x0) - 1, rounded(y0) - 9, 3, 18,
        hovered and 0xFFFFFFFF or color, 1, 'COPY')
    local bounds = { math.max(0, math.floor(x0 - 8)), math.max(0, math.floor(math.min(y0, y1) - 15)),
        math.min(g.width, math.ceil(x1 + 8)), math.min(g.height, math.ceil(math.max(y0, y1) + 15)) }
    local old = native.bounds
    native.bounds = bounds
    if old then
        invalidate({ math.min(old[1], bounds[1]), math.min(old[2], bounds[2]),
            math.max(old[3], bounds[3]), math.max(old[4], bounds[4]) })
    else invalidate(bounds) end
end

-- Use REAPER's standard horizontal double-headed resize cursor.
local edge_cursor = reaper.JS_Mouse_LoadCursor and reaper.JS_Mouse_LoadCursor(32644)
local function draw_arrange_envelope_tool()
    local current_project = reaper.EnumProjects(-1, '')
    if current_project ~= project then
        drag = nil
        release_mouse()
        clear_graphics()
        project = current_project
    end
    local g = arrange_geometry()
    local item = drag and drag.item or reaper.GetSelectedMediaItem(0, 0)
    local rect = g and item_geometry(item, g)
    if not rect then
        drag = nil
        release_mouse()
        clear_graphics()
        return
    end
    local sx, sy = reaper.GetMousePosition()
    local mx, my = reaper.JS_Window_ScreenToClient(native.hwnd, sx, sy)
    local mouse_state = reaper.JS_Mouse_GetState(255)
    local down = has_bit(mouse_state, 1)
    local near = math.abs(mx - rect.x) <= 9
        and my >= math.max(0, rect.y + 7) and my <= math.min(g.height - 1, rect.y + rect.h - 3)
        and reaper.JS_Window_FromPoint(sx, sy) == native.hwnd
        and not has_bit(mouse_state, 4) and not has_bit(mouse_state, 8) and not has_bit(mouse_state, 16)
    if rect.x < 0 or rect.x >= g.width then near = false end
    if not drag and native.armed then
        local received, passed, stamp, _, _, click_x, click_y =
            reaper.JS_WindowMessage_Peek(native.hwnd, 'WM_LBUTTONDOWN')
        if received and not passed and stamp > native.last_down then
            native.last_down = stamp
            if math.abs(click_x - rect.x) <= 10 and click_y >= rect.y and click_y <= rect.y + rect.h then
                drag = { item = item, note_step = note_length, start_time = rect.finish,
                    end_time = rect.finish, start_x = rect.x, end_x = rect.x,
                    start_y = rect.baseline, end_y = rect.baseline,
                    gain_span = math.max(24, rect.h / 2), pan_mode = pan_mode,
                    ribbon_drop = ribbon_drop_enabled, pitch_step = ribbon_pitch_step,
                    reverse_alternating = reverse_alt_enabled, fade_mode = fade_mode_enabled,
                    fade_in_on = fade_in_enabled, fade_out_on = fade_out_enabled,
                    fade_direction = fade_progression }
            end
        end
    end
    if drag then
        drag.start_x, drag.start_y = rect.x, rect.baseline
        drag.end_x = math.max(rect.x, math.min(g.width - 1, mx))
        drag.end_y = clamp(my, math.max(1, rect.baseline - drag.gain_span),
            math.min(g.height - 2, rect.baseline + drag.gain_span))
        drag.end_time = drag.start_time + (drag.end_x - rect.x) / g.zoom
        local escape = reaper.JS_VKeys_GetState and reaper.JS_VKeys_GetState(0):byte(28) ~= 0
        if escape then
            drag = nil
            clear_graphics()
        elseif not down then finish_drag() end
    end
    if not drag then
        if near and not down then arm_mouse()
        elseif not down then release_mouse() end
    end
    -- Show the horizontal resize cursor over the edge and during the drag.
    if (near or drag) and edge_cursor and reaper.JS_Mouse_SetCursor then
        reaper.JS_Mouse_SetCursor(edge_cursor)
    end
    if rect.x >= 0 and rect.x < g.width then
        draw_native_curve(g, rect, drag, near)
    else clear_graphics() end
end

local function handle_undo_shortcut()
    if not reaper.ImGui_IsWindowFocused(ctx) then return end
    local undo_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z(), false)
        and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
    if undo_pressed and reaper.ImGui_SetNextFrameWantCaptureKeyboard then
        reaper.ImGui_SetNextFrameWantCaptureKeyboard(ctx, true)
    end
    if reaper.ImGui_IsAnyItemActive(ctx) then return end
    if undo_pressed then
        reaper.Undo_DoUndo2(0)
        reaper.UpdateArrange()
    end
end

local function draw_theme_editor()
    local open_editor = true
    push_gray_titlebar()
    local visible, open = reaper.ImGui_Begin(ctx, 'Theme Editor', open_editor, reaper.ImGui_WindowFlags_AlwaysAutoResize())
    
    if visible then
        handle_undo_shortcut()
        reaper.ImGui_Text(ctx, "Current Theme: " .. current_theme_name)
        reaper.ImGui_Separator(ctx)
        
        -- Color pickers
        local function color_edit(label, idx)
            local rv, new_col = reaper.ImGui_ColorEdit4(ctx, label, current_colors[idx] or 0xFFFFFFFF, reaper.ImGui_ColorEditFlags_NoInputs())
            if rv then current_colors[idx] = new_col end
        end

        color_edit("Window Background", CLR_WIN_BG)
        color_edit("Text Color", CLR_TXT)
        color_edit("Button Normal", CLR_BTN)
        color_edit("Button Hover", CLR_BTN_HOV)
        color_edit("Frame/Slider BG", CLR_FRM_BG)
        color_edit("Slider Grab", CLR_SLD_GRB)
        
        reaper.ImGui_Separator(ctx)
        
        -- Save New Theme
        local rv, buf = reaper.ImGui_InputText(ctx, 'Name', new_theme_name)
        if rv then new_theme_name = buf end
        
        if reaper.ImGui_Button(ctx, "Save Theme") then
            if new_theme_name ~= "" then
                themes[new_theme_name] = copy_table(current_colors)
                current_theme_name = new_theme_name
                save_user_themes()
            end
        end
        
        reaper.ImGui_SameLine(ctx)
        
        -- Delete Theme (Protect presets)
        local is_preset = (current_theme_name == "Default" or current_theme_name == "Light" or current_theme_name == "Ocean" or current_theme_name == "Cherry" or current_theme_name == "Matrix")
        
        if is_preset then reaper.ImGui_BeginDisabled(ctx) end
        if reaper.ImGui_Button(ctx, "Delete Current") then
            themes[current_theme_name] = nil
            apply_theme("Default")
            save_user_themes()
        end
        if is_preset then reaper.ImGui_EndDisabled(ctx) end
        
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Close Editor") then show_theme_editor = false end

        reaper.ImGui_End(ctx)
    end

    pop_gray_titlebar()
    
    if not open then show_theme_editor = false end
end

local function main_loop()
    if reaper.GetExtState(instance_section, 'instance') ~= instance_token then return false end
    draw_arrange_envelope_tool()
    -- PUSH THEME COLORS
    local theme_color_push_count = 0
    for k, v in pairs(current_colors) do
        reaper.ImGui_PushStyleColor(ctx, k, v)
        theme_color_push_count = theme_color_push_count + 1
    end
    reaper.ImGui_PushFont(ctx, font, 14)
    push_gray_titlebar()

    local expanded_layout = ribbon_drop_enabled or fade_mode_enabled
    if last_layout_expanded ~= expanded_layout then
        reaper.ImGui_SetNextWindowSize(ctx, expanded_layout and 430 or 340, 254, reaper.ImGui_Cond_Always())
        last_layout_expanded = expanded_layout
    end

    local visible, open = reaper.ImGui_Begin(ctx, 'Delay Effect###DelayFadeEffect62', window_open)
    
    if visible then
        handle_undo_shortcut()
        -- RIGHT CLICK CONTEXT MENU
        if reaper.ImGui_BeginPopupContextWindow(ctx) then
            -- Sort themes for display
            local t_keys = {}
            for k in pairs(themes) do table.insert(t_keys, k) end
            table.sort(t_keys)

            for _, name in ipairs(t_keys) do
                if reaper.ImGui_MenuItem(ctx, name, nil, name == current_theme_name) then
                    apply_theme(name)
                end
            end

            reaper.ImGui_Separator(ctx)
            if reaper.ImGui_MenuItem(ctx, "Open Theme Editor...") then
                show_theme_editor = true
            end

            reaper.ImGui_EndPopup(ctx)
        end
        local quarter_note = 60 / reaper.Master_GetTempo()
        local note_multipliers = {
            half = 2, quarter = 1, eighth = 0.5, sixteenth = 0.25, thirtysecond = 0.125,
        }
        if not drag then
            note_length = quarter_note * note_multipliers[selected_note]
        end

        local selected_color = 0x8C3F5FFF
        local selected_hover = 0xA64F70FF
        local selected_active = 0x74334FFF
        local mode_x = 112
        local settings_x = 266
        reaper.ImGui_Text(ctx, 'Length')
        reaper.ImGui_SameLine(ctx, mode_x)
        reaper.ImGui_Text(ctx, 'Mode')
        if expanded_layout then
            reaper.ImGui_SameLine(ctx, settings_x)
            reaper.ImGui_Text(ctx, 'Settings')
        end
        reaper.ImGui_Separator(ctx)

        local function draw_mode_button(label, mode)
            local active = pan_mode == mode
            if active then
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
            end
            if reaper.ImGui_Button(ctx, label, 142, 24) then
                pan_mode = active and 'off' or mode
            end
            if active then reaper.ImGui_PopStyleColor(ctx, 3) end
        end

        local function draw_fade_toggle(label, enabled, state_key)
            local active = enabled
            if active then
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
            end
            if reaper.ImGui_Button(ctx, label .. ': ' .. (enabled and 'On' or 'Off'), 136, 24) then
                enabled = not enabled
                if state_key == 'in' then
                    fade_in_enabled = enabled
                    reaper.SetExtState(ribbon_state_section, 'FadeInEnabled', enabled and '1' or '0', true)
                else
                    fade_out_enabled = enabled
                    reaper.SetExtState(ribbon_state_section, 'FadeOutEnabled', enabled and '1' or '0', true)
                end
            end
            if active then reaper.ImGui_PopStyleColor(ctx, 3) end
        end

        local note_buttons = {
            { '1/2', 'half' }, { '1/4', 'quarter' }, { '1/8', 'eighth' },
            { '1/16', 'sixteenth' }, { '1/32', 'thirtysecond' },
        }
        for i, button in ipairs(note_buttons) do
            local is_selected = selected_note == button[2]
            if is_selected then
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
            end
            if reaper.ImGui_Button(ctx, button[1], 76, 24) then selected_note = button[2] end
            if is_selected then reaper.ImGui_PopStyleColor(ctx, 3) end
            if i <= #note_buttons then
                reaper.ImGui_SameLine(ctx, mode_x)
                if i == 1 then draw_mode_button('Ping-Pong', 'pingpong')
                elseif i == 2 then draw_mode_button('Stereo Spread', 'spread')
                elseif i == 3 then
                    local active = ribbon_drop_enabled
                    if active then
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
                    end
                    if reaper.ImGui_Button(ctx, 'Ribbon Drop', 142, 24) then
                        ribbon_drop_enabled = not ribbon_drop_enabled
                        reaper.SetExtState(ribbon_state_section, 'Enabled',
                            ribbon_drop_enabled and '1' or '0', true)
                    end
                    if active then reaper.ImGui_PopStyleColor(ctx, 3) end
                elseif i == 4 then
                    local active = reverse_alt_enabled
                    if active then
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
                    end
                    if reaper.ImGui_Button(ctx, 'Reverse Alt.', 142, 24) then
                        reverse_alt_enabled = not reverse_alt_enabled
                        reaper.SetExtState(ribbon_state_section, 'ReverseAlt',
                            reverse_alt_enabled and '1' or '0', true)
                    end
                    if active then reaper.ImGui_PopStyleColor(ctx, 3) end
                elseif i == 5 then
                    local active = fade_mode_enabled
                    if active then
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
                    end
                    if reaper.ImGui_Button(ctx, 'Fade', 142, 24) then
                        fade_mode_enabled = not fade_mode_enabled
                        reaper.SetExtState(ribbon_state_section, 'FadeMode',
                            fade_mode_enabled and '1' or '0', true)
                    end
                    if active then reaper.ImGui_PopStyleColor(ctx, 3) end
                else reaper.ImGui_Dummy(ctx, 142, 24) end
            end
            if expanded_layout then
                reaper.ImGui_SameLine(ctx, settings_x)
                if i == 1 and ribbon_drop_enabled then
                    reaper.ImGui_SetNextItemWidth(ctx, 136)
                    local changed, value = reaper.ImGui_InputDouble(ctx, '##ribbonPitchStep',
                        ribbon_pitch_step, 0.1, 0.5, '%+.2f st')
                    if changed then
                        ribbon_pitch_step = math.max(-2, math.min(2, value))
                        reaper.SetExtState(ribbon_state_section, 'PitchPerRepeat',
                            string.format('%.4f', ribbon_pitch_step), true)
                    end
                elseif i == 2 and fade_mode_enabled then
                    draw_fade_toggle('Fade In', fade_in_enabled, 'in')
                elseif i == 3 and fade_mode_enabled then
                    draw_fade_toggle('Fade Out', fade_out_enabled, 'out')
                elseif i == 4 and fade_mode_enabled then
                    local grow_active = fade_progression == 'grow'
                    if grow_active then
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
                    end
                    if reaper.ImGui_Button(ctx, 'Grow', 64, 24) then
                        fade_progression = 'grow'
                        reaper.SetExtState(ribbon_state_section, 'FadeProgression', fade_progression, true)
                    end
                    if grow_active then reaper.ImGui_PopStyleColor(ctx, 3) end
                    reaper.ImGui_SameLine(ctx, settings_x + 70)
                    local fall_active = fade_progression == 'fall'
                    if fall_active then
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN, selected_color)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_HOV, selected_hover)
                        reaper.ImGui_PushStyleColor(ctx, CLR_BTN_ACT, selected_active)
                    end
                    if reaper.ImGui_Button(ctx, 'Fall', 64, 24) then
                        fade_progression = 'fall'
                        reaper.SetExtState(ribbon_state_section, 'FadeProgression', fade_progression, true)
                    end
                    if fall_active then reaper.ImGui_PopStyleColor(ctx, 3) end
                else
                    reaper.ImGui_Dummy(ctx, 136, 24)
                end
            end
        end

        reaper.ImGui_End(ctx)
    end

    pop_gray_titlebar()

    -- POP THEME COLORS
    reaper.ImGui_PopStyleColor(ctx, theme_color_push_count)

    reaper.ImGui_PopFont(ctx)
    
    -- Draw Editor if active (outside main font/style stack to allow editor to see raw colors or use its own logic, 
    -- but here we keep it simple and let it inherit defaults or we could wrap it too)
    if show_theme_editor then draw_theme_editor() end

    window_open = open
    return open
end

local function run()
    local ok, keep_running = xpcall(main_loop, debug.traceback)
    if not ok then
        cleanup_native()
        reaper.ShowMessageBox(tostring(keep_running), 'Delay Effect', 0)
    elseif keep_running then
        reaper.defer(run)
    else
        cleanup_native()
    end
end

reaper.defer(run)

