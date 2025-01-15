import MetalKit

class TouchableMTKView: MTKView {
    var touchHandler: ((CGPoint?) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchHandler?(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchHandler?(location)
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        touchHandler?(nil)
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        touchHandler?(nil)
    }
}
