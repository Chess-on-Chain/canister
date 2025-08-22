import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Char "mo:base/Char";
import Blob "mo:base/Blob";
import Nat16 "mo:base/Nat16";

module {
  public func encode(ns : Blob) : Text {
    Array.foldRight<Nat8, Text>(
      Blob.toArray(ns),
      "",
      func(n : Nat8, acc : Text) : Text {
        let chars : [Char] = Text.toArray("0123456789abcdef");
        let c0 = chars[Nat8.toNat(n / 16)];
        let c1 = chars[Nat8.toNat(n % 16)];
        Char.toText(c0) # Char.toText(c1) # acc;
      },
    );
  };

  public func decode(hex : Text) : ?Blob {
    let hexStr = Text.toLowercase(hex);
    let chars = Text.toArray(hexStr);
    if (chars.size() % 2 != 0) return null; // Hex string must have even length

    let bytes = Array.tabulate<Nat8>(
      chars.size() / 2,
      func(i) {
        let hi = chars[2 * i];
        let lo = chars[2 * i + 1];

        let digit = func(c : Char) : ?Nat8 {
          if (c >= '0' and c <= '9') {
            ?Nat8.fromNat16(
              Nat16.fromNat32(Char.toNat32(c) - Char.toNat32('0'))
            );
          } else if (c >= 'a' and c <= 'f') {
            ?Nat8.fromNat16(
              Nat16.fromNat32(Char.toNat32(c) - Char.toNat32('a'))
            );
          } else {
            null;
          };
        };

        switch (digit(hi), digit(lo)) {
          case (?d0, ?d1) { Nat8.fromNat(Nat8.toNat(d0) * 16 + Nat8.toNat(d1)) };
          case _ { return 0 : Nat8 }; // Invalid hex, could also return null for the whole function
        };
      },
    );
    ?Blob.fromArray(bytes);
  };
};