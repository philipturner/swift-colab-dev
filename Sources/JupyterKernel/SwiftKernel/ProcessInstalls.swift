import Foundation
fileprivate let shlex = Python.import("shlex")

func processInstallDirective(line: String, isValidDirective: inout Bool) throws {
  isValidDirective = true
}
