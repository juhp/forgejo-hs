{-# LANGUAGE OverloadedStrings #-}

module Gitea.Forgejo (
  listOrgs,
  listOrgRepos,
  listUserRepos,
  searchUsers,
  getUser,
  listRepoIssues,
  RepoIssueOptions(..),
  defaultRepoIssueOptions,
  fedoraForge,
  Issue(..),
  Label(..),
  Organization(..),
  Repository(..),
  User(..)
  )
where

import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as B
import Data.Char (toLower)
import Data.Either.Extra (mapLeft)
import qualified Data.Text as T
import Gitea (addAuthMethod, configHost, configValidateAuthMethods,
              dispatchMime, issueListIssues, mimeError, mimeResult,
              mimeResultResponse, newConfig, orgGetAll, orgListRepos,
              repoSearch, userGet, userSearch, (-&-),
              AuthApiKeyAuthorizationHeaderToken(..), CreatedBy(..),
              E'State4(..), E'Type3(..), GiteaConfig,
              Issue(..), Label(..), MimeResult, Org(..), Organization(..),
              Owner(..), Page(..), ParamType2(..), Q(..), Repo(..),
              Repository(..),
              SearchResults(searchResultsData, searchResultsOk),
              Sort(..), State3(..), Uid(..), User(..), Username(..),
              UserSearch200Response(userSearch200ResponseData,
                                    userSearch200ResponseOk))
import Network.HTTP.Client (Manager, responseHeaders)
import Network.HTTP.Client.TLS (getGlobalManager)

-- | Fedora Forge api url
fedoraForge :: String
fedoraForge = "https://forge.fedoraproject.org/api/v1"

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

-- | List all organizations visible to the caller.
listOrgs :: String -- ^ API URL
         -> Maybe String -- ^ personal access token
         -> IO (Either String [Organization])
listOrgs url mtoken = do
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  fetchAllPages $ \page ->
    listPageResult <$> dispatchMime mgr config (orgGetAll -&- Page page)

-- | List all visible repositories of a Forgejo org with an optional token.
listOrgRepos :: String -- ^ API URL
             -> Maybe String -- ^ personal access token
             -> String -- ^ org
             -> IO (Either String [Repository])
listOrgRepos url mtoken org = do
  let req = orgListRepos (Org $ T.pack org)
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  fetchAllPages $ \page ->
    listPageResult <$> dispatchMime mgr config (req -&- Page page)

-- | List repositories associated with a user and visible to the caller.
listUserRepos :: String -- ^ API URL
              -> Maybe String -- ^ personal access token
              -> String -- ^ username
              -> IO (Either String [Repository])
listUserRepos url mtoken username = do
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  let fetchPage uid page = do
        let req = repoSearch -&- Uid uid -&- Sort (T.pack "id") -&- Page page
        result <- dispatchMime mgr config req
        case mimeResult result of
          Left err -> return $
            Left ("Could not search repositories: " ++ mimeError err)
          Right found -> return $
            case (searchResultsOk found, searchResultsData found) of
              (Just True, Just repos) -> Right (repos, hasNextPage result)
              _ -> Left "Invalid repository search response"
  result <- lookupUser mgr config username
  case result of
    Left err -> return (Left err)
    Right user ->
      case userId user of
        Just uid | uid > 0 -> fetchAllPages (fetchPage uid)
        _ -> return $ Left ("Missing or invalid ID for user " ++ username)

-- | Get a user's profile by username.
getUser :: String -- ^ API URL
        -> Maybe String -- ^ personal access token
        -> String -- ^ username
        -> IO (Either String User)
getUser url mtoken username = do
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  lookupUser mgr config username

lookupUser :: Manager -> GiteaConfig -> String -> IO (Either String User)
lookupUser mgr config username = do
  result <- mimeResult <$> dispatchMime mgr config (userGet (Username (T.pack username)))
  return $ mapLeft (\err -> "Could not look up user " ++ username ++ ": " ++ mimeError err) result

-- | Search for visible users using the server's keyword matching.
searchUsers :: String -- ^ API URL
            -> Maybe String -- ^ personal access token
            -> String -- ^ search keyword
            -> IO (Either String [User])
searchUsers url mtoken keyword = do
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  let request = userSearch -&- Q (T.pack keyword)
  fetchAllPages $ \page -> do
    result <- dispatchMime mgr config (request -&- Page page)
    return $ case mimeResult result of
      Left err -> Left ("Could not search users: " ++ mimeError err)
      Right found ->
        case (userSearch200ResponseOk found, userSearch200ResponseData found) of
          (Just True, Just users) -> Right (users, hasNextPage result)
          _ -> Left "Invalid user search response"

listPageResult :: MimeResult [a] -> Either String ([a], Bool)
listPageResult result = do
  items <- mapLeft mimeError (mimeResult result)
  return (items, hasNextPage result)

hasNextPage :: MimeResult a -> Bool
hasNextPage result =
  any (BS.isInfixOf "rel=\"next\"")
  [value | (name, value) <- headers, name == "Link"]
  where
    headers = responseHeaders (mimeResultResponse result)

fetchAllPages :: (Int -> IO (Either String ([a], Bool)))
              -> IO (Either String [a])
fetchAllPages fetchPage = go 1 []
  where
    go page pages = do
      result <- fetchPage page
      case result of
        Left err -> return (Left err)
        Right ([], False) -> return (Right (concat (reverse pages)))
        Right (items, _) -> go (page + 1) (items : pages)

data RepoIssueOptions = RepoIssueOptions
  { repoIssueCreatedBy :: Maybe String
  , repoIssueState :: Maybe String
  }

-- | no options
defaultRepoIssueOptions :: RepoIssueOptions
defaultRepoIssueOptions = RepoIssueOptions Nothing Nothing

-- | List all matching issues in a Forgejo repo with an optional token.
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
  mgr <- getGlobalManager
  config <- newApiConfig url mtoken
  fetchAllPages $ \page ->
    listPageResult <$> dispatchMime mgr config (req -&- Page page)

toE'State4' :: String -> E'State4
toE'State4' s =
  case map toLower s of
    "closed" -> E'State4'Closed
    "open" -> E'State4'Open
    "all" -> E'State4'All
    _ -> error $ "toE'State4': enum parse failure: " ++ show s
