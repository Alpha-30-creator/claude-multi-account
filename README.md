# claude-multi-account

Run two Claude Desktop apps at once (e.g. personal + work), each signed in to its own account.

Claude Desktop is an Electron app; launching it with `--user-data-dir=<folder>` gives that
instance its own login, chats and settings. Your normal Claude stays untouched.

## Mac

```bash
bash mac/make-claude-profile.sh Personal --default   # Claude's normal data folder
bash mac/make-claude-profile.sh Work                 # separate folder Claude-Work
```

Creates `~/Applications/Claude Personal.app` and `Claude Work.app` (findable in Spotlight).
**Always open Claude through these two, never the plain "Claude" icon**: both profiles are
the same app to macOS, so the plain icon just jumps to whichever one is already open.

- Personal = `~/Library/Application Support/Claude` (the original data, untouched).
- Work = `~/Library/Application Support/Claude-Work`.
- Both launch the real `/Applications/Claude.app`, so one update covers both.
  After an update, quit both and reopen so they run the same version.
- Re-opening a launcher focuses its existing window instead of starting a duplicate
  (allow the one-time "System Events" prompt).
- Code-tab chats are stored locally per profile *and* per account, so work Code chats live
  in Claude Work and personal ones in Claude Personal. Regular chats sync with the account.

Tested on Claude 2.19675.0.

## Windows (untested)

```powershell
powershell -ExecutionPolicy Bypass -File windows\ClaudeProfile.ps1 -Install -Name Work
```

Adds "Claude Work" shortcuts to the Desktop and Start menu. Data goes in `%APPDATA%\Claude-Work`.
For Microsoft Store (MSIX) installs it keeps a private copy of Claude in
`%LOCALAPPDATA%\ClaudeProfiles\app` and refreshes it after updates.

## First sign-in (once per profile)

Quit your other Claude completely, open "Claude Work", sign in, then reopen your normal Claude.
Browser sign-in (Google/SSO) uses `claude://` links, which can land in the wrong window
if both are open. On Windows, prefer email + code; if browser sign-in still lands in the
wrong window, launch once with `-SignIn`.

## Notes

- Both instances show the same Dock/taskbar icon.
- A relocated profile disables Claude's "local pairing" feature; nothing else changes.
- Never run two instances on the same profile folder at once.

## License

MIT, see [LICENSE](LICENSE). Do whatever you like with it.
