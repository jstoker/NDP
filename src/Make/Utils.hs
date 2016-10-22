module Make.Utils ((!!?),
                  withPath,
                  pathIdx,
                  pathIdx',
                  withReverse,
                  getDirectoryFilesWithExt) where

import Data.List
import Development.Shake.FilePath
import System.Directory

(!!?) :: [a] -> Int -> Maybe a
as !!? a = if a < 0 then
             Nothing
           else
             search as a
  where search (a:as) 0 = Just a
        search (a:as) n = search as (n-1)
        search []     _ = Nothing

withPath :: ([FilePath] -> [FilePath]) -> FilePath -> FilePath
withPath f = joinPath . f . splitDirectories

pathIdx :: FilePath -> Int -> FilePath
pathIdx p i = (splitDirectories p) !! i

pathIdx' :: FilePath -> Int -> FilePath
pathIdx' p i = split !! (max - i)
  where split = splitDirectories p
        max = length split - 1

withReverse :: ([a] -> [b]) -> [a] -> [b]
withReverse f = reverse . f . reverse

getDirectoryFilesWithExt :: FilePath -> String -> IO [FilePath]
getDirectoryFilesWithExt dir ext = do
  files <- getDirectoryContents dir
  let files' = filter ((==ext) . takeExtension) files
  return $ map (dir </>) files'
