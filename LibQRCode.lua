--[[
Name: LibQRCode
Revision: $Rev$
Author(s): wolftankk
Description: QR Code builder library.
Dependency: LibStub
License: BSD License
]]

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

local qrcode = {}
local qrcode_MT = {__index = qrcode}

function lib:New()
    local builder = setmetatable({}, qrcode_MT); 
    builder.canvas = CreateFrame("Frame");
    return builder;
end

function qrcode:Create(str, size)

end
