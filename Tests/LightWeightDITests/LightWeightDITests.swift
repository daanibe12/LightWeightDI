import Testing
@testable import LightWeightDI
import Foundation


// MARK: - スコープ別テスト

struct ScopeVariationTests {

    @Test func weakScopeはresolveのたびに新しいインスタンスを返す() {
        let resolver = DependencyResolver()
        var callCount = 0
        resolver.regist(GreeterRepository.self, scope: .weak) { _ in
            callCount += 1
            return GreeterRepository()
        }

        let a = resolver.resolve(GreeterRepository.self)
        let b = resolver.resolve(GreeterRepository.self)

        #expect(callCount == 2)
        #expect(a.id != b.id)
    }

    @Test func applicationScopeは同じインスタンスを返す() {
        let resolver = DependencyResolver()
        var callCount = 0
        resolver.regist(GreeterRepository.self, scope: .application) { _ in
            callCount += 1
            return GreeterRepository()
        }

        let a = resolver.resolve(GreeterRepository.self)
        let b = resolver.resolve(GreeterRepository.self)

        #expect(callCount == 1)
        #expect(a.id == b.id)
    }

    @Test func graphScopeは連続resolveで同じインスタンスを返す() {
        let resolver = DependencyResolver()
        var callCount = 0
        resolver.regist(GreeterRepository.self, scope: .graph) { _ in
            callCount += 1
            return GreeterRepository()
        }

        let a = resolver.resolve(GreeterRepository.self)
        let b = resolver.resolve(GreeterRepository.self)

        #expect(callCount == 1)
        #expect(a.id == b.id)
    }

    @Test func デフォルトスコープはweak() {
        let resolver = DependencyResolver()
        var callCount = 0
        resolver.regist(GreeterRepository.self) { _ in
            callCount += 1
            return GreeterRepository()
        }

        let a = resolver.resolve(GreeterRepository.self)
        let b = resolver.resolve(GreeterRepository.self)

        #expect(callCount == 2)
        #expect(a.id != b.id)
    }

    @Test func legacyFactoryクロージャはコンパイルできる() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterRepository.self, scope: .application) {
            GreeterRepository()
        }

        let a = resolver.resolve(GreeterRepository.self)
        let b = resolver.resolve(GreeterRepository.self)

        #expect(a.id == b.id)
    }

    @Test func 異なるResolver間でキャッシュは共有されない() {
        let resolverA = DependencyResolver()
        let resolverB = DependencyResolver()

        resolverA.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        resolverB.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }

        let a = resolverA.resolve(GreeterRepository.self)
        let b = resolverB.resolve(GreeterRepository.self)

        #expect(a.id != b.id)
    }

    @Test func 複数型を独立して解決できる() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        resolver.regist(NetworkClient.self, scope: .application) { _ in NetworkClient() }

        let repo = resolver.resolve(GreeterRepository.self)
        let client = resolver.resolve(NetworkClient.self)

        #expect(repo.id != client.id)
    }
}

// MARK: - 依存グラフ・スコープ混在

struct DependencyGraphTests {

    @Test func 依存関係の連鎖を解決できる() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        resolver.regist(GreeterViewModel.self, scope: .application) { r in
            GreeterViewModel(repository: r.resolve(GreeterRepository.self))
        }

        let vm = resolver.resolve(GreeterViewModel.self)
        let repo = resolver.resolve(GreeterRepository.self)

        #expect(vm.repository.id == repo.id)
    }

    @Test func 多段依存を解決できる() {
        let resolver = DependencyResolver()
        resolver.regist(NetworkClient.self, scope: .application) { _ in NetworkClient() }
        resolver.regist(AuthService.self, scope: .application) { r in
            AuthService(client: r.resolve(NetworkClient.self))
        }
        resolver.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        resolver.regist(DashboardViewModel.self, scope: .application) { r in
            DashboardViewModel(
                auth: r.resolve(AuthService.self),
                repo: r.resolve(GreeterRepository.self)
            )
        }

        let dashboard = resolver.resolve(DashboardViewModel.self)
        let auth = resolver.resolve(AuthService.self)
        let client = resolver.resolve(NetworkClient.self)

        #expect(dashboard.auth.client.id == client.id)
        #expect(dashboard.auth === auth)
    }

    @Test func スコープ混在でも依存解決できる() {
        let resolver = DependencyResolver()
        var weakCount = 0
        var appCount = 0

        resolver.regist(NetworkClient.self, scope: .weak) { _ in
            weakCount += 1
            return NetworkClient()
        }
        resolver.regist(AuthService.self, scope: .application) { r in
            appCount += 1
            return AuthService(client: r.resolve(NetworkClient.self))
        }

        let auth1 = resolver.resolve(AuthService.self)
        let auth2 = resolver.resolve(AuthService.self)

        #expect(appCount == 1)
        #expect(auth1 === auth2)
        #expect(weakCount == 1)
        #expect(auth1.client.id == auth2.client.id)
    }

    @Test func factoryにはresolverが渡される() {
        let resolver = DependencyResolver()
        var receivedResolver: DependencyResolver?
        resolver.regist(GreeterRepository.self, scope: .weak) { r in
            receivedResolver = r
            return GreeterRepository()
        }

        _ = resolver.resolve(GreeterRepository.self)
        #expect(receivedResolver === resolver)
    }

    @Test func プロトコル型で登録・解決できる() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterProtocol.self, scope: .application) { _ in
            Greeter(name: "Hello")
        }

        let greeter = resolver.resolve(GreeterProtocol.self)
        #expect(greeter.name == "Hello")
    }
}

