import FactoryTesting
import Foundation
import Testing
import os
@testable import Bro_Player

@Suite(.container)
struct ProgramGuideParserTests {

    @Test func parsesProgramGuideFromXMLFile() async throws {
        let xmlURL = try resourceURL(named: "program-guide.xml")
        let receiveSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        let foundSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        let guides = try await ProgramGuideParser(onProgress: { steps, step, _ in
            receiveSteps.withLock { $0 = steps }
            foundSteps.withLock({ $0.append(step) })
        }).parse(xmlURL: xmlURL)

        #expect(guides == expectedGuides)
        
        receiveSteps.withLock({
            #expect([.start, .parsing, .complete] == $0)
        })
        foundSteps.withLock({
            #expect([.start, .parsing, .complete] == $0)
        })
    }

    @Test func parsesProgramGuideFromArchive() async throws {
        let archiveURL = try resourceURL(named: "program-guide.xml.gz")
        let xmlURL = try resourceURL(named: "program-guide.xml")
        let parser = ProgramGuideParser()

        let guidesFromArchive = try await parser.parse(archiveURL: archiveURL)
        let guidesFromXML = try await parser.parse(xmlURL: xmlURL)

        #expect(guidesFromArchive == guidesFromXML)
    }

    @Test func parsesProgramGuideBigArchive() async throws {
        let receiveSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        let foundSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        let archiveURL = try resourceURL(named: "test.xml.gz")
        let parser = ProgramGuideParser(onProgress: { steps, step, _ in
            receiveSteps.withLock { $0 = steps }
            foundSteps.withLock({ $0.append(step) })
        })
        let clock = ContinuousClock()
        let duration = try await clock.measure {
           let _ = try await parser.parse(archiveURL: archiveURL)
        }
        #expect(duration < .seconds(10.0))
        receiveSteps.withLock({
            #expect([.start, .unarchiving, .parsing, .complete] == $0)
        })
        foundSteps.withLock({
            #expect([.start, .unarchiving, .parsing, .complete] == $0)
        })
    }
    
    @Test func parsesProgramGuideRemoteURLArchive() async throws {
        let receiveSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        let foundSteps = OSAllocatedUnfairLock(initialState: [ProgramGuideParser.Progress]())
        await #expect(throws: Error.self) {
            _ = try await ProgramGuideParser(onProgress: { steps, step, _ in
                receiveSteps.withLock { $0 = steps }
                foundSteps.withLock({ $0.append(step) })
            }).parse(archiveURL: URL(string: "https://google.com/archive.zip")!)
        }
        receiveSteps.withLock({
            #expect([.start, .downloading, .unarchiving, .parsing, .complete] == $0)
        })
        foundSteps.withLock({
            #expect([.start, .downloading, .complete] == $0)
        })
    }

    private var expectedGuides: [ProgramGuide] {
        [
            ProgramGuide(
                channel: .init(
                    id: "673247127d5da5000817b4d6",
                    displayName: "Pluto TV Trending Now",
                    iconURL: "https://images.pluto.tv/channels/673247127d5da5000817b4d6/colorLogoPNG_1732662634386.png"
                ),
                programs: [
                    .init(
                        title: "Maggie and the Ferocious Beast",
                        start: date(year: 2026, month: 2, day: 18, hour: 13, minute: 53, second: 22),
                        stop: date(year: 2026, month: 2, day: 18, hour: 14, minute: 22, second: 22)
                    ),
                    .init(
                        title: "Maggie and the Ferocious Beast",
                        start: date(year: 2026, month: 2, day: 18, hour: 14, minute: 22, second: 22),
                        stop: date(year: 2026, month: 2, day: 18, hour: 14, minute: 51, second: 22)
                    )
                ]
            ),
            ProgramGuide(
                channel: .init(
                    id: "5ba3fb9c4b078e0f37ad34e8",
                    displayName: "Pluto TV Spotlight",
                    iconURL: "https://images.pluto.tv/channels/5ba3fb9c4b078e0f37ad34e8/colorLogoPNG.png"
                ),
                programs: [
                    .init(
                        title: "Maggie and the Ferocious Beast",
                        start: date(year: 2026, month: 2, day: 18, hour: 14, minute: 51, second: 22),
                        stop: date(year: 2026, month: 2, day: 18, hour: 15, minute: 20, second: 22)
                    ),
                    .init(
                        title: "Maggie and the Ferocious Beast",
                        start: date(year: 2026, month: 2, day: 18, hour: 15, minute: 20, second: 22),
                        stop: date(year: 2026, month: 2, day: 18, hour: 15, minute: 49, second: 22)
                    )
                ]
            )
        ]
    }
}

private extension ProgramGuideParserTests {

    func resourceURL(named resourceName: String) throws -> URL {
        let bundle = Bundle(for: BundleLocator.self)

        if let resourceURL = bundle.url(forResource: resourceName, withExtension: nil) {
            return resourceURL
        }

        if let resourceURL = bundle.url(
            forResource: (resourceName as NSString).deletingPathExtension,
            withExtension: (resourceName as NSString).pathExtension,
            subdirectory: "Resources"
        ) {
            return resourceURL
        }

        throw TestError.missingResource(resourceName)
    }

    func date(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        return components.date!
    }
}

private final class BundleLocator: NSObject {}

private enum TestError: Error {
    case missingResource(String)
}
