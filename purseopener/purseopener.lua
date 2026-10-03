addon.name      = 'purseopener';
addon.author    = 'Laudout';
addon.version   = '2.1';
addon.desc      = 'Automatically opens Lin. Purse (Alx.) and Ctn. Purse (Alx.) items.';
addon.link      = '';

require('common');
local chat = require('chat');
local imgui = require('imgui');

local baseDelay = 2;
local active = false;
local nextAction = 0;

local showWindow = false;

local function IsInGame()
    local entity = GetEntity(0);
    return entity ~= nil and entity.Name ~= nil and entity.Name ~= '';
end

local linenTerm  = string.lower('Lin. Purse (Alx.)');
local cottonTerm = string.lower('Ctn. Purse (Alx.)');
local alexTerm   = string.lower('Alexandrite');

local mode = 'linen';

---------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------

local function GetInventoryItemCount(searchName)
    local invMgr = AshitaCore:GetMemoryManager():GetInventory();
    local total = 0;

    for i = 1,80 do
        local item = invMgr:GetContainerItem(0, i);

        if (item ~= nil and item.Id > 0 and item.Count > 0) then
            local res = AshitaCore:GetResourceManager():GetItemById(item.Id);

            if (res ~= nil and res.Name ~= nil and res.Name[1] ~= nil) then
                if string.lower(res.Name[1]) == searchName then
                    total = total + item.Count;
                end
            end
        end
    end

    return total;
end

local function GetPurseCounts()
    local linen = 0;
    local cotton = 0;

    local invMgr = AshitaCore:GetMemoryManager():GetInventory();

    for i = 1,80 do
        local item = invMgr:GetContainerItem(0, i);

        if (item ~= nil and item.Id > 0 and item.Count > 0) then
            local res = AshitaCore:GetResourceManager():GetItemById(item.Id);

            if (res ~= nil and res.Name ~= nil and res.Name[1] ~= nil) then
                local name = string.lower(res.Name[1]);

                if name == linenTerm then
                    linen = linen + item.Count;
                elseif name == cottonTerm then
                    cotton = cotton + item.Count;
                end
            end
        end
    end

    return linen, cotton;
end

local function IsInventoryFull()
    local invMgr = AshitaCore:GetMemoryManager():GetInventory();
    local used = 0;

    for i = 1,80 do
        local item = invMgr:GetContainerItem(0, i);

        if (item ~= nil and item.Id > 0) then
            used = used + 1;
        end
    end

    return used >= 80, used;
end

---------------------------------------------------------------------
-- Locate purse by mode
---------------------------------------------------------------------

local function LocatePurse()
    local invMgr = AshitaCore:GetMemoryManager():GetInventory();

    for i = 1,80 do
        local item = invMgr:GetContainerItem(0, i);

        if (item ~= nil and item.Id > 0) then
            local res = AshitaCore:GetResourceManager():GetItemById(item.Id);

            if (res ~= nil and res.Name ~= nil and res.Name[1] ~= nil) then
                local name = string.lower(res.Name[1]);

                if mode == 'linen' and name == linenTerm then
                    return item, res;
                end

                if mode == 'cotton' and name == cottonTerm then
                    return item, res;
                end

                if mode == 'both' then
                    if name == linenTerm or name == cottonTerm then
                        return item, res;
                    end
                end
            end
        end
    end

    return nil, nil;
end

---------------------------------------------------------------------
-- Session tracking (display only)
---------------------------------------------------------------------

local session = { opened = 0, alex_start = nil };

local function BeginRun(newMode)
    if newMode then mode = newMode; end
    if not active then
        session.opened = 0;
        session.alex_start = GetInventoryItemCount(alexTerm);
    end
    active = true;
    nextAction = 0;
end


---------------------------------------------------------------------
-- Open purse
---------------------------------------------------------------------

local function OpenPurse(item, res)
    local itemName = res.Name[1];

    AshitaCore:GetChatManager():QueueCommand(
        1,
        string.format('/item "%s" <me>', itemName)
    );

    nextAction = os.clock() + baseDelay;
    session.opened = session.opened + 1;
