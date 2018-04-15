{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Nix.Convert where

import           Control.Monad
-- import           Control.Monad.Catch
-- import           Control.Monad.Fix
-- import           Control.Monad.IO.Class
import           Data.Aeson (toJSON)
import qualified Data.Aeson as A
import           Data.ByteString
import           Data.Fix
import           Data.Functor.Compose
import           Data.HashMap.Lazy (HashMap)
import qualified Data.HashMap.Lazy as M
import           Data.Scientific
import           Data.Text (Text)
import qualified Data.Text as Text
import           Data.Text.Encoding (encodeUtf8, decodeUtf8)
import qualified Data.Vector as V
import           Nix.Atoms
import           Nix.Effects
import           Nix.Expr.Types
import           Nix.Expr.Types.Annotated
import           Nix.Normal
-- import           Nix.Scope
import           Nix.Stack
import           Nix.Thunk
import           Nix.Utils
import           Nix.Value
import           Text.Megaparsec.Pos
-- import {-# SOURCE #-} Nix.Entry

class FromNix a m v where
    fromNix    :: (Framed e m, MonadVar m, MonadFile m) => v -> m a
    fromNixMay :: (Framed e m, MonadVar m, MonadFile m) => v -> m (Maybe a)

instance FromNix Bool m (NValueNF m) where
    fromNixMay = \case
        Fix (NVConstant (NBool b)) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a bool, but saw: " ++ show v

instance FromNix Bool m (NValue m) where
    fromNixMay = \case
        NVConstant (NBool b) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a bool, but saw: " ++ show v

instance FromNix Int m (NValueNF m) where
    fromNixMay = \case
        Fix (NVConstant (NInt b)) -> pure $ Just (fromInteger b)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an integer, but saw: " ++ show v

instance FromNix Int m (NValue m) where
    fromNixMay = \case
        NVConstant (NInt b) -> pure $ Just (fromInteger b)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an integer, but saw: " ++ show v

instance FromNix Integer m (NValueNF m) where
    fromNixMay = \case
        Fix (NVConstant (NInt b)) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an integer, but saw: " ++ show v

instance FromNix Integer m (NValue m) where
    fromNixMay = \case
        NVConstant (NInt b) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an integer, but saw: " ++ show v

instance FromNix Float m (NValueNF m) where
    fromNixMay = \case
        Fix (NVConstant (NFloat b)) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a float, but saw: " ++ show v

instance FromNix Float m (NValue m) where
    fromNixMay = \case
        NVConstant (NFloat b) -> pure $ Just b
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a float, but saw: " ++ show v

instance FromNix Text m (NValueNF m) where
    fromNixMay = \case
        Fix (NVStr t _) -> pure $ Just t
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a string, but saw: " ++ show v

instance FromNix Text m (NValue m) where
    fromNixMay = \case
        NVStr t _ -> pure $ Just t
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a string, but saw: " ++ show v

instance FromNix ByteString m (NValueNF m) where
    fromNixMay = \case
        Fix (NVStr t _) -> pure $ Just (encodeUtf8 t)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a string, but saw: " ++ show v

instance FromNix ByteString m (NValue m) where
    fromNixMay = \case
        NVStr t _ -> pure $ Just (encodeUtf8 t)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a string, but saw: " ++ show v

newtype Path = Path { getPath :: FilePath }
    deriving Show

instance FromNix Path m (NValueNF m) where
    fromNixMay = \case
        Fix (NVPath p) -> pure $ Just (Path p)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a path, but saw: " ++ show v

instance FromNix Path m (NValue m) where
    fromNixMay = \case
        NVPath p -> pure $ Just (Path p)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a path, but saw: " ++ show v

instance (FromNix a m (NValueNF m), Show a)
      => FromNix [a] m (NValueNF m) where
    fromNixMay = \case
        Fix (NVList l) -> fmap sequence $ traverse fromNixMay l
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance (MonadThunk (NValue m) (NThunk m) m,
          FromNix a m (NValue m), Show a)
      => FromNix [a] m (NValue m) where
    fromNixMay = \case
        NVList l -> fmap sequence $ traverse fromNixMay l
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance FromNix (HashMap Text (NValueNF m)) m (NValueNF m) where
    fromNixMay = \case
        Fix (NVSet s _) -> pure $ Just s
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance FromNix (HashMap Text (NThunk m)) m (NValue m) where
    fromNixMay = \case
        NVSet s _ -> pure $ Just s
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance FromNix (HashMap Text (NValueNF m),
                  HashMap Text SourcePos) m (NValueNF m) where
    fromNixMay = \case
        Fix (NVSet s p) -> pure $ Just (s, p)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance FromNix (HashMap Text (NThunk m),
                  HashMap Text SourcePos) m (NValue m) where
    fromNixMay = \case
        NVSet s p -> pure $ Just (s, p)
        _ -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected an attrset, but saw: " ++ show v

instance (MonadThunk (NValue m) (NThunk m) m)
      => FromNix (NThunk m) m (NValue m) where
    fromNixMay = pure . Just . value @_ @_ @m
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Expected a thunk, but saw: " ++ show v

instance FromNix a m (NValue m) => FromNix a m (m (NValue m)) where
    fromNix    v = v >>= fromNix
    fromNixMay v = v >>= fromNixMay

instance (MonadThunk (NValue m) (NThunk m) m,
          FromNix a m (NValue m)) => FromNix a m (NThunk m) where
    fromNix    = force ?? fromNix
    fromNixMay = force ?? fromNixMay

instance (MonadThunk (NValue m) (NThunk m) m,
          FromNix a m (NValue m)) => FromNix a m (m (NThunk m)) where
    fromNix    v = v >>= fromNix
    fromNixMay v = v >>= fromNixMay

{-
instance (MonadNix e m, FromNix a m (NValue m))
      => FromNix a m NExprLoc where
    fromNix    = evalLoc Nothing [] >=> fromNix
    fromNixMay = evalLoc Nothing [] >=> fromNixMay

instance (MonadCatch m, MonadFix m, MonadIO m, MonadEffects m,
          FromNix a m (NValue m)) => FromNix a m NExpr where
    fromNix    = eval Nothing [] >=> fromNix
    fromNixMay = eval Nothing [] >=> fromNixMay
-}

instance MonadEffects m => FromNix A.Value m (NValueNF m) where
    fromNixMay = \case
        Fix (NVConstant a) -> pure $ Just $ case a of
            NInt n   -> toJSON n
            NFloat n -> toJSON n
            NBool b  -> toJSON b
            NNull    -> A.Null
            NUri u   -> toJSON u
        Fix (NVStr s _)     -> pure $ Just $ toJSON s
        Fix (NVList l)      -> fmap (A.Array . V.fromList) . sequence
                                  <$> traverse fromNixMay l
        Fix (NVSet m _)     -> fmap A.Object . sequence <$> traverse fromNixMay m
        Fix NVClosure {}    -> pure Nothing
        Fix (NVPath p)      -> Just . toJSON . unStorePath <$> addPath p
        Fix (NVBuiltin _ _) -> pure Nothing
    fromNix = fromNixMay >=> \case
        Just b -> pure b
        v -> throwError $ "Cannot convert value to JSON: " ++ show v

instance (MonadThunk (NValue m) (NThunk m) m, MonadEffects m)
      => FromNix A.Value m (NValue m) where
    fromNixMay = normalForm >=> fromNixMay
    fromNix    = normalForm >=> fromNix

class ToNix a m v where
    toNix :: Monad m => a -> m v

instance ToNix Bool m (NValueNF m) where
    toNix = pure . Fix . NVConstant . NBool

instance ToNix Bool m (NValue m) where
    toNix = pure . NVConstant . NBool

instance ToNix Int m (NValueNF m) where
    toNix = pure . Fix . NVConstant . NInt . toInteger

instance ToNix Int m (NValue m) where
    toNix = pure . NVConstant . NInt . toInteger

instance ToNix Integer m (NValueNF m) where
    toNix = pure . Fix . NVConstant . NInt

instance ToNix Integer m (NValue m) where
    toNix = pure . NVConstant . NInt

instance ToNix Float m (NValueNF m) where
    toNix = pure . Fix . NVConstant . NFloat

instance ToNix Float m (NValue m) where
    toNix = pure . NVConstant . NFloat

instance ToNix Text m (NValueNF m) where
    toNix = pure . Fix . flip NVStr mempty

instance ToNix Text m (NValue m) where
    toNix = pure . flip NVStr mempty

instance ToNix ByteString m (NValueNF m) where
    toNix = pure . Fix . flip NVStr mempty . decodeUtf8

instance ToNix ByteString m (NValue m) where
    toNix = pure . flip NVStr mempty . decodeUtf8

instance ToNix Path m (NValueNF m) where
    toNix = pure . Fix . NVPath . getPath

instance ToNix Path m (NValue m) where
    toNix = pure . NVPath . getPath

instance MonadThunk (NValue m) (NThunk m) m
      => ToNix SourcePos m (NValue m) where
    toNix (SourcePos f l c) = do
        f' <- toNix @_ @_ @(NValue m) (Text.pack f)
        l' <- toNix (unPos l)
        c' <- toNix (unPos c)
        toNix $ M.fromList [ ("file" :: Text, value @_ @_ @m f')
                           , ("line",        value @_ @_ @m l')
                           , ("column",      value @_ @_ @m c') ]

instance ToNix a m (NValueNF m) => ToNix [a] m (NValueNF m) where
    toNix = fmap (Fix . NVList) . traverse toNix

instance (MonadThunk (NValue m) (NThunk m) m,
          ToNix a m (NValue m)) => ToNix [a] m (NValue m) where
    toNix = fmap NVList . traverse toNix

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValueNF m))
      => ToNix (HashMap Text a) m (NValueNF m) where
    toNix = fmap (Fix . flip NVSet M.empty) . traverse toNix

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValue m))
      => ToNix (HashMap Text a) m (NValue m) where
    toNix = fmap (flip NVSet M.empty) . traverse toNix

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValueNF m))
      => ToNix (HashMap Text a, HashMap Text SourcePos) m (NValueNF m) where
    toNix (s, p) = Fix . flip NVSet p <$> traverse toNix s

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValue m))
      => ToNix (HashMap Text a, HashMap Text SourcePos) m (NValue m) where
    toNix (s, p) = flip NVSet p <$> traverse toNix s

