
handler : (keyStates : [] bool) -> () = null;

Handle :: (keyStates : [] bool) {
    if handler {
        handler(keyStates);
    } else {
        print("No Input handler set!\n");
    }
}

SetHandler :: (customHandler : (keyStates : []bool) -> ()) {
    handler = customHandler;
}
