{-# LANGUAGE CPP #-}
#if __GLASGOW_HASKELL__ >= 708
{-# LANGUAGE PatternSynonyms #-}
#endif
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE TemplateHaskell #-}

#ifndef MIN_VERSION_base
#define MIN_VERSION_base(x,y,z) 1
#endif

-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) 2014 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  experimental
-- Portability :  PatternSynonyms
--
-- Half-precision floating-point values. These arise commonly in GPU work
-- and it is useful to be able to compute them and compute with them on the
-- CPU as well.
----------------------------------------------------------------------------

module Numeric.Half
  ( Half(..)
  , isZero
  , fromHalf
  , toHalf
#if __GLASGOW_HASKELL__ >= 708
  , pattern POS_INF
  , pattern NEG_INF
  , pattern QNaN
  , pattern SNaN
  , pattern HALF_MIN
  , pattern HALF_NRM_MIN
  , pattern HALF_MAX
  , pattern HALF_EPSILON
  , pattern HALF_DIG
  , pattern HALF_MIN_10_EXP
  , pattern HALF_MAX_10_EXP
#endif
  ) where

import Control.DeepSeq (NFData)
import Data.Bits
import Data.Function (on)
import Data.Typeable
import Foreign.C.Types
import Foreign.Ptr (castPtr)
import Foreign.Storable
import GHC.Generics
import Language.Haskell.TH
import Language.Haskell.TH.Syntax
import Text.Read hiding (lift)

-- | Convert a 'Float' to a 'Half' with proper rounding, while preserving NaN and dealing appropriately with infinity
foreign import ccall unsafe "hs_floatToHalf" toHalf :: Float -> Half
-- {-# RULES "toHalf"  realToFrac = toHalf #-}

-- | Convert a 'Half' to a 'Float' while preserving NaN
foreign import ccall unsafe "hs_halfToFloat" fromHalf :: Half -> Float
-- {-# RULES "fromHalf" realToFrac = fromHalf #-}

newtype
#if __GLASGOW_HASKELL__ >= 706
  {-# CTYPE "unsigned short" #-}
#endif
  Half = Half { getHalf :: CUShort } deriving (Generic, Typeable)

instance NFData Half where

instance Storable Half where
  sizeOf = sizeOf . getHalf
  alignment = alignment . getHalf
  peek p = peek (castPtr p) >>= return . Half
  poke p = poke (castPtr p) . getHalf

instance Show Half where
  showsPrec d h = showsPrec d (fromHalf h)

instance Read Half where
  readPrec = fmap toHalf readPrec

instance Eq Half where
  (==) = (==) `on` fromHalf

instance Ord Half where
  compare = compare `on` fromHalf

instance Real Half where
  toRational = toRational . fromHalf

instance Fractional Half where
  fromRational = toHalf . fromRational
  recip = toHalf . recip . fromHalf
  a / b = toHalf $ fromHalf a / fromHalf b

instance RealFrac Half where
  properFraction a = case properFraction (fromHalf a) of
    (b, c) -> (b, toHalf c)
  truncate = truncate . fromHalf
  round = round . fromHalf
  ceiling = ceiling . fromHalf
  floor = floor . fromHalf

instance Floating Half where
  pi = toHalf pi
  exp = toHalf . exp . fromHalf
  sqrt = toHalf . sqrt . fromHalf
  log = toHalf . log . fromHalf
  a ** b = toHalf $ fromHalf a ** fromHalf b
  logBase a b = toHalf $ logBase (fromHalf a) (fromHalf b)
  sin = toHalf . sin . fromHalf
  tan = toHalf . tan . fromHalf
  cos = toHalf . cos . fromHalf
  asin = toHalf . asin . fromHalf
  atan = toHalf . atan . fromHalf
  acos = toHalf . acos . fromHalf
  sinh = toHalf . sinh . fromHalf
  tanh = toHalf . tanh . fromHalf
  cosh = toHalf . cosh . fromHalf
  asinh = toHalf . asinh . fromHalf
  atanh = toHalf . atanh . fromHalf
  acosh = toHalf . acosh . fromHalf

instance RealFloat Half where
  floatRadix  _ = 2
  floatDigits _ = 11
  decodeFloat = decodeFloat . fromHalf
  isIEEE _ = isIEEE (undefined :: Float)
  atan2 a b = toHalf $ atan2 (fromHalf a) (fromHalf b)
#if MIN_VERSION_base(4,5,0)
  isInfinite (Half h) = unsafeShiftR h 10 .&. 0x1f >= 31
  isDenormalized (Half h) = unsafeShiftR h 10 .&. 0x1f == 0 && h .&. 0x3ff /= 0
  isNaN (Half h) = unsafeShiftR h 10 .&. 0x1f == 0x1f && h .&. 0x3ff /= 0
#else
  isInfinite (Half h) = shiftR h 10 .&. 0x1f >= 31
  isDenormalized (Half h) = shiftR h 10 .&. 0x1f == 0 && h .&. 0x3ff /= 0
  isNaN (Half h) = shiftR h 10 .&. 0x1f == 0x1f && h .&. 0x3ff /= 0
#endif

  isNegativeZero (Half h) = h == 0x8000
  floatRange _ = (16,-13)
  encodeFloat i j = toHalf $ encodeFloat i j
  exponent = exponent . fromHalf
  significand = toHalf . significand . fromHalf
  scaleFloat n = toHalf . scaleFloat n . fromHalf

-- | Is this 'Half' equal to 0?
isZero :: Half -> Bool
isZero (Half h) = h .&. 0x7fff == 0

#if __GLASGOW_HASKELL__ >= 708

-- | Positive infinity
pattern POS_INF = Half 0x7c00

-- | Negative infinity
pattern NEG_INF = Half 0xfc00

-- | Quiet NaN
pattern QNaN    = Half 0x7fff

-- | Signalling NaN
pattern SNaN    = Half 0x7dff

-- | Smallest positive half
pattern HALF_MIN = Half 0x0001  -- 5.96046448e-08

-- | Smallest positive normalized half
pattern HALF_NRM_MIN = Half 0x0400  -- 6.10351562e-05

-- | Largest positive half
pattern HALF_MAX = Half 0x7bff  -- 65504.0

-- | Smallest positive e for which half (1.0 + e) != half (1.0)
pattern HALF_EPSILON = Half 0x1400  -- 0.00097656

-- | Number of base 10 digits that can be represented without change
pattern HALF_DIG = 2

-- Minimum positive integer such that 10 raised to that power is a normalized half
pattern HALF_MIN_10_EXP = -4

-- Maximum positive integer such that 10 raised to that power is a normalized half
pattern HALF_MAX_10_EXP = 4

#endif

instance Num Half where
  a * b = toHalf (fromHalf a * fromHalf b)
  a - b = toHalf (fromHalf a - fromHalf b)
  a + b = toHalf (fromHalf a + fromHalf b)
  negate (Half a) = Half (xor 0x8000 a)
  abs = toHalf . abs . fromHalf
  signum = toHalf . signum . fromHalf
  fromInteger a = toHalf (fromInteger a)

instance Lift Half where
  lift (Half (CUShort w)) = appE (conE 'Half) . appE (conE 'CUShort) . lift $ w
