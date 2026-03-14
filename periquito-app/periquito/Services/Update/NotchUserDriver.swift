//
//  NotchUserDriver.swift
//  periquito
//
//  Custom Sparkle user driver that routes all UI callbacks to UpdateManager
//

import Foundation
import Sparkle

/// Custom Sparkle user driver that routes all UI to UpdateManager.
/// Sparkle calls these methods from background threads, so we hop
/// to @MainActor via Task when touching UpdateManager.
nonisolated class NotchUserDriver: NSObject, SPUUserDriver {

    nonisolated var canCheckForUpdates: Bool { true }

    // MARK: - Permission & Check

    nonisolated func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    nonisolated func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        Task { @MainActor in
            UpdateManager.shared.state = .checking
        }
    }

    // MARK: - Update Found

    nonisolated func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let version = appcastItem.displayVersionString
        let releaseNotes = appcastItem.itemDescription

        Task { @MainActor in
            UpdateManager.shared.updateFound(
                version: version,
                releaseNotes: releaseNotes,
                installHandler: reply
            )
        }
    }

    nonisolated func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        // Release notes already captured from appcastItem
    }

    nonisolated func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        // Ignore release notes download failures
    }

    nonisolated func showUpdateNotFoundWithError(
        _ error: Error,
        acknowledgement: @escaping () -> Void
    ) {
        Task { @MainActor in
            UpdateManager.shared.noUpdateFound()
            acknowledgement()
        }
    }

    nonisolated func showUpdaterError(
        _ error: Error,
        acknowledgement: @escaping () -> Void
    ) {
        Task { @MainActor in
            UpdateManager.shared.updateError(error.localizedDescription)
            acknowledgement()
        }
    }

    // MARK: - Download Progress

    nonisolated func showDownloadInitiated(cancellation: @escaping () -> Void) {
        Task { @MainActor in
            UpdateManager.shared.downloadStarted(cancellation: cancellation)
        }
    }

    nonisolated func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        Task { @MainActor in
            UpdateManager.shared.downloadExpectedLength(expectedContentLength)
        }
    }

    nonisolated func showDownloadDidReceiveData(ofLength length: UInt64) {
        Task { @MainActor in
            UpdateManager.shared.downloadReceivedData(length)
        }
    }

    nonisolated func showDownloadDidStartExtractingUpdate() {
        Task { @MainActor in
            UpdateManager.shared.extractionStarted()
        }
    }

    nonisolated func showExtractionReceivedProgress(_ progress: Double) {
        Task { @MainActor in
            UpdateManager.shared.extractionProgress(progress)
        }
    }

    // MARK: - Install

    nonisolated func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        Task { @MainActor in
            UpdateManager.shared.readyToInstall(installHandler: reply)
        }
    }

    nonisolated func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        Task { @MainActor in
            UpdateManager.shared.installing()
        }
    }

    nonisolated func showUpdateInstalledAndRelaunched(
        _ relaunched: Bool,
        acknowledgement: @escaping () -> Void
    ) {
        Task { @MainActor in
            UpdateManager.shared.installed(relaunched: relaunched)
            acknowledgement()
        }
    }

    nonisolated func dismissUpdateInstallation() {
        Task { @MainActor in
            UpdateManager.shared.sparkleDidDismiss()
        }
    }

    // MARK: - Resume / Focus

    nonisolated func showUpdateInFocus() {
        // No-op: could expand notch here if desired
    }

    nonisolated func showResumableUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        showUpdateFound(with: appcastItem, state: state, reply: reply)
    }

    nonisolated func showInformationalUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        reply(.dismiss)
    }
}
