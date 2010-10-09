--[[
Name: LibQRCode
Revision: $Rev$
Author(s): wolftankk
Description: QR Code builder library.
Dependency: LibStub
Document: http://www.swetake.com/qr/qr1_en.html
License: Apache 2.0 License
]]
strmatch = string.match;
strlen = string.len;
tinsert = table.insert;
if dofile then
    dofile([[/home/workspace/LibStub/LibStub.lua]]);
end
if require then
    bit = require("bit");
end

local MAJOR_VERSION = "LibQRCode-1.0";
local MINOR_VERSION = tonumber(("$Rev$"):match("(%d+)")) or 1000
if not LibStub then error(MAJOR_VERSION.." require LibStub", 2) end
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

---------------------------------------------------------------
-----  common functions
---------------------------------------------------------------
local function copyTable(t1, t2)
    for k, v in pairs(t1) do
        if type(v) == "table" then
            t2[k] = {}
            copyTable(v, t2[k]);
        end
        t2[k] = v
    end
end

local function new(size)
    local t = {}
    for i = 1, size do
        t[i] = 0
    end
    return t
end

--from ckknight
local function combine_type(...)
    local count = select('#', ...);
    if count == 1 then
        return (...)
    elseif count == 2 then
        return ("%s or %s"):format(...);
    elseif count == 3 then
        return ("%s, %s or %s"):format(...)
    else
        local t = {};
        for i = 1, count - 1 do
            t[#t+1] = (...);
            t[#t+1] = ", "
        end
        t[#t+1] = "or ";
        t[#t+1] = select(count, ...);
        return table.concat(t)
    end
end

local function check(num, argument, ...)
    if type(num) ~= "number" then
        error("Argument #1 to check must be a number, got %s (%s)"):format(type(num), tostring(num));
    end
    local argument_type = type(argument);
    for i = 1, select('#', ...) do
        if argument_type == (select(i, ...)) then
            return
        end
    end
    error(("Argument #%d must be a %s, got %s (%s)"):format(num, combine_type(...), argument_type, tostring(argument)), 3)
end

local function arraycopy(src, srcPos, desc, destPos, length)
    check(1, src, "table");
    check(2, srcPos, "number");
    check(3, desc, "table");
    check(4, destPos, "number");
    check(5, length, "number");
    local srcLength = #src; 
    local descLength = #desc;
        
    if srcPos == 0 then srcPos = 1 end
    if destPos == 0 then destPos = 1 end
    
    if (srcPos + length - 1) > srcLength then
        error("srcPos + length is must be lesser than src length", 2); 
    end
    
    if (destPos + length - 1) > descLength then
        error("destPos + length is must be lesser that desc length", 2)
    end

    local start = srcPos;
    for di = destPos, (destPos + length - 1) do
        desc[di] = src[start];

        if start == (srcPos + length - 1) then
            return;
        else
            start = start + 1
        end
    end
end

local function toByte(value)
    if value >= -128 and value <= 127 then
        return value
    end
    
    if value > 127 then
        return toByte(-128 + (value - 128))
    end

    if value < -128 then
        return toByte(128 + (value + 128))
    end
end

local QRCode = {}
local BitArray = {}
local BlockPair = {};
local Mode = {}

local ErrorCorrectionLevel = {};
local ECList = {};
local ECB = {}
local ECBlocks = {}
local Encode = {};
local Version = {}
local bMatrix = {}
local MatrixUtil = {}
local QRCodeWriter = {}

local GF256 = {}
local GF256Poly = {}
local ReedSolomonEncoder = {}

-- constant
--the original table is defined in the table 5 of JISX0510:2004 (p19)
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

do
    QRCode.prototype = {
        mode = nil,
        ecLevel = nil,
        version = -1,
        matrixWidth = -1,
        maskPattern = -1,
        numTotalBytes = -1,
        numDataBytes = -1,
        numECBytes = -1,
        numRSBlocks = -1,
        martix = nil
    }

    --- Construct and return a new QRCode
    -- @return object 
    -- @usage QRCode:New(); 
    function QRCode:New()
        local newObj = setmetatable({}, {__index = QRCode.prototype});
        return newObj
    end

    --- get mode of the QRCode
    -- @return mode
    function QRCode.prototype:GetMode()
        return self.mode;
    end

    --- set mode of the QRCode
    -- @param mode Mode obejct
    function QRCode.prototype:SetMode(mode)
        check(1, mode, "table"); 
        self.mode = mode
    end

    --- get error correction level of the QRCode
    -- @return ecLevel
    function QRCode.prototype:GetECLevel()
        return self.ecLevel;
    end

    --- set error correction level of the QRCode
    -- @param value ecLevel object
    function QRCode.prototype:SetECLevel(value)
        check(1, value, "table")
        self.ecLevel = value;
    end

    --- get version of the QRCode, the bigger version, the bigger size
    -- @return Version object
    function QRCode.prototype:GetVersion()
        return self.version
    end

    --- set version of the QRCode
    -- @param value Version object
    function QRCode.prototype:SetVersion(value)
        check(1, value, "number")
        self.version = value;
    end

    --- get bytesMatrix width of the QRCode
    function QRCode.prototype:GetMatrixWidth()
        return self.matrixWidth
    end

    --- set bytesMatrix width of the QRCode
    function QRCode.prototype:SetMatrixWidth(value)
        check(1, value, "number");
        self.matrixWidth = value
    end

    --- get Mask pattern of the QRCode
    function QRCode.prototype:GetMaskPattern()
        return self.maskPattern
    end

    --- check if "mask pattern" is vaild
    function QRCode.prototype:isValidMaskPattern(maskPattern)
        check(1, maskPattern, "number");
        return (maskPattern > 0 and maskPattern < NUM_MASK_PATTERNS)
    end

    --- set mask pattern of the QRCode
    function QRCode.prototype:SetMaskPattern(value)
        check(1, value, "number");
        self.maskPattern = value
    end

    --- get number of total bytes in the QRCode
    function QRCode.prototype:GetNumTotalBytes()
        return self.numTotalBytes;
    end

    function QRCode.prototype:SetNumTotalBytes(value)
        check(1, value, "number");
        self.numTotalBytes = value
    end

    --- get number of data bytes in the QRCode
    function QRCode.prototype:GetNumDataBytes()
        return self.numDataBytes
    end

    function QRCode.prototype:SetNumDataBytes(value)
        check(1, value, "number");
        self.numDataBytes = value;
    end

    --- get number of error correction in the QRCode
    function QRCode.prototype:GetNumECBytes()
        return self.numECBytes;
    end

    function QRCode.prototype:SetNumECBytes(value)
        check(1, value, "number");
        self.numECBytes = value;
    end

    --- get number of Reedsolomon blocks in the QRCode
    function QRCode.prototype:GetNumRSBlocks()
        return self.numRSBlocks;
    end

    function QRCode.prototype:SetNumRSBlocks(value)
        check(1, value, "number")
        self.numRSBlocks = value;
    end

    --- get ByteMatrix of the QRCode
    function QRCode.prototype:GetMatrix()
        return self.matrix;
    end

    function QRCode.prototype:SetMatrix(value)
        check(1, value, "table")
        self.matrix = value
    end

    --- Return the value of the module(cell) point by "x" and "y" in the matrix of the QRCode They call cells in the matrix modules.
    -- @param x horizontal value
    -- @param y vertical value 
    -- @result 1 represents a black cell, and 0 represents a white cell
    -- @usage qrcode:at(x, y)
    function QRCode.prototype:at(x, y)
        check(1, x, "number");
        check(1, y, "number");
        local value = self.matrix:get(x, y);
        if not(value == 0 or value == 1) then
            error("Matrix return value is bad.", 2);
        end
        return value
    end

    --- Check all the member vars are set properly.
    -- @return boolean. true on success, otherwise returns false
    function QRCode.prototype:isVaild()
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
end

---------------------------------------------------
-- BitArray
-- This is a simple, fast array of bits, represented compactly by an array of this internally.
---------------------------------------------------
do
    BitArray.prototype = {};  
    BitArray_MT = {__index = BitArray.prototype};

    local function makeArray(size)
        return new(bit.rshift(size + 31, 5) + 1)
    end
    
    --- Construct and return a new BitArray
    -- @param size the bits size
    function BitArray:New(size)
        check(1, size, "number", "nil");
        local newObj = setmetatable({}, BitArray_MT);
        newObj.size = size or 0;
        newObj.bits = (size == nil) and new(1) or makeArray(size); 
        return newObj
    end

    function BitArray.prototype:getSize()
        return self.size;
    end

    function BitArray.prototype:getSizeInBytes()
        return bit.rshift(self.size + 7, 3);
    end
    
    -- @param b bit to get first value: 0
    -- @return true if bit b is set
    function BitArray.prototype:get(b)
        check(1, b, "number")
        return (bit.band(self.bits[bit.rshift(b, 5) + 1], bit.lshift(1, bit.band(b, 0x1F))) ~= 0)
    end
   
    --- Sets bit b
    -- @param b bit to set
    function BitArray.prototype:set(b)
        check(1, b, "number")
        self.bits[ bit.rshift(b, 5) + 1 ] = bit.bor( self.bits[bit.rshift(b, 5) + 1], bit.lshift(1, bit.band(b, 0x1F)));
    end

    --- Flips bit b
    -- @param b bit to set
    function BitArray.prototype:flip(b)
        check(1, b, "number")
        self.bits[ bit.rshift(b, 5) + 1] = bit.bxor( self.bits[bit.rshift(b, 5) + 1], bit.lshift(1, bit.band(b, 0x1F))); 
    end

    --- Set a block of 32 bits, starting at bit b
    -- @param b first bit to set
    -- @param newBits the new value of the next 32bits.
    function BitArray.prototype:setBulk(b, newBits)
        check(1, self, "table");
        check(2, b, "number");
        check(3, newBits, "number");
        
        self.bits[ bit.rshift(b, 5) + 1 ] = newBits;
    end
    
    --- Clear all bits
    function BitArray.prototype:clear()
        local max = #self.bits;
        for i = 1, max do
            self.bits[i] = 0;
        end
    end
        
    --- Efficient method to check if a range of bits is setm or not set
    -- @param start the start value of range, inclusive
    -- @param finish  the end value of range, exclusive
    -- @param value if true, checks that the bits in range are set, otherwise that they are not set;
    -- @return true if all bits are set or not set in range, according to value argument
    function BitArray.prototype:isRange(start, finish, value)
        check(1, self, "table");
        check(2, start, "number");
        check(3, finish, "number");
        check(4, value, "boolean");

        if start > finish then
            error("The end value is must be greater than the start value", 2);
        end

        if start == finish then
            return true;
        end

        finish = finish - 1;
        local firstInt = bit.rshift(start, 5);
        local lastInt = bit.rshift(finish, 5);
        local mask = 0;
        for i = firstInt, lastInt, 1 do
            local firstBit = i > firstInt and 0 or bit.band(start, 0x1F);
            local lastBit = i < lastInt and 31 or bit.band(finish, 0x1F);
            if firstBit == 0 and lastBit == 31 then
                mask = -1
            else
                mask = 0;
                for j = firstBit, lastBit do
                    mask = bit.bor(mask, bit.lshift(1, j));
                end
            end

            if (bit.band(self.bits[i + 1], mask) ~= (value and mask or 0)) then
                return false
            end
        end
        return true
    end
    
    --- conover to bit, and writing into the array
    -- @param bitOffset first bit ti start writing
    -- @param array array to write into. Bytes are written most-significant bytes first.This is the opposits of the internal repressentation, which is exposed by (@see getBitArray) 
    -- @param offset position in array to start writing
    -- @param numBytes how many bytes to write
    function BitArray.prototype:toBytes(bitOffset, array, offset, numBytes)
        for i = 1, numBytes, 1 do
            local theByte = 0;
            for j = 0, 7 do
                if (self:get(bitOffset)) then
                    theByte = bit.bor(theByte, (bit.lshift(1, 7 - j)))
                end
                bitOffset = bitOffset + 1;
            end
            array[offset + i] = theByte
        end
    end

    function BitArray.prototype:getBitArray()
        return self.bits;
    end

    function BitArray.prototype:appendBit(b)
        check(1, b, "boolean");
        self:ensureCapacity(self.size + 1);
        if (b) then
           self.bits[bit.rshift(self.size, 5) + 1] = bit.bor(self.bits[bit.rshift(self.size, 5) + 1], (bit.lshift(1, bit.band(self.size, 0x1F)))); 
        end
        self.size = self.size + 1;
    end

    function BitArray.prototype:ensureCapacity(size)
        if ( size > bit.lshift(#self.bits, 5)) then
            local newBits = makeArray(size);
            for k,v in pairs(self.bits) do
                newBits[k] = v;
            end
            self.bits = newBits
        end
    end
    
    --- Appends the least-significant bits from value, in order from most-significant to least-significant.
    -- For example, appending 6 bits from 0x000001E will append the bits 0, 1, 1, 1, 1, 0 in that order
    -- @param number
    -- @param numBits
    function BitArray.prototype:appendBits(value, numBits)
        check(1, value, "number");
        check(2, numBits, "number")
        if numBits < 0 or numBits > 32 then
            error("num bits must be between 0 and 32", 2);
        end
        self:ensureCapacity(self.size + numBits);
        for numBitsLeft = numBits, 1, -1  do
           self:appendBit((bit.band(bit.rshift(value, (numBitsLeft - 1)), 0x01)) == 1)
        end
    end
    
    function BitArray.prototype:appendBitArray(other)
        check(1, other, "table");
        local othersize = other:getSize();
        self:ensureCapacity(othersize);
        for i = 0, othersize - 1 do
            self:appendBit(other:get(i));
        end
    end

    --- Reverses all bits in the array
    -- TODO: need test
    function BitArray.prototype.reverse()
        local newBits = new( #self.bits );
        local size = self.size;
        for i = 1, size do
            if (self:get(size - i)) then
                newBits[bit.rshift(i, 5) + 1] = bit.bor( newBits[bit.rshift(i, 5) + 1], bit.lshift(1, bit.band(i, 0x1F)));
            end
        end
    end
end

--[[
-- BitArray Test Unit
--]]
do
    --set/get
    local function test1()
        local array = BitArray:New(33);
        for i= 1, 33 do
            print(array:get(i), "false");
            
            array:set(i);

            print(array:get(i), "true");
        end
    end

    --set/bulk
    local function test2()
        local array = BitArray:New(64);
        array:setBulk(32, 0xFFFF0000);

        for i = 0, 47 do
            print(array:get(i), "false", i);
        end

        for i = 48, 63 do
            print(array:get(i), "true", i);
        end
    end
    
    local function testClear()
        local array = BitArray:New(32);
        for i = 1, 32 do
            array:set(i);
        end
        array:clear();
        for i = 1, 32 do
            assert(array:get(i) == false, i)
        end
    end

    local function testGetArray()
        local array = BitArray:New(64);

        array:set(0);
        array:set(63);
        local ints = array:getBitArray();
        print(ints[1], 1)
        print(ints[2])
    end

    local function testIsRange()
        local array = BitArray:New(64);
        print(array:isRange(0, 64, false), true);
        print(array:isRange(0, 64, true), false);

        array:set(32);
        print(array:isRange(32, 33, true), true);
        array:set(31);
        print(array:isRange(31, 33, true), true);
        array:set(34);
        print(array:isRange(31, 35, true), false);

        print(array:getSize())
        print(array:getSizeInBytes())
    end
end

--------------------------------------------------------------------
do
    GF256Poly.prototype = {};  
    local GF256Poly_MT = {__index = GF256Poly.prototype}

    --- Construct and return a new GF256Poly
    -- @param field the {@link GF256} instance repressentating the field to use to perform computations
    -- @param coefficients 
    -- TODO: update
    function GF256Poly:New(field, coefficients)
        check(1, self, "table");
        check(2, field, "table");
        check(3, coefficients, "table");

        local newObj = setmetatable({}, GF256Poly_MT);
        
        if coefficients == nil or #coefficients == 0 then
            error("coefficients need a table type", 2);
        end
        newObj.field = field;
        local coefficientsLength = #coefficients
        
        if (coefficientsLength > 1 and coefficients[1] == 0) then
            local firstNonZore = 1;
            while (firstNonZore < coefficientsLength and coefficients[firstNonZore] == 0) do
                firstNonZore = firstNonZore + 1;
            end
            if firstNonZore == coefficientsLength then
                newObj.coefficients = (field:getZero()).coefficients;
            else
                newObj.coefficients = new(coefficientsLength - firstNonZore);
                arraycopy(coefficients, firstNonZore, newObj.coefficients, 0, #newObj.coefficients);
            end
        else
            newObj.coefficients = coefficients;
        end
        return newObj
    end

    function GF256Poly.prototype:getCoefficients()
        return self.coefficients;
    end

    function GF256Poly.prototype:getDegree()
        return (#self.coefficients - 1);
    end

    function GF256Poly.prototype:isZero()
        return (self.coefficients[1] == 0);
    end

    function GF256Poly.prototype:getCoefficient(degree)
        return self.coefficients[#self.coefficients  - degree]
    end

    function GF256Poly.prototype:evaluateAt(a)
        if (a == 0) then
            return self:getCoefficient(0)
        end
        local size = #self.coefficients;
        if (a == 1) then
            local result = 0;
        end
    end

    function GF256Poly.prototype:multiplyByMonomial(degree, coefficient)
        if degree < 0 then
            error("Degree must be a integer number.", 2);
        end
        if coefficient == 0 then
            return self.field:getZero()
        end
        local size = #self.coefficients;
        local product = new(size + degree);
        for i = 1, size do
            product[i] = self.field:multiply(self.coefficients[i], coefficient);
        end
        return GF256Poly:New(self.field, product);
    end
   
    --TODO: puts data is error
    function GF256Poly.prototype:addOrSubtract(other)
        if self:isZero() then
            return other
        end

        if other:isZero() then
            return self
        end

        local smaller = self.coefficients;
        local larger = other.coefficients;
        
        if #smaller > #larger then
            local t = smaller;
            smaller = larger;
            larger = t;
        end

        local sumDiff = new(#larger);
        local lengthDiff = #larger - #smaller;
        arraycopy(larger, 1, smaller, 1, lengthDiff);
        
        for i = lengthDiff + 1, #larger do
            sumDiff[i] = GF256:addOrSubtract(smaller[i-lengthDiff], larger[i]);
        end
        
        return (GF256Poly:New(self.field, sumDiff));
    end

    function GF256Poly.prototype:multiply(other)
        check(1, other, "table")
        if (self.field ~= other.field) then
            error("GF256Polys do not have same GF256 field", 2);
        end

        if (self:isZero() or other:isZero()) then
            return self.field:getZero();
        end
        local aCoefficients = self.coefficients;
        local aLength = #aCoefficients;

        local bCoefficients = other.coefficients;
        local bLength = #bCoefficients;
        
        local product = new(aLength + bLength - 1);
        for i = 1, aLength, 1 do
            local aCoeff = aCoefficients[i];
            for j = 1, bLength, 1 do
                product[i + j - 1] = GF256:addOrSubtract(product[i+j-1], self.field:multiply(aCoeff, bCoefficients[j]));
            end
        end
        return GF256Poly:New(self.field, product);
    end

    function GF256Poly.prototype:divide(other)
        if (self.field ~= other.field) then
            error("GF256Polys do not have same GF256 field", 2);
        end
        if (other:isZero()) then
           error("Divide by 0", 2) 
        end

        local quotient = self.field:getZero();
        local remainder = self;
        
        local denominatorLeadingTerm = other:getCoefficient(other:getDegree());
        local inverseDeniminator = self.field:inverse(denominatorLeadingTerm);
        
        while ( (remainder:getDegree() >= other:getDegree()) and (not remainder:isZero()) ) do
            local diffDegree = remainder:getDegree() - other:getDegree()
            local scale = self.field:multiply(remainder:getCoefficient(remainder:getDegree()), inverseDeniminator);
            local term = other:multiplyByMonomial(diffDegree, scale);
            local interationQuotient = self.field:buildMonomial(diffDegree, scale);
            quotient = quotient:addOrSubtract(interationQuotient);
            remainder = remainder:addOrSubtract(term);
        end
        
        return {quotient, remainder};
    end
end
--------------------------------------------------------------------
do
    GF256.prototype = {}
    local GF256_MT = {__index = GF256.prototype};
    function GF256:New(primitive)
        local newObj = setmetatable({}, GF256_MT);
        newObj.expTable = new(256);
        newObj.logTable = new(256);

        local x = 1;
        for i = 1, 256 do
            newObj.expTable[i] = x
            x = bit.lshift(x, 1);
            if (x >= 0x100) then
                x = bit.bxor(primitive, x);
            end
        end

        for i= 0, 254 do
            newObj.logTable[newObj.expTable[i + 1]] = i;
        end
        
        newObj.zero = GF256Poly:New(newObj, {0});
        newObj.one = GF256Poly:New(newObj, {1});
        
        return newObj;
    end

    function GF256.prototype:getZero()
        return self.zero;
    end

    function GF256.prototype:getOne()
        return self.one;
    end

    function GF256.prototype:buildMonomial(degree, coefficient)
        check(1, degree, "number");
        check(2, coefficient, "number");
        if degree < 0 then
            error("The degree is must be greater than zero.", 2);
        end
        
        if coefficient == 0 then
            return self.zero;
        end

        local coefficients = new(degree + 1);
        coefficients[1] = coefficient;
        return GF256Poly:New(self, coefficients);
    end

    function GF256.prototype:addOrSubtract(a, b)
        return (bit.bxor(a, b))
    end

    function GF256:addOrSubtract(a, b)
        return (bit.bxor(a, b))
    end
    
    function GF256.prototype:inverse(a)
        check(1, a, "number");
        return (self.expTable[256 - self.logTable[a]])
    end

    function GF256.prototype:multiply(a, b)
        if a == 0 or b == 0 then
            return 0
        end
        local logSum = self.logTable[a] + self.logTable[b]
        return self.expTable[bit.band(logSum, 0xFF) + bit.arshift(logSum, 8) + 1]
    end

    function GF256.prototype:exp(a)
        return self.expTable[a]
    end

    do
        GF256.QR_CODE_FIELD = GF256:New(0x011D);-- x^8 + x^4 + x^ 4 + x^2 + x^1
        --GF256.DATA_MATRIX_FIELD = GF256:New(0x012D);-- x^8 + x^5 + x^3 + x^2 + 1
    end
end
---------------------------------------------------
-- ReedSolomonEncoder
---------------------------------------------------
do
    ReedSolomonEncoder.prototype = {}  
    local ReedSolomonEncoder_MT = { __index = ReedSolomonEncoder.prototype };

    function ReedSolomonEncoder:New(field)
        check(1, field, "table");
        local newObj = setmetatable({}, ReedSolomonEncoder_MT);
        
        if (field ~= GF256.QR_CODE_FIELD) then
            error("Only QR Code is supperted at this time", 2);
        end

        newObj.field = field;
        newObj.cachedGenerators = setmetatable({}, {__mode = "k"});
        tinsert(newObj.cachedGenerators, GF256Poly:New(field, {1}));
        return newObj;    
    end

    function ReedSolomonEncoder.prototype:builderGenerator(degree)
        if degree >= #self.cachedGenerators then
            local lastGenerator = self.cachedGenerators[#self.cachedGenerators];
            for d = #self.cachedGenerators, degree, 1 do
              local nextGenerator = lastGenerator:multiply(GF256Poly:New(self.field, {1, self.field:exp(d)}));
              tinsert(self.cachedGenerators, nextGenerator);
              lastGenerator = nextGenerator;
            end
        end
        return self.cachedGenerators[degree + 1]
    end

    function ReedSolomonEncoder.prototype:encode(toEncode, ecBytes)
        if ecBytes == 0 then
            error("No error correction bytes", 2)
        end
        local dataBytes = #toEncode - ecBytes;
        if dataBytes <= 0 then
            error("No data bytes provided.", 2)
        end
        local generator = self:builderGenerator(ecBytes);
        local infoCoefficients = new(dataBytes);
        arraycopy(toEncode, 1, infoCoefficients, 1, dataBytes);
        local info = GF256Poly:New(self.field, infoCoefficients);
        info = info:multiplyByMonomial(ecBytes, 1);
        local remainder = info:divide(generator)[2];
        local coefficients = remainder:getCoefficients();
        local numZeroCoefficients = ecBytes - #coefficients;
        for i = 1, numZeroCoefficients do
            toEncode[dataBytes + i] = 0
        end

        arraycopy(coefficients, 1, toEncode, dataBytes+numZeroCoefficients + 1, #coefficients)
    end
end

--[[
-- ReedSolomonEncoder, GF256, GF256Poly Test Unit
--]]
do
    local function test()
        local dataBytes = {
            0x10, 0x20, 0x0c, 0x56, 0x61, 0x80, 0xEC, 0x11,
            0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11
        }
        local expectedECBytes = {
            0xA5, 0x24, 0xd4, 0xc1, 0xed, 0x36, 0xc7, 0x87, 0x2c, 0x55
        }
    end

    local function testQRCodeVersus()
        local encoder = ReedSolomonEncoder:New(GF256.QR_CODE_FIELD);
        for i = 1, 100 do
            
        end
    end
end
---------------------------------------------------
-- Error Correction 
---------------------------------------------------
do
    ErrorCorrectionLevel.prototype = {};
    local ErrorCorrectionLevel_MT = {__index = ErrorCorrectionLevel.prototype}

    -- This enum encapsulates the four error correction levels defined 
    -- by the QRCode standard.
    function ErrorCorrectionLevel:New(ordinal, bits, name)
        local newObj = setmetatable({}, ErrorCorrectionLevel_MT);
        newObj.ordinal = ordinal;
        newObj.bits = bits;
        newObj.name = name;
        return newObj
    end

    function ErrorCorrectionLevel.prototype:Ordinal()
        return self.ordinal
    end

    function ErrorCorrectionLevel.prototype:getBits()
        return self.bits
    end

    function ErrorCorrectionLevel.prototype:getName()
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
end
-----------------------------------------------
--ECB method class
-----------------------------------------------
do
    ECB.prototype = {};
    local ECB_MT = { __index = ECB.prototype }

    --- Encapsualtes the parameters for one error-correction block in one symbol version.
    -- This includes the number of data codewords, and the number of times a block with these
    -- paramers is used consecutively in the QRCode version's format.
    function ECB:New(count, dataCodewords)
        check(1, count, "number");
        check(1, dataCodewords, "number");
        local newObj = setmetatable({}, ECB_MT);
        newObj.count = count;
        newObj.dataCodewords = dataCodewords;
        return newObj;
    end

    function ECB.prototype:getCount()
        return self.count;
    end

    function ECB.prototype:getDataCodewords()
        return self.dataCodewords;
    end
end
-----------------------------------------------
-- ECBlocks method class
-----------------------------------------------
do
    ECBlocks.prototype = {};
    local ECBlocks_MT = { __index = ECBlocks.prototype }
    function ECBlocks:New(ecCodewordsPerBlock, ...)
        local newObj = setmetatable({}, ECBlocks_MT);
        newObj.ecCodewordsPerBlock = ecCodewordsPerBlock;
        newObj.ecBlocks = {...};
        return newObj;
    end

    function ECBlocks.prototype:getECCodewordsPerBlock()
        return self.ecCodewordsPerBlock;
    end

    function ECBlocks.prototype:getNumBlocks()
        local total = 0;
        for i = 1, #self.ecBlocks do
            total = total + self.ecBlocks[i]:getCount();
        end
        return total
    end

    function ECBlocks.prototype:getTotalECCodewords()
        return self.ecCodewordsPerBlock * self:getNumBlocks();
    end

    function ECBlocks.prototype:getECBlocks()
        return self.ecBlocks;
    end
end
-----------------------------------------------
-- Version method class
-----------------------------------------------
do
    Version.prototype = {}
    local Version_MT = { __index = Version.prototype };

    function Version:New(versionNumber, alignmentPatternCenters, ...)
        check(1, versionNumber, "number");
        check(2, alignmentPatternCenters, "table");

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

    function Version.prototype:getVersionNumber()
        return self.versionNumber
    end

    function Version.prototype:getAlignmentPatternCenters()
        return self.alignmentPatternCenters
    end

    function Version.prototype:getTotalCodewords()
        return self.totalCodewords;
    end

    function Version.prototype:getDimensionForVersion()
        return QRCODE_MATRIX + QRCODE_MATRIX_PER_VERSION * self.versionNumber;
    end

    function Version.prototype:getECBlocksForLevel(ecLevel)
        return self.ecBlocks[ecLevel:Ordinal() + 1]
    end

    --- Deduce version information purely for the QRCode dimensions.
    --
    -- @param dimension dimension in modules;
    -- @return Version for a QRCode of that dimension;
    function Version.prototype:getProvisionalVersionForDimension(dimension)
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
end
------------------------------------------------
-- Mode method class
------------------------------------------------
do
    Mode.prototype = {};
    Mode_MT = {__index = Mode.prototype}

    function Mode:New(versions, bits, name)
        local newObj = setmetatable({}, Mode_MT)
        newObj.characterCountBitsForVersions = versions;
        newObj.bits = bits;
        newObj.name = name;
        return newObj
    end

    function Mode.prototype:forBits(bits)
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
    --  the count of characters that will follow encoded in this
    -- @param version  version in question
    -- @return  number of bits used, in this QRCode symbol. to encode
    function Mode.prototype:getCharacterCountBits(version)
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

    function Mode.prototype:getBits()
        return self.bits;
    end

    function Mode.prototype:getName()
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
end
------------------------------------------------
-- byte matrix class method
------------------------------------------------
do
    bMatrix.prototype = {}
    local bMatrix_MT = { __index = bMatrix.prototype}
    --- Construct and return a new bMatrix object 
    -- bytes is 2meta table. save y-x value 
    -- @param width value
    -- @param height value
    -- @usage bMatrix:New(21, 21)
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
                newObj.bytes[h][w] = 0
            end
        end
        return newObj
    end

    function bMatrix.prototype:getHeight()
        return self.height;
    end

    function bMatrix.prototype:getWidth()
        return self.width;
    end

    function bMatrix.prototype:getTable()
        return self.bytes;
    end

    function bMatrix.prototype:get(x, y)
        return self.bytes[y][x]
    end

    function bMatrix.prototype:set(x, y, value)
        self.bytes[y][x] = value
    end

    function bMatrix.prototype:clear(value)
        for y = 1, self.height do
            for x = 1, self.width do
                self.bytes[y][x] = value;
            end
        end
    end
end
--------------------------------------------------------
-- Matrix util
--------------------------------------------------------
do
    MatrixUtil.prototype = {}
    local MatrixUtil_MT = {__index = MatrixUtil.prototype};
    setmetatable(MatrixUtil, MatrixUtil_MT);    

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

    -- Type info cells at the left top corner.
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

    function MatrixUtil.prototype:clearMatrix(matrix)
        matrix:clear(-1)
    end

    function MatrixUtil.prototype:buildMatrix(dataBits, ecLevel, version, maskPattern, matrix)
        self:clearMatrix(matrix);

        --embeds base patterns
        self:embedBasicPatterns(version, matrix);
        --type infomation appear with any version
        --self:embedTypeInfo(ecLevel, maskPattern, matrix);

    end

    --- Embed basic patterns. On success, modify  the matrix and return true
    -- The basic patterns are:
    -- Position detection patterns
    -- Timing patterns
    -- Dark dont at the left bottom corner
    -- @param object version
    -- @param object version
    function MatrixUtil.prototype:embedBasicPatterns(version, matrix)
        --first
        -- lets get started with embedding big squares at corners
        self:embedPositionDetectionPatternAndSquarators(matrix);
            --then, embed the dark dot at the left bottom corner
            self:embedDarkDotAtLeftBottomConer(matrix);
            
            self:embedTimingPatterns(matrix)
    end

    function MatrixUtil.prototype:embedTimingPatterns(matrix)
            for i = 8, matrix:getWidth() - 7, 1 do
                    local b = (i + 1) % 2;
                    if (matrix:get(i + 1, 7) == -1) then
                            matrix:set(i + 1, 7, b);
                    end
                    if (matrix:get(7, i + 1) == -1) then
                            matrix:set(7, i + 1, b);
                    end
            end
    end

    function MatrixUtil.prototype:embedDarkDotAtLeftBottomConer(matrix)
            matrix:set(8 + 1, matrix:getHeight() - 8 + 1, 1);
    end

    function MatrixUtil.prototype:embedPositionDetectionPattern(xStart, yStart, matrix)
        for y = 1, 7 do
            for x = 1, 7 do
                matrix:set(xStart + x, yStart + y, self.POSITION_DETECTION_PATTERN[y][x])
            end
        end
    end

    function MatrixUtil.prototype:embedHorizontalSeparationPattern(xStart, yStart, matrix)
        if #self.HORIZONTAL_SEPARATION_PATTERN[1] ~= 8 or #self.HORIZONTAL_SEPARATION_PATTERN ~= 1 then
          error("bad horizontal separation pattern", 2);
        end
        for x = 1, 8 do
            matrix:set(xStart + x, yStart, self.HORIZONTAL_SEPARATION_PATTERN[1][x]);
        end
    end

    function MatrixUtil.prototype:embedVerticalSeparationPattern(xStart, yStart, matrix)
            for y = 1, 7 do
                    matrix:set(xStart, yStart+y, self.VERTICAL_SEPARATION_PATTERN[y][1]);
            end
    end

    function MatrixUtil.prototype:embedPositionDetectionPatternAndSquarators(matrix)
        local pdpWidth = #self.POSITION_DETECTION_PATTERN[1]
        
        --left top corner
        self:embedPositionDetectionPattern(0, 0, matrix);
        --right top corner
        self:embedPositionDetectionPattern(matrix:getWidth() - pdpWidth, 0 , matrix)
        --left bottom corner
        self:embedPositionDetectionPattern(0, matrix:getHeight() - pdpWidth, matrix);

        local hspWidth = #self.HORIZONTAL_SEPARATION_PATTERN[1]
        --left top corner
        self:embedHorizontalSeparationPattern(0, hspWidth, matrix); 

        --right top corner
        self:embedHorizontalSeparationPattern(matrix:getWidth() - hspWidth, hspWidth, matrix);

        --left bottom corner
        self:embedHorizontalSeparationPattern(0, matrix:getWidth() - hspWidth + 1, matrix);

        local vspSize = #self.VERTICAL_SEPARATION_PATTERN;
        --left
            self:embedVerticalSeparationPattern(vspSize, 0, matrix);     
        --right
            self:embedVerticalSeparationPattern(matrix:getWidth() - vspSize + 1, 0, matrix)
            --left bottom
            self:embedVerticalSeparationPattern(vspSize, matrix:getWidth() - vspSize + 1, matrix)
    end
end

do
    BlockPair.prototype = {}

    function BlockPair:New(data, errorCorrection)
        local newObj = setmetatable({}, {__index = BlockPair.prototype});
        newObj.dataBytes = data;
        newObj.errorCorrectionBytes = errorCorrection;

        return newObj
    end


    function BlockPair.prototype:getDataBytes()
        return self.dataBytes
    end

    function BlockPair.prototype:getErrorCorrectionBytes()
        return self.errorCorrectionBytes
    end
end

--------------------------------------------------------
-- Encode method class
--------------------------------------------------------
do
    Encode.prototype = {}
    local Encode_MT = {__index = Encode.prototype}
    
    function Encode:New(contents, ecLevel, hints, qrcode)
        local newObj = setmetatable({}, Encode_MT);
        local encoding = "";
        if hints == nil then
            encoding = "utf8";
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
            --TODO: donothing now.
        end
        newObj:appendModeInfo(mode, headerAndDataBits)
        local numLetters = (mode == Mode.BYTE) and dataBits:getSizeInBytes() or #contents;
        newObj:appendLengthInfo(numLetters, qrcode:GetVersion(), mode, headerAndDataBits);
        headerAndDataBits:appendBitArray(dataBits);

        -- setup 5: terminate the bits properly
        newObj:terminateBits(qrcode:GetNumDataBytes(), headerAndDataBits);
        -- setup 6: interleave data bits with error correction code;
        local finalBits = BitArray:New();
        --newObj:interLeaveWithECBytes(headerAndDataBits, qrcode:GetNumTotalBytes(), qrcode:GetNumDataBytes(), qrcode:GetNumRSBlocks(), finalBits);
        -- setup 7: choose the mask pattern and set to "qrCode"
        local matrix = bMatrix:New(qrcode:GetMatrixWidth(), qrcode:GetMatrixWidth()); 
        qrcode:SetMaskPattern(newObj:chooseMaskPattern(finalBits, qrcode:GetECLevel(), qrcode:GetVersion(), matrix));
        -- setup 8 build the matrix and set it to qrcode
        MatrixUtil:buildMatrix(finalBits, qrcode:GetECLevel(), qrcode:GetVersion(), qrcode:GetMaskPattern(), matrix)
        qrcode:SetMatrix(matrix);
        -- setup 9: make sure we have a vaild qrcode
        --if (not qrcode:isVaild()) then
        --    error("Invaild QR Code.", 2)
        --end
        return newObj
    end

    --- getAlphanumericCode 
    -- @return the code point of the table used in alphanumeric mode
    -- or -1 if there is no corresponding code in the table
    function Encode.prototype:getAlphanumericCode(c)
        local code = string.byte(c);
        if code <= #ALPHANUMERIC_TABLE then
            return (ALPHANUMERIC_TABLE[code + 1])
        end
        return -1;
    end

    -- TODO: only NUMERIC
    function Encode.prototype:chooseMode(contents, encoding)
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
    
    --TODO
    function Encode.prototype:chooseMaskPattern(bits, ecLevel, version, matrix)
        local minPenaly = 2^31 - 1;
        local bestMaskPattern = -1;
        for maskPattern = 1, NUM_MASK_PATTERNS do
            MatrixUtil:buildMatrix(bits, ecLevel, version, maskPattern, matrix);
            local panalty = self:calcMaskPattern(matrix);

        end
        return bestMaskPattern;
    end

    function Encode.prototype:calcMaskPattern(martix)

    end

    function Encode.prototype:appendBytes(content, mode, bits, encoding)
        if mode == Mode.NUMERIC then
            self:appendNumericBytes(content, bits)
        elseif mode == Mode.ALPHANUMERIC then

        elseif mode == Mode.BYTE then

        end
    end

    function Encode.prototype:appendNumericBytes(content, bits)
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
                bits:appendBits(num1 * 10 + num2, 7);
                i = i + 2;
            else
                bits:appendBits(num1, 4)
                i = i + 1;
            end
        end
    end

    function Encode.prototype:appendModeInfo(mode, bits)
        bits:appendBits(mode:getBits(), 4)
    end

    function Encode.prototype:appendLengthInfo(numLetters, version, mode, bits)
        local numBits = mode:getCharacterCountBits(Version:getVersionForNumber(version));
        if (numLetters > (bit.lshift(1, numBits) - 1)) then
            error(numLetters .. " is bigger than" .. ( bit.lshift(1, numBits) -1 ), 2);
        end
        bits:appendBits(numLetters, numBits);
    end

    function Encode.prototype:initQRCode(numInputsBytes, ecLevel, mode, qrcode)
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

    function Encode.prototype:terminateBits(numDataBytes, bits)
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
    function Encode.prototype:interLeaveWithECBytes(bits, numTotalBytes, numDataBytes, numRSBlocks, result)
        if (bits:getSizeInBytes() ~= numDataBytes) then
            error("Number of bits and data bytes does not match", 2);
        end
        
        -- Setup 1. Divide data bytes into blocks and generate error correction bytes for them
        -- We'll store the divided data bytes blocks and error correction bytes blocks into "blocks"
        local dataBytesOffset, maxNumDataBytes, maxNumEcBytes = 0, 0, 0;

        --since, we know the number of reedsolmon blocks. we can initialize the vector with the number
        local blocks = {};
        for i = 0, numRSBlocks - 1, 1 do
            local numDataBytesInBlock, numEcBytesInBlock = {}, {};
            self:getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes, numRSBlocks, i, numDataBytesInBlock, numEcBytesInBlock);
            local size = numDataBytesInBlock[1];
            local dataBytes = new(size);
            bits:toBytes(8 * dataBytesOffset, dataBytes, 0, size )
            local ecBytes = self:generateECBytes(dataBytes, numEcBytesInBlock[1]);
            tinsert(blocks, BlockPair:New(dataBytes, ecBytes));
            maxNumDataBytes = math.max(maxNumDataBytes, size);
            maxNumEcBytes = math.max(maxNumEcBytes, #ecBytes);
            dataBytesOffset = dataBytesOffset + numDataBytesInBlock[1]
          end

          if numDataBytes ~= dataBytesOffset then
            error("Data bytes does not match offset", 2)
          end
    end

    function Encode.prototype:generateECBytes(dataBytes, numEcBytesInBlock)
        check(1, dataBytes, "table");
        check(2, numEcBytesInBlock, "number");
        local numDataBytes = #dataBytes
        local toEncode = new(numDataBytes + numEcBytesInBlock);
        for i = 1, numDataBytes do
            toEncode[i] = bit.band(dataBytes[i], 0xFF);
        end
        local RSEncoder = ReedSolomonEncoder:New(GF256.QR_CODE_FIELD);
        RSEncoder:encode(toEncode, numEcBytesInBlock);

        local ecBytes = new(numEcBytesInBlock);
        for  i = 1, numEcBytesInBlock do
            ecBytes[i] = (toByte(toEncode[i]))
        end
        return ecBytes
    end

    --- Get number of data bytes and number of error correction bytes for block id "blockID".
    -- Store the result in "numDataBytesInBlock", and "numECBytesInBlocks".
    -- see table 12 in 8.5.1 of JISX0510:2004 (p.30)
    function Encode.prototype:getNumDataBytesAndNumECBytesForBlockID(numTotalBytes, numDataBytes, numRSBlocks, blockID, numDataBytesInBlock, numEcBytesInBlock)
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
end
--------------------------------------------------------
-- QRCodeWriter method class
--------------------------------------------------------
do
    QRCodeWriter.prototype = {}
    local QRCodeWriter_MT = { __index = QRCodeWriter.prototype}
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
        --newObj:renderResult(code, width, height);
        return newObj
    end

    local martixList = {};
    --- note that the input matrix uses 0 = white , 1 = black
    -- while the output matrix uses
    -- texture: WHITE8X8
    function QRCodeWriter.prototype:renderResult(code, width, height)
        --for wow game    
        local matrix = code:GetMatrix();
        if not code.frame then
            code.frame = CreateFrame("Frame", nil)
            code.frame:SetWidth(width);
            code.frame:SetHeight(height);
            code.frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                tile = true, 
                tileSize = 32, 
                edgeSize = 32, 
                insets = {
                    left = 11,
                    right = 12,
                    top = 12,
                    bottom = 11
                }
            });
            code.frame:SetBackdropColor(0, 0, 0);
            code.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
        end

            --clear/hide
        if #martixList > 0 then
            for i, m in pairs(martixList) do
                m:ClearAllPoints()
                m:Hide();
            end
        end
        
        --0 = white 1 = black
        local matrixWidth = matrix:getWidth();
        local texWidth = width / matrixWidth - 1;--scale?
        for y = 1, matrixWidth do
            for x = 1, matrixWidth do
                local texNum = (y - 1) * matrixWidth + x;
                local tex
                if martixList[texNum] then
                    tex = martixList[texNum];
                else
                    tex = code.frame:CreateTexture(nil, "ARTWORK");
                    martixList[texNum] = tex;
                end
                local c = matrix:get(x, y);
                tex:SetTexture([[Interface\BUTTONS\WHITE8X8]]);
                tex:SetPoint("TOPLEFT", code.frame, "TOPLEFT", x == 1 and texWidth or x * texWidth, y == 1 and -texWidth or -(y * texWidth));
                            tex:SetWidth(texWidth);
                tex:SetHeight(texWidth);
                tex:Show();
                if c == 1 then
                    tex:SetVertexColor(0, 0, 0); 
                elseif c == 0 then
                    tex:SetVertexColor(1, 1, 1);
                else
                    tex:SetVertexColor(1, 0, 0, 0.6);
                end
            end
        end
    end
end
--------------------------------------------------------

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
	--/dump LibStub("LibQRCode-1.0"):new()
end

--[[
-- QRCode Test Unit
--]]
do
    local function testqrcode()
        local qrCode = QRCode:New();
        qrCode:SetMode(Mode.BYTE);
        qrCode:SetECLevel(ECList.H);
        qrCode:SetVersion(7)
        qrCode:SetMatrixWidth(45);
        qrCode:SetMaskPattern(3);
        qrCode:SetNumTotalBytes(196);
        qrCode:SetNumDataBytes(66);
        qrCode:SetNumECBytes(130);
        qrCode:SetNumRSBlocks(5);

        assert(Mode.BYTE == qrCode:GetMode());
        print(ECList.H == qrCode:GetECLevel());
        print(7 == qrCode:GetVersion());
        print(45 == qrCode:GetMatrixWidth());
        print(3 == qrCode:GetMaskPattern());
        print(196 == qrCode:GetNumTotalBytes());
        print(66 == qrCode:GetNumDataBytes());
        print(130 == qrCode:GetNumECBytes());
        print(5 == qrCode:GetNumRSBlocks());

        print(qrCode:isVaild());

        local matrix = bMatrix:New(45, 45);
        for y = 1, 45 do
            for x = 1, 45 do
                matrix:set(x, y, (y + x) % 2);
            end
        end

        qrCode:SetMatrix(matrix);
        print(matrix, qrCode:GetMatrix());
        print(martix == qrCode:GetMatrix());
        print(qrCode:isVaild());
    end
end
