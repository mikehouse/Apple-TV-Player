import FactoryTesting
import Foundation
import Testing
@testable import Bro_Player

@Suite(.container)
struct PlaylistParserTests {

    @Test func case1() async throws {
        let playlist = """
        #EXTM3U url-tvg="http://tvguide.sibset.en/channels/program/jtv.zip" url-img="http://tvguide.sibset.en/channels/borpas_icons.zip" tvg-logo="http://tvguide.sibset.en/channels/main_logo.png" tvg-shift=+07

        #EXTINF: -1 id="9104" tvg-name="9104" tvg-logo="9104" group-title="Эфирные", Первый канал
        http://94.hlstv.nsk.211.en/239.211.0.1.m3u8
        #EXTINF: -1 id="1004" tvg-name="1004" tvg-logo="1004" group-title="Эфирные", Россия 1
        http://94.hlstv.nsk.211.en/239.211.0.2.m3u8    
        """
        
        let playlists = try await parse(string: playlist)

        #expect(playlists.count == 1)

        let parsedPlaylist = try #require(playlists.first)

        #expect(parsedPlaylist.tvgURL == "http://tvguide.sibset.en/channels/program/jtv.zip")
        #expect(parsedPlaylist.imageURL == "http://tvguide.sibset.en/channels/borpas_icons.zip")
        #expect(parsedPlaylist.xTvgURL == nil)
        #expect(parsedPlaylist.tvgLogo == "http://tvguide.sibset.en/channels/main_logo.png")
        #expect(parsedPlaylist.streams.count == 2)

        let firstStream = parsedPlaylist.streams[0]
        let secondStream = parsedPlaylist.streams[1]

        #expect(firstStream.title == "Первый канал")
        #expect(firstStream.url == "http://94.hlstv.nsk.211.en/239.211.0.1.m3u8")
        #expect(firstStream.tvgLogo == "9104")
        #expect(firstStream.tvgID == nil)
        #expect(firstStream.tvgName == "9104")
        #expect(firstStream.groupTitle == "Эфирные")

        #expect(secondStream.title == "Россия 1")
        #expect(secondStream.url == "http://94.hlstv.nsk.211.en/239.211.0.2.m3u8")
        #expect(secondStream.tvgLogo == "1004")
        #expect(secondStream.tvgID == nil)
        #expect(secondStream.tvgName == "1004")
        #expect(secondStream.groupTitle == "Эфирные")
    }
    
    @Test func case2() async throws {
        let playlist = """
        #EXTM3U x-tvg-url="https://iptv-org.github.io/epg/guides/af.xml,https://iptv-org.github.io/epg/guides/al.xml,https://iptv-org.github.io/epg/guides/by.xml,https://iptv-org.github.io/epg/guides/ca.xml,https://iptv-org.github.io/epg/guides/ee.xml,https://iptv-org.github.io/epg/guides/fr.xml,https://iptv-org.github.io/epg/guides/lu.xml,https://iptv-org.github.io/epg/guides/ru.xml,https://iptv-org.github.io/epg/guides/uk.xml,https://iptv-org.github.io/epg/guides/us.xml"
        #EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png" group-title="Music",1HD Music Television (404p) [Not 24/7]
        https://sc.id-tv.kz/1hd.m3u8
        #EXTINF:-1 tvg-id="2x2.ru" tvg-logo="https://i.imgur.com/fhQFLEl.png" group-title="Entertainment",2x2 (720p) [Not 24/7]
        https://bl.uma.media/live/317805/HLS/4614144_3,2883584_2,1153024_1/1613019214/3754dbee773afc02014172ca26d3bb79/playlist.m3u8
        #EXTINF:-1 tvg-id="Channel5.ru" tvg-logo="https://i.imgur.com/KPXMa3U.png" group-title="General",5 канал (480p) [Geo-blocked]
        https://okkotv-live.cdnvideo.ru/channel/5_OTT.m3u8
        #EXTINF:-1 tvg-id="AmediaHit.ru" tvg-logo="https://i.imgur.com/Jtfq9xA.png" group-title="Movies;Series",Amedia Hit (1080p) [Geo-blocked]
        https://okkotv-live.cdnvideo.ru/channel/Amedia_Hit_HD.m3u8
        #EXTINF:-1 tvg-id="AmediaPremium.ru" tvg-logo="https://i.imgur.com/L3c9gNk.png" group-title="Movies;Series" user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",Amedia Premium (480p)
        #EXTVLCOPT:http-user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148
        http://ott-cdn.ucom.am/s64/index.m3u8  
        """

        let playlists = try await parse(dataFrom: playlist)

        #expect(playlists.count == 1)

        let parsedPlaylist = try #require(playlists.first)

        #expect(parsedPlaylist.tvgURL == nil)
        #expect(parsedPlaylist.imageURL == nil)
        #expect(parsedPlaylist.xTvgURL == "https://iptv-org.github.io/epg/guides/af.xml,https://iptv-org.github.io/epg/guides/al.xml,https://iptv-org.github.io/epg/guides/by.xml,https://iptv-org.github.io/epg/guides/ca.xml,https://iptv-org.github.io/epg/guides/ee.xml,https://iptv-org.github.io/epg/guides/fr.xml,https://iptv-org.github.io/epg/guides/lu.xml,https://iptv-org.github.io/epg/guides/ru.xml,https://iptv-org.github.io/epg/guides/uk.xml,https://iptv-org.github.io/epg/guides/us.xml")
        #expect(parsedPlaylist.tvgLogo == nil)
        #expect(parsedPlaylist.streams.count == 5)

        let lastStream = try #require(parsedPlaylist.streams.last)

        #expect(lastStream.title == "Amedia Premium (480p)")
        #expect(lastStream.url == "http://ott-cdn.ucom.am/s64/index.m3u8")
        #expect(lastStream.tvgLogo == "https://i.imgur.com/L3c9gNk.png")
        #expect(lastStream.tvgID == "AmediaPremium.ru")
        #expect(lastStream.tvgName == nil)
        #expect(lastStream.groupTitle == "Movies;Series")
    }
    
