{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}

module Week05.Homework2 where

import           Control.Monad          hiding (fmap)
import qualified Data.Map               as Map
import           Data.Text              (Text)
import           Data.Void              (Void)
import           Plutus.Contract        as Contract
import           Plutus.Trace.Emulator  as Emulator
import qualified PlutusTx
import           PlutusTx.Prelude       hiding (Semigroup(..), unless)
import           Ledger                 hiding (mint, singleton)
import           Ledger.Constraints     as Constraints
import qualified Ledger.Typed.Scripts   as Scripts
import           Ledger.Value           as Value
import           Playground.Contract    (printJson, printSchemas, ensureKnownCurrencies, stage, ToSchema)
import           Playground.TH          (mkKnownCurrencies, mkSchemaDefinitions)
import           Playground.Types       (KnownCurrency (..))
import           Prelude                (IO, Semigroup (..), Show (..), String, undefined)
import           Text.Printf            (printf)
import           Wallet.Emulator.Wallet

{-# INLINABLE mkPolicy #-}
-- Minting policy for an NFT, where the minting transaction must consume the given UTxO as input
-- and where the TokenName will be the empty ByteString.
mkPolicy :: TxOutRef -> () -> ScriptContext -> Bool
mkPolicy oref () ctx = traceIfFalse "given UTxO not consumed" givenUtxoConsumed           &&
                       traceIfFalse "token name is not empty ByteString" tokenNameCorrect
  where
    info :: TxInfo
    info = scriptContextTxInfo

    givenUtxoConsumed :: Bool
    givenUtxoConsumed = any (\x -> txInInfoOutRef x == oref) $ txInfoInputs ctx

    tokenNameCorrect :: Bool
    tokenNameCorrect = case flattenValue (txInfoMint ctx) of
      [(cs, tn, amt)] -> cs  == ownCurrencySymbol ctx && tn == (TokenName emptyByteString) && amt == 1
        _                -> False

policy :: TxOutRef -> Scripts.MintingPolicy
policy oref = mkMintingPolicyScript $
  $$(PlutusTx.compile [|| \oref' deadline' -> Scripts.wrapMintingPolicy $ mkPolicy oref' deadline' ||])
  `PlutusTx.applyCode`
  PlutusTx.liftCode oref


curSymbol :: TxOutRef -> CurrencySymbol
curSymbol oref = scriptCurrencySymbol $ policy oref

type NFTSchema = Endpoint "mint" ()

mint :: Contract w NFTSchema Text ()
mint = 

endpoints :: Contract () NFTSchema Text ()
endpoints = mint' >> endpoints
  where
    mint' = endpoint @"mint" >> mint

mkSchemaDefinitions ''NFTSchema

mkKnownCurrencies []

test :: IO ()
test = runEmulatorTraceIO $ do
    h1 <- activateContractWallet (Wallet 1) endpoints
    h2 <- activateContractWallet (Wallet 2) endpoints
    callEndpoint @"mint" h1 ()
    callEndpoint @"mint" h2 ()
    void $ Emulator.waitNSlots 1