instance (MonadThunk (NValue m) (NThunk m) m)
      => ToNix (NThunk m) m (NValue m) where
    toNix = force ?? pure

instance ToNix a m (NValue m) => ToNix a m (m (NValue m)) where
    toNix = pure . toNix

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValue m))
      => ToNix a m (NThunk m) where
    toNix = fmap (value @(NValue m) @_ @m) . toNix

instance (MonadThunk (NValue m) (NThunk m) m, ToNix a m (NValue m))
      => ToNix a m (m (NThunk m)) where
    toNix = pure . fmap (value @(NValue m) @_ @m) . toNix

instance ToNix Bool m (NExprF r) where
    toNix = pure . NConstant . NBool

instance ToNix a m (NExprF (Fix NExprF)) => ToNix a m NExpr where
    toNix = fmap Fix . toNix

instance ToNix a m (NExprF (Fix (Compose (Ann SrcSpan) NExprF)))
      => ToNix a m NExprLoc where
    toNix = fmap (Fix . Compose . Ann (SrcSpan blankSpan blankSpan)) . toNix
      where
        blankSpan = SourcePos "<unknown>" (mkPos 1) (mkPos 1)

instance MonadThunk (NValue m) (NThunk m) m
      => ToNix A.Value m (NValue m) where
    toNix = \case
        A.Object m -> flip NVSet M.empty <$> traverse (thunk . toNix @_ @_ @(NValue m)) m
        A.Array l -> NVList <$> traverse (thunk . toNix) (V.toList l)
        A.String s -> pure $ NVStr s mempty
        A.Number n -> pure $ NVConstant $ case floatingOrInteger n of
            Left r -> NFloat r
            Right i -> NInt i
        A.Bool b -> pure $ NVConstant $ NBool b
        A.Null -> pure $ NVConstant NNull