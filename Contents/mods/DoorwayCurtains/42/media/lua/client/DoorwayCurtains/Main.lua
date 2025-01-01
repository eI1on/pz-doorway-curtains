require("Moveables/ISMoveableSpriteProps")
require("Moveables/ISMoveablesAction")

local DoorwayCurtainsModule = {}

Events.OnGameStart.Add(function()
    -- Table for Wall Mode Configurations
    DoorwayCurtainsModule.wallModeTable = {
        WallDoorframe = { N = { "WallN", "WallNW", "DoorWallN" }, W = { "WallW", "WallNW", "DoorWallW" } },
    };

    --- Function to get the wall object for a given direction and mode
    --- @param _square IsoGridSquare The grid square to check
    --- @param _dir string The direction to check (e.g., "N", "S", "E", "W")
    --- @param _mode string The mode to check (e.g., "WallDoorframe")
    --- @return IsoObject|nil object The wall object if found, or nil if not found
    function DoorwayCurtainsModule.getWallForFacing(_square, _dir, _mode)
        if not _dir then return nil; end
        if _dir == "N" then
            _square = _square and _square:getTileInDirection(IsoDirections.S);
        elseif _dir == "W" then
            _square = _square and _square:getTileInDirection(IsoDirections.E);
        end

        local lookup = DoorwayCurtainsModule.wallModeTable.WallDoorframe;
        if _mode and _mode ~= "WallDoorframe" and DoorwayCurtainsModule.wallModeTable[_mode] then
            lookup = DoorwayCurtainsModule.wallModeTable[_mode];
        end

        local square, tag1, tag2, tag3;
        if _dir == "S" or _dir == "N" then
            square, tag1, tag2, tag3 = _square, lookup.N[1], lookup.N[2], lookup.N[3];
        elseif _dir == "E" or _dir == "W" then
            square, tag1, tag2, tag3 = _square, lookup.W[1], lookup.W[2], lookup.W[3];
        end

        if square and (tag1 or tag2 or tag3) then
            if (tag1 and square:Is(tag1)) or (tag2 and square:Is(tag2)) or (tag3 and square:Is(tag3)) then
                for i = 0, square:getObjects():size() - 1 do
                    local obj = square:getObjects():get(i);
                    local sprite = obj:getSprite();
                    if sprite and sprite:getProperties() then
                        local props = sprite:getProperties();
                        if props then
                            if (tag1 and props:Is(tag1)) or (tag2 and props:Is(tag2)) or (tag3 and props:Is(tag3)) then
                                return obj;
                            end
                        end
                    end
                end
            end
        end
        return nil;
    end

    DoorwayCurtainsModule.oldCanPlaceMoveableInternal = ISMoveableSpriteProps.canPlaceMoveableInternal;
    --- Function to check if a moveable object can be placed
    --- @param _character IsoPlayer The character trying to place the item
    --- @param _square IsoGridSquare The square where the item is being placed
    --- @param _item InventoryItem The item being placed
    --- @param _forceTypeObject string Type of object being placed
    --- @return boolean|IsoObject validity Can the item be placed or not
    ---@diagnostic disable-next-line: duplicate-set-field
    function ISMoveableSpriteProps:canPlaceMoveableInternal(_character, _square, _item, _forceTypeObject)
        local canPlace = false;
        if _square and _square:isVehicleIntersecting() then return false; end

        if self.isMoveable then
            local hasTileFloor = _square and _square:getFloor();
            if not hasTileFloor and self.type ~= "Window" then
                return false;
            end
            if self.type == "WindowObject" then
                canPlace = self:hasFaces() and
                    DoorwayCurtainsModule.getWallForFacing(_square, self.facing, "WallDoorframe");
                if canPlace then
                    if _square:Is(IsoFlagType.exterior) or (_character:getSquare() and _character:getSquare():Is(IsoFlagType.exterior)) then
                        canPlace = false;
                    end
                end
                if canPlace then
                    for i = 0, _square:getObjects():size() - 1 do
                        local obj = _square:getObjects():get(i);
                        local sprite = obj:getSprite();
                        if sprite and sprite:getProperties() then
                            local props = sprite:getProperties();
                            if props then
                                if props:Is("MoveType") and props:Val("MoveType") == "WindowObject" then
                                    if props:Is("Facing") and props:Val("Facing") == self.facing then
                                        canPlace = false;
                                        break;
                                    end
                                end
                            end
                        end

                        if instanceof(obj, "IsoCurtain") then
                            if self.facing == "S" and obj:getType() == IsoObjectType.curtainN then
                                canPlace = false;
                                break;
                            end
                            if self.facing == "N" and obj:getType() == IsoObjectType.curtainS then
                                canPlace = false;
                                break;
                            end
                            if self.facing == "E" and obj:getType() == IsoObjectType.curtainW then
                                canPlace = false;
                                break;
                            end
                            if self.facing == "W" and obj:getType() == IsoObjectType.curtainE then
                                canPlace = false;
                                break;
                            end
                        end
                    end
                end
            end
            if not canPlace then
                return DoorwayCurtainsModule.oldCanPlaceMoveableInternal(self, _character, _square, _item,
                    _forceTypeObject);
            end
        end
        return canPlace;
    end

    DoorwayCurtainsModule.oldPlaceMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal;
    --- Function to place a moveable object at a given square
    --- @param _square IsoGridSquare The square where the item is placed
    --- @param _item InventoryItem The item being placed
    --- @param _spriteName string The name of the sprite to be used
    --- @return nil
    ---@diagnostic disable-next-line: duplicate-set-field
    function ISMoveableSpriteProps:placeMoveableInternal(_square, _item, _spriteName)
        if self.type == "WindowObject" then
            local north = self.facing and (self.facing == "N" or self.facing == "S");
            local wallFrame = DoorwayCurtainsModule.getWallForFacing(_square, self.facing, "WallDoorframe");
            if wallFrame then
                local obj = IsoCurtain.new(getCell(), _square, _spriteName, north);
                local objects = _square:getObjects();
                local insertIndex = objects:size();

                for i = 0, objects:size() - 1 do
                    local object = objects:get(i);
                    if object == wallFrame then
                        insertIndex = i + 1;
                        break;
                    end
                end

                if obj then
                    _square:AddSpecialObject(obj, insertIndex);
                    if isClient() then obj:transmitCompleteItemToServer(); end
                    triggerEvent("OnObjectAdded", obj);
                end
                return;
            end
        end
        return DoorwayCurtainsModule.oldPlaceMoveableInternal(self, _square, _item, _spriteName);
    end

    DoorwayCurtainsModule.oldSnapFaceToSquare = ISMoveableSpriteProps.snapFaceToSquare;
    --- Function to snap a face to a given square
    --- @param _square IsoGridSquare The square to snap to
    --- @return integer direction The direction of the snap (1-4)
    ---@diagnostic disable-next-line: duplicate-set-field
    function ISMoveableSpriteProps:snapFaceToSquare(_square)
        if self.isMoveable and self:hasFaces() then
            local faces = self:getFaces();
            if self.type == "WindowObject" then
                if faces.S and DoorwayCurtainsModule.getWallForFacing(_square, "S", "WallDoorframe") then
                    return 3;
                elseif faces.E and DoorwayCurtainsModule.getWallForFacing(_square, "E", "WallDoorframe") then
                    return 4;
                elseif faces.N and DoorwayCurtainsModule.getWallForFacing(_square, "N", "WallDoorframe") then
                    return 1;
                elseif faces.W and DoorwayCurtainsModule.getWallForFacing(_square, "W", "WallDoorframe") then
                    return 2;
                end
            end
        end
        return DoorwayCurtainsModule.oldSnapFaceToSquare(self, _square);
    end

    DoorwayCurtainsModule.oldWalkToAndEquip = ISMoveableSpriteProps.walkToAndEquip;
    --- Function to walk to and equip an item
    --- @param _character IsoPlayer The character walking to and equipping the item
    --- @param _square IsoGridSquare The square to walk to
    --- @param _mode string The mode in which the item is being used (e.g., "pickup", "place")
    --- @return boolean successful Whether the action was successful
    ---@diagnostic disable-next-line: duplicate-set-field
    function ISMoveableSpriteProps:walkToAndEquip(_character, _square, _mode)
        if self.type == "WindowObject" then
            local dir = self.facing;
            local windowFrame = DoorwayCurtainsModule.getWallForFacing(_square, dir, "WallDoorframe");
            if windowFrame then
                local dowalk = luautils.walkAdjWindowOrDoor(_character, _square, windowFrame, false);
                if dowalk and _mode ~= "scrap" then
                    local usesTool = (_mode == "pickup" and self.pickUpTool) or (_mode == "place" and self.placeTool);
                    if usesTool then
                        local tool = self:hasTool(_character, _mode);
                        if tool then
                            ISWorldObjectContextMenu.equip(_character, _character:getPrimaryHandItem(), tool:getType(),
                                true);
                            return true;
                        end
                    else
                        return true;
                    end
                end
            end
        end
        return DoorwayCurtainsModule.oldWalkToAndEquip(self, _character, _square, _mode);
    end
end)

