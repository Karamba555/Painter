import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var id: String { rawValue }
}

enum Topic: String, Codable, CaseIterable, Identifiable {
    case manga, animals, flowers, portraits, relax
    var id: String { rawValue }
    var title: String {
        switch self {
        case .manga: "Manga"
        case .animals: "Animals & Pets"
        case .flowers: "Flowers"
        case .portraits: "Portraits"
        case .relax: "Relax & color"
        }
    }
    var subtitle: String {
        switch self {
        case .manga: "Big expressions. Little beginnings."
        case .animals: "Little creatures. Lots of character."
        case .flowers: "Let something beautiful bloom."
        case .portraits: "Find the person in every pencil line."
        case .relax: "Slow down with coloring pages."
        }
    }
    var artwork: String {
        switch self {
        case .manga: "manga"
        case .animals: "pet"
        case .flowers: "flowers"
        case .portraits: "portrait"
        case .relax: "mandala"
        }
    }
}

struct Drawing: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let asset: String
    let topic: Topic
    let difficulty: Difficulty
    let minutes: Int
    let isFree: Bool
    var localImage: String? = nil
    var origin: String? = nil
    var isPhoto: Bool { localImage != nil && origin != "ai" }
    var isOutline: Bool { localImage != nil || origin == "template-outline" }
}

struct Lesson: Hashable, Identifiable {
    let id: String
    let title: String
    let drawing: Drawing
    let minutes: Int
    let isFree: Bool
    let day: Int?
    let steps: [String]
    var difficulty: Difficulty { drawing.difficulty }
}

