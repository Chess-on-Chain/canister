import chess_types
from kybra import StableBTreeMap, Vec, blob

Principal = chess_types.Principal
User = chess_types.User
Match = chess_types.Match

# menggunakan heap memory karena data ini tidak perlu di-persistance
# data akan menjadi kosong ketika di-restart atau di-upgrade
active_matchs: dict[str, tuple[str, str]] = {}

matchs = StableBTreeMap[str, Match](memory_id = 0, max_key_size = 96, max_value_size = 1000)

# matchs: DictState[str, Match] = DictState()

users = StableBTreeMap[Principal, User](memory_id = 1, max_key_size = 100, max_value_size = 1000)

# users: PrincipalKeyDataState[User] = PrincipalKeyDataState()

# username_exists = StableBTreeMap[str, bool](memory_id = 2, max_key_size = 20, max_value_size = 8)

# username_exists: DictState[str, bool] = DictState()

histories = StableBTreeMap[Principal, Vec[str]](memory_id = 3, max_key_size = 100, max_value_size = 10000)

# histories: PrincipalKeyDataState[Vec[str]] = PrincipalKeyDataState()

# owner = Principal(bytes(3))
otw_owner = Principal(bytes(4))

stable = StableBTreeMap[str, blob](memory_id = 4, max_key_size = 20, max_value_size = 1000)