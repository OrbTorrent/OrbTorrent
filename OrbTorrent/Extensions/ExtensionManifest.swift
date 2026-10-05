import Foundation

/// The version of the extension API this OrbTorrent provides. An extension
/// built with a newer minor version may use something missing here, and one
/// with a newer major version certainly does.
enum ExtensionAPI {
    static let version = (major: 1, minor: 2)
    static var versionString: String { "\(version.major).\(version.minor).0" }

    /// Whether an extension built with `version` of `@orbtorrent/api` can run here.
    static func supports(_ version: String) -> Bool {
        let numbers = version.trimmingCharacters(in: CharacterSet(charactersIn: "^~>=< v"))
            .split(separator: ".").map { Int($0) ?? 0 }
        let major = numbers.first ?? 0
        let minor = numbers.count > 1 ? numbers[1] : 0
        return major == Self.version.major && minor <= Self.version.minor
    }
}

/// An extension's `package.json`: what it is, when it runs, what it may do
/// and the settings it needs.
struct ExtensionManifest: Sendable, Equatable {
    enum Event: String, Sendable, CaseIterable {
        case beforeStart
        case afterFinish
        /// Once a download's other checks are done: after it finishes, and
        /// when a check holds it before it starts.
        case afterChecks

        /// For the Extensions page's "Runs" list.
        var title: String {
            switch self {
            case .beforeStart: "Before a download starts, and can hold it"
            case .afterFinish: "After a download finishes"
            case .afterChecks: "Once a download's checks are done, to report what they found"
            }
        }
    }

    struct Hook: Sendable, Equatable, Identifiable {
        let name: String
        let title: String
        let description: String?
        let event: Event
        var id: String { name }
    }

    struct Permissions: Sendable, Equatable {
        var readsFileContents = false
        /// Whether it may add files, such as subtitles, next to a finished download's files.
        var addsFiles = false
        /// Host names it may reach over HTTPS, in lowercase.
        var network: [String] = []

        func allows(host: String) -> Bool {
            network.contains(host.lowercased())
        }
    }

    struct Preference: Sendable, Equatable, Identifiable {
        enum Kind: String, Sendable {
            case textfield, password, checkbox, dropdown
        }

        struct Option: Sendable, Equatable, Hashable {
            let title: String
            let value: String
        }

        let name: String
        let kind: Kind
        let title: String
        let description: String?
        let isRequired: Bool
        let placeholder: String?
        /// A checkbox's label, shown next to it.
        let label: String?
        let defaultValue: JSONValue?
        let options: [Option]
        var id: String { name }
    }

    struct Invalid: LocalizedError, Equatable {
        let problems: [String]
        var errorDescription: String? {
            "The extension's package.json isn't valid:\n" + problems.map { "• \($0)" }.joined(separator: "\n")
        }
    }

    let name: String
    let title: String
    let description: String
    let author: String
    let icon: String?
    let license: String?
    let version: String?
    let hooks: [Hook]
    let permissions: Permissions
    let preferences: [Preference]
    /// The entry point that checks the settings, if it has one.
    let verify: String?
    /// The `@orbtorrent/api` version it was built with.
    let apiVersion: String?

