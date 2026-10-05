module Gitea.Forgejo (
  listOrgRepos,
  listRepoIssues,
  RepoIssueOptions(..),
  defaultRepoIssueOptions,
  fedoraForge,
  Repository(..),
  Issue(..),
  Label(..)
  )
where

import qualified Data.ByteString.Lazy.Char8 as B
import Data.Char (toLower)
import qualified Data.Text as T
import Gitea
import Network.HTTP.Client.TLS

fedoraForge :: B.ByteString
fedoraForge = B.pack "https://forge.fedoraproject.org/api/v1"

listOrgRepos :: B.ByteString -> String -> IO [Repository]
listOrgRepos url org = do
  let req = orgListRepos (Org $ T.pack org)
  mgr <- newTlsManager
  config' <- newConfig
  let config = config'
               { configHost = url
               , configValidateAuthMethods = False }
               -- `addAuthMethod` AuthOAuthFoo "secret-key"
  res <- dispatchMime mgr config req
  case mimeResult res of
    Left err -> error $ mimeError err
    Right rs -> return rs

data RepoIssueOptions = RepoIssueOptions
  { repoIssueCreatedBy :: Maybe String
  , repoIssueState :: Maybe String
  }

defaultRepoIssueOptions :: RepoIssueOptions
defaultRepoIssueOptions = RepoIssueOptions Nothing Nothing

listRepoIssues :: B.ByteString -> String -> String -> RepoIssueOptions -> IO [Issue]
listRepoIssues url owner repo options = do
  let baseReq = issueListIssues (Owner $ T.pack owner) (Repo $ T.pack repo)
                -&- ParamType2 E'Type3'Issues
      creatorReq = maybe baseReq (\user -> baseReq -&- CreatedBy user) $
                   T.pack <$> repoIssueCreatedBy options
      req = maybe creatorReq (\state -> creatorReq -&- State3 state) $
            toE'State4' <$> (repoIssueState options)
  mgr <- newTlsManager
  config' <- newConfig
  let config = config'
               { configHost = url
               , configValidateAuthMethods = False }
  res <- dispatchMime mgr config req
  case mimeResult res of
    Left err -> error $ mimeError err
    Right issues -> return issues

toE'State4' :: String -> E'State4
toE'State4' s =
  case map toLower s of
    "closed" -> E'State4'Closed
    "open" -> E'State4'Open
    "all" -> E'State4'All
    _ -> error $ "toE'State4': enum parse failure: " ++ show s
