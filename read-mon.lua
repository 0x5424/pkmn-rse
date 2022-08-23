--[[
  Utils for parsing the 80/100 pokemon bytes

  * parseMon(bytes80or100) produces a table with the following keys:

  local mon = parseMon(rawBytes)

  mon.species                         -- String:  species
  mon.nature                          -- String:  nature
  mon.pv                              -- Number:  4 byte personality value (parsed little endian)
  mon.checksum                        -- Number:  calculated checksum for the now decrypted data
  mon.hpIV                            -- Number:  HP IV
  mon.{atk,def,spAtk,spDef,speed}IV   -- Number:  corresponding IV for that stat
  mon.hiddenPower                     -- String:  Hidden Power type and power (TODO)
  mon.hpEV                            -- Number:  HP EV
  mon.{atk,def,spAtk,spDef,speed}EV   -- Number:  corresponding EV for that stat
  mon.move1                           -- String:  Move in slot 1
  mon.pp1                             -- Number:  Current PP for move in slot 1
  mon.move{2,3,4}                     -- String:  corresponding move for that slot
  mon.pp{2,3,4}                       -- Number:  current PP for move in that slot

  * partyInfo(bytes100) produces a table with the following keys:

  local mon = partyInfo(rawBytes)

  mon.hp                             -- Current HP
  mon.maxHp                          -- Max HP
  mon.{atk,def,spAtk,spDef,speed}    -- corresponding stat
]]

-- Load common helper utils
require("parsing-utils")

function readMon(bytes)
  local personalityValue = getBytes(bytes, 4)    -- 4 bytes, offset 0
  local trainerID        = getBytes(bytes, 4, 4) -- 4 bytes, offset 4

  -- Nature = personalityValue mod 25
  local nature = NATURE_MAP[asInt(personalityValue) % 25]

  -- Key = bitwise XOR trainerID with personalityValue
  local encryptionKey = tonumber(trainerID, 16) ~ tonumber(personalityValue, 16)

  -- Init checksum
  local calculatedChecksum = 0

  --[[
    Init decrypted data table, with the following keys:

    decryptedData.G       -- String: Growth substructure
    decryptedData.A       -- String: Attack substructure
    decryptedData.M       -- String: Misc. data substructure
    decryptedData.E       -- String: EV substructure

    Each string value must be further parsed to extract any useful information
  ]]
  local decryptedData = {
    ['G'] = nil,
    ['A'] = nil,
    ['M'] = nil,
    ['E'] = nil
  }

  -- Calc substructure order; pv mod 24
  local substructureOrder = SUBSTRUCTURE_MAP[asInt(personalityValue) % 24]

  -- Encrypted substructures
  local encryptedData = getBytes(bytes, 48, 32) -- 48 bytes, offset 32

  -- Begin decrypting substructures
  for i = 1, 4 do -- 1 upto 4, inclusive (1, 2, 3, 4)
    -- Init parsed data
    local dataDecrypted = ''

    -- Must offset by 12 bytes each iteration (48/4 = 12 byte chunks)
    local dataOffset = (i - 1) * 12
    local dataRaw = getBytes(encryptedData, 12, dataOffset)

    -- Decryption is the result of XOR-ing entirety of the above 12 bytes, 4 bytes at a time
    for offset = 0, 8, 4 do
      -- Get raw bytes, first as string
      local toXor = getBytes(dataRaw, 4, offset)

      -- Decrypted data = bitwise XOR these 4 bytes with the encryptionKey
      local decrypted = tonumber(toXor, 16) ~ encryptionKey

      -- Lastly, format data by including any leading 0's (%08x = pad up to eight 0's)
      dataDecrypted = dataDecrypted..string.format('%08x', decrypted)
    end

    -- Checksum is calculated by summing decrypted data 2 bytes at a time
    for offset = 0, 10, 2 do
      local toSum = getBytes(dataDecrypted, 2, offset)
      --[[
        Each 2 byte . Little endian
        Eg. given the following 12 bytes:

        > ff00 ff00 ff00 ff00 ff00 ff00

        The correct sum should be:

        > 255 + 255 + 255 + 255 + 255 + 255 = 1530

        If parsed *incorrectly* (as Big Endian), an erroneous sum would be:

        > 65280 + 65280 + 65280 + 65280 + 65280 + 65280 = 391680 (INCORRECT!)
      ]]
      calculatedChecksum = calculatedChecksum + asInt(toSum)
    end

    -- The string G, A, M, or E
    local currentSubstructure = substructureOrder:sub(i, i)

    decryptedData[currentSubstructure] = dataDecrypted
  end

  -- TODO: Calculate hidden power type + bp
  local hiddenPower = '(todo)'

  -- TODO: Make prettier
  local monStruct   = parseSubstruct(decryptedData.G, 'G')
  local movesStruct = parseSubstruct(decryptedData.A, 'A')
  local evStruct    = parseSubstruct(decryptedData.E, 'E')
  local miscStruct  = parseSubstruct(decryptedData.M, 'M')

  -- Return formatted data
  return {
    -- General
    ['species'] = monStruct.species,
    ['nature'] = nature,
    ['pv'] = asInt(personalityValue),
    ['checksum'] = calculatedChecksum,
    ['hiddenPower'] = hiddenPower,
    -- IV
    ['hpIV'] = miscStruct.hpIV, ['atkIV'] = miscStruct.atkIV, ['defIV'] = miscStruct.defIV,
    ['speedIV'] = miscStruct.speedIV, ['spAtkIV'] = miscStruct.spAtkIV, ['spDefIV'] = miscStruct.spDefIV,
    -- EV
    ['hpIV'] = evStruct.hpEV, ['atkIV'] = evStruct.atkEV, ['defIV'] = evStruct.defEV,
    ['speedIV'] = evStruct.speedEV, ['spAtkIV'] = evStruct.spAtkEV, ['spDefIV'] = evStruct.spDefEV,
    -- Moves
    ['move1'] = movesStruct.move1, ['move2'] = movesStruct.move2, ['move3'] = movesStruct.move3, ['move4'] = movesStruct.move4,
    ['pp1'] = movesStruct.pp1, ['pp2'] = movesStruct.pp2, ['pp3'] = movesStruct.pp3, ['pp4'] = movesStruct.pp4
  }
end
