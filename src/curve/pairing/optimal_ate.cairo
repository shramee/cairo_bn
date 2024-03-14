use core::debug::PrintTrait;
use bn::traits::{MillerPrecompute, MillerSteps};
use bn::fields::{Fq12, Fq12Utils, Fq12Exponentiation};
use bn::curve::{groups, pairing::optimal_ate_impls};
use groups::{g1, g2, ECGroup};
use groups::{Affine, AffineG1, AffineG2, AffineOps};
use bn::curve::{six_t_plus_2_naf_rev_trimmed, FIELD};
use bn::fields::{print, FieldUtils, FieldOps, fq, Fq, Fq2, Fq6};
use optimal_ate_impls::{SingleMillerPrecompute, SingleMillerSteps};

// Pairing Implementation Revisited - Michael Scott
//
// The implementation below is the algorithm described below in a single loop.
//
//
// Algorithm 2: Calculate and store line functions for BLS12 curve Input: Q ∈ G2, P ∈ G1, curve parameter u
// Output: An array g of ⌊log2(u)⌋ line functions ∈ Fp12
// 1: T←Q
// 2: for i ← ⌊log2(u)⌋−1 to 0 do
// 3:     g[i] ← lT,T(P), T ← 2T
// 4:     if ui =1then
// 5:         g[i] ← g[i].lT,Q(P), T ← T + Q return g
//
// Algorithm 3: Miller loop for BLS12 curve
// Input: An array g of ⌊log2(u)⌋ line functions ∈ Fp12 Output: f ∈ Fp12
// 1: f ← 1
// 2: for i ← ⌊log2(u)⌋−1 to 0 do
// 3:     f ← f^2 . g[i]
// 4: return f
//
// -------------------------------------------------------------------------
//
// The algo below is effectively this:
// 1: f ← 1
// 2: for i ← ⌊log2(u)⌋−1 to 0 do
// 3:     f ← f^2
// 4:     Compute g[i] and mul with f based on the bit value
// 5: return f
// 
fn ate_miller_loop<
    TG1,
    TG2,
    TPreC,
    +MillerPrecompute<TG1, TG2, TPreC>,
    +MillerSteps<TPreC, TG2, Fq12>,
    +Drop<TG1>,
    +Drop<TG2>,
    +Drop<TPreC>,
>(
    p: TG1, q: TG2
) -> Fq12 {
    core::internal::revoke_ap_tracking();
    let field_nz = FIELD.try_into().unwrap();
    let (precompute, mut q_acc) = (p, q).precompute(field_nz);
    let precompute = @precompute; // To avoid copying, use snapshot var
    let mut f = precompute.miller_first_second(ref q_acc);
    let mut array_items = six_t_plus_2_naf_rev_trimmed();

    loop {
        match array_items.pop_front() {
            Option::Some((
                b1, b2
            )) => {
                f = f.sqr();
                if b1 {
                    if b2 {
                        precompute.miller_bit_p(ref q_acc, ref f);
                    } else {
                        precompute.miller_bit_n(ref q_acc, ref f);
                    }
                } else {
                    precompute.miller_bit_o(ref q_acc, ref f);
                }
            //
            },
            Option::None => { break; }
        }
    };
    precompute.miller_last(ref q_acc, ref f);
    f
}

fn ate_pairing<
    TG1,
    TG2,
    TPreC,
    +MillerPrecompute<TG1, TG2, TPreC>,
    +MillerSteps<TPreC, TG2, Fq12>,
    +Drop<TG1>,
    +Drop<TG2>,
    +Drop<TPreC>,
>(
    p: TG1, q: TG2
) -> Fq12 {
    ate_miller_loop(p, q).final_exponentiation()
}

fn single_ate_pairing(p: AffineG1, q: AffineG2) -> Fq12 {
    ate_miller_loop(p, q).final_exponentiation()
}
