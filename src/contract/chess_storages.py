import chess_types
from kybra import Principal, StableBTreeMap, Vec

User = chess_types.User
Match = chess_types.Match

matchs = StableBTreeMap[str, Match](memory_id = 0, max_key_size = 96, max_value_size = 1000)
users = StableBTreeMap[Principal, User](memory_id = 1, max_key_size = 100, max_value_size = 1000)
username_exists = StableBTreeMap[str, bool](memory_id = 2, max_key_size = 20, max_value_size = 8)
histories = StableBTreeMap[Principal, Vec[str]](memory_id = 3, max_key_size = 100, max_value_size = 10000)

owner = Principal(bytes(3))
otwOwner = Principal(bytes(4))