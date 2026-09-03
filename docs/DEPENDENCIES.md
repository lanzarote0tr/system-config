# Dependencies

The human layer. This is the list as I actually think about it — what I use,
and what each thing needs in order to be useful. `packages/manifest.psv` is the
machine-readable version of the parts that a package manager can install; this
file is the one to edit first when something new enters the setup.

A nested item is a **dependency**, not a category: Ollama needs the internet
only to pull models; CrystalFetch needs macOS *and* the internet; HWP needs a
경기도교육청 교육디지털원패스 login before it is of any use.

OS is only noted where the program is not cross-platform.

## Computers

- **MacBook Pro** — macOS — profile `macbook`
- **Home server (trillion-won-com)** — Ubuntu Linux — profile `server`
- **Galaxy Book** — profile `galaxybook`
  - Arch Linux
  - Microsoft Windows
  - GParted Live (USB)

## Dev platforms

- GitHub
  - GPG — commit signing
  - Internet
- Linear — Internet
- 위시켓 — Internet
- AWS — Internet

## Dev — open source

- Git
  - Neovim — `git difftool`
  - Internet — remote branches
- GPG
  - Internet — publishing the key
- npm
  - Internet — resolving packages

## Dev — IDE

- Neovim
- IntelliJ IDEA

## Dev — helpers

- DataGrip — Internet (remote databases)
- Apidog — Internet
- Postman — Internet
- `pbcopy` — macOS (on Linux: `xclip` / `wl-copy`)

## Dev — other

- Ollama

## Hacking — network

- WireGuard — Internet
- Wireshark

## Dev — VMs, virtualisation, CI/CD

- Docker — Internet (pulling images)
- UTM — macOS
  - CrystalFetch — macOS, Internet
- OrbStack — Internet (pulling images)
- Dokploy — Internet

## Internet

- Firefox
- Safari — macOS
- Google Chrome
- Arc — macOS
- NordVPN

## Files and documents

- Notion — Internet
- HWP — 경기도교육청 교육디지털원패스 ([goedu.kr](http://goedu.kr))
- Apple Keynote — macOS

## Learning platforms

- Wikipedia — Internet
- Dreamhack — Internet
- Anki
- [ebsi.co.kr](http://ebsi.co.kr) — Internet
- 유빈아카이브
  - Telegram — Internet

## AI

- ChatGPT — Internet
- Claude — Internet
- Gemini — Internet
- Ollama — Internet (downloading models)

## Social media and messengers

- YouTube
- Instagram
- Discord
- Discord Canary
- KakaoTalk

## Games and entertainment

- Apple Music — Internet
  - Music Presence (optional)
- Laftel — Internet
- Netflix — Internet
- Steam — Internet
- Berkeley County (Five-O)
  - Roblox — Internet
  - Google Drive — Internet

## Other

- OBS — Internet (streaming)
