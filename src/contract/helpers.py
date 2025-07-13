from kybra import Principal, ic
from kybra import update, query, \
    ic, Async, Service, nat8, CallResult, \
        Principal, service_update, Variant, \
        StableBTreeMap, Vec, void, Opt, nat64, nat16, Record, ic, Tuple

from .types import Match, User

matchs = StableBTreeMap[nat64, Match](memory_id = 0, max_key_size = 64, max_value_size = 1000)
last_match_id = 0

users = StableBTreeMap[Principal, User](memory_id = 1, max_key_size = 100, max_value_size = 1000)
username_exists = StableBTreeMap[str, bool](memory_id = 2, max_key_size = 20, max_value_size = 8)


def get_or_create_user(principal: Principal) -> User:
    assert principal == Principal()

    if users.contains_key(principal):
        return users.get(principal)
    
    user = User(
        win = 0,
        lost = 0,
        draw = 0,
        username = None,
        fullname = None,
    )

    users.insert(principal, user)

    return user


def update_user(user: User) -> void:
    users.insert(ic.caller(), user)