// MARK: - 再登録・キャッシュ挙動

struct RegistrationVariationTests {

    @Test func 同じ型を再登録してもapplicationキャッシュは維持される() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        let first = resolver.resolve(GreeterRepository.self)

        resolver.regist(GreeterRepository.self, scope: .application) { _ in GreeterRepository() }
        let second = resolver.resolve(GreeterRepository.self)

        #expect(first.id == second.id)
    }

    @Test func weakScope再登録後も毎回新規生成される() {
        let resolver = DependencyResolver()
        resolver.regist(GreeterRepository.self, scope: .weak) { _ in GreeterRepository() }
        let first = resolver.resolve(GreeterRepository.self)

        resolver.regist(GreeterRepository.self, scope: .weak) { _ in GreeterRepository() }
        let second = resolver.resolve(GreeterRepository.self)

        #expect(first.id != second.id)
    }
}

// MARK: - 並行アクセス

struct ConcurrencyTests {

    @Test func applicationScopeは並行resolveでも同一インスタンス() async {
        let resolver = DependencyResolver()
        var callCount = 0
        resolver.regist(GreeterRepository.self, scope: .application) { _ in
            callCount += 1
            return GreeterRepository()
        }

        let ids = await withTaskGroup(of: UUID.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    resolver.resolve(GreeterRepository.self).id
                }
            }
            var collected: [UUID] = []
            for await id in group { collected.append(id) }
            return collected
        }

        #expect(callCount == 1)
        #expect(Set(ids).count == 1)
    }

    @Test func weakScopeは並行resolveでもそれぞれ生成される() async {
        let resolver = DependencyResolver()
        let counter = LockedCounter()
        resolver.regist(GreeterRepository.self, scope: .weak) { _ in
            counter.increment()
            return GreeterRepository()
        }

        let ids = await withTaskGroup(of: UUID.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    resolver.resolve(GreeterRepository.self).id
                }
            }
            var collected: [UUID] = []
            for await id in group { collected.append(id) }
            return collected
        }

        #expect(counter.value == 10)
        #expect(Set(ids).count == 10)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private var lock = NSLock()
    private(set) var value = 0
    func increment() {
        lock.lock(); defer { lock.unlock() }
        value += 1
    }
}

/// shared を使うテストの前に呼び、並行実行によるキャッシュ汚染を防ぐ
private func resetSharedResolver() {
    DependencyResolver.shared.initialize()
}

// MARK: - @Autowired バリエーション

private final class AutowiredUniqueCounter {
    let id = UUID()
}

private final class AutowiredApplicationCounter {
    let id = UUID()
}

private final class AutowiredGraphCounter {
    let id = UUID()
}

private final class AutowiredWeakHolder {
    @Autowired var counter: AutowiredUniqueCounter
}

private final class AutowiredApplicationHolder {
    @Autowired var counter: AutowiredApplicationCounter
}

private final class AutowiredGraphHolderA {
    @Autowired var counter: AutowiredGraphCounter
}

private final class AutowiredGraphHolderB {
    @Autowired var counter: AutowiredGraphCounter
}

/// factory が何回呼ばれたかを数えるヘルパー
private final class FactoryCallCounter {
    private(set) var count = 0
    func track<T>(_ make: () -> T) -> T {
        count += 1
        return make()
    }
}

/// Factory の `Scope.shared` と同等: コンテナが強参照を保持し reset まで同一インスタンスを返す
private final class FactorySharedScopeSimulator {
    private var cache = [String: Any]()

    func resolve<Service>(_ type: Service.Type, factory: () -> Service) -> Service {
        let key = String(describing: type)
        if let cached = cache[key] as? Service { return cached }
        let instance = factory()
        cache[key] = instance
        return instance
    }

    func reset() {
        cache.removeAll()
    }
}

// MARK: - DependencyResolver.shared テスト（singleton 競合防止のため直列実行）

@Suite(.serialized)
struct DependencyResolverSharedIsolationTests {

    @Suite
    struct AutowiredVariationTests {

        @Test func graphScopeはregist時点では生成されAutowired初アクセスで紐づく() {
            resetSharedResolver()

            final class LinkedService: AnyObject {
                let id = UUID()
            }
            final class LinkedHolder {
                @Autowired var service: LinkedService
            }

            var factoryCount = 0
            DependencyResolver.shared.regist(LinkedService.self, scope: .graph) { _ in
                factoryCount += 1
                return LinkedService()
            }
            #expect(factoryCount == 0)

            var holder = LinkedHolder()
            #expect(factoryCount == 0)

            let service = holder.service
            #expect(factoryCount == 1)

            let again = holder.service
            #expect(factoryCount == 1)
            #expect(service === again)
        }

