//
//  ViewController.swift
//  Rectangles
//
//  Created by Dmytro on 10.12.2022.
//

import UIKit
import CoreGraphics
import GameKit


class ViewController: UIViewController {

    let canvas = Canvas()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupView()
    }
    
    private func setupView() {
        view.addSubview(canvas)
        canvas.contentMode = .redraw
        canvas.translatesAutoresizingMaskIntoConstraints = false
        let constrainsts = [
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        constrainsts.forEach {
            $0.isActive = true
        }
        
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(swipeUp))
        swipeUp.direction = .up
        canvas.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipeDown))
        swipeDown.direction = .down
        canvas.addGestureRecognizer(swipeDown)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        tap.numberOfTapsRequired = 2
        canvas.addGestureRecognizer(tap)
    }

    @objc
    private func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        canvas.reset()
    }
    
    @objc
    private func swipeUp( sender: UISwipeGestureRecognizer) {
        canvas.numberOfRects = min(20, canvas.numberOfRects + 1)
    }
    
    @objc
    private func swipeDown( sender: UISwipeGestureRecognizer) {
        canvas.numberOfRects = max(2, canvas.numberOfRects - 1)
    }
}

extension CGRect {
    func intersects(_ others: [CGRect]) -> Bool {
        for other in others {
            if intersects(other) {
                return true
            }
        }
        return false
    }
}

class Canvas: UIView {
    static var counter: Int = 0
    private lazy var rects: [CGRect] = generateRects() {
        didSet {
            collisionDetector = QTCollisionDetector(rects: rects)
            setNeedsDisplay()
        }
    }
    private lazy var collisionDetector = QTCollisionDetector(rects: rects)

    var numberOfRects = 10 {
        didSet {
            reset()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        ctx.beginTransparencyLayer(in: bounds, auxiliaryInfo: nil)

        let timer = ParkBenchTimer()
        for rect in rects {
            _ = collisionDetector.detectCollisions(for: rect)
        }
        print("The task took \(timer.stop() * 1000) ms.")

        for rect in rects {
            let collission = collisionDetector.detectCollisions(for: rect)
            let color = collission ? UIColor.systemRed : UIColor.systemMint
            
            renderFill(rect, color: color.withAlphaComponent(0.4).cgColor, in: ctx)
            renderPathBoundingBox(rect, color: color.cgColor, in: ctx)
        }
        
        ctx.endTransparencyLayer()
    }
    
    func reset() {
        Canvas.counter = 0
        rects = generateRects()
    }
    
    private func generateRects() -> [CGRect] {
        CGRect.generateRandom(numberOfRects, in: bounds.insetBy(dx: 50, dy: 50))
    }
    
    private func renderStatus(_ rect: CGRect, color: CGColor, in ctx: CGContext) {
    }
    
    private func renderFill(_ rect: CGRect, color: CGColor, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(color)
        ctx.addRect(rect)
        ctx.fillPath()
        ctx.restoreGState()
    }
    
    private func renderPathBoundingBox(_ rect: CGRect, color: CGColor, in ctx: CGContext) {
        ctx.saveGState()

        ctx.addRect(rect)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(3.0)
        ctx.strokePath()

        ctx.restoreGState()
    }
    
}

extension CGRect {
    
    fileprivate static func generateRandom(
        _ numberOfRects: Int,
        in bounds: CGRect,
        minSize: Int = 30,
        maxSize: Int = 200
    ) -> [CGRect] {
        var result = [CGRect]()
        while numberOfRects > result.count {
            let width = Int.random(in: minSize...maxSize)
            let height = Int.random(in: minSize...maxSize)
            
            let minX = Int(bounds.origin.x)
            let minY = Int(bounds.origin.y)
            let maxX = Int(bounds.width) - minX - width
            let maxY = Int(bounds.height) - minY - height

            let x = Int.random(in: minX...maxX)
            let y = Int.random(in: minY...maxY)
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            if CGRectContainsRect(bounds, rect) {
                result.append(rect)
            }
        }
        return result
    }
}

protocol CollisionDetectoring {
    init(rects: [CGRect])
    func detectCollisions(for rect: CGRect) -> Bool
}

// DumbCollisionDetector
final class DumbCollisionDetector: CollisionDetectoring {
    let rects: [CGRect]
    
    init(rects: [CGRect]) {
        self.rects = rects
    }
    
