use bn::{fq_non_residue, fq2_non_residue};
use bn::traits::FieldOps;
use bn::fields::fq_generics::{TFqAdd, TFqSub, TFqMul, TFqDiv, TFqNeg, TFqPartialEq,};
use bn::fields::{Fq, fq,};

#[derive(Copy, Drop, Serde)]
struct Fq2 {
    c0: Fq,
    c1: Fq,
}

// Extension field is represented as two number with X (a root of an polynomial in Fq which doesn't exist in Fq).
// X for field extension is equivalent to imaginary i for real numbers.
// number a: Fq2 = (a0, a1), mathematically, a = a0 + a1 * X

#[inline(always)]
fn fq2(c0: u256, c1: u256) -> Fq2 {
    Fq2 { c0: fq(c0), c1: fq(c1), }
}

#[generate_trait]
impl Fq2Ops2 of Fq2OpsTrait {
    fn scale(self: Fq2, by: Fq) -> Fq2 {
        Fq2 { c0: self.c0 * by, c1: self.c1 * by, }
    }

    fn mul_by_non_residue(self: Fq2,) -> Fq2 {
        self * fq2_non_residue()
    }

    fn frobenius_map(self: Fq2, power: usize) -> Fq2 {
        if power % 2 == 0 {
            self
        } else {
            Fq2 { c0: self.c0, c1: self.c1 * fq_non_residue(), }
        }
    }
}

impl Fq2Ops of FieldOps<Fq2> {
    #[inline(always)]
    fn add(self: Fq2, rhs: Fq2) -> Fq2 {
        Fq2 { c0: self.c0 + rhs.c0, c1: self.c1 + rhs.c1, }
    }

    #[inline(always)]
    fn sub(self: Fq2, rhs: Fq2) -> Fq2 {
        Fq2 { c0: self.c0 - rhs.c0, c1: self.c1 - rhs.c1, }
    }

    #[inline(always)]
    fn mul(self: Fq2, rhs: Fq2) -> Fq2 {
        let Fq2{c0: a0, c1: a1 } = self;
        let Fq2{c0: b0, c1: b1 } = rhs;
        // Multiplying ab in Fq2 mod X^2 + BETA
        // c = ab = a0*b0 + a0*b1*X + a1*b0*X + a0*b0*BETA
        // c = a0*b0 + a0*b0*BETA + (a0*b1 + a1*b0)*X
        // or c = (a0*b0 + a0*b0*BETA, a0*b1 + a1*b0)
        Fq2 { //
         c0: a0 * b0 + a1 * b1 * fq_non_residue(), //
         c1: a0 * b1 + a1 * b0, //
         }
    }

    #[inline(always)]
    fn div(self: Fq2, rhs: Fq2) -> Fq2 {
        self.mul(rhs.inv())
    }

    #[inline(always)]
    fn neg(self: Fq2) -> Fq2 {
        // @TODO
        Fq2 { c0: -self.c0, c1: -self.c1, }
    }

    #[inline(always)]
    fn eq(lhs: @Fq2, rhs: @Fq2) -> bool {
        lhs.c0 == rhs.c0 && lhs.c1 == rhs.c1
    }

    #[inline(always)]
    fn one() -> Fq2 {
        fq2(1, 0)
    }

    #[inline(always)]
    fn sqr(self: Fq2) -> Fq2 {
        let Fq2{c0: a0, c1: a1 } = self;
        // Squaring a in Fq2 mod X^2 + BETA
        // c = a ^ 2 = a0*a0 + a0*a1*X + a1*a0*X + a0*a0*BETA
        // c = a0*a0 + a0*a0*BETA + (a0*a1 + a1*a0)*X
        // or c = (a0*b0 + a0*b0*BETA, a0*b1 + a1*b0)
        let v = a0 * a1;

        Fq2 { //
         c0: a0.sqr() + a1.sqr() * fq_non_residue(), //
         c1: v + v, //
         }
    }

    #[inline(always)]
    fn inv(self: Fq2) -> Fq2 {
        // "High-Speed Software Implementation of the Optimal Ate Pairing
        // over Barreto–Naehrig Curves"; Algorithm 8
        let t = (self.c0.sqr() - (self.c1.sqr() * fq_non_residue())).inv();
        Fq2 { c0: self.c0 * t, c1: -(self.c1 * t), }
    }
}