end

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------

ashita.events.register('command', 'purseopener_command', function(e)
    local cmd = string.lower(e.command);

    if cmd == '/openlinen' then
        mode = 'linen';
    elseif cmd == '/opencotton' then
        mode = 'cotton';
    elseif cmd == '/openpurses' then
        mode = 'both';
    elseif cmd == '/stoplinen' or cmd == '/stopcotton' or cmd == '/stoppurses' then
        active = false;
        print(chat.header('PurseOpener') .. chat.message('Stopped purse opener.'));
        e.blocked = true;
        return;
    elseif cmd == '/purseui' then
        showWindow = not showWindow;
        e.blocked = true;
        return;
    else
        return;
    end

    e.blocked = true;

    if active then
        print(chat.header('PurseOpener') .. chat.message('Already opening purses.'));
        return;
    end

    print(chat.header('PurseOpener') .. chat.message('Starting purse opener (' .. mode .. ')...'));
    BeginRun();
end);

---------------------------------------------------------------------
-- Purse opener
---------------------------------------------------------------------

ashita.events.register('packet_out', 'purseopener_packet', function(e)
    if not active then
        return;
    end

    if e.id ~= 0x15 then
        return;
    end

    if os.clock() < nextAction then
        return;
    end

    local inventoryFull, usedSlots = IsInventoryFull();

    if inventoryFull then
        active = false;
        print(chat.header('PurseOpener') ..
            chat.message('Inventory full (' .. usedSlots .. '/80 slots). Purse opener stopped.'));
        return;
    end

    local item, res = LocatePurse();

    if item == nil then
        print(chat.header('PurseOpener') .. chat.message('All purses opened (' .. mode .. ').'));
        active = false;
        return;
    end

    print(chat.header('PurseOpener') ..
        chat.message('Opening ') ..
        chat.color1(2, res.Name[1]) ..
        chat.message('.'));

    OpenPurse(item, res);
end);


---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------

local HUD = {
    accent    = { 0.30, 0.76, 1.00, 1.00 },
    accent2   = { 0.48, 0.86, 1.00, 1.00 },
    text      = { 0.94, 0.95, 0.98, 1.00 },
    subtext   = { 0.72, 0.76, 0.82, 1.00 },
    muted     = { 0.52, 0.57, 0.65, 1.00 },
    faint     = { 0.34, 0.39, 0.46, 1.00 },
    good      = { 0.40, 0.95, 0.58, 1.00 },
    warn      = { 1.00, 0.68, 0.28, 1.00 },
    bad       = { 1.00, 0.38, 0.32, 1.00 },
    alex      = { 0.78, 0.52, 1.00, 1.00 }, -- alexandrite violet
    linen     = { 0.92, 0.86, 0.70, 1.00 },
    cotton    = { 0.70, 0.86, 1.00, 1.00 },
    window_bg = { 0.028, 0.036, 0.052, 0.96 },
    header_bg = { 0.042, 0.068, 0.100, 1.00 },
    card      = { 0.062, 0.076, 0.104, 0.97 },
    card_line = { 1.00, 1.00, 1.00, 0.07 },
    track     = { 1.00, 1.00, 1.00, 0.08 },
};

local CORNERS_ALL = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;

local function rgba(c, a) return { c[1], c[2], c[3], a or c[4] }; end
local function col(c, a) return imgui.GetColorU32(rgba(c, a)); end
local function pulse(speed) return (math.sin(os.clock() * (speed or 3.0)) + 1.0) * 0.5; end
local function line_h() return tonumber(imgui.GetTextLineHeight()) or 13; end
local function text_w(s) return tonumber((imgui.CalcTextSize(s))) or 0; end
local function DL() return imgui.GetWindowDrawList(); end

local function text(x, y, c, s, scale)
    local dl = DL();
    if scale and scale ~= 1 and type(imgui.GetFont) == 'function' and type(imgui.GetFontSize) == 'function' then
        local ok = pcall(function() dl:AddText(imgui.GetFont(), imgui.GetFontSize() * scale, { x, y }, col(c), s); end);
        if ok then return; end
    end
    dl:AddText({ x, y }, col(c), s);