    func detectCollisions(for rect: CGRect) -> Bool {
        let otherRects = rects.filter {
            $0 != rect
        }
        return rect.intersects(otherRects)
    }
}

// QTCollisionDetector
final class QTCollisionDetector: CollisionDetectoring {
    private let quadtree: QuadTree
        
    init(rects: [CGRect]) {
        let boundingRect = rects.reduce(CGRect.zero) { partialResult, rect in
            partialResult.union(rect)
        }
        
        quadtree = QuadTree(boundingBox: boundingRect)
        rects.forEach { rect in
            let _ = quadtree.insertObject(rect: rect)
        }
    }
    
    func detectCollisions(for rect: CGRect) -> Bool {
        let elements = quadtree.queryRegion(region: rect)
        return elements.count > 1
    }
}

class QuadTree {
    let boundingBox: CGRect
    /// Max number of objects stored by the quadrant.
//    let maximumNodeCapacity = 2
    
    /// The objects contained in the quadrant. It could be a  data model, but since we need only the rectangle we merely store it.
    var objects: [CGRect]
    
    /// Children.
    var northWest: QuadTree?
    var northEast: QuadTree?
    var southWest: QuadTree?
    var southEast: QuadTree?
    
    init(boundingBox: CGRect) {
        self.boundingBox = boundingBox
        self.objects = [CGRect]()
    }
    
    func insertObject(rect: CGRect) -> Bool {
        // Check to see if the region contains the point.
        // if rectangle fits entirely inside the
        if !boundingBox.contains(rect) {
            return false
        }
        
        objects.append(rect)
        
        // Not enough space, subdivide:
        if northWest == nil {
            subdivide()
        }
        
        if northWest != nil && northWest!.insertObject(rect: rect) {
            return true
        }
        else if northEast != nil && northEast!.insertObject(rect: rect) {
            return true
        }
        else if southWest != nil && southWest!.insertObject(rect: rect) {
            return true
        }
        else if southEast != nil && southEast!.insertObject(rect: rect) {
            return true
        }
        
        return false
    }
    
    func queryRegion(region: CGRect) -> [CGRect] {
        var objectsInRegion = [CGRect]()
        
        // Automatically abort if the range does not intersect this quad
        if !(boundingBox.intersects(region)) {
            return objectsInRegion
        }
        
        // Rectangles that stores in the quad.
        for object in objects {
            if region.intersects(object) {
                objectsInRegion.append(object)
            }
        }

        // If this node is a leaf, and has no children quads, insert it to the list.
        if northWest == nil {
            return objectsInRegion
        }
        
        // Otherwise recursively query children.
        if northWest != nil { objectsInRegion += northWest!.queryRegion(region: region) }
        if northEast != nil { objectsInRegion += northEast!.queryRegion(region: region) }
        if southWest != nil { objectsInRegion += southWest!.queryRegion(region: region) }
        if southEast != nil { objectsInRegion += southEast!.queryRegion(region: region) }
        
        return objectsInRegion
    }
    
    private func subdivide() {
        let size = CGSize(width: boundingBox.width / 2.0, height: boundingBox.height / 2.0)
        
        let nwRect = CGRect(origin: CGPoint(x: boundingBox.minX, y: boundingBox.minY), size: size)
        northWest = QuadTree(boundingBox: nwRect)
        let neRect = CGRect(origin: CGPoint(x: boundingBox.midX, y: boundingBox.minY), size: size)
        northEast = QuadTree(boundingBox: neRect)
        let swRect = CGRect(origin: CGPoint(x: boundingBox.minX, y: boundingBox.midY), size: size)
        southWest = QuadTree(boundingBox: swRect)
        let seRect = CGRect(origin: CGPoint(x: boundingBox.midX, y: boundingBox.midY), size: size)
        southEast = QuadTree(boundingBox: seRect)
    }
}

class ParkBenchTimer {
    let startTime: CFAbsoluteTime
    var endTime: CFAbsoluteTime?

    init() {
        startTime = CFAbsoluteTimeGetCurrent()
    }

    func stop() -> CFAbsoluteTime {
        endTime = CFAbsoluteTimeGetCurrent()

        return duration!
    }

    var duration: CFAbsoluteTime? {
        if let endTime = endTime {
            return endTime - startTime
        } else {
            return nil
        }
    }
}
