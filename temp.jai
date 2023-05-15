#import "Basic";

Camera :: struct {
    x, y, z : float;
}

changeBasicInt :: (a : *s64) {
    <<a = 12;
}

changeCameraPos :: (camera : *Camera) {
    camera.x = 10.0;
    camera.y = 20.0;
    camera.z = 30.0;
}

someOptionalParams :: (a := 1, b := 2) -> *void {
    print("inside: someOptionalParams\n");
    return get_caller_address();
}

get_caller_address :: () -> *void {
    return context.stack_trace.info.procedure_address;
}

main :: () {
    a := 10;
    b := *a;

    print("a is: %\n", a);
    print("b (ptr): %\n", b);
    print("<<b (dereferenced): %\n", <<b);

    changeBasicInt(*a);
    print("a after myProc: %\n", a);
    print("<<b after myProc: %\n", <<b);

    camera : Camera;
    print("camera is: %\n", camera);

    changeCameraPos(*camera);
    print("camera after changeCameraPos: %\n", camera);

    cameraPtr := *camera; // get pointer to camera;
    cameraPtr.x = 100.0; // the '.' is like the '->' in C, apparently
    print("<<cameraPtr: %\n", <<cameraPtr);

    camera2 : Camera;
    // cameraPtr = camera2; // this won't work
    <<cameraPtr = camera2;
    print("<<cameraPtr after assigning new camera2: %\n", <<cameraPtr);
        

    p1 := #procedure_of_call someOptionalParams(1);
    p2 := #procedure_of_call someOptionalParams(1, 3);

    print("p1 is %\n", p1);
    print("p2 is %\n", p2);

    p3 := someOptionalParams(1);
    p4 := someOptionalParams(1, 3);
    print("p3 return: %\n", p3);
    print("p4 return: %\n", p4);


}