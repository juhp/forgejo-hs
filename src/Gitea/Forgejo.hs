module Gitea.Forgejo (
  listOrgRepos,
  listUserRepos,
  searchUsers,
  listRepoIssues,
  RepoIssueOptions(..),
  defaultRepoIssueOptions,
  fedoraForge,
  Issue(..),
  Label(..),
  Repository(..),
  User(..)
  )
where

import qualified Data.ByteString.Lazy.Char8 as B
import Data.Char (toLower)
import Data.Either.Extra (mapLeft)
import qualified Data.Text as T
import Gitea (addAuthMethod, configHost, configValidateAuthMethods, dispatchMime,
              issueListIssues, mimeError, mimeResult, newConfig, orgListRepos,
              repoSearch, searchResultsData, searchResultsOk, userGet, userSearch,
              userSearch200ResponseData, userSearch200ResponseOk, (-&-),
              AuthApiKeyAuthorizationHeaderToken(..), CreatedBy(..), E'State4(..),
              E'Type3(..), GiteaConfig, Issue(..), Label(..), Org(..), Owner(..),
              Page(..), ParamType2(..), Q(..), Repo(..), Repository(..), Sort(..),
              State3(..), Uid(..), User(..), Username(..))
import Network.HTTP.Client.TLS (newTlsManager)

-- | Fedora Forge api url
fedoraForge :: String
fedoraForge = "https://forge.fedoraproject.org/api/v1"

-- | List the repositories of a Forgejo org with an optional token.
listOrgRepos :: String -- ^ API URL
             -> Maybe String -- ^ personal access token
             -> String -- ^ org
             -> IO (Either String [Repository])
listOrgRepos url mtoken org = do
  let req = orgListRepos (Org $ T.pack org)
  mgr <- newTlsManager
  config <- newApiConfig url mtoken
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

-- | List repositories associated with a user and visible to the caller.
listUserRepos :: String -- ^ API URL
              -> Maybe String -- ^ personal access token
              -> String -- ^ username
              -> IO (Either String [Repository])
listUserRepos url mtoken username = do
  mgr <- newTlsManager
  config <- newApiConfig url mtoken
  let fetchPage uid page = do
        let req = repoSearch -&- Uid uid -&- Sort (T.pack "id") -&- Page page
        result <- mimeResult <$> dispatchMime mgr config req
        case result of
          Left err -> return $
            Left ("Could not search repositories: " ++ mimeError err)
          Right found -> return $
            case (searchResultsOk found, searchResultsData found) of
              (Just True, Just repos) -> Right repos
              _ -> Left "Invalid repository search response"
  result <- mimeResult <$> dispatchMime mgr config (userGet (Username (T.pack username)))
  case result of
    Left err -> return $ Left ("Could not look up user " ++ username ++ ": " ++ mimeError err)
    Right user ->
      case userId user of
        Just uid | uid > 0 -> fetchAllPages (fetchPage uid)
        _ -> return $ Left ("Missing or invalid ID for user " ++ username)

-- | Search for visible users using the server's keyword matching.
searchUsers :: String -- ^ API URL
            -> Maybe String -- ^ personal access token
            -> String -- ^ search keyword
            -> IO (Either String [User])
searchUsers url mtoken keyword = do
  mgr <- newTlsManager
  config <- newApiConfig url mtoken
  let request = userSearch -&- Q (T.pack keyword)
  fetchAllPages $ \page -> do
    result <- mimeResult <$> dispatchMime mgr config (request -&- Page page)
    return $ case result of
      Left err -> Left ("Could not search users: " ++ mimeError err)
      Right found ->
        case (userSearch200ResponseOk found, userSearch200ResponseData found) of
          (Just True, Just users) -> Right users
          _ -> Left "Invalid user search response"

newApiConfig :: String -> Maybe String -> IO GiteaConfig
newApiConfig url mtoken = do
  config <- newConfig
  let defaultConfig = config
        { configHost = B.pack url
        , configValidateAuthMethods = False }
  return $ case mtoken of
    Nothing -> defaultConfig
    Just token -> addAuthMethod defaultConfig $
      AuthApiKeyAuthorizationHeaderToken (T.pack ("token " ++ token))

fetchAllPages :: (Int -> IO (Either String [a])) -> IO (Either String [a])
fetchAllPages fetchPage = go 1 []
  where
    go page pages = do
      result <- fetchPage page
      case result of
        Left err -> return (Left err)
        Right [] -> return (Right (concat (reverse pages)))
        Right items -> go (page + 1) (items : pages)

data RepoIssueOptions = RepoIssueOptions
  { repoIssueCreatedBy :: Maybe String
  , repoIssueState :: Maybe String
  }

-- | no options
defaultRepoIssueOptions :: RepoIssueOptions
defaultRepoIssueOptions = RepoIssueOptions Nothing Nothing

-- | List issues in a Forgejo repo with an optional token.
listRepoIssues :: String -- ^ API URL
               -> Maybe String -- ^ personal access token
               -> String -- ^ repo owner
               -> String -- ^ repo
               -> RepoIssueOptions -- ^ issue filter options
               -> IO (Either String [Issue])
listRepoIssues url mtoken owner repo options = do
  let baseReq = issueListIssues (Owner $ T.pack owner) (Repo $ T.pack repo)
                -&- ParamType2 E'Type3'Issues
      creatorReq = maybe baseReq
                   ((\user -> baseReq -&- CreatedBy user) . T.pack) $
                   repoIssueCreatedBy options
      req = maybe creatorReq
            ((\state -> creatorReq -&- State3 state) . toE'State4') $
            repoIssueState options
  mgr <- newTlsManager
  config <- newApiConfig url mtoken
  mapLeft mimeError . mimeResult <$> dispatchMime mgr config req

toE'State4' :: String -> E'State4
toE'State4' s =
  case map toLower s of
    "closed" -> E'State4'Closed
    "open" -> E'State4'Open
    "all" -> E'State4'All
    _ -> error $ "toE'State4': enum parse failure: " ++ show s
