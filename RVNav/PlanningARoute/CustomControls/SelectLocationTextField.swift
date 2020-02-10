//
//  SelectLocationTextField.swift
//  RVNav
//
//  Created by Lambda_School_Loaner_214 on 1/25/20.
//  Copyright © 2020 RVNav. All rights reserved.
//

import UIKit
import ArcGIS

class SelectLocationTextField: NibDesignableControl {

    // MARK: - Properties
    private let nibName = "SelectLocationTextField"
    public var delegate: SelectALocationDelegate?
    public var label: String? {
        didSet {
            labelView.text = self.label
            setNeedsDisplay()
        }
    }
    public var location: AGSGeocodeResult?{
        didSet{
            self.label = location?.label
        }
    }
    @IBInspectable public var leftImage: UIImage? {
        get{
            return leftImageView.image
        }
        set {
            leftImageView.image = newValue
            setNeedsDisplay()
        }
    }
    @IBInspectable public var _cornerRadius: CGFloat = 4 {
        didSet{
            containerView.layer.cornerRadius = _cornerRadius
            setNeedsDisplay()
        }
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var labelView: UILabel!
    @IBOutlet weak var leftImageView: UIImageView!
    
    // MARK: - View Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonSetup()
    }
    
    
    override class func awakeFromNib() {
        super.awakeFromNib()
        //Configure anything that may need outlets here
    }
    
    @objc func openSelect() {
        delegate?.openSelectALocation(target: self)
    }
    
    // MARK: Interface Builder
    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
    }
    
    // MARK: - IBActions
    // MARK: - Private Methods
    
    private func commonSetup () {
        addTarget(self, action: #selector(openSelect), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(openSelect))
        isUserInteractionEnabled = true
        tap.numberOfTapsRequired = 1
        tap.numberOfTouchesRequired = 1
        containerView.addGestureRecognizer(tap)
        containerView.layer.cornerRadius = _cornerRadius
    }
}

// MARK: - Extensions

extension SelectLocationTextField: SelectALocationDelegate {
    func locationSelected(location: AGSGeocodeResult) {
        self.location = location
    }
    
    func openSelectALocation(target: SelectALocationDelegate) {
        //nothing should be needed here
    }
}
