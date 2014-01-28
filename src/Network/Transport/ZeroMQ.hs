module Network.Transport.ZeroMQ
  ( -- * Main API
    createTransport
  , ZeroMQParameters(..)
  , defaultZeroMQParameters
  -- * Internals
  -- * Design
  ) where

import           Control.Applicative
import           Control.Concurrent
       ( yield
       )
import           Control.Concurrent.Chan
import           Control.Concurrent.MVar
import           Control.Concurrent.STM
import           Control.Concurrent.STM.TMChan
import           Control.Exception
      ( try
      , IOException
      )
import           Control.Monad
      ( when
      , void
      )
import           Control.Monad.IO.Class

import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as B8
import           Data.IORef
import           Data.Maybe
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Void
import           Data.Word

import Network.Transport
import qualified System.ZMQ4.Monadic as ZMQ

-- | Parameters for ZeroMQ connection
data ZeroMQParameters = ZeroMQParameters

defaultZeroMQParameters :: ZeroMQParameters
defaultZeroMQParameters = ZeroMQParameters

-- =========================================================================== 
-- =    Internal datatypes                                                   =
-- ===========================================================================

-- | Transport data type.
data ZeroMQTransport = ZeroMQTransport
    { _transportAddress :: !ByteString              -- ^ Transport address (used as identifier).
    , _transportState   :: !(MVar TransportState)   -- ^ Internal state.
    }

-- | Transport state.
data TransportState
      = TransportValid !ValidTransportState         -- ^ Transport is in active state.
      | TransportClosed                             -- ^ Transport is closed.

-- XXX: can we reopen transport?


-- XXX: we may want to introduce a new level of indirection: socket -> endpoint

-- | Transport state.
data ValidTransportState = ValidTransportState
      { _localEndPoints :: !(Map EndPointAddress LocalEndPoint) -- ^ List of local Endpoints.
      , _nextEndPoint   :: !Word32                              -- ^ Endpoint counter.
      }

-- XXX: when incrementing endpoint we need to check that we have no node
-- with that address.

data LocalEndPoint
      = LocalEndPointValid !ValidLocalEndPointState
      | LocalEndPointClosed

data ValidLocalEndPointState = ValidLocalEndPointState
      { _localNextConnOutId :: !Word32
      , _nextConnInId       :: !Word32
      , _localConnections   :: !(Map EndPointAddress RemoteEndPoint)
      }

data RemoteEndPoint = RemoteEndPoint
      { remoteAddress   :: !EndPointAddress
      , remoteState     :: !(MVar RemoteState)
      , remoteId        :: !Word32
      }


data RemoteState
      = RemoteEndPointInvalid !(TransportError ConnectErrorCode)
      | RemoteEndPointInit 
      | RemoteEndPointValid   !ValidRemoteEndPointState
      | RemoteEndPointClosing !ValidRemoteEndPointState
      | RemoteEndPointFailed  !IOException

data ValidRemoteEndPointState = ValidRemoteEndPointState


data ZMQMessage = 
        MessageConnect
      | MessageOk
      | MessageInitConnection !Reliability !EndPointAddress
      | MessageCloseConnection
      | ZMQMessage !ByteString


createTransport :: ZeroMQParameters
                -> ByteString
                -> IO (Either (TransportError Void) Transport)
createTransport _params addr = do
    transport <- ZeroMQTransport 
                    <$> pure addr
                    <*> newMVar (TransportValid (ValidTransportState M.empty 0))
    try $ do
      needContinue <- newIORef True
      void $ ZMQ.runZMQ $ ZMQ.async $ do
        router <- ZMQ.socket ZMQ.Router
        ZMQ.setIdentity (ZMQ.restrict addr) router
        ZMQ.bind router (B8.unpack addr)
        repeatWhile (ZMQ.liftIO $ readIORef needContinue) $ do
          liftIO $ yield
      return $
        Transport
          { newEndPoint    = apiNewEndPoint transport
          , closeTransport = writeIORef needContinue False
          } 
  where
    repeatWhile :: MonadIO m => m Bool -> m () -> m ()
    repeatWhile f g = f >>= flip when (g >> repeatWhile f g)

apiNewEndPoint :: ZeroMQTransport -> IO (Either (TransportError NewEndPointErrorCode) EndPoint)
apiNewEndPoint transport = error "apiNewEndPoint"

apiConnect :: EndPointAddress
           -> ZeroMQTransport
           -> EndPointAddress
           -> Reliability
           -> ConnectHints
           -> IO (Either (TransportError ConnectErrorCode) Connection)
apiConnect _ourep transport _theirep _reliability _hints = error "apiConnect"

apiSend :: [ByteString] -> IO (Either (TransportError SendErrorCode) ())
apiSend = error "apiSend"

apiClose :: IO ()
apiClose = error "apiClose"
