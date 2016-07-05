
local http = require("socket.http")
require("ffmpeg")

extractor = {
    uri='',
    streams = {},
    streams_fallback = {},
    streams_sorted = {},
}

fake_headers = {
    ['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    ['Accept-Charset'] = 'UTF-8,*;q=0.5',
    ['Accept-Encoding'] = 'gzip,deflate,sdch',
    ['Accept-Language'] = 'en-US,en;q=0.8',
    ['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64; rv] =13.0) Gecko/20100101 Firefox/13.0'
}

function extractor:new(o)
    o = o or {} 
    setmetatable(o, self)
    self.__index = self
    return o
end

function extractor:seturi(uri)
    self.uri = uri
end

function extractor:prepare()
    print("super prepare" .. self.uri)
end

function extractor:extract()
    print("super extract")
end

function get_output_filename(urls, title, ext, output_dir, merge)
    merged_ext = ext
    if (#urls > 1) and merge then
        if ext == 'flv' or ext == 'f4v' then
            if has_ffmpeg_installed() then
                merged_ext = 'mp4'
            else
                merged_ext = 'flv'
            end
        elseif ext == 'mp4' then
            merged_ext = 'mp4'
        elseif ext == 'ts' then
            if has_ffmpeg_installed() then
                merged_ext = 'mkv'
            else
                merged_ext = 'ts'
            end
        end
    end
    return title .. '.' .. merged_ext
end

function url_save(url, filepath, file_size, refer, is_part, faker, headers)
    print(filepath)
    if exists(filepath) then
        if not force and file_size == filesize(filepath) then
            if not is_part then
                print(string.format('Skipping %s: file already exists', fs.basename(filepath)))
            end
            return
        else
            if not is_part then
                print(string.format('Overwriting %s', fs.basename(filepath)), '...')
            end
        end
    elseif not exists(dirname(filepath)) then
        os.execute("mkdir -p " .. filepath)
    end

    temp_filepath = filepath .. '.download' 
    print(temp_filepath)
    received = 0
    if not force then
        open_mode = 'ab'
        if isfile(temp_filepath) then
            received = received + filesize(temp_filepath)
        end
    else
        open_mode = 'wb'
    end

    if received < file_size then
        if faker then
            headers = fake_headers
        elseif headers then
            headers = headers
        else
            headers = {}
        end
        if received then
            headers['Range'] = 'bytes=' .. received .. '-'
        end
        if refer then
            headers['Referer'] = refer
        end

        b,c,h,s = get_content(url, headers)
        if h['Content-Length'] then
            range_length = 0 + h['Content-Length']
        elseif h['Content-Range'] then
            local r = h['Content-Range']:sub(7):split('/')
            range_start = r[1].split('-')
            range_start = range_start[1]
            end_length = r[2]
            range_length = end_length - range_start
        else
            print("Bad Response")
            return
        end

        if file_size ~= received + range_length then
            received = 0
            open_mode = 'wb'
        end

        fp = io.open(temp_filepath, open_mode)
        fp:write(b)
        io.close(fp)
        --while true do
        --    buffer = response.read(1024 * 256)
        --    if not buffer then
        --        if received == file_size then -- Download finished
        --            break
        --        else -- Unexpected termination. Retry request
        --            headers['Range'] = 'bytes=' + str(received) + '-'
        --            response = request.urlopen(request.Request(url, headers), None)
        --        end
        --        output.write(buffer)
        --        received = received + len(buffer)
        --    end
        --    io.close(fp)
        --end

        os.rename(temp_filepath, filepath)
    end
end

function extractor:download()
    print("super download")
    if self.streams_sorted[1]['id'] then
        stream_id = self.streams_sorted[1]['id']  
    else 
        stream_id = self.streams_sorted[1]['itag']
    end

    title = self.title
    urls = self.streams[stream_id]['src']
    sizes = self.streams[stream_id]['sizes']
    ext = self.streams[stream_id]['container']
    total_size = self.streams[stream_id]['size']
    output_dir = "/opt/users/xy/lua/you-get-lua/src"
    merge = true
    faker = false
    headers = nil
    refer = nil

    output_filename = get_output_filename(urls, title, ext, output_dir, merge)
    output_filepath = pathjoin(output_dir, output_filename)
    print(output_filepath)

    if #urls == 1 then
        url = urls[0]
        print(string.format('Downloading %s ...',  output_filename))
        url_save(url, output_filepath, total_size, refer, false, faker, headers)
    else
        parts = {}
        print(string.format('Downloading %s.%s ...', title, ext))
        for i, url in pairs(urls) do
            filename = string.format('%s[%02d].%s', title, i, ext)
            filepath = pathjoin(output_dir, filename)
            parts[i] = filepath
            print(string.format('Downloading %s [%s/%s]...', filename, i, #urls))
            url_save(url, filepath, sizes[i], refer, true, faker, headers)
        end
    end

    if ext =='flv' or ext == 'f4v' then
        --pcall
        if has_ffmpeg_installed() then
            --from .processor.ffmpeg import ffmpeg_concat_flv_to_mp4
            ffmpeg_concat_flv_to_mp4(parts, output_filepath)
        else
            concat_flv(parts, output_filepath)
        end
        print('Done.')
        --pcall
        --for _,part in pairs(parts) do
        --    os.remove(part)
        --end

    elseif ext == 'mp4' then
        --pcall
        --from .processor.ffmpeg import has_ffmpeg_installed
        if has_ffmpeg_installed() then
            --from .processor.ffmpeg import ffmpeg_concat_mp4_to_mp4
            ffmpeg_concat_mp4_to_mp4(parts, output_filepath)
        else
            --from .processor.join_mp4 import concat_mp4
            concat_mp4(parts, output_filepath)
        end
        print('Done.')
        --pcall
        for _,part in pair(parts) do
            os.remove(part)
        end

    elseif ext == "ts" then
        --pcall
        --from .processor.ffmpeg import has_ffmpeg_installed
        if has_ffmpeg_installed() then
            --from .processor.ffmpeg import ffmpeg_concat_ts_to_mkv
            ffmpeg_concat_ts_to_mkv(parts, output_filepath)
        else
            --from .processor.join_ts import concat_ts
            concat_ts(parts, output_filepath)
        end
        print('Done.')
        --pcall
        for _,part in pair(parts) do
            os.remove(part)
        end
    else
        print("Can't merge %s files" % ext)
    end
end

function extractor:start()
    self:prepare()
    self:extract()
    self:download()
end

return extractor