    init(data: Data) throws {
        guard let json = try? JSONValue(data: data), let root = json.object else {
            throw Invalid(problems: ["package.json isn't a JSON object."])
        }
        var problems: [String] = []
        func text(_ key: String, required: Bool = true) -> String? {
            let value = root[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            if required, value?.isEmpty ?? true { problems.append("“\(key)” is missing.") }
            return value?.isEmpty == false ? value : nil
        }

        name = text("name") ?? ""
        if !name.isEmpty, !Self.isIdentifier(name) {
            problems.append("“name” must be lowercase letters, digits and hyphens, such as “fake-download-check”.")
        }
        title = text("title") ?? ""
        description = text("description") ?? ""
        author = text("author") ?? ""
        icon = text("icon", required: false)
        license = text("license", required: false)
        version = text("version", required: false)
        verify = text("verify", required: false)
        if let verify, !Self.isIdentifier(verify) {
            problems.append("“verify” must name a file in src, such as “verify”.")
        }

        var hooks: [Hook] = []
        let hookList = root["hooks"]?.array ?? []
        if hookList.isEmpty { problems.append("“hooks” must list at least one hook.") }
        for (index, entry) in hookList.enumerated() {
            let label = "hooks[\(index)]"
            guard let hookName = entry["name"]?.string, Self.isIdentifier(hookName) else {
                problems.append("\(label) needs a “name” of lowercase letters, digits and hyphens.")
                continue
            }
            guard let event = entry["event"]?.string.flatMap(Event.init(rawValue:)) else {
                problems.append("\(label) (“\(hookName)”) needs an “event”: “beforeStart”, “afterFinish” or “afterChecks”.")
                continue
            }
            if hooks.contains(where: { $0.name == hookName }) {
                problems.append("Two hooks are named “\(hookName)”.")
            }
            hooks.append(Hook(name: hookName, title: entry["title"]?.string ?? hookName,
                              description: entry["description"]?.string, event: event))
        }
        self.hooks = hooks

        var permissions = Permissions()
        if let permissionsValue = root["permissions"], !permissionsValue.isNull {
            if let files = permissionsValue["files"], !files.isNull {
                // One of "contents" and "add", or a list of them.
                let values = files.array?.map(\.string) ?? [files.string]
                for value in values {
                    switch value {
                    case "contents": permissions.readsFileContents = true
                    case "add": permissions.addsFiles = true
                    case "names": break
                    default:
                        if !problems.contains(Self.filesProblem) { problems.append(Self.filesProblem) }
                    }
                }
            }
            for host in permissionsValue["network"]?.array ?? [] {
                guard let host = host.string?.lowercased(), Self.isHostName(host) else {
                    problems.append("“permissions.network” lists host names only, such as “www.virustotal.com”, without https:// or a path.")
                    continue
                }
                if !permissions.network.contains(host) { permissions.network.append(host) }
            }
        }
        self.permissions = permissions

        var preferences: [Preference] = []
        for (index, entry) in (root["preferences"]?.array ?? []).enumerated() {
            let label = "preferences[\(index)]"
            guard let preferenceName = entry["name"]?.string,
                  preferenceName.range(of: #"^[A-Za-z][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
                problems.append("\(label) needs a “name” made of letters, digits and underscores, starting with a letter.")
                continue
            }
            guard let kind = entry["type"]?.string.flatMap(Preference.Kind.init(rawValue:)) else {
                problems.append("\(label) (“\(preferenceName)”) needs a “type”: textfield, password, checkbox or dropdown.")
                continue
            }
            if preferences.contains(where: { $0.name == preferenceName }) {
                problems.append("Two preferences are named “\(preferenceName)”.")
            }
            let options = (entry["data"]?.array ?? []).compactMap { option -> Preference.Option? in
                guard let value = option["value"]?.string else { return nil }
                return Preference.Option(title: option["title"]?.string ?? value, value: value)
            }
            if kind == .dropdown, options.isEmpty {
                problems.append("The dropdown “\(preferenceName)” needs “data”: a list of { title, value }.")
            }
            let defaultValue = entry["default"].flatMap { $0.isNull ? nil : $0 }
            if let defaultValue {
                switch kind {
                case .checkbox where defaultValue.bool == nil:
                    problems.append("The checkbox “\(preferenceName)” needs true or false as its default.")
                case .dropdown where !options.contains { $0.value == defaultValue.string }:
                    problems.append("The dropdown “\(preferenceName)” has a default that isn't one of its values.")
                case .textfield where defaultValue.string == nil:
                    problems.append("The text field “\(preferenceName)” needs text as its default.")
                case .password:
                    problems.append("The password “\(preferenceName)” can't have a default.")
                default: break
                }
            }
            preferences.append(Preference(
                name: preferenceName, kind: kind,
                title: entry["title"]?.string ?? preferenceName,
                description: entry["description"]?.string,
                isRequired: entry["required"]?.bool ?? false,
                placeholder: entry["placeholder"]?.string,
                label: entry["label"]?.string,
                defaultValue: defaultValue,
                options: options
            ))
        }
        self.preferences = preferences

        // `orb build` records the exact version it built with.
        let isVersion = { (text: String) in text.range(of: #"^[\^~]?\d+(\.\d+){0,2}"#, options: .regularExpression) != nil }
        if let built = root["orbtorrent"]?["api"]?.string {
            apiVersion = built
            if !isVersion(built) { problems.append("The @orbtorrent/api version “\(built)” isn't a version number.") }
        } else {
            apiVersion = root["dependencies"]?["@orbtorrent/api"]?.string.flatMap { isVersion($0) ? $0 : nil }
        }

        if !problems.isEmpty { throw Invalid(problems: problems) }
    }

    func hooks(for event: Event) -> [Hook] {
        hooks.filter { $0.event == event }
    }

    /// What it's allowed to do, in plain words, for the Extensions page and
    /// the install sheet.
    var abilities: [String] {
        var lines = ["See the names and sizes of the files in your downloads"]
        if hooks.contains(where: { $0.event == .beforeStart }) {
            lines.append("Hold a download before it starts, until you decide")
        }
        if hooks.contains(where: { $0.event == .afterChecks }) {
            lines.append("See what other extensions found in your downloads")
        }
        if permissions.readsFileContents {
            lines.append("Read the contents of your downloads")
        }
        if permissions.addsFiles {
            lines.append("Add files, such as subtitles, next to your downloads")
        }
        lines += permissions.network.map { "Connect to \($0)" }
        return lines
    }

    private static let filesProblem = "“permissions.files” can only be “contents”, “add”, or a list of both."

    static func isIdentifier(_ text: String) -> Bool {
        text.count <= 64 && text.range(of: #"^[a-z0-9]+(-[a-z0-9]+)*$"#, options: .regularExpression) != nil
    }

    static func isHostName(_ text: String) -> Bool {
        text.count <= 253 && text.contains(".")
            && text.range(of: #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"#, options: .regularExpression) != nil
    }
}
