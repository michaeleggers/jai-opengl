
MouseState :: struct {
    x, y            : s32;
    oldX, oldY      : s32;
    dX, dY          : s32;
    rightButtonDown  := false;
    rightButtonWentUp := false;
}

// TODO: Too large to fit in static memory. Often we are just lucky that it works.
//       -> Put this onto the heap.
keyState : [#run enum_highest_value(SDL_Keycode)] bool;
keyStatePrevFrame : [..] bool;

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
