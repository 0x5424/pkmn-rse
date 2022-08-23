-- Defines the `ALL_POKEMON` table
require('pkmn')

-- Defines the `ALL_MOVES` table
require('moves')

-- Based on personalityValue mod 24, the mon's encrypted data will be persisted in the following order
SUBSTRUCTURE_MAP = {
  [0] = "GAEM",   [1] = "GAME",  [2] = "GEAM",  [3] = "GEMA",
  [4] = "GMAE",   [5] = "GMEA",  [6] = "AGEM",  [7] = "AGME",
  [8] = "AEGM",   [9] = "AEMG", [10] = "AMGE", [11] = "AMEG",
  [12] = "EGAM", [13] = "EGMA", [14] = "EAGM", [15] = "EAMG",
  [16] = "EMGA", [17] = "EMAG", [18] = "MGAE", [19] = "MGEA",
  [20] = "MAGE", [21] = "MAEG", [22] = "MEGA", [23] = "MEAG"
}

--[[
  Based on personalityValue mod 25; Table is arranged as follows:

        | ATK | DEF |  SPE | SpA | SpD |
   +ATK |  0
   +DEF |        0
   +SPE |               0
   +SpA |                     0
   +SpD |                           0

  Each row represents the boosted stat, columns are the reduced stat.
  Where the boon & bane intersect is a neutral nature
]]
NATURE_MAP = {
  --
  [0] = "Hardy",    [1] = "Lonely",  [2] = "Brave",    [3] = "Adamant",  [4] = "Naughty",
  [5] = "Bold",     [6] = "Docile",  [7] = "Relaxed",  [8] = "Impish",   [9] = "Lax",
  [10] = "Timid",  [11] = "Hasty",  [12] = "Serious", [13] = "Jolly",   [14] = "Naive",
  [15] = "Modest", [16] = "Mild",   [17] = "Quiet",   [18] = "Bashful", [19] = "Rash",
  [20] = "Calm",   [21] = "Gentle", [22] = "Sassy",   [23] = "Careful", [24] = "Quirky"
}

-- Get # of bytes from hex string, supplying an optional offset (in bytes)
function getBytes(raw, numBytes, offset)
  -- If offset given, use it, or default to index 1
  offset = offset or 0
  local startIndex = (offset * 2) + 1
  local charLength = numBytes * 2 -- 2 hex chars = 1 byte

  local endIndex = (startIndex - 1) + charLength

  return raw:sub(startIndex, endIndex)
end

-- Returns bits with optional 0 padding, big endian style. Accepts either hex string or integer
-- eg. asBin(0f, 8) = 00001111, asBin(0f) = 1111, asBin(f0) = 11110000
function asBin(ambiguous, bits)
  local num = type(ambiguous) == "string" and tonumber(ambiguous, 16) or ambiguous

  -- returns a table of bits, most significant first.
  bits = bits or math.max(1, select(2, math.frexp(num)))
  local t = {} -- will contain the bits
  for b = bits, 1, -1 do
    t[b] = math.fmod(num, 2)
    num = math.floor((num - t[b]) / 2)
  end
  return table.concat(t)
end

