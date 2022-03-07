import Foundation
import PythonKit

// does this need to be public?
@_cdecl("validation_test")
func validation_test() {
  print("Should be '42':", meaningOfLife)
  print("Should be 'None':", Python.None)
}
