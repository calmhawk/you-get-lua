
require "extractor"
require "base64"

local json = require("json")
local bit = require("bit")

local youku = extractor:new()

stream_types = {
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
headers = {
    ['Referer'] = 'http://static.youku.com/',
    ['Cookie']  = '__ysuid=1467375092.9994347',
}

local f_code_1 = 'becaf9be'
local f_code_2 = 'bf7e5f01'

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

function generate_ep(fileid, sid, token)
    local e = trans_e(f_code_2, sid .. '_' .. fileid .. '_' .. token)
    e = base64_enc(e)
    e = quoted(e, '~()*!.\'')

    return e
end

function youku:get_vid_from_url(uri)
    return string.match(uri, "v_show/id_([a-zA-Z0-9=]+)") or 
           string.match(uri, "player\.php/sid/([a-zA-Z0-9=]+)/v\.swf") or 
           string.match(uri, "loader\.swf\?VideoIDS=([a-zA-Z0-9=]+)") or 
           string.match(uri, "embed/([a-zA-Z0-9=]+)")
end

function youku:prepare()
    local vid = self:get_vid_from_url(self.uri)
    local api1_url = 'http://play.youku.com/play/get.json?vid=' .. vid .. '&ct=10'
    local api2_url = 'http://play.youku.com/play/get.json?vid=' .. vid .. '&ct=12'
    if vid == nil then
        print('[Failed] Video not found.')
        return false
    end

    local b1,c1,_,_ = get_content(api1_url, headers)
    local b2,c2,_,_ = get_content(api2_url, headers)
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

    self.title = j1['video']['title']
    self.ep = j2['security']['encrypt_string']
    self.ip = j2['security']['ip']

    stream_type = {}
    for _,s in pairs(stream_types) do
        stream_type[s['id']] = s
    end
    audio_lang = j1['stream'][1]['audio_lang']
    for _, s in pairs(j1['stream']) do
        local s_id = s['stream_type']
        if stream_type[s_id] and s['audio_lang'] == audio_lang then
            if stream_type[s_id]['alias-of'] then
                s_id = stream_type[s_id]['alias-of']
            end
            if self.streams[s_id] == nil then
                self.streams[s_id] = {
                    ['container'] = stream_type[s_id]['container'],
                    ['video_profile'] = stream_type[s_id]['video_profile'],
                    ['size'] = s['size'],
                    ['pieces'] = {
                        {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']},
                    }
                }
            else
                self.streams[s_id]['size'] = self.streams[s_id]['size'] + s['size']
                table.insert(self.streams[s_id]['pieces'], {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']}) 
            end
        end
    end

    for _, s in pairs(j2['stream']) do
        local s_id = s['stream_type']
        if stream_type[s_id] and s['audio_lang'] == audio_lang then
            if stream_type[s_id]['alias-of'] then
                s_id = stream_type[s_id]['alias-of']
            end
            if self.streams_fallback[s_id] == nil then
                self.streams_fallback[s_id] = {
                    ['container'] = stream_type[s_id]['container'],
                    ['video_profile'] = stream_type[s_id]['video_profile'],
                    ['size'] = s['size'],
                    ['pieces'] = {
                        {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']},
                    }
                }
            else
                self.streams_fallback[s_id]['size'] = self.streams_fallback[s_id]['size'] + s['size']
                table.insert(self.streams_fallback[s_id]['pieces'], {['fileid'] = s['stream_fileid'], ['segs'] = s['segs']}) 
            end
        end
    end
end

function youku:extract()
    local i = 1
    for _,s in pairs(stream_types) do
        if self.streams[s['id']] then
            self.streams_sorted[i] = s
            i = i + 1
        end
    end
    i = 1
    e_code = trans_e(f_code_1, base64_dec(self.ep))
    local r = e_code:split('_')
    sid, token = r[1], r[2]
    ksegs = {}
    ksizes = {}
    local stream_id=''
    while i <= table.getn(self.streams_sorted) do
        stream_id = self.streams_sorted[i]['id']
        pieces = self.streams[stream_id]['pieces']
        local b_flag = false
        for _,piece in pairs(pieces) do
            segs = piece['segs']
            for no = 0,#segs - 1 do
                k = segs[no + 1]['key']
                if k == -1 then break end -- we hit the paywall; stop here
                local fileid = segs[no + 1]['fileid']
                local ep = generate_ep(fileid, sid, token)
                q = build_params({
                    ['ctype'] = 12,
                    ['ev']    = 1,
                    ['K']     = k,
                    ['ep']    = ep,
                    ['oip']   = self.ip,
                    ['token'] = token,
                    ['yxon']  = 1
                })
                u = string.format('http://k.youku.com/player/getFlvPath/sid/%s_00/st/%s/fileid/%s?%s',
                sid, self.streams[stream_id]['container'], fileid, q)
                local b, c, h, s = get_content(u, nil)
                if c == 403 or c == 404 then
                    self.streams = self.streams_fallback
                    b_flag = true
                    break
                end
                for _,i in pairs(json:decode(b)) do 
                    table.insert(ksegs, i['server'])  
                    table.insert(ksizes, 0 + segs[no + 1]['size'])
                end
            end

            if b_flag then break end
        end

        if b_flag then i = i + 1 else break end
    end

    self.streams[stream_id]['src'] = ksegs
    self.streams[stream_id]['sizes'] = ksizes
end

return youku
