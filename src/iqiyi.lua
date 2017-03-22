
require "extractor"
require "base64"
require "md5"

local json = require("json")
local bit = require("bit")

local iqiyi = extractor:new()

stream_types = {
    {['id'] = '4k',         ['container']= 'fl4', ['video_profile']= '4K'},
    {['id'] = 'fullhd',     ['container']= 'f4v', ['video_profile']= '全高清'},
    {['id'] = 'suprt-high', ['container']= 'f4v', ['video_profile']= '超高清'},
    {['id'] = 'super',      ['container']= 'f4v', ['video_profile']= '超清'},
    {['id'] = 'high',       ['container']= 'f4v', ['video_profile']= '高清'},
    {['id'] = 'standard',   ['container']= 'f4v', ['video_profile']= '标清'},
    {['id'] = 'topspeed',   ['container']= 'f4v', ['video_profile']= '最差'},
}

stream_to_bid = { 
    ['4k'] = 10, 
    ['fullhd'] = 5, 
    ['suprt-high'] = 4, 
    ['super'] = 3, 
    ['high'] = 2, 
    ['standard'] = 1, 
    ['topspeed'] = 96
}

stream_urls = {  
    ['4k'] = {} , 
    ['fullhd'] = {}, 
    ['suprt-high'] = {}, 
    ['super'] = {}, 
    ['high'] = {}, 
    ['standard'] = {}, 
    ['topspeed'] = {}
}

baseurl = ''
gen_uid = ''

function iqiyi:mix(tvid)
    local salt = '4a1caba4b4465345366f28da7c117d20'
    local tm = '' .. math.random(2000,4000)
    local sc = md5.sumhexa(salt .. tm .. tvid)
    return tm, sc, 'eknas'

end

function iqiyi:getVRSXORCode(arg1,arg2)
    local loc3 = arg2 % 3
    if loc3 == 1 then
        return bit.bxor(arg1, 121)
    end
    if loc3 == 2 then
        return bit.bxor(arg1, 72)
    end
    return bit.bxor(arg1, 103)
end


function iqiyi:getVrsEncodeCode(vlink)
    local loc6 = 0
    local loc2 = ''
    local loc3 = vlink.split("-")
    local loc4 = #loc3
    for i = loc4-1,-1,-1 do
        loc6 = self:getVRSXORCode(loc3:byte(loc4 - i - 1),i)
        loc2 = loc2 .. loc6
    end
    return loc2:reverse()
end

function iqiyi:getDispathKey(rid)
    local tp=")(*&^flash@#$%a"  
    local c = get_content("http://data.video.qiyi.com/t?tn=" .. math.random())
    local j = json:decode(c)
    local t = j['t']
    local t= '' .. math.floor(t/(10*60.0))
    local s = md5.sumhexa(t .. tp .. rid)
    return s
end

function iqiyi:getVMS(self)
    --tm ->the flash run time for md5 usage
    --um -> vip 1 normal 0
    --authkey -> for password protected video ,replace '' with your password
    --puid user.passportid may empty?
    local tvid, vid = self.vid
    local tm, sc, src = mix(tvid)
    local uid = self.gen_uid
    local vmsreq = 'http://cache.video.qiyi.com/vms?key=fvip&src=1702633101b340d8917a69cf8a4b8c7' .. "&tvId=" .. tvid .. "&vid=" .. vid .. "&vinfo=1&tm=" .. tm .. "&enc=" .. sc ..  "&qyid=" .. uid .. "&tn=" .. random() .. "&um=1" .. "&authkey=" .. md5.sumhexa(md5.sumhexa('') .. tm .. tvid)
    local c = get_content(vmsreq)
    local j = json:decode(c)
    return j
end

function iqiyi:download_playlist_by_url(url)
    local c = get_content(url)
    local videos = {}
    c:gsub('<a href="(http://www\.iqiyi\.com/v_[^"]+)"', function(w) table.insert(videos, w) end )

    for _,video in pairs(videos) do
        self:download_by_url(video)
    end
end

function iqiyi:prepare()
    math.randomseed(tostring(os.time()):reverse():sub(1, 6))

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
