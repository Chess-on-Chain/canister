import random
import re

import chess_helpers as helpers
import chess_types
from kybra import Principal, Tuple, Vec, ic, nat16, nat64, query, update, void

User = chess_types.User
Match = chess_types.Match

last_match_id: nat64 = 0
owner = ic.caller()

# class Chess(Service):
#     @service_update
#     def status(self, fen: str) -> nat8:
#         ...

# chess = Chess(Principal.from_str('uzt4z-lp777-77774-qaabq-cai'))

INITIAL_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

@update
def set_username(new_username: str) -> void:
    user = helpers.get_or_create_user(ic.caller())

    if user['username'] != None:
        raise ValueError("username already set")
    
    if helpers.username_exists.contains_key(new_username):
        raise ValueError("username already exists")
    
    if not re.match(r'[a-z0-9_]{3,20}', new_username):
        raise ValueError("username not valid")
    
    helpers.username_exists.insert(new_username, True)
    user['username'] = new_username
    helpers.update_user(user)


@update
def set_name(fullname: str) -> void:
    user = helpers.get_or_create_user(ic.caller())
    user['fullname'] = fullname
    helpers.update_user(user)


@update
def add_match(principalA: Principal, principalB: Principal) -> Tuple[nat64, Match]:
    global last_match_id

    if ic.caller() != owner:
        raise Exception("Forbidden")

    last_match_id += 1

    users_ = [
        helpers.get_or_create_user(principalA),
        helpers.get_or_create_user(principalB)
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

    helpers.matchs.insert(last_match_id, match_)

    return (last_match_id, match_)


@update
def add_match_move(match_id: nat64, move: nat16) -> void:
    match_ = helpers.matchs.get(match_id)
    if match_ is None:
        raise ValueError("match not found")
    
    if match_['winner'] != "ongoing":
        raise Exception("match already closed")

    match_['moves'].append(move)
    helpers.matchs.insert(match_id, match_)


@query
def get_match(match_id: nat64) -> Match:
    match_ = helpers.matchs.get(match_id)
    if match_ is None:
        raise ValueError("match not found")

    return match_
