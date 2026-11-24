-- SPDX-License-Identifier: BSD-3-Clause

module Main (main) where

import Data.List (sort)
import Data.Maybe (mapMaybe)
import qualified Data.Text as T
import SimpleCmd (error', (+-+))
import SimpleCmdArgs
import System.Environment (lookupEnv)

import Gitea.Forgejo (RepoIssueOptions(..), fedoraForge,
                      listOrgRepos, listRepoIssues, listUserRepos,
                      Issue(issueNumber, issueTitle),
                      Repository(repositoryFullName, repositoryName))
import Paths_forgejo (version)

main :: IO ()
main =
  simpleCmdArgs (Just version) "Forgejo client" "Simple forgejo CLI" $
  subcommands
  [ Subcommand "repos" "list org's repos" $
    listOrgReposCmd
    <$> serviceOpt
    <*> switchLongWith "full" "Print full name"
    <*> strArg "ORG"
  , Subcommand "user-repos" "list repositories associated with a user" $
    listUserReposCmd
    <$> serviceOpt
    <*> strArg "USER"
  , Subcommand "issues" "list repo issues" $
    repoIssuesCmd
    <$> serviceOpt
    <*> optional (strOptionLongWith "created-by" "USER" "Only issues created by USER")
    <*> optional (optionLongWith (eitherReader parseIssueState) "state" "STATE" "open, closed, or all")
    <*> strArg "OWNER/REPO"
  ]
  where
    serviceOpt = strOptionalWith 's' "server" "URL" ("Forgejo server" +-+ "[default:" +-+ fedoraForge ++ "]") fedoraForge

listOrgReposCmd :: String -> Bool -> String -> IO ()
listOrgReposCmd url full org = do
  erepos <- listOrgRepos url org
  case erepos of
    Left err -> error' err
    Right repos ->
      mapM_ (printRepo . T.unpack) . sort $
      mapMaybe repositoryName repos
  where
    printRepo repo =
      putStrLn $ (if full then org ++ "/" else "") ++ repo

listUserReposCmd :: String -> String -> IO ()
listUserReposCmd url username = do
  mtoken <- lookupEnv "FORGEJO_TOKEN"
  erepos <- listUserRepos url mtoken username
  case erepos of
    Left err -> error' err
    Right repos -> mapM_ (putStrLn . T.unpack) $ sort (mapMaybe repositoryFullName repos)

repoIssuesCmd :: String -> Maybe String -> Maybe String -> String
              -> IO ()
repoIssuesCmd url createdBy state repoPath =
  case break (== '/') repoPath of
    (owner, '/':repo) | not (null owner) && not (null repo) && '/' `notElem` repo -> do
      let options = RepoIssueOptions createdBy state
      eissues <- listRepoIssues url owner repo options
      case eissues of
        Left err -> error' err
        Right issues ->
          mapM_ printIssue . sort $ mapMaybe issueSummary issues
    _ -> fail "Expected repository in OWNER/REPO form"
  where
    issueSummary issue =
      (,) <$> issueNumber issue <*> issueTitle issue
    printIssue (number, title) =
      putStrLn $ "#" ++ show number ++ " " ++ T.unpack title

parseIssueState :: String -> Either String String
parseIssueState s =
  if s `elem` ["open","closed","all"]
  then Right s
  else Left "STATE must be open, closed, or all"
