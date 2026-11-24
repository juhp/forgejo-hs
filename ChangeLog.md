# forgejo releases

## 0.2.0 (2026-11-24)
- rename executable to forgejo-tool
- rename "repos" command to "org-repos"
- add "user-repos" command with `listUserRepos` API
- add "users" command with `searchUsers` API
- add "user" command with `getUser` API
- [breaking] `listOrgRepos` and `listRepoIssues` now take an optional token
- paginate `listOrgRepos` and `listRepoIssues`
- use getGlobalManager

## 0.1.0 (2026-11-23)
- inital release with `listOrgRepos` and `listRepoIssues`
- also corresponding CLI
