// FFmpegProcessRunnerDelegate.swift
import Foundation

protocol FFmpegProcessRunnerDelegate: AnyObject {
    func processRunnerDidUpdateProgress(_ progress: Double)
    func processRunnerDidFailWithError(_ error: String)
    func processRunnerDidFinish()
}
