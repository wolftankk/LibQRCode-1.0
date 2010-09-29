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
strlen = string.len;
tinsert = table.insert;
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

local BitArray = {}
local BitArray_MT = { __index = BitArray }

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
local ECBlocks_MT = {__index = ECBlocks}
--@class encode
local Encode = {};
local Encode_MT = {__index = Encode};
--@class Version class
local Version = {}
local Version_MT = {__index = Version}
--@class byte matrix
local bMatrix = {}
local bMatrix_MT = {__index = bMatrix};

local MatrixUtil = {}
local MatrixUtil_MT = { __index = MatrixUtil };
--@class QRCodeWriter
local QRCodeWriter = {}
local QRCodeWriter_MT = {__index = QRCodeWriter}

local Vector = {}
local Vector_MT = { __index = Vector }

local GF256 = {}
local GF256_MT = { __index = Get256 }

local ReedSolomonEncode = {}
local ReedSolomonEncode_MT = { __index = ReedSolomonEncode}

-- constant
--------------------------------------------------------------------------------------
---the original table is defined in the table 5 of JISX0510:2004 (p19)
local ALPHANUMERIC_TABLE = {
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
local QUITE_ZONE_SIZE = 4;
local MAX_QRCODER_VERSIONS = 10;
-------------------------------------------------------------------------------------
---reset rcode params
--@usage local a = LibStub("LibQRCode-1.0"); a:reset();
function QRCode:New()
    local newObj = setmetatable({}, QRCode_MT);
    newObj.mode = nil;
    newObj.ecLevel = nil;
    newObj.version = -1;
    newObj.matrixWidth = -1;
    newObj.maskPattern = -1;
    newObj.numTotalBytes = -1;
    newObj.numDataBytes = -1;
    newObj.numECBytes = -1;
    newObj.numRSBlocks = -1;
    newObj.matrix = nil;
    return newObj
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
function QRCode:SetECLevel(value)
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
-- BitArray
---------------------------------------------------

local function makeArray(size)
    local tmp = {}
    for i = 0, size do
        tmp[i] = 0; 
    end
    return tmp
end

function BitArray:New(size)
    local newObj = setmetatable({}, BitArray_MT);
    newObj.size = size or 0;
    newObj.bits = makeArray(size or 0) 
    return newObj
end

function BitArray:getSize()
    return self.size;
end

function BitArray:getSizeInBytes()
    return bit.rshift(self.size + 7, 3);
end

function BitArray:get(b)
    return (bit.band(self.bits[bit.rshift(b, 5)], bit.lshift(1, bit.band(b, 0x1F))) ~= 0)
end

function BitArray:toBytes(bitOffset, array, offset, numBytes)
    for i = 0, numBytes - 1, 1 do
        local theByte = 0;

        for j =0, 7 do
            if (self:get(bitOffset)) then
                theByte = bit.bor(theByte, (bit.lshift(1, 7 - j)))
            end
            bitOffset = bitOffset + 1;
        end
        array[offset + i] = theByte
    end
end

function BitArray:appendBit(b)
    self:ensureCapacity(self.size + 1);
    if (b) then
       self.bits[bit.rshift(self.size, 5)] = bit.bor(self.bits[bit.rshift(self.size, 5)], (bit.lshift(1, bit.band(self.size, 0x1F)))); 
    end
    self.size = self.size + 1;
end

function BitArray:ensureCapacity(size)
    if ( size > bit.lshift(select('#', self.bits), 5)) then
        local newBits = makeArray(size);
        for k,v in pairs(self.bits) do
            newBits[k] = v;
        end
        self.bits = newBits
    end
end

function BitArray:appendBits(value, numBits)
    if numBits < 0 or numBits > 32 then
        error("num bits must be between 0 and 32", 2);
    end
    self:ensureCapacity(self.size + numBits);

    for numBitsLeft = numBits, 1, -1  do
       self:appendBit((bit.band(bit.rshift(value, (numBitsLeft - 1)), 0x01)) == 1)
    end
end

--------------------------------------------------------------------

function GF256:New(primitive)
    local newObj = setmetatable({}, GF256_MT);
    return newObj;
end

do
    GF256.QR_CODE_FIELD = GF256:New(0x011D);-- x^8 + x^4 + x^ 4 + x^2 + x^1

end

---------------------------------------------------
-- ReedSolomonEncode
---------------------------------------------------

function ReedSolomonEncode:New(field)
    local newObj = setmetatable({}, ReedSolomonEncode_MT);
    newObj.field = field;
    
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
    return newObj
end

function ErrorCorrectionLevel:Ordinal()
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
    ECList = { ["L"]= L, ["M"] = M, ["Q"] = Q, ["H"] = H }
    ErrorCorrectionLevel.ECList = ECList;
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
    local newObj = setmetatable({}, ECBlocks_MT);
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
        total = total + self.ecBlocks[i]:getCount();
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
    return self.ecBlocks[ecLevel:Ordinal() + 1]
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

do
    --see ISO 180004:2006 6.5.1 table 9
    VERSIONS = {
      Version:New(1, {},      ECBlocks:New(7, ECB:New(1, 19)),
                              ECBlocks:New(10, ECB:New(1, 16)),
                              ECBlocks:New(13, ECB:New(1, 13)), 
                              ECBlocks:New(17, ECB:New(1, 9)) 
      ),--1
      Version:New(2, {6, 18}, ECBlocks:New(10, ECB:New(1, 34)), 
                              ECBlocks:New(16, ECB:New(1, 28)),
                              ECBlocks:New(22, ECB:New(1, 22)), 
                              ECBlocks:New(28, ECB:New(1, 16))
      ),--2
      Version:New(3, {6, 22}, ECBlocks:New(15, ECB:New(1, 55)),
                              ECBlocks:New(26, ECB:New(1, 44)),
                              ECBlocks:New(18, ECB:New(2, 17)),
                              ECBlocks:New(22, ECB:New(2, 13))
      ),--3
      Version:New(4, {6, 26}, ECBlocks:New(20, ECB:New(1, 80)),
                              ECBlocks:New(18, ECB:New(2, 32)), 
                              ECBlocks:New(26, ECB:New(2, 24)),
                              ECBlocks:New(16, ECB:New(4, 9))
      ),--4
      Version:New(5, {6, 30}, ECBlocks:New(26, ECB:New(1, 108)),
                              ECBlocks:New(24, ECB:New(2, 43)),
                              ECBlocks:New(18, ECB:New(2, 15), ECB:New(2, 16)),
                              ECBlocks:New(22, ECB:New(2, 11), ECB:New(2, 12))
      ),--5
      Version:New(6, {6, 34}, ECBlocks:New(18, ECB:New(2, 68)),
                              ECBlocks:New(16, ECB:New(4, 27)),
                              ECBlocks:New(24, ECB:New(4, 19)),
                              ECBlocks:New(28, ECB:New(4, 15))
      ),--6
      Version:New(7, {6, 22, 38}, ECBlocks:New(20, ECB:New(2, 78)),
                                  ECBlocks:New(18, ECB:New(4, 31)),
                                  ECBlocks:New(18, ECB:New(2, 14), ECB:New(4, 15)),
                                  ECBlocks:New(26, ECB:New(4, 13), ECB:New(1, 14))
      ),--7
      Version:New(8, {6, 24, 42}, ECBlocks:New(24, ECB:New(2, 97)),
                                  ECBlocks:New(22, ECB:New(2, 38), ECB:New(2, 39)),
                                  ECBlocks:New(22, ECB:New(4, 18), ECB:New(2, 19)),
                                  ECBlocks:New(26, ECB:New(4, 14), ECB:New(2, 15))
      ),--8
      Version:New(9, {6, 26, 46}, ECBlocks:New(30, ECB:New(2, 116)),
                                  ECBlocks:New(22, ECB:New(3, 36), ECB:New(2, 37)),
                                  ECBlocks:New(20, ECB:New(4, 16), ECB:New(4, 17)),
                                  ECBlocks:New(24, ECB:New(4, 12), ECB:New(4, 13))
      ),--9
      Version:New(10, {6, 28, 50}, ECBlocks:New(18, ECB:New(2, 68), ECB:New(2, 69)),
                                   ECBlocks:New(26, ECB:New(4, 43), ECB:New(1, 44)),
                                   ECBlocks:New(24, ECB:New(6, 19), ECB:New(2, 20)),
                                   ECBlocks:New(28, ECB:New(6, 15), ECB:New(2, 16))
      ),--10
    }
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
        return self.NUMERIC
    elseif bits == 0x02 then
        return self.ALPHANUMERIC;
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
function Mode:getCharacterCountBits(version)
    if self.characterCountBitsForVersions == nil then
        error("LibQRCode-1.0: Character count doesnt apply to this mode.");
    end

    local number = version:getVersionNumber();
    local offset;
    if number <= 9 then
        offset = 1
    elseif number <= 26 then
        offset = 2;
    else
        offset = 3;
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
    Mode.NUMERIC = Mode:New({10, 12, 14}, 0x01, "NUMERIC")
    Mode.ALPHANUMERIC = Mode:New({9, 11, 13}, 0x02, "ALPHANUMERIC");
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
-- Matrix util
--------------------------------------------------------
function MatrixUtil:New()
    return setmetatable({}, MatrixUtil_MT);
end

--constant
MatrixUtil.POSITION_DETECTION_PATTERN = {
    {1, 1, 1, 1, 1, 1, 1},
    {1, 0, 0, 0, 0, 0, 1},
    {1, 0, 1, 1, 1, 0, 1},
    {1, 0, 1, 1, 1, 0, 1},
    {1, 0, 1, 1, 1, 0, 1},
    {1, 0, 0, 0, 0, 0, 1},
    {1, 1, 1, 1, 1, 1, 1},
}

MatrixUtil.POSITION_ADJUSTMENT_PATTERN = {
    {1, 1, 1, 1, 1},
    {1, 0, 0, 0, 1},
    {1, 0, 1, 0, 1},
    {1, 0, 0, 0, 1},
    {1, 1, 1, 1, 1},
}

MatrixUtil.HORIZONTAL_SEPARATION_PATTERN = {
    {0,0,0,0,0,0,0,0}
}

MatrixUtil.VERTICAL_SEPARATION_PATTERN = {
    {0},{0},{0},{0},{0},{0},{0},{0},
}

--From Appendix E. Table 1, JIS0510X:2004 (p 71)
MatrixUtil.POSITION_ADJUSTMENT_PATTERN_COORDINATE_TABLE = {
	{-1, -1, -1, -1,  -1,  -1,  -1},  -- Version 1
	{ 6, 18, -1, -1,  -1,  -1,  -1},  -- Version 2
	{ 6, 22, -1, -1,  -1,  -1,  -1},  -- Version 3
	{ 6, 26, -1, -1,  -1,  -1,  -1},  -- Version 4
	{ 6, 30, -1, -1,  -1,  -1,  -1},  -- Version 5
	{ 6, 34, -1, -1,  -1,  -1,  -1},  -- Version 6
	{ 6, 22, 38, -1,  -1,  -1,  -1},  -- Version 7
	{ 6, 24, 42, -1,  -1,  -1,  -1},  -- Version 8
	{ 6, 26, 46, -1,  -1,  -1,  -1},  -- Version 9
	{ 6, 28, 50, -1,  -1,  -1,  -1},  -- Version 10
	{ 6, 30, 54, -1,  -1,  -1,  -1},  -- Version 11
	{ 6, 32, 58, -1,  -1,  -1,  -1},  -- Version 12
	{ 6, 34, 62, -1,  -1,  -1,  -1},  -- Version 13
	{ 6, 26, 46, 66,  -1,  -1,  -1},  -- Version 14
	{ 6, 26, 48, 70,  -1,  -1,  -1},  -- Version 15
	{ 6, 26, 50, 74,  -1,  -1,  -1},  -- Version 16
	{ 6, 30, 54, 78,  -1,  -1,  -1},  -- Version 17
	{ 6, 30, 56, 82,  -1,  -1,  -1},  -- Version 18
	{ 6, 30, 58, 86,  -1,  -1,  -1},  -- Version 19
	{ 6, 34, 62, 90,  -1,  -1,  -1},  -- Version 20
	{ 6, 28, 50, 72,  94,  -1,  -1},  -- Version 21
	{ 6, 26, 50, 74,  98,  -1,  -1},  -- Version 22
	{ 6, 30, 54, 78, 102,  -1,  -1},  -- Version 23
	{ 6, 28, 54, 80, 106,  -1,  -1},  -- Version 24
	{ 6, 32, 58, 84, 110,  -1,  -1},  -- Version 25
	{ 6, 30, 58, 86, 114,  -1,  -1},  -- Version 26
	{ 6, 34, 62, 90, 118,  -1,  -1},  -- Version 27
	{ 6, 26, 50, 74,  98, 122,  -1},  -- Version 28
	{ 6, 30, 54, 78, 102, 126,  -1},  -- Version 29
	{ 6, 26, 52, 78, 104, 130,  -1},  -- Version 30
	{ 6, 30, 56, 82, 108, 134,  -1},  -- Version 31
	{ 6, 34, 60, 86, 112, 138,  -1},  -- Version 32
	{ 6, 30, 58, 86, 114, 142,  -1},  -- Version 33
	{ 6, 34, 62, 90, 118, 146,  -1},  -- Version 34
	{ 6, 30, 54, 78, 102, 126, 150},  -- Version 35
	{ 6, 24, 50, 76, 102, 128, 154},  -- Version 36
	{ 6, 28, 54, 80, 106, 132, 158},  -- Version 37
	{ 6, 32, 58, 84, 110, 136, 162},  -- Version 38
	{ 6, 26, 54, 82, 110, 138, 166},  -- Version 39
	{ 6, 30, 58, 86, 114, 142, 170},  -- Version 40
}

--- Type info cells at the left top corner.
MatrixUtil.TYPE_INFO_COORDINATES = {
	{8, 0},
	{8, 1},
	{8, 2},
	{8, 3},
	{8, 4},
	{8, 5},
	{8, 7},
	{8, 8},
	{7, 8},
	{5, 8},
	{4, 8},
	{3, 8},
	{2, 8},
	{1, 8},
	{0, 8},
}

--From Appendix D in JISX0510:2004 (p. 67)
MatrixUtil.VERSION_INFO_POLY = 0x1f25 -- 1 111 1 0100 0101

--From Appendix C in JISX0510:2004 (p.65).
MatrixUtil.TYPE_INFO_POLY = 0x537;
MatrixUtil.TYPE_INFO_MASK_PATTERN = 0x5412;
--------------------------------------------------------
-- Encode method class
--------------------------------------------------------
function Encode:New(contents, ecLevel, hints, qrcode)
    local newObj = setmetatable({}, Encode_MT);
    local encoding = "";
    if hints == nil then
        local encoding = "utf8";
    end
   
    --setup 1: choose the mode(encoding);
    local mode = newObj:chooseMode(contents, encoding)
    --setup 2: append bytes into dataBits in approprise encoding
    local dataBits = BitArray:New();
    newObj:appendBytes(contents, mode, dataBits, encoding);
    -- setup 3: initialize QRCode that can contain "dataBites"
    local numInputsBytes = dataBits:getSizeInBytes();
    newObj:initQRCode(numInputsBytes, ecLevel, mode, qrcode);
    -- setup 4: build another bit vector that contains header and data
    local headerAndDataBits = BitArray:New();
    -- setup 4.5: append ECI message if applicale
    if (mode == Mode.BYTE) then
        --@TODO: donothing now.
    end
    newObj:appendModeInfo(mode, headerAndDataBits)
    local numLetters = mode == Mode.BYTE and dataBits:getSizeInBytes() or string.len(contents);
    newObj:appendLengthInfo(numLetters, qrcode:GetVersion(), mode, headerAndDataBits);
    -- setup 5: terminate the bits properly
    newObj:terminateBits(qrcode:GetNumDataBytes(), headerAndDataBits);
    -- setup 6: interleave data bits with error correction code;
    local finalBits = BitArray:New();
    --@TODO: need GF256, ReedSolomonEncoder
    --newObj:interLeaveWithECBytes(headerAndDataBits, qrcode:GetNumTotalBytes(), qrcode:GetNumDataBytes(), qrcode:GetNumRSBlocks(), finalBits);

    -- setup 7: choose the mask pattern and set to "qrCode"
    local matrix = bMatrix:New(qrcode:GetMatrixWidth(), qrcode:GetMatrixWidth()); 
    qrcode:SetMaskPattern(newObj:chooseMaskPattern(finalBits, qrcode:GetECLevel(), qrcode:GetVersion(), matrix));
    -- setup 8 build the matrix and set it to qrcode
    -- setup 9: make sure we have a vaild qrcode
    return newObj
end

--- getAlphanumericCode 
-- @return the code point of the table used in alphanumeric mode
-- or -1 if there is no corresponding code in the table
function Encode:getAlphanumericCode(c)
    local code = string.byte(c);
    if code <= #ALPHANUMERIC_TABLE then
        return (ALPHANUMERIC_TABLE[code + 1])
    end
    return -1;
end

--- @TODO: only NUMERIC
function Encode:chooseMode(contents, encoding)
    --test is always byte
    local hasNumeric = false;
    local hasAlphanumeric = false;
    for i = 1, #contents do
        local c = string.sub(contents, i, i);
        if (c >= '0' and c <= '9') then
            hasNumeric = true;
        elseif self:getAlphanumericCode(c) ~= -1 then
            hasAlphanumeric = true;
        else
            return Mode.BYTE;
        end
    end
    
    if hasAlphanumeric then
        return Mode.ALPHANUMERIC;
    elseif hasNumeric then
        return Mode.NUMERIC;
    end

    return Mode.BYTE;
end

function Encode:chooseMaskPattern(bits, ecLevel, version, matrix)
    local minPenaly = 2^31 - 1;
    local bestMaskPattern = -1;
    for maskPattern = 1, NUM_MASK_PATTERNS do
        
        
    end
end

function Encode:appendBytes(content, mode, bits, encoding)
    local modeName = mode:getName();
    if modeName == "NUMERIC" then
        self:appendNumericBytes(content, bits)
    elseif modeName == "ALPHANUMERIC" then

    elseif modeName == "BYTE" then

    end
end

function Encode:appendNumericBytes(content, bits)
    local len = #content;
    local i = 0;
    while i < len do
        local num1 = string.sub(content, i+1, i+1);
        if (i + 2 < len) then
            --encode three numberic letters in ten bits
            local num2 = string.sub(content, i + 2, i + 2);
            local num3 = string.sub(content, i + 3, i + 3);
            bits:appendBits(num1 * 100 + num2 * 10 + num3 , 10);
            i = i + 3;
        elseif (i + 1 < len) then
            local num2 = string.sub(content, i + 2, i +2);
            i = i + 2;
        else
          i = i + 1;
        end
    end
end

function Encode:appendModeInfo(mode, bits)
    bits:appendBits(mode:getBits(), 4)
end

function Encode:appendLengthInfo(numLetters, version, mode, bits)
    local numBits = mode:getCharacterCountBits(Version:getVersionForNumber(version));
    if (numLetters > (bit.lshift(1, numBits) - 1)) then
        error(numLetters .. " is bigger than" .. ( bit.lshift(1, numBits) -1 ), 2);
    end
    bits:appendBits(numLetters, numBits);
end

function Encode:initQRCode(numInputsBytes, ecLevel, mode, qrcode)
    qrcode:SetECLevel(ecLevel);
    qrcode:SetMode(mode);

    for versionNum = 1, MAX_QRCODER_VERSIONS  do
        local version = Version:getVersionForNumber(versionNum) 
        local numBytes = version:getTotalCodewords();
        local ecBlocks = version:getECBlocksForLevel(ecLevel);
        local numECBytes = ecBlocks:getTotalECCodewords();
        local numRSBlocks = ecBlocks:getNumBlocks();

        local numDataBytes = numBytes - numECBytes;

        if (numDataBytes >= (numInputsBytes + 3)) then
            qrcode:SetVersion(versionNum);
            qrcode:SetNumTotalBytes(numBytes);
            qrcode:SetNumDataBytes(numDataBytes);
            qrcode:SetNumRSBlocks(numRSBlocks);
            qrcode:SetNumECBytes(numECBytes);
            qrcode:SetMatrixWidth(version:getDimensionForVersion());
            return;
        end 
    end
    error("Cannot find proper rs block info (maybe input data too big?)", 2)
end

function Encode:terminateBits(numDataBytes, bits)
    local capacity = bit.lshift(numDataBytes, 3);
    if (bits:getSize() > capacity) then
        error("The data bits cannot fit in the QRCode ".. bits:getSize(), 2);
    end
    local i = 0;
    while (i < 4 and bits:getSize() < capacity) do
        bits:appendBit(false)
        i = i + 1;
    end
    local numBitsInLastByte = bit.band(bits:getSize(), 0x07);
    if (numBitsInLastByte > 0) then
        for n = numBitsInLastByte, 7, 1 do
            bits:appendBit(false)
        end
    end

    local numPaddingBytes = numDataBytes - bits:getSizeInBytes();
    for i = 0, numPaddingBytes - 1, 1 do
        bits:appendBits((bit.band(i, 0x01) == 0) and 0xEC or 0x11, 8);
    end

    if (bits:getSize() ~= capacity) then
        error("Bits size does not equal capacity", 2);
    end
end

--- Interleave bits with corresponding error correction bytes.
-- On success, store the result in "result", The interleavel rule is
-- complicated. see 8.6 of JISX0510:2004 p 37 for details
function Encode:interLeaveWithECBytes(bits, numTotalBytes, numDataBytes, numRSBlocks, result)
    if (bits:getSizeInBytes() ~= numDataBytes) then
        error("Number of bits and data bytes does not match", 2);
    end

    local dataBytesOffset, maxNumDataBytes, maxNumEcBytes = 0, 0, 0;

    --since, we know the number of reedsolmon blocks. we can initialize the vector with the number

    local blocks = {};
    for i = 0, numRSBlocks - 1, 1 do
        local numDataBytesInBlock, numEcBytesInBlock = {}, {};
        self:getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes, numRSBlocks, i, numDataBytesInBlock, numEcBytesInBlock);
        local size = numDataBytesInBlock[1];
        
        dataBytes = {};
        bits:toBytes(8 * dataBytesOffset, dataBytes, 0, size )
    
        ecBytes = self:generateECBytes(dataBytes, numEcBytesInBlock[1]);

        maxNumDataBytes = math.max(maxNumDataBytes, size);
        --maxNumEcBytes = math.max(maxNumEcBytes, );
        dataBytesOffset = dataBytesOffset + numDataBytesInBlock[1]
    end
