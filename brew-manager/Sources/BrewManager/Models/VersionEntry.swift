import Foundation

struct VersionEntry: Identifiable, Hashable {
    let id: String  // git commit hash
    let shortHash: String
    let message: String
    let author: String
    let date: Date
    let addedPackages: [String]
    let removedPackages: [String]
}
