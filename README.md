
<h1 align="center">Apple TV player</h1>
<p align="center">
  <img src="logo.png"  alt="" width="40%"/>
</p>

### Supported formats

- IPTV protocol (m3u, m3u8)

### State

- Development is in progress...

### Description

This app can play the playlists in m3u/m3u8 formats when able to parse.

### Supported playlists

Over 8000 channels are available https://github.com/iptv-org/iptv (not mine, please star the project)

### Localization

- EN

### Built-in TV providers

#### ottclub.tv

- Official site https://www.ottclub.tv
- To use you need API_KEY
- Little to modify a source code

### How to Build

1. Install dependencies

```bash
# Call once to configure bundler
bundle install
# Call every time when want to install dependencies
bundle exec pod install
```

2. Open `Apple-TV-Player.xcworkspace` using Xcode/AppCode

3. Set your Development Team and BundleID for files:

- Apple-TV-Player/Configuration/Debug.xcconfig
- Channels/Configuration/Debug-Channels.xcconfig

or just change them via Xcode `Signing & Capabilities` tab for `Apple-TV-Player` and `Channels` projects.

4. Select your Apple TV and hit Xcode build/run button.

### How to pair Apple TV to Xcode

- Make sure Mac and Apple TV have the same network ("AirPlay and HomeKit" > "Allow Access" is set to "Anyone in the Same Network")
- In Xcode open "Devices & Simulators" window
- On Apple TV open "Remote App And Device" > "Remote App And Device"
- If Xcode does not see your Apple TV box then try to use 2.4 Ghz wi-fi instead of 5 Ghz
- Click "pair" and enter code
- If "pair" reappear again then turn off the wi-fi on your Mac for 10 seconds and then turn it on back (https://developer.apple.com/forums/thread/108459)
- Maybe needed to delete the TV from ignored list https://stackoverflow.com/a/63195311/3614746

### How to install if Xcode fails to connect to Apple TV (but paired)

It is often the error found  `Xcode will continue when Apple TV is connected and unlocked`. That is freaking issue, it is better to not spend time to fix this, but just use another way to install the app to Apple TV by building IPA manually and installing it on TV directly.

- Build IPA with fastlane

```bash
# Call once to configure bundler
bundle install
# Call every time when want to create IPA file
bundle exec fastlane make_ipa
```

- Open Apple Configurator app
- Find there paired Apple TV (must be on the same network, better use 2.4 Ghz wi-fi)
- Open there `Apps` section
- Drag-n-Drop the generated IPA file

#### If Apple Configurator app does not see your paired Apple TV

- Unpack generated ipa (ipa it is just zip archive)
- Find there `****.app/` directory
- Open Xcode -> Window -> Devices and Simulators
- In Devices section find your Apple TV (better use 2.4 Ghz wi-fi)
- Click `Add installed app` plus button
- Select there `****.app/` directory

<img src="010.jpg" alt=""/>

### Update / Delete existed playlist (Home Screen only)

Long tap on TV Remote or press Play/Pause TV Remote button.

### Set / Delete playlist pin code (Home Screen only)

Select a playlist and Long tap on TV Remote or press Play/Pause TV Remote button.

----

- Some app screenshots:

</br><img src="001.jpg" alt=""/>
<img src="003.jpg" alt=""/>
<img src="002.jpg" alt=""/>
<img src="007.jpg" alt=""/>

## ottclub.tv

<img src="Channels/Resources/IpTvProvider/ottclub/ottclub.bundle/favicon.png"  width="82" height="82"  alt=""/>

```swift
// Open file `IpTvProvider.swift`.
// Add there ottclub provider with your API_KEY.
// That is change function:

public static func builtInProviders() -> [IpTvProviderKind] {
    return []
}

// to this:

public static func builtInProviders() -> [IpTvProviderKind] {
    return [.ottclub(key: "API_KEY")]
}
```

<img src="009.jpg"  alt=""/>
<img src="008.jpg"  alt=""/>

## Pluto TV

<img src="Channels/Resources/IpTvProvider/pluto/Pluto TV.bundle/favicon.png"  width="82" height="82"  alt=""/>

- USA only or use VPN with the USA ip address

```swift
// Open file `IpTvProvider.swift`.
// Add there plutoTv provider.
// That is change the function:

public static func builtInProviders() -> [IpTvProviderKind] {
    return []
}

// to this:

public static func builtInProviders() -> [IpTvProviderKind] {
    return [.plutoTv]
}
```

<img src="011.jpg" alt=""/>
<img src="012.jpg" alt=""/>
