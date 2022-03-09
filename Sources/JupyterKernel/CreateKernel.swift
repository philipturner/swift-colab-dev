import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let Kernel = Python.import("ipykernel.kernelbase").Kernel

/// Move this downward after debugging

fileprivate var preservedSwiftKernelRef: PythonObject?

@_cdecl("JupyterKernel_constructSwiftKernelClass")
public func JupyterKernel_constructSwiftKernelClass(_ classObj: OpaquePointer) {
  let SwiftKernel = PythonObject(OwnedPyObjectPointer(classObj))
  print(4, SwiftKernel)
}

/// [End section to move]

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  // first try class declaration. Then, try type creation.
  PyRun_SimpleString("""
  from ctypes import *; from ipykernel.kernelbase import Kernel
  SwiftKernel = type("SwiftKernel", (Kernel, object), {})
  
  print(3, SwiftKernel)     
  func = PyDLL("/opt/swift/lib/libJupyterKernel.so").JupyterKernel_constructSwiftKernelClass
  func.argtypes = [c_void_p]
  func(c_void_p(id(SwiftKernel)))
  """)
   
  
  
  let fm = FileManager.default
  let runtimePath = "/opt/swift/runtime_type"
  
  let runtimeData = fm.contents(atPath: runtimePath)!
  let currentRuntime = String(data: runtimeData, encoding: .utf8)!.lowercased()
  
  let MyClass = PythonClass(
    "MyClass",
    superclasses: [Python.object],
    members: [
      "mem1": "val1"
    ]
  ).pythonObject
  
  print(MyClass().mem1)
  let evenOlderInstance = MyClass()
  
  MyClass.mem2 = PythonObject("val2")
  print(MyClass().mem2)
  let oldInstance = MyClass()
  print(evenOlderInstance.mem1)
  
  MyClass.firstMethod = PythonInstanceMethod { (`self`: PythonObject) in
    print(`self`.mem1, `self`.mem2)
    return Python.None
  }.pythonObject
  MyClass().firstMethod()
  oldInstance.firstMethod()
  
  if currentRuntime == "swift" {
    print("Debug checkpoint (Swift) in CreateKernel.swift")
  } else if currentRuntime == "python3" {
    print("Debug checkpoint (Python) in CreateKernel.swift")
  } else {
    print("Debug checkpoint (Unknown) in CreateKernel.swift")
  }
  
  // --- uncomment in development mode
  let nextRuntime = ["python3", "python"].contains(currentRuntime) ? "swift" : "python3"
  // --- uncomment in release mode
//   let nextRuntime = ["python3", "python"].contains(currentRuntime) ? "python3" : "swift"
  fm.createFile(atPath: runtimePath, contents: nextRuntime.data(using: .utf8)!)
  
  // Until there is a built-in alternative, switch back into Python mode on the next
  // runtime restart. This makes debugging a lot easier and decreases the chance my
  // main account will be kicked off of Colab for excessive restarts/downloads.
  if ["python3", "python"].contains(currentRuntime) {
    activatePythonKernel()
  } else {
    activateSwiftKernel()
  }
}

fileprivate func activateSwiftKernel() {
  print("=== Activating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
//   PyRun_SimpleString("""
  
//   """)
  
//   // Initialize the Swift kernel
//   let SwiftKernel = PythonClass(
//     "SwiftKernel",
//     superclasses: [Kernel],
//     members: [
//       // How many of these members are actually necessary?
//       "implementation": "swift",
//       "implementation_version": "2.0",
//       "banner": "",

//       "language_info": [
//         "name": "swift",
//         "mimetype": "text/x-swift",
//         "file_extension": ".swift",
//         "version": ""
//       ],
    
// //       "__init__": PythonInstanceMethod { (params: [PythonObject]) in
// //         let `self` = params[0]
// //         let kwargs = params[1]
// //         Kernel.__init__(`self`, kwargs)

// //         return Python.None
// //       }
//     ]
//   ).pythonObject
  
  let IPKernelApp = Python.import("ipykernel.kernelapp").IPKernelApp
  // We pass the kernel name as a command-line arg, since Jupyter gives those
  // highest priority (in particular overriding any system-wide config).
//   IPKernelApp.launch_instance(
//     argv: CommandLine.arguments + ["--IPKernelApp.kernel_class=SwiftKernel"])
  
//   print(SwiftKernel)
}

// The original Python kernel. There is no way to get it run besides
// passing a string into the Python interpreter. No component of the
// string can be extracted into Swift.
fileprivate func activatePythonKernel() {
  print("=== Activating Python kernel ===")
  
  // Remove the CWD from sys.path while we load stuff.
  // This is added back by InteractiveShellApp.init_path()
  PyRun_SimpleString("""
  import sys
  if sys.path[0] == '':
    del sys.path[0]
  
  from ipykernel import kernelapp as app
  app.launch_new_instance()          
  """)
}

