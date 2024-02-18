mod math {
    mod i257;
    mod fast_mod;
// #[cfg(test)]
// mod fast_mod_tests;
}
mod traits;
mod fields {
    mod fq_generics;
    mod fq_1;
    mod fq_2;
    mod fq_6;
    mod fq_12;
    mod frobenius;
    mod print;

    #[cfg(test)]
    mod tests { //
        // mod bench;
        // mod fq;
        mod fq2;
        mod fq6;
    // mod fq12;
    // mod frobenius;
    }
    mod fq_generics;
    use bn::fields::fq_generics::{TFqAdd, TFqSub, TFqMul, TFqDiv, TFqNeg, TFqPartialEq,};
    use bn::fields::fq_::{Fq, FqOps, FqShort, FqMulShort, FqUtils, fq};
    use bn::fields::fq2_::{Fq2, Fq2Ops, Fq2Short, Fq2MulShort, Fq2Utils, fq2};
    use bn::fields::fq6_::{Fq6, Fq6Ops, Fq6Short, Fq6MulShort, Fq6Utils, fq6, Fq6Frobenius};
    use bn::fields::fq12_::{Fq12, Fq12Ops, Fq12Utils, fq12, Fq12Frobenius};
    use bn::traits::{FieldOps, FieldUtils};
}

use bn::traits::{FieldOps, FieldUtils};
mod curve;
use math::fast_mod;
use curve::{groups as g, pairing};
// #[cfg(test)]
// mod tests;


