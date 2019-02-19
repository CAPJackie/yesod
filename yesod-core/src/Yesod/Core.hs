{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC -fno-warn-warnings-deprecations #-}
module Yesod.Core
    ( -- * Type classes
      Yesod (..)
    , YesodDispatch (..)
    , YesodSubDispatch (..)
    , RenderRoute (..)
    , ParseRoute (..)
    , RouteAttrs (..)
      -- ** Breadcrumbs
    , YesodBreadcrumbs (..)
    , breadcrumbs
      -- * Types
    , Approot (..)
    , FileUpload (..)
    , ErrorResponse (..)
      -- * Utilities
    , maybeAuthorized
    , widgetToPageContent
      -- * Defaults
    , defaultErrorHandler
    , defaultYesodMiddleware
    , authorizationCheck
      -- * Data types
    , AuthResult (..)
    , unauthorizedI
      -- * Logging
    , LogLevel (..)
    , logDebug
    , logInfo
    , logWarn
    , logError
    , logOther
    , logDebugS
    , logInfoS
    , logWarnS
    , logErrorS
    , logOtherS
      -- * Sessions
    , SessionBackend (..)
    , customizeSessionCookies
    , defaultClientSessionBackend
    , envClientSessionBackend
    , clientSessionBackend
    , sslOnlySessions
    , laxSameSiteSessions
    , strictSameSiteSessions
    , sslOnlyMiddleware
    , clientSessionDateCacher
    , loadClientSession
    , Header(..)
    -- * CSRF protection
    , defaultCsrfMiddleware
    , defaultCsrfSetCookieMiddleware
    , csrfSetCookieMiddleware
    , defaultCsrfCheckMiddleware
    , csrfCheckMiddleware
    -- * JS loaders
    , ScriptLoadPosition (..)
    , BottomOfHeadAsync
    -- * Generalizing type classes
    , HasHandlerData (..)
    , HasWidgetData (..)
    , liftHandler
    , liftWidget
      -- * Approot
    , guessApproot
    , guessApprootOr
    , getApprootText
      -- * Misc
    , yesodVersion
    , yesodRender
      -- * LiteApp
    , module Yesod.Core.Internal.LiteApp
      -- * Low-level
    , yesodRunner
      -- * Re-exports
    , module Yesod.Core.Content
    , module Yesod.Core.Dispatch
    , module Yesod.Core.Handler
    , module Yesod.Core.Widget
    , module Yesod.Core.Json
    , module Text.Shakespeare.I18N
    , module Yesod.Core.Internal.Util
    , module Text.Blaze.Html
    , MonadTrans (..)
    , MonadIO (..)
    , MonadUnliftIO (..)
    , MonadResource (..)
    , RIO
      -- * Commonly referenced functions/datatypes
    , Application
      -- * Shakespeare
      -- ** Hamlet
    , hamlet
    , shamlet
    , xhamlet
    , HtmlUrl
      -- ** Julius
    , julius
    , JavascriptUrl
    , renderJavascriptUrl
      -- ** Cassius/Lucius
    , cassius
    , lucius
    , CssUrl
    , renderCssUrl
    ) where

import Yesod.Core.Content
import Yesod.Core.Dispatch
import Yesod.Core.Handler
import Yesod.Core.Widget
import Yesod.Core.Json
import Yesod.Core.Types
import Text.Shakespeare.I18N
import Yesod.Core.Internal.Util (formatW3 , formatRFC1123 , formatRFC822)
import Text.Blaze.Html (Html, toHtml, preEscapedToMarkup)

import Control.Monad.Trans.Class (MonadTrans (..))
import Yesod.Core.Internal.Session
import Yesod.Core.Internal.Run (yesodRunner, yesodRender)
import Yesod.Core.Class.Yesod
import Yesod.Core.Class.Dispatch
import Yesod.Core.Class.Breadcrumbs
import qualified Paths_yesod_core
import Data.Version (showVersion)
import Yesod.Routes.Class
import RIO

import Control.Monad.Trans.Resource (MonadResource (..))
import Yesod.Core.Internal.LiteApp
import Text.Hamlet
import Text.Cassius
import Text.Lucius
import Text.Julius
import Network.Wai (Application)

-- | Return an 'Unauthorized' value, with the given i18n message.
unauthorizedI
  :: (HasHandlerData env, RenderMessage (HandlerSite env) msg)
  => msg
  -> RIO env AuthResult
unauthorizedI msg = do
    mr <- getMessageRender
    return $ Unauthorized $ mr msg

yesodVersion :: String
yesodVersion = showVersion Paths_yesod_core.version

-- | Return the same URL if the user is authorized to see it.
--
-- Built on top of 'isAuthorized'. This is useful for building page that only
-- contain links to pages the user is allowed to see.
maybeAuthorized :: Yesod site
                => Route site
                -> Bool -- ^ is this a write request?
                -> HandlerT site IO (Maybe (Route site))
maybeAuthorized r isWrite = do
    x <- isAuthorized r isWrite
    return $ if x == Authorized then Just r else Nothing