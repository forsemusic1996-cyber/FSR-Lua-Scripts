--[[
-------------------------------------------------------------------------------------------
*              FSR FlipX
* Section      Main
* Author:      Andrew Dihtaryk(FSR)
* Version:     1.00
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:     http://forum.cockos.com/showthread.php?t=310636


-------------------------------------------------------------------------------------------
--]]  
if not reaper.ImGui_CreateContext then
  reaper.MB("ReaImGui extension required.\nInstall via ReaPack.", "Error", 0)
  return
end

local ctx = reaper.ImGui_CreateContext("SimpleItemView")
local font = reaper.ImGui_CreateFont("Arial", 14)
local font_slot = reaper.ImGui_CreateFont("Arial", 16)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, font_slot)

-- ===== PERSISTENT STATE =====
local EXT_SECTION = "SimpleItemView"

local window_locked = false
local locked_pos_x = nil
local locked_pos_y = nil
local locked_size_w = nil
local locked_size_h = nil
local zero_cross_snap = true
local sync_arrow_selection = false
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
  reaper.SetExtState(EXT_SECTION, "sync_arrow_selection", sync_arrow_selection and "1" or "0", true)
  reaper.SetExtState(EXT_SECTION, "sample_waveform_mode", waveform_mode, true)
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
  local sas = reaper.GetExtState(EXT_SECTION, "sync_arrow_selection")
  if sas == "1" then sync_arrow_selection = true elseif sas == "0" then sync_arrow_selection = false else sync_arrow_selection = false end
  local wm = reaper.GetExtState(EXT_SECTION, "sample_waveform_mode")
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

