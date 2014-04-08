{-# LANGUAGE OverloadedStrings #-}
module Main where

import Control.Concurrent 
import Control.Exception
import Control.Monad ( (<=<), replicateM )

import Data.IORef

import Network.Transport
import Network.Transport.ZMQ
import System.Exit

main :: IO ()
main = finish <=< trySome $ do
    putStr "simple: "
    Right (zmq, transport) <- createTransportEx defaultZMQParameters "127.0.0.1"
    putStrLn "1: ep1 <- EP"
    Right ep1 <- newEndPoint transport
    putStrLn "2: ep2 <- EP"
    Right ep2 <- newEndPoint transport
    putStrLn "3: c1 <- c ep1->ep2"
    Right c1  <- connect ep1 (address ep2) ReliableOrdered defaultConnectHints
    putStrLn "4: c2 <- c ep2->ep1"
    Right c2  <- connect ep2 (address ep1) ReliableOrdered defaultConnectHints
    putStrLn "5: send c1"
    Right _   <- send c1 ["123"]
    putStrLn "6: send c2"
    Right _   <- send c2 ["321"]
    putStrLn "7: close c1"
    close c1
    putStrLn "8: close c2"
    close c2
    putStrLn "9: events.."
    [ConnectionOpened 1 ReliableOrdered _, Received 1 ["321"], ConnectionClosed 1] <- replicateM 3 $ receive ep1
    putStrLn "10: events.."
    [ConnectionOpened 1 ReliableOrdered _, Received 1 ["123"], ConnectionClosed 1] <- replicateM 3 $ receive ep2
    putStrLn "11"
    putStrLn "OK"

    putStr "connection break: "
    Right ep3 <- newEndPoint transport
    putStrLn "12: ep3 <- EP"

    putStrLn "12.5: c21: ep1 -> ep2"
    Right c21  <- connect ep1 (address ep2) ReliableOrdered defaultConnectHints
    putStrLn "13: c22: ep2 -> ep1"
    Right c22  <- connect ep2 (address ep1) ReliableOrdered defaultConnectHints
    putStrLn "14: c23: ep3 -> ep1"
    Right c23  <- connect ep3 (address ep1) ReliableOrdered defaultConnectHints
    putStrLn "15"

    ConnectionOpened 2 ReliableOrdered _ <- receive ep2
    putStrLn "16"
    ConnectionOpened 2 ReliableOrdered _ <- receive ep1
    putStrLn "17"
    ConnectionOpened 3 ReliableOrdered _ <- receive ep1
    putStrLn "18"

    breakConnection zmq (address ep1) (address ep2)
    putStrLn "19"

    ErrorEvent (TransportError (EventConnectionLost _ ) _) <- receive $ ep1
    putStrLn "20"
    ErrorEvent (TransportError (EventConnectionLost _ ) _) <- receive $ ep2
    putStrLn "21"

    Left (TransportError SendFailed _) <- send c21 ["test"]
    putStrLn "22"
    Left (TransportError SendFailed _) <- send c22 ["test"]
    putStrLn "23"

    Left (TransportError SendFailed _) <- send c23 ["test"]
    putStrLn "24"
    ErrorEvent (TransportError (EventConnectionLost _) _ ) <- receive ep1
    putStrLn "25: c24: ep3 -> ep1"
    Right c24 <- connect ep3 (address ep1) ReliableOrdered defaultConnectHints
    putStrLn "26"
    Right ()  <- send c24 ["final"]
    putStrLn "27"
    ConnectionOpened 4 ReliableOrdered _ <- receive ep1
    putStrLn "28"
    Received 4 ["final"] <- receive ep1
    putStrLn "29"
    putStrLn "OK"
    multicast transport
    putStr "Register cleanup test:"
    Right (zmq1, transport1) <- createTransportEx defaultZMQParameters "127.0.0.1"
    x <- newIORef 0
    Just _ <- registerCleanupAction zmq1 (modifyIORef x (+1))
    Just u <- registerCleanupAction zmq1 (modifyIORef x (+1))
    applyCleanupAction zmq u
    closeTransport transport1
    2 <- readIORef x
    putStrLn "OK"
  where
      multicast transport = do 
        Right ep1 <- newEndPoint transport
        Right ep2 <- newEndPoint transport
        putStr "multicast: "
        Right g1 <- newMulticastGroup ep1
        multicastSubscribe g1
        threadDelay 1000000
        multicastSend g1 ["test"]
        ReceivedMulticast _ ["test"] <- receive ep1
        Right g2 <- resolveMulticastGroup ep2 (multicastAddress g1)
        multicastSubscribe g2
        threadDelay 100000
        multicastSend g2 ["test-2"]
        ReceivedMulticast _ ["test-2"] <- receive ep2
        ReceivedMulticast _ ["test-2"] <- receive ep1
        putStrLn "OK"
        
        putStr "Auth:"
        Right tr2 <- createTransport
                       defaultZMQParameters {authorizationType=ZMQAuthPlain "user" "password"}
                       "127.0.0.1"
        Right ep3 <- newEndPoint tr2
        Right ep4 <- newEndPoint tr2
        Right c3  <- connect ep3 (address ep4) ReliableOrdered defaultConnectHints
        Right _   <- send c3 ["4456"]
        [ConnectionOpened 1 ReliableOrdered _, Received 1 ["4456"]] <- replicateM 2 $ receive ep4
        Right c4  <- connect ep3 (address ep4) ReliableOrdered defaultConnectHints
        Right _   <- send c4 ["5567"]
        [ConnectionOpened 2 ReliableOrdered _, Received 2 ["5567"]] <- replicateM 2 $ receive ep4
        putStrLn "OK"

        putStr "Connect to non existing host: "
        Left (TransportError ConnectFailed _) <- connect ep3 (EndPointAddress "tcp://128.0.0.1:7689") ReliableOrdered defaultConnectHints
        putStrLn "OK"
      finish (Left e) = print e >> exitWith (ExitFailure 1)
      finish Right{} = exitWith ExitSuccess


trySome :: IO a -> IO (Either SomeException a)
trySome = try

forkTry :: IO () -> IO ThreadId
forkTry = forkIO
