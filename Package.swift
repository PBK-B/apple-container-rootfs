// swift-tools-version: 6.3
//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "container-rootfs",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "container-rootfs", targets: ["ContainerRootFS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.11.0"),
        .package(url: "https://github.com/apple/containerization.git", exact: "0.31.0"),
    ],
    targets: [
        .executableTarget(
            name: "ContainerRootFS",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Containerization", package: "containerization"),
                .product(name: "ContainerizationOCI", package: "containerization"),
                .product(name: "ContainerizationArchive", package: "containerization"),
                .product(name: "ContainerizationOS", package: "containerization"),
                .product(name: "ContainerizationEXT4", package: "containerization"),
            ],
            path: "Sources/ContainerRootFS"
        ),
        .testTarget(
            name: "ContainerRootFSTests",
            dependencies: ["ContainerRootFS"],
            path: "Tests/ContainerRootFSTests"
        ),
    ]
)
