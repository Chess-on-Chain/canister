# from ic.principal import Principal
from ic.canister import Canister
from ic.identity import Identity
from ic.client import Client
from ic.agent import Agent
# from ic.candid import encode, Types
import pathlib, time

CANISTER_ID = "umunu-kh777-77774-qaaca-cai"
ENGINE_CANISTER_ID = "u6s2n-gx777-77774-qaaba-cai"

owner = Identity("b975a136bae81f98b65142d060eec48af125b14a9f733919d02eb49e90143863")
playerA = Identity()
playerB = Identity()

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

def initialize():
    res = agentOwner.initialize(
        owner.sender().to_str(),
        ENGINE_CANISTER_ID
    )
    print("Initialize:", res)

def add_match():
    res = agentOwner.add_match(
        playerA.sender().to_str(),
        playerB.sender().to_str()
    )
    
    match_id = res[0][0]
    match_ = res[0][1]
    white_player_address = match_['white_player']['id'].to_str()

    chars = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

    moves = [
        ("G1", "F3"),  # 1. Nf3
        ("G8", "F6"),  # 1... Nf6
        ("F3", "G1"),  # 2. Ng1
        ("F6", "G8"),  # 2... Ng8
        ("G1", "F3"),  # 3. Nf3 (posisi pertama terulang)
        ("G8", "F6"),  # 3... Nf6 (posisi kedua terulang)
        ("F3", "G1"),  # 4. Ng1 (posisi pertama terulang untuk ketiga kalinya)
        ("F6", "G8")   # 4... Ng8  → Klaim draw oleh threefold repetition
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
