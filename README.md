# forgejo

A simple Haskell library and query cli for gitea/forgejo forges built
on top of [gitea-api](https://hackage.haskell.org/package/gitea-api).

The library provides these queries.

- `listOrgRepos`
- `listUserRepos`
- `searchUsers`
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
  user-repos               list repositories associated with a user
  issues                   list repo issues
```

Use `--server https://forgejo.example.org/api/v1` to query another instance.
To authenticate, set `FORGEJO_TOKEN` to a personal access token for that instance.
On Forgejo, the commands use these token scopes.

| Command | Token scopes |
| --- | --- |
| `org-repos` | `read:organization` |
| `issues` | `read:issue` |
| `users` | `read:user` |
| `user-repos` | `read:user`, `read:repository` |

`forgejo-tool user-repos USER` lists repositories associated with a user as
`owner/repo`, including repositories they own and those Forgejo includes
through collaboration or organization membership.
The command fetches every page of results visible to the caller.

`forgejo-tool users SUBSTR` searches for users by substring and prints their
usernames in sorted order. The server can match usernames and display names.
