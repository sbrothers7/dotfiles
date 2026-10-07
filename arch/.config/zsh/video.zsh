# ~/.config/zsh/video.zsh
# Add to ~/.zshrc:   source ~/.config/zsh/video.zsh
#
#   vcompress <file> [crf=28] [preset=medium]   smaller H.264 mp4 (lower crf = better/bigger)
#   vfit      <file> [MB=10]                    two-pass encode to land under a size (Discord etc.)
#   vconvert  <file> <ext> [gif fps] [gif width] remux/convert: mp4 mkv mov webm gif mp3 m4a opus wav flac
#   vtrim     <file> <start> [end] [out] [-a]   cut a clip; -a = frame-accurate re-encode
#   vresize   <file> <1080p|720p|...|WxH> [out] scale video; presets keep aspect ratio
#   ytdl      [-a] <url> [max height|best]      download video (default ≤1080p mp4), -a = mp3
#
# Times accept 90, 1:30, 00:01:30.5
# Old names still work: trimvid = vtrim, rsvid = vresize

_vt_report() {
  print "$(du -h -- "$1" | cut -f1) → $(du -h -- "$2" | cut -f1)   $2"
}

_vt_dur() {
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1"
}

vcompress() {
  [[ -f $1 ]] || { print -u2 "usage: vcompress <file> [crf 18-35, default 28] [preset]"; return 1 }
  local in=$1 crf=${2:-28} preset=${3:-medium}
  local out="${in:r}_c${crf}.mp4"
  ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a:0?' \
    -c:v libx264 -crf "$crf" -preset "$preset" -pix_fmt yuv420p \
    -c:a aac -b:a 128k -movflags +faststart "$out" && _vt_report "$in" "$out"
}

vfit() {
  [[ -f $1 ]] || { print -u2 "usage: vfit <file> [target MB, default 10]"; return 1 }
  local in=$1 mb=${2:-10} ab=96
  local dur=$(_vt_dur "$in")
  [[ -n $dur ]] || { print -u2 "couldn't read duration"; return 1 }
  local -i vb
  (( vb = mb * 8000 * 0.96 / dur - ab ))   # kbit/s budget, 4% headroom for container overhead
  (( vb > 50 )) || { print -u2 "${mb}MB is too small for ${dur}s (${vb} kbps video)"; return 1 }
  local out="${in:r}_${mb}MB.mp4" log=$(mktemp -u /tmp/vfit.XXXXXX)
  print "video bitrate: ${vb}k"
  ffmpeg -hide_banner -y -i "$in" -map 0:v:0 -c:v libx264 -b:v ${vb}k -preset medium \
      -pix_fmt yuv420p -pass 1 -passlogfile "$log" -an -f null /dev/null &&
    ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a:0?' -c:v libx264 -b:v ${vb}k -preset medium \
      -pix_fmt yuv420p -pass 2 -passlogfile "$log" -c:a aac -b:a ${ab}k -movflags +faststart "$out"
  local rc=$?
  rm -f "$log"*
  (( rc == 0 )) && _vt_report "$in" "$out"
  return $rc
}

vconvert() {
  [[ -f $1 && -n $2 ]] || { print -u2 "usage: vconvert <file> <mp4|mkv|mov|webm|gif|mp3|m4a|opus|wav|flac> [gif fps] [gif width]"; return 1 }
  local in=$1 ext=${2#.}
  local out="${in:r}.${ext}"
  [[ $out == $in ]] && out="${in:r}_conv.${ext}"
  [[ -e $out ]] && { print -u2 "$out already exists"; return 1 }

  case $ext in
    gif)
      local fps=${3:-15} w=${4:-480}
      ffmpeg -hide_banner -i "$in" \
        -vf "fps=$fps,scale=$w:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
        -loop 0 "$out" ;;
    mp3)  ffmpeg -hide_banner -i "$in" -vn -c:a libmp3lame -q:a 2 "$out" ;;
    m4a)  ffmpeg -hide_banner -i "$in" -vn -c:a aac -b:a 192k "$out" ;;
    opus) ffmpeg -hide_banner -i "$in" -vn -c:a libopus -b:a 128k "$out" ;;
    wav|flac) ffmpeg -hide_banner -i "$in" -vn "$out" ;;
    webm)
      ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a:0?' \
        -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 -c:a libopus -b:a 128k "$out" ;;
    *)
      # try a lossless remux first; re-encode only if the codecs don't fit the container
      if ! ffmpeg -hide_banner -loglevel error -i "$in" -map 0:v -map '0:a?' -c copy "$out"; then
        rm -f "$out"
        print "can't remux into .$ext, re-encoding…"
        ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a:0?' \
          -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p \
          -c:a aac -b:a 192k -movflags +faststart "$out"
      fi ;;
  esac && _vt_report "$in" "$out"
}

