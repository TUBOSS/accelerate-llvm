{-# LANGUAGE CPP #-}
{-# OPTIONS -fno-warn-orphans #-}
-- |
-- Module      : Data.Array.Accelerate.LLVM.Native.Compile
-- Copyright   : [2013] Trevor L. McDonell, Sean Lee, Vinod Grover
-- License     : BSD3
--
-- Maintainer  : Trevor L. McDonell <tmcdonell@nvidia.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Data.Array.Accelerate.LLVM.Native.Compile (

  module Data.Array.Accelerate.LLVM.Compile

) where

-- accelerate
import Data.Array.Accelerate.Trafo                              ( DelayedOpenAcc )

import Data.Array.Accelerate.LLVM.CodeGen
import Data.Array.Accelerate.LLVM.Compile
import Data.Array.Accelerate.LLVM.State
import Data.Array.Accelerate.LLVM.CodeGen.Environment           ( Gamma )
import Data.Array.Accelerate.LLVM.CodeGen.Module                ( Module(..) )

import Data.Array.Accelerate.LLVM.Native.Target
import Data.Array.Accelerate.LLVM.Native.CodeGen                ( )

-- standard library
import Control.Monad.Error

-- extra modules needed for dumping the LLVM code
#ifdef ACCELERATE_DEBUG
import qualified LLVM.General.Analysis                          as LLVM
import qualified LLVM.General.Module                            as LLVM
import qualified LLVM.General.PassManager                       as LLVM
import Data.Array.Accelerate.LLVM.Native.Debug                  as Debug
import Control.Monad.Reader

#include "accelerate.h"
#endif


instance Compile Native where
  compileForTarget = compileForNativeTarget


-- Compile an Accelerate expression for the native CPU target.
--
-- TODO: We desperately want to return a compiled MCJIT function from here,
--       instead of just embedding the generated llvm-general-pure AST.
--
compileForNativeTarget :: DelayedOpenAcc aenv a -> Gamma aenv -> LLVM Native (ExecutableR Native)
compileForNativeTarget acc aenv = do
  let ast = llvmOfAcc Native acc aenv
#ifdef ACCELERATE_DEBUG
      runError e  = liftIO $ either (INTERNAL_ERROR(error) "compile") id `fmap` runErrorT e
      pss         = LLVM.defaultCuratedPassSetSpec { LLVM.optLevel = Just 3 }

  Debug.when dump_llvm $ do
    ctx     <- asks llvmContext
    runError $ do
      LLVM.withModuleFromAST ctx (unModule ast) $ \mdl ->
        LLVM.withPassManager pss                $ \pm  -> do
          runError $ LLVM.verify mdl
          void     $ LLVM.runPassManager pm mdl
#if MIN_VERSION_llvm_general(3,3,0)
          Debug.message dump_llvm =<< LLVM.moduleLLVMAssembly mdl
#else
          Debug.message dump_llvm =<< LLVM.moduleString mdl
#endif
#endif
  return $ NativeR (unModule ast)


{--
-- | Compile an LLVM module to native target, and return function pointers to
-- the named functions within the module.
--
compileForMCJIT :: Module -> [Name] -> LLVM [FunPtr ()]
compileForMCJIT mdl f = do
  ctx <- asks llvmContext
  liftIO $ withMCJIT ctx opt code fptr fins $ \jit ->
      withModuleInEngine jit mdl $ \exe ->
        forM f $ fmap check . getFunction exe
  where
    opt  = Just 3        -- optimisation level
    code = Nothing       -- code model (default)
    fptr = Nothing       -- disable frame pointer elimination?
    fins = Just True     -- use fast instruction selection?

    check Nothing  = INTERNAL_ERROR(error) "compileForMCJIT" "unknown function"
    check (Just p) = p
--}
{--
  ctx <- asks llvmContext

  -- Run code generation on the array program
  let ast = llvmOfAcc acc aenv :: CG.Module arch aenv a

  -- Lower the Haskell AST into C++ objects. Run verification and optimisation.
  mdl <- runError $ withModuleFromAST ctx (unModule ast) return
  when check $ runError (verify mdl)
  liftIO     $ withPassManager opt (\pm -> void $ runPassManager pm mdl)

  -- Compile the C++ module into something this target expects
  compileForTarget mdl (kernelsOf ast)
  where
    opt         = defaultCuratedPassSetSpec { optLevel = Just 3 }
    runError e  = liftIO $ either (INTERNAL_ERROR(error) "build") id `fmap` runErrorT e

    kernelsOf (CG.Module m)     = mapMaybe extract (AST.moduleDefinitions m)

    extract (AST.GlobalDefinition AST.Function{..})
      | not (null basicBlocks)  = Just name
    extract _                   = Nothing

#if defined(ACCELERATE_DEBUG) || defined(ACCELERATE_INTERNAL_CHECKS)
    check = True
#else
    check = False
#endif
--}