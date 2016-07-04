
require "extractor"
require "base64"

local url = require("socket.url")
local json = require("json")
local bit = require "bit"

local youku = extractor:new()

youku.stream_types = {
    {['id'] = 'mp4hd3', ['alias-of'] = 'hd3'},
    {['id'] = 'hd3'   , ['container']= 'flv', ['video_profile']= '1080P'},
    {['id'] = 'mp4hd2', ['alias-of'] = 'hd2'},
    {['id'] = 'hd2'   , ['container']= 'flv', ['video_profile']= '超清'},
    {['id'] = 'mp4hd' , ['alias-of'] = 'mp4'},
    {['id'] = 'mp4'   , ['container']= 'mp4', ['video_profile']= '高清'},
    {['id'] = 'flvhd' , ['container']= 'flv', ['video_profile']= '标清'},
    {['id'] = 'flv'   , ['container']= 'flv', ['video_profile']= '标清'},
    {['id'] = '3gphd' , ['container']= '3gp', ['video_profile']= '标清(3GP)'},
}
youku.headers = {
    ['Referer'] = 'http://static.youku.com/',
    ['Cookie']  = '__ysuid=1467375092.9994347',
}
youku.streams = {}
youku.streams_fallback = {}

local f_code_1 = 'becaf9be'
local f_code_2 = 'bf7e5f01'

