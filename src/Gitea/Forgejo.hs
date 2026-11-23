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
import Data.Either.Extra (mapLeft)
import qualified Data.Text as T
import Gitea (configHost, configValidateAuthMethods, dispatchMime, issueListIssues, mimeError, mimeResult, newConfig, orgListRepos, (-&-), CreatedBy(..), E'State4(..), E'Type3(..), Issue(..), Label(..), Org(..), Owner(..), ParamType2(..), Repo(..), Repository(..), State3(..))
import Network.HTTP.Client.TLS (newTlsManager)

fedoraForge :: B.ByteString
fedoraForge = B.pack "https://forge.fedoraproject.org/api/v1"

listOrgRepos :: B.ByteString -> String -> IO (Either String [Repository])
listOrgRepos url org = do
  let req = orgListRepos (Org $ T.pack org)
  mgr <- newTlsManager
  config' <- newConfig
  let config = config'
               { configHost = url
               , configValidateAuthMethods = False }
               -- `addAuthMethod` AuthOAuthFoo "secret-key"
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

data RepoIssueOptions = RepoIssueOptions
  { repoIssueCreatedBy :: Maybe String
  , repoIssueState :: Maybe String
  }

defaultRepoIssueOptions :: RepoIssueOptions
defaultRepoIssueOptions = RepoIssueOptions Nothing Nothing

listRepoIssues :: B.ByteString -> String -> String -> RepoIssueOptions
               -> IO (Either String [Issue])
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
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

toE'State4' :: String -> E'State4
toE'State4' s =
  case map toLower s of
    "closed" -> E'State4'Closed
    "open" -> E'State4'Open
    "all" -> E'State4'All
    _ -> error $ "toE'State4': enum parse failure: " ++ show s
