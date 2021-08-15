
# Apple TV player

## Supported formats

- IPTV protocol (m3u, m3u8)

## State

- Development is in progress...

## Motivation

Most of Russian TV providers have only SmartTV applications to show their streaming channels, some of them (applications) have bad UX, some have ads even when service charges monthly payments. Things not so bad actually, all providers provide m3u playlists that can be used to stream its services as you want (I had used VLC for), but it is not always convenient, on MacOS it is okay, but on Apple TV there are only a few "ok" free players that can just play m3u formats without categorizing channels somehow. 

This app can play playlists in m3u format if able to parse, but main goal to support all providers out there in the best way it can.

## Supported providers

- Электронный город (https://2090000.ru)
- Сибирские сети (https://nsk.sibset.ru) - **TBD**

## Supported playlists

Over 8000 channels are available via https://github.com/iptv-restream/iptv-channels

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

- Russian `ru2090000` TV provider (needs to enabled it in the code before project build)

</br><img src="001.png"  alt=""/>
<img src="002.png"  alt=""/>
<img src="003.png"  alt=""/>