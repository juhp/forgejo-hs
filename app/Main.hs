-- SPDX-License-Identifier: BSD-3-Clause

module Main (main) where

import Data.List (sort)
import Data.Maybe (catMaybes, mapMaybe)
import qualified Data.Text as T
import SimpleCmd (error', (+-+))
import SimpleCmdArgs
import System.Environment (lookupEnv)

import Gitea.Forgejo (RepoIssueOptions(..), fedoraForge, getUser,
                      listOrgRepos, listRepoIssues, listUserRepos, searchUsers,
                      Issue(issueNumber, issueTitle),
                      Repository(repositoryFullName, repositoryName),
                      User(userFullName, userHtmlUrl, userLogin))
import Paths_forgejo (version)

main :: IO ()
main =
  simpleCmdArgs (Just version) "Forgejo client" "Simple forgejo CLI" $
  subcommands
  [ Subcommand "org-repos" "list org's repos" $
    listOrgReposCmd
    <$> serviceOpt
    <*> switchLongWith "full" "Print full name"
    <*> strArg "ORG"
  , Subcommand "users" "search for users by keyword" $
    searchUsersCmd
    <$> serviceOpt
    <*> strArg "SUBSTR"
  , Subcommand "user" "show a user's profile" $
    getUserCmd
    <$> serviceOpt
    <*> strArg "USER"
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
  mtoken <- lookupEnv "FORGEJO_TOKEN"
  erepos <- listOrgRepos url mtoken org
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

searchUsersCmd :: String -> String -> IO ()
searchUsersCmd url keyword = do
  mtoken <- lookupEnv "FORGEJO_TOKEN"
  eusers <- searchUsers url mtoken keyword
  case eusers of
    Left err -> error' err
    Right users -> mapM_ (putStrLn . T.unpack) $ sort (mapMaybe userLogin users)

getUserCmd :: String -> String -> IO ()
getUserCmd url username = do
  mtoken <- lookupEnv "FORGEJO_TOKEN"
  result <- getUser url mtoken username
  case result of
    Left err -> error' err
    Right user ->
      case userLogin user of
        Just login | not (T.null login) -> do
          let fields = login : catMaybes [userFullName user, userHtmlUrl user]
          mapM_ (putStrLn . T.unpack) (filter (not . T.null) fields)
        _ -> error' ("Missing username in profile for " ++ username)

repoIssuesCmd :: String -> Maybe String -> Maybe String -> String -> IO ()
repoIssuesCmd url createdBy state repoPath =
  case break (== '/') repoPath of
    (owner, '/':repo) | not (null owner) && not (null repo) && '/' `notElem` repo -> do
      let options = RepoIssueOptions createdBy state
      mtoken <- lookupEnv "FORGEJO_TOKEN"
      eissues <- listRepoIssues url mtoken owner repo options
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