-- Тема: teal-акценти, але оригінальні Titlebar, Scrollbar та Popup-меню (лише підсвітка teal)
local theme = {
    WindowBg = 0x1E1E1EFF, Text = 0xE0E0E0FF, TextDisabled = 0x808080FF,
    FrameBg = 0x0F3D3AFF, FrameBgHovered = 0x14524EFF, FrameBgActive = 0x1A6A64FF,
    TitleBg = 0x1A1A1AFF, TitleBgActive = 0x2D2D2DFF,  -- оригінал
    Button = 0x0F4C49FF, ButtonHovered = 0x14615DFF, ButtonActive = 0x1A7A75FF,
    CheckMark = 0x5EEAD4FF,
    ScrollbarBg = 0x1A1A1AFF,                           -- оригінал
    ScrollbarGrab = 0x404040FF,                        -- оригінал
    ScrollbarGrabHovered = 0x505050FF,                 -- оригінал
    ScrollbarGrabActive = 0x606060FF,                  -- оригінал
    Header = 0x0F4C49FF, HeaderHovered = 0x14615DFF, HeaderActive = 0x1A7A75FF, -- підсвітка teal
    Separator = 0x505050FF,                            -- оригінал (не teal)
    PopupBg = 0x252525FF,                              -- оригінал (не teal)
    MenuBarBg = 0x2A2A2AFF,                            -- оригінал (не teal)
    Border = 0x1A7A75FF, ActivePreset = 0x5EEAD4FF, ChildBg = 0x1A1A1AFF,
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

-- ===== ALL DRAWING COLORS CONSOLIDATED INTO ONE TABLE =====
local C = {
  BG               = 0x1A1A1AFF,
  WAVE             = 0x80E0D0FF,   -- світлий teal (верхній канал)
  WAVE_ALT         = 0x2A9D95FF,   -- темніший teal (нижній канал)
  AXIS             = 0x5EEAD433,
  MARKER           = 0x5EEAD4FF,
  MARKER_HOV       = 0x99F6E4FF,
  UNUSED           = 0x00000066,
  RULER_BG         = 0x122D2CFF,
  RULER_TEXT       = 0x80E0D0FF,
  RULER_TICK       = 0x2DD4BFFF,
  GRID             = 0x2DD4BF22,
  -- Same visible grid brightness as LoopX.
  GRID_LINE        = 0x363636FF,
  GRID_BAR         = 0x0F3D3AFF,
  GRID_BEAT        = 0x0D2B2AFF,
  PLAYHEAD         = 0x5EEAD4FF,
  REGION           = 0x2DD4BF33,
  LOOPBAR_FILL     = 0x2DD4BFAA,
  SELECTION        = 0x2DD4BF55,
  SELECTION_BORDER = 0x5EEAD4CC,
  SET_BTN          = 0x5EEAD4FF,
  SET_BTN_BG       = 0x0F3D3AFF,

  SLOT_FILLED      = 0x5EEAD4FF,
  SLOT_FILLED_BG   = 0x0F3D3AFF,
  SLOT_HOVERED_BG  = 0x14524EFF,
  SLOT_ACTIVE      = 0x99F6E4FF,
  SLOT_ADD         = 0x80E0D0FF,
  SLOT_ADD_BG      = 0x0F3D3AFF,
  SLOT_ZONE        = 0x5EEAD466,
  SLOT_ZONE_LINE   = 0x5EEAD488,
  SLOT_ZONE_TEXT   = 0x5EEAD4DD,

  LOCK_ON          = 0x5EEAD4FF,
  LOCK_ON_BG       = 0x0F3D3AFF,
  LOCK_OFF         = 0x666666FF,
  LOCK_OFF_BG      = 0x1A1A1AFF,

  ZC_ON            = 0x5EEAD4FF,
  ZC_ON_BG         = 0x0F3D3AFF,
  ZC_OFF           = 0x666666FF,
  ZC_OFF_BG        = 0x1A1A1AFF,

  TS_BTN           = 0x5EEAD4FF,
  TS_BTN_BG        = 0x0F3D3AFF,

  GEAR_BTN         = 0x80E0D0FF,
  GEAR_BTN_BG      = 0x0F3D3AFF,
  GEAR_BTN_HOV     = 0x99F6E4FF,
  GEAR_BTN_BG_HOV  = 0x14524EFF,

  LOOPLEN_BTN         = 0x5EEAD4FF,
  LOOPLEN_BTN_HOV     = 0x99F6E4FF,
  LOOPLEN_BTN_BG      = 0x0F3D3AFF,
  LOOPLEN_BTN_BG_HOV  = 0x14524EFF,

  -- Скролбар повернено до оригінальних темно-сірих кольорів
  SCROLLBAR_BG         = 0x1A1A1AFF,
  SCROLLBAR_TRACK      = 0x333333FF,
  SCROLLBAR_THUMB      = 0x5A5A5AFF,
  SCROLLBAR_THUMB_HOV  = 0x7A7A7AFF,
  SCROLLBAR_THUMB_ACT  = 0x9A9A9AFF,
}

-- Колір тексту кнопок – білий
local BUTTON_TEXT = 0xFFFFFFFF

-- ===== ALL SIZE/LAYOUT CONSTANTS CONSOLIDATED INTO ONE TABLE =====
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
-- Keep Sample Scrolling themes independent from LoopX themes. Both scripts
-- use the same main ExtState section for window/grid state, but theme data
-- must live in a separate namespace.
local THEME_EXT_SECTION = EXT_SECTION .. "_SampleScrolling"

local COLOR_KEYS = { "waveform", "waveform_inactive", "waveform_bg", "centerline",
  "markers", "markers_hover", "border", "playhead", "grid_bar", "grid_beat",
  "ruler_bg", "ruler_text", "ruler_tick", "info_bar_bg", "info_bar_text",
  "info_bar_icon", "btn_on", "btn_off", "btn_hover", "btn_text", "highlight" }
settings.COLOR_KEYS = COLOR_KEYS

settings.THEMES = {
  {
    id = "default",
    name = "Default",
    description = "Current Sample teal theme",
    colors = {
      waveform = 0x80E0D0FF, waveform_inactive = 0x2A9D95FF, waveform_bg = 0x1A1A1AFF,
      centerline = 0x5EEAD433, markers = 0x5EEAD4FF, markers_hover = 0x99F6E4FF,
      border = 0x1A7A75FF, playhead = 0x5EEAD4FF, grid_bar = 0x363636FF, grid_beat = 0x2DD4BF22,
      ruler_bg = 0x122D2CFF, ruler_text = 0x80E0D0FF, ruler_tick = 0x2DD4BFFF,
      info_bar_bg = 0x1E1E1EFF, info_bar_text = 0xFFFFFFFF, info_bar_icon = 0x5EEAD4FF,
      btn_on = 0x5EEAD4FF, btn_off = 0x0F4C49FF, btn_hover = 0x99F6E4FF, btn_text = 0xFFFFFFFF,
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
      reaper.SetExtState(THEME_EXT_SECTION, "custom_color_" .. key, tostring(colors[key]), true)
    end
  end
end

function settings.load_custom_colors()
  local colors = {}
  for _, key in ipairs(COLOR_KEYS) do
    local val = reaper.GetExtState(THEME_EXT_SECTION, "custom_color_" .. key)
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
  reaper.SetExtState(THEME_EXT_SECTION, "user_theme_count", tostring(#user_themes), true)
  for i, theme in ipairs(user_themes) do
    local prefix = "user_theme_" .. i .. "_"
    reaper.SetExtState(THEME_EXT_SECTION, prefix .. "id", theme.id, true)
    reaper.SetExtState(THEME_EXT_SECTION, prefix .. "name", theme.name, true)
    for _, key in ipairs(COLOR_KEYS) do
      reaper.SetExtState(THEME_EXT_SECTION, prefix .. key, tostring(theme.colors[key] or 0), true)
    end
  end
  local i = #user_themes + 1
  while true do
    local prefix = "user_theme_" .. i .. "_"
    local old_id = reaper.GetExtState(THEME_EXT_SECTION, prefix .. "id")
    if old_id == "" then break end
    reaper.DeleteExtState(THEME_EXT_SECTION, prefix .. "id", true)
    reaper.DeleteExtState(THEME_EXT_SECTION, prefix .. "name", true)
    for _, key in ipairs(COLOR_KEYS) do
      reaper.DeleteExtState(THEME_EXT_SECTION, prefix .. key, true)
    end
    i = i + 1
  end
end

function settings._load_user_themes()
  local count_str = reaper.GetExtState(THEME_EXT_SECTION, "user_theme_count")
  local count = tonumber(count_str) or 0
  for i = 1, count do
    local prefix = "user_theme_" .. i .. "_"
    local id = reaper.GetExtState(THEME_EXT_SECTION, prefix .. "id")
    local name = reaper.GetExtState(THEME_EXT_SECTION, prefix .. "name")
    if id ~= "" and name ~= "" then
      local colors = {}
      for _, key in ipairs(COLOR_KEYS) do
        local val = reaper.GetExtState(THEME_EXT_SECTION, prefix .. key)
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
  local theme_id = reaper.GetExtState(THEME_EXT_SECTION, "theme")
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
  reaper.SetExtState(THEME_EXT_SECTION, "theme", settings.current.theme_id, true)
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
  C.WAVE = c.waveform or 0xB380CCFF
  C.WAVE_ALT = c.waveform_inactive or 0x80B3CCFF
  C.BG = bg
  C.AXIS = c.centerline or 0xB3B39966
  C.MARKER = acc
  C.MARKER_HOV = c.markers_hover or acc
  C.PLAYHEAD = c.playhead or acc
  C.GRID_LINE = c.grid_bar or 0x44444455
  C.GRID = c.grid_beat or 0xFFFFFF18
  C.RULER_TEXT = c.ruler_text or 0xAAAAAAFF
  C.RULER_TICK = c.ruler_tick or 0x666666FF

  -- Accent-derived fills
  C.REGION = with_alpha(acc, 0x33)
  C.LOOPBAR_FILL = with_alpha(acc, 0xAA)

  -- Ruler / scrollbar chrome
  C.SCROLLBAR_BG = c.ruler_bg or bg
  C.SCROLLBAR_TRACK = offset_color(C.SCROLLBAR_BG, 10)
  C.SCROLLBAR_THUMB = offset_color(C.SCROLLBAR_BG, 40)
  C.SCROLLBAR_THUMB_HOV = offset_color(C.SCROLLBAR_BG, 60)
  C.SCROLLBAR_THUMB_ACT = offset_color(C.SCROLLBAR_BG, 80)

  -- Active controls (accent-driven)
  C.SET_BTN = on
  C.SET_BTN_BG = derive_color(on, 0.30)
  C.TS_BTN = on
  C.TS_BTN_BG = derive_color(on, 0.26)
  C.ZC_ON = on
  C.ZC_ON_BG = derive_color(on, 0.26)
  C.ZC_OFF = off
  C.ZC_OFF_BG = derive_color(off, 0.50)
  C.LOOPLEN_BTN = acc
  C.LOOPLEN_BTN_BG = derive_color(acc, 0.26)

  -- Slots
  C.SLOT_FILLED = on
  C.SLOT_FILLED_BG = derive_color(on, 0.26)
  C.SLOT_HOVERED_BG = derive_color(on, 0.40)
  C.SLOT_ACTIVE = hover
  C.SLOT_ADD = on
  C.SLOT_ADD_BG = derive_color(on, 0.26)

  -- Toggles (Lock / Snap) follow the same button colors
  C.LOCK_ON = on
  C.LOCK_ON_BG = derive_color(on, 0.26)
  C.LOCK_OFF = off
  C.LOCK_OFF_BG = derive_color(off, 0.50)
  C.SNAP_ON = on
  C.SNAP_ON_BG = derive_color(on, 0.26)
  C.SNAP_OFF = off
  C.SNAP_OFF_BG = derive_color(off, 0.50)

  -- Button text is white
  C.BTN_TEXT = c.btn_text or 0xFFFFFFFF
  BUTTON_TEXT = C.BTN_TEXT

  -- Controls that are specific to Sample Scrolling but share the theme's
  -- accent/hover colors. Keep these in the same refresh pass so every preset
  -- updates the complete UI consistently.
  C.GEAR_BTN = c.waveform or on
  C.GEAR_BTN_BG = derive_color(on, 0.26)
  C.GEAR_BTN_HOV = hover
  C.GEAR_BTN_BG_HOV = derive_color(hover, 0.35)
  C.LOOPLEN_BTN_HOV = hover
  C.LOOPLEN_BTN_BG_HOV = derive_color(hover, 0.35)

  -- Unified hover + selection highlight (configurable separately)
  local hl = c.highlight or 0x66CCFFFF
  C.HOVER_FG = hl
  C.HOVER_BG = derive_color(hl, 0.35)
  C.SELECTION = with_alpha(hl, 0x55)
  C.SELECTION_BORDER = with_alpha(hl, 0xCC)

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

  -- Keep the current Sample teal appearance byte-for-byte as the built-in
  -- Default preset. Other presets use the derived LoopX palette above.
  if s.id == "default" then
    C.BG = 0x1A1A1AFF
    C.WAVE = 0x80E0D0FF
    C.WAVE_ALT = 0x2A9D95FF
    C.AXIS = 0x5EEAD433
    C.MARKER = 0x5EEAD4FF
    C.MARKER_HOV = 0x99F6E4FF
    C.RULER_BG = 0x122D2CFF
    C.RULER_TEXT = 0x80E0D0FF
    C.RULER_TICK = 0x2DD4BFFF
    C.GRID = 0x2DD4BF22
    C.GRID_LINE = 0x363636FF
    C.GRID_BAR = 0x0F3D3AFF
    C.GRID_BEAT = 0x0D2B2AFF
    C.PLAYHEAD = 0x5EEAD4FF
    C.REGION = 0x2DD4BF33
    C.LOOPBAR_FILL = 0x2DD4BFAA
    C.SELECTION = 0x2DD4BF55
    C.SELECTION_BORDER = 0x5EEAD4CC
    C.SET_BTN = 0x5EEAD4FF
    C.SET_BTN_BG = 0x0F3D3AFF
    C.SLOT_FILLED = 0x5EEAD4FF
    C.SLOT_FILLED_BG = 0x0F3D3AFF
    C.SLOT_HOVERED_BG = 0x14524EFF
    C.SLOT_ACTIVE = 0x99F6E4FF
    C.SLOT_ADD = 0x80E0D0FF
    C.SLOT_ADD_BG = 0x0F3D3AFF
    C.LOCK_ON = 0x5EEAD4FF
    C.LOCK_ON_BG = 0x0F3D3AFF
    C.LOCK_OFF = 0x666666FF
    C.LOCK_OFF_BG = 0x1A1A1AFF
    C.ZC_ON = 0x5EEAD4FF
    C.ZC_ON_BG = 0x0F3D3AFF
    C.ZC_OFF = 0x666666FF
    C.ZC_OFF_BG = 0x1A1A1AFF
    C.TS_BTN = 0x5EEAD4FF
    C.TS_BTN_BG = 0x0F3D3AFF
    C.GEAR_BTN = 0x80E0D0FF
    C.GEAR_BTN_BG = 0x0F3D3AFF
    C.GEAR_BTN_HOV = 0x99F6E4FF
    C.GEAR_BTN_BG_HOV = 0x14524EFF
    C.LOOPLEN_BTN = 0x5EEAD4FF
    C.LOOPLEN_BTN_HOV = 0x99F6E4FF
    C.LOOPLEN_BTN_BG = 0x0F3D3AFF
    C.LOOPLEN_BTN_BG_HOV = 0x14524EFF
    C.SCROLLBAR_BG = 0x1A1A1AFF
    C.SCROLLBAR_TRACK = 0x333333FF
    C.SCROLLBAR_THUMB = 0x5A5A5AFF
    C.SCROLLBAR_THUMB_HOV = 0x7A7A7AFF
    C.SCROLLBAR_THUMB_ACT = 0x9A9A9AFF
    BUTTON_TEXT = 0xFFFFFFFF

    theme.WindowBg = 0x1E1E1EFF
    theme.Text = 0xE0E0E0FF
    theme.TextDisabled = 0x808080FF
    theme.FrameBg = 0x0F3D3AFF
    theme.FrameBgHovered = 0x14524EFF
    theme.FrameBgActive = 0x1A6A64FF
    theme.TitleBg = 0x1A1A1AFF
    theme.TitleBgActive = 0x2D2D2DFF
    theme.Button = 0x0F4C49FF
    theme.ButtonHovered = 0x14615DFF
    theme.ButtonActive = 0x1A7A75FF
    theme.CheckMark = 0x5EEAD4FF
    theme.ScrollbarBg = 0x1A1A1AFF
    theme.ScrollbarGrab = 0x404040FF
    theme.ScrollbarGrabHovered = 0x505050FF
    theme.ScrollbarGrabActive = 0x606060FF
    theme.Header = 0x0F4C49FF
    theme.HeaderHovered = 0x14615DFF
    theme.HeaderActive = 0x1A7A75FF
    theme.Separator = 0x505050FF
    theme.PopupBg = 0x252525FF
    theme.MenuBarBg = 0x2A2A2AFF
    theme.Border = 0x1A7A75FF
    theme.ActivePreset = 0x5EEAD4FF
    theme.ChildBg = 0x1A1A1AFF
  end
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
  local visible, open = reaper.ImGui_Begin(ctx, "FSR SlipX - Colors & Themes", true, flags)

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


local SZ = {
  MARKER_W     = 8,
  RULER_H      = 22,
  PADDING      = 8,
  WIN_PAD      = 6,
  SET_BTN_W    = 40,
  SET_BTN_H    = 18,
  LOOPBAR_H    = 14,
  SLOT_W       = 22,
  SLOT_GAP     = 3,
  ADD_BTN_W    = 20,
  LOCK_BTN_W   = 22,
  GEAR_BTN_W   = 22,
  ZC_BTN_W     = 26,
  TS_BTN_W     = 22,
  LINK_BTN_W   = 34,
  SNAP_BTN_W   = 34,
  SLOT_ZONE_H  = 6,
  X2_BTN_W     = 30,
  DIV2_BTN_W   = 30,
  LOOP_BTN_GAP = 4,
}

-- Grid dropdown: exactly these 6 fixed divisions
local GRID_FIXED_OPTIONS = {
  {id = "1bar",  label = "1 Bar",  qn = 4},
  {id = "1/2",   label = "1/2",    qn = 2},
  {id = "1/4",   label = "1/4",    qn = 1},
  {id = "1/8",   label = "1/8",    qn = 0.5},
  {id = "1/16",  label = "1/16",   qn = 0.25},
  {id = "1/32",  label = "1/32",   qn = 0.125},
}

local LOOP_LENGTH_OPTIONS = {
  {id = "1bar", label = "1",    qn = 4},
  {id = "1/2",  label = "1/2",  qn = 2},
  {id = "1/4",  label = "1/4",  qn = 1},
  {id = "1/8",  label = "1/8",  qn = 0.5},
  {id = "1/16", label = "1/16", qn = 0.25},
  {id = "1/32", label = "1/32", qn = 0.125},
}

local zoom        = 1.0
local pan_offset  = 0.0
local v_zoom      = 1.0
local last_item_guid = nil
local DRAG_THRESH = 4

local ZC_SEARCH_RADIUS = 0.005

local item_zoom_cache = {}

-- Only a single fixed-grid setting remains
local grid_settings = { fixed = "1/8" }
local grid_popup_x = nil
local grid_popup_y = nil

local settings_popup_x = nil
local settings_popup_y = nil

local loop_len_popup_x = nil
local loop_len_popup_y = nil

local snap_enabled = false

-- ===== GRID REFERENCE (per-item exact grid-locked bounds) =====
local grid_reference = {}

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
  local defaults = { fixed = "1/8" }
  for name, default_val in pairs(defaults) do
    local saved = reaper.GetExtState(EXT_SECTION, "grid_" .. name)
    if saved ~= "" then
      grid_settings[name] = saved
    else
      grid_settings[name] = default_val
    end
  end
end

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

local loopbar_drag = false
local loopbar_drag_start_mx, loopbar_drag_start_s, loopbar_drag_start_e = 0, 0, 0
local loopbar_last_written_start = nil

local ruler_scroll_drag = false
local ruler_scroll_start_mx, ruler_scroll_start_off = 0, 0

local is_panning = false
local pan_start_mx, pan_start_off = 0, 0

local SAMPLE_POINT_RADIUS = 2.5

local item_slots = {}
local MAX_SLOTS = 10

local wav_cache = {
  file_path = nil, samples = nil, nchans = 0, srate = 0,
  src_len = 0, total_samples = 0, bitspersample = 0,
}

local view_cache = {
  view_start = -1, view_len = -1, num_points = -1,
  file_path = nil, v_zoom = -1, mode = nil, data = nil,
}

local ruler_cache = {}
local grid_cache = {}

local current_take = nil
local current_item = nil
local current_section_off = 0
local current_playrate = 1
local current_src_len = 0
local current_item_pos = 0

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local math_ceil = math.ceil
local math_log = math.log
local math_huge = math.huge
local string_format = string.format

load_persistent_state()
load_grid_settings()
load_snap_state()

local prev_window_locked = window_locked
local prev_zero_cross_snap = zero_cross_snap
local prev_sync_arrow_selection = sync_arrow_selection
local prev_locked_pos_x = locked_pos_x
local prev_locked_pos_y = locked_pos_y
local prev_locked_size_w = locked_size_w
local prev_locked_size_h = locked_size_h

local function check_and_save_state()
  local changed = false
  if window_locked ~= prev_window_locked then changed = true end
  if zero_cross_snap ~= prev_zero_cross_snap then changed = true end
  if sync_arrow_selection ~= prev_sync_arrow_selection then changed = true end
  if locked_pos_x ~= prev_locked_pos_x then changed = true end
  if locked_pos_y ~= prev_locked_pos_y then changed = true end
  if locked_size_w ~= prev_locked_size_w then changed = true end
  if locked_size_h ~= prev_locked_size_h then changed = true end
  if changed then
    save_persistent_state()
    prev_window_locked = window_locked
    prev_zero_cross_snap = zero_cross_snap
    prev_sync_arrow_selection = sync_arrow_selection
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

local VIEW_CACHE_TOLERANCE = 0.0001

-- ============================================================
-- OPTIMIZED get_view_data
-- ============================================================
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
        local mixed1, mixed2 = 0, 0
        for ch = 1, sum_nchans do
          local cs = wav_cache.samples[ch]
          mixed1 = mixed1 + (cs[idx1] or 0)
          mixed2 = mixed2 + (cs[idx2] or 0)
        end
        result[1][i] = (mixed1 + (mixed2 - mixed1) * frac) / sum_nchans
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
          for ch = 1, sum_nchans do
            mixed = mixed + (wav_cache.samples[ch][j] or 0)
          end
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

-- ============================================================
-- OPTIMIZED draw_waveform
-- ============================================================
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
    local color = (ch == 1) and C.WAVE or C.WAVE_ALT
    DL_AddLine(dl, wave_x, axis_y, wave_x + wave_w, axis_y, C.AXIS, 1)
    if ch < nchans then
      DL_AddLine(dl, wave_x, cy + chan_h, wave_x + wave_w, cy + chan_h, C.GRID_LINE, 1)
    end
    if data.is_detailed then
      local show_dots = count < 80
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
    reaper.SetMediaItemTakeInfo_Value(current_take, "D_STARTOFFS", sel_s - current_section_off)
    reaper.SetMediaItemInfo_Value(current_item, "D_LENGTH", (sel_e - sel_s) / current_playrate)
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
  reaper.UpdateArrange()
end

-- Link follows the selected item's time range only. It deliberately does not
-- move the edit cursor when the item is resized or the selection is linked.
local LINK_TIME_EPS = 0.000001
local link_prev_item = nil
local link_prev_item_pos = nil
local link_prev_item_end = nil
local link_prev_play_pos = nil
local link_prev_playing = false
local link_seek_until = 0

local function maintain_link_mode(item)
  if not sync_arrow_selection or not item then
    link_prev_item = nil
    link_prev_item_pos = nil
    link_prev_item_end = nil
    link_prev_play_pos = nil
    link_prev_playing = false
    link_seek_until = 0
    return
  end

  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_len

  local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if not ts_start or not ts_end
    or math_abs(ts_start - item_pos) > LINK_TIME_EPS
    or math_abs(ts_end - item_end) > LINK_TIME_EPS then
    reaper.GetSet_LoopTimeRange(true, false, item_pos, item_end, false)
  end

  -- REAPER has no separate SetPlayPosition API. When playback is active and
  -- shortening moves the play cursor outside the item, seek playback back to
  -- the item's start so the linked loop continues instead of going silent.
  local play_state = reaper.GetPlayState()
  local playing = play_state & 1 ~= 0
  local play_pos = reaper.GetPlayPosition2Ex and reaper.GetPlayPosition2Ex(0) or reaper.GetPlayPosition()
  local bounds_changed = link_prev_item ~= item
    or not link_prev_item_pos
    or math_abs(link_prev_item_pos - item_pos) > LINK_TIME_EPS
    or math_abs(link_prev_item_end - item_end) > LINK_TIME_EPS
  local was_inside_previous_item = link_prev_playing
    and link_prev_item == item
    and link_prev_play_pos ~= nil
    and link_prev_play_pos >= link_prev_item_pos
    and link_prev_play_pos <= link_prev_item_end + 0.005

  if bounds_changed and was_inside_previous_item then
    -- Keep a short recovery window: the audio engine may advance one or more
    -- blocks between the edit and this deferred UI frame.
    link_seek_until = reaper.time_precise() + 0.15
  end

  if playing and link_seek_until > reaper.time_precise()
    and (play_pos < item_pos or play_pos >= item_end) then
    if reaper.SetEditCurPos2 then
      reaper.SetEditCurPos2(0, item_pos, false, true)
    else
      reaper.SetEditCurPos(item_pos, false, true)
    end
  end

  link_prev_item = item
  link_prev_item_pos = item_pos
  link_prev_item_end = item_end
  link_prev_play_pos = play_pos
  link_prev_playing = playing
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
    reaper.SetMediaItemTakeInfo_Value(current_take, "D_STARTOFFS", s - current_section_off)
    reaper.SetMediaItemInfo_Value(current_item, "D_LENGTH", (e - s) / current_playrate)
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

-- Only fixed-grid mode remains
local function get_effective_grid_qn()
  return get_fixed_grid_qn(grid_settings.fixed) or 0.5
end

local function qn_to_grid_label(qn)
  if qn >= 4 then return "1 Bar"
  elseif qn >= 2 then return "1/2"
  elseif qn >= 1 then return "1/4"
  elseif qn >= 0.5 then return "1/8"
  elseif qn >= 0.25 then return "1/16"
  else return "1/32" end
end

local function resnap_item_to_grid(take, item, section_off, playrate, src_len, item_pos, grid_div)
  if not take or not item or not grid_div or grid_div <= 0 then return false end
  if playrate == 0 then playrate = 1 end
  local take_off = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local cur_start = math_max(0, section_off + take_off)
  local cur_end = math_min(src_len, cur_start + item_len * playrate)
  if cur_end <= cur_start then return false end

  local function snap_qn(t)
    local proj_t = source_to_project_time(t, item_pos, cur_start, playrate)
    local qn = reaper.TimeMap2_timeToQN(0, proj_t)
    local snapped_qn = math_floor(qn / grid_div + 0.5) * grid_div
    local snapped_proj = reaper.TimeMap2_QNToTime(0, snapped_qn)
    return project_to_source_time(snapped_proj, item_pos, cur_start, playrate)
  end

  local new_s = math_max(0, math_min(src_len, snap_qn(cur_start)))
  local new_e = math_max(0, math_min(src_len, snap_qn(cur_end)))
  if new_e <= new_s then return false end

  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_s - section_off)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", (new_e - new_s) / playrate)
  reaper.UpdateArrange()
  reaper.Undo_OnStateChangeEx("Re-snap loop to grid", -1, -1)
  return true
end

local function set_loop_length(qn_len)
  if not current_take or not current_item then return false end
  local item_pos = reaper.GetMediaItemInfo_Value(current_item, "D_POSITION")
  local playrate = current_playrate
  if playrate == 0 then playrate = 1 end
  local take_off = reaper.GetMediaItemTakeInfo_Value(current_take, "D_STARTOFFS")
  local start_offset = math_max(0, current_section_off + take_off)
  local left_qn = reaper.TimeMap2_timeToQN(0, item_pos)
  local right_qn = left_qn + qn_len
  local right_project = reaper.TimeMap2_QNToTime(0, right_qn)
  local right_source = start_offset + (right_project - item_pos) * playrate
  right_source = math_max(start_offset + 0.001, math_min(current_src_len, right_source))
  if zero_cross_snap and not snap_enabled then
    right_source = find_zero_crossing(right_source, ZC_SEARCH_RADIUS)
    right_source = math_max(start_offset + 0.001, math_min(current_src_len, right_source))
  end
  local new_len = (right_source - start_offset) / playrate
  if new_len > 0 then
    reaper.SetMediaItemInfo_Value(current_item, "D_LENGTH", new_len)
    reaper.UpdateArrange()
    reaper.Undo_OnStateChangeEx("Set loop length", -1, -1)
    return true
  end
  return false
end

local function scale_loop_length(factor)
  if not current_take or not current_item then return false end
  local playrate = current_playrate
  if playrate == 0 then playrate = 1 end
  local take_off = reaper.GetMediaItemTakeInfo_Value(current_take, "D_STARTOFFS")
  local start_offset = math_max(0, current_section_off + take_off)
  local item_len = reaper.GetMediaItemInfo_Value(current_item, "D_LENGTH")
  local cur_region_len = item_len * playrate
  if cur_region_len <= 0 then return false end

  local new_end
  if snap_enabled then
    local item_pos = current_item_pos
    local left_qn = reaper.TimeMap2_timeToQN(0, item_pos)
    local cur_end_time = item_pos + cur_region_len / playrate
    local right_qn = reaper.TimeMap2_timeToQN(0, cur_end_time)
    local qn_len = right_qn - left_qn
    local new_qn_len = qn_len * factor
    if new_qn_len <= 0 then return false end
    local new_right_qn = left_qn + new_qn_len
    local new_right_time = reaper.TimeMap2_QNToTime(0, new_right_qn)
    new_end = start_offset + (new_right_time - item_pos) * playrate
  else
    local new_region_len = cur_region_len * factor
    if new_region_len <= 0 then return false end
    new_end = start_offset + new_region_len
  end

  new_end = math_max(start_offset + 0.001, math_min(current_src_len, new_end))
  if zero_cross_snap and not snap_enabled then
    new_end = find_zero_crossing(new_end, ZC_SEARCH_RADIUS)
    new_end = math_max(start_offset + 0.001, math_min(current_src_len, new_end))
  end
  local new_len = (new_end - start_offset) / playrate
  if new_len > 0 then
    reaper.SetMediaItemInfo_Value(current_item, "D_LENGTH", new_len)
    reaper.UpdateArrange()
    reaper.Undo_OnStateChangeEx("Scale loop length", -1, -1)
    return true
  end
  return false
end

local function get_current_source_bounds(take, item, section_off, playrate, src_len)
  local pr = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if pr == 0 then pr = 1 end
  local take_off = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local s = math_max(0, section_off + take_off)
  local e = math_min(src_len, s + item_len * pr)
  return s, e
end

local function update_grid_reference(guid, take, item, section_off, playrate, src_len)
  if not guid or not take or not item then return end
  local s, e = get_current_source_bounds(take, item, section_off, playrate, src_len)
  if e > s then
    grid_reference[guid] = {s = s, e = e}
  end
end

local function set_take_loop_section(take, item, section_off, playrate, new_s, new_e)
  if not take or not item then return false end
  if playrate == 0 then playrate = 1 end
  if new_e <= new_s then return false end
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_s - section_off)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", (new_e - new_s) / playrate)
  reaper.UpdateArrange()
  return true
end

-- ===================================================================
-- ===== EXTRACTED UI HELPER FUNCTIONS =====
-- ===================================================================

local function draw_top_bar(dl, mx, my, abs_wave_x, abs_btn_y, wave_w, wave_x_end,
                             current_guid, take, item, section_off, playrate, src_len, item_pos,
                             slots, start_offset, end_offset, grid_div, grid_label)
  local has_sel = has_valid_selection()
  local btn_color = has_sel and C.SET_BTN or C.LOCK_OFF
  local btn_bg = has_sel and C.SET_BTN_BG or C.LOCK_OFF_BG
  DL_AddRectFilled(dl, abs_wave_x, abs_btn_y, abs_wave_x + SZ.SET_BTN_W, abs_btn_y + SZ.SET_BTN_H, btn_bg, 3)
  DL_AddRect(dl, abs_wave_x, abs_btn_y, abs_wave_x + SZ.SET_BTN_W, abs_btn_y + SZ.SET_BTN_H, btn_color, 3, 0, 1)
  local tw_set = reaper.ImGui_CalcTextSize(ctx, "SET")
  -- Текст завжди білий
  DL_AddText(dl, abs_wave_x + (SZ.SET_BTN_W - tw_set) / 2, abs_btn_y + 2, BUTTON_TEXT, "SET")

  local mouse_in_btn = mx >= abs_wave_x and mx <= abs_wave_x + SZ.SET_BTN_W and my >= abs_btn_y and my <= abs_btn_y + SZ.SET_BTN_H
  if mouse_in_btn and reaper.ImGui_IsMouseClicked(ctx, 0) and has_sel then
    if apply_selection() then
      if snap_enabled then
        update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
      end
    end
  end

  local slot_start_x = abs_wave_x + SZ.SET_BTN_W + SZ.SLOT_GAP * 2
  local slot_hovered_idx = nil
  local mouse_in_any_slot = false

  for i = 1, #slots do
    local sx = slot_start_x + (i - 1) * (SZ.SLOT_W + SZ.SLOT_GAP)
    local sy = abs_btn_y
    local sx2 = sx + SZ.SLOT_W
    local sy2 = sy + SZ.SET_BTN_H
    local mouse_in_slot = mx >= sx and mx <= sx2 and my >= sy and my <= sy2
    if mouse_in_slot then slot_hovered_idx = i; mouse_in_any_slot = true end
    local slot_bg = mouse_in_slot and C.SLOT_HOVERED_BG or C.SLOT_FILLED_BG
    local slot_fg = mouse_in_slot and C.SLOT_ACTIVE or C.SLOT_FILLED
    DL_AddRectFilled(dl, sx, sy, sx2, sy2, slot_bg, 3)
    DL_AddRect(dl, sx, sy, sx2, sy2, slot_fg, 3, 0, 1)
    local label = (i == 10) and "0" or tostring(i)
    local tw_slot = reaper.ImGui_CalcTextSize(ctx, label)
    -- Текст білий
    DL_AddText(dl, sx + (SZ.SLOT_W - tw_slot) / 2, sy + 2, BUTTON_TEXT, label)
    if mouse_in_slot and reaper.ImGui_IsMouseClicked(ctx, 0) then
      if apply_slot(current_guid, i) then
        if snap_enabled then
          update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
        end
      end
    end
    if mouse_in_slot and reaper.ImGui_IsMouseClicked(ctx, 1) then remove_slot(current_guid, i) end
  end

  local can_add = #slots < MAX_SLOTS
  local add_x = slot_start_x + #slots * (SZ.SLOT_W + SZ.SLOT_GAP)
  local add_color = can_add and C.SLOT_ADD or C.LOCK_OFF
  local add_bg_color = can_add and C.SLOT_ADD_BG or C.LOCK_OFF_BG
  local mouse_in_add = mx >= add_x and mx <= add_x + SZ.ADD_BTN_W and my >= abs_btn_y and my <= abs_btn_y + SZ.SET_BTN_H
  if mouse_in_add and can_add then add_bg_color = C.LOOPLEN_BTN_BG_HOV end
  DL_AddRectFilled(dl, add_x, abs_btn_y, add_x + SZ.ADD_BTN_W, abs_btn_y + SZ.SET_BTN_H, add_bg_color, 3)
  DL_AddRect(dl, add_x, abs_btn_y, add_x + SZ.ADD_BTN_W, abs_btn_y + SZ.SET_BTN_H, add_color, 3, 0, 1)
  local tw_plus = reaper.ImGui_CalcTextSize(ctx, "+")
  -- Текст білий
  DL_AddText(dl, add_x + (SZ.ADD_BTN_W - tw_plus) / 2, abs_btn_y + 2, BUTTON_TEXT, "+")
  if mouse_in_add and reaper.ImGui_IsMouseClicked(ctx, 0) and can_add then
    add_slot(current_guid, start_offset, end_offset)
  end

  -- ===== RIGHT-ALIGNED BUTTON ROW =====
  local gear_x2 = wave_x_end
  local gear_x = gear_x2 - SZ.GEAR_BTN_W

  local lock_x2 = gear_x - SZ.SLOT_GAP
  local lock_x = lock_x2 - SZ.LOCK_BTN_W

  local zc_x2 = lock_x - SZ.SLOT_GAP
  local zc_x = zc_x2 - SZ.ZC_BTN_W

  local ts_x2 = zc_x - SZ.SLOT_GAP
  local ts_x = ts_x2 - SZ.TS_BTN_W

  local grid_arrow = " \xE2\x96\xBC"
  local grid_btn_text = grid_label .. grid_arrow
  local grid_btn_w = reaper.ImGui_CalcTextSize(ctx, grid_btn_text) + 14
  local grid_btn_x = ts_x - SZ.SLOT_GAP - grid_btn_w
  local grid_btn_y = abs_btn_y
  local grid_btn_x2 = grid_btn_x + grid_btn_w
  local grid_btn_y2 = grid_btn_y + SZ.SET_BTN_H
  local mouse_in_grid_btn = mx >= grid_btn_x and mx <= grid_btn_x2 and my >= grid_btn_y and my <= grid_btn_y2
  local grid_btn_fg = mouse_in_grid_btn and C.LOOPLEN_BTN_HOV or C.TS_BTN
  local grid_btn_bg = mouse_in_grid_btn and C.LOOPLEN_BTN_BG_HOV or C.TS_BTN_BG
  DL_AddRectFilled(dl, grid_btn_x, grid_btn_y, grid_btn_x2, grid_btn_y2, grid_btn_bg, 3)
  DL_AddRect(dl, grid_btn_x, grid_btn_y, grid_btn_x2, grid_btn_y2, grid_btn_fg, 3, 0, 1)
  local tw_grid = reaper.ImGui_CalcTextSize(ctx, grid_btn_text)
  -- Текст білий
  DL_AddText(dl, grid_btn_x + (grid_btn_w - tw_grid) / 2, grid_btn_y + 2, BUTTON_TEXT, grid_btn_text)
  if mouse_in_grid_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
    reaper.ImGui_OpenPopup(ctx, "grid_dropdown_menu")
    grid_popup_x = grid_btn_x
    grid_popup_y = grid_btn_y + SZ.SET_BTN_H + 2
  end

  local snap_x = grid_btn_x - SZ.SLOT_GAP - SZ.SNAP_BTN_W
  local snap_y = abs_btn_y
  local snap_x2 = snap_x + SZ.SNAP_BTN_W
  local snap_y2 = snap_y + SZ.SET_BTN_H
  local mouse_in_snap = mx >= snap_x and mx <= snap_x2 and my >= snap_y and my <= snap_y2
  local snap_fg, snap_bg
  if snap_enabled then
    snap_fg = mouse_in_snap and C.LOOPLEN_BTN_HOV or C.ZC_ON
    snap_bg = mouse_in_snap and C.LOOPLEN_BTN_BG_HOV or C.ZC_ON_BG
  else
    snap_fg = mouse_in_snap and C.LOOPLEN_BTN_HOV or C.LOCK_OFF
    snap_bg = mouse_in_snap and C.LOOPLEN_BTN_BG_HOV or C.LOCK_OFF_BG
  end
  DL_AddRectFilled(dl, snap_x, snap_y, snap_x2, snap_y2, snap_bg, 3)
  DL_AddRect(dl, snap_x, snap_y, snap_x2, snap_y2, snap_fg, 3, 0, 1)
  local tw_snap = reaper.ImGui_CalcTextSize(ctx, "Snap")
  -- Текст білий
  local snap_text = snap_enabled and BUTTON_TEXT or 0xA0A0A0FF
  DL_AddText(dl, snap_x + (SZ.SNAP_BTN_W - tw_snap) / 2, snap_y + 2, snap_text, "Snap")
  if mouse_in_snap and reaper.ImGui_IsMouseClicked(ctx, 0) then
    local turning_on = not snap_enabled
    snap_enabled = not snap_enabled
    save_snap_state()
    if turning_on and current_guid then
      local ref = grid_reference[current_guid]
      if ref then
        local rs = math_max(0, math_min(src_len, ref.s))
        local re = math_max(0, math_min(src_len, ref.e))
        if re > rs then
          set_take_loop_section(take, item, section_off, playrate, rs, re)
          reaper.Undo_OnStateChangeEx("Restore loop to grid reference", -1, -1)
        end
      else
        if resnap_item_to_grid(take, item, section_off, playrate, src_len, item_pos, grid_div) then
          update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
        end
      end
    end
  end

  -- Link button: Sync Selection was moved out of the settings menu.
  local link_x2 = snap_x - SZ.SLOT_GAP
  local link_x = link_x2 - SZ.LINK_BTN_W
  local link_y = abs_btn_y
  local link_y2 = link_y + SZ.SET_BTN_H
  local mouse_in_link = mx >= link_x and mx <= link_x2 and my >= link_y and my <= link_y2
  local link_fg, link_bg
  if sync_arrow_selection then
    link_fg = mouse_in_link and C.LOOPLEN_BTN_HOV or C.ZC_ON
    link_bg = mouse_in_link and C.LOOPLEN_BTN_BG_HOV or C.ZC_ON_BG
  else
    link_fg = mouse_in_link and C.LOOPLEN_BTN_HOV or C.LOCK_OFF
    link_bg = mouse_in_link and C.LOOPLEN_BTN_BG_HOV or C.LOCK_OFF_BG
  end
  DL_AddRectFilled(dl, link_x, link_y, link_x2, link_y2, link_bg, 3)
  DL_AddRect(dl, link_x, link_y, link_x2, link_y2, link_fg, 3, 0, 1)
  local tw_link = reaper.ImGui_CalcTextSize(ctx, "Link")
  local link_text = sync_arrow_selection and BUTTON_TEXT or 0xA0A0A0FF
  DL_AddText(dl, link_x + (SZ.LINK_BTN_W - tw_link) / 2, link_y + 2, link_text, "Link")
  if mouse_in_link and reaper.ImGui_IsMouseClicked(ctx, 0) then
    sync_arrow_selection = not sync_arrow_selection
    save_persistent_state()
  end

  local ts_y = abs_btn_y
  local ts_y2 = ts_y + SZ.SET_BTN_H
  local mouse_in_ts = mx >= ts_x and mx <= ts_x2 and my >= ts_y and my <= ts_y2
  local ts_fg = mouse_in_ts and C.LOOPLEN_BTN_HOV or C.TS_BTN
  local ts_bg = mouse_in_ts and C.LOOPLEN_BTN_BG_HOV or C.TS_BTN_BG
  DL_AddRectFilled(dl, ts_x, ts_y, ts_x2, ts_y2, ts_bg, 3)
  DL_AddRect(dl, ts_x, ts_y, ts_x2, ts_y2, ts_fg, 3, 0, 1)
  local ts_cy = ts_y + SZ.SET_BTN_H / 2
  DL_AddLine(dl, ts_x + 5, ts_cy - 4, ts_x + 5, ts_cy + 4, ts_fg, 1.5)
  DL_AddLine(dl, ts_x + 5, ts_cy - 4, ts_x + 8, ts_cy - 4, ts_fg, 1.5)
  DL_AddLine(dl, ts_x + 5, ts_cy + 4, ts_x + 8, ts_cy + 4, ts_fg, 1.5)
  DL_AddLine(dl, ts_x2 - 5, ts_cy - 4, ts_x2 - 5, ts_cy + 4, ts_fg, 1.5)
  DL_AddLine(dl, ts_x2 - 5, ts_cy - 4, ts_x2 - 8, ts_cy - 4, ts_fg, 1.5)
  DL_AddLine(dl, ts_x2 - 5, ts_cy + 4, ts_x2 - 8, ts_cy + 4, ts_fg, 1.5)
  if mouse_in_ts and reaper.ImGui_IsMouseClicked(ctx, 0) then set_time_selection_to_item() end

  local zc_y = abs_btn_y
  local zc_y2 = zc_y + SZ.SET_BTN_H
  local mouse_in_zc = mx >= zc_x and mx <= zc_x2 and my >= zc_y and my <= zc_y2
  local zc_fg, zc_bg
  if zero_cross_snap then
    zc_fg = mouse_in_zc and C.LOOPLEN_BTN_HOV or C.ZC_ON
    zc_bg = mouse_in_zc and C.LOOPLEN_BTN_BG_HOV or C.ZC_ON_BG
  else
    zc_fg = mouse_in_zc and C.LOOPLEN_BTN_HOV or C.LOCK_OFF
    zc_bg = mouse_in_zc and C.LOOPLEN_BTN_BG_HOV or C.LOCK_OFF_BG
  end
  DL_AddRectFilled(dl, zc_x, zc_y, zc_x2, zc_y2, zc_bg, 3)
  DL_AddRect(dl, zc_x, zc_y, zc_x2, zc_y2, zc_fg, 3, 0, 1)
  local tw_zc = reaper.ImGui_CalcTextSize(ctx, "ZC")
  local zc_text = zero_cross_snap and BUTTON_TEXT or 0xA0A0A0FF
  DL_AddText(dl, zc_x + (SZ.ZC_BTN_W - tw_zc) / 2, zc_y + 2, zc_text, "ZC")
  if mouse_in_zc and reaper.ImGui_IsMouseClicked(ctx, 0) then zero_cross_snap = not zero_cross_snap end

  local lock_y = abs_btn_y
  local lock_y2 = lock_y + SZ.SET_BTN_H
  local mouse_in_lock = mx >= lock_x and mx <= lock_x2 and my >= lock_y and my <= lock_y2
  local lock_fg, lock_bg
  if window_locked then
    lock_fg = mouse_in_lock and C.LOOPLEN_BTN_HOV or C.LOCK_ON
    lock_bg = mouse_in_lock and C.LOOPLEN_BTN_BG_HOV or C.LOCK_ON_BG
  else
    lock_fg = mouse_in_lock and C.LOOPLEN_BTN_HOV or C.LOCK_OFF
    lock_bg = mouse_in_lock and C.LOOPLEN_BTN_BG_HOV or C.LOCK_OFF_BG
  end
  DL_AddRectFilled(dl, lock_x, lock_y, lock_x2, lock_y2, lock_bg, 3)
  DL_AddRect(dl, lock_x, lock_y, lock_x2, lock_y2, lock_fg, 3, 0, 1)
  local lck_cx = lock_x + SZ.LOCK_BTN_W / 2
  local lck_cy = lock_y + SZ.SET_BTN_H / 2
  if window_locked then
    DL_AddRectFilled(dl, lck_cx - 4, lck_cy - 1, lck_cx + 4, lck_cy + 5, lock_fg, 1)
    DL_AddLine(dl, lck_cx - 3, lck_cy - 1, lck_cx - 3, lck_cy - 4, lock_fg, 2)
    DL_AddLine(dl, lck_cx - 3, lck_cy - 4, lck_cx + 3, lck_cy - 4, lock_fg, 2)
    DL_AddLine(dl, lck_cx + 3, lck_cy - 4, lck_cx + 3, lck_cy - 1, lock_fg, 2)
  else
    DL_AddRect(dl, lck_cx - 4, lck_cy - 1, lck_cx + 4, lck_cy + 5, lock_fg, 1, 0, 1)
    DL_AddLine(dl, lck_cx - 3, lck_cy - 1, lck_cx - 3, lck_cy - 4, lock_fg, 2)
    DL_AddLine(dl, lck_cx - 3, lck_cy - 4, lck_cx + 1, lck_cy - 4, lock_fg, 2)
    DL_AddLine(dl, lck_cx + 3, lck_cy - 1, lck_cx + 3, lck_cy - 3, lock_fg, 2)
  end
  if mouse_in_lock and reaper.ImGui_IsMouseClicked(ctx, 0) then
    window_locked = not window_locked
    if window_locked then
      locked_pos_x, locked_pos_y = reaper.ImGui_GetWindowPos(ctx)
      locked_size_w, locked_size_h = reaper.ImGui_GetWindowSize(ctx)
    end
  end

  local gear_y = abs_btn_y
  local gear_y2 = gear_y + SZ.SET_BTN_H
  local mouse_in_gear = mx >= gear_x and mx <= gear_x2 and my >= gear_y and my <= gear_y2
  local gear_fg = mouse_in_gear and C.GEAR_BTN_HOV or C.GEAR_BTN
  local gear_bg = mouse_in_gear and C.GEAR_BTN_BG_HOV or C.GEAR_BTN_BG
  DL_AddRectFilled(dl, gear_x, gear_y, gear_x2, gear_y2, gear_bg, 3)
  DL_AddRect(dl, gear_x, gear_y, gear_x2, gear_y2, gear_fg, 3, 0, 1)
  local gear_icon = "\xE2\x9A\x99"
  local tw_gear = reaper.ImGui_CalcTextSize(ctx, gear_icon)
  -- Текст (іконка) білий
  DL_AddText(dl, gear_x + (SZ.GEAR_BTN_W - tw_gear) / 2, gear_y + 1, BUTTON_TEXT, gear_icon)
  if mouse_in_gear and reaper.ImGui_IsMouseClicked(ctx, 0) then
    reaper.ImGui_OpenPopup(ctx, "settings_popup")
    settings_popup_x = gear_x2 - 160
    settings_popup_y = gear_y2 + 2
  end

  local loop_btn_label = "LOOP LENGTH \xE2\x96\xBC"
  local tw_loop_btn = reaper.ImGui_CalcTextSize(ctx, loop_btn_label)
  local loop_btn_w = tw_loop_btn + 14
  local loop_btn_h = SZ.SET_BTN_H

  local total_group_w = loop_btn_w + SZ.LOOP_BTN_GAP + SZ.X2_BTN_W + SZ.LOOP_BTN_GAP + SZ.DIV2_BTN_W
  local group_x = abs_wave_x + (wave_w - total_group_w) / 2

  local loop_btn_x = group_x
  local loop_btn_y = abs_btn_y
  local loop_btn_x2 = loop_btn_x + loop_btn_w
  local loop_btn_y2 = loop_btn_y + loop_btn_h

  local x2_btn_x = loop_btn_x2 + SZ.LOOP_BTN_GAP
  local x2_btn_y = loop_btn_y
  local x2_btn_x2 = x2_btn_x + SZ.X2_BTN_W
  local x2_btn_y2 = loop_btn_y2

  local div2_btn_x = x2_btn_x2 + SZ.LOOP_BTN_GAP
  local div2_btn_y = loop_btn_y
  local div2_btn_x2 = div2_btn_x + SZ.DIV2_BTN_W
  local div2_btn_y2 = loop_btn_y2

  local mouse_in_loop_len_btn = mx >= loop_btn_x and mx <= loop_btn_x2 and my >= loop_btn_y and my <= loop_btn_y2
  local mouse_in_x2_btn = mx >= x2_btn_x and mx <= x2_btn_x2 and my >= x2_btn_y and my <= x2_btn_y2
  local mouse_in_div2_btn = mx >= div2_btn_x and mx <= div2_btn_x2 and my >= div2_btn_y and my <= div2_btn_y2

  local llb_fg = mouse_in_loop_len_btn and C.LOOPLEN_BTN_HOV or C.LOOPLEN_BTN
  local llb_bg = mouse_in_loop_len_btn and C.LOOPLEN_BTN_BG_HOV or C.LOOPLEN_BTN_BG
  DL_AddRectFilled(dl, loop_btn_x, loop_btn_y, loop_btn_x2, loop_btn_y2, llb_bg, 3)
  DL_AddRect(dl, loop_btn_x, loop_btn_y, loop_btn_x2, loop_btn_y2, llb_fg, 3, 0, 1)
  -- Текст білий
  DL_AddText(dl, loop_btn_x + (loop_btn_w - tw_loop_btn) / 2, loop_btn_y + 2, BUTTON_TEXT, loop_btn_label)
  if mouse_in_loop_len_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
    reaper.ImGui_OpenPopup(ctx, "loop_length_popup")
    loop_len_popup_x = loop_btn_x
    loop_len_popup_y = loop_btn_y2 + 2
  end

  local x2_fg = mouse_in_x2_btn and C.LOOPLEN_BTN_HOV or C.LOOPLEN_BTN
  local x2_bg = mouse_in_x2_btn and C.LOOPLEN_BTN_BG_HOV or C.LOOPLEN_BTN_BG
  DL_AddRectFilled(dl, x2_btn_x, x2_btn_y, x2_btn_x2, x2_btn_y2, x2_bg, 3)
  DL_AddRect(dl, x2_btn_x, x2_btn_y, x2_btn_x2, x2_btn_y2, x2_fg, 3, 0, 1)
  local tw_x2 = reaper.ImGui_CalcTextSize(ctx, "X2")
  -- Текст білий
  DL_AddText(dl, x2_btn_x + (SZ.X2_BTN_W - tw_x2) / 2, x2_btn_y + 2, BUTTON_TEXT, "X2")
  if mouse_in_x2_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
    if scale_loop_length(2) then
      if snap_enabled then
        update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
      end
      if sync_arrow_selection then
        set_time_selection_to_item()
      end
    end
  end

  local div2_fg = mouse_in_div2_btn and C.LOOPLEN_BTN_HOV or C.LOOPLEN_BTN
  local div2_bg = mouse_in_div2_btn and C.LOOPLEN_BTN_BG_HOV or C.LOOPLEN_BTN_BG
  DL_AddRectFilled(dl, div2_btn_x, div2_btn_y, div2_btn_x2, div2_btn_y2, div2_bg, 3)
  DL_AddRect(dl, div2_btn_x, div2_btn_y, div2_btn_x2, div2_btn_y2, div2_fg, 3, 0, 1)
  local tw_div2 = reaper.ImGui_CalcTextSize(ctx, "/2")
  -- Текст білий
  DL_AddText(dl, div2_btn_x + (SZ.DIV2_BTN_W - tw_div2) / 2, div2_btn_y + 2, BUTTON_TEXT, "/2")
  if mouse_in_div2_btn and reaper.ImGui_IsMouseClicked(ctx, 0) then
    if scale_loop_length(0.5) then
      if snap_enabled then
        update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
      end
      if sync_arrow_selection then
        set_time_selection_to_item()
      end
    end
  end

  return mouse_in_btn, mouse_in_add, can_add, mouse_in_any_slot, slot_hovered_idx,
    mouse_in_grid_btn, mouse_in_snap, mouse_in_link, mouse_in_ts, mouse_in_zc, mouse_in_lock,
    mouse_in_loop_len_btn, mouse_in_x2_btn, mouse_in_div2_btn, mouse_in_gear
end

-- (решта функцій без змін: draw_ruler, draw_grid_popup, draw_settings_popup, draw_loop_length_popup, nudge_loop_region, handle_vertical_arrow_scale, loop)

local function draw_ruler(dl, mx, my, shift_held, abs_wave_x, abs_ruler_y, wave_x_end, wave_w,
                           src_len, view_start, view_end, view_len, item_pos, start_offset, playrate,
                           grid_project_start, grid_project_end, range_center)
  DL_AddRectFilled(dl, abs_wave_x, abs_ruler_y, wave_x_end, abs_ruler_y + SZ.RULER_H, C.SCROLLBAR_BG)
  DL_AddRect(dl, abs_wave_x, abs_ruler_y, wave_x_end, abs_ruler_y + SZ.RULER_H, C.SCROLLBAR_TRACK, 0, 0, 1)

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

  local mouse_in_ruler = mx >= abs_wave_x and mx <= wave_x_end and my >= abs_ruler_y and my <= abs_ruler_y + SZ.RULER_H
  local mouse_in_thumb = mx >= thumb_x1 and mx <= thumb_x2 and my >= abs_ruler_y and my <= abs_ruler_y + SZ.RULER_H

  local thumb_color = C.SCROLLBAR_THUMB
  if ruler_scroll_drag then thumb_color = C.SCROLLBAR_THUMB_ACT
  elseif mouse_in_thumb then thumb_color = C.SCROLLBAR_THUMB_HOV end

  DL_AddRectFilled(dl, abs_wave_x, abs_ruler_y + 2, wave_x_end, abs_ruler_y + SZ.RULER_H - 2, C.SCROLLBAR_TRACK, 3)
  DL_AddRectFilled(dl, thumb_x1, abs_ruler_y + 1, thumb_x2, abs_ruler_y + SZ.RULER_H - 1, thumb_color, 4)

  local cache = ruler_cache
  local cache_hit = cache.view_start == view_start
    and cache.view_end == view_end
    and cache.wave_x == abs_wave_x
    and cache.wave_w == wave_w
    and cache.ruler_y == abs_ruler_y
    and cache.src_len == src_len
    and cache.item_pos == item_pos
    and cache.start_offset == start_offset
    and cache.playrate == playrate
    and cache.grid_project_start == grid_project_start
    and cache.grid_project_end == grid_project_end
    and cache.ruler_tick_color == C.RULER_TICK
    and cache.ruler_text_color == C.RULER_TEXT

  local wave_labels
  local ruler_ticks
  if cache_hit then
    wave_labels = cache.labels
    ruler_ticks = cache.ticks
  else
    wave_labels = {}
    ruler_ticks = {}
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
  local px_per_time_local = wave_w / view_len
  local function t2px_local(t) return abs_wave_x + (t - view_start) * px_per_time_local end
  while ruler_iter < 1000 do
    ruler_iter = ruler_iter + 1
    local bar_project_time = reaper.TimeMap2_beatsToTime(0, 0, ruler_bar)
    if bar_project_time > grid_project_end then break end
    local bar_source_time = project_to_source_time(bar_project_time, item_pos, start_offset, playrate)
    if bar_source_time >= view_start and bar_source_time <= view_end then
      local bar_px = t2px_local(bar_source_time)
      local is_label_bar = (ruler_bar % label_skip == 0)
      if is_label_bar then
        add_ruler_tick(bar_px, abs_ruler_y, bar_px, abs_ruler_y + SZ.RULER_H, C.RULER_TICK, 1)
        wave_labels[#wave_labels + 1] = {px = bar_px, text = tostring(ruler_bar + 1), color = C.RULER_TEXT}
      elseif show_inter_ticks then
        add_ruler_tick(bar_px, abs_ruler_y, bar_px, abs_ruler_y + SZ.RULER_H, C.RULER_TICK, 1)
        if show_inter_labels then
          wave_labels[#wave_labels + 1] = {px = bar_px, text = tostring(ruler_bar + 1), color = C.RULER_TEXT}
        end
      end
    end

    if show_beat_ticks then
      for beat = 1, beats_per_bar - 1 do
        local beat_project_time = reaper.TimeMap2_beatsToTime(0, beat, ruler_bar)
        if beat_project_time > grid_project_end then break end
        local beat_source_time = project_to_source_time(beat_project_time, item_pos, start_offset, playrate)
        if beat_source_time >= view_start and beat_source_time <= view_end then
          local beat_px = t2px_local(beat_source_time)
          local tick_top = abs_ruler_y + SZ.RULER_H - math_floor(SZ.RULER_H * 0.5)
          add_ruler_tick(beat_px, tick_top, beat_px, abs_ruler_y + SZ.RULER_H, C.RULER_TICK, 1)
          if show_beat_labels then
            wave_labels[#wave_labels + 1] = {px = beat_px, text = (ruler_bar + 1) .. "." .. (beat + 1), color = C.RULER_TEXT}
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
          local sub_source_time = project_to_source_time(sub_project_time, item_pos, start_offset, playrate)
          if sub_source_time >= view_start and sub_source_time <= view_end then
            local sub_px = t2px_local(sub_source_time)
            if show_sub_ticks then
              local tick_h = math_floor(SZ.RULER_H * 0.3)
              add_ruler_tick(sub_px, abs_ruler_y + SZ.RULER_H - tick_h, sub_px, abs_ruler_y + SZ.RULER_H, C.RULER_TICK, 1)
            end
            if show_sub_labels then
              wave_labels[#wave_labels + 1] = {px = sub_px, text = (ruler_bar + 1) .. "." .. (beat + 1) .. "." .. (q + 1), color = C.RULER_TEXT}
            end
          end
        end
      end
    end

    ruler_bar = ruler_bar + tick_skip
  end

  ruler_cache = {
    view_start = view_start, view_end = view_end,
    wave_x = abs_wave_x, wave_w = wave_w, ruler_y = abs_ruler_y,
    src_len = src_len, item_pos = item_pos, start_offset = start_offset,
    playrate = playrate, grid_project_start = grid_project_start,
    grid_project_end = grid_project_end,
    ruler_tick_color = C.RULER_TICK, ruler_text_color = C.RULER_TEXT,
    labels = wave_labels, ticks = ruler_ticks,
  }
  end

  for i = 1, #ruler_ticks do
    local tick = ruler_ticks[i]
    DL_AddLine(dl, tick[1], tick[2], tick[3], tick[4], tick[5], tick[6])
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

  return wave_labels, mouse_in_ruler, mouse_in_thumb
end

-- ===== POPUP FUNCTIONS (без змін, але переконайтесь, що вони використовують правильні кольори) =====

local function draw_grid_popup()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 6)
  if grid_popup_x then
    reaper.ImGui_SetNextWindowPos(ctx, grid_popup_x, grid_popup_y)
    grid_popup_x = nil
  end
  if reaper.ImGui_BeginPopup(ctx, "grid_dropdown_menu") then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), C.RULER_TEXT)
    reaper.ImGui_Text(ctx, "  Grid")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_Separator(ctx)

    local SEL_COL = C.SET_BTN
    local opts = GRID_FIXED_OPTIONS
    local rows = {
      {opts[1], opts[2], opts[3]},
      {opts[4], opts[5], opts[6]},
    }
    for _, row in ipairs(rows) do
      for ri, opt in ipairs(row) do
        if ri > 1 then reaper.ImGui_SameLine(ctx) end
        local is_sel = grid_settings.fixed == opt.id
        local tc = is_sel and SEL_COL or theme.Text
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), tc)
        if reaper.ImGui_Selectable(ctx, "  " .. opt.label, false,
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
end

local function draw_settings_popup()
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
    reaper.ImGui_TextColored(ctx, C.MARKER, "\xE2\x9C\xA6 Made by Andrew Dihtaryk")
    if reaper.ImGui_MenuItem(ctx, "\xE2\x9C\xA6 Support Ko-Fi") then
      reaper.CF_ShellExecute("https://ko-fi.com/pianohousestudio/shop")
    end

    reaper.ImGui_EndPopup(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx)
end

local function draw_loop_length_popup(current_guid, take, item, section_off, playrate, src_len)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 8, 6)
  if loop_len_popup_x then
    reaper.ImGui_SetNextWindowPos(ctx, loop_len_popup_x, loop_len_popup_y)
    loop_len_popup_x = nil
  end
  if reaper.ImGui_BeginPopup(ctx, "loop_length_popup") then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), C.RULER_TEXT)
    reaper.ImGui_Text(ctx, "  Loop Length")
    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_Separator(ctx)

    local opts = LOOP_LENGTH_OPTIONS
    local rows = {
      {opts[1], opts[2], opts[3]},
      {opts[4], opts[5], opts[6]},
    }
    for _, row in ipairs(rows) do
      for ri, opt in ipairs(row) do
        if ri > 1 then reaper.ImGui_SameLine(ctx) end
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.Text)
        if reaper.ImGui_Selectable(ctx, "  " .. opt.label, false,
            reaper.ImGui_SelectableFlags_None(), 55, 0) then
          if set_loop_length(opt.qn) then
            update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
          end
        end
        reaper.ImGui_PopStyleColor(ctx)
      end
    end

    reaper.ImGui_EndPopup(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx)
