import Foundation

let playlists: [URL] = [
    URL(string: "https://iptv-org.github.io/iptv/languages/rus.m3u")!,
    URL(string: "https://iptv-org.github.io/iptv/countries/ru.m3u")!,
    URL(string: "https://iptvmaster.ru/russia.m3u")!,
    URL(string: "https://iptvmaster.ru/hd.m3u")!
]

let data = playlists.reduce(Data()) { list, playlist in
    do {
        let data = try Data(contentsOf: playlist)
        return list + data + "\n".data(using: .utf8)!
    } catch {
        print(error)
    }
    return list
}

let temp = FileManager.default.temporaryDirectory
let path = temp.appendingPathComponent("playlist-ru").appendingPathExtension("m3u")
if FileManager.default.fileExists(atPath: path.path) {
    try? FileManager.default.removeItem(at: path)
}
do {
    try data.write(to: path)
} catch {
    print(error)
}
print(path.path)