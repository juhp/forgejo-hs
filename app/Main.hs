-- SPDX-License-Identifier: BSD-3-Clause

module Main (main) where

import Data.List (sort)
import Data.Maybe (mapMaybe)
import qualified Data.Text as T
import SimpleCmdArgs

import Gitea.Forgejo (RepoIssueOptions(..), fedoraForge,
                listOrgRepos, listRepoIssues,
                repositoryName, issueNumber, issueTitle)
import Paths_forgejo (version)

main :: IO ()
main =
  simpleCmdArgs (Just version) "Pagure client" "Simple pagure CLI" $
  subcommands
  [ Subcommand "repos" "list org's repos" $
    listOrgReposCmd
    <$> switchLongWith "full" "Print full name"
    <*> strArg "ORG"
  , Subcommand "issues" "list repo issues" $
    repoIssuesCmd
    <$> optional (strOptionLongWith "created-by" "USER" "Only issues created by USER")
    <*> optional (optionLongWith (eitherReader parseIssueState) "state" "STATE" "open, closed, or all")
    <*> strArg "OWNER/REPO"
  ]

listOrgReposCmd :: Bool -> String -> IO ()
listOrgReposCmd full org = do
  repos <- listOrgRepos fedoraForge org
  mapM_ (printRepo . T.unpack) . sort $
    mapMaybe repositoryName repos
  where
    printRepo repo =
      putStrLn $ (if full then org ++ "/" else "") ++ repo

repoIssuesCmd :: Maybe String -> Maybe String -> String -> IO ()
repoIssuesCmd createdBy state repoPath =
  case break (== '/') repoPath of
    (owner, '/':repo) | not (null owner) && not (null repo) && '/' `notElem` repo -> do
      let options = RepoIssueOptions createdBy state
      issues <- listRepoIssues fedoraForge owner repo options
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