        @Test func autowiredは初回アクセスで解決しプロパティ内キャッシュする() {
            resetSharedResolver()
            DependencyResolver.shared.regist(AutowiredUniqueCounter.self, scope: .weak) { _ in
                AutowiredUniqueCounter()
            }

            var holder = AutowiredWeakHolder()
            let first = holder.counter
            let second = holder.counter

            #expect(first.id == second.id)
        }

        @Test func autowiredGraphScopeは別Holder間で同一インスタンスを共有する() {
            resetSharedResolver()
            DependencyResolver.shared.regist(AutowiredGraphCounter.self, scope: .graph) { _ in
                AutowiredGraphCounter()
            }

            var holderA = AutowiredGraphHolderA()
            var holderB = AutowiredGraphHolderB()

            #expect(holderA.counter.id == holderB.counter.id)
        }

        @Test func autowiredApplicationScopeはHolder間で同一インスタンスを共有する() {
            resetSharedResolver()
            DependencyResolver.shared.regist(AutowiredApplicationCounter.self, scope: .application) { _ in
                AutowiredApplicationCounter()
            }

            var holderA = AutowiredApplicationHolder()
            var holderB = AutowiredApplicationHolder()

            #expect(holderA.counter.id == holderB.counter.id)
        }

        @Test func autowiredWeakScopeはHolderごとに別インスタンス() {
            resetSharedResolver()
            DependencyResolver.shared.regist(AutowiredUniqueCounter.self, scope: .weak) { _ in
                AutowiredUniqueCounter()
            }

            var holderA = AutowiredWeakHolder()
            var holderB = AutowiredWeakHolder()

            #expect(holderA.counter.id != holderB.counter.id)
        }

        @Test func 別親alive中はgraphは共有されweakは毎回別() {
            resetSharedResolver()

            final class GraphDep: AnyObject { let id = UUID() }
            final class WeakDep: AnyObject { let id = UUID() }
            final class GraphParentA { @Autowired var dep: GraphDep }
            final class GraphParentB { @Autowired var dep: GraphDep }
            final class WeakParentA { @Autowired var dep: WeakDep }
            final class WeakParentB { @Autowired var dep: WeakDep }

            var graphCount = 0
            var weakCount = 0
            DependencyResolver.shared.regist(GraphDep.self, scope: .graph) { _ in
                graphCount += 1
                return GraphDep()
            }
            DependencyResolver.shared.regist(WeakDep.self, scope: .weak) { _ in
                weakCount += 1
                return WeakDep()
            }

            var graphParentA = GraphParentA()
            var graphParentB = GraphParentB()
            let graphFromA = graphParentA.dep
            let graphFromB = graphParentB.dep

            var weakParentA = WeakParentA()
            var weakParentB = WeakParentB()
            let weakFromA = weakParentA.dep
            let weakFromB = weakParentB.dep

            #expect(graphCount == 1)
            #expect(graphFromA === graphFromB)
            #expect(weakCount == 2)
            #expect(weakFromA !== weakFromB)
        }

        @Test func graphScopeは親の型が違ってもalive中は同一インスタンス() {
            resetSharedResolver()

            final class CrossParentDep: AnyObject { let id = UUID() }
            final class HomeScreen { @Autowired var dep: CrossParentDep }
            final class SettingsScreen { @Autowired var dep: CrossParentDep }

            var factoryCount = 0
            DependencyResolver.shared.regist(CrossParentDep.self, scope: .graph) { _ in
                factoryCount += 1
                return CrossParentDep()
            }

            var home = HomeScreen()
            var settings = SettingsScreen()

            #expect(home.dep === settings.dep)
            #expect(factoryCount == 1)
        }

        @Test func 別親で前が解放済みならgraphもweakも別インスタンス() {
            resetSharedResolver()

            final class GraphDep: AnyObject { let id = UUID() }
            final class WeakDep: AnyObject { let id = UUID() }
            final class GraphFirstParent { @Autowired var dep: GraphDep }
            final class GraphSecondParent { @Autowired var dep: GraphDep }
            final class WeakFirstParent { @Autowired var dep: WeakDep }
            final class WeakSecondParent { @Autowired var dep: WeakDep }

            var graphCount = 0
            var weakCount = 0
            DependencyResolver.shared.regist(GraphDep.self, scope: .graph) { _ in
                graphCount += 1
                return GraphDep()
            }
            DependencyResolver.shared.regist(WeakDep.self, scope: .weak) { _ in
                weakCount += 1
                return WeakDep()
            }

            let firstGraphID: UUID
            do {
                var first = GraphFirstParent()
                firstGraphID = first.dep.id
            }

            var secondGraph = GraphSecondParent()
            let secondGraphID = secondGraph.dep.id

            let firstWeakID: UUID
            do {
                var first = WeakFirstParent()
                firstWeakID = first.dep.id
            }

            var secondWeak = WeakSecondParent()
            let secondWeakID = secondWeak.dep.id

            #expect(graphCount == 2)
            #expect(firstGraphID != secondGraphID)
            #expect(weakCount == 2)
            #expect(firstWeakID != secondWeakID)
        }

