--[[
-------------------------------------------------------------------------------------------
*              FSR LoopX
* Section      Main
* Author:      Andrew Dihtiaruk (FSR)
* Version:     1.00
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:     http://forum.cockos.com/showthread.php?t=310866


-------------------------------------------------------------------------------------------
--]]  
if not reaper.ImGui_CreateContext then
  reaper.MB("ReaImGui extension required.\nInstall via ReaPack.", "Error", 0)
  return
end

local ctx = reaper.ImGui_CreateContext("FSR LoopX")
local font = reaper.ImGui_CreateFont("Arial", 14)
local font_slot = reaper.ImGui_CreateFont("Arial", 16)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, font_slot)

-- ===== PERSISTENT STATE =====
local EXT_SECTION = "SimpleItemView"

-- ВАЖЛИВО: ці локальні змінні оголошені ТУТ (до save/load-функцій), щоб
-- Lua правильно захоплював їх як upvalue, а не створював нові глобальні
-- змінні. Раніше вони оголошувались нижче по файлу - через це кнопки
-- Lock Position і Zero-Cross Snap не зберігали стан між перезапусками.
local window_locked = false
local locked_pos_x = nil
local locked_pos_y = nil
local locked_size_w = nil
local locked_size_h = nil
local zero_cross_snap = true
local ZC_SEARCH_RADIUS = 0.005
local right_click_hint_seen = false
local waveform_mode = "stereo"

local WAVEFORM_MODE_OPTIONS = {
  {id = "stereo",    label = "Stereo (all channels)"},
  {id = "mono_left", label = "Mono Left channel"},
  {id = "mono_right", label = "Mono Right channel"},
  {id = "mono_sum",  label = "Mono Sum (L + R)"},
}

local function is_valid_waveform_mode(mode)
  for _, option in ipairs(WAVEFORM_MODE_OPTIONS) do
    if option.id == mode then return true end
  end
  return false
end

local function save_persistent_state()
  reaper.SetExtState(EXT_SECTION, "window_locked", window_locked and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "zero_cross_snap", zero_cross_snap and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "loopx_right_click_hint_seen", right_click_hint_seen and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "loopx_waveform_mode", waveform_mode, true)
  if locked_pos_x then reaper.SetExtState(EXT_SECTION, "win_x", tostring(locked_pos_x), true) end
  if locked_pos_y then reaper.SetExtState(EXT_SECTION, "win_y", tostring(locked_pos_y), true) end
  if locked_size_w then reaper.SetExtState(EXT_SECTION, "win_w", tostring(locked_size_w), true) end
  if locked_size_h then reaper.SetExtState(EXT_SECTION, "win_h", tostring(locked_size_h), true) end
end

local function load_persistent_state()
  local wl = reaper.GetExtState(EXT_SECTION, "window_locked")
  if wl == "1" then window_locked = true elseif wl == "0" then window_locked = false else window_locked = false end
  local zc = reaper.GetExtState(EXT_SECTION, "zero_cross_snap")
  if zc == "1" then zero_cross_snap = true elseif zc == "0" then zero_cross_snap = false else zero_cross_snap = true end
  local hint_seen = reaper.GetExtState(EXT_SECTION, "loopx_right_click_hint_seen")
  right_click_hint_seen = hint_seen == "1"
  local wm = reaper.GetExtState(EXT_SECTION, "loopx_waveform_mode")
  if is_valid_waveform_mode(wm) then waveform_mode = wm else waveform_mode = "stereo" end
  local wx = reaper.GetExtState(EXT_SECTION, "win_x")
  local wy = reaper.GetExtState(EXT_SECTION, "win_y")
  local ww = reaper.GetExtState(EXT_SECTION, "win_w")
  local wh = reaper.GetExtState(EXT_SECTION, "win_h")
  if wx ~= "" then locked_pos_x = tonumber(wx) end
  if wy ~= "" then locked_pos_y = tonumber(wy) end
  if ww ~= "" then locked_size_w = tonumber(ww) end
  if wh ~= "" then locked_size_h = tonumber(wh) end
end

local theme = {
    WindowBg = 0x1E1E1EFF, Text = 0xE0E0E0FF, TextDisabled = 0x808080FF,
    FrameBg = 0x333333FF, FrameBgHovered = 0x444444FF, FrameBgActive = 0x555555FF,
    TitleBg = 0x1A1A1AFF, TitleBgActive = 0x2D2D2DFF,
    Button = 0x404040FF, ButtonHovered = 0x505050FF, ButtonActive = 0x606060FF,
    CheckMark = 0x00AAFFFF, ScrollbarBg = 0x1A1A1AFF,
    ScrollbarGrab = 0x404040FF, ScrollbarGrabHovered = 0x505050FF, ScrollbarGrabActive = 0x606060FF,
    Header = 0x3D3D3DFF, HeaderHovered = 0x4D4D4DFF, HeaderActive = 0x5D5D5DFF,
    Separator = 0x505050FF, PopupBg = 0x252525FF, MenuBarBg = 0x2A2A2AFF,
    Border = 0x505050FF, ActivePreset = 0x00AAFFFF, ChildBg = 0x1A1A1AFF,
}
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
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), t.Header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), t.HeaderHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), t.HeaderActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), t.Separator)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), t.PopupBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(), t.MenuBarBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), t.Border)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), t.ChildBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), t.ActivePreset)
end
local function popTheme() reaper.ImGui_PopStyleColor(ctx, THEME_COLOR_COUNT) end

-- ===== CONSOLIDATED COLOR TABLE (fixes "too many local variables" error) =====
local COLOR = {
  BG         = 0x1A1A1AFF,
  WAVE       = 0xB380CCFF,
  WAVE_ALT   = 0x80B3CCFF,
  AXIS       = 0xB3B39966,
  MARKER     = 0xFF6644FF,
  MARKER_HOV = 0xFF9966FF,
  UNUSED     = 0x00000066,
  RULER_BG   = 0x111111FF,
  RULER_TEXT = 0xAAAAAAFF,
  RULER_TICK = 0x666666FF,
  GRID       = 0xFFFFFF18,
  GRID_LINE  = 0x44444455,
  PLAYHEAD   = 0xFFFF44FF,
  REGION     = 0x4A90D933,
  LOOPBAR_FILL = 0x4A90D9AA,
  SELECTION  = 0x44AAFF55,
  SELECTION_BORDER = 0x44AAFFCC,
  SET_BTN    = 0x44AAFFFF,
  SET_BTN_BG = 0x334455FF,

  SLOT_FILLED    = 0x44AAFFFF,
  SLOT_FILLED_BG = 0x1A3A5AFF,
  SLOT_HOVERED_BG = 0x2A4A6AFF,
  SLOT_ACTIVE    = 0x66CCFFFF,
  SLOT_ADD       = 0x88CC44FF,
  SLOT_ADD_BG    = 0x2A3A1AFF,
  SLOT_ZONE      = 0xFFDD4466,
  SLOT_ZONE_LINE = 0xFFDD4488,
  SLOT_ZONE_TEXT = 0xFFDD44DD,

  -- LOCK POSITION -- єдиний виняток, зберігає свою колірну схему
  LOCK_ON     = 0xFF6644FF,
  LOCK_ON_BG  = 0x4A1A1AFF,
  LOCK_OFF    = 0x666666FF,
  LOCK_OFF_BG = 0x2A2A2AFF,

  -- ZC -- синя коли активна
  ZC_ON      = 0x44AAFFFF,
  ZC_ON_BG   = 0x1A3A5AFF,
  ZC_OFF     = 0x666666FF,
  ZC_OFF_BG  = 0x2A2A2AFF,

  -- SNAP -- жовта коли активна
  SNAP_ON     = 0xFFDD44FF,
  SNAP_ON_BG  = 0x4A4A1AFF,
  SNAP_OFF    = 0x666666FF,
  SNAP_OFF_BG = 0x2A2A2AFF,

  -- TS / GRID -- сині
  TS_BTN     = 0x44AAFFFF,
  TS_BTN_BG  = 0x1A3A5AFF,

  -- LOOP LENGTH -- колір як у маркерів лупа (логічна відповідність)
  LOOPLEN_BTN     = 0xFF6644FF,
  LOOPLEN_BTN_BG  = 0x4A2A1AFF,

  SCROLLBAR_BG    = 0x1A1A1AFF,
  SCROLLBAR_TRACK = 0x333333FF,
  SCROLLBAR_THUMB = 0x5A5A5AFF,
  SCROLLBAR_THUMB_HOV = 0x7A7A7AFF,
  SCROLLBAR_THUMB_ACT = 0x9A9A9AFF,
}

-- ===== APPEARANCE / COLOR THEME SYSTEM =====

local function derive_color(base, factor)
  local r = (base >> 24) & 0xFF
  local g = (base >> 16) & 0xFF
  local b = (base >> 8) & 0xFF
  if factor >= 1.0 then
    local t = factor - 1.0
    r = math.min(255, math.floor(r + (255 - r) * t))
    g = math.min(255, math.floor(g + (255 - g) * t))
    b = math.min(255, math.floor(b + (255 - b) * t))
  else
    r = math.max(0, math.floor(r * factor))
    g = math.max(0, math.floor(g * factor))
    b = math.max(0, math.floor(b * factor))
  end
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

local function offset_color(base, offset)
  local r = math.max(0, math.min(255, ((base >> 24) & 0xFF) + offset))
  local g = math.max(0, math.min(255, ((base >> 16) & 0xFF) + offset))
  local b = math.max(0, math.min(255, ((base >> 8) & 0xFF) + offset))
  return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

local function with_alpha(c, a)
  return (c & 0xFFFFFF00) | (a & 0xFF)
end

-- ===== THEME SETTINGS (load / save with ExtState) =====
local settings = {}

local COLOR_KEYS = { "waveform", "waveform_inactive", "waveform_bg", "centerline",
  "markers", "markers_hover", "border", "playhead", "grid_bar", "grid_beat",
  "ruler_bg", "ruler_text", "ruler_tick", "info_bar_bg", "info_bar_text",
  "info_bar_icon", "btn_on", "btn_off", "btn_hover", "btn_text", "highlight" }
settings.COLOR_KEYS = COLOR_KEYS