enum Catalog {
    static let drawings: [Drawing] = [
        .init(id: "kitten", title: "Lucky kitten", asset: "kitten", topic: .manga, difficulty: .easy, minutes: 10, isFree: true, origin: "template-outline"),
        .init(id: "flower-girl", title: "Flower girl", asset: "flower-girl", topic: .manga, difficulty: .medium, minutes: 20, isFree: false),
        .init(id: "hoodie", title: "Sunday hoodie", asset: "hoodie", topic: .manga, difficulty: .medium, minutes: 25, isFree: false),
        .init(id: "moon", title: "Moon keeper", asset: "moon", topic: .manga, difficulty: .hard, minutes: 30, isFree: false),
        .init(id: "pet", title: "My little muse", asset: "pet", topic: .animals, difficulty: .medium, minutes: 15, isFree: true),
        .init(id: "cat", title: "Sleepy cat", asset: "cat", topic: .animals, difficulty: .easy, minutes: 12, isFree: false),
        .init(id: "flowers", title: "First bloom", asset: "flowers", topic: .flowers, difficulty: .easy, minutes: 8, isFree: true),
        .init(id: "portrait", title: "Quiet portrait", asset: "portrait", topic: .portraits, difficulty: .hard, minutes: 30, isFree: true),
        .init(id: "mandala", title: "A moment of calm", asset: "mandala", topic: .relax, difficulty: .medium, minutes: 20, isFree: true)
    ]
    static func drawing(_ id: String) -> Drawing { drawings.first { $0.id == id } ?? drawings[0] }
    static let lessons: [Lesson] = [
        .init(id: "first-flower", title: "Make your first flower", drawing: drawing("flowers"), minutes: 8, isFree: true, day: 1, steps: [
            "Start lightly. Draw a small oval for the center of your flower.",
            "Add five loose petals around the center. Let their shapes vary a little.",
            "Draw a gentle curve down from the flower to make the stem.",
            "Add two leaves. Use a curved line for each edge and a light line through the middle.",
            "Give the petals a few fine lines, moving outward from the center.",
            "Erase your guide marks, strengthen the outline, then add a touch of color."
        ]),
        .init(id: "little-muse", title: "Meet your little muse", drawing: drawing("pet"), minutes: 15, isFree: true, day: nil, steps: [
            "Sketch a light oval for the head and a smaller oval for the muzzle.",
            "Mark the eye line halfway down the head. Keep both eyes on this guide.",
            "Place two small eyes, leaving room for the bridge of the nose.",
            "Draw the nose and two soft curves below it for the muzzle.",
            "Add long ears on each side, using loose, wavy lines.",
            "Build up the fur with short strokes in the direction it grows.",
            "Add a bandana below the chin. Keep the folds simple.",
            "Darken the nose and pupils. Leave a tiny white highlight in each eye."
        ]),
        .init(id: "character", title: "Bring a character to life", drawing: .init(id: "character-study", title: "Flower girl", asset: "flower-girl", topic: .manga, difficulty: .hard, minutes: 25, isFree: true), minutes: 25, isFree: true, day: nil, steps: [
            "Start with an oval and a soft center line to set the angle of the face.",
            "Shape the jaw, tapering gently toward the chin.",
            "Mark the eye line and lightly place the upper eyelids.",
            "Add the irises and pupils. Preserve small white highlights.",
            "Place a small nose and a soft line for the mouth.",
            "Block in the hair as a few large shapes before adding strands.",
            "Separate the fringe into curved sections that follow the head.",
            "Draw the flower accessory with overlapping petals.",
            "Add the neck and shoulders. Keep the clothing folds light.",
            "Vary the line weight, erase guides, and add subtle shading beneath the hair."
        ])
    ]
    static let challenge: [Lesson] = [lessons[0]] + (2...7).map { day in
        let art = ["kitten", "cat", "pet", "flower-girl", "portrait", "mandala"][day - 2]
        return Lesson(id: "challenge-\(day)", title: ["A lucky little kitten", "Soft curves", "A pet with personality", "Expressive eyes", "Faces in pencil", "Your moment of calm"][day - 2], drawing: drawing(art), minutes: 10 + day * 2, isFree: false, day: day, steps: [
            "Look closely at the reference. Find the largest shapes before you start.",
            "Sketch those shapes lightly, checking their size and position on the page.",
            "Connect the shapes with a clear outer contour.",
            "Add the features that give this drawing its character.",
            "Build depth with a few light shadows. Leave the bright areas untouched.",
            "Clean up the guide lines and finish with your own colors and details."
        ])
    }
    static func lesson(_ id: String) -> Lesson { (lessons + challenge).first { $0.id == id } ?? lessons[0] }
    static func feed(interests: Set<Topic>) -> [Drawing] {
        let topics = interests.isEmpty ? [.flowers, .manga, .relax] : Topic.allCases.filter { interests.contains($0) }
        let preferred = topics.compactMap { topic in drawings.first { $0.topic == topic } }
        let moreFromSelectedTopics = drawings.filter { topics.contains($0.topic) && !preferred.contains($0) }
        let otherTopics = drawings.filter { !topics.contains($0.topic) }
        return preferred + moreFromSelectedTopics + otherTopics
    }
}

enum TraceMode: String, CaseIterable, Identifiable, Hashable {
    case camera, ar, screen
    var id: String { rawValue }
    var title: String { [Self.camera: "Camera Trace", .ar: "AR Trace", .screen: "Screen Trace"][self]! }
    var caption: String {
        switch self {
        case .camera: "Keep your phone still above the paper."
        case .ar: "Move your phone. The outline stays in place."
        case .screen: "Trace through thin paper on your screen."
        }
    }
    var badge: String {
        switch self {
        case .camera: "PHONE STAYS STILL"
        case .ar: "OUTLINE STAYS IN PLACE"
        case .screen: "NO CAMERA NEEDED"
        }
    }
    var instructions: [String] {
        switch self {
        case .camera: ["Rest your phone flat on a stable glass, with its rear camera clear of the rim.", "Place your paper below the camera. Adjust the outline, then lock it.", "Look at your phone as you draw on the paper. If either moves, align the outline again."]
        case .ar: ["Put your paper on a well-lit table with visible texture around its edges. Slowly scan the table with your phone.", "Tap the paper after a surface is detected. Adjust the size and rotation, then lock the outline.", "The outline is anchored to the table, not to the paper. Keep the paper still. If tracking is lost, stop drawing and realign before continuing."]
        case .screen: ["Place thin paper directly on your phone screen.", "Adjust the drawing size, then lock the controls. The screen will brighten.", "Trace gently with a soft pencil. Keep the paper clean and avoid pressing hard."]
        }
    }
}
