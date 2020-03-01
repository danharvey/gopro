{-# LANGUAGE TupleSections #-}

module Main where

import           Control.Concurrent.Async (mapConcurrently)
import           Control.Concurrent.QSem  (newQSem, signalQSem, waitQSem)
import           Control.Exception        (bracket_)
import           Control.Monad.IO.Class   (MonadIO (..))
import           Control.Monad.Reader     (ReaderT (..), asks, runReaderT)
import qualified Data.Set                 as Set
import           GoPro
import           GoPro.AuthDB
import           GoPro.DB
import           Options.Applicative      (Parser, argument, execParser,
                                           fullDesc, help, helper, info, long,
                                           metavar, progDesc, showDefault, some,
                                           str, strOption, value, (<**>))
import           System.IO                (hFlush, hGetEcho, hSetEcho, stdin,
                                           stdout)

data Options = Options {
  optDBPath :: String,
  optArgv   :: [String]
  }

data Env = Env {
  gpOptions :: Options,
  gpToken   :: String
  }

type GoPro = ReaderT Env IO

options :: Parser Options
options = Options
  <$> strOption (long "dbpath" <> showDefault <> value "gopro.db" <> help "db path")
  <*> some (argument str (metavar "cmd args..."))

mapConcurrentlyLimited :: (Traversable f, Foldable f) => Int -> (a -> IO b) -> f a -> IO (f b)
mapConcurrentlyLimited n f l = newQSem n >>= \q -> mapConcurrently (b q) l
  where b q x = bracket_ (waitQSem q) (signalQSem q) (f x)

data SyncType = Full | Incremental

runSync :: SyncType -> GoPro ()
runSync stype = do
  tok <- asks gpToken
  db <- asks (optDBPath . gpOptions)
  seen <- Set.fromList <$> loadMediaIDs db
  storeMedia db =<< fetch tok seen

    where resolve tok m = MediaRow . (m,) <$> fetchThumbnail tok m
          fetch tok seen = do
            l <- filter (\m@Media{..} -> notSeen m && _ready_to_view == "ready")
                 <$> listWhile tok (listPred stype)
            liftIO $ mapConcurrentlyLimited 11 (resolve tok) l
              where
                notSeen = (`Set.notMember` seen) . _media_id
                listPred Incremental = all notSeen
                listPred Full        = const True

runAuth :: GoPro ()
runAuth = do
  liftIO (prompt "Enter email: ")
  u <- liftIO getLine
  p <- liftIO getPass
  db <- asks (optDBPath . gpOptions)
  res <- authenticate u p
  updateAuth db res

  where
    prompt x = putStr x >> hFlush stdout
    withEcho echo action = do
      prompt "Enter password: "
      old <- hGetEcho stdin
      bracket_ (hSetEcho stdin echo) (hSetEcho stdin old) action

    getPass = withEcho False getLine

runReauth :: GoPro ()
runReauth = do
  db <- asks (optDBPath . gpOptions)
  a <- loadAuth db
  res <- refreshAuth a
  updateAuth db res

run :: String -> GoPro ()
run "auth"     = runAuth
run "reauth"   = runReauth
run "sync"     = runSync Incremental
run "fullsync" = runSync Full
run x          = fail ("unknown command: " <> x)

main :: IO ()
main = do
  o@Options{..} <- execParser opts
  tok <- loadToken optDBPath
  runReaderT (run (head optArgv)) (Env o tok)

  where
    opts = info (options <**> helper)
           ( fullDesc <> progDesc "GoPro cloud utility.")
