from ic import Identity,Principal
import hashlib

ii = Identity()

print(ii.sender())

pubkey, signature = ii.sign(b'mantap')

from ecdsa import VerifyingKey

vk = VerifyingKey.from_der(pubkey, hashfunc = hashlib.sha256)
print(vk.verify(signature, b'mantap'))