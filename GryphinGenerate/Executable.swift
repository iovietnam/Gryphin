//
//  Executable.swift
//  Gryphin
//
//  Created by Dima Bart on 2017-02-22.
//  Copyright © 2017 Dima Bart. All rights reserved.
//

import Foundation

class Executable {

    let args        = Arguments()
    let fileManager = FileManager.default
    
    // ----------------------------------
    //  MARK: - Init -
    //
    init() {
        
    }
    
    // ----------------------------------
    //  MARK: - Execution -
    //
    private func findConfigurationURL() throws -> URL {
        guard let rootPath = args.rootPath, !rootPath.isEmpty else {
            print("A path to the root directory is required.")
            exit(1)
        }
        
        let rootURL     = URL(fileURLWithPath: rootPath)
        let coordinator = ConfigurationCoordinator(at: rootURL)
        
        let configURL   = try coordinator.findConfiguration()
        
        return configURL
    }
    
    private func loadConfigurationAt(_ url: URL) throws -> Configuration {
        let json = try JSON.from(fileAt: url)
        return Configuration(json: json)
    }
    
    func execute() {
        
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            print("Generation time: \(CFAbsoluteTimeGetCurrent() - start) sec")
        }
        
        guard let destinationPath = args.destinationPath, !destinationPath.isEmpty else {
            print("A destination path for the generated files directory is required.")
            exit(1)
        }
        
        let destinationURL = URL(fileURLWithPath: destinationPath)
        
        do {
            let configURL = try self.findConfigurationURL()
            print("Using configuration at: \(configURL.absoluteString)")
            
            /* ------------------------------------
             ** We need to set the current working
             ** directory to be the configuration's
             ** containing folder so that all paths
             ** referenced in .gryphin are relative
             ** to this location.
             */
            self.fileManager.changeCurrentDirectoryPath(configURL.deletingLastPathComponent().path)
            print("Changed to configuration directory: \(self.fileManager.currentDirectoryPath)")
            
            let configuration = try self.loadConfigurationAt(configURL)
            let schemaJSON    = try configuration.loadSchema()
            let generator     = Swift.Generator(withSchema: schemaJSON, configuration: configuration)
            
            let files = generator.generate()
            try files.forEach { file in
                let content = file.container.stringRepresentation
                let fileURL = file.url(relativeTo: destinationURL)
                
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            /* -------------------------------------
             ** Check if custom scalars are provided
             ** and handle the implementations.
             */
            let scalarFile = files.filter { $0.kind == .aliases }.first!
            let scalarURL  = scalarFile.url(relativeTo: destinationURL)
            
            try self.copyScalarsDefinedIn(configuration, to: scalarURL)
            
            print("Schema generated to: \(destinationURL)")
            
        } catch ConfigurationError.noSchemaLocation {
            
            print("Failed to load schema. Configuration must provide a `path` or `url` parameters for `schema`.")
            exit(1)
            
        } catch JsonError.readFailed(let url) {
            
            print("Failed to read file at: \(url)")
            exit(1)
            
        } catch JsonError.invalidFormat {
            
            print("Failed to parse schema JSON. The format is invalid.")
            exit(1)
            
        } catch JsonError.invalidSchema {
            
            print("Failed to parse schema JSON. The schema layout is invalid.")
            exit(1)
            
        } catch ConfigurationCoordinatorError.notFound {
            
            print("Failed to find .gryphin configuration file. Create a configuration file named .grypin in your project root.")
            exit(1)
            
        } catch ConfigurationCoordinatorError.multipleFound {
            
            print("Failed to load .gryphin configuration, multiple files found. There must only be one configuration file.")
            exit(1)
            
        } catch let error {
            print("Failed to generate schema: \(error)")
            exit(1)
        }
    }
    
    // ----------------------------------
    //  MARK: - Scalars -
    //
    private func copyScalarsDefinedIn(_ configuration: Configuration, to url: URL) throws {
        guard let scalarDescriptions = configuration.scalarDescriptions else {
            return
        }
        
        let newline = "\n".data(using: .utf8)!
        let file    = try FileHandle(forWritingTo: url)
        file.seekToEndOfFile()
        
        defer {
            file.closeFile()
        }
        
        var processedSources: Set<URL> = []
        
        for scalarDescription in scalarDescriptions {
            if case .file(let sourceURL) = scalarDescription.source, !processedSources.contains(sourceURL) {
                
                if let data = try? Data(contentsOf: sourceURL) {
                    print("Writing scalar definitions from: \(sourceURL)")
                    file.write(newline)
                    file.write(data)
                }
                processedSources.insert(sourceURL)
            }
        }
    }
}
