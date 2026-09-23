--[[
-------------------------------------------------------------------------------------------
*              Script: FSR MIDI Smart Focus 
* Section      MIDI Editor
* Author:      Andrew Dihtiaruk (FSR)
* Version:     1.0.0
-------------------------------------------------------------------------------------------               
* DONATION:    http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
               http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it.
               
* Bug Reports: If you find any errors, please report one of the link below                  
* Website:     http://reaper-script-feedback.forsemusic1996.workers.dev/

------------------------------------------------------------
*  @description Automatically zooms the MIDI Editor to the selected note's 4-bar block; 
   returns to the full MIDI item when no notes are selected. 
   Optional Time Selection sync.
------------------------------------------------------------
--]] 

-- Sync Time Selection with zoom
------------------------------------------------------------

local TIME_SELECTION = "OFF" -- ON / OFF

local r = reaper

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local BARS_PER_BLOCK = 4

-- MIDI selection check interval (0.05 = 50 ms)
local CHECK_INTERVAL = 0.05

-- Consecutive "no selected note" checks before returning to full item
local NO_SELECTION_CONFIRM = 2

------------------------------------------------------------
-- MIDI EDITOR SECTION ONLY
------------------------------------------------------------

local _, _, section_id = r.get_action_context()
if section_id ~= 32060 then
  r.MB("Load this script into the MIDI Editor section.", "FSR MIDI Smart 4-Bar Zoom", 0)
  return
end

-- Toggle action state is set to ON while running and OFF on exit.
-- Starting it again terminates the previous instance.
r.set_action_options(5)

local function find_action(section_id, search_text)
  local section = r.SectionFromUniqueID(section_id)
  if not section then return nil end
  search_text = search_text:lower()
  local i = 0
  while true do
    local cmd, name = r.kbd_enumerateActions(section, i)
    if not cmd or cmd <= 0 then break end
    if name and name:lower():find(search_text, 1, true) then return cmd end
    i = i + 1
  end
  return nil
end

local ZOOM_TO_LOOP_CMD = find_action(32060, "zoom to project loop selection")
if not ZOOM_TO_LOOP_CMD then
  r.MB("Could not find MIDI Editor action:\n\nView: Zoom to project loop selection", "FSR MIDI Smart 4-Bar Zoom", 0)
  return
end

local LINK_LOOP_TIME_CMD = find_action(0, "link loop points to time selection") or 40621

local current_mode, last_take, last_item, last_block = nil, nil, nil, nil
local last_check_time, no_selection_count = 0, 0
local pending = nil

local function get_selected_note(take)
  local note_idx = r.MIDI_EnumSelNotes(take, -1)
  if note_idx == -1 then return nil end
  local ok, _, _, start_ppq = r.MIDI_GetNote(take, note_idx)
  if not ok then return nil end
  return start_ppq
end

local function set_time_selection(range_start, range_end)
  r.GetSet_LoopTimeRange2(0, true, false, range_start, range_end, false)
end

local function get_item_range(item)
  local item_start = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  return item_start, item_start + item_length
end

local function get_block(take, item, note_start_ppq)
  local item_start = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_start_qn = r.TimeMap2_timeToQN(0, item_start)
  local note_qn = r.MIDI_GetProjQNFromPPQPos(take, note_start_ppq)
  local num, den = r.TimeMap_GetTimeSigAtTime(0, item_start)
  if not num or not den or den == 0 then num, den = 4, 4 end

  local block_qn = (num * 4 / den) * BARS_PER_BLOCK
  local relative_qn = math.max(0, note_qn - item_start_qn)
  local block_index = math.floor((relative_qn + 0.000000001) / block_qn)
  local block_start_qn = item_start_qn + block_index * block_qn
  local block_end_qn = block_start_qn + block_qn

  return block_index,
    r.TimeMap2_QNToTime(0, block_start_qn),
    r.TimeMap2_QNToTime(0, block_end_qn)
end

