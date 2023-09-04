
KeyboardButton :: enum u32 {
    A :: 0;
    B;
    C;
    D;
    E;
    F;
    G;
    H;
    I;
    J;
    K;
    L;
    M;
    N;
    O;
    P;
    Q;
    R;
    S;
    T;
    U;
    V;
    W;
    X;
    Y;
    Z;
    LEFT;
    RIGHT;
    UP;
    DOWN;
    PERIOD;
    COMMA;
    NUM_1;
    NUM_2;
    NUM_3;
    NUM_4;
    NUM_5;
    NUM_6;
    NUM_7;
    NUM_8;
    NUM_9;
    LEFTBRACKET;
    RIGHTBRACKET;
    ESCAPE;
    TAB;
    MAX_KEYS;
}

MouseState :: struct {
    x, y            : s32;
    oldX, oldY      : s32;
    dX, dY          : s32;
    rightButtonDown  := false;
    rightButtonWentUp := false;
}

// TODO: Too large to fit in static memory. Often we are just lucky that it works.
//       -> Put this onto the heap.
keyState : [..] bool;
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

KeyReleased :: (key : KeyboardButton) -> bool {
    return keyStatePrevFrame[key] && !keyState[key];
}

KeyDown :: (key : KeyboardButton) -> bool {
    return !keyStatePrevFrame[key] && keyState[key];
}

KeyPressed :: (key : KeyboardButton) -> bool {
    return keyState[key];
}

InputInit :: () {
    // TODO: enum_highest_value(SDL_Keycode) causes weird behavior during runtime. Large mem consumption
    //       and super low framerate. Not sure why. Compilerbug?
    highestKeycodeValue := #run type_info(KeyboardButton).names.count-1;
    // print("type info: %\n", #run type_info(SDL_Keycode).names.count);
    // print("KeyboardButton type info: %\n", <<type_info(KeyboardButton));
    array_resize(*keyState, highestKeycodeValue);
    array_resize(*keyStatePrevFrame, highestKeycodeValue);
}
