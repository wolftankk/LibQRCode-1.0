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

--- metatable list
--@class qrcode
local qrcode = {}
local qrcode_MT = {__index = qrcode}
--@class Mode class
local Mode = {}
local Mode_MT = {__index = Mode};
--@class ECBlocks class
local ECBlocks = {}
local ECBlocks_MT = {index = ECBlocks}
--@class Version class
local Version = {}
local Version_MT = {__index = Version}
--@class byte matrix
local bMatrix = {}
local bMatrix_MT = {__index = bMatrix};

local QRCodeWriter = {}
-- constant
--------------------------------------------------------------------------------------
---the original table is defined in the table 5 of JISX0510:2004 (p19)
local ALPHANUMBERIC_TABLE = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, --0x00-0x0f
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, --0x10-0x1f
    36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43,  -- 0x20-0x2f
    0,   1,  2,  3,  4,  5,  6,  7,  8,  9, 44, -1, -1, -1, -1, -1,  -- 0x30-0x3f
    -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,  -- 0x40-0x4f
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1   -- 0x50-0x5f
}
local QRCODE_MATRIX = 17;
local QRCODE_MATRIX_PER_VERSION = 4;
local NUM_MASK_PATTERNS = 8;


-------------------------------------------------------------------------------------

function lib:New()
    --local builder = setmetatable({}, qrcode_MT); 
    --builder.canvas = CreateFrame("Frame");
    --return builder;
end

---reset qrcode params
--@usage local a = LibStub("LibQRCode-1.0"); a:reset();
function qrcode:reset()
    self.mode = nil;
    self.ecLevel = nil;
    self.version = -1;
    self.matrixWidth = -1;
    self.maskPattern = -1;
    self.numTotalBytes = -1;
    self.numDataBytes = -1;
    self.numECBytes = -1;
    self.numRSBlocks = -1;
    self.matrix = nil;
end

---get mode of the QRCode
function qrcode:GetMode()
    return self.mode;
end

---set mode of the QRCode
function qrcode:SetMode(mode)
    self.mode = mode
end

---get error correction level of the QRCode
function qrcode:GetECLevel()
    return self.ecLevel;
end

---set error correction level of the QRCode
function qrcode:SetSCLevel(value)
    self.ecLevel = value;
end

---get version of the QRCode, the bigger version, the bigger size
function qrcode:GetVersion()
    return self.version
end

---set version of the QRCode
function qrcode:SetVersion(value)
    self.version = value;
end

---get bytesMatrix width of the QRCode
function qrcode:GetMatrixWidth()
    return self.matrixWidth
end

---set bytesMatrix width of the QRCode
function qrcode:SetMatrixWidth(value)
    self.matrixWidth = value
end

---get Mask pattern of the QRCode
function qrcode:GetMaskPattern()
    return self.maskPattern
end

---check if "mask pattern" is vaild
function qrcode:isValidMaskPattern(maskPattern)
    return (maskPattern > 0 and maskPattern < NUM_MASK_PATTERNS)
end

---set mask pattern of the QRCode
function qrcode:SetMaskPattern(value)
    self.maskPattern = value
end

---get number of total bytes in the QRCode
function qrcode:GetNumTotalBytes()
    return self.numTotalBytes;
end

function qrcode:SetNumTotalBytes(value)
    self.numTotalBytes = value
end

---get number of data bytes in the QRCode
function qrcode:GetNumDataBytes()
    return self.numDataBytes
end

function qrcode:SetNumDataBytes(value)
    self.numDataBytes = value;
end

---get number of error correction in the QRCode
function qrcode:GetNumECBytes()
    return self.numECBytes;
end

function qrcode:SetNumECBytes(value)
    self.numECBytes = value;
end

---get number of Reedsolomon blocks in the QRCode
function qrcode:GetNumRSBlocks()
    return self.numRSBlocks;
end

function qrcode:SetNumRSBlocks(value)
    self.numRSBlocks = value;
end

---get ByteMatrix of the QRCode
function qrcode:GetMatrix()
    return self.matrix;
end

function qrcode:SetMatrix(value)
    self.matrix = value
end

--- Return the value of the module(cell) point by "x" and "y" in the matrix of the QRCode
-- They call cells in the matrix modules.
-- @result number  1 represents a black cell, and 0 represents a white cell
function qrcode:at(x, y)
    local value = self.matrix:get(x, y);
    if not(value == 0 or value == 1) then
        error("Matrix return value is bad.", 2);
    end
    return value
end

--- Check all the member vars are set properly.
-- @resume boolean. true on success, otherwise returns false
function qrcode:isVaild()
    return (self.mode ~= nil and
        self.ecLevel ~= nil and
        self.version ~= -1 and
        self.matrixWidth ~= -1 and
        self.maskPattern ~= -1 and
        self.numTotalBytes ~= -1 and
        self.numDataBytes ~= -1 and
        self.numECBytes ~= -1 and
        self.numRSBlocks ~= -1 and 
        self:isValidMaskPattern(self.maskPattern) and
        (self.numTotalBytes == (self.numDataBytes + self.numECBytes)) and
        self.matrix ~= nil and (self.matrixWidth == self.matrix:getWidth()) and (self.matrix:getHeight() == self.matrix:getWidth()))
end

-----------------------------------------------
-- ECBlocks method class
-----------------------------------------------
function ECBlocks:New()

end

