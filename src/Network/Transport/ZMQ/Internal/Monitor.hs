-- |
-- Copyright: (C) 2014 EURL Tweag
--
{-# LANGUAGE DeriveGeneric #-}
module Network.Transport.ZMQ.Internal.Monitor
    where

import            Control.Applicative
import            Control.Concurrent.Async
import            Control.Monad
      ( forever 
      , unless
      )
import            Control.Monad.Catch
      ( bracket )
import            Data.Binary
import qualified  Data.ByteString.Lazy as BL
import            System.ZMQ4 as ZMQ
import            System.ZMQ4.Internal
import            System.ZMQ4.Base hiding (null)
import            System.ZMQ4.Error
import            Foreign
import            GHC.Generics (Generic)

data MonitorControl = MonitorNew String
                    | MonitorDelete String
                    deriving (Generic)

instance Binary MonitorControl

monitorThread :: Context -> String -> (EventMsg -> IO ()) -> IO (Socket Pair, Async ())
monitorThread ctx addr f = 
  (,) <$> (socket ctx Pair >>= \s -> bind s addr >> return s)
      <*> (async $ bracket (socket ctx Pair >>= \s -> connect s addr >> return s)
                  (close)
                 $ \control -> bracket (socket ctx Router)
                                       (close)
                 $ \evs -> bracket messageInit
                                      messageClose
                 $ \msg -> forever $ do
                     [cEv,eEv] <- ZMQ.poll 0 [ Sock control [In] Nothing
                                             , Sock evs  [In] Nothing
                                             ]
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
        f =<< eventMessage <$> receive evs
                           <*> peek ptr
