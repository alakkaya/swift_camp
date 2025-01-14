import Foundation
import UIKit
import Combine


final class HomeInteractor: HomeInteractorInterface {
    // MARK: - Properties
    
    /// Base URL fetched dynamically from the environment configuration (EnvironmentHelper)
    private let baseURL = EnvironmentHelper.shared.githubRepoApi
    private let batteryHelper = BatteryHelper.shared
    private var subscriptions = Set<AnyCancellable>()
    weak var presenter: HomePresenterInterface?
    
    
    // MARK: - Public Interface
    
    /// Fetches repository information including commit count, closed pull requests, branch count, and contributors.
    /// - Parameter completion: Completion handler returning a `GithubRepoInfo` object containing repository details.
    func fetchRepoInfo(completion: @escaping (GithubRepoInfo) -> Void) {
        var repoInfo = GithubRepoInfo(commitCount: 0, closedPRCount: 0, branchCount: 0, contributors: [])
        let group = DispatchGroup()
        
        // Fetch commits
        group.enter()
        fetchPaginatedData(endpoint: "commits", collection: [Commit]()) { commits in
            repoInfo.commitCount = commits.count
            group.leave()
        }
        
        // Fetch closed pull requests
        group.enter()
        fetchPaginatedData(endpoint: "pulls", collection: [PullRequest]()) { pulls in
            repoInfo.closedPRCount = pulls.count
            group.leave()
        }
        
        // Fetch branches
        group.enter()
        fetchGenericData(from: "\(baseURL)/branches") { (branches: [Branch]) in
            repoInfo.branchCount = branches.count
            group.leave()
        }
        
        // Fetch contributors
        group.enter()
        fetchGenericData(from: "\(baseURL)/contributors") { (contributors: [Contributor]) in
            repoInfo.contributors = contributors
            group.leave()
        }
        
        // Notify completion when all requests are finished
        group.notify(queue: .main) {
            completion(repoInfo)
        }
    }
    
    // MARK: - Time Helper
    
    /// Manages the scheduled timer for updating date and time.
    private var timer: Timer?
    
    /// The current date and time string.
    private var currentDateTime: String = ""
    
    /// Starts updating the current date and time.
    func startUpdatingDateTime() {
        updateDateTime() // Initial update
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDateTime()
        }
    }
    
    /// Stops updating the current date and time.
    func stopUpdatingDateTime() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Returns the current date and time as a string.
    /// - Returns: The current date and time in the format `yyyy-MM-dd HH:mm:ss`.
    func getCurrentDateTime() -> String {
        return currentDateTime
    }
    
    /// Updates the current date and time string.
    private func updateDateTime() {
        currentDateTime = TimeHelper.shared.getCurrentDateTime(format: "yyyy-MM-dd HH:mm:ss")
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetches paginated data from a given endpoint, handling multiple pages of results.
    /// - Parameters:
    ///   - endpoint: The API endpoint to fetch data from (e.g., "commits").
    ///   - perPage: The number of results per page (default is 100).
    ///   - collection: The collection to append fetched data to.
    ///   - page: The current page to fetch (default is 1).
    ///   - completion: Completion handler returning the aggregated collection of decoded data.
    private func fetchPaginatedData<T: Decodable>(
        endpoint: String,
        perPage: Int = 100,
        collection: [T] = [],
        page: Int = 1,
        completion: @escaping ([T]) -> Void
    ) {
        let url = endpoint == "pulls"
        ? "\(baseURL)/\(endpoint)?state=closed&per_page=\(perPage)&page=\(page)"
        : "\(baseURL)/\(endpoint)?per_page=\(perPage)&page=\(page)"
        
        fetchGenericData(from: url) { (items: [T]) in
            var updatedCollection = collection
            updatedCollection.append(contentsOf: items)
            
            if items.count == perPage {
                self.fetchPaginatedData(
                    endpoint: endpoint,
                    perPage: perPage,
                    collection: updatedCollection,
                    page: page + 1,
                    completion: completion
                )
            } else {
                completion(updatedCollection)
            }
        }
    }
    
    /// Fetches generic data from a URL and decodes it into the specified type.
    /// - Parameters:
    ///   - urlString: The URL string to fetch data from.
    ///   - completion: Completion handler returning the decoded data.
    private func fetchGenericData<T: Decodable>(
        from urlString: String,
        completion: @escaping (T) -> Void
    ) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            do {
                let decodedData = try JSONDecoder().decode(T.self, from: data)
                completion(decodedData)
            } catch {
                print("Failed to decode data from \(urlString): \(error)")
            }
        }.resume()
    }
    
    // MARK: - Battery Information Fetching

    /// Fetches the battery information from BatteryHelper and passes it to the presenter.
    /// - This method retrieves the current battery level, state description, and color
    ///   from the `BatteryHelper` instance, which is then sent to the presenter to update the UI.
    /// - The presenter will receive the battery level, state description, and the color
    ///   for the battery state which are all `@Published` properties in `BatteryHelper`.
    func fetchBatteryInfo() {
        // BatteryHelper artık @Published özelliklerle SwiftUI tarafından dinleniyor.
        presenter?.didFetchBatteryInfo(
            level: BatteryHelper.shared.batteryLevel,
            stateDescription: BatteryHelper.shared.batteryStateDescription,
            color: BatteryHelper.shared.batteryColor
        )
    }

    /// Starts battery monitoring by observing changes in BatteryHelper.
    /// - This method starts observing changes to the `BatteryHelper`'s `@Published` properties
    ///   such as `batteryLevel`, `batteryStateDescription`, and `batteryColor`.
    /// - When these values change, the method passes the updated values to the presenter
    ///   to keep the UI in sync with the battery status.
    /// - Monitoring is done using Combine's `objectWillChange` publisher.
    func startBatteryMonitoring() {
        stopBatteryMonitoring() // Stop any existing monitoring before starting a new one.

        // BatteryHelper'ı SwiftUI veya Combine aracılığıyla dinliyoruz.
        BatteryHelper.shared.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    // Presenter'a BatteryHelper'dan gelen değerleri ilet
                    self?.presenter?.didFetchBatteryInfo(
                        level: BatteryHelper.shared.batteryLevel,
                        stateDescription: BatteryHelper.shared.batteryStateDescription,
                        color: BatteryHelper.shared.batteryColor
                    )
                }
            }
            .store(in: &subscriptions) // Store the subscription to prevent it from being deallocated.
    }

    /// Stops battery monitoring by clearing all active subscriptions.
    /// - This method removes all stored subscriptions, halting the monitoring of changes
    ///   to the `BatteryHelper`'s published properties.
    /// - It helps avoid memory leaks by ensuring that any active subscriptions are
    ///   properly cancelled when monitoring is no longer needed.
    func stopBatteryMonitoring() {
        subscriptions.removeAll() // Clear all subscriptions to stop monitoring.
    }
}