end

local function dot(cx, cy, r, c, glow)
    local dl = DL();
    if glow and glow > 0 then
        dl:AddCircleFilled({ cx, cy }, r * 2.4, col(c, 0.10 * glow), 20);
        dl:AddCircleFilled({ cx, cy }, r * 1.6, col(c, 0.22 * glow), 20);
    end
    dl:AddCircleFilled({ cx, cy }, r, col(c), 16);
end

local function pill_w(s) return text_w(s) + 14; end

local function pill(x, y, s, c, fill)
    local dl = DL();
    local w, h = pill_w(s), line_h() + 3;
    local top = y - 1.5;
    dl:AddRectFilled({ x, top }, { x + w, top + h }, col(c, fill or 0.15), h * 0.5);
    dl:AddRect({ x, top }, { x + w, top + h }, col(c, 0.50), h * 0.5, CORNERS_ALL, 1.0);
    dl:AddText({ x + 7, y }, col(c), s);
    return w;
end

local function bar(x, y, w, h, frac, c)
    local dl = DL();
    frac = math.max(0, math.min(1, frac));
    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(HUD.track), h * 0.5);
    if frac > 0 then
        dl:AddRectFilled({ x, y }, { x + math.max(h, w * frac), y + h }, col(c, 0.9), h * 0.5);
    end
end

local function card_bg(x, y, w, h, accent, strength)
    local dl = DL();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, col(HUD.card), 8);
    if accent then
        dl:AddRectFilledMultiColor({ x + 1, y + 1 }, { x + w * 0.6, y + h - 1 },
            col(accent, 0.08 * (strength or 1)), col(accent, 0), col(accent, 0), col(accent, 0.03 * (strength or 1)));
        dl:AddRect({ x, y }, { x + w, y + h }, col(accent, 0.30 * (strength or 1)), 8, CORNERS_ALL, 1.0);
    else
        dl:AddRect({ x, y }, { x + w, y + h }, col(HUD.card_line), 8, CORNERS_ALL, 1.0);
    end
end

-- Click target at an absolute position; leaves the layout cursor alone.
local function hit(id, x, y, w, h)
    local cx, cy = imgui.GetCursorScreenPos();
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    if hov then imgui.SetMouseCursor(ImGuiMouseCursor_Hand); end
    imgui.SetCursorScreenPos({ cx, cy });
    return clicked, hov;
end

local function fmt_time(sec)
    sec = math.max(0, math.floor(sec + 0.5));
    if sec >= 60 then return ('%dm %02ds'):format(math.floor(sec / 60), sec % 60); end
    return ('%ds'):format(sec);
end

local function PushStyle()
    imgui.PushStyleColor(ImGuiCol_WindowBg, HUD.window_bg);
    imgui.PushStyleColor(ImGuiCol_Border, { 0.30, 0.76, 1.00, 0.22 });
    imgui.PushStyleColor(ImGuiCol_Text, HUD.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 10.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 8 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 6, 6 });
end

local function PopStyle()
    imgui.PopStyleVar(4);
    imgui.PopStyleColor(3);
end

