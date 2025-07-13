from kybra import update, query, \
    ic, Async, Service, nat8, CallResult, \
        Principal, service_update, Variant, \
        StableBTreeMap, Vec, void, Opt, nat64, nat16, Record, ic, Tuple

import random, re


# class Chess(Service):
#     @service_update
#     def status(self, fen: str) -> nat8:
#         ...

# chess = Chess(Principal.from_str('uzt4z-lp777-77774-qaabq-cai'))

INITIAL_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"


class User(Record):
    win: nat16
    lost: nat16
    draw: nat16
    username: Opt[str]
    fullname: Opt[str]


class Match(Record):
    whitePlayer: User
    blackPlayer: User
    moves: Vec[nat16]
    fen: str
    is_white_turn: bool
    winner: str # Literal['white', 'black', 'draw', 'ongoing']


matchs = StableBTreeMap[nat64, Match](memory_id = 0, max_key_size = 64, max_value_size = 1000)
last_match_id = 0

users = StableBTreeMap[Principal, User](memory_id = 1, max_key_size = 100, max_value_size = 1000)
username_exists = StableBTreeMap[str, bool](memory_id = 2, max_key_size = 20, max_value_size = 8)

owner: Principal = ic.caller()

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

@update
def set_username(new_username: str) -> void:
    user = get_or_create_user(ic.caller())

    if user['username'] != None:
        raise ValueError("username already set")
    
    if username_exists.contains_key(new_username):
        raise ValueError("username already exists")
    
    if not re.match(r'[a-z0-9_]{3,20}', new_username):
        raise ValueError("username not valid")
    
    username_exists.insert(new_username, True)
    user['username'] = new_username
    update_user(user)


@update
def set_name(fullname: str) -> void:
    user = get_or_create_user(ic.caller())
    user['fullname'] = fullname
    update_user(user)


@update
def add_match(principalA: Principal, principalB: Principal) -> Tuple[nat64, Match]:
    global last_match_id

    if ic.caller() != owner:
        raise Exception("Forbidden")

    last_match_id += 1

    users_ = [
        get_or_create_user(principalA),
        get_or_create_user(principalB)
    ]
    
    random.shuffle(users_)

    userA, userB = users_

    match_ = Match(
        whitePlayer = userA,
        blackPlayer = userB,
        moves = Vec(),
        fen = INITIAL_FEN,
        is_white_turn = True,
        winner = "ongoing"
    )

    matchs.insert(last_match_id, match_)

    return (last_match_id, match_)


@update
def add_match_move(match_id: nat64, move: nat16) -> void:
    match_ = matchs.get(match_id)
    if match_ is None:
        raise ValueError("match not found")
    
    if match_['winner'] != "ongoing":
        raise Exception("match already closed")

    match_['moves'].append(move)
    matchs.insert(match_id, match_)


@query
def get_match(match_id: nat64) -> Match:
    match_ = matchs.get(match_id)
    if match_ is None:
        raise ValueError("match not found")

    return match_
