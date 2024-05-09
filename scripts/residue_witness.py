# This script follows paper 'On Proving Pairings' - https://eprint.iacr.org/2024/640
# to generate residue witness for the final exponentiation.

# From 2.1 Eliminating the Final Exponentiation,
# Two elements x, y ∈ F are equivalent if there exists some c such that  x * c**r = y
# Our optimization avoids this cost by instead providing c as auxiliary input and
# directly checking xcr = y. In this way we replace an exponentiation by (q**k − 1)/r
# with an exponentiation by r, which in general is much cheaper.


# from py_ecc import bn128, fields
# from py_ecc.bn128 import bn128_curve;
from py_ecc.fields import (
    bn128_FQ as FQ,
    bn128_FQ12 as FQ12,
)


# The library we use here, py_ecc uses direct field extensions
# But Cairo implementation uses tower field extensions
# Utils for direct extension and tower extension conversions
# https://gist.github.com/feltroidprime/bd31ab8e0cbc0bf8cd952c8b8ed55bf5
def tower_to_direct(x: list):
    p = q
    res = 12 * [0]
    res[0] = (x[0] - 9 * x[1]) % p
    res[1] = (x[6] - 9 * x[7]) % p
    res[2] = (x[2] - 9 * x[3]) % p
    res[3] = (x[8] - 9 * x[9]) % p
    res[4] = (x[4] - 9 * x[5]) % p
    res[5] = (x[10] - 9 * x[11]) % p
    res[6] = x[1]
    res[7] = x[7]
    res[8] = x[3]
    res[9] = x[9]
    res[10] = x[5]
    res[11] = x[11]
    return res


def direct_to_tower(x: list):
    p = q
    res = 12 * [0]
    res[0] = (x[0] + 9 * x[6]) % p
    res[1] = x[6]
    res[2] = (x[2] + 9 * x[8]) % p
    res[3] = x[8]
    res[4] = (x[4] + 9 * x[10]) % p
    res[5] = x[10]
    res[6] = (x[1] + 9 * x[7]) % p
    res[7] = x[7]
    res[8] = (x[3] + 9 * x[9]) % p
    res[9] = x[9]
    res[10] = (x[5] + 9 * x[11]) % p
    res[11] = x[11]
    return res


# Section 4.3 Computing Residue Witness for the BN254 curve

# bn254 curve properties from https://hackmd.io/@jpw/bn254
q = 21888242871839275222246405745257275088696311157297823662689037894645226208583
x = 4965661367192848881
r = 21888242871839275222246405745257275088548364400416034343698204186575808495617
# (q**12 - 1) is the exponent of the final exponentiation

# Section 4.3.1 Parameters
h = (q**12 - 1) // r  # = 3^3 · l # where gcd(l, 3) = 1
l = h // (3**3)
λ = 6 * x + 2 + q - q**2 + q**3
m = λ // r
d = 3  # = gcd(m, h)
m_dash = m // d  # m' = m/d

# equivalently, λ = 3rm′.
assert 3 * r * m_dash == λ, "incorrect parameters"  # sanity check

# precompute r' and m''

r_inv = 495819184011867778744231927046742333492451180917315223017345540833046880485481720031136878341141903241966521818658471092566752321606779256340158678675679238405722886654128392203338228575623261160538734808887996935946888297414610216445334190959815200956855428635568184508263913274453942864817234480763055154719338281461936129150171789463489422401982681230261920147923652438266934726901346095892093443898852488218812468761027620988447655860644584419583586883569984588067403598284748297179498734419889699245081714359110559679136004228878808158639412436468707589339209058958785568729925402190575720856279605832146553573981587948304340677613460685405477047119496887534881410757668344088436651291444274840864486870663164657544390995506448087189408281061890434467956047582679858345583941396130713046072603335601764495918026585155498301896749919393
assert r_inv * r % h == 1, "r_inv should be the inverse of r"
m_d_inv = 17840267520054779749190587238017784600702972825655245554504342129614427201836516118803396948809179149954197175783449826546445899524065131269177708416982407215963288737761615699967145070776364294542559324079147363363059480104341231360692143673915822421222230661528586799190306058519400019024762424366780736540525310403098758015600523609594113357130678138304964034267260758692953579514899054295817541844330584721967571697039986079722203518034173581264955381924826388858518077894154909963532054519350571947910625755075099598588672669612434444513251495355121627496067454526862754597351094345783576387352673894873931328099247263766690688395096280633426669535619271711975898132416216382905928886703963310231865346128293216316379527200971959980873989485521004596686352787540034457467115536116148612884807380187255514888720048664139404687086409399
assert m_d_inv * m_dash % h == 1, "r_inv should be the inverse of r"

