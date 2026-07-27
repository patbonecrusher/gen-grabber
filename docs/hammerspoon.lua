-- Gen Grabber — Hammerspoon hotkey to open the current Finder folder in the app.
--
-- Copy this binding into your ~/.hammerspoon/init.lua (or `dofile` this file from it), then
-- reload Hammerspoon. Pressing the hotkey opens the folder selected in Finder — or, if nothing
-- is selected, the folder the front Finder window is showing — in Gen Grabber.
--
-- It works whether or not the app is already running: `open -b <bundle id>` launches it if
-- needed, and the app loads the folder via its .onOpenURL handler (prompting first if there are
-- unsaved edits). Resolving by bundle id means it keeps working wherever GenGrabber.app lives.

-- Change the modifiers/key to whatever you like.
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "G", function()
  local script = [[
    tell application "Finder"
      if (count of (selection as list)) > 0 then
        set theItem to item 1 of (selection as list)
        if class of theItem is folder or class of theItem is disk then
          set p to (theItem as alias)
        else
          set p to (container of theItem as alias)   -- a file is selected → use its folder
        end if
      else
        set p to (target of front window as alias)    -- nothing selected → the window's folder
      end if
      return POSIX path of p
    end tell
  ]]

  local ok, path = hs.osascript.applescript(script)
  if ok and path then
    -- Shell-quote so folders with spaces or apostrophes are passed intact.
    local function shquote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    hs.execute("/usr/bin/open -b com.gengrabber.GenGrabber " .. shquote(path))
    hs.alert.show("Gen Grabber → " .. path:gsub("/$", ""):match("[^/]+$"))
  else
    hs.alert.show("No Finder folder to open")
  end
end)
