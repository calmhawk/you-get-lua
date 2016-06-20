
local http = require("socket.http")

extractor = {}

function extractor:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

