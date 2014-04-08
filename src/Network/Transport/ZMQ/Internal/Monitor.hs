-- |
-- Copyright: (C) 2014 EURL Tweag
--
{-# LANGUAGE DeriveGeneric #-}
module Network.Transport.ZMQ.Internal.Monitor
    ( monitorThread 
    , MonitorControl(..)
    ) where

import            Control.Applicative
import            Control.Concurrent.Async
import            Control.Monad
      ( forever 
      , unless
      , void
      )
import            Control.Monad.Catch
      ( bracket 
      , try
      , MonadCatch
      )
import		  Control.Exception
      ( SomeException )
import            Data.Binary
import qualified  Data.ByteString.Lazy as BL
import            System.ZMQ4 as ZMQ
import            System.ZMQ4.Internal
import            System.ZMQ4.Base hiding (null)
import            System.ZMQ4.Error
import            Foreign hiding (void)
import            GHC.Generics (Generic)

data MonitorControl = MonitorNew String
                    | MonitorDelete String
                    deriving (Generic, Show)

instance Binary MonitorControl

monitorThread :: Context -> String -> (EventMsg -> IO ()) -> IO (Socket Pair, Async ())
monitorThread ctx addr f = 
  (,) <$> (socket ctx Pair >>= \s -> bind s addr >> return s)
      <*> (async $ bracket (socket ctx Pair >>= \s -> connect s addr >> return s)
                  (close)
                 $ \control -> bracket (socket ctx Pull)
                                       (close)
                 $ \evs -> bracket messageInit
                                      messageClose
                 $ \msg -> do
		     forever $ do
                        [eEv,cEv] <- ZMQ.poll (-1) [ Sock evs  [In] Nothing
                                                   , Sock control  [In] Nothing
                                                   ]
		        print (eEv,cEv)
                        unless (null cEv) $ processControl evs control
                        unless (null eEv) $ processEvent   evs msg)
  where
    processControl evs socket = do
        msg <- receive socket
        case decode (BL.fromChunks [msg]) of
          MonitorNew addr -> do
              connect evs addr
          MonitorDelete addr -> do
              disconnect evs addr
    processEvent evs m = onSocket "read" evs $ \s -> do
        throwIfMinus1RetryMayBlock_ "retry"
              (c_zmq_recvmsg s (msgPtr m) (flagVal dontWait))
              (waitRead evs)
        ptr <- c_zmq_msg_data (msgPtr m)
	void . trySome $ f =<< eventMessage <$> receive evs
                                            <*> peek ptr

trySome :: MonadCatch m => m a -> m (Either SomeException a)
trySome = try
