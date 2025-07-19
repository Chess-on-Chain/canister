import json
import pickle

import chess_helpers
import chess_storages as storages
import chess_types
from kybra import CallResult, Principal, Vec, blob, ic, void
from kybra.canisters.management import HttpResponse, management_canister

User = chess_types.User
Match = chess_types.Match

_owner = None

def transfer_ownership(new_owner: Principal) -> void:
    global _owner
    
    new_owner_pickled = pickle.dumps(new_owner)
    storages.stable.insert("owner", new_owner_pickled)
    _owner = None


def get_owner() -> Principal:
    global _owner

    if not _owner is None:
        return _owner
    
    owner_pickled = storages.stable.get("owner")
    if owner_pickled is None:
        return Principal(bytes(4))

    owner = pickle.loads(owner_pickled)
    _owner = owner
    return owner

def change_webhook_url(new_webhook_url: str):
    storages.stable.insert("webhook_url", new_webhook_url.encode('utf-8'))


def get_webhook_url() -> str | None:
    webhook_url = storages.stable.get("webhook_url")

    if webhook_url is None:
        return None

    return webhook_url.decode('utf-8')


def inject_history(match_id: str):
    """ini dieksekusi setelah pertandingan selesai"""

    match_ = storages.matchs.get(match_id)
    principals = (match_['black_player'], match_['white_player'])

    for principal in principals:
        histories = storages.histories.get(principal) or Vec()
        histories.append(match_['id'])

        storages.histories.insert(principal, histories)


def decide_win(match_id: str, pawn: str):
    """putuskan pemenang"""
    def inner():
        match_ = storages.matchs.get(match_id)

        timer = match_['timer']
        if timer != None:
            ic.clear_timer(timer)

        white_player_id = match_['white_player']
        white_player = storages.users.get(white_player_id)

        black_player_id = match_['black_player']
        black_player = storages.users.get(black_player_id)

        if pawn == 'draw':
            # match_['white_player']['draw'] += 1

            white_player['draw'] += 1
            black_player['draw'] += 1

            # match_['black_player']['draw'] += 1
            match_['winner'] = 'draw'
        elif pawn == 'white':
            # match_['white_player']['win'] += 1
            # match_['black_player']['lost'] += 1
            
            white_player['win'] += 1
            black_player['lost'] += 1
            match_['winner'] = 'white'
        else:
            # match_['black_player']['win'] += 1
            # match_['white_player']['lost'] += 1

            white_player['lost'] += 1
            black_player['win'] += 1
            match_['winner'] = 'black'

        storages.users.insert(white_player_id, white_player)
        storages.users.insert(black_player_id, black_player)
        storages.matchs.insert(match_['id'], match_)

        inject_history(match_['id'])
        
        if storages.active_matchs.get(white_player_id.to_str()):
            del storages.active_matchs[white_player_id.to_str()]

        if storages.active_matchs.get(black_player_id.to_str()):
            del storages.active_matchs[black_player_id.to_str()]

        winner_player = 'draw'

        if match_['winner'] == 'white':
            winner_player = white_player_id.to_str()
        elif match_['winner'] == 'black':
            winner_player = black_player_id.to_str()

        webhook_url = chess_helpers.get_webhook_url()
        random_bytes: CallResult[blob] = yield management_canister.raw_rand()
        webhook_id = random_bytes.Ok.hex()

        storages.webhooks[webhook_id] = {
            'webhook_id': webhook_id,
            'match_id': match_id,
            'white_player': white_player_id.to_str(),
            'black_player': black_player_id.to_str(),
            'winner': match_['winner'],
            'winner_player': winner_player,
        }

        http_result: CallResult[HttpResponse] = yield management_canister.http_request(
            {
                "url": webhook_url,
                "max_response_bytes": 1_000,
                "method": {"post": None},
                "headers": [],
                "body": json.dumps({'webhook_id': webhook_id}).encode('utf-8'),
                "transform": {"function": (ic.id(), "webhook_transform"), "context": bytes()},
            }
        ).with_cycles(70_000_000)

        if http_result.Err:
            ic.print("failed webhook to: %s message: %s" % (webhook_url, http_result.Err))

    return inner


def get_or_create_user(principal: Principal) -> User:
    assert principal != Principal(), "Zero address"

    if storages.users.contains_key(principal):
        user = storages.users.get(principal)
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

    storages.users.insert(principal, user)

    return user


def update_current_user(user: User) -> void:
    storages.users.insert(ic.caller(), user)