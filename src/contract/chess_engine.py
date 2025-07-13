import chess_types
from kybra import Principal, Service, nat8, service_query, void

NextMoveAndStatusOutput = chess_types.NextMoveAndStatusOutput

class Chess(Service):
    @service_query
    def next_move_and_status(self, fen: str, from_position: nat8, to_position: nat8) -> NextMoveAndStatusOutput:
        ...

_engine = Chess(Principal())

def get_engine() -> Chess:
    return _engine

def change_principal(principal: Principal) -> void:
    global _engine

    _engine = Chess(principal)