settings.THEMES = {
  {
    id = "default",
    name = "Default",
    description = "Professional steel-blue with gold accents",
    colors = {
      waveform = 0x5B7B8AFF, waveform_inactive = 0x3D5560FF, waveform_bg = 0x1C1C1CFF,
      centerline = 0x2C2C2CFF, markers = 0xC9A227FF, markers_hover = 0xDCB53AFF,
      border = 0x4B6B7AFF, playhead = 0xC9A227FF, grid_bar = 0x363636FF, grid_beat = 0x262626FF,
      ruler_bg = 0x242424FF, ruler_text = 0x888888FF, ruler_tick = 0x606060FF,
      info_bar_bg = 0x1E1E1EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xC9A227FF,
      btn_on = 0xC9A227FF, btn_off = 0x424242FF, btn_hover = 0xD9B237FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "classic",
    name = "Classic",
    description = "Classic green waveform",
    colors = {
      waveform = 0x5A9F5AFF, waveform_inactive = 0x3A6A3AFF, waveform_bg = 0x1A1A1AFF,
      centerline = 0x2A2A2AFF, markers = 0x4A90D9FF, markers_hover = 0x6AB0F9FF,
      border = 0x4A7A4AFF, playhead = 0x00CC00FF, grid_bar = 0x383838FF, grid_beat = 0x2E2E2EFF,
      ruler_bg = 0x252525FF, ruler_text = 0x888888FF, ruler_tick = 0x666666FF,
      info_bar_bg = 0x1E1E1EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5A9F5AFF,
      btn_on = 0x4A90D9FF, btn_off = 0x404040FF, btn_hover = 0x5AA0E9FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "modern",
    name = "Modern",
    description = "Clean, muted teal tones",
    colors = {
      waveform = 0x6B8E9BFF, waveform_inactive = 0x4A6570FF, waveform_bg = 0x1A1D1FFF,
      centerline = 0x2A2D30FF, markers = 0x5BC0BEFF, markers_hover = 0x7DD3D1FF,
      border = 0x5B7B85FF, playhead = 0x5BC0BEFF, grid_bar = 0x353840FF, grid_beat = 0x282B30FF,
      ruler_bg = 0x222528FF, ruler_text = 0x8A9098FF, ruler_tick = 0x606670FF,
      info_bar_bg = 0x1C1F22FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5BC0BEFF,
      btn_on = 0x5BC0BEFF, btn_off = 0x404548FF, btn_hover = 0x6DD0CEFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "ableton_dark",
    name = "Ableton Dark",
    description = "Classic DAW orange accents",
    colors = {
      waveform = 0x7B9BA6FF, waveform_inactive = 0x556A72FF, waveform_bg = 0x1E1E1EFF,
      centerline = 0x2E2E2EFF, markers = 0xE8A449FF, markers_hover = 0xFFB85CFF,
      border = 0x6A8A92FF, playhead = 0xE8A449FF, grid_bar = 0x3A3A3AFF, grid_beat = 0x2A2A2AFF,
      ruler_bg = 0x262626FF, ruler_text = 0x909090FF, ruler_tick = 0x686868FF,
      info_bar_bg = 0x202020FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xE8A449FF,
      btn_on = 0xE8A449FF, btn_off = 0x454545FF, btn_hover = 0xF8B459FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "pro_tools",
    name = "Pro Tools",
    description = "Authentic blue-teal with lighter dark bg",
    colors = {
      waveform = 0x5588A0FF, waveform_inactive = 0x3A6070FF, waveform_bg = 0x2A2A2AFF,
      centerline = 0x383838FF, markers = 0xC9A227FF, markers_hover = 0xDCB53AFF,
      border = 0x506070FF, playhead = 0x6699CCFF, grid_bar = 0x3C3C3CFF, grid_beat = 0x323232FF,
      ruler_bg = 0x3A3A3AFF, ruler_text = 0x999999FF, ruler_tick = 0x666666FF,
      info_bar_bg = 0x282828FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xC9A227FF,
      btn_on = 0xC9A227FF, btn_off = 0x484848FF, btn_hover = 0xD9B237FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "high_contrast",
    name = "High Contrast",
    description = "Accessibility-focused bright colors",
    colors = {
      waveform = 0x7FFF00FF, waveform_inactive = 0x4A9900FF, waveform_bg = 0x0A0A0AFF,
      centerline = 0x1A1A1AFF, markers = 0x00BFFFFF, markers_hover = 0x40DFFFFF,
      border = 0x60CC00FF, playhead = 0xFF4444FF, grid_bar = 0x333333FF, grid_beat = 0x1A1A1AFF,
      ruler_bg = 0x151515FF, ruler_text = 0xCCCCCCFF, ruler_tick = 0x888888FF,
      info_bar_bg = 0x101010FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x7FFF00FF,
      btn_on = 0x00BFFFFF, btn_off = 0x505050FF, btn_hover = 0x40DFFFFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "warm",
    name = "Warm",
    description = "Orange and amber tones",
    colors = {
      waveform = 0xD4915AFF, waveform_inactive = 0x8A5A3AFF, waveform_bg = 0x1A1816FF,
      centerline = 0x2A2826FF, markers = 0xE07A5FFF, markers_hover = 0xF08A6FFF,
      border = 0xB07A4AFF, playhead = 0xE07A5FFF, grid_bar = 0x383432FF, grid_beat = 0x282624FF,
      ruler_bg = 0x252220FF, ruler_text = 0x9A8A80FF, ruler_tick = 0x6A6058FF,
      info_bar_bg = 0x1E1C1AFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xD4915AFF,
      btn_on = 0xE07A5FFF, btn_off = 0x484440FF, btn_hover = 0xF08A6FFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "cool",
    name = "Cool",
    description = "Blue and purple tones",
    colors = {
      waveform = 0x5A8A9FFF, waveform_inactive = 0x3A5A6AFF, waveform_bg = 0x16181AFF,
      centerline = 0x26282AFF, markers = 0x8A7FBFFF, markers_hover = 0x9A8FCFFF,
      border = 0x4A7A8FFF, playhead = 0x8A7FBFFF, grid_bar = 0x323438FF, grid_beat = 0x242628FF,
      ruler_bg = 0x202225FF, ruler_text = 0x808890FF, ruler_tick = 0x585E68FF,
      info_bar_bg = 0x1A1C1EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5A8A9FFF,
      btn_on = 0x8A7FBFFF, btn_off = 0x404448FF, btn_hover = 0x9A8FCFFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "monochrome",
    name = "Monochrome",
    description = "Minimal grayscale",
    colors = {
      waveform = 0x8A8A8AFF, waveform_inactive = 0x5A5A5AFF, waveform_bg = 0x181818FF,
      centerline = 0x282828FF, markers = 0xCCCCCCFF, markers_hover = 0xEEEEEEFF,
      border = 0x707070FF, playhead = 0xFFFFFFFF, grid_bar = 0x353535FF, grid_beat = 0x252525FF,
      ruler_bg = 0x222222FF, ruler_text = 0x888888FF, ruler_tick = 0x606060FF,
      info_bar_bg = 0x1C1C1CFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x8A8A8AFF,
      btn_on = 0xA0A0A0FF, btn_off = 0x404040FF, btn_hover = 0xB0B0B0FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "sunset",
    name = "Sunset",
    description = "Warm earth tones",
    colors = {
      waveform = 0xC4785AFF, waveform_inactive = 0x7A4A38FF, waveform_bg = 0x1A1614FF,
      centerline = 0x2A2624FF, markers = 0xD4A850FF, markers_hover = 0xE8BC64FF,
      border = 0xA06848FF, playhead = 0xE8C040FF, grid_bar = 0x383230FF, grid_beat = 0x282422FF,
      ruler_bg = 0x252120FF, ruler_text = 0x988878FF, ruler_tick = 0x685850FF,
      info_bar_bg = 0x1E1A18FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xC4785AFF,
      btn_on = 0xD4A850FF, btn_off = 0x484240FF, btn_hover = 0xE4B860FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "arctic",
    name = "Arctic",
    description = "Cool blues and whites",
    colors = {
      waveform = 0x5A8AAFFF, waveform_inactive = 0x3A5A70FF, waveform_bg = 0x161A1EFF,
      centerline = 0x262A2EFF, markers = 0x70C0D8FF, markers_hover = 0x88D4ECFF,
      border = 0x4A7A95FF, playhead = 0x90E0F0FF, grid_bar = 0x323638FF, grid_beat = 0x242628FF,
      ruler_bg = 0x202428FF, ruler_text = 0x808A92FF, ruler_tick = 0x586068FF,
      info_bar_bg = 0x1A1E22FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5A8AAFFF,
      btn_on = 0x70C0D8FF, btn_off = 0x404448FF, btn_hover = 0x80D0E8FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "forest",
    name = "Forest",
    description = "Natural greens",
    colors = {
      waveform = 0x5A8A60FF, waveform_inactive = 0x3A5A40FF, waveform_bg = 0x161A16FF,
      centerline = 0x262A26FF, markers = 0x8AB060FF, markers_hover = 0x9EC474FF,
      border = 0x4A7A50FF, playhead = 0xA0D060FF, grid_bar = 0x323832FF, grid_beat = 0x242824FF,
      ruler_bg = 0x202420FF, ruler_text = 0x808A80FF, ruler_tick = 0x586058FF,
      info_bar_bg = 0x1A1E1AFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5A8A60FF,
      btn_on = 0x8AB060FF, btn_off = 0x404840FF, btn_hover = 0x9AC070FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "neon",
    name = "Neon",
    description = "High energy, fun",
    colors = {
      waveform = 0xFF4488FF, waveform_inactive = 0x992A55FF, waveform_bg = 0x12101AFF,
      centerline = 0x22202AFF, markers = 0x44FF88FF, markers_hover = 0x66FF9AFF,
      border = 0xCC3070FF, playhead = 0x44CCFFFF, grid_bar = 0x302E38FF, grid_beat = 0x201E28FF,
      ruler_bg = 0x1E1C25FF, ruler_text = 0x887898FF, ruler_tick = 0x605068FF,
      info_bar_bg = 0x18161EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xFF4488FF,
      btn_on = 0x44FF88FF, btn_off = 0x403848FF, btn_hover = 0x55FF99FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "bitwig",
    name = "Bitwig",
    description = "Warm orange, modern energy",
    colors = {
      waveform = 0xA0A0A0FF, waveform_inactive = 0x686868FF, waveform_bg = 0x1E1C1AFF,
      centerline = 0x2E2C2AFF, markers = 0xFF8800FF, markers_hover = 0xFFA030FF,
      border = 0x808080FF, playhead = 0xFF8800FF, grid_bar = 0x3A3836FF, grid_beat = 0x2A2826FF,
      ruler_bg = 0x262422FF, ruler_text = 0x909090FF, ruler_tick = 0x686058FF,
      info_bar_bg = 0x201E1CFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xFF8800FF,
      btn_on = 0xFF8800FF, btn_off = 0x484440FF, btn_hover = 0xFFA030FF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "cubase",
    name = "Cubase",
    description = "Cool blue precision",
    colors = {
      waveform = 0x7090A8FF, waveform_inactive = 0x4A6070FF, waveform_bg = 0x181A1EFF,
      centerline = 0x282A2EFF, markers = 0x5A8ACAFF, markers_hover = 0x6A9ADAFF,
      border = 0x607890FF, playhead = 0x5A8ACAFF, grid_bar = 0x323438FF, grid_beat = 0x242628FF,
      ruler_bg = 0x222428FF, ruler_text = 0x8890A0FF, ruler_tick = 0x586070FF,
      info_bar_bg = 0x1C1E22FF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5A8ACAFF,
      btn_on = 0x5A8ACAFF, btn_off = 0x404448FF, btn_hover = 0x6A9ADAFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "logic",
    name = "Logic Pro",
    description = "Minimal apple blue with sage green",
    colors = {
      waveform = 0x6A8A6AFF, waveform_inactive = 0x485A48FF, waveform_bg = 0x1A1A1AFF,
      centerline = 0x2A2A2AFF, markers = 0x4488CCFF, markers_hover = 0x5498DCFF,
      border = 0x5A7A5AFF, playhead = 0x4488CCFF, grid_bar = 0x343434FF, grid_beat = 0x262626FF,
      ruler_bg = 0x242424FF, ruler_text = 0x888888FF, ruler_tick = 0x606060FF,
      info_bar_bg = 0x1C1C1CFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x4488CCFF,
      btn_on = 0x4488CCFF, btn_off = 0x424242FF, btn_hover = 0x5498DCFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "studio_one",
    name = "Studio One",
    description = "Deep purple with blue waveform",
    colors = {
      waveform = 0x5A80B0FF, waveform_inactive = 0x3A5578FF, waveform_bg = 0x181620FF,
      centerline = 0x282630FF, markers = 0x8866BBFF, markers_hover = 0x9876CBFF,
      border = 0x6A5A90FF, playhead = 0x8866BBFF, grid_bar = 0x302E38FF, grid_beat = 0x222028FF,
      ruler_bg = 0x201E28FF, ruler_text = 0x888090FF, ruler_tick = 0x605868FF,
      info_bar_bg = 0x1A181EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x8866BBFF,
      btn_on = 0x8866BBFF, btn_off = 0x403848FF, btn_hover = 0x9876CBFF, btn_text = 0xFFFFFFFF,
    }
  },
  {
    id = "custom",
    name = "Custom",
    description = "Your own color palette",
    colors = {
      waveform = 0x5B7B8AFF, waveform_inactive = 0x3D5560FF, waveform_bg = 0x1C1C1CFF,
      centerline = 0x2C2C2CFF, markers = 0xC9A227FF, markers_hover = 0xDCB53AFF,
      border = 0x4B6B7AFF, playhead = 0xC9A227FF, grid_bar = 0x363636FF, grid_beat = 0x262626FF,
      ruler_bg = 0x242424FF, ruler_text = 0x888888FF, ruler_tick = 0x606060FF,
      info_bar_bg = 0x1E1E1EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0xC9A227FF,
      btn_on = 0xC9A227FF, btn_off = 0x424242FF, btn_hover = 0xD9B237FF, btn_text = 0xFFFFFFFF,
    }
  },
}

settings.BUILTIN_THEME_COUNT = #settings.THEMES
settings.colors_dirty = true
settings.current = { theme_id = "default" }

function settings.save_custom_colors(colors)
  for _, key in ipairs(COLOR_KEYS) do
    if colors[key] then
      reaper.SetExtState(EXT_SECTION, "custom_color_" .. key, tostring(colors[key]), true)
    end
  end
end

function settings.load_custom_colors()
  local colors = {}
  for _, key in ipairs(COLOR_KEYS) do
    local val = reaper.GetExtState(EXT_SECTION, "custom_color_" .. key)
    if val ~= "" then colors[key] = tonumber(val) end
  end
  return colors
end

function settings.save_user_theme(name, colors)
  local id = "user_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
  local theme = { id = id, name = name, description = "Custom", colors = {}, user_theme = true }
  for _, key in ipairs(COLOR_KEYS) do
    theme.colors[key] = colors[key]
  end
  table.insert(settings.THEMES, 1, theme)
  settings._save_all_user_themes()
  return id
end

function settings.delete_user_theme(id)
  for i, theme in ipairs(settings.THEMES) do
    if theme.id == id and theme.user_theme then
      table.remove(settings.THEMES, i)
      break
    end
  end
  settings._save_all_user_themes()
end

function settings._save_all_user_themes()
  local user_themes = {}
  for _, theme in ipairs(settings.THEMES) do
    if theme.user_theme then user_themes[#user_themes + 1] = theme end
  end
  reaper.SetExtState(EXT_SECTION, "user_theme_count", tostring(#user_themes), true)
  for i, theme in ipairs(user_themes) do
    local prefix = "user_theme_" .. i .. "_"
    reaper.SetExtState(EXT_SECTION, prefix .. "id", theme.id, true)
    reaper.SetExtState(EXT_SECTION, prefix .. "name", theme.name, true)
    for _, key in ipairs(COLOR_KEYS) do
      reaper.SetExtState(EXT_SECTION, prefix .. key, tostring(theme.colors[key] or 0), true)
    end
  end
  local i = #user_themes + 1
  while true do
    local prefix = "user_theme_" .. i .. "_"
    local old_id = reaper.GetExtState(EXT_SECTION, prefix .. "id")
    if old_id == "" then break end
    reaper.DeleteExtState(EXT_SECTION, prefix .. "id", true)
    reaper.DeleteExtState(EXT_SECTION, prefix .. "name", true)
    for _, key in ipairs(COLOR_KEYS) do
      reaper.DeleteExtState(EXT_SECTION, prefix .. key, true)
    end
    i = i + 1
  end
end

function settings._load_user_themes()
  local count_str = reaper.GetExtState(EXT_SECTION, "user_theme_count")
  local count = tonumber(count_str) or 0
  for i = 1, count do
    local prefix = "user_theme_" .. i .. "_"
    local id = reaper.GetExtState(EXT_SECTION, prefix .. "id")
    local name = reaper.GetExtState(EXT_SECTION, prefix .. "name")
    if id ~= "" and name ~= "" then
      local colors = {}
      for _, key in ipairs(COLOR_KEYS) do
        local val = reaper.GetExtState(EXT_SECTION, prefix .. key)
        if val ~= "" then colors[key] = tonumber(val) end
      end
      table.insert(settings.THEMES, i, {
        id = id, name = name, description = "Custom", colors = colors, user_theme = true,
      })
    end
  end
end

function settings.get_theme(id)
  for _, theme in ipairs(settings.THEMES) do
    if theme.id == id then return theme end
  end
  return settings.THEMES[1]
end

function settings.get_colors()
  local theme = settings.get_theme(settings.current.theme_id)
  return theme.colors
end

function settings.load()
  settings._load_user_themes()
  local theme_id = reaper.GetExtState(EXT_SECTION, "theme")
  if theme_id and theme_id ~= "" then
    settings.current.theme_id = theme_id
  else
    settings.current.theme_id = "default"
  end
  local custom_colors = settings.load_custom_colors()
  local custom_theme = settings.get_theme("custom")
  if custom_theme then
    for key, val in pairs(custom_colors) do custom_theme.colors[key] = val end
  end
  for _, t in ipairs(settings.THEMES) do
    if not t.colors.highlight then t.colors.highlight = 0x66CCFFFF end
  end
end

function settings.save()
  reaper.SetExtState(EXT_SECTION, "theme", settings.current.theme_id, true)
end

-- ===== APPLY ACTIVE THEME TO THE SCRIPT'S COLOR TABLES =====
local function refresh_colors()
  -- Theme colors only change after a theme/custom-color edit. Avoid doing
  -- dozens of color derivations on every waveform frame while idle.
  if not settings.colors_dirty then return end

  local s = settings.get_theme(settings.current.theme_id)
  if not s then s = settings.get_theme("default") end
  local c = s.colors

  local acc = c.markers or 0xC9A227FF
  local on = c.btn_on or acc
  local off = c.btn_off or 0x424242FF
  local hover = c.btn_hover or on
  local bg = c.waveform_bg or 0x1C1C1CFF
  local info_bg = c.info_bar_bg or 0x1E1E1EFF
  local txt = c.info_bar_text or 0xE0E0E0FF

  -- Waveform core
  COLOR.WAVE = c.waveform or 0xB380CCFF
  COLOR.WAVE_ALT = c.waveform_inactive or 0x80B3CCFF
  COLOR.BG = bg
  COLOR.AXIS = c.centerline or 0xB3B39966
  COLOR.MARKER = acc
  COLOR.MARKER_HOV = c.markers_hover or acc
  COLOR.PLAYHEAD = c.playhead or acc
  COLOR.GRID_LINE = c.grid_bar or 0x44444455
  COLOR.GRID = c.grid_beat or 0xFFFFFF18
  COLOR.RULER_TEXT = c.ruler_text or 0xAAAAAAFF
  COLOR.RULER_TICK = c.ruler_tick or 0x666666FF

  -- Accent-derived fills
  COLOR.REGION = with_alpha(acc, 0x33)
  COLOR.LOOPBAR_FILL = with_alpha(acc, 0xAA)

  -- Ruler / scrollbar chrome
  COLOR.SCROLLBAR_BG = c.ruler_bg or bg
  COLOR.SCROLLBAR_TRACK = offset_color(COLOR.SCROLLBAR_BG, 10)
  COLOR.SCROLLBAR_THUMB = offset_color(COLOR.SCROLLBAR_BG, 40)
  COLOR.SCROLLBAR_THUMB_HOV = offset_color(COLOR.SCROLLBAR_BG, 60)
  COLOR.SCROLLBAR_THUMB_ACT = offset_color(COLOR.SCROLLBAR_BG, 80)

  -- Active controls (accent-driven)
  COLOR.SET_BTN = on
  COLOR.SET_BTN_BG = derive_color(on, 0.30)
  COLOR.TS_BTN = on
  COLOR.TS_BTN_BG = derive_color(on, 0.26)
  COLOR.ZC_ON = on
  COLOR.ZC_ON_BG = derive_color(on, 0.26)
  COLOR.ZC_OFF = off
  COLOR.ZC_OFF_BG = derive_color(off, 0.50)
  COLOR.LOOPLEN_BTN = acc
  COLOR.LOOPLEN_BTN_BG = derive_color(acc, 0.26)

  -- Slots
  COLOR.SLOT_FILLED = on
  COLOR.SLOT_FILLED_BG = derive_color(on, 0.26)
  COLOR.SLOT_HOVERED_BG = derive_color(on, 0.40)
  COLOR.SLOT_ACTIVE = hover
  COLOR.SLOT_ADD = on
  COLOR.SLOT_ADD_BG = derive_color(on, 0.26)

  -- Toggles (Lock / Snap) follow the same button colors
  COLOR.LOCK_ON = on
  COLOR.LOCK_ON_BG = derive_color(on, 0.26)
  COLOR.LOCK_OFF = off
  COLOR.LOCK_OFF_BG = derive_color(off, 0.50)
  COLOR.SNAP_ON = on
  COLOR.SNAP_ON_BG = derive_color(on, 0.26)
  COLOR.SNAP_OFF = off
  COLOR.SNAP_OFF_BG = derive_color(off, 0.50)

  -- Button text is white
  COLOR.BTN_TEXT = c.btn_text or 0xFFFFFFFF

  -- Unified hover + selection highlight (configurable separately)
  local hl = c.highlight or 0x66CCFFFF
  COLOR.HOVER_FG = hl
  COLOR.HOVER_BG = derive_color(hl, 0.35)
  COLOR.SELECTION = with_alpha(hl, 0x55)
  COLOR.SELECTION_BORDER = with_alpha(hl, 0xCC)

  -- UI window chrome
  theme.WindowBg = info_bg
  theme.ChildBg = derive_color(info_bg, 0.90)
  theme.TitleBg = derive_color(info_bg, 0.85)
  theme.TitleBgActive = derive_color(info_bg, 1.10)
  theme.MenuBarBg = derive_color(info_bg, 1.10)
  theme.PopupBg = derive_color(info_bg, 1.15)
  theme.Text = txt
  theme.TextDisabled = c.ruler_text or 0x808080FF
  theme.Border = c.border or 0x505050FF
  theme.Button = off
  theme.ButtonHovered = hover
  theme.ButtonActive = on
  theme.CheckMark = acc
  theme.ActivePreset = acc
  theme.FrameBg = derive_color(info_bg, 1.20)
  theme.FrameBgHovered = derive_color(info_bg, 1.35)
  theme.FrameBgActive = derive_color(info_bg, 1.50)
  theme.Separator = c.border or 0x505050FF
  theme.Header = derive_color(info_bg, 1.15)
  theme.HeaderHovered = derive_color(info_bg, 1.30)
  theme.HeaderActive = derive_color(info_bg, 1.45)
  theme.ScrollbarBg = derive_color(info_bg, 0.90)
  theme.ScrollbarGrab = derive_color(info_bg, 1.40)
  theme.ScrollbarGrabHovered = derive_color(info_bg, 1.60)
  theme.ScrollbarGrabActive = derive_color(info_bg, 1.80)
  settings.colors_dirty = false
end

-- ===== APPEARANCE SETTINGS WINDOW (theme presets + custom editor) =====
local settings_ui = {}

local CORE_COLORS = {
  {key = "waveform_bg", label = "Background"},
  {key = "waveform",    label = "Waveform"},
  {key = "markers",     label = "Accent"},
  {key = "info_bar_text", label = "Text"},
}

local ui_state = {
  open = false,
  pending_theme_id = nil,
  custom_init_from = 0,
  custom_colors_dirty = false,
  custom_save_time = 0,
  save_theme_name = "",
  show_save_input = false,
  save_input_focused = nil,
  delete_confirm_id = nil,
  hovered_theme_id = nil,
}

local COLORS = {
  window_bg = 0x2A2A2AFF, child_bg = 0x252525FF, text = 0xDDDDDDFF, text_dim = 0x888888FF,
  accent = 0x4A90D9FF, accent_hover = 0x5AA0E9FF, accent_active = 0x3A80C9FF,
  btn_default = 0x404040FF, btn_hover = 0x505050FF, btn_active = 0x606060FF,
  separator = 0x444444FF, warning = 0xFF4444FF, unbound = 0x666666FF,
  border = 0x555555FF, header_text = 0xFFFFFFFF,
}

local function init_pending(s)
  ui_state.pending_theme_id = s.current.theme_id
end

function settings_ui.open(s)
  ui_state.open = true
  init_pending(s)
end

function settings_ui.close(s)
  if ui_state.custom_colors_dirty and s then
    local custom_theme = s.get_theme("custom")
    if custom_theme then s.save_custom_colors(custom_theme.colors) end
    ui_state.custom_colors_dirty = false
  end
  ui_state.open = false
end

function settings_ui.is_open()
  return ui_state.open
end

local function draw_color_bar(ctx, colors, width, height)
  local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
  local seg = math.floor(width / 3)
  reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + seg, y + height, colors.waveform_bg)
  reaper.ImGui_DrawList_AddRectFilled(draw_list, x + seg, y, x + seg * 2, y + height, colors.waveform)
  reaper.ImGui_DrawList_AddRectFilled(draw_list, x + seg * 2, y, x + width, y + height, colors.markers)
  reaper.ImGui_DrawList_AddRect(draw_list, x, y, x + width, y + height, 0x00000044, 2)
  reaper.ImGui_Dummy(ctx, width, height)
end

local function color_rgba_to_rgb(c)
  return (c >> 8) & 0xFFFFFF
end

local function color_rgb_to_rgba(c)
  return (c << 8) | 0xFF
end

local AUTO_DERIVE = {
  waveform_bg   = {
    {"centerline", 16, "add"}, {"ruler_bg", 10, "add"}, {"info_bar_bg", 3, "add"},
    {"grid_bar", 28, "add"}, {"grid_beat", 12, "add"}, {"btn_off", 38, "add"},
  },
  waveform      = {{"waveform_inactive", 0.65}, {"border", 0.85}},
  markers       = {
    {"markers_hover", 1.12}, {"playhead", 1.0}, {"btn_on", 1.0},
    {"btn_hover", 1.08}, {"info_bar_icon", 1.0},
  },
  info_bar_text = {{"ruler_text", 0.79}, {"ruler_tick", 0.55}, {"btn_text", 1.57}},
}

local function apply_auto_derive(colors, key)
  local derived_list = AUTO_DERIVE[key]
  if derived_list then
    for _, d in ipairs(derived_list) do
      if d[3] == "add" then
        colors[d[1]] = offset_color(colors[key], d[2])
      else
        colors[d[1]] = derive_color(colors[key], d[2])
      end
    end
  end
end

local function draw_custom_color_editor(ctx, settings_obj)
  local custom_theme = settings_obj.get_theme("custom")
  if not custom_theme then return end

  reaper.ImGui_Dummy(ctx, 0, 4)
  local dl = reaper.ImGui_GetWindowDrawList(ctx)
  local lx, ly = reaper.ImGui_GetCursorScreenPos(ctx)
  local lw = reaper.ImGui_GetContentRegionAvail(ctx)
  reaper.ImGui_DrawList_AddLine(dl, lx, ly, lx + lw, ly, COLORS.separator, 1)
  reaper.ImGui_Dummy(ctx, 0, 6)

  reaper.ImGui_TextColored(ctx, COLORS.text_dim, "Start from:")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, 140)
  if reaper.ImGui_BeginCombo(ctx, "##init_from", settings_obj.THEMES[ui_state.custom_init_from + 1] and settings_obj.THEMES[ui_state.custom_init_from + 1].name or "Select...") then
    for i, theme in ipairs(settings_obj.THEMES) do
      if theme.id ~= "custom" then
        if reaper.ImGui_Selectable(ctx, theme.name, ui_state.custom_init_from == i - 1) then
          ui_state.custom_init_from = i - 1
          for _, key in ipairs(settings_obj.COLOR_KEYS) do
            custom_theme.colors[key] = theme.colors[key]
          end
          settings_obj.save_custom_colors(custom_theme.colors)
          settings_obj.colors_dirty = true
        end
      end
    end
    reaper.ImGui_EndCombo(ctx)
  end

  reaper.ImGui_Spacing(ctx)

  local edit_flags = reaper.ImGui_ColorEditFlags_NoInputs()
  if reaper.ImGui_BeginTable(ctx, "core_colors", 2, reaper.ImGui_TableFlags_None()) then
    for i, entry in ipairs(CORE_COLORS) do
      if (i - 1) % 2 == 0 then reaper.ImGui_TableNextRow(ctx) end
      reaper.ImGui_TableNextColumn(ctx)
      local c = custom_theme.colors[entry.key] or 0xFFFFFFFF
      local rgb = color_rgba_to_rgb(c)
      local rv, new_rgb = reaper.ImGui_ColorEdit3(ctx, entry.label .. "##core_" .. entry.key, rgb, edit_flags)
      if rv then
        custom_theme.colors[entry.key] = color_rgb_to_rgba(new_rgb)
        apply_auto_derive(custom_theme.colors, entry.key)
        ui_state.custom_colors_dirty = true
        settings_obj.colors_dirty = true
      end
    end
    reaper.ImGui_EndTable(ctx)
  end
end

local function draw_theme_row(ctx, theme, settings_obj, bar_w, bar_h)
  local is_selected = ui_state.pending_theme_id == theme.id

  reaper.ImGui_TableNextRow(ctx)
  reaper.ImGui_TableNextColumn(ctx)
  if reaper.ImGui_RadioButton(ctx, theme.name .. "##" .. theme.id, is_selected) then
    if theme.id == "custom" and ui_state.pending_theme_id ~= "custom" then
      local prev_theme = settings_obj.get_theme(ui_state.pending_theme_id)
      local custom_theme = settings_obj.get_theme("custom")
      if prev_theme and custom_theme then
        for _, key in ipairs(settings_obj.COLOR_KEYS) do
          custom_theme.colors[key] = prev_theme.colors[key]
        end
        settings_obj.save_custom_colors(custom_theme.colors)
      end
    end
    ui_state.pending_theme_id = theme.id
    settings_obj.current.theme_id = theme.id
    settings_obj.colors_dirty = true
    settings_obj.save()
  end
  if reaper.ImGui_IsItemHovered(ctx) and theme.description ~= "" then
    reaper.ImGui_SetTooltip(ctx, theme.description)
  end

  reaper.ImGui_TableNextColumn(ctx)
  local cy = reaper.ImGui_GetCursorPosY(ctx)
  reaper.ImGui_SetCursorPosY(ctx, cy + 2)
  draw_color_bar(ctx, theme.colors, bar_w, bar_h)

  reaper.ImGui_TableNextColumn(ctx)
  if theme.user_theme then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 4, 0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x66333399)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xCC444499)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x888888FF)
    local dcy = reaper.ImGui_GetCursorPosY(ctx)
    reaper.ImGui_SetCursorPosY(ctx, dcy + 2)
    local dx = reaper.ImGui_GetCursorPosX(ctx)
    local txw = reaper.ImGui_CalcTextSize(ctx, "x")
    reaper.ImGui_SetCursorPosX(ctx, dx + (22 - (txw + 8)) / 2)
    if reaper.ImGui_SmallButton(ctx, "x##del_" .. theme.id) then
      ui_state.delete_confirm_id = theme.id
    end
    reaper.ImGui_PopStyleColor(ctx, 4)
    reaper.ImGui_PopStyleVar(ctx)
  end
end

local function setup_theme_columns(ctx, bar_w)
  reaper.ImGui_TableSetupColumn(ctx, "name", reaper.ImGui_TableColumnFlags_WidthStretch())
  reaper.ImGui_TableSetupColumn(ctx, "preview", reaper.ImGui_TableColumnFlags_WidthFixed(), bar_w + 8)
  reaper.ImGui_TableSetupColumn(ctx, "del", reaper.ImGui_TableColumnFlags_WidthFixed(), 22)
end

local function draw_appearance_content(ctx, settings_obj)
  local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
  if not reaper.ImGui_BeginChild(ctx, "appearance_scroll", avail_w, avail_h) then return end

  -- Unified highlight + selection color (per-theme, saved with custom themes)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.header_text)
  reaper.ImGui_Text(ctx, "Highlight & Selection")
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_Dummy(ctx, 0, 2)

  local active_hl = settings_obj.get_theme(settings_obj.current.theme_id)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.btn_default)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.btn_hover)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLORS.btn_active)
  if reaper.ImGui_Button(ctx, "Set to Accent##hl_accent") then
    if active_hl and active_hl.colors.markers then
      active_hl.colors.highlight = active_hl.colors.markers
      if settings_obj.current.theme_id == "custom" then
        settings_obj.save_custom_colors(active_hl.colors)
      elseif active_hl.user_theme then
        settings_obj._save_all_user_themes()
      end
      settings_obj.colors_dirty = true
    end
  end
  reaper.ImGui_PopStyleColor(ctx, 3)

  reaper.ImGui_SameLine(ctx)

  local hl = active_hl and active_hl.colors.highlight or 0x66CCFFFF
  local hl_rgb = color_rgba_to_rgb(hl)
  local hl_changed, hl_new = reaper.ImGui_ColorEdit3(ctx, "Color##highlight_color", hl_rgb, reaper.ImGui_ColorEditFlags_NoInputs())
  if hl_changed then
    if active_hl then active_hl.colors.highlight = color_rgb_to_rgba(hl_new) end
    if settings_obj.current.theme_id == "custom" then
      settings_obj.save_custom_colors(active_hl.colors)
    elseif active_hl and active_hl.user_theme then
      settings_obj._save_all_user_themes()
    end
    settings_obj.colors_dirty = true
  end

  reaper.ImGui_Dummy(ctx, 0, 6)
  local hdl = reaper.ImGui_GetWindowDrawList(ctx)
  local hx, hy = reaper.ImGui_GetCursorScreenPos(ctx)
  local hw = reaper.ImGui_GetContentRegionAvail(ctx)
  reaper.ImGui_DrawList_AddLine(hdl, hx, hy, hx + hw, hy, COLORS.separator, 1)
  reaper.ImGui_Dummy(ctx, 0, 6)

  local bar_w = 84
  local bar_h = 14
  local tbl_flags = reaper.ImGui_TableFlags_None()
  local open_delete_popup = false

  local has_user_themes = false
  for _, theme in ipairs(settings_obj.THEMES) do
    if theme.user_theme then has_user_themes = true; break end
  end

  if has_user_themes then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.header_text)
    reaper.ImGui_Text(ctx, "Saved Themes")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_Dummy(ctx, 0, 2)
    if reaper.ImGui_BeginTable(ctx, "user_themes", 3, tbl_flags) then
      setup_theme_columns(ctx, bar_w)
      for _, theme in ipairs(settings_obj.THEMES) do
        if theme.user_theme then
          draw_theme_row(ctx, theme, settings_obj, bar_w, bar_h)
          if ui_state.delete_confirm_id == theme.id then open_delete_popup = true end
        end
      end
      reaper.ImGui_EndTable(ctx)
    end
    reaper.ImGui_Dummy(ctx, 0, 4)
    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    local lx, ly = reaper.ImGui_GetCursorScreenPos(ctx)
    local lw = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_DrawList_AddLine(dl, lx, ly, lx + lw, ly, COLORS.separator, 1)
    reaper.ImGui_Dummy(ctx, 0, 6)
  end

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.header_text)
  reaper.ImGui_Text(ctx, "Built-in Themes")
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_Dummy(ctx, 0, 2)
  if reaper.ImGui_BeginTable(ctx, "preset_themes", 3, tbl_flags) then
    setup_theme_columns(ctx, bar_w)
    for _, theme in ipairs(settings_obj.THEMES) do
      if not theme.user_theme then draw_theme_row(ctx, theme, settings_obj, bar_w, bar_h) end
    end
    reaper.ImGui_EndTable(ctx)
  end

  if open_delete_popup then
    reaper.ImGui_OpenPopup(ctx, "##delete_theme_confirm")
  end
  local del_vp = reaper.ImGui_GetMainViewport(ctx)
  local del_cx, del_cy = reaper.ImGui_Viewport_GetCenter(del_vp)
  reaper.ImGui_SetNextWindowPos(ctx, del_cx, del_cy, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  reaper.ImGui_SetNextWindowSize(ctx, 300, 0, reaper.ImGui_Cond_Appearing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 20, 16)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), 0x2A2A2AFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), COLORS.border)
  local del_flags = reaper.ImGui_WindowFlags_NoTitleBar()
                  + reaper.ImGui_WindowFlags_AlwaysAutoResize()
                  + reaper.ImGui_WindowFlags_NoMove()
  if reaper.ImGui_BeginPopupModal(ctx, "##delete_theme_confirm", nil, del_flags) then
    local del_theme = ui_state.delete_confirm_id and settings_obj.get_theme(ui_state.delete_confirm_id)
    local del_name = del_theme and del_theme.name or "this theme"

    local dtitle = "Delete Theme"
    local dtitle_w = reaper.ImGui_CalcTextSize(ctx, dtitle)
    local dcontent_w = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + (dcontent_w - dtitle_w) / 2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.header_text)
    reaper.ImGui_Text(ctx, dtitle)
    reaper.ImGui_PopStyleColor(ctx)

    reaper.ImGui_Spacing(ctx)
    local ddl = reaper.ImGui_GetWindowDrawList(ctx)
    local dsx, dsy = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_DrawList_AddLine(ddl, dsx, dsy, dsx + dcontent_w, dsy, COLORS.separator, 1)
    reaper.ImGui_Dummy(ctx, 0, 4)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xBBBBBBFF)
    reaper.ImGui_TextWrapped(ctx, "Delete \"" .. del_name .. "\"? This cannot be undone.")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_Dummy(ctx, 0, 4)

    local dbtn_w = (dcontent_w - 8) / 2

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.btn_default)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.btn_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLORS.btn_active)
    if reaper.ImGui_Button(ctx, "Cancel##del_cancel", dbtn_w, 30) then
      ui_state.delete_confirm_id = nil
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_SameLine(ctx)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xCC3333FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xDD4444FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xBB2222FF)
    if reaper.ImGui_Button(ctx, "Delete##del_confirm", dbtn_w, 30) then
      if ui_state.delete_confirm_id then
        if ui_state.pending_theme_id == ui_state.delete_confirm_id then
          ui_state.pending_theme_id = "default"
          settings_obj.current.theme_id = "default"
          settings_obj.colors_dirty = true
          settings_obj.save()
        end
        settings_obj.delete_user_theme(ui_state.delete_confirm_id)
      end
      ui_state.delete_confirm_id = nil
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_EndPopup(ctx)
  end
  reaper.ImGui_PopStyleColor(ctx, 2)
  reaper.ImGui_PopStyleVar(ctx, 2)

  if ui_state.pending_theme_id == "custom" then
    draw_custom_color_editor(ctx, settings_obj)

    reaper.ImGui_Dummy(ctx, 0, 4)
    local dl2 = reaper.ImGui_GetWindowDrawList(ctx)
    local lx2, ly2 = reaper.ImGui_GetCursorScreenPos(ctx)
    local lw2 = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_DrawList_AddLine(dl2, lx2, ly2, lx2 + lw2, ly2, COLORS.separator, 1)
    reaper.ImGui_Dummy(ctx, 0, 6)

    if ui_state.show_save_input then
      reaper.ImGui_TextColored(ctx, COLORS.text_dim, "Name:")
      reaper.ImGui_SameLine(ctx)
      if not ui_state.save_input_focused then
        reaper.ImGui_SetKeyboardFocusHere(ctx, 0)
        ui_state.save_input_focused = true
      end
      reaper.ImGui_SetNextItemWidth(ctx, 160)
      local _, new_name = reaper.ImGui_InputText(ctx, "##save_theme_name", ui_state.save_theme_name)
      ui_state.save_theme_name = new_name
      reaper.ImGui_SameLine(ctx)
      local name_ok = ui_state.save_theme_name ~= ""
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLORS.accent_active)
      if reaper.ImGui_Button(ctx, "Save##save_confirm") and name_ok then
        local source_theme = settings_obj.get_theme("custom")
        if source_theme then
          local new_id = settings_obj.save_user_theme(ui_state.save_theme_name, source_theme.colors)
          ui_state.pending_theme_id = new_id
          settings_obj.current.theme_id = new_id
          settings_obj.colors_dirty = true
          settings_obj.save()
        end
        ui_state.show_save_input = false
        ui_state.save_theme_name = ""
        ui_state.save_input_focused = nil
      end
      reaper.ImGui_PopStyleColor(ctx, 3)
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Cancel##save_cancel") then
        ui_state.show_save_input = false
        ui_state.save_theme_name = ""
        ui_state.save_input_focused = nil
      end
    else
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLORS.accent_active)
      if reaper.ImGui_Button(ctx, "Save current as new theme") then
        ui_state.show_save_input = true
        ui_state.save_theme_name = ""
        ui_state.save_input_focused = nil
      end
      reaper.ImGui_PopStyleColor(ctx, 3)
    end
  end

  reaper.ImGui_EndChild(ctx)
