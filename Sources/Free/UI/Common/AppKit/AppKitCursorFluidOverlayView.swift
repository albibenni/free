import AppKit
import CoreImage
import Metal
import MetalKit
import simd

@MainActor
final class AppKitCursorFluidOverlayView: MTKView, MTKViewDelegate {
    private struct Particle {
        var position: CGPoint
        var velocity: CGVector
        var life: CGFloat
        var radius: CGFloat
        var color: NSColor
    }

    private var ciContext: CIContext?
    private var commandQueue: MTLCommandQueue?
    private var particles: [Particle] = []
    private var eventMonitor: Any?
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var currentPointer = CGPoint.zero
    private var lastPointer = CGPoint.zero
    private var hasPointer = false
    private var spawnAccumulator: CGFloat = 0

    static func makeIfSupported() -> AppKitCursorFluidOverlayView? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return AppKitCursorFluidOverlayView(device: device)
    }

    init?(device: MTLDevice) {
        super.init(frame: .zero, device: device)
        setup(device: device)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureEventMonitor()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let drawable = currentDrawable,
            let ciContext,
            let commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        let now = CACurrentMediaTime()
        let dt = max(1.0 / 240.0, min(1.0 / 30.0, now - lastFrameTime))
        lastFrameTime = now

        updateParticles(dt: CGFloat(dt))
        let bounds = CGRect(origin: .zero, size: drawableSize)
        let image = renderImage(in: bounds)

        ciContext.render(
            image,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: bounds,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func setup(device: MTLDevice) {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        isPaused = false
        enableSetNeedsDisplay = false
        delegate = self
        framebufferOnly = false
        preferredFramesPerSecond = 60
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        colorPixelFormat = .bgra8Unorm

        commandQueue = device.makeCommandQueue()
        ciContext = CIContext(mtlDevice: device)
    }

    private func configureEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            guard let self else { return event }
            let location = self.convert(event.locationInWindow, from: nil)
            lastPointer = currentPointer
            currentPointer = location
            hasPointer = true
            return event
        }
    }

    private func updateParticles(dt: CGFloat) {
        let pointerVelocity = CGVector(
            dx: (currentPointer.x - lastPointer.x) / max(dt, 0.001),
            dy: (currentPointer.y - lastPointer.y) / max(dt, 0.001)
        )

        if hasPointer {
            spawnAccumulator += dt * 120
            while spawnAccumulator >= 1 {
                spawnAccumulator -= 1
                let jitter = CGPoint(
                    x: CGFloat.random(in: -6 ... 6),
                    y: CGFloat.random(in: -6 ... 6)
                )
                let spawnPosition = CGPoint(
                    x: currentPointer.x + jitter.x,
                    y: currentPointer.y + jitter.y
                )
                let velocityScale: CGFloat = 0.012
                let velocity = CGVector(
                    dx: pointerVelocity.dx * velocityScale + CGFloat.random(in: -12 ... 12),
                    dy: pointerVelocity.dy * velocityScale + CGFloat.random(in: -12 ... 12)
                )
                let life = CGFloat.random(in: 0.45 ... 0.8)
                let radius = CGFloat.random(in: 8 ... 18)
                let hue: CGFloat = CGFloat.random(in: 0.33 ... 0.42)
                let color = NSColor(
                    hue: hue,
                    saturation: 0.85,
                    brightness: 0.95,
                    alpha: 0.22
                )
                particles.append(
                    Particle(
                        position: spawnPosition,
                        velocity: velocity,
                        life: life,
                        radius: radius,
                        color: color
                    )
                )
            }
        } else {
            spawnAccumulator = 0
        }

        for index in particles.indices {
            particles[index].position.x += particles[index].velocity.dx * dt
            particles[index].position.y += particles[index].velocity.dy * dt
            particles[index].velocity.dx *= 0.96
            particles[index].velocity.dy *= 0.96
            particles[index].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    private func renderImage(in bounds: CGRect) -> CIImage {
        var output = CIImage(color: .clear).cropped(to: bounds)

        for particle in particles {
            let alpha = max(0, min(1, particle.life / 0.8))
            let color = CIColor(
                color: particle.color.withAlphaComponent(particle.color.alphaComponent * alpha)
            ) ?? CIColor(red: 0.2, green: 0.9, blue: 0.45, alpha: 0.12)
            let gradient = radialGradient(
                center: particle.position,
                radius: particle.radius,
                color: color
            )
            output = gradient.composited(over: output)
        }

        if particles.isEmpty { return output }
        return output.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5.5])
            .cropped(to: bounds)
    }

    private func radialGradient(center: CGPoint, radius: CGFloat, color: CIColor) -> CIImage {
        let filter = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": CIVector(cgPoint: center),
                "inputRadius0": radius * 0.15,
                "inputRadius1": radius,
                "inputColor0": color,
                "inputColor1": CIColor.clear,
            ]
        )
        return (filter?.outputImage ?? CIImage(color: .clear))
            .cropped(
                to: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
    }
}
