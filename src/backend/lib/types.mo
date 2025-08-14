import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

module {
  public type Move = {
    fen : Text;
    time : Nat64;
  };

  // public type NextMoveAndStatusOutput = {
  //   status : Nat8;
  // };

  public type File = {
    filename : Text;
    data : Blob;
    hash : Blob;
  };

  public type User = {
    id : Principal;
    win : Nat16;
    lost : Nat16;
    draw : Nat16;
    username : ?Text;
    fullname : Text;
    score : Nat16;
    is_banned : Bool;
    country : ?Text;
    photo : ?File;
  };

  public type Match = {
    id : Nat64;
    white_player : Principal;
    black_player : Principal;
    fen : Text;
    moves : [Move];
    is_white_turn : Bool;
    winner : Text; // Could use variant for 'white', 'black', etc.
    is_ranked : Bool;
    time : Nat64;
    last_move : Nat64;
  };

  public type MatchCreated = {
    #match : Match;
    #text : Text;
  };

  public type MatchResult = {
    id : Nat64;
    white_player : User;
    black_player : User;
    moves : [Move];
    winner : Text;
    is_ranked : Bool;
    time : Nat64;
  };

  public type MatchResultHistory = {
    id : Nat64;
    white_player : Principal;
    black_player : Principal;
    moves : [Move];
    winner : Text;
    is_ranked : Bool;
    time : Nat64;
  };

  // public type WebhookData = {
  //   webhook_id : Text;
  //   match_id : Text;
  //   white_player : Text;
  //   black_player : Text;
  //   winner : Text;
  //   winner_player : Text;
  //   is_ranked : Bool;
  // };
};
