# from ic.principal import Principal
from ic.canister import Canister
from ic.identity import Identity
from ic.client import Client
from ic.agent import Agent
# from ic.candid import encode, Types
import pathlib

CANISTER_ID = "uzt4z-lp777-77774-qaabq-cai"
ENGINE_CANISTER_ID = "uxrrr-q7777-77774-qaaaq-cai"

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
    white_player_address = res[0][1]['whitePlayer']['id'].to_str()
    print(match_id)

    if white_player_address == playerA.sender().to_str():
        agentPlayerA.add_match_move(match_id, 8024)
    else:
        agentPlayerB.add_match_move(match_id, 8024)


try:
    initialize()
except:
    pass

add_match()
