-- TODO (in order):
-- [ ] Fetch party slot0 pokemon (first mon)
-- [ ] Fetch rest
-- [ ] Add frame loop to constantly run this check
-- [ ] Move shared logic to utils

-- Proprietary encoding used for a few text fields
CHAR_MAP = {
    ["bb"] = "A", ["bc"] = "B", ["bd"] = "C",
    ["be"] = "D", ["bf"] = "E", ["c0"] = "F",
    ["c1"] = "G", ["c2"] = "H", ["c3"] = "I",
    ["c4"] = "J", ["c5"] = "K", ["c6"] = "L",
    ["c7"] = "M", ["c8"] = "N", ["c9"] = "O",
    ["ca"] = "P", ["cb"] = "Q", ["cc"] = "R",
    ["cd"] = "S", ["ce"] = "T", ["cf"] = "U",
    ["d0"] = "V", ["d1"] = "W", ["d2"] = "X",
    ["d3"] = "Y", ["d4"] = "Z",
    ["d5"] = "a", ["d6"] = "b", ["d7"] = "c",
    ["d8"] = "d", ["d9"] = "e", ["da"] = "f",
    ["db"] = "g", ["dc"] = "h", ["dd"] = "i",
    ["de"] = "j", ["df"] = "k", ["e0"] = "l",
    ["e1"] = "m", ["e2"] = "n", ["e3"] = "o",
    ["e4"] = "p", ["e5"] = "q", ["e6"] = "r",
    ["e7"] = "s", ["e8"] = "t", ["e9"] = "u",
    ["ea"] = "v", ["eb"] = "w", ["ec"] = "x",
    ["ed"] = "y", ["ee"] = "z"
}

-- 48 bytes starting at 32 are encoded; The pokemon PV mod 24 determines the substructure order
SUBSTRUCTURE_MAP = {
  [0] = "GAEM",   [1] = "GAME",  [2] = "GEAM",  [3] = "GEMA",
  [4] = "GMAE",   [5] = "GMEA",  [6] = "AGEM",  [7] = "AGME",
  [8] = "AEGM",   [9] = "AEMG", [10] = "AMGE", [11] = "AMEG",
  [12] = "EGAM", [13] = "EGMA", [14] = "EAGM", [15] = "EAMG",
  [16] = "EMGA", [17] = "EMAG", [18] = "MGAE", [19] = "MGEA",
  [20] = "MAGE", [21] = "MAEG", [22] = "MEGA", [23] = "MEAG"
}

--[[
Example dumps:

-- No marks
MUDKIP = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0059d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"

-- constant name corresponds to the marking made
CIRCLE   = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0159d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"
SQUARE   = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0259d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"
TRIANGLE = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0459d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"
HEART    = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0859d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"

-- All marks
MUDKIP = "bb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0f59d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"

]]

MUDKIP = "881cbb6ad6cb4f8bbce9d8ffffffffffffff0202bbd3bfffffffff0f59d000005ed6f4e15ed7f4e15ed7f4e15ec7f1408b7fa9e25ed7f4e145d6f4e1c8d7f4e15e9ff4e17fd7d9e15ed7f4e17dfff4e10000000005ff150015000c000b0009000b000a00"

-- Returns bits as given; eg. 0f = 00001111, f0 = 11110000
function asBin(hexStr, bits)
  local num = tonumber(hexStr, 16)
  -- returns a table of bits, most significant first.
  bits = bits or math.max(1, select(2, math.frexp(num)))
  local t = {} -- will contain the bits
  for b = bits, 1, -1 do
    t[b] = math.fmod(num, 2)
    num = math.floor((num - t[b]) / 2)
  end
  return table.concat(t)
end