f = tower_to_direct(
    [
        0x1BF4E21820E6CC2B2DBC9453733A8D7C48F05E73F90ECC8BDD80505D2D3B1715,
        0x264F54F6B719920C4AC00AAFB3DF29CC8A9DDC25E264BDEE1ADE5E36077D58D7,
        0xDB269E3CD7ED27D825BCBAAEFB01023CF9B17BEED6092F7B96EAB87B571F3FE,
        0x25CE534442EE86A32C46B56D2BF289A0BE5F8703FB05C260B2CB820F2B253CF,
        0x33FC62C521F4FFDCB362B12220DB6C57F487906C0DAF4DC9BA736F882A420E1,
        0xE8B074995703E92A7B9568C90AE160E4D5B81AFFE628DC1D790241DE43D00D0,
        0x84E35BD0EEA3430B350041D235BB394E338E3A9ED2F0A9A1BA7FE786D391DE1,
        0x244D38253DA236F714CB763ABF68F7829EE631B4CC5EDE89B382E518D676D992,
        0x1EE0A098B62C76A9EBDF4D76C8DFC1586E3FCB6A01712CBDA8D10D07B32C5AF4,
        0xD23AEB23ACACF931F02ECA9ECEEE31EE9607EC003FF934694119A9C6CFFC4BD,
        0x16558217BB9B1BCDA995B123619808719CB8A282A190630E6D06D7D03E6333CA,
        0x14354C051802F8704939C9948EF91D89DB28FE9513AD7BBF58A4639AF347EA86,
    ]
)
f = FQ12(f)

# print("Should be one", f**h)

# Section 4.3.2 Finding c
# find some u a cubic non-residue and c such that f = c**λ * u.

# 1. Compute r-th root
# 2. Compute m′-th root
# 3. Compute cubic root

unity = FQ12([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

root_27th = FQ12(
    tower_to_direct(
        [
            0,
            0,
            0,
            0,
            8204864362109909869166472767738877274689483185363591877943943203703805152849,
            17912368812864921115467448876996876278487602260484145953989158612875588124088,
            0,
            0,
            0,
            0,
            0,
            0,
        ]
    )
)

assert root_27th**27 == unity, "root_27th**27 should be one"
assert root_27th**9 != unity, "root_27th**9 should not be one"


def find_cube_root(f: FQ12, w: FQ12) -> FQ12:
    unity


def find_c(f: FQ12, w: FQ12):
    # Algorithm 5: Algorithm for computing λ residues over BN curve
    # Input: Output of a Miller loop f and fixed 27-th root of unity w
    # Output: (c, wi) such that c**λ = f · wi
    # 1 s = 0
    s = 0
    exp = (q**12 - 1) // 3
    w = root_27th
    # 2 if f**(q**k-1)/3 = 1 then
    if f**exp == unity:
        # 3 continue
        # 4 end
        # 5 else if (f · w)**(q**k-1)/3 = 1 then
        c = f
    elif (f * w) ** exp == unity:
        # 6 s = 1
        s = 1
        # 7 f ← f · w
        c = f * w
    # 8 end
    # 9 else
    else:
        # 10 s = 2
        s = 2
        # 11 f ← f · w**2
        c = f * w * w
    # 12 end

    print("\n\nc = ", c, "\n c exp is ", c**exp)
    # 13 c ← f**r′
    c = c**r_inv
    # 14 c ← c**m′′
    c = c**m_d_inv
    # 15 c ← c**1/3 (by using modified Tonelli-Shanks 4)
    c = find_cube_root(c, w)
    # 16 return (c, ws)
    return c, w**s


print("\n\nAlgorithm 5: Algorithm for computing λ residues over BN curve")
find_c(f)