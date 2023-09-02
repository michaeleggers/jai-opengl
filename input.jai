
using KeyboardButton :: enum u32 {
    KEYBOARD_A :: 0;
    KEYBOARD_B;
    KEYBOARD_C;
    KEYBOARD_D;
    KEYBOARD_E;
    KEYBOARD_F;
    KEYBOARD_G;
    KEYBOARD_H;
    KEYBOARD_I;
    KEYBOARD_J;
    KEYBOARD_K;
    KEYBOARD_L;
    KEYBOARD_M;
    KEYBOARD_N;
    KEYBOARD_O;
    KEYBOARD_P;
    KEYBOARD_Q;
    KEYBOARD_R;
    KEYBOARD_S;
    KEYBOARD_T;
    KEYBOARD_U;
    KEYBOARD_V;
    KEYBOARD_W;
    KEYBOARD_X;
    KEYBOARD_Y;
    KEYBOARD_Z;
    KEYBOARD_LEFT;
    KEYBOARD_RIGHT;
    KEYBOARD_UP;
    KEYBOARD_DOWN;
    KEYBOARD_PERIOD;
    KEYBOARD_COMMA;
    KEYBOARD_1;
    KEYBOARD_2;
    KEYBOARD_3;
    KEYBOARD_4;
    KEYBOARD_5;
    KEYBOARD_6;
    KEYBOARD_7;
    KEYBOARD_8;
    KEYBOARD_9;
    KEYBOARD_LEFTBRACKET;
    KEYBOARD_RIGHTBRACKET;
    KEYBOARD_ESCAPE;
    KEYBOARD_TAB;

    KEYBOARD_MAX_KEYS;
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
