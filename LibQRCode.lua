--[[
Name: LibQRCode
Revision: $Rev$
Author(s): wolftankk
Description: QR Code builder library.
Dependency: LibStub
Document: http://www.swetake.com/qr/qr1_en.html
License: Apache 2.0 License
]]
--debug
strmatch = string.match;
if (dofile) then
    dofile([[/home/workspace/LibStub/LibStub.lua]]);
end
if require then
     bit = require("bit")
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
--@class QRCode
local QRCode = {}
local QRCode_MT = {__index = QRCode}
--@class Mode class
local Mode = {}
local Mode_MT = {__index = Mode};
--@class ErrorCorrectionLevel  ecLevel
local ErrorCorrectionLevel = {};
local ErrorCorrectionLevel_MT = {__index = ErrorCorrectionLevel}
local ECList = {};
--@class ECB
local ECB = {}
local ECB_MT = {__index = ECB};
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
local VERSIONS = {};--version 1 ~ 40 container of the QRCode
-------------------------------------------------------------------------------------

function lib:New()
    --test code
    local str = 13788953440
    
end

---reset rcode params
--@usage local a = LibStub("LibQRCode-1.0"); a:reset();
function QRCode:reset()
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
function QRCode:GetMode()
    return self.mode;
end

---set mode of the QRCode
function QRCode:SetMode(mode)
    self.mode = mode
end

---get error correction level of the QRCode
function QRCode:GetECLevel()
    return self.ecLevel;
end

---set error correction level of the QRCode
function QRCode:SetSCLevel(value)
    self.ecLevel = value;
end

---get version of the QRCode, the bigger version, the bigger size
function QRCode:GetVersion()
    return self.version
end

---set version of the QRCode
function QRCode:SetVersion(value)
    self.version = value;
end

---get bytesMatrix width of the QRCode
function QRCode:GetMatrixWidth()
    return self.matrixWidth
end

---set bytesMatrix width of the QRCode
function QRCode:SetMatrixWidth(value)
    self.matrixWidth = value
end

---get Mask pattern of the QRCode
function QRCode:GetMaskPattern()
    return self.maskPattern
end

---check if "mask pattern" is vaild
function QRCode:isValidMaskPattern(maskPattern)
    return (maskPattern > 0 and maskPattern < NUM_MASK_PATTERNS)
end

---set mask pattern of the QRCode
function QRCode:SetMaskPattern(value)
    self.maskPattern = value
end

---get number of total bytes in the QRCode
function QRCode:GetNumTotalBytes()
    return self.numTotalBytes;
end

function QRCode:SetNumTotalBytes(value)
    self.numTotalBytes = value
end

---get number of data bytes in the QRCode
function QRCode:GetNumDataBytes()
    return self.numDataBytes
end

function QRCode:SetNumDataBytes(value)
    self.numDataBytes = value;
end

---get number of error correction in the QRCode
function QRCode:GetNumECBytes()
    return self.numECBytes;
end

function QRCode:SetNumECBytes(value)
    self.numECBytes = value;
end

---get number of Reedsolomon blocks in the QRCode
function QRCode:GetNumRSBlocks()
    return self.numRSBlocks;
end

function QRCode:SetNumRSBlocks(value)
    self.numRSBlocks = value;
end

---get ByteMatrix of the QRCode
function QRCode:GetMatrix()
    return self.matrix;
end

function QRCode:SetMatrix(value)
    self.matrix = value
end

--- Return the value of the module(cell) point by "x" and "y" in the matrix of the QRCode
-- They call cells in the matrix modules.
-- @result number  1 represents a black cell, and 0 represents a white cell
function QRCode:at(x, y)
    local value = self.matrix:get(x, y);
    if not(value == 0 or value == 1) then
        error("Matrix return value is bad.", 2);
    end
    return value
end

--- Check all the member vars are set properly.
-- @resume boolean. true on success, otherwise returns false
function QRCode:isVaild()
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

---------------------------------------------------
-- Error Correction 
---------------------------------------------------
-- This enum encapsulates the four error correction levels defined 
-- by the QRCode standard.
function ErrorCorrectionLevel:New(ordinal, bits, name)
    local newObj = setmetatable({}, ErrorCorrectionLevel_MT);
    newObj.ordinal = ordinal;
    newObj.bits = bits;
    newObj.name = name;
end

function ErrorCorrectionLevel:ordinal()
    return self.ordinal
end

function ErrorCorrectionLevel:getBits()
    return self.bits
end

function ErrorCorrectionLevel:getName()
    return self.name
end

do
    -- L = ~7% correction
    local L = ErrorCorrectionLevel:New(0, 0x01, "L")
    -- M = ~15%
    local M= ErrorCorrectionLevel:New(1, 0x00, "M")
    -- Q = ~25%
    local Q = ErrorCorrectionLevel:New(2, 0x02, "Q")
    -- H ~= 30%
    local H = ErrorCorrectionLevel:New(3, 0x03, "H")

    ErrorCorrectionLevel = {L, M, Q, H}; 
    ECList = {L, M, Q, H}
end
-----------------------------------------------
--ECB method class
-----------------------------------------------
--- Encapsualtes the parameters for one error-correction block in one symbol version.
-- This includes the number of data codewords, and the number of times a block with these
-- paramers is used consecutively in the QRCode version's format.
function ECB:New(count, dataCodewords)
    local newObj = setmetatable({}, ECB_MT);
    newObj.count = count;
    newObj.dataCodewords = dataCodewords;
    return newObj;
end

function ECB:getCount()
    return self.count;
end

function ECB:getDataCodewords()
    return self.dataCodewords;
end
-----------------------------------------------
-- ECBlocks method class
-----------------------------------------------
function ECBlocks:New(ecCodewordsPerBlock, ...)
    local newObj = setmetatable({}, {__index = ECBlocks_MT});
    newObj.ecCodewordsPerBlock = ecCodewordsPerBlock;
    newObj.ecBlocks = {...};
    return newObj;
end

function ECBlocks:getECCodewordsPerBlock()
    return self.ecCodewordsPerBlock;
end

function ECBlocks:getNumBlocks()
    local total = 0;
    for i = 1, #self.ecBlocks do
        total = total + ecBlocks[i]:getCount();
    end
    return total
end

function ECBlocks:getTotalECCodewords()
    return self.ecCodewordsPerBlock * self:getNumBlocks();
end

function ECBlocks:getECBlocks()
    return self.ecBlocks;
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

--- Deduce version information purely for the QRCode dimensions.
--
-- @param dimension dimension in modules;
-- @return Version for a QRCode of that dimension;
function Version:getProvisionalVersionForDimension(dimension)
    if (dimension % 4 ~= 1) then
        error("dimension is error", 2);
    end
    return self:getVersionForNumber(bit.rshift((dimension - 17), 2)); 
end

function Version:getVersionForNumber(versionNumber)
    if (versionNumber < 1 or versionNumber > 40) then
        error("version number is invaild value", 2);
    end
    return VERSIONS[versionNumber];
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
  lib.QRCode = setmetatable({}, {
    __index = QRCode_MT,
    __newindex = function()
        error("attemp to update a read-only table", 2);
    end
  })
  lib.bMatrix = setmetatable({}, {
    __index = bMatrix_MT,
    __newindex = function() 
        error("attemp to update a read-only table",2)
    end
  })
end
--[[
test code
]]
local barcode = LibStub("LibQRCode-1.0"):New();
