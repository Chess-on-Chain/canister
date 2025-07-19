import pickle

import chess_storages
import chess_types
from kybra import Opt, Service, nat8, service_query, void

NextMoveAndStatusOutput = chess_types.NextMoveAndStatusOutput
Principal = chess_types.Principal

class Chess(Service):
    @service_query
    def next_move_and_status(self, fen: str, from_position: nat8, to_position: nat8, promotion_to: Opt[str]) -> NextMoveAndStatusOutput:
        ...


_chess = None

def get_engine() -> Chess:
    global _chess

    if not _chess is None:
        return _chess

    engine = chess_storages.stable.get("engine")
    if engine is None:
        return Chess(Principal())
    
    engine = pickle.loads(engine)
    return engine


def change_engine(principal: Principal) -> void:
    global _chess

    chess = Chess(principal)
    chess_storages.stable.insert("engine", pickle.dumps(chess))
    _chess = None