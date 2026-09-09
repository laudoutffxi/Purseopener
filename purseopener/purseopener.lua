addon.name      = 'purseopener';
addon.author    = 'Laudout';
addon.version   = '2.0';
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
-- Open purse
---------------------------------------------------------------------

local function OpenPurse(item, res)
    local itemName = res.Name[1];

    AshitaCore:GetChatManager():QueueCommand(
        1,
        string.format('/item "%s" <me>', itemName)
    );

    nextAction = os.clock() + baseDelay;
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
    active = true;
    nextAction = 0;
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
-- FIXED BLUE HUD STYLE
---------------------------------------------------------------------

local colors = {
    window_bg = { 0.025, 0.035, 0.050, 0.97 },
    child_bg  = { 0.045, 0.050, 0.060, 0.94 },
    border    = { 0.10, 0.48, 0.72, 1.00 },
    separator = { 0.10, 0.36, 0.55, 0.90 },
    header    = { 0.35, 0.68, 1.00, 1.00 },
    text_main = { 0.92, 0.92, 0.92, 1.00 },
    text_dim  = { 0.60, 0.67, 0.74, 1.00 },
    good      = { 0.35, 1.00, 0.45, 1.00 },
    bad       = { 1.00, 0.30, 0.25, 1.00 },
};

local function PushBlueHudStyle()
    imgui.PushStyleColor(ImGuiCol_WindowBg, colors.window_bg);
    imgui.PushStyleColor(ImGuiCol_ChildBg, colors.child_bg);
    imgui.PushStyleColor(ImGuiCol_Border, colors.border);
    imgui.PushStyleColor(ImGuiCol_Separator, colors.separator);
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.025, 0.095, 0.145, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.035, 0.16, 0.24, 1.00 });
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0.025, 0.095, 0.145, 1.00 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, { 0.02, 0.035, 0.05, 0.90 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, { 0.08, 0.42, 0.66, 1.00 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, { 0.10, 0.55, 0.82, 1.00 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, { 0.12, 0.65, 0.95, 1.00 });

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6.0);
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6.0);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 3.0);
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0);
    imgui.PushStyleVar(ImGuiStyleVar_ChildBorderSize, 1.0);
end

local function PopBlueHudStyle()
    imgui.PopStyleVar(5);
    imgui.PopStyleColor(11);
end

---------------------------------------------------------------------
-- ImGui UI
---------------------------------------------------------------------

local function DrawPurseOpener()
    if not showWindow then
        return;
    end

    local linen, cotton = GetPurseCounts();
    local alex = GetInventoryItemCount(alexTerm);
    local totalPurses = linen + cotton;
    local inventoryFull, usedSlots = IsInventoryFull();

    PushBlueHudStyle();

    imgui.SetNextWindowSize({ 430, 360 }, ImGuiCond_FirstUseEver);

    local visible = imgui.Begin('PurseOpener - Alexandrite##purseopener_blue', true);

    if visible then
        imgui.PushStyleColor(ImGuiCol_Text, colors.header);
        imgui.Text('ALEXANDRITE PURSE OPENER');
        imgui.PopStyleColor();
        imgui.Separator();

        imgui.TextColored(colors.text_main, 'Alexandrite in inventory:');
        imgui.SameLine();
        imgui.TextColored(colors.good, tostring(alex));

        imgui.Separator();

        imgui.TextColored(colors.header, 'PURSES');
        imgui.TextColored(colors.text_main, string.format('Linen Purse:   %d', linen));
        imgui.TextColored(colors.text_main, string.format('Cotton Purse:  %d', cotton));
        imgui.TextColored(colors.text_main, string.format('Total Purses:  %d', totalPurses));

        imgui.Separator();

        imgui.TextColored(colors.text_main, string.format('Inventory: %d / 80 slots', usedSlots));

        if inventoryFull then
            imgui.TextColored(colors.bad, 'INVENTORY FULL - OPENER STOPPED');
        end

        imgui.Separator();

        imgui.TextColored(colors.text_main, 'Opening mode:');
        imgui.SameLine();
        imgui.TextColored(colors.header, string.upper(mode));

        if imgui.Button('Open Linen') then
            mode = 'linen';
            active = true;
            nextAction = 0;
        end

        imgui.SameLine();

        if imgui.Button('Open Cotton') then
            mode = 'cotton';
            active = true;
            nextAction = 0;
        end

        imgui.SameLine();

        if imgui.Button('Open Both') then
            mode = 'both';
            active = true;
            nextAction = 0;
        end

        if imgui.Button('STOP') then
            active = false;
        end

        imgui.SameLine();
        imgui.TextColored(active and colors.good or colors.bad,
            active and 'Status: RUNNING' or 'Status: STOPPED'
        );

        imgui.Separator();

        imgui.TextColored(colors.text_dim, 'Commands:');
        imgui.TextColored(colors.text_dim, '/openlinen   /opencotton   /openpurses');
        imgui.TextColored(colors.text_dim, '/stoppurses   /purseui');
    end

    imgui.End();
    PopBlueHudStyle();
end

ashita.events.register('d3d_present', 'purseopener_present', function()
    DrawPurseOpener();
end);






	















