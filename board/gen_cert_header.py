#!/usr/bin/env python3

def to_c_uint32(x):
  nums = []
  for _ in range(0x20):
    nums.append(x % (2**32))
    x //= (2**32)
  return "{" + 'U,'.join(map(str, nums)) + "U}"


def get_key_header(name):
  from Crypto.PublicKey import RSA

  public_fn = ('../certs/%s.pub' % (name))
  rsa = RSA.importKey(open(public_fn).read())
  assert(rsa.size_in_bits() == 1024)

  rr = pow(2**1024, 2, rsa.n)
  n0inv = 2**32 - pow(rsa.n, -1, 2**32)

  r = [
    f"RSAPublicKey {name}_rsa_key = {{",
    f"  .len = 0x20,",
    f"  .n0inv = {n0inv}U,",
    f"  .n = {to_c_uint32(rsa.n)},",
    f"  .rr = {to_c_uint32(rr)},",
    f"  .exponent = {rsa.e},",
    f"}};",
  ]
  return r

certs = [get_key_header(n) for n in ["debug", "release"]]
with open("obj/cert.h", "w") as f:
  for cert in certs:
    f.write("\n".join(cert) + "\n")
