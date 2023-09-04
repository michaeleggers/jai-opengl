
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

#scope_file

// TODO: Maybe they should not be modifyable by other files than input.jai
keyState : [..] bool;
keyStatePrevFrame : [..] bool;
// Safe mouse state, so we can get a delta
mouseState : MouseState;

#scope_export

// Not sure if the handler will be needed? At the moment it is not used.
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

MouseRightButtonDown :: () -> bool {
    return mouseState.rightButtonDown;
}

MouseRightButtonUp :: () -> bool {
    return mouseState.rightButtonWentUp;
}

// TODO: Should maybe just be: GetMouseState() and return the whole thing.
GetMouseX :: () -> s32 {
    return mouseState.x;
}

GetMouseY :: () -> s32 {
    return mouseState.y;
}

GetMouseDX :: () -> s32 {
    return mouseState.dX;
}

GetMouseDY :: () -> s32 {
    return mouseState.dY;
}

InputInit :: () {
    // TODO: enum_highest_value(SDL_Keycode) causes weird behavior during runtime. Large mem consumption
    //       and super low framerate. Not sure why. Compilerbug?
    numKeyboardNames := #run type_info(KeyboardButton).names.count-1;
    // print("type info: %\n", #run type_info(SDL_Keycode).names.count);
    // print("KeyboardButton type info: %\n", <<type_info(KeyboardButton));
    array_resize(*keyState, numKeyboardNames);
    array_resize(*keyStatePrevFrame, numKeyboardNames);
}

