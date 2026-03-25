//
//  MapRootHost.swift
//  compass-sample-app
//
//  Created by p0a0595 on 9/11/25.
//
//

//import SwiftUI
//import LivingDesign
//
//struct MapRootHost: UIViewControllerRepresentable {
//    let viewController: LDRootViewController
//    
//    func makeUIViewController(context: Context) -> LDRootViewController {
//        return viewController
//    }
//    
//    func updateUIViewController(_ uiViewController: LDRootViewController, context: Context) {
//        
//    }
//}

import SwiftUI
import LivingDesign

final class MapContainerViewController: UIViewController {
    let mapRoot: LDRootViewController

    init(mapRoot: LDRootViewController) {
        self.mapRoot = mapRoot
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rehostIfNeeded()
    }

    func rehostIfNeeded() {
        let child = mapRoot

        if let parent = child.parent, parent !== self {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        if child.parent !== self {
            addChild(child)
            child.didMove(toParent: self)
        }

        if child.view.superview !== view {
            let v = child.view!
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                v.topAnchor.constraint(equalTo: view.topAnchor),
                v.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

struct MapRootHost: UIViewControllerRepresentable {
    let viewController: LDRootViewController
    @Binding var mapViewController: UIViewController?

    func makeUIViewController(context: Context) -> MapContainerViewController {
        addMapViewController(mapViewController)
        let containerViewControler = MapContainerViewController(mapRoot: viewController)
        return containerViewControler
    }

    func updateUIViewController(_ uiViewController: MapContainerViewController, context: Context) {
        addMapViewController(mapViewController)
        uiViewController.rehostIfNeeded()
    }

    func addMapViewController(_ mapViewController: UIViewController?) {
        guard let mapViewController else {
            viewController.children.forEach { viewController.remove(childVC: $0) }
            return
        }

        viewController.children
            .filter { $0 !== mapViewController }
            .forEach { viewController.remove(childVC: $0) }

        if let parent = mapViewController.parent, parent !== viewController {
            parent.remove(childVC: mapViewController)
        }

        if mapViewController.parent !== viewController {
            viewController.add(childVC: mapViewController)
        }
    }
}

struct KeyboardIgnoringMapHost: View {
    let viewController: LDRootViewController
    @Binding var mapViewController: UIViewController?

    var body: some View {
        GeometryReader { proxy in
            MapRootHost(viewController: viewController, mapViewController: $mapViewController)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private extension UIViewController {
    func add(childVC: UIViewController) {
        addChild(childVC)
        view.addSubview(childVC.view)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints([
            childVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        childVC.didMove(toParent: self)
    }

    func remove(childVC: UIViewController) {
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
    }
}