        @Test func autowiredGraphScopeは既存強参照があればweakキャッシュを再利用する() {
            resetSharedResolver()
            final class ReusableGraphService: AnyObject {
                let id = UUID()
            }
            final class ReusableHolder {
                @Autowired var service: ReusableGraphService
            }

            DependencyResolver.shared.regist(ReusableGraphService.self, scope: .graph) { _ in
                ReusableGraphService()
            }

            var keeper = ReusableHolder()
            let kept = keeper.service

            var another = ReusableHolder()
            let reused = another.service

            #expect(kept.id == reused.id)
        }

        @Test func autowiredGraphScopeは全Holder解放後は新インスタンスを生成する() {
            resetSharedResolver()
            final class EphemeralGraphService: AnyObject {
                let id = UUID()
            }
            final class EphemeralHolder {
                @Autowired var service: EphemeralGraphService
            }

            var factoryCount = 0
            DependencyResolver.shared.regist(EphemeralGraphService.self, scope: .graph) { _ in
                factoryCount += 1
                return EphemeralGraphService()
            }

            weak var weakRef: EphemeralGraphService?
            let firstID: UUID
            do {
                var holder = EphemeralHolder()
                let service = holder.service
                weakRef = service
                firstID = service.id
            }

            #expect(weakRef == nil)

            var newHolder = EphemeralHolder()
            let secondID = newHolder.service.id

            #expect(factoryCount == 2)
            #expect(firstID != secondID)
        }

        @Test func autowired遅延評価でも依存グラフ内で同一インスタンス() {
            resetSharedResolver()
            final class LazyGraphRepo: AnyObject {
                let id = UUID()
            }
            final class LazyGraphUseCase: AnyObject {
                @Autowired var repo: LazyGraphRepo
            }
            final class LazyGraphPresenter: AnyObject {
                @Autowired var useCase: LazyGraphUseCase
                @Autowired var repo: LazyGraphRepo
            }

            DependencyResolver.shared.regist(LazyGraphRepo.self, scope: .graph) { _ in LazyGraphRepo() }
            DependencyResolver.shared.regist(LazyGraphUseCase.self, scope: .graph) { _ in LazyGraphUseCase() }
            DependencyResolver.shared.regist(LazyGraphPresenter.self, scope: .graph) { _ in LazyGraphPresenter() }

            var presenter = LazyGraphPresenter()
            let viaUseCase = presenter.useCase.repo.id
            let direct = presenter.repo.id

            #expect(viaUseCase == direct)
        }

        /// README example: Presenter → @Autowired useCase (ProfileUseCase) → @Autowired repository
        @Test func readmeExample_ProfilePresenterAutowiredで菱形でもRepositoryは1つ() {
            resetSharedResolver()

            final class UserRepository: AnyObject {
                let id = UUID()
            }
            final class ProfileUseCase: AnyObject {
                @Autowired var repository: UserRepository
            }
            final class ProfilePresenter: AnyObject {
                @Autowired var useCase: ProfileUseCase
                @Autowired var repository: UserRepository
            }

            let repositoryFactoryCount = FactoryCallCounter()
            let useCaseFactoryCount = FactoryCallCounter()

            DependencyResolver.shared.regist(UserRepository.self, scope: .graph) { _ in
                repositoryFactoryCount.track { UserRepository() }
            }
            DependencyResolver.shared.regist(ProfileUseCase.self, scope: .graph) { _ in
                useCaseFactoryCount.track { ProfileUseCase() }
            }
            DependencyResolver.shared.regist(ProfilePresenter.self, scope: .graph) { _ in ProfilePresenter() }

            var presenter = ProfilePresenter()
            #expect(repositoryFactoryCount.count == 0)
            #expect(useCaseFactoryCount.count == 0)

            // Same expressions as README "Usage" section
            let viaUseCase = presenter.useCase.repository
            let direct = presenter.repository

            #expect(useCaseFactoryCount.count == 1)
            #expect(repositoryFactoryCount.count == 1)
            #expect(viaUseCase === direct)

            let useCaseAgain = presenter.useCase
            #expect(useCaseAgain.repository === viaUseCase)
            #expect(useCaseFactoryCount.count == 1)
            #expect(repositoryFactoryCount.count == 1)
        }
    }

    // MARK: - graph vs Factory Scope.shared 比較

    @Suite
    struct GraphVsFactorySharedTests {

        @Test func graphScopeはFactorySharedと同様に連続resolveで同一インスタンス() {
            final class SharedService: AnyObject {
                let id = UUID()
            }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            let simFirst = simulator.resolve(SharedService.self) { factoryCounter.track { SharedService() } }
            let simSecond = simulator.resolve(SharedService.self) { factoryCounter.track { SharedService() } }

            let resolver = DependencyResolver()
            let graphCounter = FactoryCallCounter()
            resolver.regist(SharedService.self, scope: .graph) { _ in graphCounter.track { SharedService() } }
            let graphFirst = resolver.resolve(SharedService.self)
            let graphSecond = resolver.resolve(SharedService.self)

            #expect(factoryCounter.count == 1)
            #expect(graphCounter.count == 1)
            #expect(simFirst === simSecond)
            #expect(graphFirst === graphSecond)
        }

