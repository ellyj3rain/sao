local arrayKeys={episodes=true,models=true,proposals=true,beliefs=true,hypotheses=true,evidenceIds=true,parentIds=true,missing=true,experiences=true}
local function quote(v)
    return '"'..string.gsub(v,'[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',string.byte(c))
    end)..'"'
end
local function encode(v,key)
    if type(v)=='string' then return quote(v) end
    if type(v)=='boolean' or type(v)=='number' then return tostring(v) end
    if type(v)~='table' then return 'null' end
    local parts={}
    if arrayKeys[key] then
        for _,x in ipairs(v) do parts[#parts+1]=encode(x) end
        return '['..table.concat(parts,',')..']'
    end
    for k,x in pairs(v) do parts[#parts+1]=quote(tostring(k))..':'..encode(x,k) end
    return '{'..table.concat(parts,',')..'}'
end
RESULT=encode(UNICODE_EXPORT and MAXIMAL_UNICODE_SNAPSHOT or MAXIMAL_EXPORT and MAXIMAL_SNAPSHOT or SAO.Cognition.snapshot('a'))
