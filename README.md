# MPV scripts

Scripts for MPV media player.

<!-- MarkdownTOC -->

- [timestamps-for-ffmpeg-cut](#timestamps-for-ffmpeg-cut)

<!-- /MarkdownTOC -->

## timestamps-for-ffmpeg-cut

Based on: https://gitlab.com/lvml/mpv-plugin-excerpt

How to use the script:

``` sh
$ mpv --script=/path/to/timestamps-for-ffmpeg-cut.lua -fs \
--script-opts=osc-layout=bottombar \
--script-opts=excerpt-write-to-file=1 \
/path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE.mkv
```

and then:

1. Mark the start of fragment with `SHIFT + i`
2. Mark the end of fragment with `SHIFT + o`
3. Press `x` to generate FFmpeg command. It will be copied to clipboard (*Windows only*) or written to file

The result might look like:

``` sh
ffmpeg -ss 00:00:06 -i /path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE.mkv -t 11.325 -crf 18 -c:a copy -map_chapters -1 /path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE-cut.mp4
```

If you don't want to re-encode video, then replace `-crf 18` with `-c:v copy`, but be aware that you'll likely get messed up keyframes and weird timings, especially on short cuts. And if you'd like your video to be most compatible for playing in web-browsers, then you might need to re-encode audio, so if you don't get sound while playing in a web-browser, replace `-c:a copy` with `-c:a flac`.
