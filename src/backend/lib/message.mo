import Types "types";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";

module {
  public func pop_messages(
    messages : Buffer.Buffer<Types.WebsocketMessageQueue>
  ) : [Types.WebsocketMessageQueue] {
    let response = Buffer.toArray<Types.WebsocketMessageQueue>(messages);
    messages.clear();

    response;
  };

  public func add_message(
    messages : Buffer.Buffer<Types.WebsocketMessageQueue>,
    principal : Principal,
    method : Text,
    body : Text,
  ) {
    messages.add({
      body = body;
      method = method;
      principal = principal;
    });
  };
};
