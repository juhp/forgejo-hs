# forgejo

A simple Haskell library and query cli for gitea/forgejo forges built
on top of [gitea-api](https://hackage.haskell.org/package/gitea-api).

The library currently provides these queries:

- `listOrgRepos`
- `listUserRepos`
- `searchUsers`
- `getUser`
- `listRepoIssues`

The package is distributed under a BSD3 license.

## CLI tool

`$ forgejo-tool --version`

```
0.2.0
```

`$ forgejo-tool --help`

```
Forgejo client

Usage: forgejo-tool [--version] COMMAND

  Simple forgejo CLI

Available options:
  -h,--help                Show this help text
  --version                Show version

Available commands:
  org-repos                list org's repos
  users                    search for users by keyword
  user                     show a user's profile
  user-repos               list repositories associated with a user
  issues                   list repo issues
```

Use `--server https://forgejo.example.org/api/v1` to query another instance.
To authenticate, set `FORGEJO_TOKEN` to a personal access token for that instance.
On Forgejo, the commands use these token scopes:

| Command | Token scopes |
| --- | --- |
| `org-repos` | `read:organization` |
| `issues` | `read:issue` |
| `users`, `user` | `read:user` |
| `user-repos` | `read:user`, `read:repository` |

`forgejo-tool org-repos ORG` lists the repos in an organization.

`forgejo-tool issues OWNER/REPO` lists the visible issues in a repository.

`forgejo-tool user-repos USER` lists repositories associated with a user as
`owner/repo`, including repositories they own and those included
through collaboration or organization membership.

`forgejo-tool users SUBSTR` searches for users by substring and prints their
usernames in sorted order. The server can match usernames and display names.

`forgejo-tool user USER` looks up an exact username and prints the username,
followed by the display name and profile URL on separate lines when available.

The commands fetch every page of results visible to the caller.
In future it is planned to have an option to limit the number of results.
