--[[
Name: LibQRCode
Revision: $Rev$
Author(s): wolftankk
Description: QR Code builder library.
Dependency: LibStub
Document: http://www.swetake.com/qr/qr1_en.html
License: BSD License
]]
--debug
strmatch = string.match;
if (dofile) then
    dofile([[/home/workspace/LibStub/LibStub.lua]]);
end

local MAJOR_VERSION = "LibQRCode-1.0";
local MINOR_VERSION = tonumber(("$Rev$"):match("(%d+)")) or 1000
if not LibStub then error(MAJOR_VERSION.." require LibStub") end
local lib, oldLib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION);
if not lib then 
    return
end
if oldLib then
    oldLib = {}
    for k, v in pairs(lib) do
        oldLib[k] = v;
        lib[k] = nil;
    end
end

local QRCODE_MATRIX = 21;--version 1, 21* 21, 4 modules increases whenever 1 version increases.
local QRCODE_MATRIX_PER_VERSION = 4;
local qrcode = {}
local qrcode_MT = {__index = qrcode}

function lib:New()
    local builder = setmetatable({}, qrcode_MT); 
    --builder.canvas = CreateFrame("Frame");
    return builder;
end

--@param level String/Int, if type is string, val: S, M, L
--if type is int, range 1 to 40;
function qrcode:Create(str, level)
    local ilevel = 1;
    if type(level) == "string" then
        local size = level:lower();
        if size == "s" then
            ilevel = 1;
        elseif size == "m" then
            ilevel = 20;
        elseif size == "l" then
            ilevel = 40;
        else
            error("Error: Level is invalid param. You can type S, M, L or number(1~40 range).", 2);
        end
    elseif type(level) == "number" and (level >= 1 and level <= 40) then
        ilevel = level;
    else
        error("Error: Level is invalid param. You can type S, M, L or number(1~40 range).", 2);
    end

    local matrix = 0 
    if ilevel == 1 then
        matrix = QRCODE_MATRIX;
    else
        matrix = QRCODE_MATRIX + QRCODE_MATRIX_PER_VERSION * (ilevel - 1); 
    end
    self.matrix = matrix;
    self:Parse(str);
end

function qrcode:Parse(str)
    
end



--[[
test code
]]
local barcode = LibStub("LibQRCode-1.0"):New();
barcode:Create("http://www.wowace.com", "l");
print(barcode.matrix)
