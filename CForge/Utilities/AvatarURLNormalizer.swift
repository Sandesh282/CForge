import Foundation

/// Normalizes a raw avatar URL string from the Codeforces API into a loadable URL.
///
/// Codeforces returns protocol-relative URLs (e.g. "//userpic.codeforces.org/..."),
/// which `URL(string:)` accepts but image loaders cannot fetch without a scheme.
/// Empty and nil inputs return nil rather than producing a meaningless URL.
func normalizeAvatarURL(_ raw: String?) -> URL? {
    guard let raw = raw, !raw.isEmpty else { return nil }
    let normalized = raw.hasPrefix("//") ? "https:" + raw : raw
    return URL(string: normalized)
}
