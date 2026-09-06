--[[
-------------------------------------------------------------------------------------------
               FSR PINK NOISE GENERATOR
- Section      Main
- Author:      Andrew Dihtiaruk (FSR)
- Version:     1.00
-------------------------------------------------------------------------------------------  
- DESCRIPTION:
  Generates pink noise for the duration of the current REAPER time selection,
  saves it as a WAV file in the current project folder, and inserts the file
  into the project at the beginning of the time selection.
  
- Генерирует розовый шум длительностью, равной текущему временному выделению в REAPER,
  сохраняет его как WAV-файл в папке текущего проекта
  и вставляет файл в проект в начале выделенного участка.
-------------------------------------------------------------------------------------------  

- DONATION:     http://ko-fi.com/pianohousestudio    ««««« Double-click the link to open it.
                http://www.paypal.com/paypalme/AndriiDrots Double-click the link to open it

- Bug Reports: If you find any errors, please report them using the link below.

- Website:     
-------------------------------------------------------------------------------------------
--]]

local audioFormat   = 3
local nchans        = 1
local srate         = 44100
local bitspersample = 32
local Gain           = 0.8

-- Create Wave File

local function Create_Wave_File(FilePath, buf)
    local Pfmt
    if     audioFormat == 3 and bitspersample == 32 then Pfmt = "f"
    elseif audioFormat == 3 and bitspersample == 64 then Pfmt = "d"
    else return false
    end

    local numSamples = #buf
    if numSamples < 2 then return false end

    local out_buf = {}
    if nchans == 1 then
        out_buf = buf
    else
        local idx = 1
        for i = 1, numSamples do
            out_buf[idx]   = buf[i]
            out_buf[idx+1] = buf[i]
            idx = idx + 2
        end
    end

    local totalOut           = #out_buf
    local data_ChunkDataSize = totalOut * bitspersample / 8

    local RIFF_Chunk = string.pack("<c4 I4 c4",
        "RIFF", 36 + data_ChunkDataSize, "WAVE")

    local fmt_Chunk = string.pack("< c4 I4 I2 I2 I4 I4 I2 I2",
        "fmt ", 16, audioFormat, nchans, srate,
        srate * nchans * bitspersample / 8,
        nchans * bitspersample / 8,
        bitspersample)

    local data_Chunk = string.pack("< c4 I4", "data", data_ChunkDataSize)

    local file = io.open(FilePath, "wb")
    if not file then return false end

    local n        = 1024
    local rest     = totalOut % n
    local Data_buf = {}
    local b        = 1

    local Pfmt_full = "<" .. string.rep(Pfmt, n)
    for i = 1, totalOut - rest, n do
        Data_buf[b] = string.pack(Pfmt_full, table.unpack(out_buf, i, i + n - 1))
        b = b + 1
    end

    if rest > 0 then
        local Pfmt_rest = "<" .. string.rep(Pfmt, rest)
        Data_buf[b] = string.pack(Pfmt_rest,
            table.unpack(out_buf, totalOut - rest + 1, totalOut))
    end

    file:write(RIFF_Chunk, fmt_Chunk, data_Chunk, table.concat(Data_buf))
    file:close()
    return true
end

-- Generate Pink Noise

local function Gen_PinkNoise(duration)
    local numSamples  = math.floor(srate * duration)
    local buf         = {}
    local norm_factor = 1 / 6
    local b0,b1,b2,b3,b4,b5,b6 = 0,0,0,0,0,0,0

    for i = 1, numSamples do
        local white = 2 * math.random() - 1
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        local pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * norm_factor
        b6 = white * 0.115926
        buf[i] = math.max(-1, math.min(1, pink)) * Gain
    end

    return buf
end

-- Get File Path

local function Get_FilePath()
    local proj_path = reaper.GetProjectPathEx(0, "")
    local FilePath  = (proj_path .. "/PinkNoise"):gsub("\\", "/")
    local FP_i      = FilePath
    for i = 1, 999 do
        if reaper.file_exists(FP_i .. ".wav") then
            FP_i = FilePath .. "-" .. i
        else
            FilePath = FP_i .. ".wav"
            break
        end
    end
    return FilePath
end

-- Main

local function Main()
    local sel_start, sel_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local duration = sel_end - sel_start

    if duration <= 0 then
        reaper.MB("Please make a time selection!", "FCCR Pink Noise Generator", 0)
        return
    end

    local cursor_pos = reaper.GetCursorPosition()

    local buf      = Gen_PinkNoise(duration)
    local FilePath = Get_FilePath()

    if Create_Wave_File(FilePath, buf) then
        reaper.SetEditCurPos(sel_start, false, false)
        reaper.InsertMedia(FilePath, 0)
        reaper.SetEditCurPos(cursor_pos, false, false)
    end
end

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Generate FCCR Pink Noise", -1)

