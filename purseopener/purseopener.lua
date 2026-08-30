addon.name      = 'purseopener';
addon.author    = 'Laudout';
addon.version   = '1.9';
addon.desc      = 'Automatically opens Lin. Purse (Alx.) and Ctn. Purse (Alx.) items.';
addon.link      = '';

require('common');
local chat = require('chat');

local baseDelay = 2;
local active = false;
local nextAction = 0;


local linenTerm  = string.lower('Lin. Purse (Alx.)');
local cottonTerm = string.lower('Ctn. Purse (Alx.)');

-- Which purse type we are opening this run: 'linen', 'cotton', or 'both'
local mode = 'linen';

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


local function OpenPurse(item, res)
    local itemName = res.Name[1];

    AshitaCore:GetChatManager():QueueCommand(
        1,
        string.format('/item "%s" <me>', itemName)
    )

    nextAction = os.clock() + baseDelay;
end

---------------------------------------------------------------------
-- Commands: start + stop
---------------------------------------------------------------------
ashita.events.register('command', 'purseopener_command', function(e)
    local cmd = string.lower(e.command);

    ---------------------------------------------------------
    -- START COMMANDS
    ---------------------------------------------------------
    if cmd == '/openlinen' then
        mode = 'linen';
    elseif cmd == '/opencotton' then
        mode = 'cotton';
    elseif cmd == '/openpurses' then
        mode = 'both';

    ---------------------------------------------------------
    -- STOP COMMANDS
    ---------------------------------------------------------
    elseif cmd == '/stoplinen' or cmd == '/stopcotton' or cmd == '/stoppurses' then
        active = false;
        print(chat.header('PurseOpener') .. chat.message('Stopped purse opener.'));
        e.blocked = true;
        return;

    else
        return;
    end

    -- Block command output
    e.blocked = true;

    if active then
        print(chat.header('PurseOpener') .. chat.message('Already opening purses.'));
        return;
    end

    print(chat.header('PurseOpener') .. chat.message('Starting purse opener (' .. mode .. ')...'));
    active = true;
    nextAction = 0;
end);


ashita.events.register('packet_out', 'purseopener_packet', function(e)
    if not active then
        return;
    end

    if (e.id ~= 0x15) then
        return;
    end

    if (os.clock() < nextAction) then
        return;
    end

    local item, res = LocatePurse();
    if item == nil then
        print(chat.header('PurseOpener') .. chat.message('All purses opened (' .. mode .. ').'));
        active = false;
        return;
    end

    print(chat.header('PurseOpener') .. chat.message('Opening ') .. chat.color1(2, res.Name[1]) .. chat.message('.'));
    OpenPurse(item, res);
end);






	















