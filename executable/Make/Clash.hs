module Make.Clash ( clashRules
                  , getClashOut ) where

import Control.Monad.IO.Class
import Data.List
import Development.Shake
import Development.Shake.Config
import Development.Shake.FilePath
import Development.Shake.Util

import Make.Config
import Make.HDL

clashExec :: String
clashExec = "stack exec clash --"

ghcFlags :: Action [String]
ghcFlags = do
  odir <- configFlag2 "-odir" "CLASH_ODIR"
  hidir <- configFlag2 "-hidir" "CLASH_HIDIR"
  idir <- configFlag "-i" "SRC"
  return (odir ++ hidir ++ [idir])

getClashOut :: MonadIO m => m String
getClashOut = getBuildDir >>= fetch
  where fetch buildDir = liftIO $ maybeConfigIO "CLASH_OUT" (buildDir </> "clash")

validEntityOutput :: HDL -> Rules (FilePath -> Bool)
validEntityOutput hdl = do
  clashOut <- getClashOut
  (Just entityD) <- liftIO $ getConfigIO "HDL_ENTITIES"
  entities <- liftIO $ getDirectoryDirsIO entityD
  return (\ hdlD -> let hdlD' = makeRelative (clashOut </> hdlName hdl) hdlD in
                      elem hdlD' (map (\ entity -> entity </> "manifest" <.> "txt") entities))


clashRules :: Rules ()
clashRules = do

  hdlRule VHDL
  hdlRule Verilog


hdlRule :: HDL -> Rules ()
hdlRule hdl = validEntityOutput hdl >>= (?> buildHDL hdl)


-- technically this builds a manifest, a text file for which each line is the
-- name of the top level entity that was synthesised. This actually feels a
-- little silly; I wish I could have the build rule specify the `hdlD` directly
-- but shake only permits `need` to be called on files.
buildHDL :: HDL -> FilePath -> Action ()
buildHDL hdl manifestF = do
  let hdlD = takeDirectory manifestF
  clashOut <- getClashOut

  -- GHC has the capability to take a haskell source tree and spit out an old
  -- fashioned makefile for compiling any file in that tree. This lets us make
  -- explicit all the modules that the top level entity (transitively)
  -- imports. Since Shake has stuff for parsing makefile dependencies this
  -- lets us know what files we need to depend on to (potentially) trigger a
  -- rebuild.

  let mkF = hdlD <.> "mk"
  (Just entityD) <- getConfig "HDL_ENTITIES"
  (Just mainClashNameF) <- getConfig "TOPLEVEL_HS_FILE"
  let srcF = entityD </> takeBaseName hdlD </> mainClashNameF
  flags <- ghcFlags

  -- We need to muck about with the makefile after clash spits it out, so
  -- stick it in a temporary file.
  withTempFile $  \ mkF' -> do
    putNormal "Determining CLaSH dependencies"
    () <- cmd clashExec "-M -dep-suffix=" [""] " -dep-makefile" [mkF'] flags srcF

    -- We're lifting from IO becdause readFileLines will add the temporary make
    -- file as an additional dependency, which we do not want. It is a temporary
    -- file, after all.
    lns <- lines <$> liftIO (readFile mkF')
    writeFileLines mkF [ln | ln <- lns, isSuffixOf ".hs" ln]

  -- Actually include the dependencies.
  needMakefileDependencies mkF

  -- Figure out where primitives live and generate the proper include flag
  primFlags <- (</> hdlName hdl) <$> (configFlag "-i" "HDL_PRIMITIVES")

  -- generate the hdl
  putNormal "Compiling CLaSH sources"
  () <- cmd clashExec flags primFlags "-outputdir" clashOut (hdlFlag hdl) srcF

  -- put together the manifest.
  --
  -- TODO: technically this doesn't create a manifest of the top level entities
  -- that were just synthesised, it's a manifest of all the directories hdl
  -- output directory. If a top level entity is specified, the HDL is generated,
  -- and the top level entity spec is removed then as long as the build
  -- directory isn't cleaned the manifest will still list the entity even though
  -- it's no longer being built. Fix this.
  liftIO $ (unlines <$> getDirectoryDirsIO hdlD) >>= writeFile manifestF