end

-- ===== NUDGE & ARROW HANDLING (без змін) =====

local function nudge_loop_region(direction, shift_held, take, item, section_off, playrate,
                                  src_len, item_pos, start_offset, end_offset, grid_div,
                                  current_guid, snap_marker_time)
  local region_len = end_offset - start_offset
  if region_len <= 0 then return end

  local nudge_step
  if snap_enabled and grid_div and grid_div > 0 then
    local base_qn = reaper.TimeMap2_timeToQN(0, item_pos)
    local next_proj = reaper.TimeMap2_QNToTime(0, base_qn + grid_div)
    local next_source = project_to_source_time(next_proj, item_pos, start_offset, playrate)
    nudge_step = next_source - start_offset
    if not nudge_step or nudge_step <= 0 then nudge_step = region_len * 0.05 end
  else
    nudge_step = region_len * 0.05
  end
  if shift_held then nudge_step = nudge_step / FINE_MODE_DIVISOR end

  local new_s = math_max(0, math_min(src_len - region_len, start_offset + direction * nudge_step))
  if snap_enabled then
    new_s = snap_marker_time(new_s)
    new_s = math_max(0, math_min(src_len - region_len, new_s))
  elseif zero_cross_snap then
    new_s = snap_region(new_s, region_len, src_len)
  end
  local new_e = new_s + region_len

  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_s - section_off)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", region_len / playrate)
  reaper.UpdateArrange()
  reaper.Undo_OnStateChangeEx("Nudge loop position", -1, -1)
  if snap_enabled then
    update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
  end
