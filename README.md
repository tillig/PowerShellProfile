# PowerShell Profile

This repo hosts my PowerShell profile. It's yours to investigate and steal bits and pieces from, though I'm not going to accept issues or PRs on it. It's not intended for copy/paste magic instant reuse. There is no warranty, expressed or implied. It may or may not work on all versions of Windows. It may or may not work in PowerShell Core on any given day. It may be totally broken. It may not be super thoroughly documented. Don't worry about it, it's my profile, not yours.

**Setup instructions are mostly for me.** Yeah, selfish like that. It helps me remember what I need to do to hook this thing up to whatever machine I'm on. You can use them, too, if you want.

Do the OS-specific setup, then do the common setup. The OS-specific stuff gets things checked out and symlinked as needed. That has to happen before additional modules get installed or it doesn't work.

## Setup: Windows

- Check out to `C:\Users\tillig\Documents\WindowsPowerShell` so it becomes the profile for Windows PowerShell.
- Create symbolic link from that `WindowsPowerShell` folder to `C:\Users\tillig\Documents\PowerShell` so it also is the profile for Powershell Core.
- Create a DWORD key at `HKEY_CURRENT_USER\Console\VirtualTerminalLevel` with the value `1` to enable ANSI colors in terminal.

```cmd
REG ADD HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1
REG QUERY HKCU\Console /v VirtualTerminalLevel
```

## Setup: MacOS

The `sed` that ships with MacOS sucks. `sed` is used in the PowerShell profile to parse Azure subscription .ini info. Use Homebrew to install the GNU `sed`. Then you need to add the GNU `sed` to your path (e.g., update `/etc/paths`) _before_ the Apple `sed`. Homebrew will tell you how after install.

```powershell
brew install gnu-sed
```

MacOS only has PowerShell Core and profiles are all over the place for MacOS PowerShell Core. It expects:

- Profile at `~/.config/powershell/`
- Modules at `~/.local/share/powershell/Modules`

That makes for some extra symlinking. Let's say the profile is checked out at `/Users/tillig/dev/tillig/PowerShellProfile` (where `~` is `/Users/tillig`).

- Make the per-user modules folder be the Modules folder from the profile.
  `ln -s /Users/tillig/dev/tillig/PowerShellProfile/Modules /Users/tillig/.local/share/powershell/Modules`
- Make the user profile be the checked-out profile.
  `ln -s /Users/tillig/dev/tillig/PowerShellProfile /Users/tillig/.config/powershell`

## Setup: Common (Post Checkout)

There are some modules required for installation. I don't check them in; you can install them with the `Install-ProfileModules.ps1` script from the [PowerShell Gallery](https://www.powershellgallery.com). They are consumed from `ProfileCommon.ps1`.

If you've never installed modules from the gallery, you'll need to enable trust.

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

I use the [Fira Code Nerd Font which includes glyphs and logos](https://github.com/ryanoasis/nerd-fonts) so if you see things not rendering right, that's why. Plain Windows Powershell running under the old school Windows console requires the Mono version of the font because it doesn't work well with glyphs. Consider Windows Terminal and/or PowerShell Core - on Windows those both support multi-character width glyphs.