        @Test func graphScopeはFactorySharedと同様にfactory内二重resolveで1インスタンス() {
            final class SharedDep: AnyObject { let id = UUID() }
            final class DualHolder: AnyObject {
                let first: SharedDep
                let second: SharedDep
                init(first: SharedDep, second: SharedDep) {
                    self.first = first
                    self.second = second
                }
            }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            let simHolder = DualHolder(
                first: simulator.resolve(SharedDep.self) { factoryCounter.track { SharedDep() } },
                second: simulator.resolve(SharedDep.self) { factoryCounter.track { SharedDep() } }
            )

            let resolver = DependencyResolver()
            let graphCounter = FactoryCallCounter()
            resolver.regist(SharedDep.self, scope: .graph) { _ in graphCounter.track { SharedDep() } }
            resolver.regist(DualHolder.self, scope: .graph) { r in
                DualHolder(
                    first: r.resolve(SharedDep.self),
                    second: r.resolve(SharedDep.self)
                )
            }
            let graphHolder = resolver.resolve(DualHolder.self)

            #expect(factoryCounter.count == 1)
            #expect(graphCounter.count == 1)
            #expect(simHolder.first === simHolder.second)
            #expect(graphHolder.first === graphHolder.second)
        }

        @Test func graphScopeはFactorySharedと同様に菱形依存で1インスタンス() {
            final class SharedLeaf: AnyObject { let id = UUID() }
            final class LeftArm: AnyObject {
                let leaf: SharedLeaf
                init(leaf: SharedLeaf) { self.leaf = leaf }
            }
            final class RightArm: AnyObject {
                let leaf: SharedLeaf
                init(leaf: SharedLeaf) { self.leaf = leaf }
            }
            final class Root: AnyObject {
                let left: LeftArm
                let right: RightArm
                init(left: LeftArm, right: RightArm) {
                    self.left = left
                    self.right = right
                }
            }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            let simRoot = Root(
                left: LeftArm(leaf: simulator.resolve(SharedLeaf.self) { factoryCounter.track { SharedLeaf() } }),
                right: RightArm(leaf: simulator.resolve(SharedLeaf.self) { factoryCounter.track { SharedLeaf() } })
            )

            let resolver = DependencyResolver()
            let graphCounter = FactoryCallCounter()
            resolver.regist(SharedLeaf.self, scope: .graph) { _ in graphCounter.track { SharedLeaf() } }
            resolver.regist(LeftArm.self, scope: .graph) { r in LeftArm(leaf: r.resolve(SharedLeaf.self)) }
            resolver.regist(RightArm.self, scope: .graph) { r in RightArm(leaf: r.resolve(SharedLeaf.self)) }
            resolver.regist(Root.self, scope: .graph) { r in
                Root(left: r.resolve(LeftArm.self), right: r.resolve(RightArm.self))
            }
            let graphRoot = resolver.resolve(Root.self)

            #expect(factoryCounter.count == 1)
            #expect(graphCounter.count == 1)
            #expect(simRoot.left.leaf === simRoot.right.leaf)
            #expect(graphRoot.left.leaf === graphRoot.right.leaf)
        }

        @Test func graphScopeはFactorySharedと同様に複数Consumerが同一インスタンスを共有() {
            resetSharedResolver()

            final class SharedRepo: AnyObject { let id = UUID() }
            final class ConsumerA: AnyObject {
                @Autowired var repo: SharedRepo
            }
            final class ConsumerB: AnyObject {
                @Autowired var repo: SharedRepo
            }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            var simA: SharedRepo?
            var simB: SharedRepo?
            do {
                simA = simulator.resolve(SharedRepo.self) { factoryCounter.track { SharedRepo() } }
                simB = simulator.resolve(SharedRepo.self) { factoryCounter.track { SharedRepo() } }
            }

            let graphCounter = FactoryCallCounter()
            DependencyResolver.shared.regist(SharedRepo.self, scope: .graph) { _ in
                graphCounter.track { SharedRepo() }
            }
            DependencyResolver.shared.regist(ConsumerA.self, scope: .graph) { _ in ConsumerA() }
            DependencyResolver.shared.regist(ConsumerB.self, scope: .graph) { _ in ConsumerB() }

            var consumerA = ConsumerA()
            var consumerB = ConsumerB()
            let graphA = consumerA.repo
            let graphB = consumerB.repo

            #expect(factoryCounter.count == 1)
            #expect(graphCounter.count == 1)
            #expect(simA === simB)
            #expect(graphA === graphB)
        }

        @Test func graphScopeはFactorySharedと同様に参照保持中は再resolveしても同一() {
            final class HeldService: AnyObject { let id = UUID() }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            let simHeld = simulator.resolve(HeldService.self) { factoryCounter.track { HeldService() } }
            let simAgain = simulator.resolve(HeldService.self) { factoryCounter.track { HeldService() } }

            let resolver = DependencyResolver()
            let graphCounter = FactoryCallCounter()
            resolver.regist(HeldService.self, scope: .graph) { _ in graphCounter.track { HeldService() } }
            let graphHeld = resolver.resolve(HeldService.self)
            let graphAgain = resolver.resolve(HeldService.self)

            #expect(simHeld === simAgain)
            #expect(graphHeld === graphAgain)
            #expect(factoryCounter.count == 1)
            #expect(graphCounter.count == 1)
        }

