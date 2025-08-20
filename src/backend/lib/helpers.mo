import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Result "mo:base/Result";
// import Debug "mo:base/Debug";
import Nat "mo:core/Nat";
import Nat16 "mo:base/Nat16";
import Float "mo:base/Float";
import Iter "mo:base/Iter";

module {

  public func parse_image_file_id(url : Text) : ?Text {
    let parts = Text.split(url, #text "/image/");
    let len = Iter.size(parts);

    if (len == 2) {
      ignore parts.next();
      return parts.next();
    } else {
      return null;
    };
  };

  public func update_elo(eloA : Nat16, eloB : Nat16, scoreA : Float, k : Nat8) : (Nat16, Nat16) {
    let eloA_f = Float.fromInt(Nat16.toNat(eloA));
    let eloB_f = Float.fromInt(Nat16.toNat(eloB));
    let k_f = Float.fromInt(Nat8.toNat(k));

    // expected score
    let expectedA : Float = 1.0 / (1.0 + Float.pow(10.0, (eloB_f - eloA_f) / 400.0));
    let expectedB : Float = 1.0 / (1.0 + Float.pow(10.0, (eloA_f - eloB_f) / 400.0));

    let scoreB : Float = 1.0 - scoreA;

    // update elo
    let newEloA_f : Float = eloA_f + k_f * (scoreA - expectedA);
    let newEloB_f : Float = eloB_f + k_f * (scoreB - expectedB);

    let newEloA : Nat16 = Nat16.fromIntWrap(Float.toInt(newEloA_f));
    let newEloB : Nat16 = Nat16.fromIntWrap(Float.toInt(newEloB_f));

    (newEloA, newEloB);
  };
  private func char_index(chars : Text, c : Char) : ?Nat {
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

        switch (char_index(chars, colChar), Nat.fromText(Char.toText(rowChar))) {
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
