//
//  UserController.swift
//  RVNav
//
//  Created by Lambda_School_Loaner_214 on 1/16/20.
//  Copyright © 2020 RVNav. All rights reserved.
//

import Foundation
import FirebaseAnalytics

enum UserControllerError: Error {
    case noUserID(Any)
}

class UserController: UserControllerProtocol {
    static let shared = UserController()
    let networkController: NetworkControllerProtocol
    let userDefaults = UserDefaults.standard
    var currentUserID: Int?
    var hasToken: Bool = false
    let useridKey: String = "currentUserID"
    
    init (networkController: NetworkControllerProtocol = WebRESTAPINetworkController()) {
        self.networkController = networkController
        currentUserID = userDefaults.integer(forKey: useridKey)
    }
    
    func register(with user: User, completion: @escaping (Error?) -> Void) {
        networkController.register(with: user) {error in
            if let error = error  {
                completion(error)
                return
            }
            Analytics.logEvent("register", parameters: nil)
            completion(nil)
        }
    }
    
    func signIn(with signInInfo: SignInInfo, completion: @escaping (Int?, Error?) -> Void) {
        networkController.signIn(with: signInInfo) { (userID, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let userID = userID  else {
                completion(nil, UserControllerError.noUserID("No User ID Retrieved from Signin."))
                return
            }
            self.currentUserID = userID
            Analytics.logEvent("login", parameters: nil)
            completion(self.currentUserID, nil)
        }
        return
    }
    
    func logout(completion: @escaping () -> Void = { }) {
        networkController.logout(completion: completion)
        userDefaults.removeObject(forKey: useridKey)
    }
}
