--[[
-------------------------------------------------------------------------------------------
*              FSR Tooltips
* Section      Main
* Author:      Andrew Dihtaryk(FSR)
* Version:     1.0.0
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:    http://reaper-script-feedback.forsemusic1996.workers.dev/
    
--]]
local reaper = reaper
package.path = package.path .. ";" .. reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")

local math_max = math.max
local math_min = math.min
local str_format = string.format
local tbl_concat = table.concat
local io_open = io.open

local ctx = reaper.ImGui_CreateContext("FX Notes")

-- -- ТЕМА
local theme = {
  WindowBg = 0x1E1E1EFF,
  Text = 0xE0E0E0FF,
  TextDisabled = 0x808080FF,
  FrameBg = 0x333333FF,
  FrameBgHovered = 0x444444FF,
  FrameBgActive = 0x555555FF,
  TitleBg = 0x1A1A1AFF,
  TitleBgActive = 0x2D2D2DFF,
  Button = 0x404040FF,
  ButtonHovered = 0x505050FF,
  ButtonActive = 0x606060FF,
  CheckMark = 0x00AAFFFF,
  ScrollbarBg = 0x1A1A1AFF,
  ScrollbarGrab = 0x404040FF,
  ScrollbarGrabHovered = 0x505050FF,
  ScrollbarGrabActive = 0x606060FF,
  Header = 0x3D3D3DFF,
  HeaderHovered = 0x4D4D4DFF,
  HeaderActive = 0x5D5D5DFF,
  Separator = 0x505050FF,
  PopupBg = 0x252525FF,
  MenuBarBg = 0x2A2A2AFF,
  Border = 0x505050FF,
  ChildBg = 0x1A1A1AFF,
  ResizeLine = 0x00AAFF88,
  ParamNameColor = 0x00AAFFFF,
}
local THEME_COLOR_COUNT = 24

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
end

local function popTheme()
  reaper.ImGui_PopStyleColor(ctx, THEME_COLOR_COUNT)
end

-- -- ШЛЯХИ
local resource_path = reaper.GetResourcePath():gsub("\\", "/")
local data_folder = resource_path .. "/Data/FXNotes"
local param_notes_filename = data_folder .. "/fx_param_notes_binding_data.txt"
local settings_filename = data_folder .. "/fx_notes_settings.txt"

-- -- СТАН
local param_notes = {}
local last_track = nil
local last_index = nil
local current_fx_name = ""
local needs_save = false
local save_timer = 0
local SAVE_DELAY = 30
local should_exit = false
local mode = "view"
local current_param_index = -1
local current_param_name = ""
local current_param_note = ""
local current_param_height = nil
local save_target_fx_name = ""
local save_target_param_index = -1
local current_pages = {}
local current_page_index = 1
local edit_refresh_token = 0
local last_touched_param = -1
local last_param_value_track = nil
local last_param_value_fx = -1
local last_param_value_param = -1
local last_param_value = nil

local note_height = 250
local min_height = 30
local max_height = 600
local page_nav_height = 18
local is_resizing = false
local resize_zone = 8
local base_height = 250
-- The height used for parameters that have no individually saved size.
-- It must not change just because another parameter was resized.
local default_height = nil

local font_family = "sans-serif"
local font_size = 14
local current_font = nil
local font_families = {
  "sans-serif", "serif", "monospace",
  "Arial", "Courier New", "Times New Roman", "Verdana", "Calibri", "Georgia",
}

local FLAGS_WINDOW
local topmost_cache = false
local topmost_cache_frame = -999
local TOPMOST_INTERVAL = 10
local frame_counter = 0

local wrap_cache_text = nil
local wrap_cache_width = nil
local wrap_cache_result = ""
local view_lines_cache_text = nil
local view_lines_cache = {}

-- Full project FX scans are expensive on large sessions. Keep the latest
-- result briefly, while focused FX detection remains immediate.
local FLOATING_FX_SCAN_INTERVAL = 0.10
local next_floating_fx_scan_at = 0
local cached_floating_fx_found = false
local cached_floating_fx_track = nil
local cached_floating_fx_index = nil

local function is_separator_line(line)
  local hyphens = line:match("^%s*(%-+)%s*$")
  return hyphens ~= nil and #hyphens >= 3
end

