-- Valid Lua code mixed with intentional syntax errors
-- to trigger tree-sitter's (ERROR) @error capture node

local x = 10
print(x)

function greet(name)
  return "hello " .. name
end

-- Broken: triggers ERROR node
local = = = broken
if then end end end
function(((

-- More valid code after errors (tree-sitter recovers)
local dogs = {"Rex", "Buddy", "Max"}
for i, name in ipairs(dogs) do
  print(name)
end