local function DrawPurseOpener()
    if not showWindow then
        return;
    end

    local linen, cotton = GetPurseCounts();
    local alex = GetInventoryItemCount(alexTerm);
    local totalPurses = linen + cotton;
    local inventoryFull, usedSlots = IsInventoryFull();
    local queued = (mode == 'linen' and linen) or (mode == 'cotton' and cotton) or totalPurses;

    PushStyle();
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_AlwaysAutoResize);

    if imgui.Begin('PurseOpener##purseopener_hud', true, flags) then
        local dl = DL();
        local lh = line_h();
        local u = text_w('0');
        local hint = '/openlinen  /opencotton  /openpurses  /stoppurses  /purseui';
        local W = math.max(44 * u, 300, text_w(hint) + 16);
        local x, y = imgui.GetCursorScreenPos();
        local wx, wy = imgui.GetWindowPos();
        local ww = imgui.GetWindowSize();

        -- Header band ------------------------------------------------
        local row_h = lh + 8;
        local band_bot = y + row_h + 5;
        dl:PushClipRect({ wx, wy }, { wx + ww, band_bot }, true);
        dl:AddRectFilled({ wx, y - 30 }, { wx + ww, band_bot + 12 }, col(HUD.header_bg), 10);
        dl:AddRectFilledMultiColor({ wx, y - 18 }, { wx + ww * 0.7, band_bot },
            col(HUD.alex, 0.12), col(HUD.alex, 0), col(HUD.alex, 0), col(HUD.alex, 0.04));
        dl:PopClipRect();
        dl:AddRectFilledMultiColor({ wx, band_bot - 1 }, { wx + ww, band_bot },
            col(HUD.alex, 0.8), col(HUD.alex, 0), col(HUD.alex, 0), col(HUD.alex, 0.8));

        text(x, y + (row_h - lh * 1.15) * 0.5, HUD.accent, 'PURSE OPENER', 1.15);

        -- close
        local bs = lh + 4;
        local bx, by = x + W - bs, y + (row_h - bs) * 0.5;
        local closed, chov = hit('##po_close', bx, by, bs, bs);
        if closed then showWindow = false; end
        if chov then dl:AddRectFilled({ bx, by }, { bx + bs, by + bs }, col(HUD.text, 0.10), 5); end
        local m, cc = bs * 0.32, chov and HUD.text or HUD.muted;
        dl:AddLine({ bx + m, by + m }, { bx + bs - m, by + bs - m }, col(cc), 1.5);
        dl:AddLine({ bx + bs - m, by + m }, { bx + m, by + bs - m }, col(cc), 1.5);

        -- status pill
        local status = active and 'RUNNING' or 'IDLE';
        local sc = active and HUD.good or HUD.muted;
        local sx = bx - 8 - pill_w(status) - 12;
        if active then dot(sx - 2, y + row_h * 0.5, 3, HUD.good, 0.5 + pulse(4) * 0.5); end
        pill(sx + 6, y + (row_h - lh) * 0.5, status, sc, active and 0.18 or 0.08);

        imgui.Dummy({ W, row_h });
        imgui.Dummy({ 0, 2 });

        -- Stat tiles -------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        local gap = 8;
        local tw = (W - gap * 2) / 3;
        local th = lh * 2.5 + 14;
        local tiles = {
            { 'ALEXANDRITE', alex,   HUD.alex },
            { 'LINEN',       linen,  HUD.linen },
            { 'COTTON',      cotton, HUD.cotton },
        };
        for i, t in ipairs(tiles) do
            local tx = x + (i - 1) * (tw + gap);
            local on = t[2] > 0;
            card_bg(tx, y, tw, th, on and t[3] or nil, i == 1 and 1 or 0.6);
            text(tx + 10, y + 7, HUD.muted, t[1]);
            text(tx + 10, y + 9 + lh, on and t[3] or HUD.faint, tostring(t[2]), 1.5);
        end
        imgui.Dummy({ W, th });

        -- Inventory ---------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        local ih = lh + 22;
        local frac = usedSlots / 80;
        local ic = inventoryFull and HUD.bad or (usedSlots >= 75 and HUD.warn or HUD.good);
        card_bg(x, y, W, ih, inventoryFull and HUD.bad or nil, inventoryFull and (0.6 + pulse(4) * 0.4) or 1);
        text(x + 10, y + 7, HUD.muted, 'INVENTORY');
        local slots = ('%d / 80'):format(usedSlots);
        text(x + W - 10 - text_w(slots), y + 7, inventoryFull and HUD.bad or HUD.text, slots);
        if inventoryFull then
            local full = 'FULL - OPENER STOPPED';
            text(x + 10 + text_w('INVENTORY') + 10, y + 7, HUD.bad, full);
        end
        bar(x + 10, y + ih - 9, W - 20, 4, frac, ic);
        imgui.Dummy({ W, ih });

        -- Mode selector ------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        text(x + 2, y + 5, HUD.muted, 'MODE');
        local modes = { { 'linen', 'Linen', linen }, { 'cotton', 'Cotton', cotton }, { 'both', 'Both', totalPurses } };
        local mx = x + text_w('MODE') + 14;
        local mw = (x + W - mx - 4 * 2) / 3;
        local mh = lh + 10;
        for _, md in ipairs(modes) do
            local on = mode == md[1];
            local clicked, hov = hit('##po_mode_' .. md[1], mx, y, mw, mh);
            if clicked then mode = md[1]; end
            if on then
                dl:AddRectFilled({ mx, y }, { mx + mw, y + mh }, col(HUD.accent, 0.16), 6);
                dl:AddRect({ mx, y }, { mx + mw, y + mh }, col(HUD.accent, 0.6), 6, CORNERS_ALL, 1.0);
            else
                dl:AddRectFilled({ mx, y }, { mx + mw, y + mh }, col(HUD.text, hov and 0.07 or 0.035), 6);
            end
            local label = ('%s  %d'):format(md[2], md[3]);
            text(mx + (mw - text_w(label)) * 0.5, y + 5, on and HUD.text or (hov and HUD.subtext or HUD.muted), label);
            mx = mx + mw + 4;
        end
        imgui.Dummy({ W, mh });

        -- Start / Stop -------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        local bh = lh + 16;
        local can_start = queued > 0 and not inventoryFull;
        local btn_c = active and HUD.bad or (can_start and HUD.good or HUD.faint);
        local label = active and 'STOP' or ('START  -  %d purse%s'):format(queued, queued == 1 and '' or 's');
        local clicked, hov = hit('##po_go', x, y, W, bh);
        if clicked then
            if active then active = false;
            elseif can_start then BeginRun(); end
        end
        local fill = active and (0.16 + pulse(3) * 0.08) or (hov and can_start and 0.26 or 0.14);
        dl:AddRectFilled({ x, y }, { x + W, y + bh }, col(btn_c, fill), 8);
        dl:AddRect({ x, y }, { x + W, y + bh }, col(btn_c, (hov or active) and 0.9 or 0.5), 8, CORNERS_ALL, 1.2);
        text(x + (W - text_w(label) * 1.1) * 0.5, y + (bh - lh * 1.1) * 0.5, btn_c, label, 1.1);
        imgui.Dummy({ W, bh });

        -- Progress line --------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        local info, info_c;
        if active then
            local gained = session.alex_start and (alex - session.alex_start) or 0;
            info = ('Opened %d  -  +%d Alexandrite  -  ~%s left'):format(session.opened, math.max(0, gained), fmt_time(queued * baseDelay));
            info_c = HUD.subtext;
        elseif session.opened > 0 then
            local gained = session.alex_start and (alex - session.alex_start) or 0;
            info = ('Last run: opened %d  -  +%d Alexandrite'):format(session.opened, math.max(0, gained));
            info_c = HUD.muted;
        elseif inventoryFull then
            info, info_c = 'Inventory full - free some space to keep opening.', HUD.bad;
        elseif queued == 0 then
            info, info_c = 'No purses for this mode in your inventory.', HUD.faint;
        else
            info, info_c = ('Ready - about %s for %d purse%s.'):format(fmt_time(queued * baseDelay), queued, queued == 1 and '' or 's'), HUD.faint;
        end
        text(x + (W - text_w(info)) * 0.5, y, info_c, info);
        imgui.Dummy({ W, lh });

        -- Footer ---------------------------------------------------------
        x, y = imgui.GetCursorScreenPos();
        text(x + (W - text_w(hint)) * 0.5, y, HUD.faint, hint);
        imgui.Dummy({ W, lh });
    end

    imgui.End();
    PopStyle();
end

ashita.events.register('d3d_present', 'purseopener_present', function()
    DrawPurseOpener();
end);
