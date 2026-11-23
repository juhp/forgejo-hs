# forgejo

A simple Haskell library and query cli for gitea/forgejo forges built
on top of [gitea-api](https://hackage.haskell.org/package/gitea-api).

Currently only has two functions:

- `listOrgRepos`
- `listRepoIssues`

and corresponding CLI tool.

The package is distributed under a BSD3 license.

## CLI tool

`$ forgejo --version`

```
0.1.0
```

`$ forgejo --help`

```
Forgejo client

Usage: forgejo [--version] COMMAND

  Simple forgejo CLI

Available options:
  -h,--help                Show this help text
  --version                Show version

Available commands:
  repos                    list org's repos
  issues                   list repo issues
```