--- @param object IsoObject
DoorwayCurtainsModule.onObjectAdded = function(object)
    if instanceof(object, "IsoCurtain") then
        local square = object:getSquare();
        local squareObjects = square:getObjects();
        local squareObjectsSize = squareObjects:size();

        local tempObjects = ArrayList:new();
        local doorIndex = -1;

        for i = 0, squareObjectsSize - 1 do
            if instanceof(squareObjects:get(i), "IsoDoor") then
                doorIndex = i;
                break;
            end
        end
        if doorIndex ~= -1 then
            for i = 0, squareObjectsSize - 1 do
                local obj = squareObjects:get(i);
                if not (instanceof(obj, "IsoCurtain") and obj == object) then
                    tempObjects:add(obj);
                end
            end
            squareObjects:clear();
            for i = 0, tempObjects:size() - 1 do
                local obj = tempObjects:get(i);
                if i == doorIndex then
                    squareObjects:add(object);
                end
                squareObjects:add(obj);
            end
            if tempObjects:size() == doorIndex then
                squareObjects:add(object);
            end
            square:RecalcProperties();
            square:RecalcAllWithNeighbours(true);
        end
    end
end

Events.OnObjectAdded.Remove(DoorwayCurtainsModule.onObjectAdded);
Events.OnObjectAdded.Add(DoorwayCurtainsModule.onObjectAdded);

return DoorwayCurtainsModule;
