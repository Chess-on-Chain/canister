import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Result "mo:base/Result";
// import Debug "mo:base/Debug";
import Nat "mo:core/Nat";

// Helper function to get index of a character in a string
module {
  
  private func charIndex(chars : Text, c : Char) : ?Nat {
    var idx = 0;
    for (ch in chars.chars()) {
      if (ch == c) return ?idx;
      idx += 1;
    };
    null;
  };

  public func translate_move(move : Text) : Result.Result<Nat8, Text> {
    let chars = "ABCDEFGH";
    let moveUpper = Text.toUppercase(move).chars();

    // Assume move is always in the form "A1", "B2", etc.
    let colChar = moveUpper.next();
    let rowChar = moveUpper.next();

    let mantap : Result.Result<(Char, Char), Text> = switch (colChar, rowChar) {
      case (?colChar, ?rowChar) {
        #ok(colChar, rowChar);
      };
      case (_, _) {
        #err("Move not valid");
      };
    };

    switch (mantap) {
      case (#ok(colChar, rowChar)) {

        switch (charIndex(chars, colChar), Nat.fromText(Char.toText(rowChar))) {
          case (?col_position, ?row_position) {
            if (row_position <= 8 and col_position <= 8) {
              var position = 8 * (Nat8.fromNat(row_position) - 1);
              position += Nat8.fromNat(col_position);
              #ok(position);
            } else {
              #err("Move not valid");
            };

          };
          case (_, _) {
            #err("Move not valid");
          };
        };
      };
      case (#err(text)) {
        #err(text);
      };
    };
  };
};
