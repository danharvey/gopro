module Spec where

import           Control.Lens
import qualified Data.Aeson            as J
import qualified Data.ByteString.Lazy  as BL
import qualified Data.List.NonEmpty    as NE

import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck as QC

import           GoPro.Commands.Backup (extractMedia, extractOrig)
import           GoPro.Commands.Sync   (metadataSources)
import           GoPro.File
import           GoPro.Plus.Media      (FileInfo)

import qualified DBSpec

unit_extractMedia :: Assertion
unit_extractMedia = do
  Just fi <- J.decode <$> BL.readFile "test/mediaex.json" :: IO (Maybe FileInfo)
  assertEqual (show fi) [("derivatives/xxx/xxx-var-timelapse_video.mp4","hhttp://d/","http://d/"),
                         ("derivatives/xxx/xxx-var-high_res_proxy_mp4.mp4","hhttp://e/","http://e/"),
                         ("derivatives/xxx/xxx-var-mp4_low.mp4","hhttp://f/","http://f/"),
                         ("derivatives/xxx/xxx-sidecar-ziplabel.zip","hhttp://b/","http://b/"),
                         ("derivatives/xxx/xxx-files-1.JPG", "hhttp://a/", "http://a/"),
                         ("derivatives/xxx/xxx-files-2.JPG", "hhttp://aprime/", "http://aprime/")
                         ] $
    extractMedia "xxx" fi

unit_extractOrig :: Assertion
unit_extractOrig = do
  Just fi <- J.decode <$> BL.readFile "test/mediaex.json" :: IO (Maybe FileInfo)
  assertEqual (show fi) [("derivatives/xxx/xxx-files-1.JPG", "hhttp://a/", "http://a/"),
                         ("derivatives/xxx/xxx-files-2.JPG", "hhttp://aprime/", "http://aprime/")
                         ] $
    extractOrig "xxx" fi

  Just fiv <- J.decode <$> BL.readFile "test/mediavid.json" :: IO (Maybe FileInfo)
  assertEqual (show fi) [("derivatives/xxx/xxx-var-source.mp4", "hhttp://k/", "http://k/")
                         ] $
    extractOrig "xxx" fiv

