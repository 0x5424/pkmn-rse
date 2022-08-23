-- TODO: Add support for JP mapping
-- TODO: Better support for ambiguous chars

--[[
  Proprietary character encoding for strings
  Currently only covers characters *input by a player*
]]
CHARACTER_MAP = {
    -- Numeric
    ["a1"] = "0", ["a2"] = "1", ["a3"] = "2", ["a4"] = "3", ["a5"] = "4",
    ["a6"] = "5", ["a7"] = "6", ["a8"] = "7", ["a9"] = "8", ["aa"] = "9",
    -- Symbols
    ["ab"] = "!", ["ac"] = "?", ["ad"] = ".",
    ["ae"] = "-", ["b8"] = ",", ["ba"] = "/",
    -- Uppercase A-Z
    ["bb"] = "A", ["bc"] = "B", ["bd"] = "C",
    ["be"] = "D", ["bf"] = "E", ["c0"] = "F",
    ["c1"] = "G", ["c2"] = "H", ["c3"] = "I",
    ["c4"] = "J", ["c5"] = "K", ["c6"] = "L",
    ["c7"] = "M", ["c8"] = "N", ["c9"] = "O",
    ["ca"] = "P", ["cb"] = "Q", ["cc"] = "R",
    ["cd"] = "S", ["ce"] = "T", ["cf"] = "U",
    ["d0"] = "V", ["d1"] = "W", ["d2"] = "X",
    ["d3"] = "Y", ["d4"] = "Z",
    -- Lowercase a-z
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

-- Decode a name given an entire 80/100 byte mon structure, number of bytes/chars to read, and start offset (in bytes)
function decodeName(raw, numBytes, offset)
  local output = ''
  local startIndex = (offset * 2) + 1
  local endIndex = startIndex + (numBytes * 2)

  -- Read N bytes; Omit last char pair
  for i = startIndex, (endIndex - 1), 2 do
    local pair = raw:sub(i, i + 1)
    local char = CHARACTER_MAP[pair]

    output = output..(char or ' ')
  end

  return output
end
