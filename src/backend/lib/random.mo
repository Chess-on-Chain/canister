import Nat8 "mo:base/Nat8";
import Time "mo:core/Time";

module {
  public func random_nat8() : Nat8 {
    Nat8.fromIntWrap(Time.now() % 255);
  };
};
