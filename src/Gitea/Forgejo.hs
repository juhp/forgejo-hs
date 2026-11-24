module Gitea.Forgejo (
  listOrgRepos,
  listUserRepos,
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
import Gitea (addAuthMethod, configHost, configValidateAuthMethods, dispatchMime,
              issueListIssues, mimeError, mimeResult, newConfig, orgListRepos,
              repoSearch, searchResultsData, searchResultsOk, userGet, userId, (-&-),
              AuthApiKeyAuthorizationHeaderToken(..), CreatedBy(..), E'State4(..),
              E'Type3(..), Issue(..), Label(..), Org(..), Owner(..), Page(..),
              ParamType2(..), Repo(..), Repository(..), Sort(..), State3(..), Uid(..),
              Username(..))
import Network.HTTP.Client.TLS (newTlsManager)

-- | Fedora Forge api url
fedoraForge :: String
fedoraForge = "https://forge.fedoraproject.org/api/v1"

-- | List the repositories of a Forgejo org
listOrgRepos :: String -- ^ api url
             -> String -- ^ org
             -> IO (Either String [Repository])
listOrgRepos url org = do
  let req = orgListRepos (Org $ T.pack org)
  mgr <- newTlsManager
  config' <- newConfig
  let config = config'
               { configHost = B.pack url
               , configValidateAuthMethods = False }
               -- `addAuthMethod` AuthOAuthFoo "secret-key"
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

-- | List repositories associated with a user and visible to the caller.
listUserRepos :: String -- ^ API URL
              -> Maybe String -- ^ personal access token
              -> String -- ^ username
              -> IO (Either String [Repository])
listUserRepos url mtoken username = do
  mgr <- newTlsManager
  config' <- newConfig
  let defaultConfig = config'
        { configHost = B.pack url
        , configValidateAuthMethods = False }
      config = maybe defaultConfig
        (\key -> addAuthMethod defaultConfig (AuthApiKeyAuthorizationHeaderToken (T.pack ("token " ++ key))))
        mtoken
      fetchPages uid page pages = do
        let req = repoSearch -&- Uid uid -&- Sort (T.pack "id") -&- Page page
        result <- mimeResult <$> dispatchMime mgr config req
        case result of
          Left err -> return $ Left ("Could not search repositories: " ++ mimeError err)
          Right found ->
            case (searchResultsOk found, searchResultsData found) of
              (Just True, Just []) -> return $ Right (concat (reverse pages))
              (Just True, Just repos) -> fetchPages uid (page + 1) (repos : pages)
              _ -> return $ Left "Invalid repository search response"
  result <- mimeResult <$> dispatchMime mgr config (userGet (Username (T.pack username)))
  case result of
    Left err -> return $ Left ("Could not look up user " ++ username ++ ": " ++ mimeError err)
    Right user ->
      case userId user of
        Just uid | uid > 0 -> fetchPages uid 1 []
        _ -> return $ Left ("Missing or invalid ID for user " ++ username)

data RepoIssueOptions = RepoIssueOptions
  { repoIssueCreatedBy :: Maybe String
  , repoIssueState :: Maybe String
  }

-- | no options
defaultRepoIssueOptions :: RepoIssueOptions
defaultRepoIssueOptions = RepoIssueOptions Nothing Nothing

-- | List issues in a forgejo repo
listRepoIssues :: String -- ^ api url
               -> String -- ^ repo owner
               -> String -- ^ repo
               -> RepoIssueOptions -- ^ issue filter options
               -> IO (Either String [Issue])
listRepoIssues url owner repo options = do
  let baseReq = issueListIssues (Owner $ T.pack owner) (Repo $ T.pack repo)
                -&- ParamType2 E'Type3'Issues
      creatorReq = maybe baseReq
                   ((\user -> baseReq -&- CreatedBy user) . T.pack) $
                   repoIssueCreatedBy options
      req = maybe creatorReq
            ((\state -> creatorReq -&- State3 state) . toE'State4') $
            repoIssueState options
  mgr <- newTlsManager
  config' <- newConfig
  let config = config'
               { configHost = B.pack url
               , configValidateAuthMethods = False }
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

toE'State4' :: String -> E'State4
toE'State4' s =
  case map toLower s of
    "closed" -> E'State4'Closed
    "open" -> E'State4'Open
    "all" -> E'State4'All
    _ -> error $ "toE'State4': enum parse failure: " ++ show s