-----------------------------------------------
-- Version method class
-----------------------------------------------
function Version:New(versionNumber, alignmentPatternCenters, ...)
    local newObj = setmetatable({}, Version_MT);
    newObj.versionNumber = versionNumber;
    newObj.alignmentPatternCenters = alignmentPatternCenters;
    newObj.ecBlocks = {...};
    local total = 0;
    local ecBlocks1, ecBlocks2, ecBlocks3, ecBlocks4 = ...;
    local ecCodewords = ecBlocks1:getECCodewordsPerBlock();
    local ecbArray = ecBlocks1:getECBlocks();
    for i = 1, #ecbArray do
        local ecBlock = ecbArray[i];
        total = total + ecBlock:getCount() * (ecBlock:getDataCodewords() + ecCodewords);
    end
    newObj.totalCodewords = total;
    return newObj
end

function Version:getVersionNumber()
    return self.versionNumber
end

function Version:getAlignmentPatternCenters()
    return self.alignmentPatternCenters
end

function Version:getTotalCodewords()
    return self.totalCodewords;
end

function Version:getDimensionForVersion()
    return QRCODE_MATRIX + QRCODE_MATRIX_PER_VERSION * self.versionNumber;
end

function Version:getECBlocksForLevel(ecLevel)
    return self.ecBlocks[ecLevel:ordinal()]
end

------------------------------------------------
-- Mode method class
------------------------------------------------
function Mode:New(versions, bits, name)
    local newObj = setmetatable({}, Mode_MT)
    newObj.characterCountBitsForVersions = versions;
    newObj.bits = bits;
    newObj.name = name;
    return newObj
end

function Mode:forBits(bits)
    if bits == 0x00 then
        return self.TERMINATOR
    elseif bits == 0x01 then
        return self.NUMBERIC
    elseif bits == 0x02 then
        return self.ALPHANUMBERIC;
    elseif bits == 0x03 then
        return self.STRUCTURED_APPED;
    elseif bits == 0x04 then
        return self.BYTE;
    elseif bits == 0x05 then
        return self.FNC1_FIRST_POSITION;
    elseif bits == 0x07 then
        return self.ECI
    elseif bits == 0x08 then
        return self.KANJI;
    elseif bits == 0x09 then
        return self.FNC1_SECOND_POSITION;
    else
        error("bits is invaild value, not the mode",2);
    end
end

--- get character count bit for versions
-- @param version  version in question
-- @return  number of bits used, in this QRCode symbol. to encode
--  the count of characters that will follow encoded in this
function Mode:getCharacterCountBitsForVersions(version)
    if self.characterCountBitsForVersions == nil then
        error("LibQRCode-1.0: Character count doesnt apply to this mode.");
    end

    local number = version:getVersionNumber();
    local offset;
    if number <= 9 then
        offset = 0
    elseif number <= 26 then
        offset = 1;
    else
        offset = 2
    end
    return self.characterCountBitsForVersions[offset];
end

function Mode:getBits()
    return self.bits;
end

function Mode:getName()
    return self.name;
end

do
    Mode.TERMINATOR = Mode:New({0, 0, 0}, 0x00, "TERMINATOR")
    Mode.NUMBERIC = Mode:New({10, 12, 14}, 0x01, "NUMBERIC")
    Mode.ALPHANUMBERIC = Mode:New({9, 11, 13}, 0x02, "ALPHANUMBERIC");
    Mode.STRUCTURED_APPED = Mode:New({0, 0, 0}, 0x03, "STRUCTURED_APPED");--not suppered
    Mode.BYTE = Mode:New({8, 16, 16}, 0x04, "BYTE");
    Mode.ECI = Mode:New(nil, 0x07, "ECI");--dont apply
    Mode.KANJI = Mode:New({8, 10, 12}, 0x08, "KANJI");--arsia charsets
    Mode.FNC1_FIRST_POSITION = Mode:New(nil, 0x05, "FNC1_FIRST_POSITION");
    Mode.FNC1_SECOND_POSITION = Mode:New(nil, 0x09, "FNC1_SECOND_POSITION");
end

------------------------------------------------
-- byte matrix class method
------------------------------------------------
--- init bytes matrix.
-- bytes is 2meta table. save y-x value 
function bMatrix:New(width, height)
    local newObj = setmetatable({}, bMatrix_MT);
    newObj.width = width;
    newObj.height = height;
    newObj.bytes = {};
    for h = 1, height do
        for w = 1, width do
            if (newObj.bytes[h] == nil) or (type(newObj.bytes[h]) ~= "table") then
                newObj.bytes[h] = {}
            end
            newObj.bytes[h][w] = {}
        end
    end
    return newObj
end

function bMatrix:getHeight()
    return self.height;
end

function bMatrix:getWidth()
    return self.width;
end

function bMatrix:getTable()
    return self.bytes;
end

function bMatrix:get(x, y)
    return bytes[y][x]
end

function bMatrix:set(x, y, value)
    self.bytes[y][x] = value
end

function bMatrix:clear(value)
    for y = 1, self.height do
        for x = 1, self.width do
            self.bytes[y][x] = value;
        end
    end
end

--------------------------------------------------------
-- QRCodeWriter method class
--------------------------------------------------------
function QRCodeWriter:New()
end

do
  lib.bMatrix = setmetatable({}, {
    __index = bMatrix_MT,
    __newinde = function() 
        error("attemp to update a read-only table",2)
    end
  })
end
--[[
test code
]]
--local barcode = LibStub("LibQRCode-1.0"):New();
--barcode:Create("http://www.wowace.com", "l");
