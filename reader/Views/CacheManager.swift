import Foundation

class CacheManager {
    static let instance = CacheManager()
    private let fileManager = FileManager.default
    
    // 获取缓存文件夹路径: Documents/BookCache
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths[0]
        let cacheDir = docDir.appendingPathComponent("BookCache")
        
        // 如果文件夹不存在，创建它
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }
    
    // MARK: - 章节缓存 API
    
    // 保存章节内容
    func saveChapter(bookId: String, order: Int, title: String, content: String) {
        let folder = cacheDirectory.appendingPathComponent(bookId)
        
        // 1. 确保这本书的文件夹存在
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        // 2. 构造文件路径: /BookCache/{bookId}/{order}.json
        let fileURL = folder.appendingPathComponent("\(order).json")
        
        // 3. 构建数据对象
        let chapterData = ChapterResponse(title: title, content: content, order: order)
        
        // 4. 写入文件
        if let data = try? JSONEncoder().encode(chapterData) {
            try? data.write(to: fileURL)
        }
    }
    
    // 读取章节内容
    func getChapter(bookId: String, order: Int) -> ChapterResponse? {
        let fileURL = cacheDirectory.appendingPathComponent(bookId).appendingPathComponent("\(order).json")
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let chapter = try? JSONDecoder().decode(ChapterResponse.self, from: data) {
            return chapter
        }
        return nil
    }
    
    // 检查是否已缓存
    func isCached(bookId: String, order: Int) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(bookId).appendingPathComponent("\(order).json")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - 通用缓存管理
    
    // 计算缓存大小 (用于"清除缓存"功能)
    func getCacheSize(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .background).async {
            guard let enumerator = self.fileManager.enumerator(at: self.cacheDirectory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else {
                DispatchQueue.main.async { completion("0 KB") }
                return
            }
            
            var totalSize: Int64 = 0
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                   let size = resourceValues.totalFileAllocatedSize {
                    totalSize += Int64(size)
                }
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            let sizeStr = formatter.string(fromByteCount: totalSize)
            
            DispatchQueue.main.async {
                completion(sizeStr)
            }
        }
    }
    
    // 清除所有缓存
    func clearCache(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
