import IcWebSocketCdk "mo:ic-websocket-cdk";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

module {
  // let kasep: Text = "9";

  type AppMessage = {
    message : Text;
  };

  public func on_open(args : IcWebSocketCdk.OnOpenCallbackArgs) : async () {
    let message : AppMessage = {
      message = "Ping";
    };
    // kasep := "SALIS";
  };

  public func on_message(args : IcWebSocketCdk.OnMessageCallbackArgs) : async () {
    let app_msg : ?AppMessage = from_candid (args.message);
    let new_msg : AppMessage = switch (app_msg) {
      case (?msg) {
        { message = Text.concat(msg.message, " ping") };
      };
      case (null) {
        Debug.print("Could not deserialize message");
        return;
      };
    };

    Debug.print("Received message: " # debug_show (new_msg));

    // await send_app_message(args.client_principal, new_msg);
  };

  public func on_close(args : IcWebSocketCdk.OnCloseCallbackArgs) : async () {
    Debug.print("Client " # debug_show (args.client_principal) # " disconnected");
  };

  // let params = IcWebSocketCdkTypes.WsInitParams(null, null);
  // let ws_state = IcWebSocketCdkState.IcWebSocketState(params);

  //     let handlers = IcWebSocketCdkTypes.WsHandlers(
  //     ?on_open,
  //     ?on_message,
  //     ?on_close,
  //   );

  //     let ws = IcWebSocketCdk.IcWebSocket(ws_state, params, handlers);
};
