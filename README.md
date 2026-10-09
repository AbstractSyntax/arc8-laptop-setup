# Show laptop prep

One-shot setup for corporate AV presentation laptops. Paste one command, approve the admin prompt, and the laptop updates, goes quiet, and reboots.

## Before you run it

Edit the top of [setup.ps1](setup.ps1) and replace `OWNER` and `REPO` with your GitHub user and repository name. Push that change. The script relaunches itself from that URL when it asks for admin, so the copy on GitHub has to contain the real names.

Add the wallpaper before the first push:

`assets/wallpaper.jpg`

The installers are too large to commit. GitHub blocks files over 100 MB. Create a GitHub Release tagged `installers` and attach these files with these exact names:

| Asset | What to upload |
| --- | --- |
| `companion-win64.exe` | Bitfocus Companion Windows x64 installer |
| `ATEM-Switchers.zip` | Full Blackmagic ATEM Switchers zip, including the hidden `InstallerSupport.dat` |
| `Stagetimer-setup.exe` | Stagetimer Windows setup exe |
| `InputDirector.zip` | Input Director zip from the build you license |

Input Director's public download is personal non-commercial only. Upload the licensed build you already use for company machines.

Office has to already be installed as Microsoft 365 Click-to-Run. The script updates that install, which is how PowerPoint gets updated. It does not install Office.

## Run it

PowerShell:

```powershell
irm https://github.com/OWNER/REPO/raw/main/setup.ps1 | iex
```

Command Prompt:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/OWNER/REPO/raw/main/setup.ps1 | iex"
```

Replace `OWNER/REPO` with the same names you put in `setup.ps1`. Approve the admin prompt. The script reboots on its own after 20 seconds.

The log is written to `%TEMP%\ShowLaptopPrep\log.txt`.

## What it changes

- Updates Click-to-Run Office and waits for that update before rebooting
- Moves everything on the user desktop and the public desktop into a folder named `OLD`
- Sets `assets/wallpaper.jpg` as the desktop background, Fill
- Turns Windows Update off, including the Windows Update service, Store auto-downloads, and Delivery Optimization
- Turns notifications off: toasts, critical toasts, Action Center, lock screen, tips, suggestions, widgets, and the sound scheme
- Keeps the screen on and stops sleep, hibernate, the screensaver, and the console lock while the machine is awake
- Turns off Sticky Keys, Filter Keys, and Toggle Keys, including the Shift five times shortcut
- Closing the lid does nothing. High performance power plan. USB selective suspend off. Fast Startup off. Night light off
- Installs Companion, ATEM Software Control, Stagetimer, and Input Director
- Allows those programs through the firewall on Private networks
- Removes login startup programs so the laptop boots without opening anything. Windows services still start, including the Input Director service. Startup shortcuts are moved to `C:\ProgramData\ShowLaptopPrep\DisabledStartup`
- On Windows 11: classic right-click menu, Start button on the left, Copilot turned off
- Syncs the clock once

Companion, ATEM Software Control, and Stagetimer do not start at login. Open them when the show needs them. Input Director's master, slave, and screen layout are not configured. Pair those by hand after the reboot.

## What it does not do

It does not turn Windows Update back on, sign in automatically, or change Defender. These machines will not take security patches until someone turns updates back on in Settings.