-- Parse hex string as little endian; Use tonumber(str, 16) if big endian desired
function asInt(hexStr)
  local toParse = ''

  for i = 1, #hexStr, 2 do
    local startChar = (#hexStr - i)
    toParse = toParse..hexStr:sub(startChar, startChar + 1)
  end

  return tonumber(toParse, 16)
end

-- Given the 4 bytes comprising the IV substructure, output into the given table
function parseIV(hexStr)
  assert(#hexStr == 8, 'must be 4 bytes')
  -- Fix endianness, once again
  -- eg. 0xd5a85d03 == 11010101101010000101110100000011 in bigEndian
  -- but the actual bin order should be: 00000011010111011010100011010101
  -- 31-Ability = 0
  -- 30-Egg     = 0
  -- 25-Sp.Def  = 00001  (1)
  -- 20-Sp.Atk  = 10101 (21)
  -- 14-Speed   = 11011 (27)
  -- 10-Defense = 01010 (10)
  -- 5-Attack   = 00110  (6)
  -- 0-HP       = 10101 (21)
  local binStr = asBin(hexStr, 32)

  -- Parse IVs 5 bits at a time; (TODO: make DRY)
  local hpIV =    tonumber(binStr:sub(28, 32), 2)
  local atkIV =   tonumber(binStr:sub(23, 27), 2)
  local defIV =   tonumber(binStr:sub(18, 22), 2)
  local speedIV = tonumber(binStr:sub(13, 17), 2)
  local spAtkIV = tonumber(binStr:sub(8, 12), 2)
  local spDefIV = tonumber(binStr:sub(3, 7), 2)

  return {
    ["hpIV"] = hpIV, ["atkIV"] = atkIV, ["defIV"] = defIV,
    ["spAtkIV"] = spAtkIV, ["spDefIV"] = spDefIV,
    ["speedIV"] = speedIV
  }
end

-- Given decrypted substructure, decode into human readable table
-- TODO: Clean this up
function parseSubstruct(decryptedData, kind)
  -- Byte offsets
  local order = {
    -- General
    ['G'] = {
      -- KEY     => offset, length (both in bytes)
      ['SPECIES'] = {0, 2},
      ['HELD_ITEM'] = {2 ,2},
      ['EXP'] = {4 ,4},
      ['PP'] = {8 ,1},
      ['FRIENDSHIP'] = {9 ,1},
      ['?'] = {10, 2} -- likely padding
    },
    -- Attacks
    ['A'] = {
      ['MOVE1'] = {0, 2},
      ['MOVE2'] = {2, 2},
      ['MOVE3'] = {4, 2},
      ['MOVE4'] = {6, 2},
      ['PP1'] = {8, 1},
      ['PP2'] = {9, 1},
      ['PP3'] = {10, 1},
      ['PP4'] = {11, 1}
    },
    -- Effort Values
    ['E'] = {
      ['HP'] = {0, 1},
      ['ATTACK'] = {1, 1}, ['DEFENSE'] = {2, 1},
      ['SPEED'] = {3, 1},
      ['SPECIAL ATTACK'] = {4, 1}, ['SPECIAL DEFENSE'] = {5, 1},
      ['COOL'] = {6, 1}, ['BEAUTY'] = {7, 1}, ['CUTE'] = {8, 1}, ['SMART'] = {9, 1}, ['TOUGH'] = {10, 1},
      ['FEEL'] = {11, 1}
   },
    -- Misc.
    ['M'] = {
      ['POKERUS'] = {0, 1},
      ['MET'] = {1, 1},
      ['ORIGIN'] = {2, 2},
      ['IV'] = {4, 4},
      ['RIBBON'] = {8, 4}
    }
  }
  assert(order[kind], "kind must be G, A, M, or E")

  local out = {}

  -- Return formatted table for relevant kind
  if (kind == 'G') then
    local value = getBytes(decryptedData, 2)

    out['species'] = ALL_POKEMON[asInt(value)]
  elseif (kind == 'A') then
    for i = 1, 4, 1 do
      local moveKey = 'MOVE'..i
      local ppKey = 'PP'..i

      local moveOffsets = order[kind][moveKey]
      local ppOffsets = order[kind][ppKey]

      local moveValue = getBytes(decryptedData, moveOffsets[2], moveOffsets[1])
      local ppValue   = getBytes(decryptedData, ppOffsets[2], ppOffsets[1])

      out[moveKey:lower()] = ALL_MOVES[asInt(moveValue)]
      out[ppKey:lower()] = asInt(ppValue)
    end
  elseif (kind == 'E') then
    local hpEV = getBytes(decryptedData, 1)
    local atkEV = getBytes(decryptedData, 1, 1)
    local defEV = getBytes(decryptedData, 1, 2)
    local speedEV = getBytes(decryptedData, 1, 3)
    local spAtkEV = getBytes(decryptedData, 1, 4)
    local spDefEV = getBytes(decryptedData, 1, 5)

    out['hpEV'] = asInt(hpEV)
    out['atkEV'] = asInt(atkEV)
    out['defEV'] = asInt(defEV)
    out['spAtkEV'] = asInt(spAtkEV)
    out['spDefEV'] = asInt(spDefEV)
    out['speedEV'] = asInt(speedEV)
  elseif (kind == 'M') then
    local dataIV = getBytes(decryptedData, 4, 4)
    dataIV = string.format('%08x', asInt(dataIV)) -- Flip endianness before re-parsing as hex string

    for stat, valueIV in pairs(parseIV(dataIV)) do out[stat] = valueIV end
  end

  return out
end
