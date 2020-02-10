//
//  MenuItemController.swift
//  RVNav
//
//  Created by Lambda_School_Loaner_214 on 1/13/20.
//  Copyright © 2020 RVNav. All rights reserved.
//

import Foundation

class MenuItemController {
    private static let sectionNames = ["MAP VIEWS","ROUTING PREFERENCES","PROFILE"]
    private(set) var sections: [MenuItemSection] = []
    
    init () {
        //Create Sections
        self.sections.append(MenuItemSection(name: MenuItemController.sectionNames[0], order: 0, menuItems: [
            MenuItem(label: "Street", imageName: "map", order: 0, segueID: "", selector: "map_street"),
            MenuItem(label: "Satelite", imageName: "satelite", order: 1, segueID: "", selector: "map_sat"),
            MenuItem(label: "Terrain", imageName: "terrain", order: 2, segueID: "", selector: "map_ter"),
            MenuItem(label: "Night", imageName: "nightMode", order: 2, segueID: "", selector: "map_night")]))
        self.sections.append(MenuItemSection(name: MenuItemController.sectionNames[1], order: 1, menuItems: [
            MenuItem(label: "My Vehicles", imageName: "car", order: 0, segueID: "ShowVehichleInfo", inMenu: true),
            MenuItem(label: "Plan A Route", imageName: "navigation-diagonal", order: 1, segueID: "PlanARoute", inMenu: true),
            MenuItem(label: "Saved Routes", imageName: "savedroute", order: 2, segueID: "", inMenu: true),
            MenuItem(label: "Routing options", imageName: "settings", order: 3, segueID: "", inMenu: true)]))
        self.sections.append(MenuItemSection(name: MenuItemController.sectionNames[2], order: 2, menuItems: [
            MenuItem(label: "Logout", imageName: "log-out", order: 0, segueID: "", selector: "logout")]))
    }
    
    convenience init(with sections: [MenuItemSection]) {
        self.init()
        self.sections = sections
    }
    
    func getMenuItem (for index: IndexPath) -> MenuItem {
        return sections[index.section].menuItems[index.row]
    }
    
}
