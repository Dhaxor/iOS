//
//  DaxOnboarding.swift
//  DuckDuckGo
//
//  Created by Chris Brind on 11/05/2020.
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//

import Foundation
import Core

class DaxOnboarding {
    
    struct MajorTrackers {
        
        static let facebookDomain = "facebook.com"
        static let googleDomain = "google.com"
        
        static let domains = [ Self.facebookDomain, Self.googleDomain ]
        
    }
    
    struct HomeScreenSpec: Equatable {
        // swiftlint:disable line_length
        static let initial = HomeScreenSpec(height: 235, message: "Next, try visiting one of your favorite sites!\n\nI’ll block trackers so they can’t spy on you. I’ll also upgrade the security of your connection if possible. 🔒")
        
        static let subsequent = HomeScreenSpec(height: 210, message: "You’ve got this!\n\nRemember: every time you browse with me a creepy ad loses its wings. 👍")
        // swiftlint:enable line_length

        let height: CGFloat
        let message: String
        
    }
    
    struct BrowsingSpec: Equatable {

        // swiftlint:disable line_length
        static let afterSearch = BrowsingSpec(height: 250, message: "Your DuckDuckGo searches are anonymous and I never store your search history.  Ever. 🙌", cta: "Phew!")
        
        static let withoutTrackers = BrowsingSpec(height: 340, message: "As you tap and scroll, I'll block pesky trackers.\nGo head - keep browsing!", cta: "Got It")
        
        static let siteIsMajorTracker = BrowsingSpec(height: 340, message: "Heads up! %0@ is a major tracking network.\nTheir trackers lurk on about %1d% of top sites 😱 but don't worry!<br>I'll block %0@ from seeing your activity on those sites.", cta: "Got It")
        
        static let siteOwnedByMajorTracker = BrowsingSpec(height: 340, message: "Heads up! %1$@ is owned by %2$@.<br>%2$@'s trackers lurk on about %3$.0lf%% of top websites 😱 but don't worry!<br>I'll block %2$@ from seeing your activity on those sites.", cta: "Got It")
        
        static let withOneMajorTracker = BrowsingSpec(height: 340, message: "*%0@* was trying to track you here.\n\nI blocked them!\n\n☝️ You can check the URL bar to see who is trying to track you when you visit a new site.", cta: "High Five!")

        static let withOneMajorTrackerAndOthers = BrowsingSpec(height: 340, message: "*%0@* and *%1d others* were trying to track you here.\n\nI blocked them!\n\n☝️ You can check the URL bar to see who is trying to track you when you visit a new site.", cta: "High Five!")
        
        static let withTwoMajorTrackers = BrowsingSpec(height: 340, message: "*%0@ and %1@* were trying to track you here.\n\nI blocked them!\n\n☝️ You can check the URL bar to see who is trying to track you when you visit a new site.", cta: "High Five!")
        
        static let withTwoMajorTrackerAndOthers = BrowsingSpec(height: 340, message: "*%0@, %1@* and *%2d others* were trying to track you here.\n\nI blocked them!\n\n☝️ You can check the URL bar to see who is trying to track you when you visit a new site.", cta: "High Five!")

        // swiftlint:enable line_length

        let height: CGFloat
        let message: String
        let cta: String
        
        func format(args: CVarArg...) -> BrowsingSpec {
            return BrowsingSpec(height: height, message: String(format: message, arguments: args), cta: cta)
        }
        
    }
    
    private let appUrls = AppUrls()
    private var settings: DaxOnboardingSettings
    
    init(settings: DaxOnboardingSettings = DefaultDaxOnboardingSettings()) {
        self.settings = settings
    }
    
    private var browsingMessageSeen: Bool {
        return settings.browsingAfterSearchShown
            || settings.browsingWithTrackersShown
            || settings.browsingWithoutTrackersShown
            || settings.browsingMajorTrackingSiteShown
            || settings.browsingOwnedByMajorTrackingSiteShown
    }
    
    func dismiss() {
        settings.isDismissed = true
    }
    
    func nextBrowsingMessage(siteRating: SiteRating) -> BrowsingSpec? {
        guard let host = siteRating.domain else { return nil }
        guard !settings.isDismissed else { return nil }
                
        if appUrls.isDuckDuckGoSearch(url: siteRating.url) {
            return searchMessage()
        }
        
        if isMajorTracker(host) {
            return majorTrackerMessage()
        }
        
        if let owner = majorTrackerOwnerOf(host) {
            return majorTrackerOwnerMessage(host, owner)
        }
        
        if siteRating.trackersBlocked.isEmpty {
            return noTrackersMessage()
        }
        
        if let trackersBlocked = trackersBlocked(siteRating) {
            return trackersBlockedMessage(trackersBlocked)
        }
        
        return nil
    }
    