end

function settings_ui.draw(ctx, settings_obj)
  if not ui_state.open then return end

  if ui_state.custom_colors_dirty then
    local now = reaper.time_precise()
    if now - ui_state.custom_save_time > 0.5 then
      local custom_theme = settings_obj.get_theme("custom")
      if custom_theme then settings_obj.save_custom_colors(custom_theme.colors) end
      ui_state.custom_colors_dirty = false
      ui_state.custom_save_time = now
    end
  end

  local viewport = reaper.ImGui_GetMainViewport(ctx)
  local vp_cx, vp_cy = reaper.ImGui_Viewport_GetCenter(viewport)
  reaper.ImGui_SetNextWindowPos(ctx, vp_cx, vp_cy, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
  reaper.ImGui_SetNextWindowSize(ctx, 500, 620, reaper.ImGui_Cond_FirstUseEver())

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), COLORS.window_bg)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), COLORS.window_bg)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), COLORS.border)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.btn_default)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.btn_hover)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), COLORS.btn_active)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), COLORS.separator)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x333333FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), 0x3D3D3DFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), 0x222222FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x2A2A2AFF)
  local style_color_count = 11
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 20, 16)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 8)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 6)
  local style_var_count = 5

  local flags = reaper.ImGui_WindowFlags_NoCollapse()
  local visible, open = reaper.ImGui_Begin(ctx, "FSR LoopX - Colors & Themes", true, flags)

  if not open then
    settings_ui.close(settings_obj)
    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, style_var_count)
    reaper.ImGui_PopStyleColor(ctx, style_color_count)
    return
  end

  if visible then
    reaper.ImGui_Spacing(ctx)
    draw_appearance_content(ctx, settings_obj)
  end

  reaper.ImGui_End(ctx)
  reaper.ImGui_PopStyleVar(ctx, style_var_count)
  reaper.ImGui_PopStyleColor(ctx, style_color_count)
end

settings.load()
refresh_colors()

local MARKER_W    = 8
local RULER_H     = 22
local PADDING     = 8
local WIN_PAD     = 6
local SET_BTN_W   = 40
local SET_BTN_H   = 18
local LOOPBAR_H   = 14
local SLOT_W      = 22
local SLOT_GAP    = 3
local ADD_BTN_W   = 20
local LOCK_BTN_W  = 22
local SETTINGS_BTN_W = 26
local ZC_BTN_W    = 26
local TS_BTN_W    = 22
local SNAP_BTN_W  = 34
local SLOT_ZONE_H = 6

-- ===== GRID SYSTEM (FIXED ONLY) =====
local GRID_FIXED_OPTIONS = {
  {id = "1",     label = "1",    qn = 4},
  {id = "1/2",   label = "1/2",  qn = 2},
  {id = "1/4",   label = "1/4",  qn = 1},
  {id = "1/8",   label = "1/8",  qn = 0.5},
  {id = "1/16",  label = "1/16", qn = 0.25},
  {id = "1/32",  label = "1/32", qn = 0.125},
}

local grid_settings = { fixed = "1/8", triplet = false }
local grid_popup_x = nil
local grid_popup_y = nil

local loop_len_popup_x = nil
local loop_len_popup_y = nil

local settings_popup_x = nil
local settings_popup_y = nil

local snap_enabled = false

local function save_snap_state()
  reaper.SetExtState(EXT_SECTION, "snap_enabled", snap_enabled and "1" or "0", true)
end

local function load_snap_state()
  snap_enabled = (reaper.GetExtState(EXT_SECTION, "snap_enabled") == "1")
end

local function save_grid_setting(name)
  reaper.SetExtState(EXT_SECTION, "grid_" .. name, tostring(grid_settings[name]), true)
end

local function load_grid_settings()
  local defaults = { fixed = "1/8", triplet = false }
  for name, default_val in pairs(defaults) do
    local saved = reaper.GetExtState(EXT_SECTION, "grid_" .. name)
    if saved ~= "" then
      if type(default_val) == "boolean" then
        grid_settings[name] = (saved == "true")
      else
        grid_settings[name] = saved
      end
    else
      grid_settings[name] = default_val
    end
  end
end

local zoom        = 1.0
local pan_offset  = 0.0
local v_zoom      = 1.0
local last_item_guid = nil
local DRAG_THRESH = 4

local item_zoom_cache = {}

local selection_start = nil
local selection_end = nil
local is_selecting = false

local FINE_MODE_DIVISOR = 10

local AUTO_SCROLL_ZONE = 30
local AUTO_SCROLL_SPEED = 0.02
local EDGE_SCROLL_MARGIN = 5

local drag_mode = nil
local drag_activated = false
local drag_start_mx, drag_start_s, drag_start_e = 0, 0, 0
local drag_root_fn = nil
local drag_root_type = nil

local loopbar_drag = false
local loopbar_drag_start_mx, loopbar_drag_start_s, loopbar_drag_start_e = 0, 0, 0
local loopbar_drag_root_fn = nil
local loopbar_drag_root_type = nil

local loop_preview_start = nil
local loop_preview_end = nil
local last_loop_chunk_update = 0
local last_loop_written_start = nil
local last_loop_written_end = nil
local LOOP_CHUNK_UPDATE_INTERVAL = 0.05

local ruler_scroll_drag = false
local ruler_scroll_start_mx, ruler_scroll_start_off = 0, 0

