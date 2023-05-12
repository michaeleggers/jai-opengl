#import "Basic";
#import "Math";

Camera :: struct {
    pos     := Vector3.{ 0.0, 0.0, 3.0 };
    center  := Vector3.{ 0.0, 0.0, 0.0 };
    up      := Vector3.{ 0.0, 1.0, 0.0 };
    right   := Vector3.{ 1.0, 0.0, 0.0 };
}

createView :: (using camera : *Camera) -> Matrix4 {
    result := make_translation_matrix4(pos); // TODO: Do rotation
    result = inverse(result);

    return result;
}