-- Parse hex string, default little endian (ff00 -> 255)
function asDec(raw, bigEndian)
  local little = not bigEndian

  local toParse = ''
  if (little) then
    for i = 1, #raw, 2 do
      -- as always... 1-indexed...
      local startChar = (#raw - i)
      toParse = toParse..raw:sub(startChar, startChar + 1)
    end
  else
    toParse = toParse..raw
  end

  return tostring(tonumber(toParse, 16))
end

-- Get # of bytes from hex string, supplying an optional offset (in bytes)
function getBytes(raw, numBytes, offset)
  -- If offset given, use it, or default to index 1
  offset = offset or 0
  local startIndex = (offset * 2) + 1
  local charLength = numBytes * 2 -- 2 hex chars = 1 byte

  local endIndex = (startIndex - 1) + charLength

  return raw:sub(startIndex, endIndex)
end

function parseName(raw, numBytes, offset)
  local output = ''
  local startIndex = (offset * 2) + 1
  local endIndex = startIndex + (numBytes * 2)

  -- Read N bytes; Omit last char pair
  for i = startIndex, (endIndex - 1), 2 do
    local pair = raw:sub(i, i + 1)
    local char = CHAR_MAP[pair]

    output = output..(char or ' ')
  end

  return output
end

function log(label, result)
  io.write(label..": "..result.."\n")
end

-------- BEGIN PARSING

-- PV = 4 bytes starting at 0 (12, 34, 56, 78)
local personalityValue = getBytes(MUDKIP, 4)
log("PV", personalityValue)

-- OT ID = 4 bytes at offset 4
local trainerFull = getBytes(MUDKIP, 4, 4)
log("OT", trainerFull)

-- Visible ID = first 2 bytes
local trainerSecret = getBytes(trainerFull, 2)
log(" - ID", trainerSecret.." ("..asDec(trainerSecret)..")")

-- Secret ID = last 2 bytes
local trainerVisible = getBytes(trainerFull, 2, 2)
log(" - SID", trainerVisible.." ("..asDec(trainerVisible)..")")

-- Nickname = 10 bytes at offset 8
local nickname = parseName(MUDKIP, 10, 8)
log("NICKNAME", nickname)

-- Language = 1 byte at offset 18 (1=jp, 2=en, 3=fr, 4=it, 5=de, 6=kr, 7=es)
LOCALE_MAP = {
  ["01"] = "ja", ["02"] = "en", ["03"] = "fr",
  ["04"] = "it", ["05"] = "de", ["06"] = "kr",
  ["07"] = "es",
}
local lang = getBytes(MUDKIP, 1, 18)
log("LANG", lang.." ("..LOCALE_MAP[lang]..")")

-- Egg name = 1 byte at offset 19, each bit represents an egg attribute
-- *MSB bits* 01234 = padding, 5=isEgg, 6=hasSpecies, 7=isValidChecksum (bad egg)
local eggName = getBytes(MUDKIP, 1, 19)
log("EGG", asBin(eggName, 8))

-- Trainer name = 7 bytes at offset 20
local trainerName = parseName(MUDKIP, 7, 20)
log("TRAINER", trainerName)

-- Markings = 1 byte at offset 27
local markings = getBytes(MUDKIP, 1, 27)
log("MARK", markings..' ('..asBin(markings, 8)..')')

-- Checksum = 2 bytes at offset 28
local checksum = getBytes(MUDKIP, 2, 28)
log("CHKSUM", checksum)

-- Padding? = 2 bytes at offset 30
log("???", getBytes(MUDKIP, 2, 30))

-- Pokemon data = 48 bytes at offset 32
local pkmnRaw = getBytes(MUDKIP, 48, 32)
log("PKMN (raw)", pkmnRaw)

-- Remember: No russian (little endian for all numeric operations)
local pvModulo = asDec(personalityValue) % 24
local dataOrder = SUBSTRUCTURE_MAP[pvModulo]
log(" - ORDER", tostring(pvModulo)..'. '..dataOrder)

local encryptionKey = tonumber(trainerFull, 16) ~ tonumber(personalityValue, 16)
log(" - KEY", string.format("%02x", encryptionKey))

-- Parse each 12 bytes of the raw pokemon data
for i = 1, 4, 1 do
  local currentStructure = dataOrder:sub(i, i)
  local dataOffset = (i - 1) * 12
  local encryptedData = getBytes(pkmnRaw, 12, dataOffset)
  local decryptedData = ''
  -- Decrypt the 12 bytes, 4 bytes at a time (offsets= 0, 4, 8)
  for chunkOffset = 0, 8, 4 do
    local rawData = getBytes(encryptedData, 4, chunkOffset)
    local decrypted = tonumber(rawData, 16) ~ encryptionKey

    decryptedData = decryptedData..string.format("%08x", decrypted)
  end
  log(" - "..currentStructure, decryptedData)
  -- TODO: Parse data based on current structure; parse("G", data) => {species: 'etc'...}
end

-- Status = 4 bytes at offset 80
local pkmnStatus = getBytes(MUDKIP, 4, 80)
log("STATUS", pkmnStatus..(' ('..asBin(pkmnStatus, 32)..')'))

-- Level = 1 byte at offset 84
local pkmnLevel = getBytes(MUDKIP, 1, 84)
log("LV", asDec(pkmnLevel))

-- Pokerus = 1 byte at offset 85
local pkmnPkrs = getBytes(MUDKIP, 1, 85)
log("PKRS", asBin(pkmnPkrs))

-- Current HP = 2 bytes at offset 86
-- Max HP = 2 bytes at offset 88
local currentHp = getBytes(MUDKIP, 2, 86)
local maxHp = getBytes(MUDKIP, 2, 88)
log("HP", asDec(currentHp)..'/'..asDec(maxHp))

-- Attack = 2 bytes at offset 90
local attack = getBytes(MUDKIP, 2, 90)
log("ATTACK", asDec(attack))

-- Defense = 2 bytes at offset 92
local defense = getBytes(MUDKIP, 2, 92)
log("DEFENSE", asDec(defense))

-- Speed = 2 bytes at offset 94
local speed = getBytes(MUDKIP, 2, 94)
log("SPEED", asDec(speed))

-- Special Attack = 2 bytes at offset 96
local spAttack = getBytes(MUDKIP, 2, 96)
log("SP.ATTACK", asDec(spAttack))

-- Special Defense = last 2 bytes at offset 98
local spDefense = getBytes(MUDKIP, 2, 98)
log("SP.DEFENSE", asDec(spDefense))

