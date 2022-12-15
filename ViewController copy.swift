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

class Canvas: UIView {
    private lazy var rects: [CGRect] = generateRects() {
        didSet {
            collisionDetector = CollisionDetector(rects: rects)
            setNeedsDisplay()
        }
    }
    private lazy var collisionDetector = CollisionDetector(rects: rects)

    var numberOfRects = 7 {
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

        for rect in rects {
            let collission = collisionDetector.detectCollisions(for: rect)
            let color = collission ? UIColor.systemRed : UIColor.systemMint
            
            renderFill(rect, color: color.withAlphaComponent(0.4).cgColor, in: ctx)
            renderPathBoundingBox(rect, color: color.cgColor, in: ctx)
        }

        ctx.endTransparencyLayer()
    }
    
    func reset() {
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


class Element: NSObject {
    let size: CGSize
    
    init(size: CGSize) {
        self.size = size
    }
}

class CollisionDetector {
    private let quadtree: QuadTree<Element>
    
    var covered = [CGRect]()
    
    init(rects: [CGRect]) {
        let boundingRect = rects.reduce(CGRect.zero) { partialResult, rect in
            partialResult.union(rect)
        }
        
        quadtree = QuadTree(frame: boundingRect)
        rects.forEach { rect in
            let _ = quadtree.insertObject(rect: rect)
        }
    }
    
    func detectCollisions(for rect: CGRect) -> Bool {
        let elements = quadtree.queryRegion(region: rect)
        return elements.count > 1
    }
}

//traversed = {}
//gather quadtree leaves
//for each leaf in leaves:
//{
//     for each element in leaf:
//     {
//          if not traversed[element]:
//          {
//              use quad tree to check for collision against other elements
//              traversed[element] = true
//          }
//     }
//}

class QuadTree <T> {
    
    //MARK: Variable Declarations
//    typealias Object = (T, CGPoint)
    
    /// Max number of objects stored by the quadrant
    let nodeCapacity = 4
    
    /// The boundary of the tree
    let boundary: CGRect!
    /// The objects contained in the quadrant
    var objects: [CGRect]!
    
    /// Child Quad Trees
    var northWest: QuadTree?
    var northEast: QuadTree?
    var southWest: QuadTree?
    var southEast: QuadTree?
    
    //MARK: - Class Functions
    /**
        Initializer for the QuadTree class
    
        :param: frame Boundary frame for the QuadTree
    
        :returns: QuadTree class
    */
    
    init(frame theBoundary: CGRect) {
        self.boundary = theBoundary
        self.objects = [CGRect]()
    }
    
    /**
        Inserts an object into the quad tree, dividing the tree if necessary
    
        :param: object Any object
        :param: atPoint location of the object
    
        :returns: true if object was added, false if not
    */
    
    func insertObject(rect: CGRect) -> Bool {
        // Check to see if the region contains the point
        if !boundary.contains(rect) {
            return false
        }
            
        //If there is enough space add the point
        if objects.count < nodeCapacity {
            objects.append(rect)
            return true
        }
        //Otherwise, subdivide and add the point to whichever child will accept it
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
        
        //If all else fails...
        return false
    }
    
    /**
        Querys all objects within a region of the QuadTree
    
        :param: region The region of interest
        :returns: Array of objects that lie within the region of interest
    */
    
    func queryRegion(region: CGRect) -> [CGRect] {
        var objectsInRegion = [CGRect]()
        
        if !(boundary.intersects(region)) {
            return objectsInRegion
        }
        
        for object in objects {
            if region.intersects(object) {
                objectsInRegion.append(object)
            }
        }
        
        //If there are no children stop here
        if northWest == nil {
            return objectsInRegion
        }
        
        //Otherwise add the points from the children
        if northWest != nil {
            objectsInRegion += northWest!.queryRegion(region: region)
        }
        if northEast != nil {
            objectsInRegion += northEast!.queryRegion(region: region)
        }
        if southWest != nil {
            objectsInRegion += southWest!.queryRegion(region: region)
        }
        if southEast != nil {
            objectsInRegion += southEast!.queryRegion(region: region)
        }
        
        return objectsInRegion
    }
    
    //MARK: - Private Functions
    /**
        Function to subdivide a QuadTree into 4 smaller QuadTrees
    */
    private func subdivide() {
        let size = CGSize(width: boundary.width / 2.0, height: boundary.height / 2.0)
        
        northWest = QuadTree(frame: CGRect(origin: CGPoint(x: boundary.minX, y: boundary.minY), size: size))
        northEast = QuadTree(frame: CGRect(origin: CGPoint(x: boundary.midX, y: boundary.minY), size: size))
        southWest = QuadTree(frame: CGRect(origin: CGPoint(x: boundary.minX, y: boundary.midY), size: size))
        southEast = QuadTree(frame: CGRect(origin: CGPoint(x: boundary.midX, y: boundary.midY), size: size))
        
    }

}