local is_panning = false
local pan_start_mx, pan_start_off = 0, 0

local SAMPLE_POINT_RADIUS = 2.5

local item_slots = {}
local MAX_SLOTS = 10

-- ===== GRID REFERENCE MEMORY (per item GUID) =====
-- Stores the last loop-section bounds (source-time s/e) that were committed
-- while GRID-SNAP was active for a given item. When grid-snap is toggled
-- back ON, this stored position is automatically re-applied, so the loop
-- always returns to its exact tempo-locked alignment - even if it was
-- dragged around freely (no snap / zero-cross snap) in the meantime.
local grid_reference = {}

local wav_cache = {
  file_path = nil, samples = nil, nchans = 0, srate = 0,
  src_len = 0, total_samples = 0, bitspersample = 0,
}

local view_cache = {
  view_start = -1, view_len = -1, num_points = -1,
  file_path = nil, v_zoom = -1, mode = nil, data = nil,
}

-- Cached ruler/grid geometry. The draw list is rebuilt every frame, but the
-- expensive time-map calculations only need to run when the view/layout/grid
-- inputs change.
local ruler_grid_cache = {}

local current_take = nil
local current_item = nil
local current_section_off = 0
local current_playrate = 1
local current_src_len = 0

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_huge = math.huge
local math_ceil = math.ceil
local math_log = math.log
local string_format = string.format

load_persistent_state()
load_grid_settings()
load_snap_state()

local prev_window_locked = window_locked
local prev_zero_cross_snap = zero_cross_snap
local prev_locked_pos_x = locked_pos_x
local prev_locked_pos_y = locked_pos_y
local prev_locked_size_w = locked_size_w
local prev_locked_size_h = locked_size_h

local function check_and_save_state()
  local changed = false
  if window_locked ~= prev_window_locked then changed = true end
  if zero_cross_snap ~= prev_zero_cross_snap then changed = true end
  if locked_pos_x ~= prev_locked_pos_x then changed = true end
  if locked_pos_y ~= prev_locked_pos_y then changed = true end
  if locked_size_w ~= prev_locked_size_w then changed = true end
  if locked_size_h ~= prev_locked_size_h then changed = true end
  if changed then
    save_persistent_state()
    prev_window_locked = window_locked
    prev_zero_cross_snap = zero_cross_snap
    prev_locked_pos_x = locked_pos_x
    prev_locked_pos_y = locked_pos_y
    prev_locked_size_w = locked_size_w
    prev_locked_size_h = locked_size_h
  end
end

local function fmt_time(t)
  if t < 60 then return string_format("%.3fs", t)
  else return string_format("%d:%06.3f", math_floor(t / 60), t % 60) end
end

local function get_item_guid(item)
  if not item then return nil end
  local retval, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
  return retval and guid or nil
end

local function get_root_source(source)
  if not source then return nil end
  local root = source
  while true do
    local parent = reaper.GetMediaSourceParent(root)
    if not parent then break end
    root = parent
  end
  return root
end

local function load_wav_direct(file_path)
  if not file_path or file_path == "" then return false end
  if wav_cache.file_path == file_path and wav_cache.samples then return true end
  view_cache.file_path = nil
  local file = io.open(file_path, "rb")
  if not file then return false end
  local header = file:read(12)
  if not header or #header < 12 then file:close(); return false end
  local riff_id, riff_size, wave_id = string.unpack("<c4 I4 c4", header)
  if riff_id ~= "RIFF" or wave_id ~= "WAVE" then file:close(); return false end
  local file_size = riff_size + 8
  local find_limit = math_min(file_size, 1024 * 1024)
  file:seek("set", 0)
  local search_data = file:read(find_limit)
  local fmt_start = search_data:find("fmt ")
  local data_start = search_data:find("data")
  if not fmt_start or not data_start then file:close(); return false end
  file:seek("set", fmt_start - 1)
  local fmt_data = file:read(24)
  if not fmt_data or #fmt_data < 24 then file:close(); return false end
  local fmt_id, fmt_size, audio_format, nchans, srate, byterate, blockalign, bitspersample =
    string.unpack("<c4 I4 I2 I2 I4 I4 I2 I2", fmt_data)
  if audio_format ~= 1 and audio_format ~= 3 then file:close(); return false end
  file:seek("set", data_start - 1)
  local data_header = file:read(8)
  if not data_header or #data_header < 8 then file:close(); return false end
  local data_id, data_size = string.unpack("<c4 I4", data_header)
  local data_block_start = data_start + 8
  local total_samples = data_size // blockalign
  local pack_fmt, bytes_per_sample
  if bitspersample == 16 then pack_fmt = "<i2"; bytes_per_sample = 2
  elseif bitspersample == 24 then pack_fmt = "<i3"; bytes_per_sample = 3
  elseif bitspersample == 32 then pack_fmt = "<f"; bytes_per_sample = 4
  elseif bitspersample == 64 then pack_fmt = "<d"; bytes_per_sample = 8
  else file:close(); return false end
  local max_cache_samples = 200000
  local step = math_max(1, math_floor(total_samples / max_cache_samples))
  local cached_samples = math_floor(total_samples / step)
  local norm_factor
  if pack_fmt == "<f" or pack_fmt == "<d" then norm_factor = 1.0
  else norm_factor = 2^(bitspersample - 1) end
  local samples = {}
  for ch = 1, nchans do samples[ch] = {} end
  file:seek("set", data_block_start - 1)
  local sample_idx = 1
  local read_pos = 0
  local chunk_size = 65536
  while sample_idx <= cached_samples and read_pos < total_samples do
    local bytes_to_read = math_min(chunk_size * blockalign, (total_samples - read_pos) * blockalign)
    local chunk = file:read(bytes_to_read)
    if not chunk then break end
    local chunk_samples = #chunk // blockalign
    local byte_pos = 1
    for s = 1, chunk_samples do
      if (read_pos + s - 1) % step == 0 and sample_idx <= cached_samples then
        for ch = 1, nchans do
          local ss = byte_pos + (ch - 1) * bytes_per_sample
          local se = ss + bytes_per_sample - 1
          if se <= #chunk then
            samples[ch][sample_idx] = string.unpack(pack_fmt, chunk:sub(ss, se)) / norm_factor
          else samples[ch][sample_idx] = 0 end
        end
        sample_idx = sample_idx + 1
      end
      byte_pos = byte_pos + blockalign
    end
    read_pos = read_pos + chunk_samples
  end
  file:close()
  wav_cache.file_path = file_path
  wav_cache.samples = samples
  wav_cache.nchans = nchans
  wav_cache.srate = srate
  wav_cache.src_len = total_samples / srate
  wav_cache.total_samples = sample_idx - 1
  wav_cache.bitspersample = bitspersample
  wav_cache.step = step
  return true
end

local function find_zero_crossing(time_pos, search_radius)
  if not wav_cache.samples or wav_cache.total_samples < 2 then return time_pos end
  local src_len = wav_cache.src_len
  local total = wav_cache.total_samples
  local nchans = wav_cache.nchans
  local center_idx = math_floor((time_pos / src_len) * total) + 1
  local radius_samples = math_floor((search_radius / src_len) * total)
  radius_samples = math_max(1, math_min(radius_samples, 500))
  local idx_lo = math_max(1, center_idx - radius_samples)
  local idx_hi = math_min(total - 1, center_idx + radius_samples)
  local best_idx = center_idx
  local best_dist = math_huge
  local ch1 = wav_cache.samples[1]
  for i = idx_lo, idx_hi do
    local v1 = ch1[i] or 0
    local v2 = ch1[i + 1] or 0
    if (v1 >= 0 and v2 <= 0) or (v1 <= 0 and v2 >= 0) then
      local cross_idx
      local dv = v1 - v2
      if math_abs(dv) > 1e-12 then cross_idx = i + v1 / dv
      else cross_idx = i + 0.5 end
      local dist = math_abs(cross_idx - center_idx)
      if dist < best_dist then best_dist = dist; best_idx = cross_idx end
    end
  end
  if nchans > 1 and best_dist < math_huge then
    local multi_best_idx = center_idx
    local multi_best_score = math_huge
    for i = idx_lo, idx_hi do
      local all_cross = true
      local total_score = 0
      for ch = 1, nchans do
        local cs = wav_cache.samples[ch]
        local v1 = cs[i] or 0
        local v2 = cs[i + 1] or 0
        if (v1 >= 0 and v2 <= 0) or (v1 <= 0 and v2 >= 0) then
          total_score = total_score + math_abs(i - center_idx)
        else all_cross = false; break end
      end
      if all_cross then
        local score = total_score / nchans
        if score < multi_best_score then
          multi_best_score = score
          local v1 = ch1[i] or 0
          local v2 = ch1[i + 1] or 0
          local dv = v1 - v2
          if math_abs(dv) > 1e-12 then multi_best_idx = i + v1 / dv
          else multi_best_idx = i + 0.5 end
        end
      end
    end
    if multi_best_score < math_huge then best_idx = multi_best_idx end
  end
  local result_time = ((best_idx - 1) / total) * src_len
  return math_max(0, math_min(src_len, result_time))
end

local function snap_time(t)
  if zero_cross_snap then return find_zero_crossing(t, ZC_SEARCH_RADIUS) end
  return t
end

local function snap_region(new_start, region_len, src_len)
  if not zero_cross_snap then return new_start end
  local snapped_s = find_zero_crossing(new_start, ZC_SEARCH_RADIUS)
  local snapped_e = find_zero_crossing(snapped_s + region_len, ZC_SEARCH_RADIUS)
  local adjusted_s = snapped_e - region_len
  local dist_s = math_abs(snapped_s - new_start)
  local dist_adj = math_abs(adjusted_s - new_start)
  local final_s = dist_s <= dist_adj and snapped_s or adjusted_s
  return math_max(0, math_min(src_len - region_len, final_s))
end

-- ===== SOURCE <-> PROJECT TIME MAPPING (for tempo grid) =====
local function source_to_project_time(source_t, item_position, start_offset, playrate)
  if playrate == 0 then playrate = 1 end
  return item_position + (source_t - start_offset) / playrate
end

local function project_to_source_time(project_t, item_position, start_offset, playrate)
  return start_offset + (project_t - item_position) * playrate
end

local function get_fixed_grid_qn(division_id)
  for _, opt in ipairs(GRID_FIXED_OPTIONS) do
    if opt.id == division_id then return opt.qn end
  end
  return nil
end

local function get_fixed_grid_label(division_id)
  for _, opt in ipairs(GRID_FIXED_OPTIONS) do
    if opt.id == division_id then return opt.label end
  end
  return "1/8"
end

local function get_effective_grid_qn()
  return get_fixed_grid_qn(grid_settings.fixed) or 0.5
end