unit_extractMediaConcat :: Assertion
unit_extractMediaConcat = do
  efi <- J.eitherDecode <$> BL.readFile "test/concat.json" :: IO (Either String FileInfo)
  assertEqual (show efi) (Right [("derivatives/xxx/xxx-var-concat.mp4","hhttp://AAK","http://AAK"),
                                 ("derivatives/xxx/xxx-var-source-1.mp4","hhttp://AAL","http://AAL"),
                                 ("derivatives/xxx/xxx-var-source-2.mp4","hhttp://AAM","http://AAM"),
                                 ("derivatives/xxx/xxx-var-source-3.mp4","hhttp://AAN","http://AAN"),
                                 ("derivatives/xxx/xxx-var-high_res_proxy_mp4.mp4","hhttp://AAO","http://AAO"),
                                 ("derivatives/xxx/xxx-var-mp4_low.mp4","hhttp://AAP","http://AAP"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.1.mp4","hhttp://AAB","http://AAB"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.antishake.json","hhttp://AAC","http://AAC"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.antishake_horizon.json","hhttp://AAD","http://AAD"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.antishake_horizon_worldlock.json","hhttp://AAE","http://AAE"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.antishake_worldlock.json","hhttp://AAF","http://AAF"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.proxy_antishake.json","hhttp://AAG","http://AAG"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.proxy_horizon_worldlock.json","hhttp://AAH","http://AAH"),
                                 ("derivatives/xxx/xxx-sidecar-gpmf.proxy_worldlock.json","hhttp://AAI","http://AAI"),
                                 ("derivatives/xxx/xxx-files-1.MP4","hhttp://AAA","http://AAA")]
    ) $
    extractMedia "xxx" <$> efi

unit_extractOrigConcat :: Assertion
unit_extractOrigConcat = do
  eciv <- J.eitherDecode <$> BL.readFile "test/concat.json" :: IO (Either String FileInfo)
  assertEqual (show eciv) (Right [("derivatives/xxx/xxx-var-concat.mp4", "hhttp://AAK", "http://AAK")
                                 ]) $
    extractOrig "xxx" <$> eciv

unit_extractMediaDedup :: Assertion
unit_extractMediaDedup = do
  e <- J.eitherDecode <$> BL.readFile "test/trailing.json" :: IO (Either String FileInfo)
  assertEqual (show e) (Right [("derivatives/xxx/xxx-var-source.jpg", "hhttp://a","http://a")]
                       ) $ extractMedia "xxx" <$> e

unit_metadataSources :: Assertion
unit_metadataSources = do
  e <- J.eitherDecode <$> BL.readFile "test/mediaex.json" :: IO (Either String FileInfo)
  assertEqual (show e) (Right [("http://f/","low"),("http://e/","high")]) $ metadataSources <$> e

unit_gpmfGuesses :: Assertion
unit_gpmfGuesses = do
  e <- J.eitherDecode <$> BL.readFile "test/gpmf.json" :: IO (Either String FileInfo)
  assertEqual (show e) (Right [("https://B","gpmf"),
                               ("https://P","low"),
                               ("https://O","high"),
                               ("https://K","concat"),
                               ("https://L","src"),
                               ("https://M","src"),
                               ("https://N","src")]) $ metadataSources <$> e

unit_fileParseGroup :: Assertion
unit_fileParseGroup = do
  let fns = [
        "/some/path/GL010644.LRV",
        "/some/path/GL010646.LRV",
        "/some/path/GL010647.LRV",
        "/some/path/GL010648.LRV",
        "/some/path/GL010649.LRV",
        "/some/path/GL020648.LRV",
        "/some/path/GL020649.LRV",
        "/some/path/GOPR0645.GPR",
        "/some/path/GOPR0645.JPG",
        "/some/path/GOPR0650.GPR",
        "/some/path/GOPR0650.JPG",
        "/some/path/GX010644.MP4",
        "/some/path/GX010644.THM",
        "/some/path/GX010646.MP4",
        "/some/path/GX010646.THM",
        "/some/path/GX010647.MP4",
        "/some/path/GX010647.THM",
        "/some/path/GX010648.MP4",
        "/some/path/GX010648.THM",
        "/some/path/GX010649.MP4",
        "/some/path/GX010649.THM",
        "/some/path/GX020648.MP4",
        "/some/path/GX020648.THM",
        "/some/path/GX020649.MP4",
        "/some/path/GX020649.THM",
        "/some/path/Get_started_with_GoPro.url",
        "/some/path/leinfo.sav"]
      grouped = NE.toList <$> parseAndGroup fns
  assertEqual (show grouped) (
    [[File {_gpFilePath = "/some/path/GX010644.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 644, _gpChapter = 1}],
     [File {_gpFilePath = "/some/path/GOPR0645.JPG", _gpCodec = GoProJPG,  _gpFileNumber = 645, _gpChapter = 0}],
     [File {_gpFilePath = "/some/path/GX010646.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 646, _gpChapter = 1}],
     [File {_gpFilePath = "/some/path/GX010647.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 647, _gpChapter = 1}],
     [File {_gpFilePath = "/some/path/GX010648.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 648, _gpChapter = 1},
      File {_gpFilePath = "/some/path/GX020648.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 648, _gpChapter = 2}],
     [File {_gpFilePath = "/some/path/GX010649.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 649, _gpChapter = 1},
      File {_gpFilePath = "/some/path/GX020649.MP4", _gpCodec = GoProHEVC, _gpFileNumber = 649, _gpChapter = 2}],
     [File {_gpFilePath = "/some/path/GOPR0650.JPG", _gpCodec = GoProJPG,  _gpFileNumber = 650, _gpChapter = 0}]]) grouped