        @Test func graphScopeは参照解放後FactorySharedと挙動が異なる() {
            resetSharedResolver()

            final class ReleasedService: AnyObject { let id = UUID() }
            final class ReleasedHolder {
                @Autowired var service: ReleasedService
            }

            let factoryCounter = FactoryCallCounter()
            let simulator = FactorySharedScopeSimulator()
            weak var simWeak: ReleasedService?
            let simFirst = simulator.resolve(ReleasedService.self) { factoryCounter.track { ReleasedService() } }
            simWeak = simFirst
            let simSecond = simulator.resolve(ReleasedService.self) { factoryCounter.track { ReleasedService() } }

            let graphCounter = FactoryCallCounter()
            DependencyResolver.shared.regist(ReleasedService.self, scope: .graph) { _ in
                graphCounter.track { ReleasedService() }
            }

            weak var graphWeak: ReleasedService?
            let graphFirstID: UUID
            do {
                var holder = ReleasedHolder()
                let service = holder.service
                graphWeak = service
                graphFirstID = service.id
            }
            #expect(graphWeak == nil)

            var newHolder = ReleasedHolder()
            let graphSecondID = newHolder.service.id

            // Factory shared: コンテナが強参照保持 → 解放後も同一
            #expect(factoryCounter.count == 1)
            #expect(simFirst === simSecond)
            #expect(simWeak != nil)

            // graph: 全参照解放後は新インスタンス（Factory shared との意図的な差分）
            #expect(graphCounter.count == 2)
            #expect(graphFirstID != graphSecondID)
        }
    }

    // MARK: - graph スコープ：オブジェクト二重生成防止

    @Suite
    struct GraphDoubleObjectPreventionTests {

        @Test func graphScopeは同一factory内の二重resolveで1インスタンスのみ生成() {
            let resolver = DependencyResolver()
            let counter = FactoryCallCounter()

            final class SharedNode: AnyObject {
                let id = UUID()
            }
            final class DualConsumer: AnyObject {
                let first: SharedNode
                let second: SharedNode
                init(first: SharedNode, second: SharedNode) {
                    self.first = first
                    self.second = second
                }
            }

            resolver.regist(SharedNode.self, scope: .graph) { _ in
                counter.track { SharedNode() }
            }
            resolver.regist(DualConsumer.self, scope: .graph) { r in
                DualConsumer(
                    first: r.resolve(SharedNode.self),
                    second: r.resolve(SharedNode.self)
                )
            }

            let consumer = resolver.resolve(DualConsumer.self)

            #expect(counter.count == 1)
            #expect(consumer.first === consumer.second)
        }

        @Test func graphScopeは菱形依存でも共有インスタンスは1つ() {
            let resolver = DependencyResolver()
            let counter = FactoryCallCounter()

            final class SharedLeaf: AnyObject {
                let id = UUID()
            }
            final class LeftBranch: AnyObject {
                let leaf: SharedLeaf
                init(leaf: SharedLeaf) { self.leaf = leaf }
            }
            final class RightBranch: AnyObject {
                let leaf: SharedLeaf
                init(leaf: SharedLeaf) { self.leaf = leaf }
            }
            final class DiamondRoot: AnyObject {
                let left: LeftBranch
                let right: RightBranch
                init(left: LeftBranch, right: RightBranch) {
                    self.left = left
                    self.right = right
                }
            }

            resolver.regist(SharedLeaf.self, scope: .graph) { _ in counter.track { SharedLeaf() } }
            resolver.regist(LeftBranch.self, scope: .graph) { r in LeftBranch(leaf: r.resolve(SharedLeaf.self)) }
            resolver.regist(RightBranch.self, scope: .graph) { r in RightBranch(leaf: r.resolve(SharedLeaf.self)) }
            resolver.regist(DiamondRoot.self, scope: .graph) { r in
                DiamondRoot(
                    left: r.resolve(LeftBranch.self),
                    right: r.resolve(RightBranch.self)
                )
            }

            let root = resolver.resolve(DiamondRoot.self)

            #expect(counter.count == 1)
            #expect(root.left.leaf === root.right.leaf)
        }

        @Test func weakScopeは同一factory内の二重resolveで2インスタンス生成される() {
            let resolver = DependencyResolver()
            let counter = FactoryCallCounter()

            final class SharedNode: AnyObject {
                let id = UUID()
            }
            final class DualConsumer: AnyObject {
                let first: SharedNode
                let second: SharedNode
                init(first: SharedNode, second: SharedNode) {
                    self.first = first
                    self.second = second
                }
            }

            resolver.regist(SharedNode.self, scope: .weak) { _ in counter.track { SharedNode() } }
            resolver.regist(DualConsumer.self, scope: .graph) { r in
                DualConsumer(
                    first: r.resolve(SharedNode.self),
                    second: r.resolve(SharedNode.self)
                )
            }

            let consumer = resolver.resolve(DualConsumer.self)

            #expect(counter.count == 2)
            #expect(consumer.first !== consumer.second)
        }