vtrim() {
  local accurate=0 a
  local -a pos=()
  for a in "$@"; do
    [[ $a == -a ]] && accurate=1 || pos+=("$a")
  done
  if [[ ! -f ${pos[1]} || -z ${pos[2]} ]]; then
    print -u2 "usage: vtrim <file> <start> [end] [output] [-a]"
    print -u2 "  e.g. vtrim clip.mp4 0:51 1:11            → clip_0.51-1.11.mp4"
    print -u2 "       vtrim clip.mp4 0:51 1:11 out.mp4 -a → frame-accurate, named out.mp4"
    return 1
  fi

  local in=${pos[1]} ss=${pos[2]} to= out=
  # 3rd arg is the end time if it looks like a time, otherwise it's the output name
  if [[ ${pos[3]} =~ '^[0-9:.]+$' ]]; then
    to=${pos[3]}; out=${pos[4]}
  else
    out=${pos[3]}
  fi
  if [[ -z $out ]]; then
    local tag="${ss}-${to:-end}"
    out="${in:r}_${tag//:/.}.${in:e}"
  fi

  local -a range=(-ss "$ss")
  [[ -n $to ]] && range+=(-to "$to")

  if (( accurate )); then
    ffmpeg -hide_banner "${range[@]}" -i "$in" -map 0:v:0 -map '0:a?' \
      -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k "$out"
  else
    # stream copy: instant and lossless, but snaps the start to the nearest keyframe
    ffmpeg -hide_banner "${range[@]}" -i "$in" -map 0:v -map '0:a?' \
      -c copy -avoid_negative_ts make_zero "$out"
  fi
}

vresize() {
  if [[ ! -f $1 || -z $2 ]]; then
    print -u2 "usage: vresize <file> <dimensions> [output]"
    print -u2 "  presets: 2160p 1440p 1080p 720p 480p 360p (keep aspect ratio)"
    print -u2 "  or WxH:  1280x720 (exact), 1280x-2 / -2x720 (one side, keep aspect)"
    return 1
  fi
  local in=$1 dims=$2 scale
  local out=${3:-"${in:r}_${dims}.${in:e}"}

  case $dims in
    2160p|1440p|1080p|720p|480p|360p) scale="-2:${dims%p}" ;;   # -2 = matching even width
    *x*)                              [[ $dims =~ '^-?[0-9]+x-?[0-9]+$' ]] || { print -u2 "bad size '$dims'"; return 1 }; scale="${dims/x/:}" ;;
    *) print -u2 "invalid dimensions '$dims' (use 1080p, 720p, … or WxH like 1280x720)"; return 1 ;;
  esac

  local -a vcodec=(-c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p)
  [[ ${out:e} == webm ]] && vcodec=(-c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1)

  # copy audio untouched; fall back to re-encoding it if the container won't take it
  ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a?' -vf "scale=${scale}:flags=lanczos" \
      "${vcodec[@]}" -c:a copy "$out" ||
    { rm -f "$out"; ffmpeg -hide_banner -i "$in" -map 0:v:0 -map '0:a?' \
      -vf "scale=${scale}:flags=lanczos" "${vcodec[@]}" "$out"; } &&
    _vt_report "$in" "$out"
}

# old names from .zshrc
alias trimvid=vtrim
alias rsvid=vresize

ytdl() {
  local audio=0
  [[ $1 == -a ]] && { audio=1; shift }
  [[ -n $1 ]] || { print -u2 "usage: ytdl [-a] <url> [max height (default 1080) | best]"; return 1 }
  local dir=${YTDL_DIR:-$HOME/Videos/yt}
  local -a common=(--embed-metadata --no-playlist -o "$dir/%(title).150B [%(id)s].%(ext)s")

  if (( audio )); then
    yt-dlp "${common[@]}" -x --audio-format mp3 --audio-quality 0 --embed-thumbnail "$1"
  else
    local h=${2:-1080}
    local -a sort=()
    # prefer H.264/AAC up to the cap so the file plays everywhere (Discord, phones, editors)
    [[ $h != best ]] && sort=(-S "res:$h,vcodec:h264,acodec:m4a")
    yt-dlp "${common[@]}" "${sort[@]}" --merge-output-format mp4 "$1"
  fi
}