HandleSystemEvents :: (running : *bool, refdef : *RefDef) {

    // memset(keyStatePrevFrame.data, cast(u8)(false), keyStatePrevFrame.count*size_of(bool));
    memcpy(keyStatePrevFrame.data, keyState.data, keyState.count*size_of(bool));

    // Maybe even use SDL_GetKeyboardState() here and don't rely on SDL events at all?
    buttonMask := SDL_GetMouseState(*mouseState.x, *mouseState.y);
    mouseState.oldX = mouseState.x;
    mouseState.oldY = mouseState.y;
    mouseState.rightButtonDown = false;        
    mouseState.rightButtonWentUp = false;

    // SDL Event Loop
    event : SDL_Event;
    while SDL_PollEvent(*event) {

        if event.type == {
            case SDL_QUIT;
                <<running = false;
                
            case SDL_KEYDOWN;
                if event.key.keysym.sym == {
                    case .SDLK_a; keyState[KeyboardButton.A] = true;
                    case .SDLK_b; keyState[KeyboardButton.B] = true;
                    case .SDLK_c; keyState[KeyboardButton.C] = true;
                    case .SDLK_d; keyState[KeyboardButton.D] = true;
                    case .SDLK_e; keyState[KeyboardButton.E] = true;
                    case .SDLK_f; keyState[KeyboardButton.F] = true;
                    case .SDLK_g; keyState[KeyboardButton.G] = true;
                    case .SDLK_h; keyState[KeyboardButton.H] = true;
                    case .SDLK_i; keyState[KeyboardButton.I] = true;
                    case .SDLK_j; keyState[KeyboardButton.J] = true;
                    case .SDLK_k; keyState[KeyboardButton.K] = true;
                    case .SDLK_l; keyState[KeyboardButton.L] = true;
                    case .SDLK_m; keyState[KeyboardButton.M] = true;
                    case .SDLK_n; keyState[KeyboardButton.N] = true;
                    case .SDLK_o; keyState[KeyboardButton.O] = true;
                    case .SDLK_p; keyState[KeyboardButton.P] = true;
                    case .SDLK_q; keyState[KeyboardButton.Q] = true;
                    case .SDLK_r; keyState[KeyboardButton.R] = true;
                    case .SDLK_s; keyState[KeyboardButton.S] = true;
                    case .SDLK_t; keyState[KeyboardButton.T] = true;
                    case .SDLK_u; keyState[KeyboardButton.U] = true;
                    case .SDLK_v; keyState[KeyboardButton.V] = true;
                    case .SDLK_w; keyState[KeyboardButton.W] = true;
                    case .SDLK_x; keyState[KeyboardButton.X] = true;
                    case .SDLK_y; keyState[KeyboardButton.Y] = true;
                    case .SDLK_z; keyState[KeyboardButton.Z] = true;                        

                    case .SDLK_RIGHT; keyState[KeyboardButton.RIGHT] = true;    
                    case .SDLK_LEFT; keyState[KeyboardButton.LEFT] = true;    
                    case .SDLK_UP; keyState[KeyboardButton.UP] = true;    
                    case .SDLK_DOWN; keyState[KeyboardButton.DOWN] = true;                            

                    case .SDLK_1; keyState[KeyboardButton.NUM_1] = true;
                    case .SDLK_2; keyState[KeyboardButton.NUM_2] = true;

                    case .SDLK_ESCAPE; keyState[KeyboardButton.ESCAPE] = true;                            
                    case .SDLK_COMMA; keyState[KeyboardButton.COMMA] = true;
                    case .SDLK_PERIOD; keyState[KeyboardButton.PERIOD] = true;    
                    case .SDLK_TAB; keyState[KeyboardButton.TAB] = true;

                    case; print("Button not mapped\n");
                }
        
            case SDL_KEYUP;
                // memcpy(keyStatePrevFrame.data, keyState.data, keyState.count*size_of(bool));
                if event.key.keysym.sym == {
                    case .SDLK_a; keyState[KeyboardButton.A] = false;
                    case .SDLK_b; keyState[KeyboardButton.B] = false;
                    case .SDLK_c; keyState[KeyboardButton.C] = false;
                    case .SDLK_d; keyState[KeyboardButton.D] = false;
                    case .SDLK_e; keyState[KeyboardButton.E] = false;
                    case .SDLK_f; keyState[KeyboardButton.F] = false;
                    case .SDLK_g; keyState[KeyboardButton.G] = false;
                    case .SDLK_h; keyState[KeyboardButton.H] = false;
                    case .SDLK_i; keyState[KeyboardButton.I] = false;
                    case .SDLK_j; keyState[KeyboardButton.J] = false;
                    case .SDLK_k; keyState[KeyboardButton.K] = false;
                    case .SDLK_l; keyState[KeyboardButton.L] = false;
                    case .SDLK_m; keyState[KeyboardButton.M] = false;
                    case .SDLK_n; keyState[KeyboardButton.N] = false;
                    case .SDLK_o; keyState[KeyboardButton.O] = false;
                    case .SDLK_p; keyState[KeyboardButton.P] = false;
                    case .SDLK_q; keyState[KeyboardButton.Q] = false;
                    case .SDLK_r; keyState[KeyboardButton.R] = false;
                    case .SDLK_s; keyState[KeyboardButton.S] = false;
                    case .SDLK_t; keyState[KeyboardButton.T] = false;
                    case .SDLK_u; keyState[KeyboardButton.U] = false;
                    case .SDLK_v; keyState[KeyboardButton.V] = false;
                    case .SDLK_w; keyState[KeyboardButton.W] = false;
                    case .SDLK_x; keyState[KeyboardButton.X] = false;
                    case .SDLK_y; keyState[KeyboardButton.Y] = false;
                    case .SDLK_z; keyState[KeyboardButton.Z] = false;                        

                    case .SDLK_RIGHT; keyState[KeyboardButton.RIGHT] = false;    
                    case .SDLK_LEFT; keyState[KeyboardButton.LEFT] = false;    
                    case .SDLK_UP; keyState[KeyboardButton.UP] = false;    
                    case .SDLK_DOWN; keyState[KeyboardButton.DOWN] = false;                            

                    case .SDLK_1; keyState[KeyboardButton.NUM_1] = false;
                    case .SDLK_2; keyState[KeyboardButton.NUM_2] = false;

                    case .SDLK_ESCAPE; keyState[KeyboardButton.ESCAPE] = false;                            
                    case .SDLK_COMMA;  keyState[KeyboardButton.COMMA] = false;                                                    
                    case .SDLK_PERIOD; keyState[KeyboardButton.PERIOD] = false;                        
                    case .SDLK_TAB; keyState[KeyboardButton.TAB] = false;                            
                    
                    case; print("Button not mapped\n");
                }
                
                // if event.key.keysym.sym == SDLK_COMMA {
                //     keyStatePrevFrame[SDLK_COMMA] = keyState[SDLK_COMMA];
                //     keyState[SDLK_COMMA] = false;
                // }
                // if event.key.keysym.sym == SDLK_PERIOD {
                //     keyStatePrevFrame[SDLK_PERIOD] = keyState[SDLK_PERIOD];
                //     keyState[SDLK_PERIOD] = false;
                // }

            // case SDL_MOUSEBUTTONDOWN;
            //     // if event.button.state == SDL_PRESSED {
            //         print("Mouse button down\n");
            //         mouseX, mouseY : s32;
            //         buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
            //         if SDL_BUTTON(buttonMask) & SDL_BUTTON_LEFT == SDL_BUTTON_LEFT {
            //             print("Mouse pressed at %, %\n", mouseX, mouseY);
            //         }
            //     // }

            case SDL_MOUSEMOTION;
                mouseState.x = event.motion.x;
                mouseState.y = event.motion.y;
                if event.motion.state & SDL_BUTTON(3) {
                    mouseState.dX = mouseState.x - mouseState.oldX;
                    mouseState.dY = mouseState.y - mouseState.oldY;                        
                    mouseState.rightButtonDown = true;
                    // UpdateCameraOnMouse(*refdef.camera, dX, dY); // TODO: Move this down, out of the event loop
                    //print("Mouse delta %, %\n", dX, dY);
                    mouseState.oldX = mouseState.x;
                    mouseState.oldY = mouseState.y;
                }
            
            case SDL_MOUSEBUTTONUP;
                mouseState.oldX = 0;
                mouseState.oldY = 0;
                mouseState.rightButtonDown = false;
                if event.button.button & SDL_BUTTON_RIGHT == SDL_BUTTON_RIGHT {
                    mouseState.rightButtonWentUp = true;
                }

            case SDL_WINDOWEVENT;
                if event.window.event == SDL_WINDOWEVENT_RESIZED {
                    refdef.clientWidth = xx event.window.data1;
                    refdef.clientHeight = xx event.window.data2;
                    print("Window client dimensions have changed: ( %, % )\n", refdef.clientWidth, refdef.clientHeight);
                }                    

        }
    }
}