local function get_view_lines(text)
  if view_lines_cache_text ~= text then
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      lines[#lines + 1] = line
    end
    view_lines_cache_text = text
    view_lines_cache = lines
  end
  return view_lines_cache
end

local function count_lines(text)
  if not text or text == "" then return 1 end
  local lines = 1
  for _ in text:gmatch("\n") do
    lines = lines + 1
  end
  return lines
end

local function normalize_newlines(text)
  if not text then return "" end
  return text
    :gsub("\r\n", "\n")
    :gsub("\r", "\n")
    :gsub("\226\128\168", "\n")
    :gsub("\226\128\169", "\n")
end

local function calc_desired_note_height_for_text(text)
  text = normalize_newlines(text or "")
  local line_h = 18
  if type(reaper.ImGui_GetTextLineHeightWithSpacing) == "function" then
    local ok, h = pcall(reaper.ImGui_GetTextLineHeightWithSpacing, ctx)
    if ok and type(h) == "number" and h > 0 then line_h = h end
  end
  local header_h = (current_param_name ~= "") and 52 or 24
  local page_nav_h = (mode == "view" and #current_pages > 1) and page_nav_height or 0
  local desired = math.floor(header_h + page_nav_h + (count_lines(text) * line_h) + resize_zone + 12)
  return math.floor(math_max(min_height, math_min(max_height, desired)))
end

local function auto_resize_note_height_for_text(text)
  local desired = calc_desired_note_height_for_text(text)
  note_height = math.floor(math_max(min_height, math_min(max_height, desired)))
  base_height = note_height
end

local function ensure_saved_height_fits_text(text, keep_exact_saved_height)
  if keep_exact_saved_height then return end
  -- BUGFIX: this auto-grow-to-fit-text safety net must never engage for a
  -- parameter that has no note text. Previously it ran unconditionally and,
  -- whenever the live default_height (from the right-click menu) was smaller
  -- than the "minimum size to show N lines" heuristic, it silently grew
  -- note_height past the default AND wrote that grown value into
  -- current_param_height / current_pages[idx].height. That made an empty
  -- parameter look "stuck" at a stale/derived height instead of following
  -- the default_height you just picked from the menu, and could even persist
  -- to disk on the next background save. An empty note has nothing to fit,
  -- so just leave the live default_height alone.
  if not text or text == "" then return end
  local desired = calc_desired_note_height_for_text(text)
  if note_height >= desired then return end

  note_height = desired
  base_height = desired
  current_param_height = desired

  if type(current_pages) == "table" and #current_pages > 0 then
    local idx = math.floor(tonumber(current_page_index) or 1)
    if idx < 1 then idx = 1 end
    if idx > #current_pages then idx = #current_pages end
    current_page_index = idx
    local page = current_pages[idx]
    if type(page) == "table" then
      page.height = desired
    end
  end

  needs_save = true
  save_timer = SAVE_DELAY
end

-- -- ІНІЦІАЛІЗАЦІЯ КЕШОВАНИХ ПРАПОРІВ
local function init_cached_flags()
  FLAGS_WINDOW =
    reaper.ImGui_WindowFlags_NoMove() |
    reaper.ImGui_WindowFlags_NoResize() |
    reaper.ImGui_WindowFlags_NoSavedSettings() |
    reaper.ImGui_WindowFlags_NoCollapse() |
    reaper.ImGui_WindowFlags_NoDocking() |
    reaper.ImGui_WindowFlags_NoTitleBar() |
    reaper.ImGui_WindowFlags_NoScrollbar()
end

-- -- ШРИФТ
local function build_font()
  current_font = nil
  if type(reaper.ImGui_CreateFont) ~= "function" then return end
  local ok, f = pcall(reaper.ImGui_CreateFont, font_family, font_size)
  if ok and f then
    if type(reaper.ImGui_Attach) == "function" then
      pcall(reaper.ImGui_Attach, ctx, f)
    end
    current_font = f
  end
end

-- -- WORD WRAP
local function calc_text_width(s)
  if s == "" then return 0 end
  local ok, w = pcall(reaper.ImGui_CalcTextSize, ctx, s)
  return (ok and type(w) == "number") and w or 0
end

local function wrap_text_impl(text, max_px)
  local result = {}
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(lines) do
    if line == "" then
      result[#result + 1] = ""
    else
      local current = ""
      local words = {}
      for word in (line .. " "):gmatch("([^ \t]*[ \t])") do
        if word ~= "" then words[#words + 1] = word end
      end
      for _, word in ipairs(words) do
        local candidate = current .. word
        local trimmed = candidate:match("^(.-)%s*$") or candidate
        local w = calc_text_width(trimmed)
        if w > max_px and current ~= "" then
          result[#result + 1] = current:match("^(.-)%s*$") or current
          current = word
        else
          current = candidate
        end
      end
      if current ~= "" then
        result[#result + 1] = current:match("^(.-)%s*$") or current
      end
    end
  end
  return tbl_concat(result, "\n")
end

local function wrap_text(text, max_px)
  if not text or text == "" or not max_px or max_px <= 0 then return text or "" end
  if text == wrap_cache_text and max_px == wrap_cache_width then
    return wrap_cache_result
  end
  local result = wrap_text_impl(text, max_px)
  wrap_cache_text = text
  wrap_cache_width = max_px
  wrap_cache_result = result
  return result
end

local function wrap_editor_text(text, max_px)
  return normalize_newlines(wrap_text(normalize_newlines(text), max_px))
end

local function clamp_page_index(index, count)
  count = math_max(1, count or 1)
  index = math.floor(tonumber(index) or 1)
  if index < 1 then return 1 end
  if index > count then return count end
  return index
end

local function make_note_page(text, height, manual_height)
  local page = { text = normalize_newlines(text or "") }
  height = tonumber(height)
  if height then
    page.height = math.floor(math_max(min_height, math_min(max_height, height)))
  end
  if manual_height then
    page.manual_height = true
  end
  return page
end

local function normalize_note_entry(entry)
  local pages = {}
  local active_page = 1

  if type(entry) == "table" and type(entry.pages) == "table" then
    for i = 1, #entry.pages do
      local page = entry.pages[i]
      if type(page) == "table" then
        pages[#pages + 1] = make_note_page(
          page.text or "",
          page.height or entry.height,
          page.manual_height or entry.manual_height
        )
      elseif type(page) == "string" then
        pages[#pages + 1] = make_note_page(page, entry.height, entry.manual_height)
      end
    end
    active_page = entry.active_page or 1
  elseif type(entry) == "table" then
    pages[1] = make_note_page(entry.text or "", entry.height, entry.manual_height)
  elseif type(entry) == "string" then
    pages[1] = make_note_page(entry, nil)
  end

  if #pages == 0 then pages[1] = make_note_page("", nil) end
  active_page = clamp_page_index(active_page, #pages)
  return pages, active_page
end

local function ensure_current_pages()
  if #current_pages == 0 then
    current_pages[1] = make_note_page(current_param_note, current_param_height)
    current_page_index = 1
  end
  current_page_index = clamp_page_index(current_page_index, #current_pages)
end

local function store_current_page_state(mark_manual_height)
  ensure_current_pages()
  local page = current_pages[current_page_index]
  page.text = normalize_newlines(current_param_note or "")
  local clamped_h = math.floor(math_max(min_height, math_min(max_height, note_height)))
  -- Height in view mode is committed only by explicit Save/Ctrl+S.
  -- Background saves should not overwrite stored per-parameter height.
  if mark_manual_height then
    page.height = clamped_h
    page.manual_height = true
  elseif mode == "edit" then
    page.height = clamped_h
  end
  current_param_height = page.height and math.floor(math_max(min_height, math_min(max_height, page.height))) or current_param_height
end

local function load_current_page_state()
  ensure_current_pages()
  local page = current_pages[current_page_index]
  current_param_note = normalize_newlines(page.text or "")
  current_param_height = page.height and math.floor(math_max(min_height, math_min(max_height, page.height))) or nil
  if current_param_height then
    note_height = current_param_height
    base_height = note_height
  else
    note_height = math.floor(base_height)
  end
  local keep_exact_saved_height = type(page) == "table" and page.manual_height == true
  ensure_saved_height_fits_text(current_param_note, keep_exact_saved_height)
  wrap_cache_text = nil
  edit_refresh_token = edit_refresh_token + 1
end

local function copy_current_pages_for_save(mark_manual_height)
  store_current_page_state(mark_manual_height)
  local pages = {}
  for i, page in ipairs(current_pages) do
    pages[i] = make_note_page(page.text or "", page.height, page.manual_height)
  end
  return pages
end

local function pages_have_text(pages)
  for _, page in ipairs(pages) do
    if (page.text or "") ~= "" then return true end
  end
  return false
end

local function copy_entry_pages_for_height_save(entry, fallback_text, fallback_height)
  local pages = {}
  local active_page = 1

  if type(entry) == "table" and type(entry.pages) == "table" then
    for i = 1, #entry.pages do
      local page = entry.pages[i]
      if type(page) == "table" then
        pages[#pages + 1] = make_note_page(
          page.text or "",
          page.height or entry.height,
          page.manual_height or entry.manual_height
        )
      elseif type(page) == "string" then
        pages[#pages + 1] = make_note_page(page, entry.height, entry.manual_height)
      end
    end
    active_page = entry.active_page or 1
  elseif type(entry) == "table" then
    pages[1] = make_note_page(entry.text or fallback_text or "", entry.height or fallback_height, entry.manual_height)
  elseif type(entry) == "string" then
    pages[1] = make_note_page(entry, fallback_height, false)
  end

  if #pages == 0 then
    pages[1] = make_note_page(fallback_text or "", fallback_height, true)
  end

  active_page = clamp_page_index(active_page, #pages)
  return pages, active_page
end

local function mark_note_dirty()
  wrap_cache_text = nil
  needs_save = true
  save_timer = SAVE_DELAY
end

local function switch_page(delta)
  ensure_current_pages()
  local new_index = clamp_page_index(current_page_index + delta, #current_pages)
  if new_index == current_page_index then return end
  store_current_page_state()
  current_page_index = new_index
  load_current_page_state()
  mark_note_dirty()
end

local function go_to_page(index)
  ensure_current_pages()
  local new_index = clamp_page_index(index, #current_pages)
  if new_index == current_page_index then return end
  store_current_page_state()
  current_page_index = new_index
  load_current_page_state()
  mark_note_dirty()
end

local function add_page()
  store_current_page_state()
  current_pages[#current_pages + 1] = make_note_page("", note_height)
  current_page_index = #current_pages
  load_current_page_state()
  mark_note_dirty()
end

local function delete_current_page()
  ensure_current_pages()
  if #current_pages <= 1 then return end
  table.remove(current_pages, current_page_index)
  current_page_index = clamp_page_index(current_page_index, #current_pages)
  load_current_page_state()
  mark_note_dirty()
end

-- -- СЕРІАЛІЗАЦІЯ
local function serialize_table(val, name, depth)
  depth = depth or 0
  local indent = ("  "):rep(depth)
  local tmp = ""
  if name then
    if type(name) == "string" then
      tmp = indent .. (name:match("^[a-zA-Z_][a-zA-Z0-9_]*$")
        and name .. " = "
        or str_format("[%q] = ", name))
    else
      tmp = indent .. "[" .. tostring(name) .. "] = "
    end
  else
    tmp = indent
  end

  if type(val) == "table" then
    local parts = { "{\n" }
    for k, v in pairs(val) do
      parts[#parts + 1] = serialize_table(v, k, depth + 1) .. ",\n"
    end
    parts[#parts + 1] = indent .. "}"
    return tmp .. tbl_concat(parts)
  elseif type(val) == "number" then return tmp .. tostring(val)
  elseif type(val) == "string" then return tmp .. str_format("%q", val)
  elseif type(val) == "boolean" then return tmp .. (val and "true" or "false")
  else return tmp .. '"[unserializable]"'
  end
end

-- -- ФАЙЛОВІ ОПЕРАЦІЇ
local function load_param_notes()
  local file = io_open(param_notes_filename, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local func = load(content)
    if func then
      local ok, result = pcall(func)
      if ok and type(result) == "table" then
        param_notes = result
        return
      end
    end
  end
  param_notes = {}
end

local function save_param_notes(force_entry, mark_manual_height)
  if current_fx_name ~= "" and current_param_index >= 0 then
    if not param_notes[current_fx_name] then param_notes[current_fx_name] = {} end
    local pages = copy_current_pages_for_save(mark_manual_height)
    if pages_have_text(pages) or force_entry or #pages > 1 then
      param_notes[current_fx_name][current_param_index] = {
        pages = pages,
        active_page = current_page_index
      }
    else
      param_notes[current_fx_name][current_param_index] = nil
    end
  end

  local file = io_open(param_notes_filename, "w")
  if file then
    file:write("return " .. serialize_table(param_notes))
    file:close()
  end
end

local function get_note_text_and_height(fx_name, param_idx)
  local fx_tbl = param_notes[fx_name]
  if not fx_tbl then
    current_pages, current_page_index = normalize_note_entry(nil)
    return "", nil
  end
  local entry = fx_tbl[param_idx]
  current_pages, current_page_index = normalize_note_entry(entry)
  local page = current_pages[current_page_index]
  local h = page.height and math_max(min_height, math_min(max_height, page.height)) or nil
  return page.text or "", h
end

local function load_settings()
  local file = io_open(settings_filename, "r")
  if file then
    local content = file:read("*a")
    file:close()
    local func = load(content)
    if func then
      local ok, result = pcall(func)
      if ok and type(result) == "table" then
        if result.height then note_height = math_max(min_height, math_min(max_height, result.height)) end
        if result.mode then mode = result.mode end
        if result.font_family then font_family = result.font_family end
        if result.font_size then font_size = math_max(8, math_min(32, result.font_size)) end
        if result.base_height then base_height = math_max(min_height, math_min(max_height, result.base_height)) end
        if result.default_height then
          default_height = math_max(min_height, math_min(max_height, result.default_height))
        end
      end
    end
  end

  -- Settings created by older versions have no default_height. Preserve their
  -- former startup behavior once, then save the value separately.
  if not default_height or default_height < min_height or default_height > max_height then
    default_height = math_max(min_height, math_min(max_height, base_height or note_height))
  end
  -- Keep fallback height in sync for entries/pages that don't have their own saved height yet.
  if not base_height or base_height < min_height or base_height > max_height then
    base_height = math_max(min_height, math_min(max_height, note_height))
  end
  if not note_height or note_height < min_height or note_height > max_height then
    note_height = math_max(min_height, math_min(max_height, base_height))
  end
end

local function save_settings()
  note_height = math.floor(math_max(min_height, math_min(max_height, note_height)))
  base_height = math.floor(math_max(min_height, math_min(max_height, base_height or note_height)))
  default_height = math.floor(math_max(min_height, math_min(max_height, default_height or note_height)))
  local file = io_open(settings_filename, "w")
  if file then
    file:write(str_format(
      "return { height = %d, mode = %q, font_family = %q, font_size = %d, auto_resize = %s, base_height = %d, default_height = %d }",
      math.floor(note_height), mode, font_family, math.floor(font_size),
      "false", math.floor(base_height), math.floor(default_height)
    ))
    file:close()
  end
end

local function set_default_window_height()
  default_height = math.floor(math_max(min_height, math_min(max_height, note_height)))
  save_settings()
end

local function reset_window_height_to_default()
  note_height = math.floor(math_max(min_height, math_min(max_height, default_height)))
  base_height = note_height
  save_settings()
end

local function save_current_note()
  current_param_height = math.floor(math_max(min_height, math_min(max_height, note_height)))
  base_height = current_param_height
  save_param_notes(true, true)
  needs_save = false
  mode = "view"
  save_settings()
end

local function save_current_param_height_in_view()
  local target_fx_name = current_fx_name ~= "" and current_fx_name or save_target_fx_name
  local target_param_index = current_param_index >= 0 and current_param_index or save_target_param_index

  if target_fx_name == "" or target_param_index < 0 then
    if last_track and last_index ~= nil then
      local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
      if retval then
        local track_num = (last_track == reaper.GetMasterTrack(0))
          and 0 or reaper.CSurf_TrackToID(last_track, false)
        if tracknumber == track_num and fxnumber == last_index then
          local _, pname = reaper.TrackFX_GetParamName(last_track, last_index, paramnumber, "")
          current_param_index = paramnumber
          current_param_name = pname
          target_param_index = paramnumber
          target_fx_name = current_fx_name
        end
      end
    end
  end
  if target_fx_name == "" or target_param_index < 0 then return end

  save_target_fx_name = target_fx_name
  save_target_param_index = target_param_index

  ensure_current_pages()
  local clamped_h = math.floor(math_max(min_height, math_min(max_height, note_height)))
  note_height = clamped_h
  current_param_height = clamped_h
  base_height = clamped_h

  local page = current_pages[current_page_index]
  if type(page) == "table" then
    page.text = normalize_newlines(current_param_note or "")
    page.height = clamped_h
    page.manual_height = true
  end

  if not param_notes[target_fx_name] then param_notes[target_fx_name] = {} end
  local saved_pages, saved_active_page = copy_entry_pages_for_height_save(
    param_notes[target_fx_name][target_param_index],
    current_param_note,
    clamped_h
  )
  local target_page_index = clamp_page_index(current_page_index or saved_active_page, #saved_pages)
  saved_pages[target_page_index].text = normalize_newlines(current_param_note or saved_pages[target_page_index].text or "")
  saved_pages[target_page_index].height = clamped_h

  -- FIX (bugfix, see changelog): only mark the height as a durably "frozen"
  -- manual preference when there is actual note text on this page. This is
  -- what current_pages/get_note_text_and_height look at later (via
  -- current_param_note) to decide whether a parameter counts as "empty".
  -- If we always stamped manual_height = true here (as before), a parameter
  -- that never had any text but was resized once in view mode would forever
  -- report a non-nil current_param_height on every future visit, which made
  -- the "empty parameter -> use live default_height from the menu" branch in
  -- main_loop() unreachable for it. Gating this on actual text keeps that
  -- fallback working correctly for parameters without notes.
  local target_text_is_empty = (saved_pages[target_page_index].text or "") == ""
  saved_pages[target_page_index].manual_height = not target_text_is_empty

  current_page_index = target_page_index
  current_pages = saved_pages
  param_notes[target_fx_name][target_param_index] = {
    pages = saved_pages,
    active_page = target_page_index
  }

  local file = io_open(param_notes_filename, "w")
  if file then
    file:write("return " .. serialize_table(param_notes))
    file:close()
  end
  needs_save = false
  save_timer = 0
  save_settings()
end

-- -- LAST TOUCHED ПАРАМЕТР
local function get_last_touched_param(track, fx_index)
  local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
  if not retval then return -1, "" end
  local track_num = (track == reaper.GetMasterTrack(0))
    and 0 or reaper.CSurf_TrackToID(track, false)
  if tracknumber == track_num and fxnumber == fx_index then
    local _, pname = reaper.TrackFX_GetParamName(track, fx_index, paramnumber, "")
    return paramnumber, pname
  end
  return -1, ""
end

-- -- ПОШУК FLOATING FX
local function find_any_floating_fx()
  for t = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, t)
    for f = 0, reaper.TrackFX_GetCount(track) - 1 do
      if reaper.TrackFX_GetFloatingWindow(track, f) then return true, track, f end
    end
  end
  local master = reaper.GetMasterTrack(0)
  for f = 0, reaper.TrackFX_GetCount(master) - 1 do
    if reaper.TrackFX_GetFloatingWindow(master, f) then return true, master, f end
  end
  return false, nil, nil
end

local function get_focused_or_floating_fx()
  local retval, track_idx, _, fx_idx = reaper.GetFocusedFX2()
  if retval ~= 0 and (retval & 4 == 0) and (retval & 1 == 1) and track_idx > 0 then
    local media_track = reaper.GetTrack(0, track_idx - 1)
    if media_track and reaper.TrackFX_GetFloatingWindow(media_track, fx_idx) then
      return true, media_track, fx_idx
    end
  end

  local now = reaper.time_precise()
  if now >= next_floating_fx_scan_at then
    cached_floating_fx_found, cached_floating_fx_track, cached_floating_fx_index = find_any_floating_fx()
    next_floating_fx_scan_at = now + FLOATING_FX_SCAN_INTERVAL
  end
  return cached_floating_fx_found, cached_floating_fx_track, cached_floating_fx_index
end

-- -- FONT SUBMENU
local function draw_font_submenu()
  if reaper.ImGui_BeginMenu(ctx, "Font Family") then
    for _, fam in ipairs(font_families) do
      if reaper.ImGui_MenuItem(ctx, fam, nil, fam == font_family) then
        font_family = fam
        build_font()
        save_settings()
      end
    end
    reaper.ImGui_EndMenu(ctx)
  end
  if reaper.ImGui_BeginMenu(ctx, "Font Size") then
    for _, sz in ipairs({8,10,11,12,13,14,16,18,20,22,24,28,32}) do
      if reaper.ImGui_MenuItem(ctx, tostring(sz), nil, sz == font_size) then
        font_size = sz
        build_font()
        save_settings()
      end
    end
    reaper.ImGui_EndMenu(ctx)
  end
end

-- -- STYLES
local function push_style_vars()
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 4, 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 6, 6)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 3)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0)
end
local STYLE_VAR_COUNT = 7
local function pop_style_vars()
  reaper.ImGui_PopStyleVar(ctx, STYLE_VAR_COUNT)
end

-- -- HELPER: чи активне текстове поле вводу
local function IsTextInputActive()
  return reaper.ImGui_IsAnyItemActive(ctx)
end

local function reset_last_param_value_state()
  last_param_value_track = nil
  last_param_value_fx = -1
  last_param_value_param = -1
  last_param_value = nil
end

local function snapshot_last_param_value(track, fx_index, param_index)
  if not track or fx_index == nil or param_index == nil or param_index < 0 then
    reset_last_param_value_state()
    return
  end
  local ok, v = pcall(reaper.TrackFX_GetParamNormalized, track, fx_index, param_index)
  if ok and type(v) == "number" then
    last_param_value_track = track
    last_param_value_fx = fx_index
    last_param_value_param = param_index
    last_param_value = v
  else
    reset_last_param_value_state()
  end
end

local function try_restore_saved_height_on_param_touch(track, fx_index, param_index)
  if mode ~= "view" or is_resizing then return end
  if current_param_height == nil or param_index < 0 then return end
  if current_param_index ~= param_index or current_fx_name == "" then return end

  local ok, v = pcall(reaper.TrackFX_GetParamNormalized, track, fx_index, param_index)
  if not (ok and type(v) == "number") then return end

  local is_same_param =
    last_param_value_track == track and
    last_param_value_fx == fx_index and
    last_param_value_param == param_index and
    type(last_param_value) == "number"

  if is_same_param and math.abs(v - last_param_value) > 1e-9 then
    local restored_h = math.floor(math_max(min_height, math_min(max_height, current_param_height)))
    note_height = restored_h
    base_height = restored_h
  end

  last_param_value_track = track
  last_param_value_fx = fx_index
  last_param_value_param = param_index
  last_param_value = v
end

local function is_imgui_key_pressed(key_name)
  local key_fn = reaper["ImGui_Key_" .. key_name]
  if type(key_fn) ~= "function" then return false end
  local ok, key = pcall(key_fn)
  return ok and reaper.ImGui_IsKeyPressed(ctx, key)
end

local function is_any_imgui_key_pressed(names)
  for _, name in ipairs(names) do
    if is_imgui_key_pressed(name) then return true end
  end
  return false
end

local js_vkey_was_down = {}
local function get_js_vkey_state()
  if type(reaper.JS_VKeys_GetState) ~= "function" then return nil end
  local ok, a, b = pcall(reaper.JS_VKeys_GetState, 0)
  if not ok then return nil end
  if type(a) == "string" then return a end
  if type(b) == "string" then return b end
  return nil
end

local function is_js_vkey_down(state, vk)
  return type(state) == "string" and (state:byte(vk) or 0) ~= 0
end

local function is_js_vkey_pressed(state, vk)
  local down = is_js_vkey_down(state, vk)
  local pressed = down and not js_vkey_was_down[vk]
  js_vkey_was_down[vk] = down
  return pressed
end

local digit_key_aliases = {
  [1] = { "1", "Digit1", "D1", "One", "Keypad1", "Numpad1", "NumPad1" },
  [2] = { "2", "Digit2", "D2", "Two", "Keypad2", "Numpad2", "NumPad2" },
  [3] = { "3", "Digit3", "D3", "Three", "Keypad3", "Numpad3", "NumPad3" },
  [4] = { "4", "Digit4", "D4", "Four", "Keypad4", "Numpad4", "NumPad4" },
  [5] = { "5", "Digit5", "D5", "Five", "Keypad5", "Numpad5", "NumPad5" },
  [6] = { "6", "Digit6", "D6", "Six", "Keypad6", "Numpad6", "NumPad6" },
  [7] = { "7", "Digit7", "D7", "Seven", "Keypad7", "Numpad7", "NumPad7" },
  [8] = { "8", "Digit8", "D8", "Eight", "Keypad8", "Numpad8", "NumPad8" },
  [9] = { "9", "Digit9", "D9", "Nine", "Keypad9", "Numpad9", "NumPad9" },
}

local function handle_page_shortcuts()
  if mode ~= "view" or current_param_index < 0 then return end
  ensure_current_pages()

  local key_state = get_js_vkey_state()
  for i = 1, math_min(9, #current_pages) do
    local main_digit_vk = 0x30 + i
    local keypad_digit_vk = 0x60 + i
    if is_js_vkey_pressed(key_state, main_digit_vk)
       or is_js_vkey_pressed(key_state, keypad_digit_vk)
       or is_any_imgui_key_pressed(digit_key_aliases[i]) then
      go_to_page(i)
      return true
    end
  end

  if is_js_vkey_pressed(key_state, 0x25) or is_any_imgui_key_pressed({ "LeftArrow", "Left" }) then
    switch_page(-1)
    return true
  elseif is_js_vkey_pressed(key_state, 0x27) or is_any_imgui_key_pressed({ "RightArrow", "Right" }) then
    switch_page(1)
    return true
  end

  return false
end

-- -- DRAW CONTENT
local iflags_edit = nil
local last_editor_wrap_width = 400

local function draw_tiny_page_button(label, id)
  local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
  local clicked = reaper.ImGui_Button(ctx, "##" .. id, 18, page_nav_height)
  local tw, th = reaper.ImGui_CalcTextSize(ctx, label)
  local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  reaper.ImGui_DrawList_AddText(
    draw_list,
    x + ((18 - tw) * 0.5),
    y + ((page_nav_height - th) * 0.5) - 1,
    theme.Text,
    label
  )
  return clicked
end

local function draw_page_nav(show_add, draw_separator)
  ensure_current_pages()
  local page_count = #current_pages
  if not show_add and page_count <= 1 then return false end

  local pop_count = 1
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 3, 1)
  if type(reaper.ImGui_StyleVar_ItemSpacing) == "function" then
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 3, 0)
    pop_count = 2
  end
  if draw_tiny_page_button("<", "page_prev") then switch_page(-1) end
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, tostring(current_page_index) .. "/" .. tostring(page_count))
  reaper.ImGui_SameLine(ctx)
  if draw_tiny_page_button(">", "page_next") then switch_page(1) end

  if show_add then
    reaper.ImGui_SameLine(ctx)
    if draw_tiny_page_button("+", "page_add") then add_page() end
  end

  reaper.ImGui_PopStyleVar(ctx, pop_count)
  if draw_separator then reaper.ImGui_Separator(ctx) end
  return true
end

local function draw_content()
  local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)

  if mode == "view" then
    ensure_current_pages()
    local show_view_nav = #current_pages > 1
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), theme.ChildBg)
    local child_h = avail_h - resize_zone - (show_view_nav and page_nav_height or 0)
    if reaper.ImGui_BeginChild(ctx, "##view_scroll", avail_w, math_max(20, child_h), 0) then
      local text = current_param_note ~= "" and current_param_note or " "
      for _, line in ipairs(get_view_lines(text)) do
        if is_separator_line(line) then
          reaper.ImGui_Separator(ctx)
        else
          local cx = reaper.ImGui_GetCursorPosX(ctx)
          reaper.ImGui_PushTextWrapPos(ctx, cx + avail_w - 8)
          reaper.ImGui_Text(ctx, line ~= "" and line or " ")
          reaper.ImGui_PopTextWrapPos(ctx)
        end
      end
      reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx)
    if show_view_nav then
      draw_page_nav(false, false)
    end

  elseif mode == "edit" then
    if current_param_name ~= "" then
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.ParamNameColor)
      local title = current_param_name
      if current_param_index >= 0 then
        title = title .. " [#" .. current_param_index .. "]"
      end
      reaper.ImGui_Text(ctx, title)
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_SameLine(ctx)
      draw_page_nav(true, false)
      reaper.ImGui_Separator(ctx)
    else
      draw_page_nav(true, true)
    end

    local avail_w2, avail_h2 = reaper.ImGui_GetContentRegionAvail(ctx)

    if not iflags_edit then
      iflags_edit = reaper.ImGui_InputTextFlags_AllowTabInput()
      if type(reaper.ImGui_InputTextFlags_NoHorizontalScroll) == "function" then
        iflags_edit = iflags_edit | reaper.ImGui_InputTextFlags_NoHorizontalScroll()
      end
    end

    local editor_w = math_max(40, avail_w2 - 16)
    last_editor_wrap_width = editor_w
    local display_text = normalize_newlines(current_param_note)
    local changed, new_display = reaper.ImGui_InputTextMultiline(
      ctx, "##ParamText" .. edit_refresh_token, display_text,
      avail_w2, math_max(20, avail_h2 - resize_zone),
      iflags_edit
    )

    if changed then
      local normalized_display = normalize_newlines(new_display)
      local paste_like_change = false

      if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
         and is_any_imgui_key_pressed({ "V", "KeyV", "Paste" }) then
        paste_like_change = true
      end
      current_param_note = normalized_display
      wrap_cache_text = nil
      if paste_like_change then
        auto_resize_note_height_for_text(current_param_note)
      end
      needs_save  = true
      save_timer  = SAVE_DELAY
    end
  end
end

-- -- CONTEXT MENU
local function draw_context_menu()
  if not reaper.ImGui_BeginPopup(ctx, "##ctx_menu") then return end

  if reaper.ImGui_MenuItem(ctx, "View Mode", nil, mode == "view") then
    if mode == "edit" and current_fx_name ~= "" and current_param_index >= 0 then
      save_param_notes()
    end
    mode = "view"
    save_settings()
  end
  if reaper.ImGui_MenuItem(ctx, "Edit Mode", nil, mode == "edit") then
    mode = "edit"
    save_settings()
  end
  reaper.ImGui_Separator(ctx)
  draw_font_submenu()
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Set Current Height as Default") then
    set_default_window_height()
  end
  if reaper.ImGui_BeginMenu(ctx, "Default Height") then
    for height = 30, 120, 10 do
      if reaper.ImGui_MenuItem(ctx, tostring(height), nil, default_height == height) then
        default_height = height
        -- Apply the chosen default immediately to the open panel too.
        note_height = height
        base_height = height
        save_settings()
      end
    end
    reaper.ImGui_EndMenu(ctx)
  end
  if reaper.ImGui_MenuItem(ctx, "Reset Height to Default") then
    reset_window_height_to_default()
  end
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Save") then
    if mode == "view" then
      save_current_param_height_in_view()
    else
      save_current_note()
    end
  end
  if mode == "edit" then
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Add Page") then
      add_page()
    end
    if #current_pages > 1 and reaper.ImGui_MenuItem(ctx, "Delete Page") then
      delete_current_page()
    end
  end
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Copy") then
    reaper.ImGui_SetClipboardText(ctx, current_param_note)
  end
  if reaper.ImGui_MenuItem(ctx, "Paste") and mode == "edit" then
    local clip = reaper.ImGui_GetClipboardText(ctx)
    if clip then
      current_param_note = wrap_editor_text(current_param_note .. normalize_newlines(clip), last_editor_wrap_width)
      edit_refresh_token = edit_refresh_token + 1
      wrap_cache_text    = nil
      auto_resize_note_height_for_text(current_param_note)
      needs_save  = true
      save_timer  = SAVE_DELAY
    end
  end
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Clear Current") then
    current_param_note = ""
    current_pages, current_page_index = normalize_note_entry(nil)
    edit_refresh_token = edit_refresh_token + 1
    wrap_cache_text = nil
    if current_fx_name ~= "" and current_param_index >= 0 and param_notes[current_fx_name] then
      param_notes[current_fx_name][current_param_index] = nil
    end
    needs_save = true
    save_timer = SAVE_DELAY
  end
  if reaper.ImGui_MenuItem(ctx, "Clear All for this FX") and current_fx_name ~= "" then
    param_notes[current_fx_name] = {}
    current_param_note = ""
    current_pages, current_page_index = normalize_note_entry(nil)
    edit_refresh_token = edit_refresh_token + 1
    wrap_cache_text = nil
    save_param_notes()
  end
  reaper.ImGui_Separator(ctx)
  if reaper.ImGui_MenuItem(ctx, "Close Script") then should_exit = true end

  reaper.ImGui_EndPopup(ctx)
end

-- -- ГОЛОВНИЙ ЦИКЛ
local function main_loop()
  if should_exit then
    save_param_notes()
    save_settings()
    return
  end

  if not reaper.ImGui_ValidatePtr(ctx, 'ImGui_Context*') then
    ctx = reaper.ImGui_CreateContext("FX Notes")
    init_cached_flags()
    build_font()
  end

  if needs_save then
    save_timer = save_timer - 1
    if save_timer <= 0 then
      save_param_notes()
      needs_save = false
    end
  end

  local fx_found, track, index = get_focused_or_floating_fx()

  if not (fx_found and track and index) then
    if current_fx_name ~= "" then save_param_notes() end
    last_track, last_index  = nil, nil
    current_fx_name         = ""
    current_param_index     = -1
    current_param_name      = ""
    current_param_note      = ""
    current_pages, current_page_index = normalize_note_entry(nil)
    current_param_height    = nil
    save_target_fx_name     = ""
    save_target_param_index = -1
    wrap_cache_text         = nil
    last_touched_param      = -1
    reset_last_param_value_state()
    reaper.defer(main_loop)
    return
  end

  local fx_window = reaper.TrackFX_GetFloatingWindow(track, index)
  if not fx_window then
    reaper.defer(main_loop)
    return
  end

  local ret, cl, ct, cr, cb = reaper.JS_Window_GetClientRect(fx_window)
  if not ret then
    reaper.defer(main_loop)
    return
  end

  if track ~= last_track or index ~= last_index then
    last_track = track
    last_index = index
    local _, fx_name = reaper.TrackFX_GetFXName(track, index, "")
    if current_fx_name ~= "" and current_param_index >= 0 then
      save_param_notes()
    end
    current_fx_name     = fx_name
    current_param_index = -1
    current_param_name  = ""
    current_param_note  = ""
    current_pages, current_page_index = normalize_note_entry(nil)
    edit_refresh_token  = edit_refresh_token + 1
    current_param_height = nil
    save_target_fx_name = ""
    save_target_param_index = -1
    wrap_cache_text     = nil
    last_touched_param  = -1
    reset_last_param_value_state()
    topmost_cache_frame = -999
  end

  local param_idx, param_name = get_last_touched_param(track, index)
  if param_idx >= 0 and param_idx ~= last_touched_param then
    if current_fx_name ~= "" and current_param_index >= 0 then
      save_param_notes()
    end
    last_touched_param  = param_idx
    current_param_index = param_idx
    current_param_name  = param_name
    save_target_fx_name = current_fx_name
    save_target_param_index = param_idx
    current_param_note, current_param_height = get_note_text_and_height(current_fx_name, param_idx)
    edit_refresh_token  = edit_refresh_token + 1

    -- BUGFIX: "empty parameter" must be decided by whether there is saved
    -- NOTE TEXT, not merely by whether a page.height happens to exist.
    -- Previously, if a parameter had once had its height explicitly saved
    -- while its note text was empty (e.g. via Ctrl+S / manual resize in
    -- view mode), current_param_height came back non-nil forever, and this
    -- branch never fell through to `default_height` again — so changing
    -- "Default Height" in the right-click menu appeared to have no effect
    -- on that parameter. Now, a frozen per-parameter height is only trusted
    -- when there is actual saved text; an empty parameter always follows
    -- the live default_height from the menu.
    local has_saved_note_text = (current_param_note ~= nil and current_param_note ~= "")
    if has_saved_note_text and current_param_height then
      note_height = math.floor(current_param_height)
      base_height = note_height
    else
      -- A new/empty parameter always starts at the CURRENT default size
      -- from the menu, rather than inheriting a stale frozen height or
      -- the size of the previously opened note.
      note_height = math.floor(default_height)
      base_height = note_height
    end

    local active_page = current_pages[current_page_index]
    local keep_exact_saved_height = has_saved_note_text and type(active_page) == "table" and active_page.manual_height == true
    ensure_saved_height_fits_text(current_param_note, keep_exact_saved_height)
    wrap_cache_text     = nil
    snapshot_last_param_value(track, index, param_idx)
  elseif param_idx >= 0 then
    try_restore_saved_height_on_param_touch(track, index, param_idx)
  end

  local window_width = cr - cl

  reaper.ImGui_SetNextWindowPos(ctx, cl, cb, reaper.ImGui_Cond_Always())
  reaper.ImGui_SetNextWindowSize(ctx, window_width, note_height, reaper.ImGui_Cond_Always())

  local flags = FLAGS_WINDOW

  applyTheme()
  push_style_vars()

  local using_font = current_font ~= nil
  if using_font then reaper.ImGui_PushFont(ctx, current_font, font_size) end

  local visible = reaper.ImGui_Begin(ctx, "FX Note##main", true, flags)
  if visible then
    local text_input_active = IsTextInputActive()

    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
       and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then
      if mode == "view" then
        save_current_param_height_in_view()
      else
        save_current_note()
      end
    end

    handle_page_shortcuts()

    if not text_input_active then
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
        reaper.Main_OnCommand(40044, 0)
      end
      if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
         and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z()) then
        reaper.Main_OnCommand(40029, 0)
      end
    end

    local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
    local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)

    local in_resize_zone = mouse_y >= (win_y + win_h - resize_zone)
                       and mouse_y <= (win_y + win_h)
                       and mouse_x >= win_x
                       and mouse_x <= (win_x + win_w)

    if in_resize_zone or is_resizing then
      reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
    end

    if in_resize_zone and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) then
      is_resizing = true
    end

    if is_resizing then
      if reaper.ImGui_IsMouseDown(ctx, reaper.ImGui_MouseButton_Left()) then
        local _, dy = reaper.ImGui_GetMouseDelta(ctx)
        note_height = math.floor(math_max(min_height, math_min(max_height, note_height + dy)))
        base_height = note_height
      else
        is_resizing = false
        -- In view mode, height is committed only by explicit Save/Ctrl+S.
        if mode ~= "view" and current_fx_name ~= "" and current_param_index >= 0 then
          current_param_height = math.floor(math_max(min_height, math_min(max_height, note_height)))
          save_param_notes(true, true)
        end
        save_settings()
      end
    end

    if reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) and not in_resize_zone then
      reaper.ImGui_OpenPopup(ctx, "##ctx_menu")
    end

    draw_context_menu()
    draw_content()

    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    reaper.ImGui_DrawList_AddRectFilled(
      draw_list,
      win_x, win_y + win_h - 3,
      win_x + win_w, win_y + win_h,
      theme.ResizeLine
    )
  end

  reaper.ImGui_End(ctx)

  if using_font then reaper.ImGui_PopFont(ctx) end
  pop_style_vars()
  popTheme()

  reaper.defer(main_loop)
end

-- -- ЗАПУСК
reaper.RecursiveCreateDirectory(data_folder, 0)
load_param_notes()
load_settings()
init_cached_flags()
build_font()
reaper.atexit(function()
  save_param_notes()
  save_settings()
end)
main_loop()