end

function Encode:generateECBytes(dataBytes, numEcBytesInBlock)
    local numDataBytes = #dataBytes
    local toEncode = {};
    for i = 1, numDataBytes do
        toEncode[i] = bit.band(dataBytes[i], 0xFF);
    end
end

--- Get number of data bytes and number of error correction bytes for block id "blockID".
-- Store the result in "numDataBytesInBlock", and "numECBytesInBlocks".
-- see table 12 in 8.5.1 of JISX0510:2004 (p.30)
function Encode:getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes, numRSBlocks, blockID, numDataBytesInBlock, numEcBytesInBlock)
    if (blockID >= numRSBlocks) then
        error("Block ID too large", 2);
    end

    local numRSBlocksInGroup2 = numTotalBytes % numRSBlocks;
    local numRSBlocksInGroup1 = numRSBlocks - numRSBlocksInGroup2;

    local numTotalBytesInGroup1 = numTotalBytes / numRSBlocks;
    local numTotalBytesInGroup2 = numTotalBytesInGroup1 + 1;

    local numDataBytesInGroup1 = numDataBytes / numRSBlocks;
    local numDataBytesInGroup2 = numDataBytesInGroup1 + 1;

    local numEcBytesInGroup1 = numTotalBytesInGroup1 - numDataBytesInGroup1;
    local numEcBytesInGroup2 = numTotalBytesInGroup2 - numDataBytesInGroup2;

    --sanity checks
    if (numEcBytesInGroup1 ~= numEcBytesInGroup2) then
        error("EC bytes mismatch", 2)
    end

    if (numRSBlocks ~= numRSBlocksInGroup1 + numRSBlocksInGroup2) then
        error("RS blocks mismatch", 2);
    end

    if (numTotalBytes ~= ((numDataBytesInGroup1 + numEcBytesInGroup1) * numRSBlocksInGroup1) + ( (numDataBytesInGroup2 + numEcBytesInGroup2) * numRSBlocksInGroup2)) then
        error("Total bytes mismatch", 2);
    end
    
    if (blockID < numRSBlocksInGroup1) then
        numDataBytesInBlock[1] = numDataBytesInGroup1;
        numEcBytesInBlock[1] = numEcBytesInGroup1;
    else
        numDataBytesInBlock[1] = numDataBytesInGroup2;
        numEcBytesInBlock[1] = numEcBytesInGroup2;
    end
end

--------------------------------------------------------
-- QRCodeWriter method class
--------------------------------------------------------
function QRCodeWriter:New(contents, width, height, hints)
    local newObj = setmetatable({}, QRCodeWriter_MT);
    --checkArgs
    if (contents == nil or contents == "" or strlen(contents) == 0 or type(contents) ~= "string") then
        error("contents is empty or not string.", 2);
    end
    
    if (width < 0 or height < 20 or type(width) ~= "number" or type(height) ~= "number") then
        error("Requested dimensions are too small or not number." ,2)
    end
    local ecLevel  = ECList.L;--use L ecLevel
    if (hints ~= nil) then

    end
    local code = QRCode:New();
    Encode:New(contents, ecLevel, hints, code);
    newObj:renderResult(code, width, height);
    return newObj
end

--- note that the input matrix uses 0 = white , 1 = black
-- while the output matrix uses
-- texture: WHITE8X8
function QRCodeWriter:renderResult(code, width, height)

end
--------------------------------------------------------
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


--final
function lib:new()
    local barcode = QRCodeWriter:New("13788953440", 256, 256);
    --local barcode.canvas = CreateFrame("Frame", nil)
end

--[[
test code
]]
do
    lib:new();
end