    @Test func case3() async throws {
        let playlist = """
        #EXTM3U
        #EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png" group-title="Music",1HD Music Television (404p) [Not 24/7]
        https://sc.id-tv.kz/1hd.m3u8
        #EXTINF:-1 tvg-id="AmediaPremium.ru" tvg-logo="https://i.imgur.com/L3c9gNk.png" group-title="Movies;Series" user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",Amedia Premium (480p)
        #EXTVLCOPT:http-user-agent=Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148
        http://ott-cdn.ucom.am/s64/index.m3u8
        #EXTINF:-1 tvg-id="Yamal.ru" tvg-logo="https://i.imgur.com/O9PJHUy.png" group-title="Undefined",ЯМАЛ 1
        https://bl.rutube.ru/livestream/eff3ed0c2cdde88e8c5fdc515aee2c9f/index.m3u8?e=1653312522&s=rAfTRV43vtwOtE12zJ8UQQ&scheme=https

        #EXTM3U x-tvg-url="https://iptv-org.github.io/epg/guides/af.xml,https://iptv-org.github.io/epg/guides/al.xml,https://iptv-org.github.io/epg/guides/ao.xml,https://iptv-org.github.io/epg/guides/ar.xml,https://iptv-org.github.io/epg/guides/ba.xml,https://iptv-org.github.io/epg/guides/by.xml,https://iptv-org.github.io/epg/guides/cy.xml,https://iptv-org.github.io/epg/guides/cz.xml,https://iptv-org.github.io/epg/guides/pt.xml,https://iptv-org.github.io/epg/guides/ru.xml" tvg-logo="https://example.com/playlist-logo.png"
        #EXTINF:-1 tvg-id="1Plus1.ua" tvg-logo="https://i.imgur.com/eJXfMh0.png" group-title="Undefined",1+1 (1080p)
        http://free.fullspeed.tv/iptv-query?streaming-ip=https://www.youtube.com/channel/UCVEaAWKfv7fE1c-ZuBs7TKQ/live
        #EXTINF:-1 tvg-id="1Plus1Sport.ua" tvg-logo="https://i.imgur.com/VpBVorp.png" group-title="Sports",1+1 Спорт (720p) [Not 24/7]
        https://live-k2301-kbp.1plus1.video/sport/smil:sport.smil/playlist.m3u8
        #EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png" group-title="Music",1HD Music Television (404p) [Not 24/7]
        https://sc.id-tv.kz/1hd.m3u8
        """

        let playlists = try await parse(string: playlist)

        #expect(playlists.count == 2)

        let firstPlaylist = playlists[0]
        let secondPlaylist = playlists[1]

        #expect(firstPlaylist.xTvgURL == nil)
        #expect(firstPlaylist.tvgLogo == nil)
        #expect(secondPlaylist.xTvgURL == "https://iptv-org.github.io/epg/guides/af.xml,https://iptv-org.github.io/epg/guides/al.xml,https://iptv-org.github.io/epg/guides/ao.xml,https://iptv-org.github.io/epg/guides/ar.xml,https://iptv-org.github.io/epg/guides/ba.xml,https://iptv-org.github.io/epg/guides/by.xml,https://iptv-org.github.io/epg/guides/cy.xml,https://iptv-org.github.io/epg/guides/cz.xml,https://iptv-org.github.io/epg/guides/pt.xml,https://iptv-org.github.io/epg/guides/ru.xml")
        #expect(secondPlaylist.tvgLogo == "https://example.com/playlist-logo.png")
        #expect(firstPlaylist.streams.count == 3)
        #expect(secondPlaylist.streams.count == 3)

        let firstPlaylistLastStream = try #require(firstPlaylist.streams.last)
        let secondPlaylistFirstStream = secondPlaylist.streams[0]

        #expect(firstPlaylistLastStream.title == "ЯМАЛ 1")
        #expect(firstPlaylistLastStream.url == "https://bl.rutube.ru/livestream/eff3ed0c2cdde88e8c5fdc515aee2c9f/index.m3u8?e=1653312522&s=rAfTRV43vtwOtE12zJ8UQQ&scheme=https")
        #expect(firstPlaylistLastStream.tvgID == "Yamal.ru")
        #expect(firstPlaylistLastStream.groupTitle == "Undefined")

        #expect(secondPlaylistFirstStream.title == "1+1 (1080p)")
        #expect(secondPlaylistFirstStream.url == "http://free.fullspeed.tv/iptv-query?streaming-ip=https://www.youtube.com/channel/UCVEaAWKfv7fE1c-ZuBs7TKQ/live")
        #expect(secondPlaylistFirstStream.tvgID == "1Plus1.ua")
        #expect(secondPlaylistFirstStream.groupTitle == "Undefined")
    }
    
