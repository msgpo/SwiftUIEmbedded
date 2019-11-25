import OpenSwiftUI
import Foundation
import Nodes

public final class ViewNode: Node {
    public typealias Value = Drawable
    public var value: Value
    public weak var parent: ViewNode?
    public var children: [ViewNode]
    public var uuid = UUID()
    public init(value: Value) {
        self.value = value
        self.children = []
    }
}

extension ViewNode: Equatable {
    public static func == (lhs: ViewNode, rhs: ViewNode) -> Bool {
        return lhs.uuid == rhs.uuid && lhs.parent == rhs.parent
    }
}

extension ViewNode: CustomStringConvertible {
    public var description: String {
        return "\(value)"
    }
}

extension ViewNode {
    static var defaultSpacing: Int {
        return 8
    }
    
    var internalSpacingRequirements: Int {
        let numberOfSpacings = degree - 1
        return numberOfSpacings * Self.defaultSpacing
    }
    
    public func calculateSize(givenWidth: Int) {
        guard isBranch else { return }

        switch value {
        case is HStackDrawable:
            calculateNodeWithHorizontallyStackedNodes(givenWidth: givenWidth)
        default:
            calculateNodeWithVerticallyStackedNodes(givenWidth: givenWidth)
        }
    }
    
    func calculateNodeWithVerticallyStackedNodes(givenWidth: Int) {
        let paddingFromSelf = (value as? ModifiedContentDrawable<PaddingModifier>)?.modifier.value ?? EdgeInsets()
        
        var remainingWidth = givenWidth// - Int(paddingFromSelf.leading) - Int(paddingFromSelf.trailing)
        var proposedWidth = remainingWidth
        
        var requestedWidthsWithIndex = [(index: Int, width: Int)]()
        for (index, child) in children.enumerated() {
            child.calculateSize(givenWidth: proposedWidth)
            let wantedWidth = child.value.wantedWidthForProposal(proposedWidth)
            if proposedWidth > wantedWidth {
                remainingWidth = remainingWidth - wantedWidth
                if child.value.size.width < 1 {
                    child.value.size.width = wantedWidth
                }
            } else {
                requestedWidthsWithIndex.append((index: index, width: wantedWidth))
            }
        }
        
        if requestedWidthsWithIndex.count > 0 {
            proposedWidth = remainingWidth
            for unclearWidth in requestedWidthsWithIndex {
                if children[unclearWidth.index].value.size.width < 1 {
                    children[unclearWidth.index].value.size.width = givenWidth
                }
            }
        }
        
        var maxHeight = Int(paddingFromSelf.top + paddingFromSelf.bottom)
        for child in children {
            let childHeight = child.value.wantedHeightForProposal(remainingWidth)
            if child.value.size.height < 1 {
                child.value.size.height = childHeight
            }
            maxHeight += childHeight
        }
        
        let total = (children.map { $0.value.size.width }.max() ?? 0) + Int(paddingFromSelf.leading + paddingFromSelf.trailing)
        let totalHeight = children.reduce(0, { $0 + $1.value.size.height }) + internalSpacingRequirements
        
        value.size = Size(width: total, height: totalHeight + Int(paddingFromSelf.top + paddingFromSelf.bottom))
        
        for (index, child) in children.enumerated() {
            if index > 0 {
                let previousNode = children[index - 1]
                child.value.origin.y = previousNode.value.origin.y + previousNode.value.size.height + ViewNode.defaultSpacing
            }
        }
    }
    
    func calculateNodeWithHorizontallyStackedNodes(givenWidth: Int) {
        var remainingWidth = givenWidth - internalSpacingRequirements // - Int(paddingFromParent.leading) - Int(paddingFromParent.trailing)
        var totalWidth = internalSpacingRequirements
        
        var remainingChildren = degree
        
        var requestedWidthsWithIndex = [(index: Int, width: Int)]()
        var dividerIndicies = [Int]()
        for (index, child) in children.enumerated() {
            let proposedWidth = remainingWidth / remainingChildren
            
            child.calculateSize(givenWidth: proposedWidth)
            let wantedWidth = child.value.wantedWidthForProposal(proposedWidth)
            
            if proposedWidth > wantedWidth {
                if child.value is DividerDrawable {
                    dividerIndicies.append(index)
                }
                remainingWidth = remainingWidth - wantedWidth
                if child.value.size.width < 1 {
                    child.value.size.width = wantedWidth
                }
                totalWidth = totalWidth + wantedWidth
                remainingChildren -= 1
            } else if child.value.size.width > 0 {
                remainingWidth = remainingWidth - child.value.size.width
                remainingChildren -= 1
            } else {
                requestedWidthsWithIndex.append((index: index, width: wantedWidth))
            }
        }
        
        
        if requestedWidthsWithIndex.count > 0 {
            let proposedWidth = remainingWidth / requestedWidthsWithIndex.count
            for unclearWidth in requestedWidthsWithIndex {
                if children[unclearWidth.index].value.size.width == 0 {
                    children[unclearWidth.index].value.size.width = proposedWidth
                }
                totalWidth = totalWidth + proposedWidth
            }
        }
        
        var maxHeight = 0
        for child in children {
            let childHeight = child.value.wantedHeightForProposal(remainingWidth)
            if child.value.size.height < 1 {
                child.value.size.height = childHeight
            }
            if childHeight > maxHeight {
                maxHeight = childHeight
            }
        }
        
        let total = children.reduce(0, { $0 + $1.value.size.width }) + internalSpacingRequirements
        let totalHeight = children.map { $0.value.size.height }.max() ?? 1
        
        if dividerIndicies.count > 0 {
            for dividerIndex in dividerIndicies {
                children[dividerIndex].value.size.height = totalHeight
            }
        }
        
        value.size = Size(width: total, height: totalHeight)
        
        for (index, child) in children.enumerated() {
            if index > 0 {
                let previousNode = children[index - 1]
                child.value.origin.x = previousNode.value.origin.x + previousNode.value.size.width + ViewNode.defaultSpacing
            }
        }
    }
}