        @Test func autowiredGraphScopeは同一画面内の複数ConsumerでRepoが1つ() {
            resetSharedResolver()
            final class ScreenSharedRepo: AnyObject {
                let id = UUID()
            }
            final class ScreenConsumerA: AnyObject {
                @Autowired var repo: ScreenSharedRepo
            }
            final class ScreenConsumerB: AnyObject {
                @Autowired var repo: ScreenSharedRepo
            }
            final class ScreenRoot: AnyObject {
                @Autowired var consumerA: ScreenConsumerA
                @Autowired var consumerB: ScreenConsumerB
            }

            let counter = FactoryCallCounter()
            DependencyResolver.shared.regist(ScreenSharedRepo.self, scope: .graph) { _ in
                counter.track { ScreenSharedRepo() }
            }
            DependencyResolver.shared.regist(ScreenConsumerA.self, scope: .graph) { _ in ScreenConsumerA() }
            DependencyResolver.shared.regist(ScreenConsumerB.self, scope: .graph) { _ in ScreenConsumerB() }
            DependencyResolver.shared.regist(ScreenRoot.self, scope: .graph) { _ in ScreenRoot() }

            var screen = ScreenRoot()
            let repoA = screen.consumerA.repo
            let repoB = screen.consumerB.repo

            #expect(counter.count == 1)
            #expect(repoA === repoB)
        }

        @Test func autowiredGraphScopeは直接参照と間接参照でRepoが1つ() {
            resetSharedResolver()
            final class PathSharedRepo: AnyObject {
                let id = UUID()
            }
            final class PathUseCase: AnyObject {
                @Autowired var repo: PathSharedRepo
            }
            final class PathPresenter: AnyObject {
                @Autowired var useCase: PathUseCase
                @Autowired var repo: PathSharedRepo
            }

            let counter = FactoryCallCounter()
            DependencyResolver.shared.regist(PathSharedRepo.self, scope: .graph) { _ in
                counter.track { PathSharedRepo() }
            }
            DependencyResolver.shared.regist(PathUseCase.self, scope: .graph) { _ in PathUseCase() }
            DependencyResolver.shared.regist(PathPresenter.self, scope: .graph) { _ in PathPresenter() }

            var presenter = PathPresenter()
            let viaUseCase = presenter.useCase.repo
            let direct = presenter.repo

            #expect(counter.count == 1)
            #expect(viaUseCase === direct)
        }

        @Test func autowiredGraphScopeはアクセス順序が違ってもRepoが1つ() {
            resetSharedResolver()
            final class OrderSharedRepo: AnyObject {
                let id = UUID()
            }
            final class OrderUseCase: AnyObject {
                @Autowired var repo: OrderSharedRepo
            }
            final class OrderPresenter: AnyObject {
                @Autowired var useCase: OrderUseCase
                @Autowired var repo: OrderSharedRepo
            }

            let counter = FactoryCallCounter()
            DependencyResolver.shared.regist(OrderSharedRepo.self, scope: .graph) { _ in
                counter.track { OrderSharedRepo() }
            }
            DependencyResolver.shared.regist(OrderUseCase.self, scope: .graph) { _ in OrderUseCase() }
            DependencyResolver.shared.regist(OrderPresenter.self, scope: .graph) { _ in OrderPresenter() }

            var presenter2 = OrderPresenter()
            let directFirst = presenter2.repo
            let indirectSecond = presenter2.useCase.repo

            #expect(counter.count == 1)
            #expect(directFirst === indirectSecond)
        }

        @Test func autowiredGraphScopeは3経路の参照でも1インスタンス() {
            resetSharedResolver()
            final class TripleShared: AnyObject {
                let id = UUID()
            }
            final class TripleA: AnyObject {
                @Autowired var shared: TripleShared
            }
            final class TripleB: AnyObject {
                @Autowired var shared: TripleShared
            }
            final class TripleRoot: AnyObject {
                @Autowired var a: TripleA
                @Autowired var b: TripleB
                @Autowired var shared: TripleShared
            }

            let counter = FactoryCallCounter()
            DependencyResolver.shared.regist(TripleShared.self, scope: .graph) { _ in
                counter.track { TripleShared() }
            }
            DependencyResolver.shared.regist(TripleA.self, scope: .graph) { _ in TripleA() }
            DependencyResolver.shared.regist(TripleB.self, scope: .graph) { _ in TripleB() }
            DependencyResolver.shared.regist(TripleRoot.self, scope: .graph) { _ in TripleRoot() }

            var root = TripleRoot()
            let idA = root.a.shared.id
            let idB = root.b.shared.id
            let idDirect = root.shared.id

            #expect(counter.count == 1)
            #expect(idA == idB)
            #expect(idB == idDirect)
        }
    }

    // MARK: - graph キャッシュ検証（公開 API の振る舞いのみ）

    @Suite
    struct GraphCacheTests {