    @Test func case4() async throws {
        let playlist = """
        #EXTM3U
        #EXT-INETRA-CHANNEL-INF: channel-id=36942372 recordable=false
        #EXT-INETRA-STREAM-INF: aspect-ratio=16:9 has-timeshift=false access=allowed 
        #EXTINF:-1 cn-id=36942372 cn-records=0, Paramount Comedy HD
        http://tv.novotelecom.ru/channel/paramount_comedy_hd/592/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1

        #EXT-INETRA-CHANNEL-INF: channel-id=10338251 recordable=true
        #EXT-INETRA-STREAM-INF: has-timeshift=true access=allowed 
        #EXTINF:-1 cn-id=10338251 cn-records=1, РЕН-ТВ
        http://tv.novotelecom.ru/channel/rentv/219/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1    
        """

        let playlists = try await parse(string: playlist)

        #expect(playlists.count == 1)

        let parsedPlaylist = try #require(playlists.first)

        #expect(parsedPlaylist.tvgURL == nil)
        #expect(parsedPlaylist.imageURL == nil)
        #expect(parsedPlaylist.xTvgURL == nil)
        #expect(parsedPlaylist.tvgLogo == nil)
        #expect(parsedPlaylist.streams.count == 2)

        let firstStream = parsedPlaylist.streams[0]
        let secondStream = parsedPlaylist.streams[1]

        #expect(firstStream.title == "Paramount Comedy HD")
        #expect(firstStream.url == "http://tv.novotelecom.ru/channel/paramount_comedy_hd/592/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1")
        #expect(firstStream.tvgLogo == nil)
        #expect(firstStream.tvgID == nil)
        #expect(firstStream.tvgName == nil)
        #expect(firstStream.groupTitle == nil)

        #expect(secondStream.title == "РЕН-ТВ")
        #expect(secondStream.url == "http://tv.novotelecom.ru/channel/rentv/219/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1")
        #expect(secondStream.groupTitle == nil)
    }
    
