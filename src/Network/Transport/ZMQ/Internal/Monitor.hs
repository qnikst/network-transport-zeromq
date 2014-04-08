-- |
-- Copyright: (C) 2014 EURL Tweag
--
module Network.Transport.ZMQ.Internal.Monitor
    where

import            Control.Applicative
import            Control.Monad
      ( forever )
import            Control.Monad.Catch
      ( bracket )
import            System.ZMQ4 as ZMQ
import            System.ZMQ4.Internal
import            System.ZMQ4.Base
import            System.ZMQ4.Error
import            Foreign

-- | Run monitor thread.
monitorThread :: Context -> String -> (EventMsg -> IO ()) -> IO ()
monitorThread ctx addr f =
    bracket (socket ctx Router >>= \s -> bind s addr >> return s)
            (close)
            (\s ->
                bracket
                  messageInit
                  messageClose
                  (forever . (go s))
            )
    where
      go :: Receiver a => Socket a -> Message -> IO ()
      go z m = onSocket "recv" z $ \s -> do
          throwIfMinus1RetryMayBlock_ "retry"
                (c_zmq_recvmsg s (msgPtr m) (flagVal dontWait))
                (waitRead z)
          ptr <- c_zmq_msg_data (msgPtr m)
          f =<< eventMessage <$> receive z
                             <*> peek ptr
