import Foundation

public enum UpdateChannelPolicy {
    /// Sparkle always includes the default (stable) channel. Previews may also receive previews.
    public static func allowedChannels(currentVersion: String) -> Set<String> {
        ReleaseVersion(currentVersion)?.isPrerelease == true ? ["preview"] : []
    }
}
