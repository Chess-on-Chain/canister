import chess_types
from kybra import Principal, StableBTreeMap, ic, nat64, void

User = chess_types.User
Match = chess_types.Match

matchs = StableBTreeMap[nat64, Match](memory_id = 0, max_key_size = 64, max_value_size = 1000)
users = StableBTreeMap[Principal, User](memory_id = 1, max_key_size = 100, max_value_size = 1000)
username_exists = StableBTreeMap[str, bool](memory_id = 2, max_key_size = 20, max_value_size = 8)


def get_or_create_user(principal: Principal) -> User:
    assert principal != Principal(), "Zero address"

    if users.contains_key(principal):
        user = users.get(principal)
        assert not user['is_banned'], "User has been banned"
        return user
            
    user = User(
        id = principal,
        win = 0,
        lost = 0,
        draw = 0,
        username = None,
        fullname = None,
        is_banned = False
    )

    users.insert(principal, user)

    return user


def update_user(user: User) -> void:
    users.insert(ic.caller(), user)