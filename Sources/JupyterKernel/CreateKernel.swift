import Foundation
import PythonKit

@_cdecl("testFunction")
func testFunction() {
  print("Should be '42':", meaningOfLife)
  print("Should be 'None':", Python.None)
}


