--[[
-------------------------------------------------------------------------------------------
*              FSR Metronom Volume
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

local ctx = r.ImGui_CreateContext('MetroFullColor')

local EXT_SECTION = 'MetroVolSlider'
local SHOW_BORDER = true


------------------------------------------------------------
-- VOLUME RANGE
------------------------------------------------------------

local DB_PER_SLIDER_HEIGHT = 12.7433628318584


------------------------------------------------------------
-- DEFAULT COLOR
--
-- HEX: #008080
-- RGB: 0, 128, 128
------------------------------------------------------------

local DEFAULT_HUE = 0.5
local DEFAULT_SAT = 1.0
local DEFAULT_VAL = 0.5019607843137255


------------------------------------------------------------
-- COLOR / GUI SETTINGS
------------------------------------------------------------

local HUE =
    tonumber(
        r.GetExtState(
            EXT_SECTION,
            'hue'
        )
    )
    or DEFAULT_HUE


local SAT =
    tonumber(
        r.GetExtState(
            EXT_SECTION,
            'sat'
        )
    )
    or DEFAULT_SAT


local VAL =
    tonumber(
        r.GetExtState(
            EXT_SECTION,
            'val'
        )
    )
    or DEFAULT_VAL


local GUI_SCALE =
    tonumber(
        r.GetExtState(
            EXT_SECTION,
            'scale'
        )
    )
    or 1.5


local CONTRAST =
    tonumber(
        r.GetExtState(
            EXT_SECTION,
            'contrast'
        )
    )
    or 0.5


GUI_SCALE =
    math.max(
        0.8,
        math.min(
            2.5,
            GUI_SCALE
        )
    )


------------------------------------------------------------
-- REAPER METRONOME RANGE
------------------------------------------------------------

local MIN_METRO_VOL = 5e-51
local MAX_METRO_VOL = 3.981071705534973


------------------------------------------------------------
-- GUI METRICS
------------------------------------------------------------

local SLIDER_WIDTH
local SLIDER_HEIGHT
local PADDING

local WINDOW_WIDTH
local WINDOW_HEIGHT

local HUE_SLIDER_WIDTH
local SV_SIZE
local PICKER_PADDING

local PICKER_WIDTH
local PICKER_HEIGHT


local function updateGuiMetrics()

    SLIDER_WIDTH =
        math.floor(
            36 * GUI_SCALE
        )

    SLIDER_HEIGHT =
        math.floor(
            180 * GUI_SCALE
        )

    PADDING =
        math.floor(
            6 * GUI_SCALE
        )


    WINDOW_WIDTH =
        math.ceil(
            SLIDER_WIDTH +
            PADDING * 2
        )


    WINDOW_HEIGHT =
        math.ceil(
            SLIDER_HEIGHT +
            PADDING * 2
        )


    HUE_SLIDER_WIDTH =
        math.floor(
            20 * GUI_SCALE
        )


    SV_SIZE =
        math.floor(
            140 * GUI_SCALE
        )


    PICKER_PADDING =
        math.floor(
            6 * GUI_SCALE
        )


    PICKER_WIDTH =
        SV_SIZE +
        HUE_SLIDER_WIDTH +
        PICKER_PADDING * 3 +
        math.floor(
            18 * GUI_SCALE
        )


    PICKER_HEIGHT =
        SV_SIZE +
        PICKER_PADDING * 2
end


updateGuiMetrics()


------------------------------------------------------------
-- COLORS
------------------------------------------------------------

local function getHSVColor(
    h,
    s,
    v,
    a
)

    a = a or 1.0

    local rr,
          gg,
          bb =
        r.ImGui_ColorConvertHSVtoRGB(
            h,
            s,
            v
        )


    return
        r.ImGui_ColorConvertDouble4ToU32(
            rr,
            gg,
            bb,
            a
        )
end


local function updateColors()

    local hover_v =
        math.min(
            1,
            VAL + 0.12
        )


    local shadow_alpha =
        0.6 * CONTRAST


    return
        getHSVColor(
            HUE,
            SAT,
            VAL
        ),

        getHSVColor(
            HUE,
            SAT,
            hover_v
        ),

        getHSVColor(
            0,
            0,
            0,
            shadow_alpha
        )
end


local BLUE_TINT,
      BLUE_TINT_HOVER,
      SHADOW_COLOR =
    updateColors()


------------------------------------------------------------
-- RESET COLOR
------------------------------------------------------------

local function resetColor()

    HUE = DEFAULT_HUE
    SAT = DEFAULT_SAT
    VAL = DEFAULT_VAL

    BLUE_TINT,
    BLUE_TINT_HOVER,
    SHADOW_COLOR =
        updateColors()

    r.SetExtState(
        EXT_SECTION,
        'hue',
        tostring(HUE),
        true
    )

    r.SetExtState(
        EXT_SECTION,
        'sat',
        tostring(SAT),
        true
    )

    r.SetExtState(
        EXT_SECTION,
        'val',
        tostring(VAL),
        true
    )
end


------------------------------------------------------------
-- dB HELPERS
------------------------------------------------------------

local function roundToTenth(value)

    if value >= 0 then

        return
            math.floor(
                value * 10.0 + 0.5
            ) / 10.0

    else

        return
            math.ceil(
                value * 10.0 - 0.5
            ) / 10.0
    end
end


local function mainVolToDb(vol)

    if not vol
    or vol <= 0 then
        return nil
    end


    return
        20.0 *
        math.log(
            vol,
            10
        )
end


local function mainDbToVol(db)

    return
        10.0 ^
        (
            db / 20.0
        )
end


local function relativeVolToDb(
    v1,
    v2
)

    if not v1
    or not v2
    or v1 <= 0
    or v2 <= 0 then

        return nil
    end


    return
        20.0 *
        math.log(
            v2 / v1,
            10
        )
end


local function relativeDbToV2(
    v1,
    relative_db
)

    return
        v1 *
        (
            10.0 ^
            (
                relative_db /
                20.0
            )
        )
end


------------------------------------------------------------
-- DRAG STATE
------------------------------------------------------------

local current_vol = 0.5

local drag_start_mouse_y = nil

local drag_start_main_db = nil
local drag_reference_difference_db = nil

local drag_last_main_db = nil


------------------------------------------------------------
-- START DRAG
------------------------------------------------------------

local function beginVolumeDrag(mouse_y)

    local start_v1 =
        r.SNM_GetDoubleConfigVar(
            "projmetrov1",
            -1
        )


    local start_v2 =
        r.SNM_GetDoubleConfigVar(
            "projmetrov2",
            -1
        )


    if not start_v1
    or not start_v2
    or start_v1 <= 0
    or start_v2 <= 0 then

        drag_start_mouse_y = nil
        drag_start_main_db = nil
        drag_reference_difference_db = nil
        drag_last_main_db = nil

        return
    end


    local raw_main_db =
        mainVolToDb(
            start_v1
        )


    local raw_relative_db =
        relativeVolToDb(
            start_v1,
            start_v2
        )


    if not raw_main_db
    or not raw_relative_db then
        return
    end


    local displayed_main_db =
        roundToTenth(
            raw_main_db
        )


    local displayed_relative_db =
        roundToTenth(
            raw_relative_db
        )


    drag_reference_difference_db =
        displayed_main_db -
        displayed_relative_db


    drag_start_main_db =
        displayed_main_db


    drag_last_main_db =
        displayed_main_db


    drag_start_mouse_y =
        mouse_y
end


------------------------------------------------------------
-- APPLY DRAG
------------------------------------------------------------

local function applyVolumeDrag(mouse_y)

    if not drag_start_mouse_y
    or drag_start_main_db == nil
    or drag_reference_difference_db == nil then

        return
    end


    local delta_pixels =
        drag_start_mouse_y -
        mouse_y


    local movement_db =
        delta_pixels *
        (
            DB_PER_SLIDER_HEIGHT /
            SLIDER_HEIGHT
        )


    local target_main_db =
        roundToTenth(
            drag_start_main_db +
            movement_db
        )


    if drag_last_main_db ~= nil
    and target_main_db == drag_last_main_db then

        return
    end


    local target_relative_db =
        target_main_db -
        drag_reference_difference_db


    local requested_v1 =
        mainDbToVol(
            target_main_db
        )


    requested_v1 =
        math.max(
            MIN_METRO_VOL,
            math.min(
                MAX_METRO_VOL,
                requested_v1
            )
        )


    local actual_main_db =
        roundToTenth(
            mainVolToDb(
                requested_v1
            )
        )


    target_relative_db =
        actual_main_db -
        drag_reference_difference_db


    local requested_v2 =
        relativeDbToV2(
            requested_v1,
            target_relative_db
        )


    if requested_v2 < 1e-50 then
        requested_v2 = 1e-50
    end


    r.SNM_SetDoubleConfigVar(
        "projmetrov1",
        requested_v1
    )


    r.SNM_SetDoubleConfigVar(
        "projmetrov2",
        requested_v2
    )


    drag_last_main_db =
        actual_main_db


    r.UpdateArrange()
end


------------------------------------------------------------
-- FINISH DRAG
------------------------------------------------------------

local function finishVolumeDrag()

    drag_start_mouse_y = nil

    drag_start_main_db = nil
    drag_reference_difference_db = nil
    drag_last_main_db = nil

    r.UpdateArrange()
end


------------------------------------------------------------
-- FAST COLOR PICKER
------------------------------------------------------------

local function drawHueGradient(
    dl,
    x,
    y,
    w,
    h
)

    local segments = 32
    local segment_h = h / segments

    for i = 0, segments - 1 do

        local h1 =
            i / segments

        local h2 =
            (i + 1) / segments


        local c1 =
            getHSVColor(
                h1,
                1,
                1
            )

        local c2 =
            getHSVColor(
                h2,
                1,
                1
            )


        local y1 =
            y +
            i * segment_h

        local y2 =
            y +
            (i + 1) * segment_h


        r.ImGui_DrawList_AddRectFilledMultiColor(
            dl,

            x,
            y1,

            x + w,
            y2,

            c1,
            c1,
            c2,
            c2
        )
    end
end


local function drawSVSquare(
    dl,
    x,
    y,
    size
)

    local hue_color =
        getHSVColor(
            HUE,
            1.0,
            1.0
        )


    r.ImGui_DrawList_AddRectFilledMultiColor(
        dl,

        x,
        y,

        x + size,
        y + size,

        0xFFFFFFFF,
        hue_color,
        hue_color,
        0xFFFFFFFF
    )


    r.ImGui_DrawList_AddRectFilledMultiColor(
        dl,

        x,
        y,

        x + size,
        y + size,

        0x00000000,
        0x00000000,
        0xFF000000,
        0xFF000000
    )
end


------------------------------------------------------------
-- INITIAL POSITION
------------------------------------------------------------

local mouse_x,
      mouse_y =
    r.GetMousePosition()


if r.GetOS():match('^OSX')
or r.GetOS():match('^macOS') then

    local viewport =
        r.ImGui_GetMainViewport(
            ctx
        )


    local _,
          vp_y =
        r.ImGui_Viewport_GetPos(
            viewport
        )


    local _,
          vp_h =
        r.ImGui_Viewport_GetSize(
            viewport
        )


    mouse_y =
        (vp_y + vp_h) -
        mouse_y
end


local first_frame = true
local show_picker = false

local drag_scale_start_y = nil
local drag_scale_start_value = nil

local drag_contrast_start_y = nil
local drag_contrast_start_value = nil

local main_wx = 0
local main_wy = 0


------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------

local function main()

    r.ImGui_PushStyleVar(
        ctx,
        r.ImGui_StyleVar_WindowPadding(),
        0,
        0
    )


    r.ImGui_PushStyleVar(
        ctx,
        r.ImGui_StyleVar_ItemSpacing(),
        0,
        0
    )


    r.ImGui_PushStyleVar(
        ctx,
        r.ImGui_StyleVar_WindowBorderSize(),
        0
    )


    local flags =
        r.ImGui_WindowFlags_NoTitleBar() |
        r.ImGui_WindowFlags_NoResize() |
        r.ImGui_WindowFlags_NoScrollbar()


    --------------------------------------------------------
    -- MAIN WINDOW
    --------------------------------------------------------

    if first_frame then

        r.ImGui_SetNextWindowPos(
            ctx,

            mouse_x,
            mouse_y,

            r.ImGui_Cond_Always(),

            0.5,
            0.5
        )


        first_frame = false
    end


    r.ImGui_SetNextWindowSize(
        ctx,
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )


    local visible,
          open =
        r.ImGui_Begin(
            ctx,
            'MainVol',
            true,
            flags
        )


    if visible then

        local dl =
            r.ImGui_GetWindowDrawList(
                ctx
            )


        local wx,
              wy =
            r.ImGui_GetWindowPos(
                ctx
            )


        main_wx = wx
        main_wy = wy


        local tx =
            wx + PADDING


        local ty =
            wy + PADDING


        ----------------------------------------------------
        -- BACKGROUND
        ----------------------------------------------------

        r.ImGui_DrawList_AddRectFilled(
            dl,

            wx,
            wy,

            wx + WINDOW_WIDTH,
            wy + WINDOW_HEIGHT,

            0xFF000000,
            4
        )


        ----------------------------------------------------
        -- BORDER
        ----------------------------------------------------

        if SHOW_BORDER then

            local border_alpha =
                0x44000000


            local border_color =
                (BLUE_TINT & 0x00FFFFFF) |
                border_alpha


            r.ImGui_DrawList_AddRect(
                dl,

                wx,
                wy,

                wx + WINDOW_WIDTH,
                wy + WINDOW_HEIGHT,

                border_color,
                4
            )
        end


        ----------------------------------------------------
        -- SLIDER
        ----------------------------------------------------

        local handle_h =
            math.floor(
                12 * GUI_SCALE
            )


        if drag_start_mouse_y then

            local _,
                  my =
                r.ImGui_GetMousePos(
                    ctx
                )


            local delta =
                (
                    drag_start_mouse_y -
                    my
                )
                /
                (
                    SLIDER_HEIGHT *
                    1.5
                )


            current_vol =
                math.max(
                    0,
                    math.min(
                        1,
                        0.5 + delta
                    )
                )

        else

            current_vol = 0.5
        end


        local handle_y =
            ty +
            (
                SLIDER_HEIGHT -
                handle_h
            ) -
            (
                current_vol *
                (
                    SLIDER_HEIGHT -
                    handle_h
                )
            )


        local centerX =
            tx +
            SLIDER_WIDTH / 2


        local halfW =
            SLIDER_WIDTH / 2


        local fill_inset =
            math.max(
                1,
                math.floor(
                    2 * GUI_SCALE
                )
            )


        r.ImGui_DrawList_AddRectFilled(
            dl,

            centerX -
            halfW +
            fill_inset,

            handle_y,

            centerX +
            halfW -
            fill_inset,

            ty +
            SLIDER_HEIGHT,

            BLUE_TINT,
            3
        )


        local shadow_length =
            math.floor(
                22 *
                GUI_SCALE *
                CONTRAST
            )


        if shadow_length > 0 then

            r.ImGui_DrawList_AddRectFilledMultiColor(
                dl,

                centerX - halfW,

                handle_y +
                handle_h,

                centerX + halfW,

                handle_y +
                handle_h +
                shadow_length,

                SHADOW_COLOR,
                SHADOW_COLOR,

                0x00000000,
                0x00000000
            )
        end


        r.ImGui_DrawList_AddRectFilled(
            dl,

            centerX - halfW,
            handle_y,

            centerX + halfW,
            handle_y + handle_h,

            BLUE_TINT_HOVER,
            3
        )


        r.ImGui_DrawList_AddRect(
            dl,

            centerX - halfW,
            handle_y,

            centerX + halfW,
            handle_y + handle_h,

            0x33000000,
            3
        )


        ----------------------------------------------------
        -- INPUT
        ----------------------------------------------------

        r.ImGui_SetCursorScreenPos(
            ctx,
            tx,
            ty
        )


        r.ImGui_InvisibleButton(
            ctx,
            '##vol_btn',

            SLIDER_WIDTH,
            SLIDER_HEIGHT
        )


        if r.ImGui_IsItemActivated(
            ctx
        ) then

            local _,
                  my =
                r.ImGui_GetMousePos(
                    ctx
                )


            beginVolumeDrag(
                my
            )
        end


        if r.ImGui_IsItemActive(
            ctx
        ) then

            local _,
                  my =
                r.ImGui_GetMousePos(
                    ctx
                )


            applyVolumeDrag(
                my
            )


        elseif r.ImGui_IsItemClicked(
            ctx,
            1
        ) then

            show_picker =
                not show_picker
        end


        if not r.ImGui_IsMouseDown(
            ctx,
            0
        )
        and
        r.ImGui_IsItemDeactivated(
            ctx
        ) then

            finishVolumeDrag()

            open = false
        end


        ----------------------------------------------------
        -- ESC
        ----------------------------------------------------

        if r.ImGui_IsKeyPressed(
            ctx,
            r.ImGui_Key_Escape()
        ) then

            open = false
        end


        ----------------------------------------------------
        -- R = RESET COLOR
        ----------------------------------------------------

        if r.ImGui_IsKeyPressed(
            ctx,
            r.ImGui_Key_R()
        ) then

            resetColor()
        end


        r.ImGui_End(ctx)
    end


    --------------------------------------------------------
    -- COLOR PICKER
    --------------------------------------------------------

    if show_picker then

        r.ImGui_SetNextWindowPos(
            ctx,

            main_wx +
            WINDOW_WIDTH +
            math.floor(
                8 * GUI_SCALE
            ),

            main_wy,

            r.ImGui_Cond_Always()
        )


        r.ImGui_SetNextWindowSize(
            ctx,
            PICKER_WIDTH,
            PICKER_HEIGHT
        )


        local pvis,
              p_open =
            r.ImGui_Begin(
                ctx,
                'ColorPicker',
                true,
                flags
            )


        if pvis then

            local dl =
                r.ImGui_GetWindowDrawList(
                    ctx
                )


            local px,
                  py =
                r.ImGui_GetWindowPos(
                    ctx
                )


            local svx =
                px +
                PICKER_PADDING


            local svy =
                py +
                PICKER_PADDING


            local hxx =
                svx +
                SV_SIZE +
                PICKER_PADDING


            ------------------------------------------------
            -- BACKGROUND
            ------------------------------------------------

            r.ImGui_DrawList_AddRectFilled(
                dl,

                px,
                py,

                px + PICKER_WIDTH,
                py + PICKER_HEIGHT,

                0xFF000000,
                4
            )


            ------------------------------------------------
            -- COLOR FIELD
            ------------------------------------------------

            drawSVSquare(
                dl,
                svx,
                svy,
                SV_SIZE
            )


            drawHueGradient(
                dl,
                hxx,
                svy,
                HUE_SLIDER_WIDTH,
                SV_SIZE
            )


            ------------------------------------------------
            -- SCALE BUTTON
            ------------------------------------------------

            local btn_size =
                math.floor(
                    14 * GUI_SCALE
                )


            local icon_x =
                hxx +
                HUE_SLIDER_WIDTH +
                PICKER_PADDING


            local plus_y =
                svy + 4


            r.ImGui_SetCursorScreenPos(
                ctx,
                icon_x,
                plus_y
            )


            r.ImGui_InvisibleButton(
                ctx,
                '##scale_btn',
                btn_size,
                btn_size
            )


            local p_hover =
                r.ImGui_IsItemHovered(
                    ctx
                )


            local p_active =
                r.ImGui_IsItemActive(
                    ctx
                )


            local p_col =
                p_hover
                and 0xFFFFFFFF
                or 0xCCFFFFFF


            local cx =
                icon_x +
                btn_size / 2


            local cy =
                plus_y +
                btn_size / 2


            r.ImGui_DrawList_AddLine(
                dl,

                cx -
                btn_size * 0.3,

                cy,

                cx +
                btn_size * 0.3,

                cy,

                p_col,
                1
            )


            r.ImGui_DrawList_AddLine(
                dl,

                cx,

                cy -
                btn_size * 0.3,

                cx,

                cy +
                btn_size * 0.3,

                p_col,
                1
            )


            if p_active then

                local _,
                      my =
                    r.ImGui_GetMousePos(
                        ctx
                    )


                if not drag_scale_start_y then

                    drag_scale_start_y =
                        my


                    drag_scale_start_value =
                        GUI_SCALE
                end


                GUI_SCALE =
                    math.max(
                        0.8,
                        math.min(
                            2.5,

                            drag_scale_start_value +
                            (
                                drag_scale_start_y -
                                my
                            ) *
                            0.01
                        )
                    )


                updateGuiMetrics()


                r.SetExtState(
                    EXT_SECTION,
                    'scale',
                    tostring(
                        GUI_SCALE
                    ),
                    true
                )


            else

                drag_scale_start_y = nil
            end


            ------------------------------------------------
            -- CONTRAST BUTTON
            ------------------------------------------------

            local contrast_y =
                plus_y +
                btn_size +
                math.floor(
                    10 * GUI_SCALE
                )


            r.ImGui_SetCursorScreenPos(
                ctx,
                icon_x,
                contrast_y
            )


            r.ImGui_InvisibleButton(
                ctx,
                '##contrast_btn',
                btn_size,
                btn_size
            )


            local c_hover =
                r.ImGui_IsItemHovered(
                    ctx
                )


            local c_active =
                r.ImGui_IsItemActive(
                    ctx
                )


            local c_col =
                c_hover
                and 0xFFFFFFFF
                or 0xCCFFFFFF


            local dcx =
                icon_x +
                btn_size / 2


            local dcy =
                contrast_y +
                btn_size / 2


            r.ImGui_DrawList_AddCircleFilled(
                dl,

                dcx,
                dcy,

                btn_size * 0.2,

                c_col
            )


            if c_active then

                local _,
                      my =
                    r.ImGui_GetMousePos(
                        ctx
                    )


                if not drag_contrast_start_y then

                    drag_contrast_start_y =
                        my


                    drag_contrast_start_value =
                        CONTRAST
                end


                CONTRAST =
                    math.max(
                        0,
                        math.min(
                            1,

                            drag_contrast_start_value +
                            (
                                drag_contrast_start_y -
                                my
                            ) *
                            0.02
                        )
                    )


                BLUE_TINT,
                BLUE_TINT_HOVER,
                SHADOW_COLOR =
                    updateColors()


                r.SetExtState(
                    EXT_SECTION,
                    'contrast',
                    tostring(
                        CONTRAST
                    ),
                    true
                )


            else

                drag_contrast_start_y = nil
            end


            ------------------------------------------------
            -- SV
            ------------------------------------------------

            r.ImGui_SetCursorScreenPos(
                ctx,
                svx,
                svy
            )


            r.ImGui_InvisibleButton(
                ctx,
                '##sv_btn',
                SV_SIZE,
                SV_SIZE
            )


            if r.ImGui_IsItemActive(
                ctx
            ) then

                local mx,
                      my =
                    r.ImGui_GetMousePos(
                        ctx
                    )


                SAT =
                    math.max(
                        0,
                        math.min(
                            1,

                            (mx - svx) /
                            SV_SIZE
                        )
                    )


                VAL =
                    1 -
                    math.max(
                        0,
                        math.min(
                            1,

                            (my - svy) /
                            SV_SIZE
                        )
                    )


                BLUE_TINT,
                BLUE_TINT_HOVER,
                SHADOW_COLOR =
                    updateColors()
            end


            ------------------------------------------------
            -- HUE
            ------------------------------------------------

            r.ImGui_SetCursorScreenPos(
                ctx,
                hxx,
                svy
            )


            r.ImGui_InvisibleButton(
                ctx,
                '##hue_btn',

                HUE_SLIDER_WIDTH,
                SV_SIZE
            )


            if r.ImGui_IsItemActive(
                ctx
            ) then

                local _,
                      my =
                    r.ImGui_GetMousePos(
                        ctx
                    )


                HUE =
                    math.max(
                        0,
                        math.min(
                            1,

                            (my - svy) /
                            SV_SIZE
                        )
                    )


                BLUE_TINT,
                BLUE_TINT_HOVER,
                SHADOW_COLOR =
                    updateColors()
            end


            ------------------------------------------------
            -- MARKERS
            ------------------------------------------------

            r.ImGui_DrawList_AddCircle(
                dl,

                svx +
                SAT * SV_SIZE,

                svy +
                (
                    1 - VAL
                ) *
                SV_SIZE,

                4,
                0xFFFFFFFF
            )


            r.ImGui_DrawList_AddLine(
                dl,

                hxx - 2,

                svy +
                HUE *
                SV_SIZE,

                hxx +
                HUE_SLIDER_WIDTH +
                2,

                svy +
                HUE *
                SV_SIZE,

                0xFFFFFFFF,
                2
            )


            ------------------------------------------------
            -- R ALSO WORKS WHILE PICKER IS OPEN
            ------------------------------------------------

            if r.ImGui_IsKeyPressed(
                ctx,
                r.ImGui_Key_R()
            ) then

                resetColor()
            end


            ------------------------------------------------
            -- SAVE
            ------------------------------------------------

            r.SetExtState(
                EXT_SECTION,
                'hue',
                tostring(
                    HUE
                ),
                true
            )


            r.SetExtState(
                EXT_SECTION,
                'sat',
                tostring(
                    SAT
                ),
                true
            )


            r.SetExtState(
                EXT_SECTION,
                'val',
                tostring(
                    VAL
                ),
                true
            )


            r.ImGui_End(ctx)
        end


        if not p_open then
            show_picker = false
        end
    end


    r.ImGui_PopStyleVar(
        ctx,
        3
    )


    if open then
        r.defer(main)
    end
end


main()
