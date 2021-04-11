# MPV scripts

Scripts for MPV media player.

## timestamps-for-ffmpeg-cut

Based on: https://gitlab.com/lvml/mpv-plugin-excerpt

How to use the script:

``` sh
mpv --script=/path/to/excerpt.lua -fs \
--script-opts=osc-layout=bottombar \
--script-opts=excerpt-write-to-file=1 \
/path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE.mkv
```

and then:

1. Mark the start of fragment with `SHIFT + i`
2. Mark the end of fragment with `SHIFT + o`
3. Press `x` to generate FFmpeg command. It will be copied to clipboard or written to file. Copying to clipboard is implemented only for Windows

The result might look like:

``` sh
ffmpeg -ss 00:00:06 -i /path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE.mkv -t 11.325 /path/to/The.Empty.Man.2020.720p.WEBRip.X264-DEFLATE-cut.mp4
```
