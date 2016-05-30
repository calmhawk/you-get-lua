
require extractor

local youku = extractor:new()

function youku.download(uri)
    print("youku:" .. uri)
end

return youku
