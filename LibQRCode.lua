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
local NUM_MASK_PATTERNS = 8;

--@class qrcode
local qrcode = {}
local qrcode_MT = {__index = qrcode}

--@class matrix method
local cmatrix = {}
local cmatrix_MT = {__index = cmatrix};

--the original table is defined in the table 5 of JISX0510:2004 (p19)
local ALPHANUMBERIC_TABLE = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, --0x00-0x0f
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, --0x10-0x1f
    36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43,  -- 0x20-0x2f
    0,   1,  2,  3,  4,  5,  6,  7,  8,  9, 44, -1, -1, -1, -1, -1,  -- 0x30-0x3f
    -1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,  -- 0x40-0x4f
    25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, -1, -1, -1, -1, -1   -- 0x50-0x5f
}

function lib:New()
    local builder = setmetatable({}, qrcode_MT); 
    --builder.canvas = CreateFrame("Frame");
    return builder;
end

--reset qrcode params
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

--get mode of the QRCode
function qrcode:GetMode()
    return self.mode;
end

--set mode of the QRCode
function qrcode:SetMode(mode)
    self.mode = mode
end

--get error correction level of the QRCode
function qrcode:GetECLevel()
    return self.ecLevel;
end

--set error correction level of the QRCode
function qrcode:SetSCLevel(value)
    self.ecLevel = value;
end

--get version of the QRCode, the bigger version, the bigger size
function qrcode:GetVersion()
    return self.version
end

--set version of the QRCode
function qrcode:SetVersion(value)
    self.version = value;
end

--get bytesMatrix width of the QRCode
function qrcode:GetMatrixWidth()
    return self.matrixWidth
end

--set bytesMatrix width of the QRCode
function qrcode:SetMatrixWidth(value)
    self.matrixWidth = value
end

--get Mask pattern of the QRCode
function qrcode:GetMaskPattern()
    return self.maskPattern
end

--check if "mask pattern" is vaild
function qrcode:isValidMaskPattern(maskPattern)
    return (maskPattern > 0 and maskPattern < NUM_MASK_PATTERNS)
end

--set mask pattern of the QRCode
function qrcode:SetMaskPattern(value)
    self.maskPattern = value
end

--get number of total bytes in the QRCode
function qrcode:GetNumTotalBytes()
    return self.numTotalBytes;
end

function qrcode:SetNumTotalBytes(value)
    self.numTotalBytes = value
end

--get number of data bytes in the QRCode
function qrcode:GetNumDataBytes()
    return self.numDataBytes
end

function qrcode:SetNumDataBytes(value)
    self.numDataBytes = value;
end

--get number of error correction in the QRCode
function qrcode:GetNumECBytes()
    return self.numECBytes;
end

function qrcode:SetNumECBytes(value)
    self.numECBytes = value;
end

--get number of Reedsolomon blocks in the QRCode
function qrcode:GetNumRSBlocks()
    return self.numRSBlocks;
end

function qrcode:SetNumRSBlocks(value)
    self.numRSBlocks = value;
end

--get ByteMatrix of the QRCode
function qrcode:GetMatrix()
    return self.matrix;
end

function qrcode:SetMatrix(value)
    self.matrix = value
end

--Return the value of the module(cell) point by "x" and "y" in the matrix of the QRCode
--They call cells in the matrix modules.
--@result number  1 represents a black cell, and 0 represents a white cell
function qrcode:at(x, y)
    local value = self.matrix:get(x, y);
    if not(value == 0 or value == 1) then
        error("Matrix return value is bad.", 2);
    end
    return value
end

--Check all the member vars are set properly.
--@resume boolean. true on success, otherwise returns false
function qrcode:isVaild()

end

------------------------------------------------
-- matrix class method
-----------------------------------------------

--[[
test code
]]
local barcode = LibStub("LibQRCode-1.0"):New();
--barcode:Create("http://www.wowace.com", "l");