        @Test func graphScopeは連続resolveで同一インスタンスを返す() {
            let resolver = DependencyResolver()
            let counter = FactoryCallCounter()

            final class ActiveCacheTarget: AnyObject {
                let id = UUID()
            }

            resolver.regist(ActiveCacheTarget.self, scope: .graph) { _ in
                counter.track { ActiveCacheTarget() }
            }

            let first = resolver.resolve(ActiveCacheTarget.self)
            let second = resolver.resolve(ActiveCacheTarget.self)

            #expect(counter.count == 1)
            #expect(first === second)
        }

        @Test func graphScopeはresolve連鎖中も1インスタンスのみ生成() {
            let resolver = DependencyResolver()
            let counter = FactoryCallCounter()

            final class ChainNode: AnyObject { let id = UUID() }
            final class ChainParent: AnyObject {
                let left: ChainNode
                let right: ChainNode
                init(left: ChainNode, right: ChainNode) {
                    self.left = left
                    self.right = right
                }
            }

            resolver.regist(ChainNode.self, scope: .graph) { _ in counter.track { ChainNode() } }
            resolver.regist(ChainParent.self, scope: .graph) { r in
                ChainParent(
                    left: r.resolve(ChainNode.self),
                    right: r.resolve(ChainNode.self)
                )
            }

            let parent = resolver.resolve(ChainParent.self)

            #expect(counter.count == 1)
            #expect(parent.left === parent.right)
        }

        @Test func graphScopeはAutowired後も別Holderで同一インスタンスを再利用() {
            resetSharedResolver()
            let counter = FactoryCallCounter()

            final class WeakCacheTarget: AnyObject { let id = UUID() }
            final class WeakCacheHolderA {
                @Autowired var target: WeakCacheTarget
            }
            final class WeakCacheHolderB {
                @Autowired var target: WeakCacheTarget
            }

            DependencyResolver.shared.regist(WeakCacheTarget.self, scope: .graph) { _ in
                counter.track { WeakCacheTarget() }
            }

            var holderA = WeakCacheHolderA()
            let fromA = holderA.target

            var holderB = WeakCacheHolderB()
            let fromB = holderB.target

            #expect(counter.count == 1)
            #expect(fromA === fromB)
        }

        @Test func graphScopeは強参照が残る間は再生成しない() {
            resetSharedResolver()
            let counter = FactoryCallCounter()

            final class KeptTarget: AnyObject { let id = UUID() }
            final class KeeperHolder {
                @Autowired var target: KeptTarget
            }
            final class LatecomerHolder {
                @Autowired var target: KeptTarget
            }

            DependencyResolver.shared.regist(KeptTarget.self, scope: .graph) { _ in
                counter.track { KeptTarget() }
            }

            var keeper = KeeperHolder()
            let kept = keeper.target

            var latecomer = LatecomerHolder()
            let reused = latecomer.target

            #expect(counter.count == 1)
            #expect(kept === reused)
        }

        @Test func graphScopeは全参照解放後は新インスタンスを生成() {
            resetSharedResolver()
            let counter = FactoryCallCounter()

            final class DeadTarget: AnyObject { let id = UUID() }
            final class DeadHolder {
                @Autowired var target: DeadTarget
            }

            DependencyResolver.shared.regist(DeadTarget.self, scope: .graph) { _ in
                counter.track { DeadTarget() }
            }

            weak var weakRef: DeadTarget?
            let firstID: UUID
            do {
                var holder = DeadHolder()
                let target = holder.target
                weakRef = target
                firstID = target.id
            }

            #expect(weakRef == nil)

            var newHolder = DeadHolder()
            let secondID = newHolder.target.id

            #expect(counter.count == 2)
            #expect(firstID != secondID)
        }

        @Test func graphScopeは2回目のアクセスでもfactoryは1回のみ() {
            resetSharedResolver()
            let counter = FactoryCallCounter()

            final class LayerTarget: AnyObject { let id = UUID() }
            final class LayerHolder {
                @Autowired var target: LayerTarget
            }

            DependencyResolver.shared.regist(LayerTarget.self, scope: .graph) { _ in
                counter.track { LayerTarget() }
            }

            var holder1 = LayerHolder()
            let first = holder1.target

            var holder2 = LayerHolder()
            let second = holder2.target

            #expect(counter.count == 1)
            #expect(first === second)
        }
    }
}
// MARK: - テスト用型

protocol GreeterProtocol: AnyObject {
    var name: String { get }
}

final class Greeter: GreeterProtocol {
    let name: String
    init(name: String) { self.name = name }
}

final class GreeterRepository {
    let id = UUID()
}

final class GreeterViewModel {
    let repository: GreeterRepository
    init(repository: GreeterRepository) { self.repository = repository }
}

final class NetworkClient {
    let id = UUID()
}

final class AuthService {
    let client: NetworkClient
    init(client: NetworkClient) { self.client = client }
}

final class DashboardViewModel {
    let auth: AuthService
    let repo: GreeterRepository
    init(auth: AuthService, repo: GreeterRepository) {
        self.auth = auth
        self.repo = repo
    }
}