function hex_dump(buf)
    for i=1,#buf do
        if(buf:byte(i) > 126 or buf:byte(i) < 32) then
            io.write(string.format('\\x%02x', buf:byte(i)))
        else
            io.write(string.char(buf:byte(i)))
        end
    end
    io.write('\n')
    --for i=1,math.ceil(#buf/16) * 16 do
    --    if (i-1) % 16 == 0 then io.write(string.format('%08X  ', i-1)) end
    --    io.write( i > #buf and '   ' or string.format('%02X ', buf:byte(i)) )
    --    if i %  8 == 0 then io.write(' ') end
    --    if i % 16 == 0 then io.write( buf:sub(i-16+1, i):gsub('%c','.'), '\n' ) end
    --end
end

function trans_e(a, c)
    local f = 0
    local result = ''
    local b = {}
    for i=0,255 do 
        b[i] = i
    end
    for i=0,255 do
        f = (f + b[i] + a:byte((i % a:len() + 1))) % 256
        b[i], b[f] = b[f], b[i]
    end
    local c_len = c:len()
    f = 0
    local h = 0
    for i=0,c_len-1 do
        h = (h + 1) % 256
        f = (f + b[h]) % 256
        b[h], b[f] = b[f], b[h]
        result = result .. string.char(bit.bxor(c:byte(i + 1), b[(b[h] + b[f]) % 256]))
    end

    return result
end

function utf8_to_latin1(s)
    return (s:gsub("([\192-\255])([\128-\191]*)", function(head, tail)
        if head == "\194" and #tail == 1 then
            return tail
        elseif head == "\195" and #tail == 1 then
            return string.char(tail:byte()+64)
        else return "?"
        end
    end))
end

--function utf8_to_latin1(s)
--    local r = ''
--    for _, c in utf8.codes(s) do
--        r = r .. string.char(c)
--    end
--    return r
--end

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

function generate_ep(fileid, sid, token)
    local e = trans_e(f_code_2, sid .. '_' .. fileid .. '_' .. token)
    e = base64_enc(e)
    e = quoted(e, '~()*!.\'')

    return e
end

function youku.get_vid_from_url(uri)
    return string.match(uri, "v_show/id_([a-zA-Z0-9=]+)") or 
           string.match(uri, "player\.php/sid/([a-zA-Z0-9=]+)/v\.swf") or 
           string.match(uri, "loader\.swf\?VideoIDS=([a-zA-Z0-9=]+)") or 
           string.match(uri, "embed/([a-zA-Z0-9=]+)")
end

function youku.prepare(uri)
    local vid = youku.get_vid_from_url(uri)
    local api1_url = 'http://play.youku.com/play/get.json?vid=' .. vid .. '&ct=10'
    local api2_url = 'http://play.youku.com/play/get.json?vid=' .. vid .. '&ct=12'
    if vid == nil then
        print('[Failed] Video not found.')
        return false
    end

    print_r(youku.headers)
    local b1,c1,_,_ = get_content(api1_url, youku.headers)
    local b2,c2,_,_ = get_content(api2_url, youku.headers)
    if c1 ~= 200 or c2 ~= 200 then
        print('[Failed] Video not found.')
        return false
    end

    local j1 = json:decode(b1)
    local j2 = json:decode(b2)
    if j1 == nil or j2 == nil or j1['data'] == nil or j2['data'] == nil then
        print('[Failed] Api data error.')
        return false
    end
    j1 = j1['data']
    j2 = j2['data']

    youku.title = j1['video']['title']
    youku.ep = j2['security']['encrypt_string']
    youku.ip = j2['security']['ip']
    --print(youku.title, youku.ep, youku.ip)

    stream_type = {}
    for _,s in pairs(youku.stream_types) do
        stream_type[s['id']] = s
    end
    audio_lang = j1['stream'][1]['audio_lang']
    for _, s in pairs(j1['stream']) do
        local s_id = s['stream_type']
        if stream_type[s_id] and s['audio_lang'] == audio_lang then
            if stream_type[s_id]['alias-of'] then
                s_id = stream_type[s_id]['alias-of']
            end
            if youku.streams[s_id] == nil then
                youku.streams[s_id] = {
                    ['container'] = stream_type[s_id]['container'],
                    ['video_profile'] = stream_type[s_id]['video_profile'],
                    ['size'] = s['size'],
                    ['pieces'] = {
                        {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']},
                    }
                }
            else
                youku.streams[s_id]['size'] = youku.streams[s_id]['size'] + s['size']
                youku.streams[s_id]['pieces'].insert({['fileid'] = s['stream_fileid'], ['segs'] = s['segs']}) 
            end
        end
    end

    for _, s in pairs(j2['stream']) do
        local s_id = s['stream_type']
        if stream_type[s_id] and s['audio_lang'] == audio_lang then
            if stream_type[s_id]['alias-of'] then
                s_id = stream_type[s_id]['alias-of']
            end
            if youku.streams_fallback[s_id] == nil then
                youku.streams_fallback[s_id] = {
                    ['container'] = stream_type[s_id]['container'],
                    ['video_profile'] = stream_type[s_id]['video_profile'],
                    ['size'] = s['size'],
                    ['pieces'] = {
                        {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']},
                    }
                }
            else
                youku.streams_fallback[s_id]['size'] = youku.streams_fallback[s_id]['size'] + s['size']
                youku.streams_fallback[s_id]['pieces'].insert({['fileid'] = s['stream_fileid'], ['segs'] = s['segs']}) 
            end
        end
    end
end

string.split = function(s, sep)
    local rt= {}
    s:gsub('[^'..sep..']+', function(w) table.insert(rt, w) end )
    return rt
end

function build_params(params)
    local r = ''
    for k,v in pairs(params) do
        r = r .. k .. '=' .. url.escape(v) .. '&'
    end
    return r:sub(1,-2)
end

function youku.extract()
    youku.streams_sorted = {}
    local i = 1
    for _,s in pairs(youku.stream_types) do
        if youku.streams[s['id']] then
            youku.streams_sorted[i] = s
            i = i + 1
        end
    end
    i = 1
    --youku.ep = "NwXWSQ4bI7LS2PXI8uJxB4igvBY71w3OWxY="
    e_code = trans_e(f_code_1, base64_dec(youku.ep))
    local r = e_code:split('_')
    sid, token = r[1], r[2]
    ksegs = {}
    while i <= table.getn(youku.streams_sorted) do
        local stream_id = youku.streams_sorted[i]['id']
        pieces = youku.streams[stream_id]['pieces']
        local b_flag = false
        for _,piece in pairs(pieces) do
            segs = piece['segs']
            for no = 0,#segs - 1 do
                k = segs[no + 1]['key']
                if k == -1 then break end -- we hit the paywall; stop here
                --k="eccd4e097c21bf082412a88c"
                --youku.ip=3659445426
                --no = 0 
                --fileid = "0300800F00576A8244B10D32F5AAF201A72B77-8878-6BE2-06CB-B2E22F95F0E8"
                --print_r(segs[no+1])
                --print(youku.ep,k,no,youku.ip)
                local fileid = segs[no + 1]['fileid']
                local ep = generate_ep(fileid, sid, token)
                --print(fileid, ep)
                q = build_params({
                    ['ctype'] = 12,
                    ['ev']    = 1,
                    ['K']     = k,
                    ['ep']    = ep,
                    ['oip']   = youku.ip,
                    ['token'] = token,
                    ['yxon']  = 1
                })
                u = string.format('http://k.youku.com/player/getFlvPath/sid/%s_00/st/%s/fileid/%s?%s',
                sid, youku.streams[stream_id]['container'], fileid, q)
                print(u)
                local b, c, h, s = get_content(u, nil)
                print(b,c)
                if c == 403 or c == 404 then
                    youku.streams = youku.streams_fallback
                    b_flag = true
                    break
                end
                for _,i in pairs(json:decode(b)) do table.insert(ksegs, i['server']) end
            end

            if b_flag then break end
        end

        if b_flag then i = i + 1 else break end
    end
end

return youku