    /// Get the next home screen message.
    ///
    /// Returns a tuple containing the height of the dialog and the message or nil if there's nothing left to show or the flow has been disabled
    func nextHomeScreenMessage() -> HomeScreenSpec? {
        guard !settings.isDismissed else { return nil }
        guard settings.homeScreenMessagesSeen < 2 else { return nil }
        
        if settings.homeScreenMessagesSeen == 0 {
            settings.homeScreenMessagesSeen += 1
            return .initial
        }
        
        if browsingMessageSeen {
            settings.homeScreenMessagesSeen += 1
            return .subsequent
        }
        
        return nil
    }
    
    private func noTrackersMessage() -> DaxOnboarding.BrowsingSpec? {
        if !settings.browsingWithoutTrackersShown {
            settings.browsingWithoutTrackersShown = true
            return BrowsingSpec.withoutTrackers
        }
        return nil
    }

    func majorTrackerOwnerMessage(_ host: String, _ majorTrackerEntity: Entity) -> DaxOnboarding.BrowsingSpec? {
        guard !settings.browsingOwnedByMajorTrackingSiteShown else { return nil }
        settings.browsingOwnedByMajorTrackingSiteShown = true
        return BrowsingSpec.siteOwnedByMajorTracker.format(args: host.dropPrefix(prefix: "www."),
                                                           majorTrackerEntity.displayName ?? "",
                                                           majorTrackerEntity.prevalence ?? 0.0)
    }
    
    private func majorTrackerMessage() -> DaxOnboarding.BrowsingSpec? {
        guard !settings.browsingMajorTrackingSiteShown else { return nil }
        settings.browsingMajorTrackingSiteShown = true
        return BrowsingSpec.siteIsMajorTracker
    }
    
    private func searchMessage() -> BrowsingSpec? {
        guard !settings.browsingAfterSearchShown else { return nil }
        settings.browsingAfterSearchShown = true
        return BrowsingSpec.afterSearch
    }
    
    private func trackersBlockedMessage(_ trackersBlocked: (major: [Entity], other: [Entity])) -> BrowsingSpec? {
        guard !settings.browsingWithTrackersShown else { return nil }
        settings.browsingWithTrackersShown = true

        switch trackersBlocked {
            
        case let x where x.major.count == 1 && x.other.count == 0:
            return BrowsingSpec.withOneMajorTracker.format(args: x.major[0].displayName ?? "")

        case let x where x.major.count == 1 && x.other.count > 0:
            return BrowsingSpec.withOneMajorTrackerAndOthers.format(args: x.major[0].displayName ?? "", x.other.count)

        case let x where x.major.count == 2 && x.other.count == 0:
            return BrowsingSpec.withTwoMajorTrackers.format(args: x.major[0].displayName ?? "", x.major[1].displayName ?? "")

        case let x where x.major.count == 2 && x.other.count > 0:
            return BrowsingSpec.withTwoMajorTrackerAndOthers.format(args: x.major[0].displayName ?? "", x.major[1].displayName ?? "", x.other.count)

        default: return nil
        }

    }
 
    private func trackersBlocked(_ siteRating: SiteRating) -> (major: [Entity], other: [Entity])? {
        guard !siteRating.trackersBlocked.isEmpty else { return nil }

        var major = Set<Entity>()
        var other = Set<Entity>()
        
        siteRating.trackersBlocked.forEach {
            guard let entity = $0.entity else { return }
            if entity.domains?.contains(MajorTrackers.facebookDomain) ?? false {
                major.insert(entity)
            } else if entity.domains?.contains(MajorTrackers.googleDomain) ?? false {
                major.insert(entity)
            } else {
                other.insert(entity)
            }
        }
        
        return (Array(major).sorted(by: { $0.prevalence ?? 0.0 > $1.prevalence ?? 0.0 }), Array(other))
    }
    
    private func isMajorTracker(_ host: String) -> Bool {
        return [ MajorTrackers.facebookDomain, MajorTrackers.googleDomain ].contains { domain in
            return domain == host || host.hasSuffix("." + domain)
        }
    }
    
    private func majorTrackerOwnerOf(_ host: String) -> Entity? {
        guard let entity = TrackerDataManager.shared.findEntity(forHost: host) else { return nil }
        return entity.domains?.contains(where: { MajorTrackers.domains.contains($0) }) ?? false ? entity : nil
    }
    
}
