-- Match selected items to project tempo
-- Menu: "Manual BPM" + "Range" on top, BPM list below. Default range 100-135 (saved via ExtState).
local RESET_BEFORE_APPLY = true
local DEFAULT_MIN, DEFAULT_MAX = 100, 135
local proj = 0
local numItems = reaper.CountSelectedMediaItems(proj)
if numItems == 0 then
  reaper.ShowMessageBox("Select at least one item", "BPM Menu", 0)
  return
end
local function getRange()
  local a = tonumber(reaper.GetExtState("BPM_MENU", "min")) or DEFAULT_MIN
  local b = tonumber(reaper.GetExtState("BPM_MENU", "max")) or DEFAULT_MAX
  if a > b then a, b = b, a end
  return math.max(21, a), math.min(298, b)
end
local function setRange()
  local a0, b0 = getRange()
  local ok, csv = reaper.GetUserInputs("BPM range", 2, "From,To", a0 .. "," .. b0)
  if not ok then return end
  local a, b = csv:match("^%s*(%d+)%s*,%s*(%d+)%s*$")
  a, b = tonumber(a), tonumber(b)
  if not a or not b then return end
  if a > b then a, b = b, a end
  reaper.SetExtState("BPM_MENU", "min", tostring(math.max(21, a)), true)
  reaper.SetExtState("BPM_MENU", "max", tostring(math.min(298, b)), true)
end
local function manualBPM()
  local ok, csv = reaper.GetUserInputs("Original BPM", 1, "BPM (21-298)", "")
  if not ok then return nil end
  local bpm = tonumber(csv)
  if not bpm then return nil end
  bpm = math.floor(bpm + 0.5)
  if bpm <= 20 or bpm >= 299 then return nil end
  return bpm
end
local function chooseBPM()
  while true do
    local minBpm, maxBpm = getRange()
    local parts = {
      "Manual BPM",
      "Range",
      "",
    }
    local LEADING_REAL_ITEMS = 2 -- "Manual BPM", "Range" -- the "" separator takes no index of its own
    local first = LEADING_REAL_ITEMS + 1
    for bpm = minBpm, maxBpm do parts[#parts + 1] = tostring(bpm) end
    local r = gfx.showmenu(table.concat(parts, "|"))
    if r <= 0 then return nil
    elseif r == 1 then local b = manualBPM(); if b then return b end
    elseif r == 2 then setRange()
    elseif r >= first then return math.floor(minBpm + (r - first)) end
  end
end
local function apply(originalBPM, targetBPM)
  if not originalBPM or originalBPM <= 20 or originalBPM >= 299 then return end
  if not targetBPM or targetBPM <= 20 or targetBPM >= 299 then return end
  local delta = (targetBPM / originalBPM) - 1 -- currentrate + (target/original - 1)
  reaper.Undo_BeginBlock()
  for i = 0, numItems - 1 do
    local item = reaper.GetSelectedMediaItem(proj, i)
    local take = item and reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      if RESET_BEFORE_APPLY then rate = 1.0 end
      reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", rate + delta)
    end
  end
  reaper.Main_OnCommand(40612, 0) -- Fix item length
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Match BPM", -1)
end
local originalBPM = chooseBPM()
if not originalBPM then return end
apply(originalBPM, math.floor(reaper.Master_GetTempo() + 0.5))
