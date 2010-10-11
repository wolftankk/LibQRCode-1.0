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
local MINOR_VERSION = 5
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

local function tryCatch(try, catch)
    check(1, try, "function");
    check(2, catch, "function");

    local error_msg;
    local function wrap(status, ...)
        if status then
            return ...
        else
            if catch(error_msg) == true then
                error(error_msg, 2)
            end
            return
        end
    end

    return wrap(xpcall(try, function(e)
        error_msg = e 
    end))
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

local QRCODE_MATRIX = 17;
local QRCODE_MATRIX_PER_VERSION = 4;
local NUM_MASK_PATTERNS = 8;
local VERSIONS = {};--version 1 ~ 40 container of the QRCode
local QUITE_ZONE_SIZE = 4;
local MAX_QRCODER_VERSIONS = 10;

---------------------------------------------------
-- QRCode
---------------------------------------------------
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
	check(1, self, "table");
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
            arraycopy(self.bits, 1, newBits, 1, #self.bits);
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
    function BitArray.prototype:reverse()
        local newBits = new( #self.bits );
        local size = self.size;
        for i = 1, size do
            if (self:get(size - i - 1)) then
                newBits[bit.rshift(i, 5) + 1] = bit.bor( newBits[bit.rshift(i, 5) + 1], bit.lshift(1, bit.band(i, 0x1F)));
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
end

---------------------------------------------------
-- GF256Poly
-- Represents a polynomial whose coefficients are elements of GF(256).Instances of this class are immutable.
---------------------------------------------------
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
	check(1, self, "table")
        return self.coefficients;
    end

    function GF256Poly.prototype:getDegree()
	check(1, self, "table");
        return (#self.coefficients - 1);
    end

    function GF256Poly.prototype:isZero()
	check(1, self, "table")
        return (self.coefficients[1] == 0);
    end
	
    --- @return coefficient of x^degree term in this polynomial
    function GF256Poly.prototype:getCoefficient(degree)
	check(1, self, "table")
        return self.coefficients[#self.coefficients - 1 - degree]
    end

    ---@return evaluation of this polynomial at a given point
    function GF256Poly.prototype:evaluateAt(a)
	check(1, self, "table")
        if (a == 0) then
            return self:getCoefficient(0)
        end
        local size = #self.coefficients;
        if (a == 1) then
            local result = 0;
            for i = 1, size do
	        result = GF256:addOrSubtract(result, self.coefficients[i]);
	    end
	    return result
        end

	local result = self.coefficients[1];
	for i = 2, #self.coefficients do
	    result = GF256:addOrSubtract(self.field:multiply(a, result), self.coefficients[i]);
	    end
	return result
    end

    function GF256Poly.prototype:addOrSubtract(other)
	check(1, self, "table");
	check(2, other, "table");
        if (self.field ~= other.field) then
            error("GF256Polys do not have same GF256 field", 2)
        end
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

    function GF256Poly.prototype:multiplyByMonomial(degree, coefficient)
        check(1, self, "table");
        check(2, degree, "number");
        check(3, coefficient, "number")
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
   
    function GF256Poly.prototype:multiply(other)
        check(1, self, "table")
        check(2, other, "table", "number");
        
        local argtype = type(other);
        if argtype == "table" then
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
        elseif argtype == "number" then
            local scalar = other;
            if scalar == 0 then
                return self.field:getZero()
            end

            if scalar == 1 then
                return self;
            end
            local size = #self.coefficients;
            local product = new(size);
            for i = 1, size do
                product[i] = self.field:multiply(self.coefficients[i], scalar);
            end
            return GF256Poly:New(self.field, product);
        end
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
        
        while ((remainder:getDegree() >= other:getDegree()) and (not remainder:isZero()) ) do
            local diffDegree = remainder:getDegree() - other:getDegree()
            local scale = self.field:multiply(remainder:getCoefficient(remainder:getDegree()), inverseDeniminator);
            local term = other:multiplyByMonomial(diffDegree, scale);
            local interationQuotient = self.field:buildMonomial(diffDegree, scale);
            quotient = quotient:addOrSubtract(interationQuotient);
            remainder = remainder:addOrSubtract(term);
        end
        
        return quotient, remainder
    end
end

-----------------------------------------------
-- GF256
-- This class contains utility methods for performing mathematical operations over
-- * the Galois Field GF(256). Operations use a given primitive polynomial in calculations.
-----------------------------------------------
do
    GF256.prototype = {}
    local GF256_MT = {__index = GF256.prototype};

    function GF256:New(primitive)
        check(1, primitive, "number");
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
        check(1, a, "number")
        check(2, b, "number")
        return (bit.bxor(a, b))
    end
    GF256.addOrSubtract = GF256.prototype.addOrSubtract

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

    function GF256.prototype:log(a)
        check(1, a, "number");
        if a == 0 then
            return
        end
        return self.logTable[a]
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
        check(1, self, "table");
        check(2, degree, "number");
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
        check(1, self, "table");
        check(2, toEncode, "table");
        check(3, ecBytes, "number");
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
        local _, remainder = info:divide(generator);
        local coefficients = remainder:getCoefficients();
        local numZeroCoefficients = ecBytes - #coefficients;
        for i = 1, numZeroCoefficients do
            toEncode[dataBytes + i] = 0
        end

        arraycopy(coefficients, 1, toEncode, dataBytes+numZeroCoefficients + 1, #coefficients)
    end
end

---------------------------------------------------
-- Error Correction 
---------------------------------------------------
do
do
    ErrorCorrectionLevel.prototype = {};
    local ErrorCorrectionLevel_MT = {__index = ErrorCorrectionLevel.prototype}

    -- This enum encapsulates the four error correction levels defined 
    -- by the QRCode standard.
    function ErrorCorrectionLevel:New(ordinal, bits, name)
        check(1, ordinal, "number");
        check(2, bits, "number");
        check(3, name, "string");
        local newObj = setmetatable({}, ErrorCorrectionLevel_MT);
        newObj.ordinal = ordinal;
        newObj.bits = bits;
        newObj.name = name;
        return newObj
    end

    function ErrorCorrectionLevel.prototype:Ordinal()
        check(1, self, "table");
        return self.ordinal
    end

    function ErrorCorrectionLevel.prototype:getBits()
        check(1, self, "table");
        return self.bits
    end

    function ErrorCorrectionLevel.prototype:getName()
        check(1, self, "table")
        return self.name
    end
    
    local FORBITS = {};

    function ErrorCorrectionLevel:forBits(bits)
        check(1, bits, "number")
        if bits < 0 or bits > #FORBITS then
            return
        end
        return FORBITS[bits]
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
        FORBITS = {L, M, Q, H}
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
        check(1, self, "table")
        return self.count;
    end

    function ECB.prototype:getDataCodewords()
        check(1, self, "table")
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
        check(1, self, "table")
        return self.ecCodewordsPerBlock;
    end

    function ECBlocks.prototype:getNumBlocks()
        check(1, self, "table")
        local total = 0;
        for i = 1, #self.ecBlocks do
            total = total + self.ecBlocks[i]:getCount();
        end
        return total
    end

    function ECBlocks.prototype:getTotalECCodewords()
        check(1, self, "table")
        return self.ecCodewordsPerBlock * self:getNumBlocks();
    end

    function ECBlocks.prototype:getECBlocks()
        check(1, self, "table")
        return self.ecBlocks;
    end
end

-----------------------------------------------
-- Version method class
-----------------------------------------------
do
    Version.prototype = {}
    local Version_MT = { __index = Version.prototype };

    local VERSION_DECODE_INFO = {
      0x07C94, 0x085BC, 0x09A99, 0x0A4D3, 0x0BBF6,
      0x0C762, 0x0D847, 0x0E60D, 0x0F928, 0x10B78,
      0x1145D, 0x12A17, 0x13532, 0x149A6, 0x15683,
      0x168C9, 0x177EC, 0x18EC4, 0x191E1, 0x1AFAB,
      0x1B08E, 0x1CC1A, 0x1D33F, 0x1ED75, 0x1F250,
      0x209D5, 0x216F0, 0x228BA, 0x2379F, 0x24B0B,
      0x2542E, 0x26A64, 0x27541, 0x28C69
    };

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
            return Mode.TERMINATOR
        elseif bits == 0x01 then
            return Mode.NUMERIC
        elseif bits == 0x02 then
            return Mode.ALPHANUMERIC;
        elseif bits == 0x03 then
            return Mode.STRUCTURED_APPED;
        elseif bits == 0x04 then
            return Mode.BYTE;
        elseif bits == 0x05 then
            return Mode.FNC1_FIRST_POSITION;
        elseif bits == 0x07 then
            return Mode.ECI
        elseif bits == 0x08 then
            return Mode.KANJI;
        elseif bits == 0x09 then
            return Mode.FNC1_SECOND_POSITION;
        else
            error("bits is invaild value, not the mode",2);
        end
    end
    Mode.forBits = Mode.prototype.forBits

    --- get character count bit for versions
    --  the count of characters that will follow encoded in this
    -- @param version  version in question
    -- @return  number of bits used, in this QRCode symbol. to encode
    function Mode.prototype:getCharacterCountBits(version)
        check(1, self, "table");
        check(2, version, "number");
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
        check(1, self, "table");
        return self.bits;
    end

    function Mode.prototype:getName()
        check(1, self, "table");
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
        return toByte(self.bytes[y][x]);
    end

    function bMatrix.prototype:set(x, y, value)
        check(1, x, "number")
        check(2, y , "number");
        check(3, value, "number", "boolean");
        if type(value) == "boolean" then
            self.bytes[y][x] = value and 1 or 0;
        else
            self.bytes[y][x] = value;
        end
    end

    function bMatrix.prototype:clear(value)
        local value = toByte(value);
        for y = 1, self.height do
            for x = 1, self.width do
                self.bytes[y][x] = value;
            end
        end
    end
end