-- A temporary Loop Selection drives REAPER's native MIDI zoom.
-- It is always restored; the existing Loop/Time-link setting is preserved.
local function request_zoom(editor, take, item, mode, block, range_start, range_end)
  if pending and pending.take == take and pending.item == item
    and pending.mode == mode and pending.block == block then
    return
  end

  local old_loop_start, old_loop_end = r.GetSet_LoopTimeRange2(0, false, true, 0, 0, false)
  local link_was_enabled = r.GetToggleCommandStateEx(0, LINK_LOOP_TIME_CMD) == 1
  if link_was_enabled then r.Main_OnCommand(LINK_LOOP_TIME_CMD, 0) end

  pending = {
    editor = editor, take = take, item = item, mode = mode, block = block,
    range_start = range_start, range_end = range_end,
    old_loop_start = old_loop_start, old_loop_end = old_loop_end,
    link_was_enabled = link_was_enabled, stage = 1
  }
  r.GetSet_LoopTimeRange2(0, true, true, range_start, range_end, false)
end

local function process_pending()
  if not pending then return end

  if pending.stage == 1 then
    if pending.editor then r.MIDIEditor_OnCommand(pending.editor, ZOOM_TO_LOOP_CMD) end
    pending.stage = 2
    return
  end

  if pending.stage == 2 then
    r.GetSet_LoopTimeRange2(0, true, true, pending.old_loop_start, pending.old_loop_end, false)
    pending.stage = 3
    return
  end

  if pending.stage == 3 then
    if pending.link_was_enabled then r.Main_OnCommand(LINK_LOOP_TIME_CMD, 0) end
    pending.stage = 4
    return
  end

  if pending.stage == 4 then
    -- This is the only point where Time Selection can change.
    if TIME_SELECTION == "ON" then
      set_time_selection(pending.range_start, pending.range_end)
    end

    current_mode = pending.mode
    last_take, last_item, last_block = pending.take, pending.item, pending.block
    pending = nil
  end
end

local function request_full_item(editor, take, item)
  if not pending and current_mode == "full" and last_take == take and last_item == item then
    return
  end
  local item_start, item_end = get_item_range(item)
  request_zoom(editor, take, item, "full", nil, item_start, item_end)
end

local function request_block(editor, take, item, note_start_ppq)
  local block, block_start, block_end = get_block(take, item, note_start_ppq)
  if not pending and current_mode == "block" and last_take == take
    and last_item == item and last_block == block then
    return
  end
  request_zoom(editor, take, item, "block", block, block_start, block_end)
end

local function reset_state()
  current_mode, last_take, last_item, last_block = nil, nil, nil, nil
  no_selection_count = 0
end

local function check()
  local editor = r.MIDIEditor_GetActive()
  if not editor or r.MIDIEditor_GetMode(editor) ~= 0 then
    reset_state()
    return
  end

  local take = r.MIDIEditor_GetTake(editor)
  if not take or not r.TakeIsMIDI(take) then
    reset_state()
    return
  end

  local item = r.GetMediaItemTake_Item(take)
  if not item then
    reset_state()
    return
  end

  local note_start_ppq = get_selected_note(take)
  if note_start_ppq then
    no_selection_count = 0
    request_block(editor, take, item, note_start_ppq)
    return
  end

  no_selection_count = no_selection_count + 1
  if no_selection_count >= NO_SELECTION_CONFIRM then
    request_full_item(editor, take, item)
  end
end

local function loop()
  if pending then
    process_pending()
    r.defer(loop)
    return
  end

  local now = r.time_precise()
  if now - last_check_time >= CHECK_INTERVAL then
    last_check_time = now
    check()
  end
  r.defer(loop)
end

r.atexit(function()
  if pending then
    r.GetSet_LoopTimeRange2(0, true, true, pending.old_loop_start, pending.old_loop_end, false)
    if pending.link_was_enabled and r.GetToggleCommandStateEx(0, LINK_LOOP_TIME_CMD) ~= 1 then
      r.Main_OnCommand(LINK_LOOP_TIME_CMD, 0)
    end
  end
  r.set_action_options(8)
end)

loop()
