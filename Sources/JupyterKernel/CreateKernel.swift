import Foundation

fileprivate let signal = Python.import("signal")
fileprivate let ipykernel = Python.import("ipykernel")

@_cdecl("JupyterKernel_createSwiftKernel")
public func JupyterKernel_createSwiftKernel() {
  // TODO: remove this notice
  print("=== Creating Swift kernel ===")
  
  // Jupyter sends us SIGINT when the user requests execution interruption.
  // Here, we block all threads from receiving the SIGINT, so that we can
  // handle it in a specific handler thread.
  signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGINT])
  
  // TODO: launch kernel
}
