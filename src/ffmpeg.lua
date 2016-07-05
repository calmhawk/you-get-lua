
local os = require("os")

function get_usable_ffmpeg(cmd)
    local r = exec(cmd .. ' -version')
    local vers = r:split(' ')
    if vers then
        return vers[3]
    else
        return nil
    end
end

FFMPEG = "ffmpeg"
FFMPEG_VERSION = get_usable_ffmpeg('ffmpeg') 
LOGLEVEL = '-loglevel quiet'

function has_ffmpeg_installed()
    return FFMPEG_VERSION 
end

function generate_params(params)
    local s = ''
    for _,p in pairs(params) do
        s = s .. p .. ' '
    end
    print(s)
    return s
end

function ffmpeg_concat_av(files, output, ext)
    --print('Merging video parts... ', end="", flush=True)
    local p = {}
    table.insert(p, FFMPEG)
    table.insert(p, LOGLEVEL)
    for file in files do
        if os.path.isfile(file) then 
            table.insert(p, '-i')
            table.insert(p, file)
        end
    end
    table.insert(p, '-c:v')
    table.insert(p, 'copy')
    if ext == 'mp4' then
        table.insert(p, '-c:a')
        table.insert(p, 'aac')
    elseif ext == 'webm' then
        table.insert(p, '-c:a')
        table.insert(p, 'vorbis')
    end
    table.insert(p, '-strict')
    table.insert(p, 'experimental')
    table.insert(p, output)
    return exec(generate_params(p))
end

--[[
function ffmpeg_convert_ts_to_mkv(files, output='output.mkv'):
    for file in files:
        if os.path.isfile(file):
            params = [FFMPEG] + LOGLEVEL
            params.extend(['-y', '-i', file, output])
            subprocess.call(params)

    return

function ffmpeg_concat_mp4_to_mpg(files, output='output.mpg'):
    # Use concat demuxer on FFmpeg >= 1.1
    if FFMPEG == 'ffmpeg' and (FFMPEG_VERSION[0] >= 2 or (FFMPEG_VERSION[0] == 1 and FFMPEG_VERSION[1] >= 1)):
        concat_list = open(output + '.txt', 'w', encoding="utf-8")
        for file in files:
            if os.path.isfile(file):
                concat_list.write("file %s\n" % parameterize(file))
        concat_list.close()

        params = [FFMPEG] + LOGLEVEL
        params.extend(['-f', 'concat', '-safe', '-1', '-y', '-i'])
        params.append(output + '.txt')
        params += ['-c', 'copy', output]

        if subprocess.call(params) == 0:
            os.remove(output + '.txt')
            return True
        else:
            raise

    for file in files:
        if os.path.isfile(file):
            params = [FFMPEG] + LOGLEVEL + ['-y', '-i']
            params.extend([file, file + '.mpg'])
            subprocess.call(params)

    inputs = [open(file + '.mpg', 'rb') for file in files]
    with open(output + '.mpg', 'wb') as o:
        for input in inputs:
            o.write(input.read())

    params = [FFMPEG] + LOGLEVEL + ['-y', '-i']
    params.append(output + '.mpg')
    params += ['-vcodec', 'copy', '-acodec', 'copy']
    params.append(output)
    subprocess.call(params)

    if subprocess.call(params) == 0:
        for file in files:
            os.remove(file + '.mpg')
        os.remove(output + '.mpg')
        return True
    else:
        raise

function ffmpeg_concat_ts_to_mkv(files, output='output.mkv'):
    print('Merging video parts... ', end="", flush=True)
    params = [FFMPEG] + LOGLEVEL + ['-isync', '-y', '-i']
    params.append('concat:')
    for file in files:
        if os.path.isfile(file):
            params[-1] += file + '|'
    params += ['-f', 'matroska', '-c', 'copy', output]

    try:
        if subprocess.call(params) == 0:
            return True
        else:
            return False
    except:
        return False
        ]]--

function ffmpeg_concat_flv_to_mp4(files, output)
    print('Merging video parts... ')
    -- Use concat demuxer on FFmpeg >= 1.1
    local p = {}
    table.insert(p, FFMPEG)
    table.insert(p, LOGLEVEL)
    if (FFMPEG_VERSION >= "1.1") then
        concat_list = io.open(output .. '.txt', 'w')
        for _,file in pairs(files) do
            if isfile(file) then
                -- for escaping rules, see:
                -- https://www.ffmpeg.org/ffmpeg-utils.html#Quoting-and-escaping
                concat_list:write(string.format("file %s\n", file))
            end
        end
        io.close(concat_list)

        table.extend(p, {'-f', 'concat', '-safe', '-1', '-y', '-i'})
        table.insert(p, output .. '.txt')
        table.extend(p, {'-c', 'copy', output})

        exec(generate_params(p))
        --os.remove(output .. '.txt')
        return true
    else
        print("ffmpeg version not supported.")
    end
end

--[[
function ffmpeg_concat_mp4_to_mp4(files, output='output.mp4'):
    print('Merging video parts... ', end="", flush=True)
    # Use concat demuxer on FFmpeg >= 1.1
    if FFMPEG == 'ffmpeg' and (FFMPEG_VERSION[0] >= 2 or (FFMPEG_VERSION[0] == 1 and FFMPEG_VERSION[1] >= 1)):
        concat_list = open(output + '.txt', 'w', encoding="utf-8")
        for file in files:
            if os.path.isfile(file):
                concat_list.write("file %s\n" % parameterize(file))
        concat_list.close()

        params = [FFMPEG] + LOGLEVEL + ['-f', 'concat', '-safe', '-1', '-y', '-i']
        params.append(output + '.txt')
        params += ['-c', 'copy', output]

        subprocess.check_call(params)
        os.remove(output + '.txt')
        return True

    for file in files:
        if os.path.isfile(file):
            params = [FFMPEG] + LOGLEVEL + ['-y', '-i']
            params.append(file)
            params += ['-c', 'copy', '-f', 'mpegts', '-bsf:v', 'h264_mp4toannexb']
            params.append(file + '.ts')

            subprocess.call(params)

    params = [FFMPEG] + LOGLEVEL + ['-y', '-i']
    params.append('concat:')
    for file in files:
        f = file + '.ts'
        if os.path.isfile(f):
            params[-1] += f + '|'
    if FFMPEG == 'avconv':
        params += ['-c', 'copy', output]
    else:
        params += ['-c', 'copy', '-absf', 'aac_adtstoasc', output]

    subprocess.check_call(params)
    for file in files:
        os.remove(file + '.ts')
    return True
]]--
