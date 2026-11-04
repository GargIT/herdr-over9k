#!/bin/sh
# A project's sidebar icon (over9k): icon.sh <paste|choose|find|remove> <slug> [folder] [icons dir].
# Icons live in Herdr's home (the sidebar passes it): data/over9k/icons/<slug>--<seconds>.<ext>
# (the newest per slug is the one shown; a new name each time, so the sidebar
# never shows a cached old one). The slug names the project's folder (and
# computer); over9k makes it.
#   paste   the clipboard's image (PNG, SVG, JPEG, WebP), or an image file whose
#           path or file:// URI is on it (Linux: Wayland wl-paste, else X11 xclip;
#           macOS: osascript; Windows: PowerShell)
#   choose  a file picked in the desktop's dialog (Linux: kdialog, else zenity;
#           macOS: osascript; Windows: PowerShell)
#   find    the best icon in the project's folder: an app icon set, a favicon
#           or apple-touch icon, a logo; exit 3 when there's none
#   remove  every icon of that slug
# ICO and WebP are turned into PNG (ImageMagick) when it's there.
cmd=$1 slug=$2 folder=$3
dir=${4:-"${HERDR_APP_HOME:-$HOME/.config/herdr-app}/data/over9k/icons"}
os=$(uname -s 2>/dev/null)
# A path PowerShell understands (Git Bash on Windows).
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf %s "$1"; fi; }
mkdir -p "$dir"
case "$slug" in ""|*/*|*..*) echo "bad slug" >&2; exit 2 ;; esac

# Saves file $1 as the slug's icon (converting what images can't show).
keep() {
  src=$1 ext=$(printf %s "${src##*.}" | tr 'A-Z' 'a-z')
  case "$ext" in png|svg|jpg|jpeg) ;;
    ico|webp|gif|icns)
      if command -v magick >/dev/null 2>&1; then
        tmp="$dir/.$slug.png"; magick "$src[0]" -resize '256x256>' "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 4; }
        src=$tmp ext=png
      else exit 4; fi ;;
    *) exit 4 ;;
  esac
  out="$dir/$slug--$(date +%s).$ext" new="$dir/.$slug.new"
  cp "$src" "$new" && rm -f "$dir/$slug--"* && mv "$new" "$out" && rm -f "$dir/.$slug.png"
  printf '%s\n' "$out"
}

case "$cmd" in
  remove) rm -f "$dir/$slug--"* ;;
  paste)
    case "$os" in
      Darwin)
        # An image on the clipboard, as PNG; else a copied file's path.
        tmp="$dir/.paste.png"
        osascript -e "set f to open for access POSIX file \"$tmp\" with write permission" -e "set eof f to 0" \
          -e "write (the clipboard as «class PNGf») to f" -e "close access f" >/dev/null 2>&1 && [ -s "$tmp" ] && { keep "$tmp"; rm -f "$tmp"; exit 0; }
        rm -f "$tmp"
        p=$(osascript -e 'POSIX path of (the clipboard as «class furl»)' 2>/dev/null); [ -n "$p" ] || p=$(pbpaste 2>/dev/null | head -n 1)
        p=$(printf %s "$p" | sed 's#^file://##; s#%20# #g'); [ -f "$p" ] && { keep "$p"; exit 0; }
        exit 3 ;;
      MINGW*|MSYS*|CYGWIN*)
        tmp="$dir/.paste.png"
        powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$i = [Windows.Forms.Clipboard]::GetImage(); if (\$i) { \$i.Save('$(winpath "$tmp")', [Drawing.Imaging.ImageFormat]::Png) } else { \$f = [Windows.Forms.Clipboard]::GetFileDropList(); if (\$f.Count) { \$f[0] } }" > "$dir/.paste.out" 2>/dev/null
        [ -s "$tmp" ] && { keep "$tmp"; rm -f "$tmp" "$dir/.paste.out"; exit 0; }
        p=$(head -n 1 "$dir/.paste.out" | tr -d '\r'); rm -f "$tmp" "$dir/.paste.out"
        [ -n "$p" ] && command -v cygpath >/dev/null 2>&1 && p=$(cygpath -u "$p")
        [ -f "$p" ] && { keep "$p"; exit 0; }
        exit 3 ;;
    esac
    if command -v wl-paste >/dev/null 2>&1 && [ -n "$WAYLAND_DISPLAY" ]; then
      types=$(wl-paste --list-types 2>/dev/null); get() { wl-paste --type "$1" 2>/dev/null; }
    else
      types=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null); get() { xclip -selection clipboard -t "$1" -o 2>/dev/null; }
    fi
    for t in image/png image/svg+xml image/jpeg image/webp; do
      if printf '%s\n' "$types" | grep -qx "$t"; then
        ext=$(case $t in image/png) echo png ;; image/svg+xml) echo svg ;; image/jpeg) echo jpg ;; *) echo webp ;; esac)
        tmp="$dir/.paste.$ext"; get "$t" > "$tmp" && [ -s "$tmp" ] && { keep "$tmp"; rm -f "$tmp"; exit 0; }
      fi
    done
    # A copied file (a file manager's copy, or a path as text).
    p=$(get text/uri-list 2>/dev/null | head -n 1 | tr -d '\r'); [ -n "$p" ] || p=$(get text/plain 2>/dev/null | head -n 1)
    p=$(printf %s "$p" | sed 's#^file://##; s#%20# #g')
    [ -f "$p" ] && { keep "$p"; exit 0; }
    exit 3 ;;
  choose)
    start=${folder:-$HOME}; [ -d "$start" ] || start=$HOME
    if [ "$os" = Darwin ]; then
      f=$(osascript -e "POSIX path of (choose file with prompt \"Choose an icon\" default location POSIX file \"$start\")" 2>/dev/null)
    elif case "$os" in MINGW*|MSYS*|CYGWIN*) true ;; *) false ;; esac; then
      f=$(powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$d = New-Object Windows.Forms.OpenFileDialog; \$d.Title = 'Choose an icon'; \$d.InitialDirectory = '$(winpath "$start")'; \$d.Filter = 'Images|*.png;*.svg;*.jpg;*.jpeg;*.webp;*.ico'; if (\$d.ShowDialog() -eq 'OK') { \$d.FileName }" 2>/dev/null | tr -d '\r')
      [ -n "$f" ] && command -v cygpath >/dev/null 2>&1 && f=$(cygpath -u "$f")
    elif command -v kdialog >/dev/null 2>&1; then
      f=$(kdialog --title "Choose an icon" --getopenfilename "$start" "Images (*.png *.svg *.jpg *.jpeg *.webp *.ico *.icns)" 2>/dev/null)
    elif command -v zenity >/dev/null 2>&1; then
      f=$(zenity --file-selection --title="Choose an icon" --filename="$start/" --file-filter="Images | *.png *.svg *.jpg *.jpeg *.webp *.ico *.icns" 2>/dev/null)
    else exit 5; fi
    [ -n "$f" ] && [ -f "$f" ] || exit 3
    keep "$f" ;;
  find)
    [ -d "$folder" ] || exit 3
    cd "$folder" || exit 3
    # Files to look at: Git's (tracked, so no build output), else a shallow find.
    if git rev-parse --git-dir >/dev/null 2>&1; then list=$(git ls-files 2>/dev/null)
    else list=$(find . -maxdepth 4 \( -name node_modules -o -name .git -o -name target -o -name build -o -name dist \) -prune -o -type f -print 2>/dev/null | sed 's#^\./##'); fi
    # Each candidate gets a score (lower is better), then its size breaks ties (bigger first).
    best=$(printf '%s\n' "$list" | grep -i -E '\.(png|svg|jpe?g|ico|webp|icns)$' | grep -v -i -E '(^|/)(node_modules|vendor|third_party|test|tests|fixtures|screenshots?|docs?/screens)/' |
      awk '{ f = tolower($0); s = 0
        if (f ~ /appicon\.appiconset\/.*(1024|512)/) s = 1
        else if (f ~ /appicon\.appiconset\//) s = 2
        else if (f ~ /(^|\/)(src-tauri\/icons\/icon\.png|icon\.icns)$/) s = 3
        else if (f ~ /(^|\/)(apple-touch-icon[^\/]*\.png)$/) s = 4
        else if (f ~ /(^|\/)(app\/)?icon\.(svg|png)$/) s = 5
        else if (f ~ /(^|\/)favicon\.svg$/) s = 6
        else if (f ~ /(^|\/)(android-chrome-512|icon-512|icon-192|android-chrome-192)[^\/]*\.png$/) s = 7
        else if (f ~ /(^|\/)(logo|logomark|mark)[^\/]*\.(svg|png)$/) s = 8
        else if (f ~ /(^|\/)[^\/]*-(logo|mark)\.(svg|png)$/) s = 8
        else if (f ~ /mipmap-xxxhdpi\/ic_launcher\.png$/) s = 9
        else if (f ~ /(^|\/)favicon[^\/]*\.png$/) s = 10
        else if (f ~ /(^|\/)[^\/]*icon[^\/]*\.(svg|png)$/ && f !~ /icons?\//) s = 11
        else if (f ~ /(^|\/)favicon\.ico$/) s = 12
        if (s) print s "\t" $0 }' |
      while IFS="$(printf '\t')" read -r s f; do [ -f "$f" ] && printf '%s\t%s\t%s\n' "$s" "$(wc -c < "$f")" "$f"; done |
      sort -t "$(printf '\t')" -k1,1n -k2,2nr | head -n 1 | cut -f 3)
    [ -n "$best" ] || exit 3
    keep "$folder/$best" ;;
  *) echo "usage: icon.sh paste|choose|find|remove <slug> [folder]" >&2; exit 2 ;;
esac
