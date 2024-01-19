
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
- RU

### Built-in TV providers

#### ottclub.tv

- Official site https://www.ottclub.tv
- To use you need API_KEY
- Little to modify a source code

### How to Build

1. Install dependencies

```bash
# Call once to configure bundler
bundle config set --local path 'vendor/bundle'
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
- Click "pair" and enter code
- If "pair" reappear again then turn off the wifi on your Mac for 10 seconds and then turn it on back (https://developer.apple.com/forums/thread/108459)
- Maybe needed to delete the TV from ignored list https://stackoverflow.com/a/63195311/3614746

### How to install if Xcode fails to connect to Apple TV (but paired)

It is often the error found  `Xcode will continue when Apple TV is connected and unlocked`. That is freaking issue, it is better to not spend time to fix this, but just use another way to install the app to Apple TV by building IPA manually and installing it on TV directly.

- Build IPA with fastlane

```bash
# Call once to configure bundler
bundle config set --local path 'vendor/bundle'
bundle install
# Call every time when want to create IPA file
bundle exec fastlane make_ipa
```

- Open Apple Configurator app
- Find there paired Apple TV (must be on the same network)
- Open there `Apps` section
- Drag-n-Drop the generated IPA file

### Update / Delete existed playlist (Home Screen only)

Long tap on TV Remote or press Play/Pause TV Remote button.

### Set / Delete playlist pin code (Home Screen only)

Select a playlist and Long tap on TV Remote or press Play/Pause TV Remote button.

----

- Some app screenshots:

</br><img src="001.png"  alt=""/>
<img src="003.png"  alt=""/>
<img src="002.png"  alt=""/>
<img src="006.png"  alt=""/>
<img src="007.png"  alt=""/>

## ottclub.tv

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

<img src="009.png"  alt=""/>
<img src="008.png"  alt=""/>