local function step_grid(direction)
  local opts = GRID_FIXED_OPTIONS
  local cur_idx = 1
  for i, opt in ipairs(opts) do
    if opt.id == grid_settings.fixed then cur_idx = i; break end
  end
  local new_idx = math_max(1, math_min(#opts, cur_idx - direction))
  grid_settings.fixed = opts[new_idx].id
  save_grid_setting("fixed")
end

local VIEW_CACHE_TOLERANCE = 0.0001

local function get_view_data(view_start, view_len, num_points)
  if not wav_cache.samples or wav_cache.total_samples < 1 then return nil end
  if view_cache.data and view_cache.file_path == wav_cache.file_path
    and view_cache.mode == waveform_mode
    and view_cache.num_points == num_points
    and math_abs(view_cache.view_start - view_start) < VIEW_CACHE_TOLERANCE
    and math_abs(view_cache.view_len - view_len) < VIEW_CACHE_TOLERANCE then
    return view_cache.data
  end
  local src_len = wav_cache.src_len
  local total = wav_cache.total_samples
  local source_nchans = wav_cache.nchans
  local output_nchans = (waveform_mode == "stereo") and source_nchans or 1
  if output_nchans < 1 then output_nchans = 1 end
  local mono_sum = waveform_mode == "mono_sum"
  local sum_nchans = math_min(source_nchans, 2)
  if sum_nchans < 1 then sum_nchans = 1 end
  local cache_samples_per_point = (view_len / src_len * total) / num_points
  local is_detailed = cache_samples_per_point <= 1.5
  local result = view_cache.data
  if not result or result.nchans ~= output_nchans then
    result = {nchans = output_nchans, count = num_points, is_detailed = is_detailed}
    for ch = 1, output_nchans do result[ch] = {} end
  else result.count = num_points; result.is_detailed = is_detailed end
  local inv_num_points = view_len / num_points
  local inv_src_len = 1.0 / src_len
  for i = 1, num_points do
    local t = view_start + (i - 1) * inv_num_points
    local cache_idx_f = (t * inv_src_len) * total
    local cache_idx = math_floor(cache_idx_f) + 1
    cache_idx = math_max(1, math_min(total, cache_idx))
    if is_detailed then
      local exact_idx = cache_idx_f + 1
      local idx1 = math_floor(exact_idx)
      local idx2 = math_min(total, idx1 + 1)
      local frac = exact_idx - idx1
      idx1 = math_max(1, math_min(total, idx1))
      if mono_sum then
        local mixed = 0
        for ch = 1, sum_nchans do
          local cs = wav_cache.samples[ch]
          mixed = mixed + (cs[idx1] or 0) + ((cs[idx2] or 0) - (cs[idx1] or 0)) * frac
        end
        result[1][i] = mixed / sum_nchans
      else
        for out_ch = 1, output_nchans do
          local src_ch = out_ch
          if waveform_mode == "mono_right" then src_ch = math_max(1, math_min(2, source_nchans)) end
          local cs = wav_cache.samples[src_ch]
          result[out_ch][i] = (cs[idx1] or 0) + ((cs[idx2] or 0) - (cs[idx1] or 0)) * frac
        end
      end
    else
      local idx_end = math_min(total, math_floor(cache_idx + cache_samples_per_point))
      local span = idx_end - cache_idx
      local jstep = 1
      if span > 8192 then jstep = math_floor(span / 4096) end
      if mono_sum then
        local cmin, cmax = math_huge, -math_huge
        for j = cache_idx, idx_end, jstep do
          local mixed = 0
          for ch = 1, sum_nchans do mixed = mixed + (wav_cache.samples[ch][j] or 0) end
          mixed = mixed / sum_nchans
          if mixed < cmin then cmin = mixed end
          if mixed > cmax then cmax = mixed end
        end
        if cmin == math_huge then cmin = 0 end
        if cmax == -math_huge then cmax = 0 end
        local entry = result[1][i]
        if type(entry) == "table" then entry[1] = cmin; entry[2] = cmax
        else result[1][i] = {cmin, cmax} end
      else
        for out_ch = 1, output_nchans do
          local src_ch = out_ch
          if waveform_mode == "mono_right" then src_ch = math_max(1, math_min(2, source_nchans)) end
          local cs = wav_cache.samples[src_ch]
          local cmin, cmax = math_huge, -math_huge
          for j = cache_idx, idx_end, jstep do
            local v = cs[j] or 0
            if v < cmin then cmin = v end
            if v > cmax then cmax = v end
          end
          if cmin == math_huge then cmin = 0 end
          if cmax == -math_huge then cmax = 0 end
          local entry = result[out_ch][i]
          if type(entry) == "table" then entry[1] = cmin; entry[2] = cmax
          else result[out_ch][i] = {cmin, cmax} end
        end
      end
    end
  end
  for ch = 1, output_nchans do
    local cd = result[ch]
    for i = num_points + 1, #cd do cd[i] = nil end
  end
  view_cache.view_start = view_start
  view_cache.view_len = view_len
  view_cache.num_points = num_points
  view_cache.file_path = wav_cache.file_path
  view_cache.mode = waveform_mode
  view_cache.data = result
  return result
end

local DL_AddLine = reaper.ImGui_DrawList_AddLine
local DL_AddRectFilled = reaper.ImGui_DrawList_AddRectFilled
local DL_AddRect = reaper.ImGui_DrawList_AddRect
local DL_AddText = reaper.ImGui_DrawList_AddText
local DL_AddCircleFilled = reaper.ImGui_DrawList_AddCircleFilled
local DL_AddTriangleFilled = reaper.ImGui_DrawList_AddTriangleFilled
local DL_AddTextEx = reaper.ImGui_DrawList_AddTextEx
local DL_PathClear = reaper.ImGui_DrawList_PathClear
local DL_PathLineTo = reaper.ImGui_DrawList_PathLineTo
local DL_PathStroke = reaper.ImGui_DrawList_PathStroke

local function draw_waveform(dl, data, wave_x, wave_y, wave_w, wave_h, v_zoom_level)
  if not data then return end
  local nchans = data.nchans
  local count = data.count
  if count < 2 then return end
  local chan_h = wave_h / nchans
  local px_step = wave_w / (count - 1)
  for ch = 1, nchans do
    local cy = wave_y + (ch - 1) * chan_h
    local axis_y = cy + chan_h / 2
    local half_h = chan_h / 2 * 0.95
    local smpls = data[ch]
    local color = (ch == 1) and COLOR.WAVE or COLOR.WAVE_ALT
    DL_AddLine(dl, wave_x, axis_y, wave_x + wave_w, axis_y, COLOR.AXIS, 1)
    if ch < nchans then
      DL_AddLine(dl, wave_x, cy + chan_h, wave_x + wave_w, cy + chan_h, 0x444444FF, 1)
    end
    if data.is_detailed then
      local show_dots = count < 80
      -- One path is much cheaper than one draw-list line per sample.
      DL_PathClear(dl)
      for i = 1, count do
        local x = wave_x + (i - 1) * px_step
        local val = (smpls[i] or 0) * v_zoom_level
        if val > 1 then val = 1 elseif val < -1 then val = -1 end
        local y = axis_y - val * half_h
        DL_PathLineTo(dl, x, y)
      end
      DL_PathStroke(dl, color, 0, 1.5)
      if show_dots then
        for i = 1, count do
          local x = wave_x + (i - 1) * px_step
          local val = (smpls[i] or 0) * v_zoom_level
          if val > 1 then val = 1 elseif val < -1 then val = -1 end
          local y = axis_y - val * half_h
          DL_AddCircleFilled(dl, x, y, SAMPLE_POINT_RADIUS, color)
        end
      end
    else
      for i = 1, count do
        local x = wave_x + (i - 1) * px_step
        local val = smpls[i]
        local vmin, vmax
        if type(val) == "table" then vmin, vmax = val[1] * v_zoom_level, val[2] * v_zoom_level
        else val = (val or 0) * v_zoom_level; vmin, vmax = val, val end
        if vmin < -1 then vmin = -1 elseif vmin > 1 then vmin = 1 end
        if vmax < -1 then vmax = -1 elseif vmax > 1 then vmax = 1 end
        local yt = axis_y - vmax * half_h
        local yb = axis_y - vmin * half_h
        DL_AddLine(dl, x, yt, x, yb, color, 1)
      end
    end
  end
end

local function has_valid_selection()
  return selection_start ~= nil and selection_end ~= nil and selection_start ~= selection_end
end

-- ===== ABLETON-STYLE LOOP SECTION HELPERS =====
local function find_nth_source_block(chunk, target_idx)
  local pos = 1
  local idx = -1
  local len = #chunk
  while true do
    local s = chunk:find("<SOURCE", pos, true)
    if not s then return nil end
    local depth = 0
    local i = s
    local e = nil
    while i <= len do
      local c = chunk:sub(i, i)
      if c == "<" then depth = depth + 1
      elseif c == ">" then
        depth = depth - 1
        if depth == 0 then e = i; break end
      end
      i = i + 1
    end
    if not e then return nil end
    idx = idx + 1
    if idx == target_idx then return s, e end
    pos = e + 1
  end
end

local function set_take_loop_section(item, take, root_fn, root_type, loop_start, loop_len)
  if not root_fn or root_fn == "" then return false end
  if loop_len < 0.001 then loop_len = 0.001 end
  if loop_start < 0 then loop_start = 0 end

  local take_idx = math_floor(reaper.GetMediaItemTakeInfo_Value(take, "IP_TAKENUMBER") + 0.5)

  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  if not ok then return false end

  local s, e = find_nth_source_block(chunk, take_idx)
  if not s then return false end

  local new_block = string.format(
    '<SOURCE SECTION\nLENGTH %.15f\nSTARTPOS %.15f\nOVERLAP %.6f\n<SOURCE %s\nFILE "%s"\n>\n>',
    loop_len, loop_start, 0.01, root_type, root_fn)

  local new_chunk = chunk:sub(1, s - 1) .. new_block .. chunk:sub(e + 1)
  return reaper.SetItemStateChunk(item, new_chunk, false)
end

-- ===== GRID REFERENCE HELPERS =====
local function save_grid_reference(guid, s, e)
  if not guid then return end
  grid_reference[guid] = {s = s, e = e}
end

local function get_grid_reference(guid)
  if not guid then return nil end
  return grid_reference[guid]
end

local function apply_selection()
  if not has_valid_selection() then return false end
  if not current_take or not current_item then return false end
  local sel_s = math_min(selection_start, selection_end)
  local sel_e = math_max(selection_start, selection_end)
  if zero_cross_snap then
    sel_s = find_zero_crossing(sel_s, ZC_SEARCH_RADIUS)
    sel_e = find_zero_crossing(sel_e, ZC_SEARCH_RADIUS)
  end
  sel_s = math_max(0, math_min(current_src_len, sel_s))
  sel_e = math_max(0, math_min(current_src_len, sel_e))
  if sel_e > sel_s then
    local source = reaper.GetMediaItemTake_Source(current_take)
    local root = get_root_source(source)
    local root_fn = reaper.GetMediaSourceFileName(root, "")
    local root_type = reaper.GetMediaSourceType(root, "")
    if set_take_loop_section(current_item, current_take, root_fn, root_type, sel_s, sel_e - sel_s) then
      local new_take = reaper.GetActiveTake(current_item)
      if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
      reaper.SetMediaItemInfo_Value(current_item, "B_LOOPSRC", 1)
      -- If grid-snap is currently active, this explicit "SET" counts as a
      -- grid-aligned commit worth remembering for future auto-restore.
      if snap_enabled then save_grid_reference(last_item_guid, sel_s, sel_e) end
    end
    reaper.UpdateArrange()
    reaper.Undo_OnStateChangeEx("Set item bounds from selection", -1, -1)
    selection_start = nil; selection_end = nil
    return true
  end
  return false
end

local function set_time_selection_to_item()
  if not current_item then return end
  local item_pos = reaper.GetMediaItemInfo_Value(current_item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(current_item, "D_LENGTH")
  reaper.GetSet_LoopTimeRange(true, false, item_pos, item_pos + item_len, false)
  reaper.SetEditCurPos(item_pos, false, false)
  reaper.UpdateArrange()
end

local function get_slots(guid)
  if not guid then return {} end
  if not item_slots[guid] then item_slots[guid] = {} end
  return item_slots[guid]
end

local function add_slot(guid, start_off, end_off)
  if not guid then return false end
  local slots = get_slots(guid)
  if #slots >= MAX_SLOTS then return false end
  slots[#slots + 1] = {s = start_off, e = end_off}
  return true
end

local function remove_slot(guid, index)
  if not guid then return end
  local slots = get_slots(guid)
  if index >= 1 and index <= #slots then table.remove(slots, index) end
end

local function apply_slot(guid, index)
  if not current_take or not current_item then return false end
  local slots = get_slots(guid)
  if index < 1 or index > #slots then return false end
  local slot = slots[index]
  local s = math_max(0, math_min(current_src_len, slot.s))
  local e = math_max(0, math_min(current_src_len, slot.e))
  if e > s then
    local source = reaper.GetMediaItemTake_Source(current_take)
    local root = get_root_source(source)
    local root_fn = reaper.GetMediaSourceFileName(root, "")
    local root_type = reaper.GetMediaSourceType(root, "")
    if set_take_loop_section(current_item, current_take, root_fn, root_type, s, e - s) then
      local new_take = reaper.GetActiveTake(current_item)
      if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
      reaper.SetMediaItemInfo_Value(current_item, "B_LOOPSRC", 1)
      -- Same logic as apply_selection: if grid-snap is active, this becomes
      -- the new remembered reference point for this item.
      if snap_enabled then save_grid_reference(guid, s, e) end
    end
    reaper.UpdateArrange()
    reaper.Undo_OnStateChangeEx("Apply slot " .. index, -1, -1)
    return true
  end
  return false
end

local last_arrange_update = 0
local ARRANGE_UPDATE_INTERVAL = 0.033

local function throttled_update_arrange()
  local now = reaper.time_precise()
  if now - last_arrange_update >= ARRANGE_UPDATE_INTERVAL then
    reaper.UpdateArrange()
    last_arrange_update = now
  end
end

local slot_keys = {
  reaper.ImGui_Key_1(), reaper.ImGui_Key_2(), reaper.ImGui_Key_3(),
  reaper.ImGui_Key_4(), reaper.ImGui_Key_5(), reaper.ImGui_Key_6(),
  reaper.ImGui_Key_7(), reaper.ImGui_Key_8(), reaper.ImGui_Key_9(),
  reaper.ImGui_Key_0(),
}

local initial_pos_set = false
local FRAME_INTERVAL = 1 / 60
local last_frame_time = 0

local function loop()
  local now = reaper.time_precise()
  if now - last_frame_time < FRAME_INTERVAL then
    reaper.defer(loop)
    return
  end
  last_frame_time = now

  settings_ui.draw(ctx, settings)
  refresh_colors()
  local open = true
  local flags = reaper.ImGui_WindowFlags_NoCollapse()

  if window_locked then
    flags = flags | reaper.ImGui_WindowFlags_NoMove() | reaper.ImGui_WindowFlags_NoResize()
    if locked_pos_x and locked_pos_y then
      reaper.ImGui_SetNextWindowPos(ctx, locked_pos_x, locked_pos_y)
    end
    if locked_size_w and locked_size_h then
      reaper.ImGui_SetNextWindowSize(ctx, locked_size_w, locked_size_h)
    end
  elseif not initial_pos_set and locked_pos_x and locked_pos_y then
    reaper.ImGui_SetNextWindowPos(ctx, locked_pos_x, locked_pos_y, reaper.ImGui_Cond_FirstUseEver())
    if locked_size_w and locked_size_h then
      reaper.ImGui_SetNextWindowSize(ctx, locked_size_w, locked_size_h, reaper.ImGui_Cond_FirstUseEver())
    end
    initial_pos_set = true
  end

  reaper.ImGui_PushFont(ctx, font, 13)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), WIN_PAD, WIN_PAD)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 3)
  applyTheme()

  local visible
  visible, open = reaper.ImGui_Begin(ctx, "FSR LoopX", true, flags)

  if visible then
    if not window_locked then
      locked_pos_x, locked_pos_y = reaper.ImGui_GetWindowPos(ctx)
      locked_size_w, locked_size_h = reaper.ImGui_GetWindowSize(ctx)
    end

    local is_focused = reaper.ImGui_IsWindowFocused(ctx, reaper.ImGui_FocusedFlags_RootAndChildWindows())

    if is_focused then
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space(), false) then
        reaper.Main_OnCommand(40044, 0)
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter(), false) then
        apply_selection()
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape(), false) then
        selection_start = nil; selection_end = nil
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z(), false) then
        local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        if not ctrl then zero_cross_snap = not zero_cross_snap end
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_GraveAccent(), false) then
        zoom = 1.0; pan_offset = 0.0
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_T(), false) then
        set_time_selection_to_item()
      end
      local ctrl_grid = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
      if ctrl_grid then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_1(), false) then step_grid(-1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_2(), false) then step_grid(1) end
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_3(), false) then
          grid_settings.triplet = not grid_settings.triplet
          save_grid_setting("triplet")
        end
      end
    end

    local item = reaper.GetSelectedMediaItem(0, 0)
    local current_guid = get_item_guid(item)

    if current_guid ~= last_item_guid then
      if last_item_guid then
        item_zoom_cache[last_item_guid] = {zoom = zoom, pan_offset = pan_offset}
      end
      if current_guid and item_zoom_cache[current_guid] then
        zoom = item_zoom_cache[current_guid].zoom
        pan_offset = item_zoom_cache[current_guid].pan_offset
      else zoom = 1.0; pan_offset = 0.0 end
      last_item_guid = current_guid
      selection_start = nil; selection_end = nil
    end

    if not item or not reaper.ValidatePtr(item, "MediaItem*") then
      current_item = nil; current_take = nil
      local aw, ah = reaper.ImGui_GetContentRegionAvail(ctx)
      local msg = "Select an audio item"
      local tw = reaper.ImGui_CalcTextSize(ctx, msg)
      reaper.ImGui_SetCursorPos(ctx, (aw - tw) / 2, ah / 2)
      reaper.ImGui_TextColored(ctx, theme.TextDisabled, msg)
      reaper.ImGui_End(ctx); popTheme()
      reaper.ImGui_PopStyleVar(ctx, 5); reaper.ImGui_PopFont(ctx)
      check_and_save_state()
      if open then reaper.defer(loop) end; return
    end

    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then
      current_item = nil; current_take = nil
      reaper.ImGui_Text(ctx, "Audio take required")
      reaper.ImGui_End(ctx); popTheme()
      reaper.ImGui_PopStyleVar(ctx, 5); reaper.ImGui_PopFont(ctx)
      check_and_save_state()
      if open then reaper.defer(loop) end; return
    end

    local source = reaper.GetMediaItemTake_Source(take)
    local root = get_root_source(source)
    if not root then
      current_item = nil; current_take = nil
      reaper.ImGui_Text(ctx, "Invalid source")
      reaper.ImGui_End(ctx); popTheme()
      reaper.ImGui_PopStyleVar(ctx, 5); reaper.ImGui_PopFont(ctx)
      check_and_save_state()
      if open then reaper.defer(loop) end; return
    end

    local file_path = reaper.GetMediaSourceFileName(root, "")
    local source_type = reaper.GetMediaSourceType(root, "")
    if source_type ~= "WAVE" and source_type ~= "WAV" then
      current_item = nil; current_take = nil
      reaper.ImGui_Text(ctx, "WAV only: " .. source_type)
      reaper.ImGui_End(ctx); popTheme()
      reaper.ImGui_PopStyleVar(ctx, 5); reaper.ImGui_PopFont(ctx)
      check_and_save_state()
      if open then reaper.defer(loop) end; return
    end

    if not load_wav_direct(file_path) then
      current_item = nil; current_take = nil
      reaper.ImGui_Text(ctx, "Error loading WAV")
      reaper.ImGui_End(ctx); popTheme()
      reaper.ImGui_PopStyleVar(ctx, 5); reaper.ImGui_PopFont(ctx)
      check_and_save_state()
      if open then reaper.defer(loop) end; return
    end

    local src_len = wav_cache.src_len
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local take_off = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if playrate == 0 then playrate = 1 end

    local section_off = 0
    local temp_src = source
    while true do
      local parent = reaper.GetMediaSourceParent(temp_src)
      if not parent then break end
      local ok, offs = reaper.PCM_Source_GetSectionInfo(temp_src)
      if ok then section_off = section_off + (offs or 0) end
      temp_src = parent
    end

    current_item = item; current_take = take
    current_section_off = section_off
    current_playrate = playrate; current_src_len = src_len

    local is_loop_section = (reaper.GetMediaSourceType(source, "") == "SECTION")
    local start_offset = math_max(0, section_off + take_off)
    local end_offset
    if is_loop_section then
      local sec_len = reaper.GetMediaSourceLength(source) or (item_len * playrate)
      end_offset = math_min(src_len, start_offset + sec_len)
    else
      end_offset = math_min(src_len, start_offset + item_len * playrate)
    end

    -- Stable anchor for tempo-grid mapping & grid snapping (captured BEFORE
    -- the live drag-preview overwrite below, so grid math never feeds back
    -- on itself while dragging).
    local grid_anchor_start = start_offset

    -- LOOP LENGTH quantize function: тримає лівий маркер (start_offset) на
    -- місці, виставляє правий так, щоб довжина лупа точно відповідала
    -- вибраній музичній довжині відносно темпу проекту.
    local function set_loop_length_to_grid(division_id)
      local qn_div = get_fixed_grid_qn(division_id)
      if not qn_div then return false end
      local s_off = grid_anchor_start
      local proj_start = item_pos
      local qn_start = reaper.TimeMap2_timeToQN(0, proj_start)
      local qn_end = qn_start + qn_div
      local proj_end = reaper.TimeMap2_QNToTime(0, qn_end)
      local new_len_source = (proj_end - proj_start) * playrate
      if new_len_source < 0.001 then new_len_source = 0.001 end
      local new_end = s_off + new_len_source
      if new_end > src_len then new_end = src_len end
      local final_len = new_end - s_off
      if final_len < 0.001 then return false end
      local root_src = get_root_source(source)
      local root_fn = reaper.GetMediaSourceFileName(root_src, "")
      local root_type = reaper.GetMediaSourceType(root_src, "")
      if set_take_loop_section(item, take, root_fn, root_type, s_off, final_len) then
        local new_take = reaper.GetActiveTake(item)
        if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
        reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Set loop length to " .. division_id, -1, -1)
        -- LOOP LENGTH always produces a musically-exact loop, regardless of
        -- whether grid-snap happens to be toggled on right now. Always
        -- remember it as the canonical reference for this item so that
        -- turning grid-snap ON later (even after free-dragging) restores
        -- exactly this alignment automatically.
        save_grid_reference(current_guid, s_off, s_off + final_len)
        return true
      end
      return false
    end

    -- Live preview during active drag (smooth visuals before chunk commit)
    if (drag_mode == "start" or drag_mode == "end") and drag_activated and loop_preview_start and loop_preview_end then
      start_offset = loop_preview_start
      end_offset = loop_preview_end
    elseif loopbar_drag and loop_preview_start and loop_preview_end then
      start_offset = loop_preview_start
      end_offset = loop_preview_end
    end

    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local wave_w = math_max(100, avail_w - PADDING * 2)
    local fixed_h = SET_BTN_H + 2 + RULER_H + 2 + SLOT_ZONE_H + LOOPBAR_H
    local wave_h = math_max(60, avail_h - fixed_h)

    local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local abs_wave_x = cur_x + PADDING - WIN_PAD
    local abs_btn_y = cur_y - WIN_PAD
    local abs_ruler_y = abs_btn_y + SET_BTN_H + 2
    local abs_wave_y = abs_ruler_y + RULER_H + 2
    local abs_slot_zone_y = abs_wave_y + wave_h
    local abs_loopbar_y = abs_slot_zone_y + SLOT_ZONE_H

    reaper.ImGui_InvisibleButton(ctx, "##area", avail_w, avail_h)
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    local shift_held = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
    local ctrl_held = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())

    local view_len = src_len / zoom
    local range_center = src_len / 2
    local view_center = range_center + pan_offset
    local view_start = view_center - view_len / 2
    local view_end = view_start + view_len
    if view_start < 0 then view_start = 0; view_end = math_min(src_len, view_len) end
    if view_end > src_len then view_end = src_len; view_start = math_max(0, src_len - view_len) end
    view_len = view_end - view_start
    if view_len <= 0 then view_len = 0.001 end

    local inv_view_len = 1.0 / view_len
    local px_per_time = wave_w * inv_view_len
    local wave_x_end = abs_wave_x + wave_w
    local wave_y_end = abs_wave_y + wave_h

    local function t2px(t) return abs_wave_x + (t - view_start) * px_per_time end
    local function px2t(px) return view_start + (px - abs_wave_x) / px_per_time end

    -- ===== TEMPO GRID (for this frame's view) =====
    local grid_project_start = source_to_project_time(view_start, item_pos, grid_anchor_start, playrate)
    local grid_project_end = source_to_project_time(view_start + view_len, item_pos, grid_anchor_start, playrate)
    local grid_view_start_qn, grid_view_end_qn
    if ruler_grid_cache.grid_project_start == grid_project_start
      and ruler_grid_cache.grid_project_end == grid_project_end
      and ruler_grid_cache.grid_view_start_qn ~= nil
      and ruler_grid_cache.grid_view_end_qn ~= nil then
      grid_view_start_qn = ruler_grid_cache.grid_view_start_qn
      grid_view_end_qn = ruler_grid_cache.grid_view_end_qn
    else
      grid_view_start_qn = reaper.TimeMap2_timeToQN(0, grid_project_start)
      grid_view_end_qn = reaper.TimeMap2_timeToQN(0, grid_project_end)
    end
    local grid_division_qn = get_effective_grid_qn()
    local grid_div = (grid_settings.triplet and (grid_division_qn * 2 / 3)) or grid_division_qn
    local grid_label = get_fixed_grid_label(grid_settings.fixed)
    if grid_settings.triplet then grid_label = grid_label .. "T" end

    -- Grid-snap has priority when enabled; otherwise falls back to zero-cross
    -- snap. The two never fight over the same drag operation.
    local function snap_marker_time(t)
      if snap_enabled then
        if grid_div > 0 then
          local proj_t = source_to_project_time(t, item_pos, grid_anchor_start, playrate)
          local qn = reaper.TimeMap2_timeToQN(0, proj_t)
          local snapped_qn = math_floor(qn / grid_div + 0.5) * grid_div
          local snapped_proj = reaper.TimeMap2_QNToTime(0, snapped_qn)
          return project_to_source_time(snapped_proj, item_pos, grid_anchor_start, playrate)
        end
        return t
      elseif zero_cross_snap then
        return find_zero_crossing(t, ZC_SEARCH_RADIUS)
      end
      return t
    end

    local function snap_region_local(new_start, region_len)
      if snap_enabled then
        return snap_marker_time(new_start)
      end
      return snap_region(new_start, region_len, src_len)
    end

    -- Move the whole loop region by one grid division left/right
    local function nudge_loop(direction)
      if grid_div <= 0 then return end
      local region_len = end_offset - start_offset
      if region_len < 0.001 then region_len = 0.001 end
      local proj_start = source_to_project_time(start_offset, item_pos, grid_anchor_start, playrate)
      local qn = reaper.TimeMap2_timeToQN(0, proj_start)
      local new_proj = reaper.TimeMap2_QNToTime(0, qn + direction * grid_div)
      local new_start = project_to_source_time(new_proj, item_pos, grid_anchor_start, playrate)
      new_start = math_max(0, math_min(src_len - region_len, new_start))
      local new_end = new_start + region_len
      local root_src = get_root_source(source)
      local root_fn = reaper.GetMediaSourceFileName(root_src, "")
      local root_type = reaper.GetMediaSourceType(root_src, "")
      if set_take_loop_section(item, take, root_fn, root_type, new_start, region_len) then
        local new_take = reaper.GetActiveTake(item)
        if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
        reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Nudge loop by grid", -1, -1)
        if snap_enabled then save_grid_reference(current_guid, new_start, new_end) end
        start_offset = new_start
        end_offset = new_end
      end
    end

    -- Scale the loop length by a factor (2x or 0.5x), keeping the start marker fixed
    local function scale_loop_length(factor)
      local cur_len = end_offset - start_offset
      if cur_len < 0.001 then return end
      local new_len = cur_len * factor
      if new_len < 0.001 then new_len = 0.001 end
      local max_len = src_len - start_offset
      if new_len > max_len then new_len = max_len end
      local new_end = start_offset + new_len
      local root_src = get_root_source(source)
      local root_fn = reaper.GetMediaSourceFileName(root_src, "")
      local root_type = reaper.GetMediaSourceType(root_src, "")
      if set_take_loop_section(item, take, root_fn, root_type, start_offset, new_len) then
        local new_take = reaper.GetActiveTake(item)
        if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
        reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Scale loop length", -1, -1)
        end_offset = new_end
      end
    end

    local function do_edge_scroll(check_px, direction)
      local scroll_delta = 0
      local scroll_speed = view_len * AUTO_SCROLL_SPEED
      if shift_held then scroll_speed = scroll_speed / FINE_MODE_DIVISOR end
      if direction == "left" or direction == "auto" then
        if check_px <= abs_wave_x + AUTO_SCROLL_ZONE then
          local intensity = 1 - ((check_px - abs_wave_x) / AUTO_SCROLL_ZONE)
          if intensity < 0 then intensity = 0 end
          if intensity > 2 then intensity = 2 end
          if check_px <= abs_wave_x then intensity = math_max(intensity, 1) end
          scroll_delta = -scroll_speed * intensity
        end
      end
      if direction == "right" or direction == "auto" then
        if check_px >= wave_x_end - AUTO_SCROLL_ZONE then
          local intensity = 1 - ((wave_x_end - check_px) / AUTO_SCROLL_ZONE)
          if intensity < 0 then intensity = 0 end
          if intensity > 2 then intensity = 2 end
          if check_px >= wave_x_end then intensity = math_max(intensity, 1) end
          scroll_delta = scroll_speed * intensity
        end
      end
      if scroll_delta ~= 0 then
        pan_offset = pan_offset + scroll_delta
        local half = view_len / 2
        pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
      end
    end

    local dl = reaper.ImGui_GetWindowDrawList(ctx)
    local slots = get_slots(current_guid)

    -- ===== TOP BAR: SET =====
    local mouse_in_btn
    do
      local has_sel = has_valid_selection()
      local btn_color = has_sel and COLOR.SET_BTN or 0x666666FF
      local btn_bg = has_sel and COLOR.SET_BTN_BG or 0x333333FF
      DL_AddRectFilled(dl, abs_wave_x, abs_btn_y, abs_wave_x + SET_BTN_W, abs_btn_y + SET_BTN_H, btn_bg, 3)
      DL_AddRect(dl, abs_wave_x, abs_btn_y, abs_wave_x + SET_BTN_W, abs_btn_y + SET_BTN_H, btn_color, 3, 0, 1)
      local tw_set = reaper.ImGui_CalcTextSize(ctx, "SET")
      DL_AddText(dl, abs_wave_x + (SET_BTN_W - tw_set) / 2, abs_btn_y + 2, COLOR.BTN_TEXT, "SET")
      mouse_in_btn = mx >= abs_wave_x and mx <= abs_wave_x + SET_BTN_W and my >= abs_btn_y and my <= abs_btn_y + SET_BTN_H
      if mouse_in_btn and reaper.ImGui_IsMouseClicked(ctx, 0) and has_sel then apply_selection() end
    end

    -- ===== SLOTS =====
    local slot_start_x = abs_wave_x + SET_BTN_W + SLOT_GAP * 2
    local slot_hovered_idx = nil
    local mouse_in_any_slot = false

    for i = 1, #slots do
      local sx = slot_start_x + (i - 1) * (SLOT_W + SLOT_GAP)
      local sy = abs_btn_y
      local sx2 = sx + SLOT_W
      local sy2 = sy + SET_BTN_H
      local mouse_in_slot = mx >= sx and mx <= sx2 and my >= sy and my <= sy2
      if mouse_in_slot then slot_hovered_idx = i; mouse_in_any_slot = true end
      local slot_bg = mouse_in_slot and COLOR.SLOT_HOVERED_BG or COLOR.SLOT_FILLED_BG
      local slot_fg = mouse_in_slot and COLOR.SLOT_ACTIVE or COLOR.SLOT_FILLED
      DL_AddRectFilled(dl, sx, sy, sx2, sy2, slot_bg, 3)
      DL_AddRect(dl, sx, sy, sx2, sy2, slot_fg, 3, 0, 1)
      local label = (i == 10) and "0" or tostring(i)
      local tw_slot = reaper.ImGui_CalcTextSize(ctx, label)
      DL_AddText(dl, sx + (SLOT_W - tw_slot) / 2, sy + 2, COLOR.BTN_TEXT, label)
      if mouse_in_slot and reaper.ImGui_IsMouseClicked(ctx, 0) then apply_slot(current_guid, i) end
      if mouse_in_slot and reaper.ImGui_IsMouseClicked(ctx, 1) then remove_slot(current_guid, i) end
    end

    -- ===== ADD =====
    local mouse_in_add, can_add, add_x
    do
      can_add = #slots < MAX_SLOTS
      add_x = slot_start_x + #slots * (SLOT_W + SLOT_GAP)
      mouse_in_add = mx >= add_x and mx <= add_x + ADD_BTN_W and my >= abs_btn_y and my <= abs_btn_y + SET_BTN_H
      local add_color = can_add and (mouse_in_add and COLOR.HOVER_FG or COLOR.SLOT_ADD) or 0x444444FF
      local add_bg_color = can_add and (mouse_in_add and COLOR.HOVER_BG or COLOR.SLOT_ADD_BG) or 0x222222FF
      DL_AddRectFilled(dl, add_x, abs_btn_y, add_x + ADD_BTN_W, abs_btn_y + SET_BTN_H, add_bg_color, 3)
      DL_AddRect(dl, add_x, abs_btn_y, add_x + ADD_BTN_W, abs_btn_y + SET_BTN_H, add_color, 3, 0, 1)
      local tw_plus = reaper.ImGui_CalcTextSize(ctx, "+")
      DL_AddText(dl, add_x + (ADD_BTN_W - tw_plus) / 2, abs_btn_y + 2, COLOR.BTN_TEXT, "+")
      if mouse_in_add and reaper.ImGui_IsMouseClicked(ctx, 0) and can_add then
        add_slot(current_guid, start_offset, end_offset)
      end
    end

    -- ===== SETTINGS =====
    local settings_x = wave_x_end - SETTINGS_BTN_W
    local mouse_in_settings
    do
      local sy, sx2, sy2 = abs_btn_y, wave_x_end, abs_btn_y + SET_BTN_H
      mouse_in_settings = mx >= settings_x and mx <= sx2 and my >= sy and my <= sy2
      local fg = mouse_in_settings and 0xCCCCCCFF or 0x999999FF
      local bg = mouse_in_settings and 0x3A3A3AFF or 0x2A2A2AFF
      DL_AddRectFilled(dl, settings_x, sy, sx2, sy2, bg, 3)
      DL_AddRect(dl, settings_x, sy, sx2, sy2, fg, 3, 0, 1)
      local gear_icon = "\xE2\x9A\x99"
      local tw = reaper.ImGui_CalcTextSize(ctx, gear_icon)
      DL_AddText(dl, settings_x + (SETTINGS_BTN_W - tw) / 2, sy + 2, fg, gear_icon)
      if mouse_in_settings and reaper.ImGui_IsMouseClicked(ctx, 0) then
        reaper.ImGui_OpenPopup(ctx, "settings_popup")
        settings_popup_x = settings_x
        settings_popup_y = sy2 + 2
      end
    end

    -- ===== LOCK =====
    local lock_x = settings_x - SLOT_GAP - LOCK_BTN_W
    local mouse_in_lock
    do
      local ly, lx2, ly2 = abs_btn_y, lock_x + LOCK_BTN_W, abs_btn_y + SET_BTN_H
      mouse_in_lock = mx >= lock_x and mx <= lx2 and my >= ly and my <= ly2
      local fg, bg
      if window_locked then
        fg = mouse_in_lock and COLOR.HOVER_FG or COLOR.LOCK_ON
        bg = mouse_in_lock and COLOR.HOVER_BG or COLOR.LOCK_ON_BG
      else
        fg = mouse_in_lock and 0x888888FF or COLOR.LOCK_OFF
        bg = mouse_in_lock and 0x3A3A3AFF or COLOR.LOCK_OFF_BG
      end
      DL_AddRectFilled(dl, lock_x, ly, lx2, ly2, bg, 3)
      DL_AddRect(dl, lock_x, ly, lx2, ly2, fg, 3, 0, 1)
      local cx, cy = lock_x + LOCK_BTN_W / 2, ly + SET_BTN_H / 2
      if window_locked then
        DL_AddRectFilled(dl, cx - 4, cy - 1, cx + 4, cy + 5, fg, 1)
        DL_AddLine(dl, cx - 3, cy - 1, cx - 3, cy - 4, fg, 2)
        DL_AddLine(dl, cx - 3, cy - 4, cx + 3, cy - 4, fg, 2)
        DL_AddLine(dl, cx + 3, cy - 4, cx + 3, cy - 1, fg, 2)
      else
        DL_AddRect(dl, cx - 4, cy - 1, cx + 4, cy + 5, fg, 1, 0, 1)
        DL_AddLine(dl, cx - 3, cy - 1, cx - 3, cy - 4, fg, 2)
        DL_AddLine(dl, cx - 3, cy - 4, cx + 1, cy - 4, fg, 2)
        DL_AddLine(dl, cx + 3, cy - 1, cx + 3, cy - 3, fg, 2)
      end
      if mouse_in_lock and reaper.ImGui_IsMouseClicked(ctx, 0) then
        window_locked = not window_locked
        if window_locked then
          locked_pos_x, locked_pos_y = reaper.ImGui_GetWindowPos(ctx)
          locked_size_w, locked_size_h = reaper.ImGui_GetWindowSize(ctx)
        end
      end
    end

    -- ===== ZC =====
    local zc_x = lock_x - SLOT_GAP - ZC_BTN_W
    local mouse_in_zc
    do
      local zy, zx2, zy2 = abs_btn_y, zc_x + ZC_BTN_W, abs_btn_y + SET_BTN_H
      mouse_in_zc = mx >= zc_x and mx <= zx2 and my >= zy and my <= zy2
      local fg, bg
      if zero_cross_snap then
        fg = mouse_in_zc and COLOR.HOVER_FG or COLOR.ZC_ON
        bg = mouse_in_zc and COLOR.HOVER_BG or COLOR.ZC_ON_BG
      else
        fg = mouse_in_zc and 0x888888FF or COLOR.ZC_OFF
        bg = mouse_in_zc and 0x3A3A3AFF or COLOR.ZC_OFF_BG
      end
      DL_AddRectFilled(dl, zc_x, zy, zx2, zy2, bg, 3)
      DL_AddRect(dl, zc_x, zy, zx2, zy2, fg, 3, 0, 1)
      local tw_zc = reaper.ImGui_CalcTextSize(ctx, "ZC")
      local zc_text = zero_cross_snap and COLOR.BTN_TEXT or 0xA0A0A0FF
      DL_AddText(dl, zc_x + (ZC_BTN_W - tw_zc) / 2, zy + 2, zc_text, "ZC")
      if mouse_in_zc and reaper.ImGui_IsMouseClicked(ctx, 0) then zero_cross_snap = not zero_cross_snap end
    end

    -- ===== TS =====
    local ts_x = zc_x - SLOT_GAP - TS_BTN_W
    local mouse_in_ts
    do
      local ty, tx2, ty2 = abs_btn_y, ts_x + TS_BTN_W, abs_btn_y + SET_BTN_H
      mouse_in_ts = mx >= ts_x and mx <= tx2 and my >= ty and my <= ty2
      local fg = mouse_in_ts and COLOR.HOVER_FG or COLOR.TS_BTN
      local bg = mouse_in_ts and COLOR.HOVER_BG or COLOR.TS_BTN_BG
      DL_AddRectFilled(dl, ts_x, ty, tx2, ty2, bg, 3)
      DL_AddRect(dl, ts_x, ty, tx2, ty2, fg, 3, 0, 1)
      local ccy = ty + SET_BTN_H / 2
      DL_AddLine(dl, ts_x + 5, ccy - 4, ts_x + 5, ccy + 4, fg, 1.5)
      DL_AddLine(dl, ts_x + 5, ccy - 4, ts_x + 8, ccy - 4, fg, 1.5)
      DL_AddLine(dl, ts_x + 5, ccy + 4, ts_x + 8, ccy + 4, fg, 1.5)
      DL_AddLine(dl, tx2 - 5, ccy - 4, tx2 - 5, ccy + 4, fg, 1.5)
      DL_AddLine(dl, tx2 - 5, ccy - 4, tx2 - 8, ccy - 4, fg, 1.5)
      DL_AddLine(dl, tx2 - 5, ccy + 4, tx2 - 8, ccy + 4, fg, 1.5)
      if mouse_in_ts and reaper.ImGui_IsMouseClicked(ctx, 0) then set_time_selection_to_item() end
    end

    -- ===== GRID =====
    local grid_btn_x
    local mouse_in_grid_btn
    do
      local grid_arrow = " \xE2\x96\xBC"
      local grid_btn_text = grid_label .. grid_arrow
      local grid_btn_w = reaper.ImGui_CalcTextSize(ctx, grid_btn_text) + 14
      grid_btn_x = ts_x - SLOT_GAP - grid_btn_w
      local gy, gx2, gy2 = abs_btn_y, grid_btn_x + grid_btn_w, abs_btn_y + SET_BTN_H
      mouse_in_grid_btn = mx >= grid_btn_x and mx <= gx2 and my >= gy and my <= gy2
      local fg = mouse_in_grid_btn and COLOR.HOVER_FG or COLOR.TS_BTN
      local bg = mouse_in_grid_btn and COLOR.HOVER_BG or COLOR.TS_BTN_BG
      DL_AddRectFilled(dl, grid_btn_x, gy, gx2, gy2, bg, 3)
      DL_AddRect(dl, grid_btn_x, gy, gx2, gy2, fg, 3, 0, 1)
      local tw = reaper.ImGui_CalcTextSize(ctx, grid_btn_text)
      DL_AddText(dl, grid_btn_x + (grid_btn_w - tw) / 2, gy + 2, COLOR.BTN_TEXT, grid_btn_text)
      if mouse_in_grid_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
        reaper.ImGui_OpenPopup(ctx, "grid_dropdown_menu")
        grid_popup_x = grid_btn_x
        grid_popup_y = gy2 + 2
      end
    end

    -- ===== SNAP =====
    local mouse_in_snap
    do
      local snap_x = grid_btn_x - SLOT_GAP - SNAP_BTN_W
      local sy, sx2, sy2 = abs_btn_y, snap_x + SNAP_BTN_W, abs_btn_y + SET_BTN_H
      mouse_in_snap = mx >= snap_x and mx <= sx2 and my >= sy and my <= sy2
      local fg, bg
      if snap_enabled then
        fg = mouse_in_snap and COLOR.HOVER_FG or COLOR.SNAP_ON
        bg = mouse_in_snap and COLOR.HOVER_BG or COLOR.SNAP_ON_BG
      else
        fg = mouse_in_snap and 0x888888FF or COLOR.SNAP_OFF
        bg = mouse_in_snap and 0x3A3A3AFF or COLOR.SNAP_OFF_BG
      end
      DL_AddRectFilled(dl, snap_x, sy, sx2, sy2, bg, 3)
      DL_AddRect(dl, snap_x, sy, sx2, sy2, fg, 3, 0, 1)
      local tw = reaper.ImGui_CalcTextSize(ctx, "Snap")
      local snap_text = snap_enabled and COLOR.BTN_TEXT or 0xA0A0A0FF
      DL_AddText(dl, snap_x + (SNAP_BTN_W - tw) / 2, sy + 2, snap_text, "Snap")
      if mouse_in_snap and reaper.ImGui_IsMouseClicked(ctx, 0) then
        local turning_on = not snap_enabled
        snap_enabled = not snap_enabled
        save_snap_state()
        if turning_on then
          -- ===== AUTOMATIC GRID-REFERENCE RESTORE =====
          local ref = get_grid_reference(current_guid)
          if ref and current_item and current_take then
            local rs = math_max(0, math_min(current_src_len, ref.s))
            local re = math_max(0, math_min(current_src_len, ref.e))
            if re > rs then
              local root_src = get_root_source(source)
              local root_fn = reaper.GetMediaSourceFileName(root_src, "")
              local root_type = reaper.GetMediaSourceType(root_src, "")
              if set_take_loop_section(current_item, current_take, root_fn, root_type, rs, re - rs) then
                local new_take = reaper.GetActiveTake(current_item)
                if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
                reaper.SetMediaItemInfo_Value(current_item, "B_LOOPSRC", 1)
                reaper.UpdateArrange()
                reaper.Undo_OnStateChangeEx("Restore grid-aligned loop reference", -1, -1)
              end
            end
          end
        end
      end
    end

    -- ===== LOOP LENGTH + x2 /2 =====
    local mouse_in_loop_len_btn, mouse_in_scale2, mouse_in_scale_half
    do
      local loop_len_text = "LOOP LENGTH \xE2\x96\xBC"
      local loop_w = reaper.ImGui_CalcTextSize(ctx, loop_len_text) + 14
      local scale2_text = "\xC3\x972"
      local scale_half_text = "/2"
      local scale2_w = reaper.ImGui_CalcTextSize(ctx, scale2_text) + 14
      local scale_half_w = reaper.ImGui_CalcTextSize(ctx, scale_half_text) + 14
      local scale_gap = 4
      local total_w = scale2_w + scale_half_w + loop_w + scale_gap * 2
      local group_x = abs_wave_x + (wave_w - total_w) / 2
      local y = abs_btn_y
      local y2 = abs_btn_y + SET_BTN_H

      local x = group_x
      local scale2_x = group_x + loop_w + scale_gap
      local scale_half_x = group_x + loop_w + scale2_w + scale_gap * 2

      -- x2 button
      mouse_in_scale2 = mx >= scale2_x and mx <= scale2_x + scale2_w and my >= y and my <= y2
      local s2fg = mouse_in_scale2 and COLOR.HOVER_FG or COLOR.LOOPLEN_BTN
      local s2bg = mouse_in_scale2 and COLOR.HOVER_BG or COLOR.LOOPLEN_BTN_BG
      DL_AddRectFilled(dl, scale2_x, y, scale2_x + scale2_w, y2, s2bg, 3)
      DL_AddRect(dl, scale2_x, y, scale2_x + scale2_w, y2, s2fg, 3, 0, 1)
      local tw2 = reaper.ImGui_CalcTextSize(ctx, scale2_text)
      DL_AddText(dl, scale2_x + (scale2_w - tw2) / 2, y + 2, COLOR.BTN_TEXT, scale2_text)

      -- /2 button
      mouse_in_scale_half = mx >= scale_half_x and mx <= scale_half_x + scale_half_w and my >= y and my <= y2
      local shfg = mouse_in_scale_half and COLOR.HOVER_FG or COLOR.LOOPLEN_BTN
      local shbg = mouse_in_scale_half and COLOR.HOVER_BG or COLOR.LOOPLEN_BTN_BG
      DL_AddRectFilled(dl, scale_half_x, y, scale_half_x + scale_half_w, y2, shbg, 3)
      DL_AddRect(dl, scale_half_x, y, scale_half_x + scale_half_w, y2, shfg, 3, 0, 1)
      local twh = reaper.ImGui_CalcTextSize(ctx, scale_half_text)
      DL_AddText(dl, scale_half_x + (scale_half_w - twh) / 2, y + 2, COLOR.BTN_TEXT, scale_half_text)

      -- LOOP LENGTH button
      mouse_in_loop_len_btn = mx >= x and mx <= x + loop_w and my >= y and my <= y2
      local fg = mouse_in_loop_len_btn and COLOR.HOVER_FG or COLOR.LOOPLEN_BTN
      local bg = mouse_in_loop_len_btn and COLOR.HOVER_BG or COLOR.LOOPLEN_BTN_BG
      DL_AddRectFilled(dl, x, y, x + loop_w, y2, bg, 3)
      DL_AddRect(dl, x, y, x + loop_w, y2, fg, 3, 0, 1)
      local tw = reaper.ImGui_CalcTextSize(ctx, loop_len_text)
      DL_AddText(dl, x + (loop_w - tw) / 2, y + 2, COLOR.BTN_TEXT, loop_len_text)

      if mouse_in_scale2 and reaper.ImGui_IsMouseClicked(ctx, 0) then scale_loop_length(2) end
      if mouse_in_scale_half and reaper.ImGui_IsMouseClicked(ctx, 0) then scale_loop_length(0.5) end
      if mouse_in_loop_len_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
        reaper.ImGui_OpenPopup(ctx, "loop_length_dropdown_menu")
        loop_len_popup_x = x
        loop_len_popup_y = y2 + 2
      end
    end

    if is_focused then
      for i = 1, 10 do
        if reaper.ImGui_IsKeyPressed(ctx, slot_keys[i], false) and not ctrl_held then
          if i <= #slots then apply_slot(current_guid, i) end
        end
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), false) then
        nudge_loop(-1)
      end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), false) then
        nudge_loop(1)
      end
    end

    -- ===== GRID DROPDOWN MENU (Fixed Grid only) =====
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 6)
    if grid_popup_x then
      reaper.ImGui_SetNextWindowPos(ctx, grid_popup_x, grid_popup_y)
      grid_popup_x = nil
    end
    if reaper.ImGui_BeginPopup(ctx, "grid_dropdown_menu") then
      local CHECK = "\xE2\x9C\x93 "
      local NOCHECK = "   "
      local DIM_COL = 0x888888FF
      local SEL_COL = COLOR.SET_BTN

      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), DIM_COL)
      reaper.ImGui_Text(ctx, NOCHECK .. "Grid:")
      reaper.ImGui_PopStyleColor(ctx)

      local fixed_opts = GRID_FIXED_OPTIONS
      local fixed_rows = {
        {fixed_opts[1], fixed_opts[2], fixed_opts[3]},
        {fixed_opts[4], fixed_opts[5], fixed_opts[6]},
      }
      for _, row in ipairs(fixed_rows) do
        for ri, opt in ipairs(row) do
          if ri > 1 then reaper.ImGui_SameLine(ctx) end
          local is_sel = grid_settings.fixed == opt.id
          local lbl = opt.label
          if grid_settings.triplet then lbl = lbl .. "T" end
          local prefix = is_sel and CHECK or NOCHECK
          local tc = is_sel and SEL_COL or theme.Text
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), tc)
          if reaper.ImGui_Selectable(ctx, prefix .. lbl .. "##f_" .. opt.id, false,
              reaper.ImGui_SelectableFlags_None(), 55, 0) then
            grid_settings.fixed = opt.id
            save_grid_setting("fixed")
          end
          reaper.ImGui_PopStyleColor(ctx)
        end
      end

      reaper.ImGui_EndPopup(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx)

    -- ===== LOOP LENGTH DROPDOWN MENU =====
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 6)
    if loop_len_popup_x then
      reaper.ImGui_SetNextWindowPos(ctx, loop_len_popup_x, loop_len_popup_y)
      loop_len_popup_x = nil
    end
    if reaper.ImGui_BeginPopup(ctx, "loop_length_dropdown_menu") then
      local DIM_COL = 0x888888FF
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), DIM_COL)
      reaper.ImGui_Text(ctx, "   Loop Length:")
      reaper.ImGui_PopStyleColor(ctx)

      local fixed_opts = GRID_FIXED_OPTIONS
      local fixed_rows = {
        {fixed_opts[1], fixed_opts[2], fixed_opts[3]},
        {fixed_opts[4], fixed_opts[5], fixed_opts[6]},
      }
      for _, row in ipairs(fixed_rows) do
        for ri, opt in ipairs(row) do
          if ri > 1 then reaper.ImGui_SameLine(ctx) end
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.Text)
          if reaper.ImGui_Selectable(ctx, "   " .. opt.label .. "##ll_" .. opt.id, false,
              reaper.ImGui_SelectableFlags_None(), 55, 0) then
            set_loop_length_to_grid(opt.id)
          end
          reaper.ImGui_PopStyleColor(ctx)
        end
      end

      reaper.ImGui_EndPopup(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx)

    -- ===== SETTINGS DROPDOWN MENU =====
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 10, 8)
    if settings_popup_x then
      reaper.ImGui_SetNextWindowPos(ctx, settings_popup_x, settings_popup_y)
      settings_popup_x = nil
    end
    if reaper.ImGui_BeginPopup(ctx, "settings_popup") then
      if reaper.ImGui_MenuItem(ctx, "Appearance (Colors & Themes)...") then
        settings_ui.open(settings)
      end
      if reaper.ImGui_BeginMenu(ctx, "Waveform Channels") then
        for _, option in ipairs(WAVEFORM_MODE_OPTIONS) do
          local selected = waveform_mode == option.id
          if reaper.ImGui_MenuItem(ctx, option.label, nil, selected) then
            if waveform_mode ~= option.id then
              waveform_mode = option.id
              view_cache.data = nil
              view_cache.file_path = nil
              view_cache.mode = nil
              save_persistent_state()
            end
          end
        end
        reaper.ImGui_EndMenu(ctx)
      end
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_TextColored(ctx, theme.ActivePreset or 0x00AAFFFF, "\xE2\x9C\xA6 Made by Andrew Dihtaryk")
      if reaper.ImGui_MenuItem(ctx, "\xE2\x9C\xA6 Support Ko-Fi") then
        reaper.CF_ShellExecute("https://ko-fi.com/pianohousestudio/shop")
      end
      reaper.ImGui_EndPopup(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx)

    -- ===== RULER + SCROLLBAR (bars / beats) =====
    DL_AddRectFilled(dl, abs_wave_x, abs_ruler_y, wave_x_end, abs_ruler_y + RULER_H, COLOR.SCROLLBAR_BG)
    DL_AddRect(dl, abs_wave_x, abs_ruler_y, wave_x_end, abs_ruler_y + RULER_H, 0x333333FF, 0, 0, 1)

    local mouse_in_ruler, mouse_in_thumb
    local wave_labels
    local grid_lines

    do
      local thumb_frac_start = view_start / src_len
      local thumb_frac_end = view_end / src_len
      local thumb_x1 = abs_wave_x + thumb_frac_start * wave_w
      local thumb_x2 = abs_wave_x + thumb_frac_end * wave_w
      local thumb_min_w = 20
      if thumb_x2 - thumb_x1 < thumb_min_w then
        local center = (thumb_x1 + thumb_x2) / 2
        thumb_x1 = center - thumb_min_w / 2
        thumb_x2 = center + thumb_min_w / 2
      end

      mouse_in_ruler = mx >= abs_wave_x and mx <= wave_x_end and my >= abs_ruler_y and my <= abs_ruler_y + RULER_H
      mouse_in_thumb = mx >= thumb_x1 and mx <= thumb_x2 and my >= abs_ruler_y and my <= abs_ruler_y + RULER_H

      local thumb_color = COLOR.SCROLLBAR_THUMB
      if ruler_scroll_drag then thumb_color = COLOR.SCROLLBAR_THUMB_ACT
      elseif mouse_in_thumb then thumb_color = COLOR.SCROLLBAR_THUMB_HOV end

      DL_AddRectFilled(dl, abs_wave_x, abs_ruler_y + 2, wave_x_end, abs_ruler_y + RULER_H - 2, COLOR.SCROLLBAR_TRACK, 3)
      DL_AddRectFilled(dl, thumb_x1, abs_ruler_y + 1, thumb_x2, abs_ruler_y + RULER_H - 1, thumb_color, 4)

      local cache = ruler_grid_cache
      local cache_hit = cache.view_start == view_start
        and cache.view_len == view_len
        and cache.wave_x == abs_wave_x
        and cache.wave_w == wave_w
        and cache.wave_y == abs_wave_y
        and cache.wave_y_end == wave_y_end
        and cache.ruler_y == abs_ruler_y
        and cache.src_len == src_len
        and cache.item_pos == item_pos
        and cache.grid_anchor_start == grid_anchor_start
        and cache.playrate == playrate
        and cache.grid_project_start == grid_project_start
        and cache.grid_project_end == grid_project_end
        and cache.grid_div == grid_div
        and cache.ruler_tick_color == COLOR.RULER_TICK
        and cache.ruler_text_color == COLOR.RULER_TEXT
        and cache.grid_line_color == COLOR.GRID_LINE

      local ruler_ticks
      if cache_hit then
        wave_labels = cache.labels
        ruler_ticks = cache.ruler_ticks
        grid_lines = cache.grid_lines
      else
        wave_labels = {}
        ruler_ticks = {}
        grid_lines = {}

        local function add_ruler_tick(x1, y1, x2, y2, color, width)
          ruler_ticks[#ruler_ticks + 1] = {x1, y1, x2, y2, color, width}
        end

        local rbpm, rbpi = reaper.GetProjectTimeSignature2(0, grid_project_start)
        if not rbpm or rbpm <= 0 then rbpm = 120 end
        if not rbpi then rbpi = 4 end
        local beats_per_bar = math_floor(rbpi)
        if beats_per_bar < 1 then beats_per_bar = 4 end
        local _, start_measures = reaper.TimeMap2_timeToBeats(0, grid_project_start)
        local first_bar = math_floor(start_measures) - 1

        local min_spacing = 42
        local avg_bar_duration = 60 / rbpm * beats_per_bar
        local px_per_bar = (avg_bar_duration / view_len) * wave_w
        local bar_skip = math_max(1, math_ceil(min_spacing / px_per_bar))
        if bar_skip > 1 then
          local power = math_ceil(math_log(bar_skip) / math_log(2))
          bar_skip = 2 ^ power
        end
        local px_per_beat = px_per_bar / beats_per_bar
        local finest_sub = 1
        while (px_per_beat / (finest_sub * 2)) >= min_spacing do
          finest_sub = finest_sub * 2
        end
        local quarter_step = finest_sub >= 4 and (finest_sub / 4) or nil

        local show_beat_ticks = px_per_beat >= 42
        local show_beat_labels = px_per_beat >= 70
        local show_sub_ticks = quarter_step and (px_per_beat / 4) >= 40
        local show_sub_labels = quarter_step and (px_per_beat / 4) >= 90

        local label_skip = bar_skip
        local px_per_label = px_per_bar * label_skip
        while px_per_label < 80 do
          label_skip = label_skip * 2
          px_per_label = px_per_bar * label_skip
        end
        local tick_skip = (label_skip >= 2) and (label_skip / 2) or label_skip
        local inter_px = px_per_bar * tick_skip
        local show_inter_ticks = inter_px >= 20
        local show_inter_labels = inter_px >= 50

        local ruler_bar = first_bar - (first_bar % tick_skip)
        local ruler_iter = 0
        while ruler_iter < 1000 do
          ruler_iter = ruler_iter + 1
          local bar_project_time = reaper.TimeMap2_beatsToTime(0, 0, ruler_bar)
          if bar_project_time > grid_project_end then break end
          local bar_source_time = project_to_source_time(bar_project_time, item_pos, grid_anchor_start, playrate)
          if bar_source_time >= view_start and bar_source_time <= view_end then
            local bar_px = t2px(bar_source_time)
            local is_label_bar = (ruler_bar % label_skip == 0)
            if is_label_bar then
              add_ruler_tick(bar_px, abs_ruler_y, bar_px, abs_ruler_y + RULER_H, COLOR.RULER_TICK, 1)
              wave_labels[#wave_labels + 1] = {px = bar_px, text = tostring(ruler_bar + 1), color = COLOR.RULER_TEXT}
            elseif show_inter_ticks then
              add_ruler_tick(bar_px, abs_ruler_y, bar_px, abs_ruler_y + RULER_H, COLOR.RULER_TICK, 1)
              if show_inter_labels then
                wave_labels[#wave_labels + 1] = {px = bar_px, text = tostring(ruler_bar + 1), color = 0x999999FF}
              end
            end
          end

          if show_beat_ticks then
            for beat = 1, beats_per_bar - 1 do
              local beat_project_time = reaper.TimeMap2_beatsToTime(0, beat, ruler_bar)
              if beat_project_time > grid_project_end then break end
              local beat_source_time = project_to_source_time(beat_project_time, item_pos, grid_anchor_start, playrate)
              if beat_source_time >= view_start and beat_source_time <= view_end then
                local beat_px = t2px(beat_source_time)
                local tick_top = abs_ruler_y + RULER_H - math_floor(RULER_H * 0.5)
                add_ruler_tick(beat_px, tick_top, beat_px, abs_ruler_y + RULER_H, COLOR.RULER_TICK, 1)
                if show_beat_labels then
                  wave_labels[#wave_labels + 1] = {px = beat_px, text = (ruler_bar + 1) .. "." .. (beat + 1), color = 0xAAAAAAFF}
                end
              end
            end
          end

          if quarter_step and (show_sub_ticks or show_sub_labels) then
            for beat = 0, beats_per_bar - 1 do
              for q = 1, 3 do
                local beat_frac = beat + (q / 4)
                local sub_project_time = reaper.TimeMap2_beatsToTime(0, beat_frac, ruler_bar)
                if sub_project_time > grid_project_end then break end
                local sub_source_time = project_to_source_time(sub_project_time, item_pos, grid_anchor_start, playrate)
                if sub_source_time >= view_start and sub_source_time <= view_end then
                  local sub_px = t2px(sub_source_time)
                  if show_sub_ticks then
                    local tick_h = math_floor(RULER_H * 0.3)
                    add_ruler_tick(sub_px, abs_ruler_y + RULER_H - tick_h, sub_px, abs_ruler_y + RULER_H, 0x444444FF, 1)
                  end
                  if show_sub_labels then
                    wave_labels[#wave_labels + 1] = {px = sub_px, text = (ruler_bar + 1) .. "." .. (beat + 1) .. "." .. (q + 1), color = 0x888888FF}
                  end
                end
              end
            end
          end

          ruler_bar = ruler_bar + tick_skip
        end

        local grid_view_length_qn = grid_view_end_qn - grid_view_start_qn
        if grid_view_length_qn > 0 and grid_div > 0 then
          local px_per_qn = wave_w / grid_view_length_qn
          local spacing_px = grid_div * px_per_qn
          if spacing_px >= 1 then
            local first_qn = math_ceil(grid_view_start_qn / grid_div) * grid_div
            if first_qn - grid_div >= grid_view_start_qn then first_qn = first_qn - grid_div end
            for qn = first_qn, grid_view_end_qn, grid_div do
              local proj_t = reaper.TimeMap2_QNToTime(0, qn)
              local src_t = project_to_source_time(proj_t, item_pos, grid_anchor_start, playrate)
              local px = t2px(src_t)
              if px >= abs_wave_x and px <= wave_x_end then
                grid_lines[#grid_lines + 1] = px
              end
            end
          end
        end

        ruler_grid_cache = {
          view_start = view_start, view_len = view_len,
          wave_x = abs_wave_x, wave_w = wave_w,
          wave_y = abs_wave_y, wave_y_end = wave_y_end,
          ruler_y = abs_ruler_y, src_len = src_len,
          item_pos = item_pos, grid_anchor_start = grid_anchor_start,
          playrate = playrate,
          grid_project_start = grid_project_start,
          grid_project_end = grid_project_end, grid_div = grid_div,
          grid_view_start_qn = grid_view_start_qn,
          grid_view_end_qn = grid_view_end_qn,
          ruler_tick_color = COLOR.RULER_TICK,
          ruler_text_color = COLOR.RULER_TEXT,
          grid_line_color = COLOR.GRID_LINE,
          labels = wave_labels, ruler_ticks = ruler_ticks,
          grid_lines = grid_lines,
        }
      end

      for i = 1, #ruler_ticks do
        local tick = ruler_ticks[i]
        DL_AddLine(dl, tick[1], tick[2], tick[3], tick[4], tick[5], tick[6])
      end

    end

    if reaper.ImGui_IsMouseClicked(ctx, 0) and mouse_in_ruler then
      if mouse_in_thumb then
        ruler_scroll_drag = true
        ruler_scroll_start_mx = mx
        ruler_scroll_start_off = pan_offset
      else
        local click_frac = (mx - abs_wave_x) / wave_w
        local new_center = click_frac * src_len
        pan_offset = new_center - range_center
        local half = view_len / 2
        pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
        ruler_scroll_drag = true
        ruler_scroll_start_mx = mx
        ruler_scroll_start_off = pan_offset
      end
    end
    if ruler_scroll_drag then
      if reaper.ImGui_IsMouseDown(ctx, 0) then
        local delta_px = mx - ruler_scroll_start_mx
        if shift_held then delta_px = delta_px / FINE_MODE_DIVISOR end
        local delta_t = (delta_px / wave_w) * src_len
        pan_offset = ruler_scroll_start_off + delta_t
        local half = view_len / 2
        pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
      else ruler_scroll_drag = false end
    end

    -- ===== WAVEFORM AREA =====
    DL_AddRectFilled(dl, abs_wave_x, abs_wave_y, wave_x_end, wave_y_end, COLOR.BG)

    -- Draw cached tempo-grid lines after the waveform background so they
    -- remain visible instead of being covered by the background rectangle.
    for i = 1, #grid_lines do
      local px = grid_lines[i]
      DL_AddLine(dl, px, abs_wave_y, px, wave_y_end, COLOR.GRID_LINE, 1)
    end

    -- Bar/beat labels at top of waveform
    for _, lbl in ipairs(wave_labels) do
      DL_AddText(dl, lbl.px + 2, abs_wave_y + 2, lbl.color, lbl.text)
    end

    local num_points = math_min(math_floor(wave_w), 2000)
    local wave_data = get_view_data(view_start, view_len, num_points)
    if wave_data then
      draw_waveform(dl, wave_data, abs_wave_x, abs_wave_y, wave_w, wave_h, v_zoom)
    end

    local sm_px = t2px(start_offset)
    local em_px = t2px(end_offset)

    do
      local r_left = math_max(abs_wave_x, sm_px)
      local r_right = math_min(wave_x_end, em_px)
      if r_right > r_left then
        DL_AddRectFilled(dl, r_left, abs_wave_y, r_right, wave_y_end, COLOR.REGION)
      end
    end

    if sm_px > abs_wave_x then
      DL_AddRectFilled(dl, abs_wave_x, abs_wave_y, math_min(sm_px, wave_x_end), wave_y_end, COLOR.UNUSED)
    end
    if em_px < wave_x_end then
      DL_AddRectFilled(dl, math_max(em_px, abs_wave_x), abs_wave_y, wave_x_end, wave_y_end, COLOR.UNUSED)
    end

    local sel_left_px, sel_right_px = 0, 0
    if has_valid_selection() then
      local sel_s = math_min(selection_start, selection_end)
      local sel_e = math_max(selection_start, selection_end)
      sel_left_px = math_max(abs_wave_x, t2px(sel_s))
      sel_right_px = math_min(wave_x_end, t2px(sel_e))
      if sel_right_px > sel_left_px then
        DL_AddRectFilled(dl, sel_left_px, abs_wave_y, sel_right_px, wave_y_end, COLOR.SELECTION)
        DL_AddRect(dl, sel_left_px, abs_wave_y, sel_right_px, wave_y_end, COLOR.SELECTION_BORDER, 0, 0, 2)

        if not right_click_hint_seen then
          -- Subtle blinking hint for the right-click SET action.
          local selection_width = sel_right_px - sel_left_px
          local hint = selection_width > 110 and "RIGHT-CLICK HERE" or "RMB"
          local hint_w = reaper.ImGui_CalcTextSize(ctx, hint)
          local hint_h = 13
          local pulse = (math.sin(now * 3.0) + 1.0) * 0.5
          local alpha = math_floor(90 + pulse * 100)
          local hint_color = with_alpha(0xB0B0B0FF, alpha)
          local hint_x = (sel_left_px + sel_right_px - hint_w) / 2
          local hint_y = abs_wave_y + 6
          DL_AddRectFilled(dl, hint_x - 4, hint_y - 2, hint_x + hint_w + 4, hint_y + hint_h + 2,
            with_alpha(0x000000FF, math_floor(45 + pulse * 35)), 3)
          DL_AddTextEx(dl, font, 13, hint_x, hint_y, hint_color, hint)
        end
      end
    end

    if #slots > 0 then
      for i = 1, #slots do
        local slot = slots[i]
        local s_px = t2px(slot.s)
        local e_px = t2px(slot.e)
        local z_left = math_max(abs_wave_x, s_px)
        local z_right = math_min(wave_x_end, e_px)
        if z_right > z_left then
          DL_AddRectFilled(dl, z_left, abs_slot_zone_y + 1, z_right, abs_slot_zone_y + SLOT_ZONE_H - 1, COLOR.SLOT_ZONE, 1)
          if s_px >= abs_wave_x and s_px <= wave_x_end then
            DL_AddLine(dl, s_px, abs_slot_zone_y, s_px, abs_slot_zone_y + SLOT_ZONE_H, COLOR.SLOT_ZONE_LINE, 1)
          end
          if e_px >= abs_wave_x and e_px <= wave_x_end then
            DL_AddLine(dl, e_px, abs_slot_zone_y, e_px, abs_slot_zone_y + SLOT_ZONE_H, COLOR.SLOT_ZONE_LINE, 1)
          end
          local lbl = (i == 10) and "0" or tostring(i)
          DL_AddTextEx(dl, font_slot, 16, z_left + 3, wave_y_end - 22, COLOR.SLOT_ZONE_TEXT, lbl)
        end
      end
    end
    DL_AddRect(dl, abs_wave_x, abs_slot_zone_y, wave_x_end, abs_slot_zone_y + SLOT_ZONE_H, 0x333333FF, 0, 0, 1)

    -- Loopbar
    local lb_x1 = math_max(abs_wave_x, sm_px)
    local lb_x2 = math_min(wave_x_end, em_px)
    if lb_x2 > lb_x1 then
      DL_AddRectFilled(dl, lb_x1, abs_loopbar_y, lb_x2, abs_loopbar_y + LOOPBAR_H, COLOR.LOOPBAR_FILL, 3)
      DL_AddRect(dl, lb_x1, abs_loopbar_y, lb_x2, abs_loopbar_y + LOOPBAR_H, COLOR.MARKER, 3, 0, 2)
    end

    local near_start = math_abs(mx - sm_px) <= MARKER_W and my >= abs_wave_y and my <= wave_y_end
    local near_end = math_abs(mx - em_px) <= MARKER_W and my >= abs_wave_y and my <= wave_y_end
    local mouse_in_wave = mx >= abs_wave_x and mx <= wave_x_end and my >= abs_wave_y and my <= wave_y_end
    local mouse_in_loopbar = mx >= lb_x1 and mx <= lb_x2 and my >= abs_loopbar_y and my <= abs_loopbar_y + LOOPBAR_H
    local mouse_in_selection = has_valid_selection() and mx >= sel_left_px and mx <= sel_right_px and my >= abs_wave_y and my <= wave_y_end

    if reaper.ImGui_IsMouseClicked(ctx, 1) and mouse_in_selection then
      if not right_click_hint_seen then
        right_click_hint_seen = true
        save_persistent_state()
      end
      apply_selection()
    end

    -- Left-click interactions
    if reaper.ImGui_IsMouseClicked(ctx, 0) and not mouse_in_btn and not mouse_in_add
      and not mouse_in_loopbar and not mouse_in_ruler and not mouse_in_any_slot
      and not mouse_in_lock and not mouse_in_zc and not mouse_in_ts
      and not mouse_in_grid_btn and not mouse_in_snap and not mouse_in_loop_len_btn
      and not mouse_in_scale2 and not mouse_in_scale_half
      and not mouse_in_settings then
      if mouse_in_wave then
        if near_start and not near_end then
          drag_mode = "start"; drag_activated = false
          drag_start_mx, drag_start_s, drag_start_e = mx, start_offset, end_offset
          last_loop_written_start, last_loop_written_end = nil, nil
          local root_src = get_root_source(source)
          drag_root_fn = reaper.GetMediaSourceFileName(root_src, "")
          drag_root_type = reaper.GetMediaSourceType(root_src, "")
        elseif near_end then
          drag_mode = "end"; drag_activated = false
          drag_start_mx, drag_start_s, drag_start_e = mx, start_offset, end_offset
          last_loop_written_start, last_loop_written_end = nil, nil
          local root_src = get_root_source(source)
          drag_root_fn = reaper.GetMediaSourceFileName(root_src, "")
          drag_root_type = reaper.GetMediaSourceType(root_src, "")
        else
          -- ===== SELECTION START: snap using same rule as loop markers =====
          is_selecting = true
          local t = px2t(mx)
          t = math_max(0, math_min(src_len, t))
          t = snap_marker_time(t)
          t = math_max(0, math_min(src_len, t))
          selection_start = t
          selection_end = t
        end
      end
    end

    if is_selecting then
      if reaper.ImGui_IsMouseDown(ctx, 0) then
        local clamped_mx = math_max(abs_wave_x - EDGE_SCROLL_MARGIN, math_min(wave_x_end + EDGE_SCROLL_MARGIN, mx))
        local raw_t = math_max(0, math_min(src_len, px2t(clamped_mx)))
        -- ===== SELECTION DRAG: snap using same rule as loop markers =====
        selection_end = math_max(0, math_min(src_len, snap_marker_time(raw_t)))
        do_edge_scroll(mx, "auto")
        local new_view_len_s = src_len / zoom
        local new_view_center_s = range_center + pan_offset
        local new_view_start_s = new_view_center_s - new_view_len_s / 2
        if new_view_start_s < 0 then new_view_start_s = 0 end
        if new_view_start_s + new_view_len_s > src_len then new_view_start_s = src_len - new_view_len_s end
        if mx <= abs_wave_x then
          selection_end = math_max(0, math_min(src_len, snap_marker_time(new_view_start_s)))
        elseif mx >= wave_x_end then
          selection_end = math_max(0, math_min(src_len, snap_marker_time(new_view_start_s + new_view_len_s)))
        end
      else
        is_selecting = false
        if selection_start and selection_end and math_abs(selection_end - selection_start) < 0.001 then
          selection_start = nil; selection_end = nil
        end
      end
    end

    -- ===== MARKER DRAG (Ableton-style loop section, always) =====
    if drag_mode and reaper.ImGui_IsMouseDown(ctx, 0) then
      if not drag_activated and math_abs(mx - drag_start_mx) >= DRAG_THRESH then drag_activated = true end
      if drag_activated then
        local raw_delta_px = mx - drag_start_mx
        local eff = shift_held and (raw_delta_px / FINE_MODE_DIVISOR) or raw_delta_px
        local delta_t = (eff / wave_w) * view_len

        local new_s, new_e
        if drag_mode == "start" then
          new_s = math_max(0, math_min(drag_start_e - 0.001, drag_start_s + delta_t))
          new_s = snap_marker_time(new_s)
          new_s = math_max(0, math_min(drag_start_e - 0.001, new_s))
          new_e = drag_start_e
        else
          new_s = drag_start_s
          new_e = math_max(drag_start_s + 0.001, math_min(src_len, drag_start_e + delta_t))
          new_e = snap_marker_time(new_e)
          new_e = math_max(drag_start_s + 0.001, math_min(src_len, new_e))
        end
        loop_preview_start = new_s
        loop_preview_end = new_e
        local now = reaper.time_precise()
        local moved_since_write = not last_loop_written_start
          or math_abs(new_s - last_loop_written_start) > 0.00001
          or math_abs(new_e - last_loop_written_end) > 0.00001
        if moved_since_write and now - last_loop_chunk_update >= LOOP_CHUNK_UPDATE_INTERVAL then
          if drag_root_fn then
            if set_take_loop_section(item, take, drag_root_fn, drag_root_type, new_s, new_e - new_s) then
              local new_take = reaper.GetActiveTake(item)
              if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
              reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
              last_loop_written_start, last_loop_written_end = new_s, new_e
            end
          end
          last_loop_chunk_update = now
        end
        do_edge_scroll(mx, "auto")
      end
    end

    if reaper.ImGui_IsMouseReleased(ctx, 0) and drag_mode then
      if drag_activated and drag_root_fn and loop_preview_start and loop_preview_end then
        if set_take_loop_section(item, take, drag_root_fn, drag_root_type, loop_preview_start, loop_preview_end - loop_preview_start) then
          local new_take = reaper.GetActiveTake(item)
          if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
          reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
        end
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Adjust loop start/end", -1, -1)
        -- Only remember this as the grid-aligned reference if the drag was
        -- actually performed with grid-snap active.
        if snap_enabled then save_grid_reference(current_guid, loop_preview_start, loop_preview_end) end
      end
      drag_mode, drag_activated = nil, false
      drag_root_fn, drag_root_type = nil, nil
      last_loop_written_start, last_loop_written_end = nil, nil
      loop_preview_start, loop_preview_end = nil, nil
    end

    -- ===== LOOPBAR DRAG (synced move, Ableton-style, always) =====
    if reaper.ImGui_IsMouseClicked(ctx, 0) and mouse_in_loopbar then
      loopbar_drag = true
      loopbar_drag_start_mx, loopbar_drag_start_s, loopbar_drag_start_e = mx, start_offset, end_offset
      last_loop_written_start, last_loop_written_end = nil, nil
      local root_src = get_root_source(source)
      loopbar_drag_root_fn = reaper.GetMediaSourceFileName(root_src, "")
      loopbar_drag_root_type = reaper.GetMediaSourceType(root_src, "")
    end
    if loopbar_drag then
      if reaper.ImGui_IsMouseDown(ctx, 0) then
        local raw_delta_px = mx - loopbar_drag_start_mx
        local eff = shift_held and (raw_delta_px / FINE_MODE_DIVISOR) or raw_delta_px
        local delta_t = (eff / wave_w) * view_len
        local region_len = loopbar_drag_start_e - loopbar_drag_start_s
        local new_s = math_max(0, math_min(src_len - region_len, loopbar_drag_start_s + delta_t))
        new_s = snap_region_local(new_s, region_len)
        new_s = math_max(0, math_min(src_len - region_len, new_s))
        local new_e = new_s + region_len

        loop_preview_start = new_s
        loop_preview_end = new_e
        local now = reaper.time_precise()
        local moved_since_write = not last_loop_written_start
          or math_abs(new_s - last_loop_written_start) > 0.00001
          or math_abs(new_e - last_loop_written_end) > 0.00001
        if moved_since_write and now - last_loop_chunk_update >= LOOP_CHUNK_UPDATE_INTERVAL then
          if loopbar_drag_root_fn then
            if set_take_loop_section(item, take, loopbar_drag_root_fn, loopbar_drag_root_type, new_s, region_len) then
              local new_take = reaper.GetActiveTake(item)
              if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
              reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
              last_loop_written_start, last_loop_written_end = new_s, new_e
            end
          end
          last_loop_chunk_update = now
        end

        local new_s_px = t2px(new_s)
        local new_e_px = t2px(new_e)
        if new_s_px <= abs_wave_x + AUTO_SCROLL_ZONE then
          do_edge_scroll(new_s_px, "left")
        elseif new_e_px >= wave_x_end - AUTO_SCROLL_ZONE then
          do_edge_scroll(new_e_px, "right")
        end
      else
        loopbar_drag = false
        if loopbar_drag_root_fn and loop_preview_start and loop_preview_end then
          local region_len = loop_preview_end - loop_preview_start
          if set_take_loop_section(item, take, loopbar_drag_root_fn, loopbar_drag_root_type, loop_preview_start, region_len) then
            local new_take = reaper.GetActiveTake(item)
            if new_take then reaper.SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS", 0) end
            reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 1)
          end
          reaper.UpdateArrange()
          reaper.Undo_OnStateChangeEx("Move loop region", -1, -1)
          if snap_enabled then save_grid_reference(current_guid, loop_preview_start, loop_preview_end) end
        end
        loopbar_drag_root_fn, loopbar_drag_root_type = nil, nil
        last_loop_written_start, last_loop_written_end = nil, nil
        loop_preview_start, loop_preview_end = nil, nil
      end
    end

    -- Mouse wheel: zoom centered on mouse
    local wheel = reaper.ImGui_GetMouseWheel(ctx)
    if wheel ~= 0 and (mouse_in_wave or mouse_in_ruler) then
      if shift_held then
        local scroll_amount = view_len * 0.1
        pan_offset = pan_offset + wheel * scroll_amount
        local new_vl = src_len / zoom
        local half = new_vl / 2
        pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
      else
        local wm = 1.2
        local frac = (mx - abs_wave_x) / wave_w
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        local t_under = view_start + frac * view_len
        zoom = math_max(1, math_min(500, wheel > 0 and zoom * wm or zoom / wm))
        local new_vl = src_len / zoom
        pan_offset = t_under - range_center + new_vl * (0.5 - frac)
        local half = new_vl / 2
        pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
      end
    end

    -- Middle-click pan
    if reaper.ImGui_IsMouseClicked(ctx, 2) and mouse_in_wave then
      is_panning = true; pan_start_mx, pan_start_off = mx, pan_offset
    end
    if reaper.ImGui_IsMouseReleased(ctx, 2) then is_panning = false end
    if is_panning and reaper.ImGui_IsMouseDown(ctx, 2) then
      local dp = mx - pan_start_mx
      if shift_held then dp = dp / FINE_MODE_DIVISOR end
      pan_offset = pan_start_off - (dp / wave_w) * view_len
      local half = view_len / 2
      pan_offset = math_max(-range_center + half, math_min(src_len - range_center - half, pan_offset))
    end

    -- Cursor
    if loopbar_drag or mouse_in_loopbar then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
    elseif is_selecting then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_TextInput())
    elseif drag_mode or near_start or near_end then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
    elseif mouse_in_selection then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    elseif ruler_scroll_drag or mouse_in_thumb then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
    elseif mouse_in_ruler then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    elseif is_panning then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
    elseif slot_hovered_idx or mouse_in_lock or mouse_in_zc or mouse_in_ts or mouse_in_grid_btn or mouse_in_snap or mouse_in_loop_len_btn or mouse_in_scale2 or mouse_in_scale_half or mouse_in_settings then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    elseif mouse_in_add and can_add then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    end

    -- Draw markers
    local function draw_marker(px, is_start, hovered, dragging)
      if px < abs_wave_x - MARKER_W or px > wave_x_end + MARKER_W then return end
      local col = (hovered or dragging) and COLOR.MARKER_HOV or COLOR.MARKER
      DL_AddLine(dl, px, abs_wave_y, px, wave_y_end, col, 2)
      local tri_dir = is_start and 1 or -1
      DL_AddTriangleFilled(dl, px, abs_wave_y, px + MARKER_W * 1.5 * tri_dir, abs_wave_y, px, abs_wave_y + MARKER_W * 1.5, col)
      if zero_cross_snap and not snap_enabled and (hovered or dragging) then
        DL_AddCircleFilled(dl, px, abs_wave_y + MARKER_W * 1.5 + 6, 3, COLOR.ZC_ON)
      end
    end

    draw_marker(sm_px, true, near_start, drag_mode == "start" and drag_activated)
    draw_marker(em_px, false, near_end, drag_mode == "end" and drag_activated)

    -- Playhead
    local play_state = reaper.GetPlayState()
    if play_state & 1 ~= 0 then
      local src_pp = (reaper.GetPlayPosition() - item_pos) * playrate + start_offset
      local is_looped = reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") > 0.5
      local loop_len_cur = end_offset - start_offset
      if is_looped and loop_len_cur > 0.0001 then
        local rel = (src_pp - start_offset) % loop_len_cur
        src_pp = start_offset + rel
      end
      local ph_px = t2px(src_pp)
      if ph_px >= abs_wave_x and ph_px <= wave_x_end then
        DL_AddLine(dl, ph_px, abs_wave_y, ph_px, wave_y_end, COLOR.PLAYHEAD, 2)
      end
    end

    DL_AddRect(dl, abs_wave_x, abs_wave_y, wave_x_end, wave_y_end, theme.Border, 0, 0, 1)

    reaper.ImGui_End(ctx)
  end

  popTheme()
  reaper.ImGui_PopStyleVar(ctx, 5)
  reaper.ImGui_PopFont(ctx)
  check_and_save_state()
  if open then reaper.defer(loop) end
end

reaper.defer(loop)

