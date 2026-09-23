--[[
-------------------------------------------------------------------------------------------
*              FSR Preset Manager
* Section      Main
* Author:      Andrew Dihtiaruk (FSR)
* Version:     0.0.4-optimized
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
local selectedCount = 0
local presetFile = nil
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
local SCRIPT_ID = "PresetManager"
local managerDataRoot = reaper.GetResourcePath() .. "/Scripts/" .. SCRIPT_ID
local colorMarkerFile = managerDataRoot .. "/ColorMarkers.txt"

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

local tags = {}
local tag_file = managerDataRoot .. "/Tags.txt"
local presetSaveTags = {}
local preset_save_tag_file = managerDataRoot .. "/PresetSaveTags.txt"
local script_presets_file = managerDataRoot .. "/ScriptPresets.txt"

local allFXFolders = {}
local folders = {}
local fx_folders_file = managerDataRoot .. "/FXFolders.txt"

local allPresetFolders = {}
local presetFolders = {}
local preset_folders_file = managerDataRoot .. "/PresetFolders.txt"

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

local feedbackMessage = ""
local feedbackTimer = 0
local feedbackColor = 0x4488FFFF
local feedbackStyle = "text"
local FEEDBACK_DURATION = 1.0

local lastPresetCount = 0
local lastPresetFileTime = 0
local nextExternalCheckTime = 0
local filterCacheVersion = 0
local filteredCache = { signature = nil, presets = {}, indexMap = {} }
local preserveFilteredDuringColorRebuild = false


-- ===== PERFORMANCE / LARGE-BANK INFRASTRUCTURE =====
-- Production build: stress/debug profiler removed.
function profBegin() return 0 end
function profEnd(name, t0, visited) end
function gcMaintenance(units)
    -- Bounded incremental GC after allocation-heavy jobs. Never force a full
    -- collection per frame.
    collectgarbage('step', units or 96)
end

JOB_BUDGET_SEC = 0.0015
bankGeneration = 0
bankHeaderEnd = 0
bankLoading = false
activeLoadJob = nil
filterJob = nil
sortBuildJob = nil
sortCache = { az = nil, colors = nil }
metadataDirty = false
metadataRevision = 0
metadataWriteJob = nil
metadataWriteQueue = {}
activePluginMeta = nil
legacyColorMarkers = {}
legacyPresetFolders = {}
legacyFolders = {}
pluginsDir = managerDataRoot .. '/Plugins'
bankHeaderNorm = ''

function cancelFilterJob(runGC)
    local j = filterJob
    if not j then return end
    -- Break references immediately so completed/cancelled searches do not keep
    -- large ID/result arrays alive until a later major GC cycle.
    j.source = nil
    j.ids = nil
    j.result = nil
    filterJob = nil
    if runGC ~= false then gcMaintenance(96) end
end

function cancelSortBuildJob(runGC)
    local j = sortBuildJob
    if not j then return end
    j.src = nil
    j.dst = nil
    j.merge = nil
    sortBuildJob = nil
    if runGC ~= false then gcMaintenance(96) end
end

function invalidatePresetViewCache(preserveCurrentFiltered, sortImpact)
    filterCacheVersion = filterCacheVersion + 1
    filteredCache.signature = nil
    cancelFilterJob(false)
    preserveFilteredDuringColorRebuild = preserveCurrentFiltered and (#currentFilteredList > 0) or false

    -- Sort orders are independent from search/folder filters.  By default a
    -- structural/name/tooltip change invalidates every cached order.  Callers
    -- that only changed folders/search can pass "none"; color-only changes
    -- can pass "colors".
    if sortImpact == nil or sortImpact == 'all' then
        sortCache.az, sortCache.colors = nil, nil
        cancelSortBuildJob(false)
    elseif sortImpact == 'colors' then
        sortCache.colors = nil
        if sortBuildJob and sortBuildJob.mode == 'colors' then cancelSortBuildJob(false) end
    elseif sortImpact == 'az' then
        sortCache.az = nil
        if sortBuildJob and sortBuildJob.mode == 'az' then cancelSortBuildJob(false) end
    end
    gcMaintenance(64)
end

function invalidateFilterOnly(preserveCurrentFiltered)
    invalidatePresetViewCache(preserveCurrentFiltered, 'none')
end

function fnv1a32(str)
    local h = 0x811C9DC5
    for i = 1, #str do
        h = ((h ~ str:byte(i)) * 0x01000193) & 0xFFFFFFFF
    end
    return string.format('%08X', h)
end

-- Stable-preset identity support.  The fingerprint deliberately excludes Name
-- and Tooltip so rename/tooltip edits do not change preset identity.  It is
-- built incrementally while the native bank is already being streamed, so no
-- Data/Data_* payload is retained in Lua memory.
function fnv1a32Update(h, str)
    h = h or 0x811C9DC5
    str = tostring(str or '')
    for i = 1, #str do
        h = ((h ~ str:byte(i)) * 0x01000193) & 0xFFFFFFFF
    end
    return h
end

function feedPresetFingerprint(p, line)
    if not p or not line then return end
    local isPayload = line:sub(1,5) == 'Data=' or line:sub(1,5) == 'Data_' or line:sub(1,4) == 'Len='
    if not isPayload then return end
    p._fp1 = fnv1a32Update(p._fp1 or 0x811C9DC5, line)
    p._fp2 = fnv1a32Update(p._fp2 or 0x9E3779B9, line)
    p._fpBytes = (p._fpBytes or 0) + #line
end

function finalizePresetFingerprint(p)
    if not p then return '' end
    if p.fingerprint and p.fingerprint ~= '' then return p.fingerprint end
    if p._fp1 then
        p.fingerprint = string.format('%08X%08X:%d:%s', p._fp1 & 0xFFFFFFFF, (p._fp2 or 0) & 0xFFFFFFFF,
            p._fpBytes or 0, tostring(p.len or ''))
    else
        p.fingerprint = ''
    end
    p._fp1, p._fp2, p._fpBytes = nil, nil, nil
    return p.fingerprint
end

local stablePresetIDSerial = 0
function makeStablePresetID(p, usedIDs, identity)
    usedIDs = usedIDs or {}
    identity = tostring(identity or (activePluginMeta and activePluginMeta.identity) or '')
    local fp = finalizePresetFingerprint(p)
    while true do
        stablePresetIDSerial = stablePresetIDSerial + 1
        local seed = table.concat({identity, fp, tostring(p and p.sourceStart or 0), tostring(p and p.ordinal or 0), tostring(stablePresetIDSerial)}, '\31')
        local id = 'P' .. fnv1a32(seed) .. fnv1a32(seed .. '\31FSR')
        if not usedIDs[id] then usedIDs[id] = true; return id end
    end
end

-- Reattach the IDs from the previous index after an external bank rewrite.
-- Fingerprint is the primary key; name+Len is only a compatibility fallback
-- for the first migration from V3/V4, where fingerprints did not exist yet.
function reconcileStablePresetIDs(newList, oldList, identity)
    oldList = oldList or {}
    local usedOld, usedIDs = {}, {}
    local byFingerprint, byNameLen, byName = {}, {}, {}

    local function add(map, key, entry)
        if not key or key == '' then return end
        local t = map[key]
        if not t then t = {}; map[key] = t end
        t[#t+1] = entry
    end

    for i, p in ipairs(oldList) do
        if p and p.id and p.id ~= '' then
            usedIDs[p.id] = true
            add(byFingerprint, p.fingerprint, {i=i,p=p})
            add(byNameLen, tostring(p.name or '') .. '\31' .. tostring(p.len or ''), {i=i,p=p})
            add(byName, tostring(p.name or ''), {i=i,p=p})
        end
    end

    local function claim(candidates, p, newIndex)
        if not candidates then return nil end
        local best, bestScore
        for _, e in ipairs(candidates) do
            if not usedOld[e.i] and e.p and e.p.id and e.p.id ~= '' then
                local oldOrdinal = tonumber(e.p.ordinal) or (e.i - 1)
                local newOrdinal = tonumber(p.ordinal) or (newIndex - 1)
                local score = math.abs(oldOrdinal - newOrdinal)
                if e.p.name == p.name then score = score - 100000000 end
                if tostring(e.p.len or '') == tostring(p.len or '') then score = score - 1000000 end
                if not best or score < bestScore then best, bestScore = e, score end
            end
        end
        if best then
            usedOld[best.i] = true
            return best.p.id
        end
    end

    for i, p in ipairs(newList or {}) do
        finalizePresetFingerprint(p)
        local id
        if p.fingerprint and p.fingerprint ~= '' then id = claim(byFingerprint[p.fingerprint], p, i) end
        if not id then id = claim(byNameLen[tostring(p.name or '') .. '\31' .. tostring(p.len or '')], p, i) end
        if not id then id = claim(byName[tostring(p.name or '')], p, i) end
        if not id then id = makeStablePresetID(p, usedIDs, identity) else usedIDs[id] = true end
        p.id = id
    end
end

-- V2/V3/V4 stored color/folder bindings by preset name.  V5 stores them by
-- stable preset ID.  Duplicate names intentionally inherit the old metadata on
-- migration, matching the old behaviour instead of losing information.
function bindMetadataToStableIDs(meta, presets)
    if not meta then return false end
    local changed = false
    if meta.metadataKeyMode ~= 'id' then
        local oldFolders, oldColors = meta.presetFolders or {}, meta.colors or {}
        local newFolders, newColors = {}, {}
        for _, p in ipairs(presets or {}) do
            if p and p.id then
                local folder = oldFolders[p.name]
                local color = oldColors[p.name]
                if folder ~= nil then newFolders[p.id] = folder end
                if color ~= nil then newColors[p.id] = color end
            end
        end
        meta.presetFolders, meta.colors = newFolders, newColors
        meta.metadataKeyMode = 'id'
        changed = true
    else
        local valid = {}
        for _, p in ipairs(presets or {}) do if p and p.id then valid[p.id] = true end end
        for id in pairs(meta.presetFolders or {}) do if not valid[id] then meta.presetFolders[id] = nil; changed = true end end
        for id in pairs(meta.colors or {}) do if not valid[id] then meta.colors[id] = nil; changed = true end end
    end
    if meta == activePluginMeta then
        presetFolders = meta.presetFolders
        colorMarkers = meta.colors
    end
    return changed
end

function hexEncode(str)
    str = tostring(str or '')
    return (str:gsub('.', function(c) return string.format('%02X', c:byte()) end))
end
function hexDecode(hex)
    if not hex or (#hex % 2) ~= 0 then return '' end
    return (hex:gsub('(%x%x)', function(cc) return string.char(tonumber(cc,16)) end))
end

function safePluginStem(name)
    local s = tostring(name or 'Plugin'):gsub('[\\/:*?"<>|%c]', '_'):gsub('%s+', ' ')
    s = s:match('^%s*(.-)%s*$') or 'Plugin'
    if s == '' then s = 'Plugin' end
    if #s > 72 then s = s:sub(1,72) end
    return s
end

function makePluginIdentity(fxName, bankPath)
    local full = tostring(fxName or '') .. '\31' .. tostring(bankPath or '')
    return full, safePluginStem(fxName) .. '_' .. fnv1a32(full)
end

function safeReplaceFile(tmpPath, targetPath)
    local bakPath = targetPath .. '.fsr_bak'
    os.remove(bakPath)
    local hadTarget = reaper.file_exists(targetPath)
    if hadTarget then
        local ok = os.rename(targetPath, bakPath)
        if not ok then return false, 'Cannot create backup' end
    end
    local ok = os.rename(tmpPath, targetPath)
    if not ok then
        if hadTarget then os.rename(bakPath, targetPath) end
        return false, 'Cannot replace target'
    end
    return true
end

function getCheapFileSignature(path)
    if not path or path == '' then return '0' end
    local f = io.open(path, 'rb')
    if not f then return '0' end
    local size = f:seek('end') or 0
    local h = 0x811C9DC5
    local function mix(data)
        if not data then return end
        for i=1,#data do h = ((h ~ data:byte(i)) * 0x01000193) & 0xFFFFFFFF end
    end
    f:seek('set',0); mix(f:read(math.min(4096,size)))
    if size > 8192 then f:seek('set', math.max(0, math.floor(size/2)-2048)); mix(f:read(4096)) end
    if size > 4096 then f:seek('set', math.max(0,size-4096)); mix(f:read(4096)) end
    f:close()return tostring(size) .. ':' .. string.format('%08X', h)
end

function hexToken(str)
    local h = hexEncode(str or '')
    return h ~= '' and h or '-'
end

function unhexToken(tok)
    if not tok or tok == '-' then return '' end
    return hexDecode(tok)
end

-- FSR_PMETA_V5 compact text framing (V4-compatible string framing).  Arbitrary UTF-8 text stays readable
-- instead of being doubled as HEX.  Only line-breaking bytes and backslash
-- are escaped so every metadata record remains one physical text line.
function frameEscape(str)
    str = tostring(str or '')
    str = str:gsub('\\', '\\\\')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\n', '\\n')
    return str
end

function frameUnescape(str)
    str = tostring(str or '')
    return (str:gsub('\\(.)', function(c)
        if c == 'n' then return '\n' end
        if c == 'r' then return '\r' end
        if c == '\\' then return '\\' end
        return '\\' .. c -- preserve unknown/corrupt escape sequences losslessly
    end))
end

function frameToken(str)
    local payload = frameEscape(str)
    return tostring(#payload) .. ':' .. payload
end

function frameRead(line, pos)
    if not line then return nil, pos end
    pos = pos or 1
    local lineLen = #line
    while pos <= lineLen and line:sub(pos,pos):match('%s') do pos = pos + 1 end
    local colon = line:find(':', pos, true)
    if not colon then return nil, pos end
    local nstr = line:sub(pos, colon - 1)
    if nstr == '' or not nstr:match('^%d+$') then return nil, pos end
    local n = tonumber(nstr)
    if not n or n < 0 then return nil, pos end
    local first = colon + 1
    local last = first + n - 1
    if last > lineLen then return nil, pos end
    local payload = n == 0 and '' or line:sub(first, last)
    return frameUnescape(payload), last + 1
end

function signatureSize(sig)
    return tonumber(tostring(sig or ''):match('^(%d+):')) or 0
end

function readNormalizedBankHeader(path)
    if not path or path == '' then return '', 0 end
    local f = io.open(path, 'rb')
    if not f then return '', 0 end
    local parts, pos = {}, 0
    while true do
        local lineStart = pos
        local line = f:read('*L')
        if not line then break end
        pos = pos + #line
        if line:match('^%[Preset%d+%]') then
            f:close()
            local txt = table.concat(parts):gsub('NbPresets=%d+', 'NbPresets=#', 1)return txt, lineStart
        end
        parts[#parts+1] = line
        if pos > 1024 * 1024 then break end
    end
    f:close()local txt = table.concat(parts):gsub('NbPresets=%d+', 'NbPresets=#', 1)
    return txt, pos
end

function loadPluginMeta(fxName, bankPath)
    -- RecursiveCreateDirectory may report 0 when the directory already exists on some setups.
    -- Directory creation is therefore best-effort here; actual I/O success is decided by io.open below.
    ensurePresetDirectory(pluginsDir)
    local identity, stem = makePluginIdentity(fxName, bankPath)
    local path = pluginsDir .. '/' .. stem .. '.txt'
    local meta = {
        identity = identity, path = path, bankPath = bankPath or '', folders = {}, presetFolders = {}, colors = {},
        revision = 0, index = {}, indexSignature = nil, headerEnd = 0, headerNorm = '', ext = nil, indexComplete = false, expectedIndexCount = nil,
        loadedFromDisk = false, formatVersion = 5, needsV5Migration = false, metadataKeyMode = 'id'
    }
    local f = io.open(path, 'rb')
    if f then
        local magic = f:read('*l')
        local supported = magic == 'FSR_PMETA_V2' or magic == 'FSR_PMETA_V3' or magic == 'FSR_PMETA_V4' or magic == 'FSR_PMETA_V5'
        if supported then
            meta.loadedFromDisk = true
            meta.formatVersion = tonumber(tostring(magic):match('V(%d+)$')) or 0
            meta.needsV5Migration = magic ~= 'FSR_PMETA_V5'
            meta.metadataKeyMode = magic == 'FSR_PMETA_V5' and 'id' or 'name'
            for line in f:lines() do
                local tag = line:sub(1,1)
                if magic == 'FSR_PMETA_V4' or magic == 'FSR_PMETA_V5' then
                    if tag == 'I' then
                        local v = frameRead(line, 3); if v ~= nil then meta.identity = v end
                    elseif tag == 'B' then
                        local v = frameRead(line, 3); if v ~= nil then meta.bankPath = v end
                    elseif tag == 'S' then
                        meta.indexSignature = line:match('^S%s+(%S+)')
                    elseif tag == 'H' then
                        meta.headerEnd = tonumber(line:match('^H%s+(%-?%d+)')) or 0
                    elseif tag == 'N' then
                        meta.expectedIndexCount = tonumber(line:match('^N%s+(%d+)'))
                    elseif tag == 'Q' then
                        local v = frameRead(line, 3); if v ~= nil then meta.headerNorm = v end
                    elseif tag == 'E' then
                        local v = frameRead(line, 3); if v ~= nil then meta.ext = v end
                    elseif tag == 'F' then
                        local v = frameRead(line, 3); if v ~= nil then meta.folders[#meta.folders+1] = v end
                    elseif tag == 'P' then
                        local a, pos = frameRead(line, 3)
                        local b = a ~= nil and frameRead(line, pos) or nil
                        if a ~= nil and b ~= nil then meta.presetFolders[a] = b end
                    elseif tag == 'C' then
                        local a, pos = frameRead(line, 3)
                        local b = a ~= nil and tonumber(line:sub(pos):match('^%s+(%-?%d+)')) or nil
                        if a ~= nil and b ~= nil then meta.colors[a] = b end
                    elseif tag == 'R' then
                        local ord,ss,bs,se,ns,had,pos = line:match('^R%s+(%-?%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%-?%d+)%s+(%d+)%s+()')
                        if ord then
                            local name, tt, len, id, fingerprint
                            name, pos = frameRead(line, pos)
                            if name ~= nil then tt, pos = frameRead(line, pos) end
                            if tt ~= nil then len, pos = frameRead(line, pos) end
                            if len ~= nil then id, pos = frameRead(line, pos) end
                            if id ~= nil and magic == 'FSR_PMETA_V5' then fingerprint, pos = frameRead(line, pos) else fingerprint = '' end
                            if name ~= nil and tt ~= nil and len ~= nil and id ~= nil and fingerprint ~= nil then
                                meta.index[#meta.index+1] = {
                                    ordinal=tonumber(ord) or (#meta.index), sourceStart=tonumber(ss) or 0, bodyStart=tonumber(bs) or 0,
                                    sourceEnd=tonumber(se) or 0, nameStart=(tonumber(ns) or -1), name=name, nameLower=name:lower(),
                                    originalName=name, tooltip=tt, tooltipLower=tt:lower(), originalTooltip=tt, len=len,
                                    hadTooltip=(had=='1'), id=id ~= '' and id or nil, fingerprint=fingerprint or ''
                                }
                            end
                        end
                    end
                else
                    -- Backward-compatible V2/V3 reader.  These files are migrated to V5
                    -- after the native bank index is rebuilt.
                    if tag == 'I' then meta.identity = unhexToken(line:match('^I%s+(%S+)'))
                    elseif tag == 'B' then meta.bankPath = unhexToken(line:match('^B%s+(%S+)'))
                    elseif tag == 'S' then meta.indexSignature = line:match('^S%s+(%S+)')
                    elseif tag == 'H' then meta.headerEnd = tonumber(line:match('^H%s+(%-?%d+)')) or 0
                    elseif tag == 'N' then meta.expectedIndexCount = tonumber(line:match('^N%s+(%d+)'))
                    elseif tag == 'Q' then meta.headerNorm = unhexToken(line:match('^Q%s+(%S+)'))
                    elseif tag == 'E' then meta.ext = unhexToken(line:match('^E%s+(%S+)'))
                    elseif tag == 'F' then
                        local a = line:match('^F%s+(%S+)'); if a then meta.folders[#meta.folders+1] = unhexToken(a) end
                    elseif tag == 'P' then
                        local a,b = line:match('^P%s+(%S+)%s+(%S+)$'); if a and b then meta.presetFolders[unhexToken(a)] = unhexToken(b) end
                    elseif tag == 'C' then
                        local a,b = line:match('^C%s+(%S+)%s+(%S+)$'); if a and b then meta.colors[unhexToken(a)] = tonumber(b) end
                    elseif tag == 'R' and magic == 'FSR_PMETA_V3' then
                        local ord,ss,bs,se,ns,nameHex,ttHex,lenHex,had,idHex = line:match('^R%s+(%-?%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%-?%d+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%S+)$')
                        if ord then
                            local name, tt, len, id = unhexToken(nameHex), unhexToken(ttHex), unhexToken(lenHex), unhexToken(idHex)
                            meta.index[#meta.index+1] = {
                                ordinal=tonumber(ord) or (#meta.index), sourceStart=tonumber(ss) or 0, bodyStart=tonumber(bs) or 0,
                                sourceEnd=tonumber(se) or 0, nameStart=(tonumber(ns) or -1), name=name, nameLower=name:lower(),
                                originalName=name, tooltip=tt, tooltipLower=tt:lower(), originalTooltip=tt, len=len,
                                hadTooltip=(had=='1'), id=id ~= '' and id or nil
                            }
                        end
                    end
                end
            end
            meta.indexComplete = (magic == 'FSR_PMETA_V3' or magic == 'FSR_PMETA_V4' or magic == 'FSR_PMETA_V5')
                and meta.indexSignature ~= nil and meta.expectedIndexCount ~= nil and #meta.index == meta.expectedIndexCount
        end
        f:close()
    else
        local key = sanitizeFXName(fxName)
        local lf = allFXFolders[key]
        if lf then for i=1,#lf do meta.folders[#meta.folders+1] = lf[i] end end
        local lp = allPresetFolders[key]
        if lp then for n,folder in pairs(lp) do meta.presetFolders[n] = folder end end
        for n,c in pairs(legacyColorMarkers) do meta.colors[n] = c end
        if next(meta.presetFolders) ~= nil or next(meta.colors) ~= nil then
            meta.metadataKeyMode = 'name'
            meta.needsV5Migration = true
        end
    end
    return meta
end

function syncActiveMetaIndexState()
    local m = activePluginMeta
    if not m or m.bankPath ~= presetFile then return end
    m.indexSignature = lastPresetFileTime
    m.headerEnd = bankHeaderEnd or 0
    m.headerNorm = bankHeaderNorm or ''
    m.ext = presetFileExt or ''
    m.index = presetList
    m.indexComplete = true
    m.folders = folders
    m.presetFolders = presetFolders
    m.colors = colorMarkers
end

function makeMetaWriteSnapshot(m)
    if not m then return nil end
    if m == activePluginMeta then syncActiveMetaIndexState() end
    return {
        meta=m, path=m.path, identity=m.identity or '', bankPath=m.bankPath or '',
        indexSignature=m.indexSignature or '0', headerEnd=m.headerEnd or 0, headerNorm=m.headerNorm or '', ext=m.ext or '',
        folders=m.folders or {}, presetFolders=m.presetFolders or {}, colors=m.colors or {}, presets=m.index or {},
        revision=m.dirtyRevision or 0
    }
end

function enqueuePluginMetaWrite(m)
    if not m or not m.path or not m.dirty then return false end
    local rev = m.dirtyRevision or 0
    if m.queuedRevision == rev then return true end
    if metadataWriteJob and metadataWriteJob.snapshot.meta == m and metadataWriteJob.snapshot.revision == rev then return true end
    local snap = makeMetaWriteSnapshot(m)
    if not snap then return false end
    metadataWriteQueue[#metadataWriteQueue+1] = snap
    m.queuedRevision = rev
    return true
end

function startNextMetadataWriteJob()
    if metadataWriteJob then return true end
    while #metadataWriteQueue > 0 do
        local snap = table.remove(metadataWriteQueue, 1)
        local m = snap.meta
        if m and m.dirty then
            if (m.dirtyRevision or 0) ~= snap.revision then
                m.queuedRevision = nil
                enqueuePluginMetaWrite(m)
            else
                ensurePresetDirectory(pluginsDir)
                local tmp = snap.path .. '.fsr_tmp'
                os.remove(tmp)
                local f = io.open(tmp, 'wb')
                if f then
                    f:write('FSR_PMETA_V5\n')
                    f:write('I ', frameToken(snap.identity), '\n')
                    f:write('B ', frameToken(snap.bankPath), '\n')
                    f:write('S ', tostring(snap.indexSignature), '\n')
                    f:write('H ', tostring(snap.headerEnd), '\n')
                    f:write('N ', tostring(#snap.presets), '\n')
                    f:write('Q ', frameToken(snap.headerNorm), '\n')
                    f:write('E ', frameToken(snap.ext), '\n')
                    metadataWriteJob = {snapshot=snap,file=f,tmp=tmp,phase='folders',i=1,mapKey=nil,visited=0,t0=profBegin()}
                    return true
                else
                    m.queuedRevision=nil
                    if reaper.ShowConsoleMsg then
                        reaper.ShowConsoleMsg('[FSR Preset Manager] Cannot create plugin metadata TXT: ' .. tostring(tmp) .. '\n')
                    end
                end
            end
        elseif m then
            m.queuedRevision=nil
        end
    end
    return false
end

function abortMetadataWriteJob(job)
    if not job then return end
    if job.file then job.file:close(); job.file=nil end
    os.remove(job.tmp)
    local m=job.snapshot and job.snapshot.meta
    if m then
        m.queuedRevision=nil
        if m.dirty then enqueuePluginMetaWrite(m) end
    end
    metadataWriteJob=nil
end

function finishMetadataWriteJob(job)
    local snap=job.snapshot; local m=snap.meta
    if (m.dirtyRevision or 0) ~= snap.revision then abortMetadataWriteJob(job); return false end
    job.file:flush(); job.file:close(); job.file=nil
    local check=io.open(job.tmp,'rb')
    local valid=false
    if check then valid=(check:read('*l')=='FSR_PMETA_V5'); check:close() end
    if not valid then os.remove(job.tmp); m.queuedRevision=nil; metadataWriteJob=nil; return false end
    local replaced,why=safeReplaceFile(job.tmp,snap.path)
    metadataWriteJob=nil
    m.queuedRevision=nil
    if replaced then
        m.revision=(m.revision or 0)+1
        m.loadedFromDisk=true
        m.formatVersion=5
        m.needsV5Migration=false
        m.metadataKeyMode='id'
        if (m.dirtyRevision or 0)==snap.revision then m.dirty=false end
        if m==activePluginMeta then metadataDirty=m.dirty and true or false end
        profEnd('pluginMetaWrite',job.t0,job.visited)
        return true
    end
    m.dirty=true
    return false,why
end

function stepMetadataWriteJob(budgetEnd)
    local job=metadataWriteJob
    if not job then startNextMetadataWriteJob(); job=metadataWriteJob; if not job then return true end end
    local snap=job.snapshot; local m=snap.meta
    if not m or (m.dirtyRevision or 0) ~= snap.revision then abortMetadataWriteJob(job); return true end
    while reaper.time_precise() < budgetEnd do
        if job.phase=='folders' then
            local v=snap.folders[job.i]
            if v==nil then job.phase='presetFolders'; job.i=1; job.mapKey=nil
            else job.file:write('F ',frameToken(v),'\n'); job.i=job.i+1; job.visited=job.visited+1 end
        elseif job.phase=='presetFolders' then
            local k,v=next(snap.presetFolders,job.mapKey); job.mapKey=k
            if k==nil then job.phase='colors'; job.mapKey=nil
            else job.file:write('P ',frameToken(k),' ',frameToken(v),'\n'); job.visited=job.visited+1 end
        elseif job.phase=='colors' then
            local k,v=next(snap.colors,job.mapKey); job.mapKey=k
            if k==nil then job.phase='records'; job.i=1
            else job.file:write('C ',frameToken(k),' ',tostring(v),'\n'); job.visited=job.visited+1 end
        elseif job.phase=='records' then
            local p=snap.presets[job.i]
            if not p then return finishMetadataWriteJob(job) end
            local i=job.i
            job.file:write('R ',tostring(p.ordinal or (i-1)),' ',tostring(p.sourceStart or 0),' ',tostring(p.bodyStart or 0),' ',
                tostring(p.sourceEnd or 0),' ',tostring(p.nameStart or -1),' ',p.hadTooltip and '1' or '0',' ',
                frameToken(p.name or ''),' ',frameToken(p.tooltip or ''),' ',frameToken(p.len or ''),' ',frameToken(p.id or ''),' ',frameToken(p.fingerprint or ''),'\n')
            job.i=i+1; job.visited=job.visited+1
        end
    end
    return false
end

function saveActivePluginMeta()
    if not activePluginMeta then return false end
    syncActiveMetaIndexState()
    activePluginMeta.dirty=true
    activePluginMeta.dirtyRevision=activePluginMeta.dirtyRevision or metadataRevision
    enqueuePluginMetaWrite(activePluginMeta)
    startNextMetadataWriteJob()
    return true
end

function activatePluginMeta(fxName, bankPath)
    local identity = makePluginIdentity(fxName, bankPath)
    if activePluginMeta and activePluginMeta.identity == identity and activePluginMeta.bankPath == (bankPath or '') then
        folders = activePluginMeta.folders
        presetFolders = activePluginMeta.presetFolders
        colorMarkers = activePluginMeta.colors
        metadataDirty=activePluginMeta.dirty and true or false
        return activePluginMeta
    end
    activePluginMeta = loadPluginMeta(fxName, bankPath)
    if activePluginMeta then
        activePluginMeta.dirty=false
        activePluginMeta.dirtyRevision=activePluginMeta.dirtyRevision or 0
        activePluginMeta.queuedRevision=nil
        folders = activePluginMeta.folders
        presetFolders = activePluginMeta.presetFolders
        colorMarkers = activePluginMeta.colors
        metadataDirty=false
        invalidatePresetViewCache()
    end
    return activePluginMeta
end

function markMetadataDirty()
    metadataRevision = metadataRevision + 1
    metadataDirty = true
    if activePluginMeta then
        syncActiveMetaIndexState()
        activePluginMeta.dirty=true
        activePluginMeta.dirtyRevision=metadataRevision
        activePluginMeta.folders=folders
        activePluginMeta.presetFolders=presetFolders
        activePluginMeta.colors=colorMarkers
    end
end

function flushPluginMetadataIfDirty()
    if activePluginMeta and activePluginMeta.dirty then enqueuePluginMetaWrite(activePluginMeta) end
    startNextMetadataWriteJob()
end

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

local function invalidateColorDependentView()
    -- Color changes only invalidate the cached Color First order.  Ordinary
    -- A-Z/original-order searches keep their sort cache intact.
    sortCache.colors = nil
    if sortBuildJob and sortBuildJob.mode == 'colors' then sortBuildJob = nil end
    if filterByColor ~= nil or sortMode == "colors" then
        invalidatePresetViewCache(true, 'colors')
    end
end

function showFeedback(msg, color)
    feedbackMessage = msg
    feedbackTimer = reaper.time_precise() + FEEDBACK_DURATION
    -- Every transient notification uses the same full-width Search-field toast.
    feedbackStyle = "toast"
    -- All transient UI notifications use Accent 1, regardless of message type.
    feedbackColor = appearance.accentColor
end

local function showFolderToast(count, folder)
    local noun = (count == 1) and "preset" or "presets"
    feedbackMessage = "✓ " .. tostring(count) .. " " .. noun .. " → " .. tostring(folder)
    feedbackTimer = reaper.time_precise() + 1.25
    feedbackStyle = "toast"
    feedbackColor = appearance.accentColor
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
    ActivePreset = 0x4488FFFF,
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

sanitizeFXName = function(fx_name)
    if not fx_name or fx_name == "" then return "_unknown_" end
    local sanitized = fx_name:gsub("[|<>:\"/\\?*\n\r]", "_")
    sanitized = sanitized:gsub("^%s+", ""):gsub("%s+$", "")
    if sanitized == "" then return "_unknown_" end
    return sanitized
end

ensurePresetDirectory = function(path)
    if not path or path == "" then return false end
    if not reaper.RecursiveCreateDirectory then return false end

    -- Do not treat a 0 return as "directory unusable": on an already-created folder
    -- the API return value is not a reliable existence/writability test for our purposes.
    -- The following io.open at the actual write site is the authoritative check.
    reaper.RecursiveCreateDirectory(path, 0)
    return true
end

local function copyFile(source, destination)
    if not source or source == "" or not destination or destination == "" then return false end
    local sourceFile = io.open(source, "rb")
    if not sourceFile then return false end
    local destinationFile = io.open(destination, "wb")
    if not destinationFile then sourceFile:close(); return false end
    local ok = true
    while true do
        local chunk = sourceFile:read(1024 * 1024)
        if not chunk then break end
        if not destinationFile:write(chunk) then ok = false break end
    end
    destinationFile:flush()
    sourceFile:close(); destinationFile:close()return ok
end

local function openManagerDataFolder()
    ensurePresetDirectory(managerDataRoot)
ensurePresetDirectory(managerDataRoot .. "/Plugins")
    if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(managerDataRoot)
    elseif reaper.ExecProcess then
        local safePath = managerDataRoot:gsub('"', '""')
        reaper.ExecProcess('explorer.exe "' .. safePath .. '"', 0)
    else
        reaper.ShowMessageBox("Preset Manager folder: " .. managerDataRoot, "Preset Manager", 0)
    end
end

local function migrateLegacyManagerFiles()
    local legacyRoot = reaper.GetResourcePath() .. "/Scripts"
    local files = {
        { legacyRoot .. "/" .. SCRIPT_ID .. "_ColorMarkers.txt", colorMarkerFile },
        { legacyRoot .. "/" .. SCRIPT_ID .. "_Tags.txt", tag_file },
        { legacyRoot .. "/" .. SCRIPT_ID .. "_PresetSaveTags.txt", preset_save_tag_file },
        { legacyRoot .. "/" .. SCRIPT_ID .. "_ScriptPresets.txt", script_presets_file },
        { legacyRoot .. "/" .. SCRIPT_ID .. "_FXFolders.txt", fx_folders_file },
        { legacyRoot .. "/" .. SCRIPT_ID .. "_PresetFolders.txt", preset_folders_file }
    }
    for _, pair in ipairs(files) do
        local legacyFile, newFile = pair[1], pair[2]
        if not reaper.file_exists(newFile) and reaper.file_exists(legacyFile) then
            copyFile(legacyFile, newFile)
        end
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
    activatePluginMeta(fx_name, presetFile)
    if not activePluginMeta then folders = {} end
end

local function SaveFolders()
    if activePluginMeta then
        activePluginMeta.folders = folders
        markMetadataDirty()
        return true
    end
    local key = sanitizeFXName(currentFXName)
    if key and key ~= "_unknown_" then allFXFolders[key] = folders end
    SaveAllFXFolders()
    return true
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
    -- Legacy compatibility writer. Normal operation uses one Plugins/<plugin>.txt file.
    local f = io.open(preset_folders_file, "w")
    if f then
        for fxName, presetMap in pairs(allPresetFolders) do
            for presetName, folderName in pairs(presetMap) do f:write(fxName .. "|" .. presetName .. "|" .. folderName .. "\n") end
        end
        f:close()
    end
end

local function LoadPresetFoldersForFX(fx_name)
    if activePluginMeta then presetFolders = activePluginMeta.presetFolders
    else
        local key = sanitizeFXName(fx_name)
        if not allPresetFolders[key] then allPresetFolders[key] = {} end
        presetFolders = allPresetFolders[key]
    end
    invalidateFilterOnly()
end

local function SavePresetFolders()
    if activePluginMeta then
        activePluginMeta.presetFolders = presetFolders
        markMetadataDirty()
        return true
    end
    local key = sanitizeFXName(currentFXName)
    if key and key ~= "_unknown_" then allPresetFolders[key] = presetFolders end
    SaveAllPresetFolders()
    return true
end

local function setPresetFolder(presetID, folderName)
    if not presetID or type(presetID) ~= "string" or presetID == "" then return end
    if folderName then presetFolders[presetID] = folderName else presetFolders[presetID] = nil end
    markMetadataDirty()
    invalidateFilterOnly()
end

function batchAssignFolder(indexSet, folderName)
    local changed = false
    for idx,v in pairs(indexSet or {}) do
        if v and presetList[idx] then
            local id = presetList[idx].id
            if id and presetFolders[id] ~= folderName then presetFolders[id] = folderName; changed = true end
        end
    end
    if changed then markMetadataDirty(); invalidateFilterOnly() end
    return changed
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
    invalidateFilterOnly()
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
    invalidateFilterOnly()
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
    legacyColorMarkers = {}
    local f = io.open(colorMarkerFile, "r")
    if f then
        for line in f:lines() do
            local name, color = line:match("^(.+)|(%d+)$")
            if name and color then legacyColorMarkers[name] = tonumber(color) end
        end
        f:close()
    end
    if not activePluginMeta then colorMarkers = legacyColorMarkers end
    invalidatePresetViewCache()
end

local function SaveColorMarkers()
    if activePluginMeta then
        activePluginMeta.colors = colorMarkers
        markMetadataDirty()
        return true
    end
    local f = io.open(colorMarkerFile, "w")
    if f then
        for name, color in pairs(colorMarkers) do f:write(name .. "|" .. tostring(color) .. "\n") end
        f:close();return true
    end
    return false
end

local function setColorMarker(presetID, color)
    if not presetID or presetID == '' then return end
    local oldColor = colorMarkers[presetID]
    if oldColor == color then return end
    if color then colorMarkers[presetID] = color else colorMarkers[presetID] = nil end
    markMetadataDirty()
    invalidateColorDependentView()
end

local function getColorMarker(presetID) return presetID and colorMarkers[presetID] or nil end

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
    -- Historical name kept for compatibility; now returns size + bounded sampled hash.
    return getCheapFileSignature(filepath)
end

function processPresetLine(job, line, lineStart, lineEnd, eol)
    if line:sub(-1) == '\r' then line = line:sub(1,-2) end
    if line:sub(1,4) == 'Ext=' then job.ext = line:sub(5); return end
    local ordinal = line:match('^%[Preset(%d+)%]$')
    if ordinal then
        if not job.firstPresetStart then job.firstPresetStart = lineStart end
        if job.current and job.current.name then
            job.current.sourceEnd = lineStart
            finalizePresetFingerprint(job.current)
            job.list[#job.list+1] = job.current
        end
        job.current = {
            ordinal = tonumber(ordinal) or #job.list,
            sourceStart = lineStart, bodyStart = lineEnd,
            sourceGeneration = job.generation,
            tooltip = ''
        }
        return
    end
    local p = job.current
    if not p then return end
    feedPresetFingerprint(p, line)
    if line:sub(1,5) == 'Name=' then
        local name=line:sub(6); p.name=name; p.nameLower=name:lower(); p.originalName=name; p.nameStart=lineStart; return
    end
    if line:sub(1,4) == 'Len=' then p.len=line:sub(5); return end
    if line:sub(1,8) == 'Tooltip=' then
        local tt=line:sub(9); p.tooltip=tt; p.tooltipLower=tt:lower(); p.originalTooltip=tt; p.hadTooltip=true; return
    end
end

function refreshMetaAfterBankChange()
    if activePluginMeta and activePluginMeta.bankPath == presetFile then
        syncActiveMetaIndexState()
        markMetadataDirty()
    end
end

function finalizeLoadJob(job)
    if job.current and job.current.name then
        job.current.sourceEnd = job.fileSize
        finalizePresetFingerprint(job.current)
        job.list[#job.list+1] = job.current
    end
    if job.file then job.file:close(); job.file=nil end
    if activeLoadJob ~= job or job.generation ~= bankGeneration then return end

    if job.mode == 'append' then
        local usedIDs = {}
        for _,p in ipairs(presetList) do if p.id then usedIDs[p.id] = true end end
        if job.delta ~= 0 then
            for _,p in ipairs(presetList) do
                p.sourceStart = (p.sourceStart or 0) + job.delta
                p.bodyStart = (p.bodyStart or 0) + job.delta
                p.sourceEnd = (p.sourceEnd or 0) + job.delta
                if p.nameStart and p.nameStart >= 0 then p.nameStart = p.nameStart + job.delta end
                p.sourceGeneration = job.generation
            end
        end
        for _,p in ipairs(job.list) do
            finalizePresetFingerprint(p)
            p.originalIndex = #presetList + 1
            p.ordinal = p.originalIndex - 1
            p.id = makeStablePresetID(p, usedIDs, activePluginMeta and activePluginMeta.identity or '')
            p.tooltipLower = p.tooltipLower or (p.tooltip or ''):lower()
            p.sourceGeneration = job.generation
            presetList[#presetList+1] = p
            if job.postLoadFolder then presetFolders[p.id] = job.postLoadFolder end
        end
        bankHeaderEnd = job.newHeaderEnd
        bankHeaderNorm = job.newHeaderNorm
        lastPresetCount = #presetList
        lastPresetFileTime = job.sourceSig
        activePresetName = getActivePresetName()
        bankLoading = false
        activeLoadJob = nil
        if #job.list > 0 and job.postLoadFolder then markMetadataDirty() end
        refreshMetaAfterBankChange()
        invalidatePresetViewCache()
        showFeedback('✓ Presets updated')
        profEnd('appendPresets', job.t0, job.visited)
        return
    end

    local previousIndex = activePluginMeta and activePluginMeta.index or nil
    for i,p in ipairs(job.list) do
        finalizePresetFingerprint(p)
        p.originalIndex = i
        p.ordinal = i-1
        p.tooltipLower = p.tooltipLower or (p.tooltip or ''):lower()
        p.sourceGeneration = job.generation
    end
    reconcileStablePresetIDs(job.list, previousIndex, activePluginMeta and activePluginMeta.identity or '')
    presetList = job.list
    if activePluginMeta then bindMetadataToStableIDs(activePluginMeta, presetList) end
    bankHeaderNorm, bankHeaderEnd = readNormalizedBankHeader(presetFile)
    presetFileExt = job.ext
    lastPresetCount = #presetList
    lastPresetFileTime = job.sourceSig or getCheapFileSignature(presetFile)
    activePresetName = getActivePresetName()
    bankLoading = false
    if job.postLoadFolder then
        local known = job.oldNames or {}
        local changed=false
        for _,p in ipairs(presetList) do
            if not known[p.name] then presetFolders[p.id]=job.postLoadFolder; changed=true end
        end
        if changed then markMetadataDirty() end
    end
    activeLoadJob = nil
    refreshMetaAfterBankChange()
    invalidatePresetViewCache()
    profEnd('loadPresets', job.t0, job.visited)
end

function stepLoadJob(job, budgetEnd)
    if job.cancelled or job.generation ~= bankGeneration then
        if job.file then job.file:close() end
        return true
    end
    while reaper.time_precise() < budgetEnd do
        local chunkStart = job.readPos
        local chunk = job.file:read(65536)if not chunk then
            if #job.lineBuf > 0 or job.lineTruncated then
                processPresetLine(job, job.lineBuf, job.lineStart, job.fileSize, '')
            end
            finalizeLoadJob(job)
            return true
        end
        job.readPos = job.readPos + #chunk
        local pos = 1
        while pos <= #chunk do
            local nl = chunk:find('\n', pos, true)
            if nl then
                local seg = chunk:sub(pos, nl - 1)
                if not job.lineTruncated then
                    local room = 65536 - #job.lineBuf
                    if #seg <= room then job.lineBuf = job.lineBuf .. seg
                    else job.lineBuf = job.lineBuf .. seg:sub(1, math.max(0, room)); job.lineTruncated = true end
                end
                local lineEnd = chunkStart + nl
                processPresetLine(job, job.lineBuf, job.lineStart, lineEnd, '\n')
                job.visited = job.visited + 1
                job.lineBuf, job.lineTruncated = '', false
                job.lineStart = lineEnd
                pos = nl + 1
            else
                local seg = chunk:sub(pos)
                if not job.lineTruncated then
                    local room = 65536 - #job.lineBuf
                    if #seg <= room then job.lineBuf = job.lineBuf .. seg
                    else job.lineBuf = job.lineBuf .. seg:sub(1, math.max(0, room)); job.lineTruncated = true end
                end
                break
            end
        end
    end
    return false
end

function useCachedPluginIndex(meta, sig, generation)
    if not meta or not meta.indexComplete or meta.indexSignature ~= sig or meta.needsV5Migration then return false end
    for _,p in ipairs(meta.index or {}) do
        if not p.id or p.id == '' or not p.fingerprint or p.fingerprint == '' then return false end
    end
    presetList = meta.index or {}
    for i,p in ipairs(presetList) do
        p.originalIndex = i
        p.ordinal = p.ordinal or (i-1)
        p.sourceGeneration = generation
        p.nameLower = p.nameLower or (p.name or ''):lower()
        p.tooltipLower = p.tooltipLower or (p.tooltip or ''):lower()
        p.originalName = p.name
        p.originalTooltip = p.tooltip or ''
    end
    bankHeaderEnd = meta.headerEnd or 0
    bankHeaderNorm = meta.headerNorm or ''
    if bankHeaderNorm == '' then bankHeaderNorm, bankHeaderEnd = readNormalizedBankHeader(presetFile) end
    presetFileExt = meta.ext ~= '' and meta.ext or nil
    lastPresetCount = #presetList
    lastPresetFileTime = sig
    bankLoading = false
    activeLoadJob = nil
    activePresetName = getActivePresetName()
    invalidatePresetViewCache()
    return true
end

local function loadPresets(tr, fx, keepSnapshot)
    if not tr then return end
    bankGeneration = bankGeneration + 1
    local generation = bankGeneration
    if activeLoadJob and activeLoadJob.file then activeLoadJob.file:close() end
    activeLoadJob = nil
    presetFileExt = nil
    presetFile = reaper.TrackFX_GetUserPresetFilename(tr, fx)
    if not keepSnapshot then presetList = {} end
    invalidatePresetViewCache()
    if not presetFile or presetFile == '' then lastPresetCount=0; lastPresetFileTime='0'; bankLoading=false; return end

    if currentFXName and currentFXName ~= '' then activatePluginMeta(currentFXName, presetFile) end
    local sig = getCheapFileSignature(presetFile)
    if activePluginMeta and useCachedPluginIndex(activePluginMeta, sig, generation) then return end

    -- Distinguish the first index build from a genuine change of an already cached bank.
    if activePluginMeta and activePluginMeta.needsV5Migration then
        showFeedback('Upgrading preset index...')
    elseif activePluginMeta and activePluginMeta.loadedFromDisk then
        showFeedback('Preset bank changed; rebuilding index...')
    else
        showFeedback('Building preset index...')
    end

    local f = io.open(presetFile, 'rb')
    if not f then lastPresetCount=0; lastPresetFileTime='0'; bankLoading=false; return end
    local size = f:seek('end') or 0; f:seek('set',0)
    bankLoading = true
    activeLoadJob = {
        file=f, fileSize=size, readPos=0, lineStart=0, lineBuf='', lineTruncated=false,
        list={}, ext=nil, current=nil, generation=generation, visited=0, t0=profBegin(), sourceSig=sig, mode='full'
    }
end

function copyRange(src, dst, startPos, endPos)
    if endPos <= startPos then return true end
    src:seek('set', startPos)
    local left = endPos - startPos
    while left > 0 do
        local chunk = src:read(math.min(left, 1024*1024))
        if not chunk or #chunk == 0 then return false end
        if not dst:write(chunk) then return false end
        left = left - #chunk
    end
    return true
end

function writeEditedPresetBody(src, dst, preset)
    src:seek('set', preset.bodyStart)
    local left = preset.sourceEnd - preset.bodyStart
    local sawTooltip, insertedTooltip = false, false
    while left > 0 do
        local line = src:read('*L')
        if not line then break end
        if #line > left then line = line:sub(1,left) end
        left = left - #line
        local core = line:gsub('[\r\n]+$','')
        local eol = line:sub(#core+1)
        if core:match('^Name=') then
            dst:write('Name=', preset.name or '', eol ~= '' and eol or '\n')
        elseif core:match('^Tooltip=') then
            sawTooltip = true
            if preset.tooltip and preset.tooltip ~= '' then dst:write('Tooltip=', preset.tooltip, eol ~= '' and eol or '\n') end
        elseif core == '' and not sawTooltip and not insertedTooltip and preset.tooltip and preset.tooltip ~= '' then
            dst:write('Tooltip=', preset.tooltip, eol ~= '' and eol or '\n')
            dst:write(line); insertedTooltip=true
        else
            dst:write(line)
        end
    end
    if not sawTooltip and not insertedTooltip and preset.tooltip and preset.tooltip ~= '' then dst:write('Tooltip=',preset.tooltip,'\n') end
    return true
end

local function savePresets()
    if bankLoading then showFeedback('Preset bank is still loading', 0xFFAA44FF); return false end
    if not presetFile or presetFile == '' then return false end
    local t0=profBegin()
    local sourceSig = getCheapFileSignature(presetFile)
    local src=io.open(presetFile,'rb'); if not src then return false end
    local tmp=presetFile..'.fsr_tmp'
    local dst=io.open(tmp,'wb'); if not dst then src:close(); return false end
    local newRanges = {}
    local newHeaderEnd = 0
    local ok,err=pcall(function()
        local firstStart = bankHeaderEnd or 0
        local header=''
        if firstStart>0 then src:seek('set',0); header=src:read(firstStart) or '' end
        if header == '' then header='[General]\n' .. (presetFileExt and ('Ext='..presetFileExt..'\n') or '') .. 'NbPresets=0\n\n' end
        if header:find('NbPresets=%d+') then header=header:gsub('NbPresets=%d+','NbPresets='..tostring(#presetList),1)
        else header=header .. 'NbPresets='..tostring(#presetList)..'\n\n' end
        dst:write(header)
        newHeaderEnd = dst:seek('cur') or #header
        for i,p in ipairs(presetList) do
            local sectionStart = dst:seek('cur') or 0
            dst:write('[Preset',tostring(i-1),']\n')
            local bodyStart = dst:seek('cur') or 0
            local dirty = (p.name ~= p.originalName) or ((p.tooltip or '') ~= (p.originalTooltip or ''))
            if dirty then writeEditedPresetBody(src,dst,p)
            else copyRange(src,dst,p.bodyStart,p.sourceEnd) end
            local sectionEnd = dst:seek('cur') or bodyStart
            local nameStart = -1
            if p.nameStart and p.nameStart >= 0 and p.bodyStart then nameStart = bodyStart + (p.nameStart - p.bodyStart) end
            newRanges[i] = {sourceStart=sectionStart, bodyStart=bodyStart, sourceEnd=sectionEnd, nameStart=nameStart}
        end
        dst:flush()
    end)
    src:close(); dst:close();if not ok then os.remove(tmp); return false end
    if getCheapFileSignature(presetFile) ~= sourceSig then os.remove(tmp); showFeedback('Preset bank changed externally; save cancelled',0xFF4444FF); return false end
    local replaced,why=safeReplaceFile(tmp,presetFile)
    if not replaced then showFeedback('Save failed: '..tostring(why),0xFF4444FF); return false end

    bankGeneration = bankGeneration + 1
    for i,p in ipairs(presetList) do
        local r = newRanges[i]
        p.sourceStart, p.bodyStart, p.sourceEnd, p.nameStart = r.sourceStart, r.bodyStart, r.sourceEnd, r.nameStart
        p.ordinal, p.originalIndex, p.sourceGeneration = i-1, i, bankGeneration
        p.originalName, p.originalTooltip = p.name, p.tooltip or ''
    end
    bankHeaderEnd = newHeaderEnd
    bankHeaderNorm, bankHeaderEnd = readNormalizedBankHeader(presetFile)
    lastPresetCount=#presetList
    lastPresetFileTime=getCheapFileSignature(presetFile)
    refreshMetaAfterBankChange()
    invalidatePresetViewCache(); profEnd('savePresets',t0,#presetList)
    return true
end

function verifyAppendAnchors(path, delta)
    if #presetList == 0 then return true end
    local f = io.open(path, 'rb'); if not f then return false end
    local samples = {1, math.floor(#presetList/4), math.floor(#presetList/2), math.floor(#presetList*3/4), #presetList}
    local seen = {}
    for _,idx in ipairs(samples) do
        if idx < 1 then idx = 1 end
        if not seen[idx] then
            seen[idx]=true
            local p=presetList[idx]
            if p and p.sourceStart then
                f:seek('set', p.sourceStart + delta)
                local sec=(f:read('*l') or ''):gsub('\r$','')
                if sec ~= ('[Preset'..tostring(p.ordinal or (idx-1))..']') then f:close(); return false end
                if p.nameStart and p.nameStart >= 0 then
                    f:seek('set', p.nameStart + delta)
                    local nl=(f:read('*l') or ''):gsub('\r$','')
                    if nl ~= ('Name='..tostring(p.name or '')) then f:close(); return false end
                end
            end
        end
    end
    f:close();return true
end

function tryStartIncrementalAppend(newSig)
    local oldSize, newSize = signatureSize(lastPresetFileTime), signatureSize(newSig)
    if oldSize <= 0 or newSize <= oldSize then return false end
    local newNorm, newHeaderEnd = readNormalizedBankHeader(presetFile)
    if bankHeaderNorm == '' or newNorm ~= bankHeaderNorm then return false end
    local delta = newHeaderEnd - (bankHeaderEnd or 0)
    local appendStart = oldSize + delta
    if appendStart < newHeaderEnd or appendStart >= newSize then return false end
    if not verifyAppendAnchors(presetFile, delta) then return false end
    local f=io.open(presetFile,'rb'); if not f then return false end
    f:seek('set',appendStart)
    bankGeneration=bankGeneration+1
    bankLoading=true
    activeLoadJob={
        file=f,fileSize=newSize,readPos=appendStart,lineStart=appendStart,lineBuf='',lineTruncated=false,
        list={},ext=presetFileExt,current=nil,generation=bankGeneration,visited=0,t0=profBegin(),sourceSig=newSig,
        mode='append',delta=delta,newHeaderEnd=newHeaderEnd,newHeaderNorm=newNorm,postLoadFolder=currentFolder
    }
    return true
end

local function checkForExternalPresetChanges()
    if not presetFile or presetFile == '' or not track or fxnum == nil or bankLoading then return end
    local now=reaper.time_precise(); if now<nextExternalCheckTime then return end
    nextExternalCheckTime=now+0.8
    local sig=getCheapFileSignature(presetFile)
    if sig ~= lastPresetFileTime then
        if tryStartIncrementalAppend(sig) then return end
        local old={}; for _,p in ipairs(presetList) do old[p.name]=(old[p.name] or 0)+1 end
        local targetFolder=currentFolder
        loadPresets(track,fxnum,true)
        if activeLoadJob then activeLoadJob.postLoadFolder=targetFolder; activeLoadJob.oldNames=old end
        if activePluginMeta and activePluginMeta.loadedFromDisk then
            showFeedback('Preset bank changed; rebuilding index...')
        else
            showFeedback('Building preset index...')
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
        showFeedback("✓ FX restarted")
        return true
    end
    return false
end

local function switchToPreset(index)
    if track and fxnum and presetList[index] then
        reaper.TrackFX_SetPreset(track, fxnum, presetList[index].name)
        currentPresetIndex = index
        activePresetName = presetList[index].name
        selectedPresets = {}
        selectedPresets[index] = true
    end
end

refreshData = function()
    LoadTags() LoadPresetSaveTags() LoadColorMarkers()
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

local function openSavePresetModal()
    savePresetState.open = true
    savePresetState.input = ""
    savePresetState.autoFocus = true
end

local function saveNewPreset(presetName)
    if not track or not fxnum or presetName == "" then return false end
    if bankLoading then showFeedback('Preset bank is still loading', 0xFFAA44FF); return false end

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
        if not PresetFile or PresetFile == '' then return false end
        local sourceSig = reaper.file_exists(PresetFile) and getCheapFileSignature(PresetFile) or '0'
        local oldSize = signatureSize(sourceSig)
        local tmp = PresetFile .. '.fsr_tmp'
        local src = io.open(PresetFile, 'rb')
        local dst = io.open(tmp, 'wb')
        if not dst then if src then src:close() end return false end
        local n = lastPresetCount or #presetList
        if src then
            local headerDone=false
            while true do
                local line=src:read('*L')
                if not line then break end
                if not headerDone and line:match('^NbPresets=') then
                    dst:write('NbPresets=', tostring(n+1), line:match('\r\n$') and '\r\n' or '\n')
                    headerDone=true
                else dst:write(line) end
            end
            src:close()
            if not headerDone then dst:write('\nNbPresets=',tostring(n+1),'\n') end
        else
            dst:write('[General]\nNbPresets=',tostring(n+1),'\n')
        end
        local appendBoundary = dst:seek('cur') or 0
        dst:write('\n')
        local sectionStart = dst:seek('cur') or (appendBoundary+1)
        dst:write('[Preset',tostring(n),']\n')
        local bodyStart = dst:seek('cur') or 0
        local Len=#Preset_HEX; local pos=1; local part=0
        while pos<=Len do
            local Data=Preset_HEX:sub(pos,pos+32767)
            local Sum=Get_CtrlSum(Data)
            if part==0 then dst:write('Data=',Data,Sum,'\n') else dst:write('Data_',tostring(part),'=',Data,Sum,'\n') end
            part=part+1; pos=pos+32768
        end
        local nameStart = dst:seek('cur') or 0
        dst:write('Name=',Preset_Name,'\nLen=',tostring(Len//2),'\n')
        local sourceEnd = dst:seek('cur') or 0
        dst:flush(); dst:close();if reaper.file_exists(PresetFile) and getCheapFileSignature(PresetFile) ~= sourceSig then os.remove(tmp); return false end
        local ok,why = safeReplaceFile(tmp,PresetFile)
        if not ok then return false,why end
        return true,{oldSize=oldSize,delta=appendBoundary-oldSize,sourceStart=sectionStart,bodyStart=bodyStart,sourceEnd=sourceEnd,nameStart=nameStart,len=tostring(Len//2)}
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
    local FX_Type, FX_Chunk, PresetFile = Get_FX_Data(track, fxnum)
    if FX_Chunk and PresetFile then
        local Preset_HEX = FX_Chunk_to_HEX(FX_Type, FX_Chunk, presetName)
        local wrote, info = Write_to_File(PresetFile, Preset_HEX, presetName)
        if not wrote then showFeedback("Could not save preset bank", 0xFF4444FF); return false end
        presetFile = PresetFile
        bankGeneration = bankGeneration + 1
        if info and info.delta ~= 0 then
            for _,p in ipairs(presetList) do
                p.sourceStart=(p.sourceStart or 0)+info.delta; p.bodyStart=(p.bodyStart or 0)+info.delta; p.sourceEnd=(p.sourceEnd or 0)+info.delta
                if p.nameStart and p.nameStart >= 0 then p.nameStart=p.nameStart+info.delta end
                p.sourceGeneration=bankGeneration
            end
        end
        local np={name=presetName,nameLower=presetName:lower(),originalName=presetName,tooltip='',tooltipLower='',originalTooltip='',
                  len=info and info.len or '',ordinal=#presetList,originalIndex=#presetList+1,
                  sourceStart=info and info.sourceStart or 0,bodyStart=info and info.bodyStart or 0,sourceEnd=info and info.sourceEnd or 0,
                  nameStart=info and info.nameStart or -1,sourceGeneration=bankGeneration,hadTooltip=false}
        do
            local pos, part = 1, 0
            while pos <= #Preset_HEX do
                local Data = Preset_HEX:sub(pos,pos+32767)
                local Sum = Get_CtrlSum(Data)
                local line = part==0 and ('Data='..Data..Sum) or ('Data_'..tostring(part)..'='..Data..Sum)
                feedPresetFingerprint(np, line)
                pos=pos+32768; part=part+1
            end
            feedPresetFingerprint(np, 'Len='..tostring(np.len or ''))
            finalizePresetFingerprint(np)
            local usedIDs={}; for _,p in ipairs(presetList) do if p.id then usedIDs[p.id]=true end end
            np.id=makeStablePresetID(np,usedIDs,activePluginMeta and activePluginMeta.identity or '')
        end
        presetList[#presetList+1]=np
        lastPresetCount=#presetList
        bankHeaderNorm,bankHeaderEnd=readNormalizedBankHeader(PresetFile)
        lastPresetFileTime=getCheapFileSignature(PresetFile)
        reaper.TrackFX_SetPreset(track, fxnum, presetName)
        activePresetName = presetName
        if currentFolder then setPresetFolder(np.id, currentFolder) end
        refreshMetaAfterBankChange()
        invalidatePresetViewCache()
        return true
    end
    return false
end

local function getSelectedCount()
    local count=0
    for _,v in pairs(selectedPresets) do if v then count=count+1 end end
    selectedCount=count
    return count
end

local function delete()
    if bankLoading then return end
    if not presetFile or presetFile == '' then return end
    local deleteSet, deleteIDs, k = {}, {}, 0
    for i,v in pairs(selectedPresets) do
        if v and presetList[i] then deleteSet[i]=true; if presetList[i].id then deleteIDs[presetList[i].id]=true end; k=k+1 end
    end
    if k==0 then return end
    local compact={}; local n=0
    for i=1,#presetList do
        if not deleteSet[i] then n=n+1; compact[n]=presetList[i] end
    end
    for id in pairs(deleteIDs) do colorMarkers[id]=nil; presetFolders[id]=nil end
    presetList=compact; selectedPresets={}; selectedCount=0
    markMetadataDirty(); invalidatePresetViewCache()
    if savePresets() then reopenFXUIFast() end
end

local function clearColorMarkersForSelectedPresets()
    local changed = false
    for i, selected in pairs(selectedPresets) do
        if selected and presetList[i] then
            local presetID = presetList[i].id
            if presetID and colorMarkers[presetID] then
                colorMarkers[presetID] = nil
                changed = true
            end
        end
    end
    if changed then SaveColorMarkers(); invalidateColorDependentView() end
end

local function clearColorMarkersInActiveFolder()
    if not currentFolder or currentFolder == "" then return end
    local changed = false
    for _, preset in ipairs(presetList) do
        local presetID = preset.id
        if presetID and presetFolders[presetID] == currentFolder and colorMarkers[presetID] then
            colorMarkers[presetID] = nil
            changed = true
        end
    end
    if changed then SaveColorMarkers(); invalidateColorDependentView() end
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
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F5(), false) then
            restartFocusedFX()
            refreshData()
        end
        if currentFXName ~= "" and (
            reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F6(), false) or
            (ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_N(), false))
        ) then
            openNewFolderModal()
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

function currentFilterSignature()
    return table.concat({tostring(filterCacheVersion),searchQuery,tostring(filterByColor or ''),tostring(currentFolder or ''),sortMode},'\31')
end

function filterLessMode(mode, a, b)
    local pa,pb=presetList[a],presetList[b]
    if not pa or not pb then return a<b end
    if mode=='az' then
        local aa=pa.nameLower or (pa.name or ''):lower(); local bb=pb.nameLower or (pb.name or ''):lower()
        if aa==bb then return a<b end; return aa<bb
    elseif mode=='colors' then
        local ca,cb=colorMarkers[pa.id],colorMarkers[pb.id]
        local ap=ca and (colorPriority[ca] or 50) or 100; local bp=cb and (colorPriority[cb] or 50) or 100
        if ap~=bp then return ap<bp end
        local aa=pa.nameLower or (pa.name or ''):lower(); local bb=pb.nameLower or (pb.name or ''):lower()
        if aa==bb then return a<b end; return aa<bb
    end
    return a<b
end

function beginSortBuildJob(mode)
    if mode=='none' then return true end
    if sortCache[mode] then return true end
    if sortBuildJob and sortBuildJob.mode==mode then return false end
    sortBuildJob={mode=mode,phase='seed',i=1,src={},dst={},width=1,pairStart=1,merge=nil,t0=profBegin(),visited=0}
    return false
end

function stepSortBuildJob(deadline)
    local j=sortBuildJob
    if not j then return end
    local sliceT0=profBegin(); local visited0=j.visited
    while reaper.time_precise()<deadline do
        if j.phase=='seed' then
            local n=#presetList
            local limit=math.min(n,j.i+127)
            while j.i<=limit do
                j.src[j.i]=j.i
                j.i=j.i+1; j.visited=j.visited+1
            end
            if j.i>n then
                if n<2 then
                    sortCache[j.mode]=j.src; sortBuildJob=nil
                    profEnd('sortBuildLatency',j.t0,j.visited)
                    profEnd('sortBuildSlice',sliceT0,j.visited-visited0)
                    return
                end
                j.phase='sort'; j.width=1; j.pairStart=1
            end
        elseif j.phase=='sort' then
            local n=#j.src
            if j.width>=n then
                sortCache[j.mode]=j.src
                sortBuildJob=nil
                profEnd('sortBuildLatency',j.t0,j.visited)
                profEnd('sortBuildSlice',sliceT0,j.visited-visited0)
                return
            end
            if not j.merge then
                if j.pairStart>n then
                    j.src,j.dst=j.dst,{}
                    j.width=j.width*2; j.pairStart=1
                else
                    local l=j.pairStart; local m=math.min(l+j.width-1,n); local r=math.min(l+2*j.width-1,n)
                    j.merge={m=m,r=r,a=l,b=m+1,k=l}; j.pairStart=r+1
                end
            else
                local m=j.merge; local steps=0
                while m.k<=m.r and steps<64 and reaper.time_precise()<deadline do
                    local takeA
                    if m.a>m.m then takeA=false
                    elseif m.b>m.r then takeA=true
                    else takeA=filterLessMode(j.mode,j.src[m.a],j.src[m.b]) end
                    if takeA then j.dst[m.k]=j.src[m.a]; m.a=m.a+1 else j.dst[m.k]=j.src[m.b]; m.b=m.b+1 end
                    m.k=m.k+1; steps=steps+1; j.visited=j.visited+1
                end
                if m.k>m.r then j.merge=nil end
            end
        end
    end
    profEnd('sortBuildSlice',sliceT0,j.visited-visited0)
end

function beginFilterJob(signature)
    if filterJob then cancelFilterJob(true) end
    local source=nil
    if sortMode~='none' then
        source=sortCache[sortMode]
        if not source then beginSortBuildJob(sortMode); return false end
    end
    filterJob={signature=signature, version=filterCacheVersion, i=1, source=source,
        sourceN=source and #source or #presetList, ids={}, result={}, query=searchQuery:lower(),
        searchActive=(searchQuery~=''), color=filterByColor, folder=currentFolder,
        visited=0, publishI=1, phase='filter', t0=profBegin()}
    return true
end

function stepFilterJob(deadline)
    local j=filterJob; if not j then return end
    if j.signature~=currentFilterSignature() or j.version~=filterCacheVersion then cancelFilterJob(true); return end
    local sliceT0=profBegin(); local visited0=j.visited
    while reaper.time_precise()<deadline do
        if j.phase=='filter' then
            local limit=math.min(j.sourceN,j.i+63)
            local noMetaFilters=(j.color==nil and j.folder==nil)
            local searchActive=j.searchActive; local q=j.query
            while j.i<=limit do
                local pos=j.i
                local idx=j.source and j.source[pos] or pos
                local p=presetList[idx]
                local ok=(p~=nil)
                if ok and not noMetaFilters then
                    if j.color~=nil and colorMarkers[p.id]~=j.color then ok=false end
                    if ok and j.folder~=nil and presetFolders[p.id]~=j.folder then ok=false end
                end
                if ok and searchActive then
                    local nl=p.nameLower or (p.name or ''):lower()
                    ok=(nl:find(q,1,true)~=nil)
                end
                if ok then j.ids[#j.ids+1]=idx end
                j.i=pos+1; j.visited=j.visited+1
            end
            if j.i>j.sourceN then j.phase='publish'; j.publishI=1 end
        elseif j.phase=='publish' then
            local limit=math.min(#j.ids,j.publishI+255)
            while j.publishI<=limit do
                local idx=j.ids[j.publishI]
                j.result[j.publishI]=presetList[idx]
                j.publishI=j.publishI+1
            end
            if j.publishI>#j.ids then
                if j.signature==currentFilterSignature() and j.version==filterCacheVersion then
                    currentFilteredList=j.result; currentIndexMap=j.ids
                    filteredCache.signature=j.signature; filteredCache.presets=j.result; filteredCache.indexMap=j.ids
                    preserveFilteredDuringColorRebuild=false
                    profEnd('filterLatency',j.t0,j.visited)
                end
                local sliceVisited = j.visited - visited0
                -- Current/cache now own the published arrays. Drop the job's
                -- duplicate references and advance GC incrementally so rapid
                -- successive searches do not grow the heap indefinitely.
                j.source = nil
                j.ids = nil
                j.result = nil
                filterJob = nil
                gcMaintenance(128)
                profEnd('filterSlice',sliceT0,sliceVisited)
                return
            end
        end
    end
    profEnd('filterSlice',sliceT0,j.visited-visited0)
end

local function getFilteredPresets()
    local sig=currentFilterSignature()
    if filteredCache.signature==sig then
        currentFilteredList=filteredCache.presets; currentIndexMap=filteredCache.indexMap
        return currentFilteredList,currentIndexMap,sig
    end

    if sortMode~='none' and not sortCache[sortMode] then
        beginSortBuildJob(sortMode)
    elseif not filterJob or filterJob.signature~=sig then
        beginFilterJob(sig)
    end

    -- Keep the last consistent snapshot visible while a new sort/filter job is
    -- being built.  This avoids blank-list flashes and makes typing immediate.
    if #currentFilteredList>0 then return currentFilteredList,currentIndexMap,sig end
    return {},{},sig
end

local function formatPresetName(preset, displayIndex)
    if showNumbers then return tostring(displayIndex) .. ". " .. preset.name end
    return preset.name
end

local function drawColorPickerMenu(presetID)
    reaper.ImGui_Separator(ctx)
    for _, colorInfo in ipairs(availableColors) do
        local isSelected = (colorMarkers[presetID] == colorInfo.color)

        -- Keep the MenuItem itself full-width.  The marker is drawn afterwards
        -- on top of the hover/selected background, so the selector does not
        -- visually stop before the marker column.
        local label = "     " .. colorInfo.name
        local clicked = reaper.ImGui_MenuItem(ctx, label, nil, isSelected)

        if colorInfo.color then
            local minX, minY = reaper.ImGui_GetItemRectMin(ctx)
            local maxX, maxY = reaper.ImGui_GetItemRectMax(ctx)
            local rowH = maxY - minY
            local radius = math.min(5, math.max(3, rowH * 0.23))
            local centerX = minX + 11
            local centerY = minY + rowH * 0.5
            local drawList = reaper.ImGui_GetWindowDrawList(ctx)
            reaper.ImGui_DrawList_AddCircleFilled(drawList, centerX, centerY, radius, colorInfo.color)
        end

        if clicked then
            setColorMarker(presetID, colorInfo.color)
        end
    end
end

local rangeStartIndex = nil

local function drawPresetItem(preset, originalIndex, displayIndex, itemWidth)
    local selected = selectedPresets[originalIndex]
    local isActive = (preset.name == activePresetName)
    local markerColor = getColorMarker(preset.id)

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

    if showColorMarkers and markerColor then
        local dotX = itemMaxX - 12
        reaper.ImGui_DrawList_AddCircleFilled(drawList, dotX, itemCenterY, 4, markerColor)
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
        drawColorPickerMenu(preset.id)
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
            dragPresetName = preset.id
            if searchQuery == "" and filterByColor == nil and sortMode == "none" then
                reaper.ImGui_SetDragDropPayload(ctx, 'reorder_multi', tostring(originalIndex))
            else
                reaper.ImGui_SetDragDropPayload(ctx, "DND_PRESET_MULTI", "m")
            end
            reaper.ImGui_Text(ctx, selCount .. " presets selected")
        else
            dragSelectedPresets = {}
            dragPresetName = preset.id
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
                    local moved=presetList[fromIndex]; local rebuilt={}; local n=0
                    for i=1,#presetList do
                        if i==toIndex then n=n+1; rebuilt[n]=moved end
                        if i~=fromIndex then n=n+1; rebuilt[n]=presetList[i] end
                    end
                    if toIndex>#presetList then n=n+1; rebuilt[n]=moved end
                    presetList=rebuilt; selectedPresets={}; selectedCount=0
                    savePresets(); invalidatePresetViewCache(); showFeedback("✓ Preset moved")
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
                    local selectedSet={}; for _,idx in ipairs(selIndices) do selectedSet[idx]=true end
                    local moved={}; for _,idx in ipairs(selIndices) do moved[#moved+1]=presetList[idx] end
                    local adjustedTo=toIndex; for _,idx in ipairs(selIndices) do if idx<toIndex then adjustedTo=adjustedTo-1 end end
                    local remain={}; for i=1,#presetList do if not selectedSet[i] then remain[#remain+1]=presetList[i] end end
                    if adjustedTo<1 then adjustedTo=1 elseif adjustedTo>#remain+1 then adjustedTo=#remain+1 end
                    local rebuilt={}; local n=0
                    for i=1,#remain+1 do
                        if i==adjustedTo then for _,p in ipairs(moved) do n=n+1; rebuilt[n]=p end end
                        if remain[i] then n=n+1; rebuilt[n]=remain[i] end
                    end
                    presetList=rebuilt; selectedPresets={}; selectedCount=0; dragSelectedPresets={}
                    savePresets(); invalidatePresetViewCache(); showFeedback("✓ "..#selIndices.." presets moved")
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
        drawPresetItem(preset, originalIndex, displayIndex)
    end

    if lastVisible < totalPresets then
        reaper.ImGui_Dummy(ctx, 0, (totalPresets - lastVisible) * rowHeight)
    end
end

local function drawHorizontalPresetList(filteredPresets, indexMap, cacheSignature)
    local totalPresets=#filteredPresets; if totalPresets==0 then return end
    local rpc=math.max(1,math.floor(rowsPerColumn)); local numColumns=math.ceil(totalPresets/rpc)
    local rowHeight=getPresetRowHeight(); local columnHeight=rpc*rowHeight
    reaper.ImGui_PushStyleVar(ctx,reaper.ImGui_StyleVar_ScrollbarSize(),scrollbarSizeHorizontal)
    local flags=reaper.ImGui_WindowFlags_HorizontalScrollbar()+reaper.ImGui_WindowFlags_AlwaysHorizontalScrollbar()
    local _,availHeight=reaper.ImGui_GetContentRegionAvail(ctx)
    if BeginChild('HorizontalPresetList',0,availHeight,false,flags) then
        local scrollX=reaper.ImGui_GetScrollX(ctx); local windowW=reaper.ImGui_GetWindowWidth(ctx)
        local spacing=6; local span=columnWidth+spacing; local overscan=2
        local first=math.max(1,math.floor(scrollX/span)+1-overscan)
        local last=math.min(numColumns,first+math.ceil(windowW/span)+overscan*2)
        if reaper.ImGui_IsWindowHovered(ctx) then local w=reaper.ImGui_GetMouseWheel(ctx); if w~=0 then reaper.ImGui_SetScrollX(ctx,scrollX-w*50) end end
        if first>1 then reaper.ImGui_Dummy(ctx,(first-1)*span,columnHeight); reaper.ImGui_SameLine(ctx,0,0) end
        for col=first,last do
            if col>first then reaper.ImGui_SameLine(ctx) end
            reaper.ImGui_BeginGroup(ctx)
            local s=(col-1)*rpc+1; local e=math.min(col*rpc,totalPresets)
            -- Vertical clipping inside a visible column for extreme rowsPerColumn values.
            local sy=reaper.ImGui_GetScrollY(ctx); local wh=reaper.ImGui_GetWindowHeight(ctx)
            local r1=math.max(s, s+math.floor(sy/rowHeight)-2)
            local r2=math.min(e, s+math.ceil((sy+wh)/rowHeight)+2)
            if r1>s then reaper.ImGui_Dummy(ctx,0,(r1-s)*rowHeight) end
            for di=r1,r2 do drawPresetItem(filteredPresets[di],indexMap and indexMap[di] or di,di,columnWidth) end
            if r2<e then reaper.ImGui_Dummy(ctx,0,(e-r2)*rowHeight) end
            reaper.ImGui_EndGroup(ctx)
        end
        if last<numColumns then reaper.ImGui_SameLine(ctx,0,0); reaper.ImGui_Dummy(ctx,(numColumns-last)*span,columnHeight) end
        reaper.ImGui_EndChild(ctx)
    end
    reaper.ImGui_PopStyleVar(ctx,1)
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
                showFeedback("✓ Folder moved")
            end
        end

        local retval2, payload2 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET")
        if retval2 and dragPresetName then
            setPresetFolder(dragPresetName, folder)
            showFolderToast(1, folder)
            dragPresetName = nil
        end

        local retval3, payload3 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET_MULTI")
        if retval3 then
            local count = getSelectedCount()
            batchAssignFolder(dragSelectedPresets, folder)
            dragSelectedPresets = {}
            dragPresetName = nil
            showFolderToast(count, folder)
        end

        local retval4, payload4 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder")
        if retval4 and dragPresetName then
            setPresetFolder(dragPresetName, folder)
            showFolderToast(1, folder)
            dragPresetName = nil
        end

        local retval5, payload5 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder_multi")
        if retval5 then
            local count = getSelectedCount()
            batchAssignFolder(dragSelectedPresets, folder)
            dragSelectedPresets = {}
            dragPresetName = nil
            showFolderToast(count, folder)
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
                showFeedback("✓ Removed from folder")
                dragPresetName = nil
            end

            local retval2, payload2 = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_PRESET_MULTI")
            if retval2 then
                local count = getSelectedCount()
                batchAssignFolder(dragSelectedPresets, nil)
                dragSelectedPresets = {}
                dragPresetName = nil
                showFeedback("✓ " .. count .. " presets removed from folder")
            end

            local retval3, payload3 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder")
            if retval3 and dragPresetName then
                setPresetFolder(dragPresetName, nil)
                showFeedback("✓ Removed from folder")
                dragPresetName = nil
            end

            local retval4, payload4 = reaper.ImGui_AcceptDragDropPayload(ctx, "reorder_multi")
            if retval4 then
                local count = getSelectedCount()
                batchAssignFolder(dragSelectedPresets, nil)
                dragSelectedPresets = {}
                dragPresetName = nil
                showFeedback("✓ " .. count .. " presets removed from folder")
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
                    local p = idx and presetList[idx]
                    if p and renameState.input ~= p.name then
                        local oldName = p.name
                        p.name = renameState.input
                        p.nameLower = renameState.input:lower()
                        -- Color/folder metadata is keyed by p.id, so rename does not move or rewrite bindings.
                        markMetadataDirty(); invalidatePresetViewCache()
                        if activePresetName == oldName then activePresetName = renameState.input end
                        if savePresets() then reopenFXUIFast() end
                    end
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
        reaper.ImGui_TextDisabled(ctx, "Right-click a display preset and choose Set Hotkey... from the menu.")
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
            if reaper.ImGui_MenuItem(ctx, "Open Preset Manager Folder") then openManagerDataFolder() end
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
            if reaper.ImGui_MenuItem(ctx, "Clear All Color Markers") then colorMarkers = {}; SaveColorMarkers(); invalidateColorDependentView() end
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
            reaper.ImGui_BulletText(ctx, "F5 - Restart focused FX + Refresh data")
            reaper.ImGui_BulletText(ctx, "F6 / Ctrl+N - Create new folder")
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
    if activeLoadJob and activeLoadJob.file then activeLoadJob.file:close(); activeLoadJob.file=nil end
    if metadataWriteJob and metadataWriteJob.file then metadataWriteJob.file:close(); metadataWriteJob.file=nil end
end

function finishWritesAndExit()
    flushPluginMetadataIfDirty()
    local deadline=reaper.time_precise()+JOB_BUDGET_SEC
    if metadataWriteJob then stepMetadataWriteJob(deadline) end
    if (metadataWriteJob or #metadataWriteQueue>0 or (activePluginMeta and activePluginMeta.dirty)) then
        reaper.defer(finishWritesAndExit)
    else
        exit()
    end
end

local function loop()
    disableKeyboardNav()

    local jobsDeadline=reaper.time_precise()+JOB_BUDGET_SEC
    if activeLoadJob and reaper.time_precise()<jobsDeadline then stepLoadJob(activeLoadJob,jobsDeadline) end
    if metadataWriteJob and reaper.time_precise()<jobsDeadline then stepMetadataWriteJob(jobsDeadline) end
    if not metadataWriteJob and #metadataWriteQueue>0 and reaper.time_precise()<jobsDeadline then startNextMetadataWriteJob(); if metadataWriteJob then stepMetadataWriteJob(jobsDeadline) end end
    if sortBuildJob and reaper.time_precise()<jobsDeadline then stepSortBuildJob(jobsDeadline) end
    if filterJob and reaper.time_precise()<jobsDeadline then stepFilterJob(jobsDeadline) end

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
            flushPluginMetadataIfDirty()
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
            lastPresetFileTime = '0'
            bankGeneration = bankGeneration + 1; bankLoading=false; activeLoadJob=nil; activePluginMeta=nil
            invalidatePresetViewCache()
        elseif track and not reaper.ValidatePtr2(0, track, "MediaTrack*") then
            flushPluginMetadataIfDirty()
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
            lastPresetFileTime = '0'
            bankGeneration = bankGeneration + 1; bankLoading=false; activeLoadJob=nil; activePluginMeta=nil
            invalidatePresetViewCache()
        end

        if fxReallyChanged then
            flushPluginMetadataIfDirty()
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

        -- Capture the exact rendered bounds of the Search field.  Toast feedback
        -- uses these bounds so it always fills the whole field, including after
        -- dynamic window resizing / DPI changes.
        local searchRectMinX, searchRectMinY = reaper.ImGui_GetItemRectMin(ctx)
        local searchRectMaxX, searchRectMaxY = reaper.ImGui_GetItemRectMax(ctx)

        local isSearchActive = reaper.ImGui_IsItemActive(ctx)
        local drawList = reaper.ImGui_GetWindowDrawList(ctx)

        if not isSearchActive then
            local now = reaper.time_precise()
            if feedbackMessage ~= "" and now < feedbackTimer then
                local remaining = feedbackTimer - now
                local alpha = math.min(1.0, remaining / 0.3)
                local r = (feedbackColor >> 24) & 0xFF
                local g = (feedbackColor >> 16) & 0xFF
                local b = (feedbackColor >> 8) & 0xFF
                local a = math.floor(255 * alpha)
                local fadedColor = (r << 24) | (g << 16) | (b << 8) | a

                local _, textH = reaper.ImGui_CalcTextSize(ctx, feedbackMessage)
                local padX = 8

                -- Replace the whole Search field visually while feedback is active.
                -- Exact item bounds keep the toast aligned through resize/DPI changes.
                local x1 = searchRectMinX
                local y1 = searchRectMinY
                local x2 = searchRectMaxX
                local y2 = searchRectMaxY

                local bg = theme.PopupBg
                local br = (bg >> 24) & 0xFF
                local bgc = (bg >> 16) & 0xFF
                local bb = (bg >> 8) & 0xFF
                local ba = math.floor(235 * alpha)
                local fadedBg = (br << 24) | (bgc << 16) | (bb << 8) | ba

                local rounding = 5
                local textY = y1 + math.max(0, (y2 - y1 - textH) * 0.5)

                reaper.ImGui_DrawList_AddRectFilled(drawList, x1, y1, x2, y2, fadedBg, rounding)
                reaper.ImGui_DrawList_AddText(drawList, x1 + padX, textY, fadedColor, feedbackMessage)
            elseif feedbackMessage ~= "" and now >= feedbackTimer then
                feedbackMessage = ""
                feedbackStyle = "toast"
                if searchQuery == "" then
                    reaper.ImGui_DrawList_AddText(drawList, inputPosX + 5, inputPosY + 3, theme.PlaceholderText, "Search...")
                end
            elseif searchQuery == "" then
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
                if bankLoading then reaper.ImGui_TextDisabled(ctx, "Loading preset bank...")
                else reaper.ImGui_TextDisabled(ctx, "No presets found") end
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
                reaper.ImGui_BulletText(ctx, "F6 / Ctrl+N - Create new folder")
                reaper.ImGui_BulletText(ctx, "Right-click search field for tags")
                reaper.ImGui_PopStyleColor(ctx)
                reaper.ImGui_PopFont(ctx)
            end
            reaper.ImGui_EndChild(ctx)
        end

        drawRenameModal()
        drawSavePresetModal()
        drawFolderRenameModal()
        drawNewFolderModal()

        reaper.ImGui_End(ctx)
    end

    popTheme(themeColorCount)
    reaper.ImGui_PopStyleVar(ctx, 5)
    reaper.ImGui_PopFont(ctx)

    drawScriptPresetsWindow()
    flushPluginMetadataIfDirty()

    if open then reaper.defer(loop)
    else finishWritesAndExit() end
end

ensurePresetDirectory(managerDataRoot)
ensurePresetDirectory(managerDataRoot .. "/Plugins")
migrateLegacyManagerFiles()
LoadTags()
LoadPresetSaveTags()
LoadColorMarkers()
LoadScriptPresets()
LoadAllFXFolders()
LoadAllPresetFolders()

folders = {}
presetFolders = {}

reaper.atexit(exit)
reaper.defer(loop)
