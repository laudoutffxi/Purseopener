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

-- Which purse type we are opening this run: 'linen', 'cotton', or 'both'
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

-- Returns true when all 80 normal inventory slots are occupied.
-- Empty slots are identified by an item with Id == 0.
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
-- Commands: start + stop + UI
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

    -- Stop automatically if the normal inventory is full.
    -- Opening another purse while there is no free slot can cause
    -- the opener to keep trying without being able to receive items.
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
-- ImGui UI
---------------------------------------------------------------------

local function DrawPurseOpener()
    if not showWindow then
        return;
    end

    local linen, cotton = GetPurseCounts();
    local alex = GetInventoryItemCount(alexTerm);
    local totalPurses = linen + cotton;

    imgui.PushStyleColor(ImGuiCol_WindowBg, {0.10, 0.10, 0.10, 0.90});
    imgui.PushStyleColor(ImGuiCol_Border, {0.35, 0.35, 0.35, 1.0});

    local visible = imgui.Begin('PurseOpener Alexandrite', true);

    if visible then
        --------------------------------------------------
        -- HEADER
        --------------------------------------------------
        imgui.PushStyleColor(ImGuiCol_Text, {0.95, 0.85, 0.30, 1.0});
        imgui.Text('ALEXANDRITE PURSE OPENER');
        imgui.PopStyleColor();
        imgui.Separator();

        --------------------------------------------------
        -- INVENTORY SUMMARY
        --------------------------------------------------
        imgui.TextColored({0.92, 0.92, 0.92, 1.0}, 'Alexandrite in inventory:');
        imgui.SameLine();
        imgui.TextColored({0.35, 1.0, 0.45, 1.0}, tostring(alex));

        imgui.Separator();

        imgui.TextColored({0.92, 0.92, 0.92, 1.0}, 'Purses in inventory');
        imgui.Text(string.format('  Linen Purse:   %d', linen));
        imgui.Text(string.format('  Cotton Purse:  %d', cotton));
        imgui.Text(string.format('  Total Purses:  %d', totalPurses));

        local inventoryFull, usedSlots = IsInventoryFull();
        imgui.Text(string.format('Inventory: %d / 80 slots', usedSlots));

        if inventoryFull then
            imgui.TextColored({1.0, 0.30, 0.25, 1.0}, 'INVENTORY FULL — OPENER STOPPED');
        end

        imgui.Separator();

        --------------------------------------------------
        -- MODE + BUTTONS
        --------------------------------------------------
        imgui.TextColored({0.92, 0.92, 0.92, 1.0}, 'Opening mode: ' .. string.upper(mode));

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
        imgui.TextColored(active and {0.35, 1.0, 0.45, 1.0} or {1.0, 0.30, 0.25, 1.0},
            active and 'Status: RUNNING' or 'Status: STOPPED'
        );

        imgui.Separator();

        --------------------------------------------------
        -- COMMANDS
        --------------------------------------------------
        imgui.TextColored({0.60, 0.60, 0.60, 1.0}, 'Commands:');
        imgui.TextColored({0.60, 0.60, 0.60, 1.0}, '/openlinen   /opencotton   /openpurses');
        imgui.TextColored({0.60, 0.60, 0.60, 1.0}, '/stoppurses   /purseui');

        imgui.End();
    else
        imgui.End();
    end

    imgui.PopStyleColor(2);
end


ashita.events.register('d3d_present', 'purseopener_present', function()
    DrawPurseOpener();
end);






	