end

local function handle_vertical_arrow_scale(current_guid, take, item, section_off, playrate, src_len)
  local up_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow(), true)
  local down_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow(), true)
  if not up_pressed and not down_pressed then return end
  local factor = up_pressed and 2 or 0.5
  if scale_loop_length(factor) then
    if snap_enabled then
      update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
    end
    if sync_arrow_selection then
      set_time_selection_to_item()
    end
  end
end

-- ===== MAIN LOOP (решта без змін) =====

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
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), SZ.WIN_PAD, SZ.WIN_PAD)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 3)
  applyTheme()

  local visible
  visible, open = reaper.ImGui_Begin(ctx, "FSR SlipX", true, flags)

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
    current_item_pos = item_pos

    local start_offset = math_max(0, section_off + take_off)
    local end_offset = math_min(src_len, start_offset + item_len * playrate)

    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local wave_w = math_max(100, avail_w - SZ.PADDING * 2)
    local fixed_h = SZ.SET_BTN_H + 2 + SZ.RULER_H + 2 + SZ.SLOT_ZONE_H + SZ.LOOPBAR_H
    local wave_h = math_max(60, avail_h - fixed_h)

    local cur_x, cur_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local abs_wave_x = cur_x + SZ.PADDING - SZ.WIN_PAD
    local abs_btn_y = cur_y - SZ.WIN_PAD
    local abs_ruler_y = abs_btn_y + SZ.SET_BTN_H + 2
    local abs_wave_y = abs_ruler_y + SZ.RULER_H + 2
    local abs_slot_zone_y = abs_wave_y + wave_h
    local abs_loopbar_y = abs_slot_zone_y + SZ.SLOT_ZONE_H

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

    local grid_project_start = source_to_project_time(view_start, item_pos, start_offset, playrate)
    local grid_project_end = source_to_project_time(view_start + view_len, item_pos, start_offset, playrate)
    local grid_view_start_qn, grid_view_end_qn
    if grid_cache.project_start == grid_project_start
      and grid_cache.project_end == grid_project_end
      and grid_cache.start_qn ~= nil and grid_cache.end_qn ~= nil then
      grid_view_start_qn = grid_cache.start_qn
      grid_view_end_qn = grid_cache.end_qn
    else
      grid_view_start_qn = reaper.TimeMap2_timeToQN(0, grid_project_start)
      grid_view_end_qn = reaper.TimeMap2_timeToQN(0, grid_project_end)
    end
    local grid_view_length_qn = grid_view_end_qn - grid_view_start_qn
    local grid_division_qn = get_effective_grid_qn()
    local grid_div = grid_division_qn
    local grid_label = qn_to_grid_label(grid_division_qn)

    local function snap_marker_time(t)
      if snap_enabled then
        if grid_div > 0 then
          local proj_t = source_to_project_time(t, item_pos, start_offset, playrate)
          local qn = reaper.TimeMap2_timeToQN(0, proj_t)
          local snapped_qn = math_floor(qn / grid_div + 0.5) * grid_div
          local snapped_proj = reaper.TimeMap2_QNToTime(0, snapped_qn)
          return project_to_source_time(snapped_proj, item_pos, start_offset, playrate)
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

    -- ===== TOP BAR (extracted) =====
    local mouse_in_btn, mouse_in_add, can_add, mouse_in_any_slot, slot_hovered_idx,
      mouse_in_grid_btn, mouse_in_snap, mouse_in_link, mouse_in_ts, mouse_in_zc, mouse_in_lock,
      mouse_in_loop_len_btn, mouse_in_x2_btn, mouse_in_div2_btn, mouse_in_gear =
      draw_top_bar(dl, mx, my, abs_wave_x, abs_btn_y, wave_w, wave_x_end,
                   current_guid, take, item, section_off, playrate, src_len, item_pos,
                   slots, start_offset, end_offset, grid_div, grid_label)

    if is_focused then
      for i = 1, 10 do
        if reaper.ImGui_IsKeyPressed(ctx, slot_keys[i], false) and not ctrl_held then
          if i <= #slots then
            if apply_slot(current_guid, i) then
              if snap_enabled then
                update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
              end
            end
          end
        end
      end

      local left_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow(), true)
      local right_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow(), true)
      if left_pressed or right_pressed then
        local direction = right_pressed and 1 or -1
        nudge_loop_region(direction, shift_held, take, item, section_off, playrate,
                           src_len, item_pos, start_offset, end_offset, grid_div,
                           current_guid, snap_marker_time)
      end

      handle_vertical_arrow_scale(current_guid, take, item, section_off, playrate, src_len)
    end

    draw_grid_popup()
    draw_settings_popup()

    local wave_labels, mouse_in_ruler, mouse_in_thumb = draw_ruler(
      dl, mx, my, shift_held, abs_wave_x, abs_ruler_y, wave_x_end, wave_w,
      src_len, view_start, view_end, view_len, item_pos, start_offset, playrate,
      grid_project_start, grid_project_end, range_center)

    -- ===== WAVEFORM AREA =====
    DL_AddRectFilled(dl, abs_wave_x, abs_wave_y, wave_x_end, wave_y_end, C.BG)

    local grid_key_hit = grid_cache.view_start == view_start
      and grid_cache.view_len == view_len
      and grid_cache.wave_x == abs_wave_x
      and grid_cache.wave_w == wave_w
      and grid_cache.wave_y == abs_wave_y
      and grid_cache.wave_y_end == wave_y_end
      and grid_cache.item_pos == item_pos
      and grid_cache.start_offset == start_offset
      and grid_cache.playrate == playrate
      and grid_cache.project_start == grid_project_start
      and grid_cache.project_end == grid_project_end
      and grid_cache.grid_div == grid_div
      and grid_cache.grid_color == C.GRID_LINE

    local grid_lines
    if grid_key_hit then
      grid_lines = grid_cache.lines
    else
      grid_lines = {}
      if grid_view_length_qn > 0 and grid_div > 0 then
        local px_per_qn = wave_w / grid_view_length_qn
        local spacing_px = grid_div * px_per_qn
        if spacing_px >= 1 then
          local first_qn = math_ceil(grid_view_start_qn / grid_div) * grid_div
          if first_qn - grid_div >= grid_view_start_qn then first_qn = first_qn - grid_div end
          for qn = first_qn, grid_view_end_qn, grid_div do
            local proj_t = reaper.TimeMap2_QNToTime(0, qn)
            local src_t = project_to_source_time(proj_t, item_pos, start_offset, playrate)
            local px = t2px(src_t)
            if px >= abs_wave_x and px <= wave_x_end then
              grid_lines[#grid_lines + 1] = px
            end
          end
        end
      end
      grid_cache = {
        view_start = view_start, view_len = view_len,
        wave_x = abs_wave_x, wave_w = wave_w,
        wave_y = abs_wave_y, wave_y_end = wave_y_end,
        item_pos = item_pos, start_offset = start_offset,
        playrate = playrate, project_start = grid_project_start,
        project_end = grid_project_end, grid_div = grid_div,
        start_qn = grid_view_start_qn, end_qn = grid_view_end_qn,
        grid_color = C.GRID_LINE, lines = grid_lines,
      }
    end

    for i = 1, #grid_lines do
      local px = grid_lines[i]
      DL_AddLine(dl, px, abs_wave_y, px, wave_y_end, C.GRID_LINE, 1)
    end

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

    local r_left = math_max(abs_wave_x, sm_px)
    local r_right = math_min(wave_x_end, em_px)
    if r_right > r_left then
      DL_AddRectFilled(dl, r_left, abs_wave_y, r_right, wave_y_end, C.REGION)
    end

    if sm_px > abs_wave_x then
      DL_AddRectFilled(dl, abs_wave_x, abs_wave_y, math_min(sm_px, wave_x_end), wave_y_end, C.UNUSED)
    end
    if em_px < wave_x_end then
      DL_AddRectFilled(dl, math_max(em_px, abs_wave_x), abs_wave_y, wave_x_end, wave_y_end, C.UNUSED)
    end

    local sel_left_px, sel_right_px = 0, 0
    if has_valid_selection() then
      local sel_s = math_min(selection_start, selection_end)
      local sel_e = math_max(selection_start, selection_end)
      sel_left_px = math_max(abs_wave_x, t2px(sel_s))
      sel_right_px = math_min(wave_x_end, t2px(sel_e))
      if sel_right_px > sel_left_px then
        DL_AddRectFilled(dl, sel_left_px, abs_wave_y, sel_right_px, wave_y_end, C.SELECTION)
        DL_AddRect(dl, sel_left_px, abs_wave_y, sel_right_px, wave_y_end, C.SELECTION_BORDER, 0, 0, 2)
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
          DL_AddRectFilled(dl, z_left, abs_slot_zone_y + 1, z_right, abs_slot_zone_y + SZ.SLOT_ZONE_H - 1, C.SLOT_ZONE, 1)
          if s_px >= abs_wave_x and s_px <= wave_x_end then
            DL_AddLine(dl, s_px, abs_slot_zone_y, s_px, abs_slot_zone_y + SZ.SLOT_ZONE_H, C.SLOT_ZONE_LINE, 1)
          end
          if e_px >= abs_wave_x and e_px <= wave_x_end then
            DL_AddLine(dl, e_px, abs_slot_zone_y, e_px, abs_slot_zone_y + SZ.SLOT_ZONE_H, C.SLOT_ZONE_LINE, 1)
          end
          local lbl = (i == 10) and "0" or tostring(i)
          DL_AddTextEx(dl, font_slot, 16, z_left + 3, wave_y_end - 22, C.SLOT_ZONE_TEXT, lbl)
        end
      end
    end
    DL_AddRect(dl, abs_wave_x, abs_slot_zone_y, wave_x_end, abs_slot_zone_y + SZ.SLOT_ZONE_H, C.SCROLLBAR_TRACK, 0, 0, 1)

    local lb_x1 = math_max(abs_wave_x, sm_px)
    local lb_x2 = math_min(wave_x_end, em_px)
    if lb_x2 > lb_x1 then
      DL_AddRectFilled(dl, lb_x1, abs_loopbar_y, lb_x2, abs_loopbar_y + SZ.LOOPBAR_H, C.LOOPBAR_FILL, 3)
      DL_AddRect(dl, lb_x1, abs_loopbar_y, lb_x2, abs_loopbar_y + SZ.LOOPBAR_H, C.MARKER, 3, 0, 2)
    end

    draw_loop_length_popup(current_guid, take, item, section_off, playrate, src_len)

    local near_start = math_abs(mx - sm_px) <= SZ.MARKER_W and my >= abs_wave_y and my <= wave_y_end
    local near_end = math_abs(mx - em_px) <= SZ.MARKER_W and my >= abs_wave_y and my <= wave_y_end
    local mouse_in_wave = mx >= abs_wave_x and mx <= wave_x_end and my >= abs_wave_y and my <= wave_y_end
    local mouse_in_loopbar = (mx >= lb_x1 and mx <= lb_x2 and my >= abs_loopbar_y and my <= abs_loopbar_y + SZ.LOOPBAR_H)
    local mouse_in_selection = has_valid_selection() and mx >= sel_left_px and mx <= sel_right_px and my >= abs_wave_y and my <= wave_y_end

    if reaper.ImGui_IsMouseClicked(ctx, 1) and mouse_in_selection then
      if apply_selection() then
        if snap_enabled then
          update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
        end
      end
    end

    if reaper.ImGui_IsMouseClicked(ctx, 0) and not mouse_in_btn and not mouse_in_add
      and not mouse_in_loopbar and not mouse_in_ruler and not mouse_in_any_slot
      and not mouse_in_lock and not mouse_in_zc and not mouse_in_ts and not mouse_in_grid_btn
      and not mouse_in_snap and not mouse_in_loop_len_btn and not mouse_in_x2_btn and not mouse_in_div2_btn
      and not mouse_in_gear then
      if mouse_in_wave then
        if near_start and not near_end then
          drag_mode = "start"; drag_activated = false
          drag_start_mx, drag_start_s, drag_start_e = mx, start_offset, end_offset
        elseif near_end then
          drag_mode = "end"; drag_activated = false
          drag_start_mx, drag_start_s, drag_start_e = mx, start_offset, end_offset
        else
          is_selecting = true
          local t = px2t(mx)
          t = snap_marker_time(t)
          selection_start = math_max(0, math_min(src_len, t))
          selection_end = selection_start
        end
      end
    end

    if is_selecting then
      if reaper.ImGui_IsMouseDown(ctx, 0) then
        local clamped_mx = math_max(abs_wave_x - EDGE_SCROLL_MARGIN, math_min(wave_x_end + EDGE_SCROLL_MARGIN, mx))
        local raw_end = math_max(0, math_min(src_len, px2t(clamped_mx)))
        selection_end = snap_marker_time(raw_end)
        do_edge_scroll(mx, "auto")
        local new_view_len_s = src_len / zoom
        local new_view_center_s = range_center + pan_offset
        local new_view_start_s = new_view_center_s - new_view_len_s / 2
        if new_view_start_s < 0 then new_view_start_s = 0 end
        if new_view_start_s + new_view_len_s > src_len then new_view_start_s = src_len - new_view_len_s end
        if mx <= abs_wave_x then
          selection_end = snap_marker_time(math_max(0, new_view_start_s))
        elseif mx >= wave_x_end then
          selection_end = snap_marker_time(math_min(src_len, new_view_start_s + new_view_len_s))
        end
      else
        is_selecting = false
        if selection_start and selection_end and math_abs(selection_end - selection_start) < 0.001 then
          selection_start = nil; selection_end = nil
        end
      end
    end

    if drag_mode and reaper.ImGui_IsMouseDown(ctx, 0) then
      if not drag_activated and math_abs(mx - drag_start_mx) >= DRAG_THRESH then drag_activated = true end
      if drag_activated then
        local raw_delta_px = mx - drag_start_mx
        local eff = shift_held and (raw_delta_px / FINE_MODE_DIVISOR) or raw_delta_px
        local delta_t = (eff / wave_w) * view_len
        if drag_mode == "start" then
          local new_s = math_max(0, math_min(drag_start_e - 0.001, drag_start_s + delta_t))
          new_s = snap_marker_time(new_s)
          new_s = math_max(0, math_min(drag_start_e - 0.001, new_s))
          reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_s - section_off)
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", (drag_start_e - new_s) / playrate)
          do_edge_scroll(mx, "auto")
        elseif drag_mode == "end" then
          local new_e = math_max(drag_start_s + 0.001, math_min(src_len, drag_start_e + delta_t))
          new_e = snap_marker_time(new_e)
          new_e = math_max(drag_start_s + 0.001, math_min(src_len, new_e))
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", (new_e - drag_start_s) / playrate)
          do_edge_scroll(mx, "auto")
        end
        throttled_update_arrange()
      end
    end

    if reaper.ImGui_IsMouseReleased(ctx, 0) and drag_mode then
      if drag_activated then
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Adjust marker", -1, -1)
        if snap_enabled then
          update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
        end
      end
      drag_mode, drag_activated = nil, false
    end

    if reaper.ImGui_IsMouseClicked(ctx, 0) and mouse_in_loopbar then
      loopbar_drag = true
      loopbar_drag_start_mx, loopbar_drag_start_s, loopbar_drag_start_e = mx, start_offset, end_offset
      loopbar_last_written_start = nil
    end
    if loopbar_drag then
      if reaper.ImGui_IsMouseDown(ctx, 0) then
        local raw_delta_px = mx - loopbar_drag_start_mx
        local eff = shift_held and (raw_delta_px / FINE_MODE_DIVISOR) or raw_delta_px
        local delta_t = (eff / wave_w) * view_len
        local region_len = loopbar_drag_start_e - loopbar_drag_start_s
        local new_s = math_max(0, math_min(src_len - region_len, loopbar_drag_start_s + delta_t))
        new_s = snap_region_local(new_s, region_len)
        local new_e = new_s + region_len
        local moved_since_write = not loopbar_last_written_start
          or math_abs(new_s - loopbar_last_written_start) > 0.00001
        if moved_since_write then
          reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", new_s - section_off)
          reaper.SetMediaItemInfo_Value(item, "D_LENGTH", region_len / playrate)
          loopbar_last_written_start = new_s
          throttled_update_arrange()
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
        reaper.UpdateArrange()
        reaper.Undo_OnStateChangeEx("Move item region", -1, -1)
        if snap_enabled then
          update_grid_reference(current_guid, take, item, section_off, playrate, src_len)
        end
        loopbar_last_written_start = nil
      end
    end

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

    if mouse_in_loop_len_btn or mouse_in_x2_btn or mouse_in_div2_btn then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    elseif loopbar_drag or mouse_in_loopbar then
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
    elseif slot_hovered_idx or mouse_in_lock or mouse_in_zc or mouse_in_ts or mouse_in_grid_btn or mouse_in_snap or mouse_in_link or mouse_in_gear then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    elseif mouse_in_add and can_add then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_Hand())
    end

    local function draw_marker(px, is_start, hovered, dragging)
      if px < abs_wave_x - SZ.MARKER_W or px > wave_x_end + SZ.MARKER_W then return end
      local col = (hovered or dragging) and C.MARKER_HOV or C.MARKER
      DL_AddLine(dl, px, abs_wave_y, px, wave_y_end, col, 2)
      local tri_dir = is_start and 1 or -1
      DL_AddTriangleFilled(dl, px, abs_wave_y, px + SZ.MARKER_W * 1.5 * tri_dir, abs_wave_y, px, abs_wave_y + SZ.MARKER_W * 1.5, col)
      if zero_cross_snap and (hovered or dragging) then
        DL_AddCircleFilled(dl, px, abs_wave_y + SZ.MARKER_W * 1.5 + 6, 3, C.ZC_ON)
      end
    end

    draw_marker(sm_px, true, near_start, drag_mode == "start" and drag_activated)
    draw_marker(em_px, false, near_end, drag_mode == "end" and drag_activated)

    local play_state = reaper.GetPlayState()
    if play_state & 1 ~= 0 then
      local src_pp = (reaper.GetPlayPosition() - item_pos) * playrate + start_offset
      local ph_px = t2px(src_pp)
      if ph_px >= abs_wave_x and ph_px <= wave_x_end then
        DL_AddLine(dl, ph_px, abs_wave_y, ph_px, wave_y_end, C.PLAYHEAD, 2)
      end
    end

    DL_AddRect(dl, abs_wave_x, abs_wave_y, wave_x_end, wave_y_end, C.SCROLLBAR_TRACK, 0, 0, 1)

    -- Keep Link synchronized after all marker/loop edits from this frame.
    maintain_link_mode(item)

    reaper.ImGui_End(ctx)
  end

  popTheme()
  reaper.ImGui_PopStyleVar(ctx, 5)
  reaper.ImGui_PopFont(ctx)
  check_and_save_state()
  if open then reaper.defer(loop) end
end

reaper.defer(loop)

