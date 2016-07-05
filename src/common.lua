
local ltn12 = require "ltn12"

local url = require("socket.url")
local argparse = require "argparse"
local version = 1.0

local SITES = {
    ["163"]              = "netease",
    ["56"]               = "w56",
    ["acfun"]            = "acfun",
    ["archive"]          = "archive",
    ["baidu"]            = "baidu",
    ["bandcamp"]         = "bandcamp",
    ["baomihua"]         = "baomihua",
    ["bilibili"]         = "bilibili",
    ["cntv"]             = "cntv",
    ["cbs"]              = "cbs",
    ["dailymotion"]      = "dailymotion",
    ["dilidili"]         = "dilidili",
    ["dongting"]         = "dongting",
    ["douban"]           = "douban",
    ["douyu"]            = "douyutv",
    ["ehow"]             = "ehow",
    ["facebook"]         = "facebook",
    ["fc2"]              = "fc2video",
    ["flickr"]           = "flickr",
    ["freesound"]        = "freesound",
    ["fun"]              = "funshion",
    ["google"]           = "google",
    ["heavy-music"]      = "heavymusic",
    ["huaban"]           = "huaban",
    ["iask"]             = "sina",
    ["ifeng"]            = "ifeng",
    ["imgur"]            = "imgur",
    ["in"]               = "alive",
    ["infoq"]            = "infoq",
    ["instagram"]        = "instagram",
    ["interest"]         = "interest",
    ["iqilu"]            = "iqilu",
    ["iqiyi"]            = "iqiyi",
    ["isuntv"]           = "suntv",
    ["joy"]              = "joy",
    ["jpopsuki"]         = "jpopsuki",
    ["kankanews"]        = "bilibili",
    ["khanacademy"]      = "khan",
    ["ku6"]              = "ku6",
    ["kugou"]            = "kugou",
    ["kuwo"]             = "kuwo",
    ["le"]               = "le",
    ["letv"]             = "le",
    ["lizhi"]            = "lizhi",
    ["magisto"]          = "magisto",
    ["metacafe"]         = "metacafe",
    ["miomio"]           = "miomio",
    ["mixcloud"]         = "mixcloud",
    ["mtv81"]            = "mtv81",
    ["musicplayon"]      = "musicplayon",
    ["7gogo"]            = "nanagogo",
    ["nicovideo"]        = "nicovideo",
    ["pinterest"]        = "pinterest",
    ["pixnet"]           = "pixnet",
    ["pptv"]             = "pptv",
    ["qianmo"]           = "qianmo",
    ["qq"]               = "qq",
    ["sina"]             = "sina",
    ["smgbb"]            = "bilibili",
    ["sohu"]             = "sohu",
    ["soundcloud"]       = "soundcloud",
    ["ted"]              = "ted",
    ["theplatform"]      = "theplatform",
    ["thvideo"]          = "thvideo",
    ["tucao"]            = "tucao",
    ["tudou"]            = "tudou",
    ["tumblr"]           = "tumblr",
    ["twimg"]            = "twitter",
    ["twitter"]          = "twitter",
    ["videomega"]        = "videomega",
    ["vidto"]            = "vidto",
    ["vimeo"]            = "vimeo",
    ["weibo"]            = "miaopai",
    ["veoh"]             = "veoh",
    ["vine"]             = "vine",
    ["vk"]               = "vk",
    ["xiami"]            = "xiami",
    ["xiaokaxiu"]        = "yixia",
    ["xiaojiadianvideo"] = "fc2video",
    ["yinyuetai"]        = "yinyuetai",
    ["miaopai"]          = "yixia",
    ["youku"]            = "youku",
    ["youtu"]            = "youtube",
    ["youtube"]          = "youtube",
    ["zhanqi"]           = "zhanqi",
}

function print_r( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

function get_content(url, headers)
    local http = require("socket.http")
    local b = {}
    local _,c,s,h = http.request{url=url, sink=ltn12.sink.table(b), headers=headers}
    return table.concat(b), c, s, h
end

function hex_dump(buf)
    for i=1,#buf do
        if(buf:byte(i) > 126 or buf:byte(i) < 32) then
            io.write(string.format('\\x%02x', buf:byte(i)))
        else
            io.write(string.char(buf:byte(i)))
        end
    end
    io.write('\n')
end

function quoted(str, safe)
    safe = '[^%w ]' .. safe
    if (str) then
        str = str:gsub("\n", "\r\n")
        str = str:gsub(safe,
        function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = str:gsub(" ", "+")
    end
    return str    
end

string.split = function(s, sep)
    local rt= {}
    s:gsub('[^'..sep..']+', function(w) table.insert(rt, w) end )
    return rt
end

table.extend = function(t, tbl)
    for _,e in pairs(tbl) do
        table.insert(t, e)
    end
end

function build_params(params)
    local r = ''
    for k,v in pairs(params) do
        r = r .. k .. '=' .. url.escape(v) .. '&'
    end
    return r:sub(1,-2)
end

function parse_args()
    local parser = argparse("script", "An example.")
    parser:argument("urls", "origin video urls."):args("+")
    parser:option("-V --version", "Print Version.", version)

    local args = parser:parse()
    return args['urls']
end

function exec(command)    
    local pp = io.popen(command) 
    local data = pp:read("*a")
    pp:close()            
   
    return data           
end

function exists(name)
    if type(name)~="string" then return false end
    return os.rename(name,name) and true or false
end

function isfile(name)
    if type(name)~="string" then return false end
    if not exists(name) then return false end
    local f = io.open(name)
    if f then
        f:close()
        return true
    end
    return false
end

function isdir(name)
    return (exists(name) and not isFile(name))
end

function dirname(str)
    if str:match(".-/.-") then
        local name = string.gsub(str, "(.*/)(.*)", "%1")
        return name
    else
        return ''
    end
end

function basename(str)
    local name = string.gsub(str, "(.*/)(.*)", "%2")
    return name
end

function filesize(path)
    file = io.open(path, "r")
    local size = file:seek("end")    -- get file size
    io.close(file)
    return size
end

function pathjoin(dir, base)
    if string.sub(dir, -1) ~= "/" then
        dir = dir .. "/"
    end
    return dir .. base
end

function download(url)
    local video_host = string.match(url, ".*://([^/]+)/")
    local video_uri = string.match(url, ".*://[^/]+/(.*)")
    if string.find(video_host, '.com.cn') then
        video_host = string.sub(video_host, 1, -4)
    end
    local domain = string.match(video_host, "(.[^.]+.[^.]+)$") or video_host
    local k = string.match(domain, "([^.]+)")

    local m = dofile(k .. ".lua")
    local o = m:new()
    o:seturi(video_uri)
    o:start()
end

function download_urls(urls)
    for i,url in ipairs(urls) do
        if string.find(url, 'https://') ~= nil then
            url = string.sub(url, 9)
        end
        if not string.find(url, 'http://') ~= nil then
            url = 'http://' .. url
        end
        download(url)
    end
end

function main(mod)
    local urls = parse_args()
    download_urls(urls)
end

main(arg[1])

