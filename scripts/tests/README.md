
# App Store Snaphosts

### Supported languages

- ar
- de
- es
- es-419
- fr
- hi
- id
- it
- ja
- ko
- pt-BR
- ru
- th
- tr
- vi
- zh-Hans
- en

## Requirements

- xcbeautify
- jq
- Python 3+
- iOS 26.4 Runtime
- tvOS 26.4 Runtime

We need snapshots for:

1. iOS – iPhone 17 Pro Max (AppStore will scale down to other iPhones)
2. iPad – iPad Pro 13 inch M5 (AppStore will scale down to other iPads)
3. AppleTV – Apple TV 4K 3rd generation 4K (AppStore will scale down to other iPads)

## How to make snapshots

### Run server for Snapshots mock data

```bash
# default port 8000
# run from project root
./scripts/tests/server.py
```

### Run Simulator screenshot maker script

```bash
# run from project root
# you can run them in parallel
LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-iphone.sh
LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-ipad.sh
LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-appletv.sh

# Durations in parallel run:
# time LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-iphone.sh  56.93s user 39.23s system 9% cpu 16:34.19 total
# time LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-ipad.sh  57.16s user 41.08s system 10% cpu 16:15.46 total
# time LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-appletv.sh  50.89s user 40.26s system 11% cpu 13:02.74 total

# Sequential run:
# time LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-iphone.sh  61.58s user 32.91s system 11% cpu 13:15.55 total
# LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-ipad.sh  57.79s user 32.80s system 12% cpu 12:18.10 total
# LOCAL_PORT=8000 ./scripts/tests/make-app-store-snapshots-appletv.sh  55.01s user 26.98s system 12% cpu 10:51.35 total
# LOCAL_PORT=8000 ./make-app-store-snapshots-macos.sh  100.13s user 74.94s system 33% cpu 8:47.21 total
```

Script is gonna do:

1. Check simulator runtimes availability
2. Creates the necessary simulators
3. Run snapshot tests (based on UI Tests) for each simulator
4. Run snapshot tests for each supported language

### UI Tests Mock Database

To run snapshot tests, we need some data in the app. We generate a database once and use it to speed up the tests.
When snapshot tests run, it asks the local server for the path to the database, and then the app uses it to get data.
It is already generated. If you want to regenerate it, then run the script:

```bash
LOCAL_PORT=8000 ./scripts/tests/make-app-store-database-mock-data-iphone.sh
```

Mocked Database stored under `scripts/tests/playlists/database/${lang}/default.store`.
In the app a database resides in `$HOME/Library/Developer/CoreSimulator/Devices/${CURRENT_UDID}/data/Containers/Data/Application/${SANDBOX_UUID}/Library/Caches/default.store` by default, from where we copy it to local machine after test data generation is completed.


### Group snapshots by language and device