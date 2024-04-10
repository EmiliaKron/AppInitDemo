//
//  ContentView.swift
//  AppInit
//
//  Created by Emilia Elgfors on 2024-04-09.
//

import SwiftUI

// Its a singleton cosplaying as something better, just for demo so its all good
class Dependency {
    static let shared = Dependency()
    let shouldFetchOne = true
    let shouldShowOnboarding = true
    let shouldFetchTwo = true
    let shouldShowDidFinish = true
}

struct ContentView: View {
    @State var showAppInit = true
    var body: some View {
        VStack {
            Text("This is the app")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.gray)
        .overlay {
            if showAppInit {
                LaunchScreen {
                    withAnimation {
                        showAppInit = false
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
}

struct LaunchScreen: View {
    
    @State private var action: AppInitializeAction = .idle
    @EnvironmentObject private var router: Router
    
    private let appInitializableSteps: [AppInitializable.Type] = [
        SetupAsyncOneAppInit.self,
        DidFinishAppInit.self,
        ShowOnboardingInit.self,
        SetupAsyncTwoAppInit.self
    ]

    var launchDone: (() -> Void)?
    
    var body: some View {
        VStack {
            Group {
                switch action {
                case .set(let route):
                    router.viewFrom(route)
                case .idle:
                    Image("logo")
                case .showLoader:
                    ProgressView()
                }
            }
            .task {
                do {
                    try await startInits()
                    debugPrint("Task done !")
                } catch {
                    action = .set(.error)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.teal)
    }
    
    private func startInits() async throws {
        let appInit = AppInitSequence(inits: appInitializableSteps.map {
            $0.init(action: $action)
        })
        for try await _ in appInit {}
        launchDone?()
    }
}

#Preview {
    ContentView()
        .environmentObject(Router())
}

struct SetupAsyncOneAppInit: AppInitializable {
    var shouldStart: Bool {
        Dependency.shared.shouldFetchOne
    }
    
    @Binding var action: AppInitializeAction
    
    init(action: Binding<AppInitializeAction>) {
        self._action = action
    }
    
    func action() async throws {
        action = .showLoader
        let delayedTask = Task.delayed(byTimeInterval: 2) {
            action = .idle
        }
        return try await delayedTask.value
    }
}

struct SetupAsyncTwoAppInit: AppInitializable {
    var shouldStart: Bool {
        Dependency.shared.shouldFetchTwo
    }
    
    @Binding var action: AppInitializeAction
    
    init(action: Binding<AppInitializeAction>) {
        self._action = action
    }
    
    func action() async throws {
        action = .showLoader
        let delayedTask = Task.delayed(byTimeInterval: 1.4) {
            action = .idle
        }
        return try await delayedTask.value
    }
}

struct ShowOnboardingInit: AppInitializable {
    
    var shouldStart: Bool {
        Dependency.shared.shouldShowOnboarding
    }
    
    @Binding var action: AppInitializeAction
    
    init(action: Binding<AppInitializeAction>) {
        self._action = action
    }
    
    func action() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let route = Route.cta {
                continuation.resume(with: .success(()))
            }
            action = .set(route)
        }
    }
}

struct DidFinishAppInit: AppInitializable {
    var shouldStart: Bool {
        Dependency.shared.shouldShowDidFinish
    }
    
    @Binding var action: AppInitializeAction
    
    init(action: Binding<AppInitializeAction>) {
        self._action = action
    }
    
    func action() async throws {
        action = .set(.finished)
        let delayedTask = Task.delayed(byTimeInterval: 1.4) {
            action = .idle
        }
        return try await delayedTask.value
    }
}

// MARK: - AppInitializeAction

enum AppInitializeAction {
    case idle
    case showLoader
    case set(Route)
}

// MARK: - Router / Route
class Router: ObservableObject {
    @ViewBuilder
    func viewFrom(_ route: Route) -> some View {
        switch route {
        case .cta(let action):
           CTAView(action: action)
        case .forceUpdate:
            Text("Force Update")
        case .error:
            Text("Something went wrong")
        case .finished:
            Text("WOOOOO YOU DID IT!!! 💃💃💃💃💃💃")
        }
    }
}

struct CTAView: View {

    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text("This is onboarding")
            Button("Press to continue") {
                action?()
            }
        }
        .onAppear {
            debugPrint("did appear")
        }
    }
}

enum Route {
    case cta((() -> Void)?)
    case forceUpdate
    case error
    case finished
}

// MARK: - AppInitializable

protocol AppInitializable {
    var action: AppInitializeAction { get set }
    var shouldStart: Bool { get }
    func start() async throws
    func action() async throws
    init(action: Binding<AppInitializeAction>)
}

// MARK: AppInitializable + Extension

extension AppInitializable {
    func start()  async throws {
        if shouldStart {
            return try await action()
        }
        return ()
    }
}

// MARK: - AsyncSequence

struct AppInitSequence: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Void
    
    private let inits: [AppInitializable]
    
    init(inits: [AppInitializable]) {
        self.inits = inits
    }
    
    private var index = 0
    
    mutating func next() async throws -> Void? {
        defer { index += 1 }
        guard let item = inits[safe: index] else { return nil }
        return try await item.start()
    }
    
    func makeAsyncIterator() -> Self {
        return self
    }
}

// MARK: - Random extensions

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Task where Failure == Error {
    static func delayed(
        byTimeInterval delayInterval: TimeInterval,
        priority: TaskPriority? = nil,
        @_implicitSelfCapture operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: priority) {
            let delay = UInt64(delayInterval * 1_000_000_000)
            try await Task<Never, Never>.sleep(nanoseconds: delay)
            return try await operation()
        }
    }
}
