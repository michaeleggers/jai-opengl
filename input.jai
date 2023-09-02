
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

KeyReleased :: (key : SDL_Keycode) -> bool {
    return keyStatePrevFrame[key] && !keyState[key];
}

InputInit :: () {
    // TODO: enum_highest_value(SDL_Keycode) causes weird behavior during runtime. Large mem consumption
    //       and super low framerate. Not sure why. Compilerbug?
    array_resize(*keyStatePrevFrame, 1024);
}
