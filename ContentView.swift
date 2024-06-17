import SwiftUI

struct ContentView: View {
    @State private var username = ""
    @State private var repositories: [Repository] = []
    @State private var isLoading = false
    @State private var selectedRepository: Repository?
    @State private var readmeContent = ""
    @State private var readmeError = false
    @State private var currentPage = 1
    @State private var hasMorePages = true

    var body: some View {
        VStack {
            TextField("Enter GitHub username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Fetch Repositories") {
                repositories = []
                currentPage = 1
                hasMorePages = true
                fetchRepositories(forUser: username)
            }
            .padding()

            if isLoading {
                ProgressView("Loading...")
                    .padding()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(repositories, id: \.id) { repo in
                        VStack(alignment: .leading) {
                            Text(repo.name)
                                .font(.headline)
                                .padding(.bottom, 2)
                            Text("⭐ \(repo.stargazers_count) | 🍴 \(repo.forks_count)")
                                .font(.subheadline)
                                .padding(.bottom, 2)
                            Text(repo.description ?? "No description")
                                .font(.body)
                                .padding(.bottom, 10)
                        }
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedRepository = repo
                            fetchReadme(for: repo)
                        }
                    }

                    if hasMorePages {
                        Button("Load More") {
                            currentPage += 1
                            fetchRepositories(forUser: username)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .background(Color.black)
            .cornerRadius(10)
        }
        .padding()
        .sheet(item: $selectedRepository) { repo in
            RepositoryDetailView(repository: repo, readmeContent: readmeContent, readmeError: readmeError)
        }
    }

    func fetchRepositories(forUser username: String) {
        guard !username.isEmpty, let url = URL(string: "https://api.github.com/users/\(username)/repos?page=\(currentPage)") else {
            print("Invalid URL or username")
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching repositories: \(error?.localizedDescription ?? "Unknown error")")
                isLoading = false
                return
            }

            do {
                let jsonArray = try JSONDecoder().decode([Repository].self, from: data)
                DispatchQueue.main.async {
                    self.repositories.append(contentsOf: jsonArray)
                    self.isLoading = false
                    self.hasMorePages = !jsonArray.isEmpty
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }

    func fetchReadme(for repository: Repository) {
        guard let url = URL(string: "https://api.github.com/repos/\(repository.owner.login)/\(repository.name)/readme") else {
            print("Invalid URL")
            return
        }

        readmeError = false
        readmeContent = ""

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching README: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.readmeError = true
                }
                return
            }

            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let content = jsonResponse?["content"] as? String {
                    if let decodedData = Data(base64Encoded: content),
                       let readme = String(data: decodedData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.readmeContent = readme
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.readmeError = true
                    }
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.readmeError = true
                }
            }
        }.resume()
    }
}

struct Repository: Identifiable, Decodable {
    let id: Int
    let name: String
    let description: String?
    let stargazers_count: Int
    let forks_count: Int
    let owner: Owner
    let html_url: String
}

struct Owner: Decodable {
    let login: String
}

struct RepositoryDetailView: View {
    var repository: Repository
    var readmeContent: String
    var readmeError: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(repository.name)
                .font(.largeTitle)
                .padding(.bottom, 10)

            if let description = repository.description {
                Text(description)
                    .padding(.bottom, 10)
            }

            Link("View on GitHub", destination: URL(string: repository.html_url)!)
                .padding()

            ScrollView {
                if readmeError {
                    Text("README not available")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text(readmeContent)
                        .padding()
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}