    @Test func case5() async throws {
        let playlist = """
        #EXTM3U url-tvg="https://epg.ottservice.org/download/epg.xml.gz"
        #EXTINF:-1 group-title="Развлекательные" tvg-rec="7" timeshift="7",ТВ3 HD
        #EXTGRP:Развлекательные
        http://ott.watch/stream/API_KEY/136.m3u8
        #EXTINF:-1 group-title="Развлекательные" tvg-rec="7" timeshift="7",Пятница! HD
        #EXTGRP:Развлекательные
        http://ott.watch/stream/API_KEY/181.m3u8
        #EXTINF:-1 group-title="Развлекательные" tvg-rec="7" timeshift="7",Суббота! HD
        #EXTGRP:Развлекательные
        http://ott.watch/stream/API_KEY/269.m3u8
        #EXTINF:-1 group-title="Развлекательные" tvg-rec="7" timeshift="7",Ю
        #EXTGRP:Развлекательные
        http://ott.watch/stream/API_KEY/230.m3u8
        """

        let playlists = try await parse(string: playlist)

        #expect(playlists.count == 1)

        let parsedPlaylist = try #require(playlists.first)

        #expect(parsedPlaylist.tvgURL == "https://epg.ottservice.org/download/epg.xml.gz")
        #expect(parsedPlaylist.tvgLogo == nil)
        #expect(parsedPlaylist.streams.count == 4)

        let firstStream = parsedPlaylist.streams[0]
        let lastStream = try #require(parsedPlaylist.streams.last)

        #expect(firstStream.title == "ТВ3 HD")
        #expect(firstStream.url == "http://ott.watch/stream/API_KEY/136.m3u8")
        #expect(firstStream.tvgLogo == nil)
        #expect(firstStream.tvgID == nil)
        #expect(firstStream.tvgName == nil)
        #expect(firstStream.groupTitle == "Развлекательные")

        #expect(lastStream.title == "Ю")
        #expect(lastStream.url == "http://ott.watch/stream/API_KEY/230.m3u8")
        #expect(lastStream.groupTitle == "Развлекательные")
    }
    
    @Test func case6() async throws {
        let playlist = """
        #EXTM3U url-tvg="https://raw.github.com/matthuisman/i.mjh.nz/master/PlutoTV/us.xml.gz"
        #EXTINF:-1 tvg-id="62bdb1c5e25122000798ac79" tvg-name="South Park" tvg-logo="https://images.pluto.tv/channels/62bdb1c5e25122000798ac79/colorLogoPNG_1732662634386.png" group-title="Entertainment" tvg-chno="5", South Park
        https://stitcher.pluto.tv/stitch/hls/channel/62bdb1c5e25122000798ac79/master.m3u8?deviceType=web&servertSideAds=false&deviceMake=safari&deviceVersion=1&deviceId=matraka&appVersion=1&deviceDNT=0&deviceModel=web&sid=SID_ID

        #EXTINF:-1 tvg-id="673247127d5da5000817b4d6" tvg-name="Pluto TV Trending Now" tvg-logo="https://images.pluto.tv/channels/673247127d5da5000817b4d6/colorLogoPNG_1732662634386.png" group-title="Movies" tvg-chno="5", Pluto TV Trending Now
        https://stitcher.pluto.tv/stitch/hls/channel/673247127d5da5000817b4d6/master.m3u8?deviceType=web&servertSideAds=false&deviceMake=safari&deviceVersion=1&deviceId=matraka&appVersion=1&deviceDNT=0&deviceModel=web&sid=SID_ID
        """

        let playlists = try await parse(dataFrom: playlist)

        #expect(playlists.count == 1)

        let parsedPlaylist = try #require(playlists.first)

        #expect(parsedPlaylist.tvgURL == "https://raw.github.com/matthuisman/i.mjh.nz/master/PlutoTV/us.xml.gz")
        #expect(parsedPlaylist.imageURL == nil)
        #expect(parsedPlaylist.xTvgURL == nil)
        #expect(parsedPlaylist.tvgLogo == nil)
        #expect(parsedPlaylist.streams.count == 2)

        let firstStream = parsedPlaylist.streams[0]
        let secondStream = parsedPlaylist.streams[1]

        #expect(firstStream.title == "South Park")
        #expect(firstStream.tvgID == "62bdb1c5e25122000798ac79")
        #expect(firstStream.tvgName == "South Park")
        #expect(firstStream.tvgLogo == "https://images.pluto.tv/channels/62bdb1c5e25122000798ac79/colorLogoPNG_1732662634386.png")
        #expect(firstStream.groupTitle == "Entertainment")

        #expect(secondStream.title == "Pluto TV Trending Now")
        #expect(secondStream.tvgID == "673247127d5da5000817b4d6")
        #expect(secondStream.tvgName == "Pluto TV Trending Now")
        #expect(secondStream.tvgLogo == "https://images.pluto.tv/channels/673247127d5da5000817b4d6/colorLogoPNG_1732662634386.png")
        #expect(secondStream.groupTitle == "Movies")
    }
}

private extension PlaylistParserTests {
    func parse(string: String) async throws -> [PlaylistParser.Playlist] {
        try await PlaylistParser(string: string).parse()
    }

    func parse(dataFrom string: String) async throws -> [PlaylistParser.Playlist] {
        try await PlaylistParser(data: Data(string.utf8)).parse()
    }
}
