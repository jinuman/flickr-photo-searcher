//
//  MoyaNetworkingManager.swift
//  PhotoSearcher
//
//  Created by Jinwoo Kim on 2021/02/16.
//

import Alamofire
import Moya

import RxSwift

protocol MoyaNetworkingServiceProtocol {
    associatedtype Target: BaseTargetType

    func request(
        _ target: Target,
        callbackQueue: DispatchQueue?,
        progress: Moya.ProgressBlock?,
        completion: @escaping Moya.Completion
    ) -> Cancellable
}

struct MoyaNetworkingManager<Target: BaseTargetType>: MoyaNetworkingServiceProtocol {

    typealias Provider = MoyaProvider<Target>
    typealias EndpointClosure = Provider.EndpointClosure
    typealias RequestClosure = Provider.RequestClosure
    typealias StubClosure = Provider.StubClosure

    private let provider: MoyaProvider<Target>

    init(
        endpointClosure: @escaping EndpointClosure = Provider.defaultEndpointMapping,
        requestClosure: @escaping RequestClosure = Provider.defaultRequestMapping,
        stubClosure: @escaping StubClosure = Provider.neverStub,
        callbackQueue: DispatchQueue? = nil,
        session: Session = Self.makeSession(),
        trackInflights: Bool = false,
        plugins: [PluginType] = [NetworkingErrorHandlingPlugin(), NetworkingLoggingPlugin()]
    ) {
        self.provider = Provider(
            endpointClosure: endpointClosure,
            requestClosure: requestClosure,
            stubClosure: stubClosure,
            callbackQueue: callbackQueue,
            session: session,
            plugins: plugins,
            trackInflights: trackInflights
        )
    }

    func request(
        _ target: Target,
        callbackQueue: DispatchQueue?,
        progress: ProgressBlock?,
        completion: @escaping Completion
    ) -> Cancellable {
        return self.provider.request(
            target,
            callbackQueue: callbackQueue,
            progress: progress,
            completion: completion
        )
    }

    private static func makeSession(retryLimit: UInt = 1) -> Session {
        let retryPolicy = RetryPolicy(retryLimit: retryLimit)

        return Session(
            configuration: URLSessionConfiguration.default,
            startRequestsImmediately: false,
            interceptor: retryPolicy
        )
    }
}

extension MoyaNetworkingManager: ReactiveCompatible {}

extension Reactive where Base: MoyaNetworkingServiceProtocol {
    func request(
        _ token: Base.Target,
        callbackQueue: DispatchQueue? = nil
    ) -> Single<Response> {
        return Single.create { single in
            let cancellableToken = self.base.request(
                token,
                callbackQueue: callbackQueue,
                progress: nil
            ) { result in
                switch result {
                case let .success(response):
                    print(result, "success")
                    single(.success(response))
                case let .failure(error):
                    print(result)
                    single(.error(error))
                }
            }
            return Disposables.create {
                cancellableToken.cancel()
            }
        }
    }
}