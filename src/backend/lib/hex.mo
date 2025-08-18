import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Char "mo:base/Char";

module {
  public func encode(ns : [Nat8]) : Text {
    Array.foldRight<Nat8, Text>(
      ns,
      "",
      func(n : Nat8, acc : Text) : Text {
        let chars : [Char] = Text.toArray("0123456789abcdef");
        let c0 = chars[Nat8.toNat(n / 16)];
        let c1 = chars[Nat8.toNat(n % 16)];
        Char.toText(c0) # Char.toText(c1) # acc;
      },
    );
  };
};
