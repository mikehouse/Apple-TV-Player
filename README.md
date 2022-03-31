
# Apple TV player

## Supported formats

- IPTV protocol (m3u, m3u8)

## State

- Development is in progress...

## Description

This app can play the playlists in m3u/m3u8 formats when able to parse.

## Supported playlists

Over 8000 channels are available https://github.com/iptv-org/iptv

## Built-in providers

- Электронный город (https://2090000.ru)
- Сибирские сети (https://nsk.sibset.ru) - **TBD**

## Localization

- RU
- EN

## How to Build

1. Set your Development Team and BundleID for files:

- Apple-TV-Player/Configuration/Debug.xcconfig
- Channels/Configuration/Debug-Channels.xcconfig

or just change them via Xcode `Signing & Capabilities` tab for `Apple-TV-Player` and `Channels` projects.

2. If you from Russia/Siberia and have `2090000.ru` provider then enable it in `Channels/Sources/IpTvProviders/IpTvProvider.swift` at the function `builtInProviders()`.

3. Select your Apple TV and hit Xcode build/run button .

----

- Add playlist

</br><img src="004.png"  alt=""/>
<img src="005.png"  alt=""/>
<img src="006.png"  alt=""/>
<img src="007.png"  alt=""/></br></br>

----

- Russian `ru2090000` TV provider (needs to enabled it in the code before project build)

</br><img src="001.png"  alt=""/>
<img src="002.png"  alt=""/>
<img src="003.png"  alt=""/>