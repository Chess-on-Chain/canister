# from ic.principal import Principal
from ic.canister import Canister
from ic.identity import Identity
from ic.client import Client
from ic.agent import Agent
# from ic.candid import encode, Types
import pathlib

CANISTER_ID = "uxrrr-q7777-77774-qaaaq-cai"
ENGINE_CANISTER_ID = "u6s2n-gx777-77774-qaaba-cai"

owner = Identity("b975a136bae81f98b65142d060eec48af125b14a9f733919d02eb49e90143863")
playerA = Identity("e7a3f1f8f2787430f2b9860da4fad3c51f21b20bd8b87110fdbb630cecfe8c2b")
playerB = Identity("71cb0af95cf6e19f371a1fbf8ae6236e53869ab08ded65afceb0a8f9adec5c12")

client = Client("http://127.0.0.1:4943")
contract_did = open(
    pathlib.Path(__file__).parent / 'contract.did'
).read()

def get_canister(ii: Identity):
    agent = Agent(ii, client)
    canister = Canister(
        agent = agent,
        canister_id = CANISTER_ID,
        candid = contract_did
    )
    return canister


agentOwner = get_canister(owner)
agentPlayerA = get_canister(playerA)
agentPlayerB = get_canister(playerB)

print(playerA.sender().to_str())
print(playerB.sender().to_str())


def initialize():
    res = agentOwner.initialize(
        owner.sender().to_str(),
        ENGINE_CANISTER_ID
    )
    print("Initialize:", res)

def add_match():
    # print(playerA.sender().to_str())
    res = agentOwner.add_match(
        playerA.sender().to_str(),
        playerB.sender().to_str()
    )
    
    match_id = res[0][0]
    print(match_id)
    match_ = res[0][1]
    white_player_address = match_['white_player']['id'].to_str()

    chars = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

    moves = [
        ("E2", "E4"),  # 1. e4
        ("E7", "E5"),  # 1... e5
        ("F1", "C4"),  # 2. Bc4
        ("B8", "C6"),  # 2... Nc6
        ("D1", "H5"),  # 3. Qh5
        ("G8", "F6"),  # 3... Nf6
        ("H5", "F7")   # 4. Qxf7# → Checkmate
    ]

    whitePlayer, blackPlayer = agentPlayerA, agentPlayerB

    if white_player_address == playerB.sender().to_str():
        whitePlayer, blackPlayer = blackPlayer, whitePlayer

    for move in moves:
        a = 8 * (int(move[0][1]) - 1)
        a += chars.index(move[0][0])

        b = 8 * (int(move[1][1]) - 1)
        b += chars.index(move[1][0])

        turn = a * 1000 + b

        print(move, turn)

        if match_['is_white_turn']:
            match_ = whitePlayer.add_match_move(match_id, turn)[0]
        else:
            match_ = blackPlayer.add_match_move(match_id, turn)[0]

        print(match_)

try:
    initialize()
except:
    pass

add_match()
