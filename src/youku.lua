
require "extractor"

local youku = extractor:new()

function youku.download(uri)
    local c = http.request(uri)
    print(c)
end

return youku
