import SwiftUI
import SceneKit

struct BodyWireframeOverlayView: NSViewRepresentable {
    var body_: BodyLandmarks?
    var leftHand: HandLandmarks?
    var rightHand: HandLandmarks?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.isPlaying = true
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 30
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.update(body: body_, leftHand: leftHand, rightHand: rightHand)
    }

    // MARK: - Coordinator

    class Coordinator {
        var scene = SCNScene()

        private var modelRoot: SCNNode?
        private var boneNodes: [String: SCNNode] = [:]
        private let leftHandRoot = SCNNode()
        private let rightHandRoot = SCNNode()
        private var leftHandBoneNodes: [SCNNode] = []
        private var rightHandBoneNodes: [SCNNode] = []

        private let cameraNode = SCNNode()
        private let lightNode = SCNNode()

        private var restWorldQuats: [String: simd_quatf] = [:]
        private var restWorldAngles: [String: Float] = [:]

        // Model is ~0.017 units tall in scene (Z-up)
        // All spatial values (hands, camera) use this scale
        private let modelScale: Float = 0.017

        private let drivenBones: [(name: String, segment: String)] = [
            ("Spine02",        "spine"),
            ("neck",           "neck"),
            ("Head",           "head"),
            ("LeftShoulder",   "l_shoulder"),
            ("RightShoulder",  "r_shoulder"),
            ("LeftArm",        "l_upper_arm"),
            ("RightArm",       "r_upper_arm"),
            ("LeftForeArm",    "l_forearm"),
            ("RightForeArm",   "r_forearm"),
            ("LeftUpLeg",      "l_thigh"),
            ("RightUpLeg",     "r_thigh"),
            ("LeftLeg",        "l_shin"),
            ("RightLeg",       "r_shin"),
        ]

        private let wireframeMaterial: SCNMaterial = {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = NSColor(calibratedRed: 0, green: 1, blue: 0.4, alpha: 1)
            m.isDoubleSided = true
            m.lightingModel = .constant
            return m
        }()

        private let leftHandMaterial: SCNMaterial = {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = NSColor.cyan
            m.isDoubleSided = true
            m.lightingModel = .constant
            return m
        }()

        private let rightHandMaterial: SCNMaterial = {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.diffuse.contents = NSColor.orange
            m.isDoubleSided = true
            m.lightingModel = .constant
            return m
        }()

        init() {
            setupCamera()
            setupHands()
            loadModel()
        }

        private func setupCamera() {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            // Model is 0.017 tall. Show ~0.024 units of vertical range.
            camera.orthographicScale = 0.012
            camera.zNear = 0.001
            camera.zFar = 100
            cameraNode.camera = camera
            // Z-up model: view from -Y, centered at mid-height
            cameraNode.position = SCNVector3(0, -10, 0.0085)
            cameraNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

            lightNode.light = SCNLight()
            lightNode.light?.type = .ambient
            lightNode.light?.color = NSColor.white
        }

        private func setupHands() {
            for _ in HandLandmarks.boneConnections {
                let cap = SCNCapsule(capRadius: 0.0001, height: 0.001)
                cap.radialSegmentCount = 8
                cap.heightSegmentCount = 2
                cap.capSegmentCount = 4
                cap.materials = [leftHandMaterial]
                let node = SCNNode(geometry: cap)
                node.isHidden = true
                leftHandRoot.addChildNode(node)
                leftHandBoneNodes.append(node)
            }

            for _ in HandLandmarks.boneConnections {
                let cap = SCNCapsule(capRadius: 0.0001, height: 0.001)
                cap.radialSegmentCount = 8
                cap.heightSegmentCount = 2
                cap.capSegmentCount = 4
                cap.materials = [rightHandMaterial]
                let node = SCNNode(geometry: cap)
                node.isHidden = true
                rightHandRoot.addChildNode(node)
                rightHandBoneNodes.append(node)
            }
        }

        // MARK: - Model Loading

        private func loadModel() {
            guard let url = Bundle.main.url(forResource: "human_rigged", withExtension: "dae") else {
                print("BodyWireframeOverlay: human_rigged.dae not found")
                addNodesToScene()
                return
            }

            guard let loadedScene = try? SCNScene(url: url, options: nil) else {
                print("BodyWireframeOverlay: Failed to load scene")
                addNodesToScene()
                return
            }

            // Use loaded scene directly — preserves skinner
            scene = loadedScene
            addNodesToScene()

            // Apply wireframe only to model geometry
            let handNodes = Set<SCNNode>(leftHandBoneNodes + rightHandBoneNodes)
            scene.rootNode.enumerateChildNodes { node, _ in
                if let geometry = node.geometry, !handNodes.contains(node) {
                    geometry.materials = [self.wireframeMaterial]
                }
            }

            // Find model root
            for child in scene.rootNode.childNodes {
                if child !== cameraNode && child !== lightNode &&
                   child !== leftHandRoot && child !== rightHandRoot {
                    modelRoot = child
                    break
                }
            }

            // Find skinner bones
            var skinnerBones: [SCNNode] = []
            scene.rootNode.enumerateChildNodes { node, _ in
                if let skinner = node.skinner {
                    skinnerBones = skinner.bones
                    print("BodyWireframeOverlay: Skinner \(skinner.bones.count) bones")
                    for (i, bone) in skinner.bones.enumerated() {
                        print("  [\(i)] \(bone.name ?? "?")")
                    }
                }
            }

            let allBoneNames = Set(drivenBones.map { $0.name })
            // Match by exact name OR "Armature_BoneName" prefix (SceneKit uses id, not name attr)
            for bone in skinnerBones {
                guard let nodeName = bone.name else { continue }
                for boneName in allBoneNames where boneNodes[boneName] == nil {
                    if nodeName == boneName || nodeName.hasSuffix("_" + boneName) {
                        boneNodes[boneName] = bone
                    }
                }
            }

            let missingBones = allBoneNames.subtracting(boneNodes.keys)
            if !missingBones.isEmpty {
                scene.rootNode.enumerateChildNodes { node, _ in
                    guard let nodeName = node.name else { return }
                    for boneName in missingBones where self.boneNodes[boneName] == nil {
                        if nodeName == boneName || nodeName.hasSuffix("_" + boneName) {
                            self.boneNodes[boneName] = node
                        }
                    }
                }
            }

            print("BodyWireframeOverlay: Matched \(boneNodes.count)/\(drivenBones.count) bones: \(boneNodes.keys.sorted())")

            // Capture rest pose (Z-up: screen X = model X, screen Y = model Z)
            for (name, node) in boneNodes {
                let world = node.simdWorldTransform
                restWorldQuats[name] = rotationOnly(world)
                let boneY = SIMD2<Float>(world.columns.1.x, world.columns.1.z)
                restWorldAngles[name] = atan2(boneY.x, boneY.y)
            }
        }

        private func addNodesToScene() {
            scene.rootNode.addChildNode(cameraNode)
            scene.rootNode.addChildNode(lightNode)
            scene.rootNode.addChildNode(leftHandRoot)
            scene.rootNode.addChildNode(rightHandRoot)
        }

        // MARK: - Vision → segment directions

        private func segmentDirections(from body: BodyLandmarks) -> [String: SIMD2<Float>] {
            func v(_ p: CGPoint) -> SIMD2<Float> {
                SIMD2<Float>(Float(p.x), Float(p.y))
            }
            let midShoulder = (v(body.leftShoulder) + v(body.rightShoulder)) / 2
            let midHip = (v(body.leftHip) + v(body.rightHip)) / 2

            return [
                "spine":       midShoulder - midHip,
                "neck":        v(body.nose) - midShoulder,
                "head":        SIMD2<Float>(0, 0.05),
                "l_shoulder":  v(body.leftShoulder) - midShoulder,
                "r_shoulder":  v(body.rightShoulder) - midShoulder,
                "l_upper_arm": v(body.leftElbow) - v(body.leftShoulder),
                "r_upper_arm": v(body.rightElbow) - v(body.rightShoulder),
                "l_forearm":   v(body.leftWrist) - v(body.leftElbow),
                "r_forearm":   v(body.rightWrist) - v(body.rightElbow),
                "l_thigh":     v(body.leftKnee) - v(body.leftHip),
                "r_thigh":     v(body.rightKnee) - v(body.rightHip),
                "l_shin":      v(body.leftAnkle) - v(body.leftKnee),
                "r_shin":      v(body.rightAnkle) - v(body.rightKnee),
            ]
        }

        // MARK: - Update

        func update(body: BodyLandmarks?, leftHand: HandLandmarks?, rightHand: HandLandmarks?) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0

            modelRoot?.isHidden = false
            if let body = body {
                updateModel(body)
            }

            if let left = leftHand {
                updateHand(left, nodes: leftHandBoneNodes)
                leftHandRoot.isHidden = false
            } else {
                leftHandRoot.isHidden = true
            }

            if let right = rightHand {
                updateHand(right, nodes: rightHandBoneNodes)
                rightHandRoot.isHidden = false
            } else {
                rightHandRoot.isHidden = true
            }

            SCNTransaction.commit()
        }

        private func updateModel(_ body: BodyLandmarks) {
            guard modelRoot != nil else { return }
            let dirs = segmentDirections(from: body)

            for (boneName, segment) in drivenBones {
                guard let node = boneNodes[boneName],
                      let targetDir = dirs[segment],
                      let restAngle = restWorldAngles[boneName],
                      let restWorldQ = restWorldQuats[boneName] else { continue }

                let dirLen = simd_length(targetDir)
                guard dirLen > 0.001 else { continue }

                let targetAngle = atan2(targetDir.x, targetDir.y)
                let worldDelta = targetAngle - restAngle

                let worldDeltaQ = simd_quatf(angle: -worldDelta, axis: SIMD3<Float>(0, -1, 0))
                let desiredWorldQ = worldDeltaQ * restWorldQ

                let parentWorldQ = rotationOnly(node.parent?.simdWorldTransform ?? matrix_identity_float4x4)
                node.simdOrientation = parentWorldQ.inverse * desiredWorldQ
            }
        }

        // MARK: - Helpers

        /// Extract pure rotation from a matrix that may have non-unit scale.
        private func rotationOnly(_ m: simd_float4x4) -> simd_quatf {
            let c0 = simd_normalize(simd_float3(m.columns.0.x, m.columns.0.y, m.columns.0.z))
            let c1 = simd_normalize(simd_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z))
            let c2 = simd_normalize(simd_float3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
            var r = matrix_identity_float4x4
            r.columns.0 = simd_float4(c0, 0)
            r.columns.1 = simd_float4(c1, 0)
            r.columns.2 = simd_float4(c2, 0)
            return simd_quatf(r)
        }

        // MARK: - Hands (Z-up, scaled to model space)

        private func updateHand(_ hand: HandLandmarks, nodes: [SCNNode]) {
            let points = hand.allPoints
            let s = modelScale  // 0.017
            let ortho: Float = 0.012
            let camZ: Float = 0.0085

            for (i, (from, to)) in HandLandmarks.boneConnections.enumerated() {
                guard i < nodes.count else { break }
                let node = nodes[i]
                guard let capsule = node.geometry as? SCNCapsule else { continue }

                // Map vision [0,1] to model XZ space
                let ax = (Float(points[from].x) - 0.5) * ortho * 2
                let az = (Float(points[from].y) - 0.5) * ortho * 2 + camZ
                let bx = (Float(points[to].x) - 0.5) * ortho * 2
                let bz = (Float(points[to].y) - 0.5) * ortho * 2 + camZ

                let dx = bx - ax, dz = bz - az
                let length = hypot(dx, dz)

                guard length > 0.0001 else {
                    node.isHidden = true
                    continue
                }

                capsule.height = CGFloat(length)
                node.position = SCNVector3((ax + bx) / 2, 0, (az + bz) / 2)
                let dir = simd_normalize(SIMD3<Float>(dx, 0, dz))
                node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: dir)
                node.isHidden = false
            }
        }
    }
}
