from ic.principal import Principal
from ic.identity import Identity

i = Identity()

pubkey, signature = i.sign(b'salis')

print(Principal.self_authenticating(pubkey))
