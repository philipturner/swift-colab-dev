import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")
